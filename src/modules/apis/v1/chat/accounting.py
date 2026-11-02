"""Generation attempt ledger: every model generation is recorded before the provider is called.

Finalization is a single conditional update (`outcome = 'started'`), so a turn is accounted once even
when completion, failure and a client disconnect race. Usage is stored only when the provider
reported it; otherwise the attempt keeps `usage_state = 'unknown'` and no zero-token usage row exists.
"""

from __future__ import annotations

import asyncio
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.observability import tracer
from src.core.settings.config import settings
from src.core.settings.logging import logger
from src.services.databases.postgresql import database
from src.services.databases.postgresql.models import GenerationAttempt

STARTED, COMPLETED, FAILED, CANCELLED = "started", "completed", "failed", "cancelled"
REPORTED, UNKNOWN = "reported", "unknown"
TOKEN_KEYS = ("input_tokens", "output_tokens", "total_tokens")
# A started attempt older than this was lost (crash/restart) and is treated as unknown usage.
STALE_AFTER = timedelta(minutes=15)


def usage_reported(usage: dict[str, Any] | None) -> bool:
    return bool(usage) and any(int(usage.get(key) or 0) > 0 for key in TOKEN_KEYS)


async def start(
    db: AsyncSession,
    *,
    space_id: str,
    user_id: str,
    session_id: str | None,
    user_message_id: str | None,
    endpoint: str,
    model: str | None,
) -> str:
    """Persist the attempt and commit before any provider call, so nothing can erase it."""
    attempt = GenerationAttempt(
        space_id=space_id,
        user_id=user_id,
        session_id=session_id,
        user_message_id=user_message_id,
        endpoint=endpoint,
        model=model,
        outcome=STARTED,
        usage_state=UNKNOWN,
    )
    db.add(attempt)
    await db.commit()
    return attempt.id


async def finalize(
    db: AsyncSession,
    attempt_id: str,
    *,
    outcome: str,
    usage: dict[str, Any] | None,
    model: str | None,
    space_id: str,
    user_id: str,
    session_id: str | None,
    endpoint: str,
    error_code: str | None = None,
    meta: dict[str, Any] | None = None,
    tool_usage: dict[str, int] | None = None,
) -> bool:
    """Close the attempt once. Returns False if it was already finalized. The caller commits."""
    from src.modules.apis.v1.chat.service import chat_service

    reported = usage_reported(usage)
    values: dict[str, Any] = {
        "outcome": outcome,
        "usage_state": REPORTED if reported else UNKNOWN,
        "error_code": error_code,
        "finished_at": datetime.utcnow(),
    }
    if reported:
        values.update({key: int((usage or {}).get(key) or 0) for key in TOKEN_KEYS})
    result = await db.execute(
        update(GenerationAttempt)
        .where(GenerationAttempt.id == attempt_id, GenerationAttempt.outcome == STARTED)
        .values(**values)
        .returning(GenerationAttempt.id)
    )
    if result.first() is None:
        return False
    if reported or tool_usage:
        # Tool calls are counted even when token usage is unknown; such rows are flagged so that
        # summaries never read their zero token columns as measured usage.
        cost = tracer.estimate_cost(model, usage) if reported and model else {}
        event = await chat_service.record_usage_event(
            db,
            space_id=space_id,
            user_id=user_id,
            session_id=session_id,
            endpoint=endpoint,
            model=model,
            usage_details=usage if reported else None,
            cost_usd=(cost or {}).get("total_cost_usd"),
            meta_payload={
                **(meta or {}),
                "attempt_id": attempt_id,
                "outcome": outcome,
                **({} if reported else {"token_usage": UNKNOWN}),
            },
            tool_usage=tool_usage or None,
        )
        await db.execute(
            update(GenerationAttempt).where(GenerationAttempt.id == attempt_id).values(usage_event_id=event.id)
        )
    return True


async def finalize_detached(attempt_id: str, **kwargs: Any) -> None:
    """Finalize from a fresh session, shielded from the cancelled request (client disconnect)."""

    async def _write() -> None:
        async with database.AsyncSessionLocal() as db:
            if await finalize(db, attempt_id, **kwargs):
                await db.commit()

    try:
        await asyncio.shield(_write())
    except asyncio.CancelledError:
        # The shielded write keeps running; the caller's cancellation still propagates.
        raise
    except Exception:  # noqa: BLE001
        logger.exception("Could not finalize generation attempt", extra={"attempt_id": attempt_id})


def _unknown_filter(space_id: str, user_id: str, since: datetime, until: datetime):
    return (
        GenerationAttempt.space_id == space_id,
        GenerationAttempt.user_id == user_id,
        GenerationAttempt.started_at >= since,
        GenerationAttempt.started_at <= until,
        GenerationAttempt.usage_state == UNKNOWN,
    )


async def unknown_usage_count(db: AsyncSession, *, space_id: str, user_id: str, since: datetime, until: datetime) -> int:
    """Attempts whose usage the provider never reported (cancelled, failed, crashed, or still running)."""
    result = await db.execute(
        select(func.count(GenerationAttempt.id)).where(*_unknown_filter(space_id, user_id, since, until))
    )
    return int(result.scalar() or 0)


async def unknown_usage_breakdown(db: AsyncSession, *, space_id: str, user_id: str, since: datetime, until: datetime) -> dict[str, int]:
    now = datetime.utcnow()
    rows = await db.execute(
        select(GenerationAttempt.outcome, GenerationAttempt.started_at).where(*_unknown_filter(space_id, user_id, since, until))
    )
    breakdown = {CANCELLED: 0, FAILED: 0, COMPLETED: 0, "in_progress": 0, "lost": 0}
    for outcome, started_at in rows.all():
        if outcome == STARTED:
            breakdown["lost" if now - started_at > STALE_AFTER else "in_progress"] += 1
        else:
            breakdown[outcome] = breakdown.get(outcome, 0) + 1
    return breakdown


def unknown_usage_reservation() -> int:
    """Tokens counted against token quotas per attempt with unknown usage (a quota rule, not usage)."""
    return max(0, int(getattr(settings, "QUOTA_UNKNOWN_USAGE_TOKENS", 4000)))
