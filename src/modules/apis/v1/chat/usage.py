"""User-facing usage overview with explicit cost coverage.

Costs are estimates from the configured price table (`tracer.estimate_cost`), never provider invoices.
Requests whose usage or price is unknown are counted and reported as such, never as zero cost.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any, Optional

from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.services.databases.postgresql.models import ChatSession, LLMUsageEvent, User

from . import accounting

PERIOD_DAYS = (1, 7, 30, 90)


class UsageWindow(BaseModel):
    start: datetime
    end: datetime
    days: int
    timezone: str = "UTC"
    kind: str = "rolling"


class UsageCost(BaseModel):
    basis: str = "estimated"
    currency: str = "USD"
    amount: Optional[float] = None
    complete: bool
    requests_without_cost: int


class UsageRequests(BaseModel):
    total: int
    with_reported_usage: int
    with_unknown_usage: int
    unknown_breakdown: dict[str, int]


class UsageTokens(BaseModel):
    input: int
    output: int
    total: int


class UsageModelRow(BaseModel):
    model: str
    requests: int
    input_tokens: int
    output_tokens: int
    total_tokens: int
    cost_usd: Optional[float] = None
    cost_complete: bool


class UsageToolRow(BaseModel):
    tool: str
    requests: int
    cost_usd: Optional[float] = None


class UsageLimit(BaseModel):
    key: str
    unit: str
    window_hours: int
    limit: Optional[int] = None
    used: int
    remaining: Optional[int] = None
    reserved_for_unknown: int = 0


class UsageOverview(BaseModel):
    window: UsageWindow
    requests: UsageRequests
    tokens: UsageTokens
    cost: UsageCost
    by_model: list[UsageModelRow]
    tools: list[UsageToolRow]
    limits: list[UsageLimit]


def _unknown_tokens(event: LLMUsageEvent) -> bool:
    payload = event.meta_payload if isinstance(event.meta_payload, dict) else {}
    return payload.get("token_usage") == accounting.UNKNOWN


async def _events(db: AsyncSession, user: User, space_id: str, since: datetime, until: datetime) -> list[LLMUsageEvent]:
    result = await db.execute(
        select(LLMUsageEvent).where(
            LLMUsageEvent.user_id == user.id,
            LLMUsageEvent.space_id == space_id,
            LLMUsageEvent.created_at >= since,
            LLMUsageEvent.created_at <= until,
        )
    )
    return list(result.scalars().all())


async def _sessions_since(db: AsyncSession, user: User, space_id: str, since: datetime, until: datetime) -> int:
    result = await db.execute(
        select(ChatSession.id).where(
            ChatSession.user_id == user.id,
            ChatSession.space_id == space_id,
            ChatSession.created_at >= since,
            ChatSession.created_at <= until,
        )
    )
    return len(result.all())


def _limit(key: str, unit: str, hours: int, limit: Any, used: int, reserved: int = 0) -> UsageLimit:
    value = int(limit) if limit is not None else None
    return UsageLimit(
        key=key,
        unit=unit,
        window_hours=hours,
        limit=value,
        used=used,
        remaining=None if value is None else max(0, value - used),
        reserved_for_unknown=reserved,
    )


async def overview(
    db: AsyncSession,
    *,
    user: User,
    space_id: str,
    policy: dict,
    days: int,
    tool_usage_of,
    tool_costs_of,
) -> UsageOverview:
    days = min(max(int(days), 1), 365)
    end = datetime.utcnow()
    start = end - timedelta(days=days)
    events = await _events(db, user, space_id, start, end)

    measured = [e for e in events if not _unknown_tokens(e) and int(e.total_tokens or 0) > 0]
    unmeasured_events = [e for e in events if not _unknown_tokens(e) and int(e.total_tokens or 0) <= 0]
    unknown_attempts = await accounting.unknown_usage_breakdown(db, space_id=space_id, user_id=user.id, since=start, until=end)
    unknown_count = sum(unknown_attempts.values()) + sum(int(e.request_count or 0) for e in unmeasured_events)
    if unmeasured_events:
        unknown_attempts["not_reported"] = sum(int(e.request_count or 0) for e in unmeasured_events)

    by_model: dict[str, dict[str, Any]] = {}
    without_cost = 0
    cost_sum = 0.0
    for event in measured:
        row = by_model.setdefault(
            event.model or "unknown",
            {"requests": 0, "input": 0, "output": 0, "total": 0, "cost": 0.0, "missing": 0},
        )
        row["requests"] += int(event.request_count or 0)
        row["input"] += int(event.input_tokens or 0)
        row["output"] += int(event.output_tokens or 0)
        row["total"] += int(event.total_tokens or 0)
        if event.cost_usd is None:
            row["missing"] += int(event.request_count or 0)
            without_cost += int(event.request_count or 0)
        else:
            row["cost"] += float(event.cost_usd)
            cost_sum += float(event.cost_usd)

    tool_usage = tool_usage_of(events)
    tool_costs = tool_costs_of(tool_usage)
    tools = [
        UsageToolRow(tool=name, requests=count, cost_usd=tool_costs.get(name))
        for name, count in sorted(tool_usage.items())
    ]
    without_cost += sum(1 for row in tools if row.cost_usd is None)
    cost_sum += sum(row.cost_usd or 0.0 for row in tools)
    has_any_cost = any(e.cost_usd is not None for e in measured) or bool(tool_costs)
    complete = without_cost == 0 and unknown_count == 0

    reservation = accounting.unknown_usage_reservation()
    limits: list[UsageLimit] = []
    for key, hours in (("daily", 24), ("monthly", 24 * 30)):
        since = end - timedelta(hours=hours)
        window_events = [e for e in events if e.created_at >= since] if hours <= days * 24 else await _events(db, user, space_id, since, end)
        known_tokens = sum(int(e.total_tokens or 0) for e in window_events if not _unknown_tokens(e))
        unknown = await accounting.unknown_usage_count(db, space_id=space_id, user_id=user.id, since=since, until=end)
        limits.append(
            _limit(f"{key}_tokens", "tokens", hours, policy.get(f"{key}_token_limit"), known_tokens + unknown * reservation, unknown * reservation)
        )
        limits.append(
            _limit(f"{key}_conversations", "conversations", hours, policy.get(f"{key}_request_limit"), await _sessions_since(db, user, space_id, since, end))
        )
        tool_used = sum(int(v or 0) for v in tool_usage_of(window_events).values())
        limits.append(_limit(f"{key}_tool_requests", "tool_requests", hours, policy.get(f"{key}_tool_request_limit"), tool_used))

    return UsageOverview(
        window=UsageWindow(start=start, end=end, days=days),
        requests=UsageRequests(
            total=sum(int(e.request_count or 0) for e in measured) + unknown_count,
            with_reported_usage=sum(int(e.request_count or 0) for e in measured),
            with_unknown_usage=unknown_count,
            unknown_breakdown={k: v for k, v in unknown_attempts.items() if v},
        ),
        tokens=UsageTokens(
            input=sum(int(e.input_tokens or 0) for e in measured),
            output=sum(int(e.output_tokens or 0) for e in measured),
            total=sum(int(e.total_tokens or 0) for e in measured),
        ),
        cost=UsageCost(
            amount=round(cost_sum, 6) if has_any_cost else None,
            complete=complete,
            requests_without_cost=without_cost + unknown_count,
        ),
        by_model=[
            UsageModelRow(
                model=model,
                requests=row["requests"],
                input_tokens=row["input"],
                output_tokens=row["output"],
                total_tokens=row["total"],
                cost_usd=round(row["cost"], 6) if row["missing"] < row["requests"] else None,
                cost_complete=row["missing"] == 0,
            )
            for model, row in sorted(by_model.items())
        ],
        tools=tools,
        limits=limits,
    )
