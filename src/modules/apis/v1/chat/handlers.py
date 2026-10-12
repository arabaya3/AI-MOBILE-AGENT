"""Chat handlers for conversational endpoints."""

from __future__ import annotations

import asyncio
import json
from collections import Counter
from datetime import datetime, timedelta

from fastapi import HTTPException, status
from fastapi.responses import Response, StreamingResponse
from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.observability import tracer
from src.modules.apis.v1.chat.schemas import (
        MessageReactionRequest,
        MessageReactionResponse,
    BranchSessionRequest,
    BranchSessionResponse,
    ChatQueryRequest,
    ChatQueryResponse,
    ChatSessionDetail,
    ChatSessionSummary,
    ConversationMessage,
    UsageEvent,
    UsageSummary,
    UsageSummaryRow,
    UsageInvoice,
    UsageLimits,
    ToolUsageSummary,
)
from src.modules.apis.v1.chat.service import chat_service
from src.modules.apis.v1.documents.service import document_service
from src.services.databases.postgresql.models import ChatSession, LLMUsageEvent, Space, User
from src.services.databases.postgresql.models import ChatMessage, ChatMessageReaction
from src.services.llm_providers.provider import get_chat_provider
from src.core.settings.config import settings
from src.core.settings.logging import logger


async def _sum_tool_requests_since(
    db: AsyncSession,
    *,
    space_id: str,
    user_id: str,
    since: datetime,
    until: datetime,
) -> int:
    stmt = select(LLMUsageEvent).where(
        LLMUsageEvent.space_id == space_id,
        LLMUsageEvent.user_id == user_id,
        LLMUsageEvent.created_at >= since,
        LLMUsageEvent.created_at <= until,
    )
    events = (await db.execute(stmt)).scalars().all()
    totals = _sum_tool_usage(events)
    return int(sum(int(v or 0) for v in totals.values()))


async def _enforce_tool_quota(db: AsyncSession, *, space_id: str, user_id: str, policy: dict) -> None:
    now = datetime.utcnow()
    daily_start = now - timedelta(days=1)
    monthly_start = now - timedelta(days=30)

    daily_limit = policy.get("daily_tool_request_limit")
    monthly_limit = policy.get("monthly_tool_request_limit")

    if daily_limit is None and monthly_limit is None:
        return

    daily_used = await _sum_tool_requests_since(db, space_id=space_id, user_id=user_id, since=daily_start, until=now)
    monthly_used = await _sum_tool_requests_since(db, space_id=space_id, user_id=user_id, since=monthly_start, until=now)

    if daily_limit is not None and int(daily_used) >= int(daily_limit):
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Daily tool request limit reached")
    if monthly_limit is not None and int(monthly_used) >= int(monthly_limit):
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Monthly tool request limit reached")


def _build_followup_web_search_query(message: str, history: list[ChatMessage]) -> str:
    """Improve follow-up searches by incorporating the prior user topic when ambiguous."""
    text = (message or "").strip()
    lowered = text.lower()
    if not text:
        return text

    ambiguous = (
        len(text.split()) <= 10
        and any(t in lowered for t in ("it", "that", "now", "right now", "again"))
        and not any(k in lowered for k in ("bitcoin", "btc", "ethereum", "price", "usd"))
    )
    if not ambiguous:
        return text

    prior_user = None
    for msg in reversed(history[:-1] if history else []):
        if getattr(msg, "role", None) == "user" and (getattr(msg, "content", "") or "").strip():
            prior_user = (msg.content or "").strip()
            break

    return f"{prior_user} (follow-up: {text})" if prior_user else text


async def _ensure_session_trace(db: AsyncSession, *, session: ChatSession, user: User, space_id: str) -> None:
    """Create a stable Langfuse trace for this chat session if missing."""
    if getattr(session, "langfuse_trace_id", None):
        return
    root = tracer.start_trace(
        name=f"chat_session:{session.id}",
        input={"space_id": space_id, "user_id": user.id, "session_id": session.id},
        tags=["chat_session"],
        metadata={"space_id": space_id, "user_id": user.id, "session_id": session.id},
    )
    if root is None:
        return
    session.langfuse_trace_id = getattr(root, "trace_id", None)
    session.langfuse_root_span_id = getattr(root, "id", None)
    tracer.end_span(root)
    await db.flush()


def _bind_chat_turn_span(*, session: ChatSession, user: User, space_id: str, payload: ChatQueryRequest):
    span = tracer.start_trace(
        name="chat_turn",
        trace_id=getattr(session, "langfuse_trace_id", None),
        parent_span_id=getattr(session, "langfuse_root_span_id", None),
        input={
            "space_id": space_id,
            "user_id": user.id,
            "session_id": session.id,
            "message": payload.message,
            "model": payload.model,
            "document_ids": payload.document_ids or [],
            "top_k": payload.top_k,
        },
        tags=["chat"],
        metadata={"space_id": space_id, "user_id": user.id, "session_id": session.id},
    )
    token = tracer.bind_span(span)
    return span, token


async def _get_space_and_member(db: AsyncSession, *, space_id: str, user: User):
    from src.modules.apis.v1.spaces.service import spaces_service

    space = await db.get(Space, space_id)
    if space is None or not space.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Space not found")
    member = await spaces_service.require_active_member(db, space_id=space_id, user=user)
    return space, member


def _effective_policy(space: Space, member) -> dict:
    def _merge_unique(*groups: list[str]) -> list[str]:
        merged: list[str] = []
        seen: set[str] = set()
        for group in groups:
            for raw in (group or []):
                item = str(raw or "").strip()
                if not item or item in seen:
                    continue
                seen.add(item)
                merged.append(item)
        return merged

    defaults_models = list(getattr(settings, "DEFAULT_ALLOWED_MODELS", []) or [])
    defaults_tools = list(getattr(settings, "DEFAULT_ALLOWED_TOOLS", []) or [])

    space_allowed_models = [str(x).strip() for x in (space.allowed_models or []) if str(x).strip()]
    member_allowed_models = (
        [str(x).strip() for x in (member.allowed_models or []) if str(x).strip()]
        if member.allowed_models is not None
        else []
    )
    # Member approvals are additive to space policy so approved requests remain effective.
    allowed_models = _merge_unique(space_allowed_models, member_allowed_models)
    if not allowed_models and defaults_models:
        allowed_models = _merge_unique(defaults_models)

    space_allowed_tools = [str(x).strip() for x in (getattr(space, "allowed_tools", None) or []) if str(x).strip()]
    member_allowed_tools = (
        [str(x).strip() for x in (getattr(member, "allowed_tools", None) or []) if str(x).strip()]
        if getattr(member, "allowed_tools", None) is not None
        else []
    )
    # Keep same precedence for tools: explicit member approvals extend policy.
    allowed_tools = _merge_unique(space_allowed_tools, member_allowed_tools)
    if not allowed_tools and defaults_tools:
        allowed_tools = _merge_unique(defaults_tools)
    return {
        "allowed_models": list(allowed_models or []),
        "allowed_tools": list(allowed_tools or []),
        "daily_token_limit": member.daily_token_limit if member.daily_token_limit is not None else space.daily_token_limit,
        "monthly_token_limit": member.monthly_token_limit if member.monthly_token_limit is not None else space.monthly_token_limit,
        "daily_request_limit": member.daily_request_limit if member.daily_request_limit is not None else space.daily_request_limit,
        "monthly_request_limit": member.monthly_request_limit if member.monthly_request_limit is not None else space.monthly_request_limit,
        "daily_tool_request_limit": getattr(member, "daily_tool_request_limit", None)
        if getattr(member, "daily_tool_request_limit", None) is not None
        else getattr(space, "daily_tool_request_limit", None),
        "monthly_tool_request_limit": getattr(member, "monthly_tool_request_limit", None)
        if getattr(member, "monthly_tool_request_limit", None) is not None
        else getattr(space, "monthly_tool_request_limit", None),
    }


def _sum_tool_usage(events: list[LLMUsageEvent]) -> dict[str, int]:
    totals: dict[str, int] = {}
    for ev in events:
        payload = ev.meta_payload or {}
        tool_usage = payload.get("tools_used") if isinstance(payload, dict) else None
        if not isinstance(tool_usage, dict):
            continue
        for name, count in tool_usage.items():
            try:
                totals[str(name)] = totals.get(str(name), 0) + int(count or 0)
            except Exception:  # noqa: BLE001
                continue
    return totals


def _tool_pricing() -> dict[str, float]:
    pricing = getattr(settings, "TOOL_PRICING", {}) or {}
    if not isinstance(pricing, dict):
        return {}
    return {str(k).strip(): float(v) for k, v in pricing.items() if str(k).strip()}


def _calc_tool_costs(tool_usage: dict[str, int]) -> dict[str, float]:
    pricing = _tool_pricing()
    costs: dict[str, float] = {}
    for tool, count in (tool_usage or {}).items():
        price = pricing.get(tool)
        if price is None:
            continue
        costs[tool] = round(float(count or 0) * float(price), 6)
    return costs


async def _enforce_token_quota(db: AsyncSession, *, space_id: str, user_id: str, policy: dict) -> None:
    now = datetime.utcnow()
    daily_start = now - timedelta(days=1)
    monthly_start = now - timedelta(days=30)

    async def _sum_since(start: datetime):
        stmt = select(
            func.coalesce(func.sum(LLMUsageEvent.request_count), 0),
            func.coalesce(func.sum(LLMUsageEvent.total_tokens), 0),
        ).where(
            LLMUsageEvent.space_id == space_id,
            LLMUsageEvent.user_id == user_id,
            LLMUsageEvent.created_at >= start,
            LLMUsageEvent.created_at <= now,
        )
        return (await db.execute(stmt)).one()

    daily_req, daily_tokens = await _sum_since(daily_start)
    monthly_req, monthly_tokens = await _sum_since(monthly_start)

    # Note: request limits are enforced as conversation creation limits elsewhere.
    _ = daily_req
    _ = monthly_req
    if policy.get("daily_token_limit") is not None and int(daily_tokens) >= int(policy["daily_token_limit"]):
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Daily token limit reached")
    if policy.get("monthly_token_limit") is not None and int(monthly_tokens) >= int(policy["monthly_token_limit"]):
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Monthly token limit reached")


async def _enforce_conversation_quota(db: AsyncSession, *, space_id: str, user_id: str, policy: dict) -> None:
    """Enforce daily/monthly conversation creation limits (sessions created) for the user."""
    now = datetime.utcnow()
    daily_start = now - timedelta(days=1)
    monthly_start = now - timedelta(days=30)

    async def _count_sessions_since(start: datetime) -> int:
        stmt = select(func.count(ChatSession.id)).where(
            ChatSession.space_id == space_id,
            ChatSession.user_id == user_id,
            ChatSession.created_at >= start,
            ChatSession.created_at <= now,
        )
        return int((await db.execute(stmt)).scalar() or 0)

    daily_conversations = await _count_sessions_since(daily_start)
    monthly_conversations = await _count_sessions_since(monthly_start)

    # Use existing request-limit fields as conversation limits (per requirement).
    if policy.get("daily_request_limit") is not None and int(daily_conversations) >= int(policy["daily_request_limit"]):
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Daily conversation limit reached")
    if policy.get("monthly_request_limit") is not None and int(monthly_conversations) >= int(policy["monthly_request_limit"]):
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Monthly conversation limit reached")


async def handle_list_all_models(user: User, db: AsyncSession, *, space_id: str) -> list[str]:
    """Return all available models for server/admin listing, ignoring space policy limits."""
    space, member = await _get_space_and_member(db, space_id=space_id, user=user)
    policy = _effective_policy(space, member)
    # Remote list (chat-capable + priced, per OpenAI account + server settings)
    remote = await get_chat_provider().list_models()

    # Configured options (show everything we support/configure, even if OpenAI listing is unavailable)
    supported = getattr(settings, "SUPPORTED_CHAT_MODELS", []) or []
    supported = [str(x).strip() for x in supported if str(x).strip()]

    catalog = getattr(settings, "CATALOG_CHAT_MODELS", []) or []
    catalog = [str(x).strip() for x in catalog if str(x).strip()]

    pricing = getattr(settings, "MODEL_PRICING", {}) or {}
    priced = [str(k).strip() for k in pricing.keys()] if isinstance(pricing, dict) else []

    aliases = getattr(settings, "MODEL_ALIASES", {}) or {}
    alias_targets: list[str] = []
    if isinstance(aliases, dict):
        alias_targets = [str(v).strip() for v in aliases.values() if str(v).strip()]

    defaults = [getattr(settings, "OPENAI_CHAT_MODEL", "")] if getattr(settings, "OPENAI_CHAT_MODEL", "") else []

    # Keep only chat-capable-looking IDs to avoid clutter.
    candidates = set(remote) | set(supported) | set(catalog) | set(priced) | set(alias_targets) | set(defaults)
    filtered = [m for m in candidates if get_chat_provider()._is_chat_model_id(m)]

    packages = getattr(settings, "MODEL_PACKAGES", []) or []
    packages = [str(x).strip() for x in packages if str(x).strip()]

    # Prefer a stable, readable ordering.
    resolved = sorted(set(filtered + packages))

    # For "all models" admin/request listing, we explicitly ignore space policy limits
    # so users can see what to request.
    return resolved


async def handle_list_model_pricing(user: User, db: AsyncSession, *, space_id: str) -> dict:
    """Return model pricing and aliases for UI display."""
    await _get_space_and_member(db, space_id=space_id, user=user)
    pricing = getattr(settings, "MODEL_PRICING", {}) or {}
    aliases = getattr(settings, "MODEL_ALIASES", {}) or {}
    if not isinstance(pricing, dict):
        pricing = {}
    if not isinstance(aliases, dict):
        aliases = {}
    normalized_pricing = {
        str(k).strip(): {"input": float(v.get("input", 0.0)), "output": float(v.get("output", 0.0))}
        for k, v in pricing.items()
        if isinstance(v, dict) and str(k).strip()
    }
    normalized_aliases = {str(k).strip(): str(v).strip() for k, v in aliases.items() if str(k).strip()}
    return {"pricing": normalized_pricing, "aliases": normalized_aliases}


def _is_package_token(token: str) -> bool:
    token_norm = (token or "").strip().lower()
    if not token_norm:
        return False
    built_in_packages = {"openai", "anthropic", "claude", "gemini", "deepseek", "qwen"}
    packages = getattr(settings, "MODEL_PACKAGES", []) or []
    packages = [str(x).strip().lower() for x in packages if str(x).strip()]
    return token_norm in built_in_packages or token_norm in packages or token_norm.endswith("/*")


def _model_matches_package(model_id: str, package_token: str) -> bool:
    mid = (model_id or "").strip().lower()
    token = (package_token or "").strip().lower()
    if not mid or not token:
        return False
    if token.endswith("/*"):
        token = token[:-2]

    if token == "openai":
        return mid.startswith(("gpt-", "o1-", "o3-", "o4-", "o1", "o3", "o4", "chatgpt-"))
    if token in {"anthropic", "claude"}:
        return mid.startswith(("claude", "anthropic"))

    return mid.startswith(token)


def _is_openai_compatible_model(model_id: str | None) -> bool:
    mid = (model_id or "").strip()
    if not mid:
        return True
    if _is_package_token(mid):
        return False
    return get_chat_provider()._is_chat_model_id(mid)


def _model_allowed_by_policy(model_id: str, allowed_models: list[str]) -> bool:
    if model_id in allowed_models:
        return True
    for token in allowed_models:
        if _is_package_token(token) and _model_matches_package(model_id, token):
            return True
    return False


def _pick_default_allowed_model(allowed_models: list[str]) -> str | None:
    for model_id in allowed_models:
        if model_id and not _is_package_token(model_id):
            return model_id

    defaults = getattr(settings, "MODEL_PACKAGE_DEFAULTS", {}) or {}
    if isinstance(defaults, dict):
        for token in allowed_models:
            key = (token or "").strip()
            if key in defaults:
                return str(defaults[key])
    return None


def _resolve_package_model(token: str) -> str | None:
    defaults = getattr(settings, "MODEL_PACKAGE_DEFAULTS", {}) or {}
    if not isinstance(defaults, dict):
        return None
    key = (token or "").strip()
    return str(defaults.get(key)) if key in defaults else None


def _pick_web_search_tool(message: str, allowed_tools: list[str]) -> str:
    """Always use Tavily for web search."""
    allowed = set(t for t in (allowed_tools or []) if t)
    if "web_search_tavily" in allowed:
        return "web_search_tavily"
    return "web_search_tavily"


async def _execute_web_search_with_fallback(
    message: str,
    *,
    allowed_tools: list[str],
    num_results: int,
) -> tuple[str, dict]:
    """Execute web search using Tavily.

    Returns (tool_name_used, tool_result)
    """
    from src.services.tools.executor import tool_executor

    tool_name = _pick_web_search_tool(message, allowed_tools)
    if not isinstance(tool_name, str) or not tool_name:
        logger.error("Web search tool selection failed", extra={"tool": tool_name})
        return "web_search_tavily", {"success": False, "error": "Web search tool is not configured"}
    
    tool_result = await tool_executor.execute_tool_call(
        tool_name,
        {"query": message, "num_results": num_results},
    )
    return tool_name, tool_result


def _is_web_search_rate_limited(result: dict) -> bool:
    """Check if web search result indicates rate limiting."""
    if not isinstance(result, dict):
        return False
    error = result.get("error") or ""
    return "rate limit" in str(error).lower() or "ratelimit" in str(error).lower()


def _format_web_search_results(result: dict) -> str:
    if not result.get("success"):
        return f"Web search failed: {result.get('error') or 'Unknown error'}"
    items = result.get("results") or []
    if not items:
        return "No web results found."
    lines = ["Web search results:"]
    for item in items[:8]:
        title = (item.get("title") or "Untitled").strip()
        url = (item.get("url") or "").strip()
        snippet = (item.get("snippet") or "").strip()
        if url:
            lines.append(f"- {title} — {url}")
        else:
            lines.append(f"- {title}")
        if snippet:
            lines.append(f"  {snippet}")
    return "\n".join(lines).strip()


def _looks_exhaustive(message: str) -> bool:
    text = (message or "").lower()
    triggers = [
        "list all",
        "all the",
        "all of the",
        "every",
        "enumerate",
        "full list",
        "list every",
        "links",
        "emails",
        "email",
    ]
    return any(t in text for t in triggers)


def _looks_doc_wide_summary(message: str) -> bool:
    text = (message or "").lower().strip()
    triggers = [
        "summarize",
        "summary",
        "tell me all the details",
        "all details",
        "full details",
        "in detail",
    ]
    return any(t in text for t in triggers)


def _is_prompt_enhancement_request(message: str) -> bool:
    text = (message or "").strip().lower()
    if not text:
        return False
    return text.startswith("you are a prompt engineering expert") or "enhance the following user prompt" in text


def _infer_single_document_id(contexts: list[dict]) -> str | None:
    doc_ids = [c.get("document_id") for c in contexts if c.get("document_id")]
    if not doc_ids:
        return None
    counts = Counter(doc_ids)
    doc_id, count = counts.most_common(1)[0]
    if count >= min(5, len(doc_ids)):
        return str(doc_id)
    return None


async def _load_ordered_document_contexts(
    db: AsyncSession,
    *,
    document_id: str,
    limit: int,
) -> list[dict]:
    doc = await document_service.get_document(db, document_id)
    if doc is None:
        return []
    chunks = await document_service.get_document_chunks(db, document_id)
    results: list[dict] = []
    for item in (chunks or [])[:limit]:
        results.append(
            {
                "chunk_id": item.get("chunk_id") or f"{document_id}:{item.get('chunk_index', 0)}",
                "score": 1.0,
                "document_id": document_id,
                "filename": doc.filename,
                "file_type": doc.file_type,
                "chunk_index": item.get("chunk_index", 0),
                "text": item.get("text", ""),
                "metadata": item.get("metadata", {}) or {},
            }
        )
    return results


async def handle_chat_query(
    payload: ChatQueryRequest,
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
) -> ChatQueryResponse:
    """Persist a chat turn, run retrieval, and return the assistant reply."""

    space, member = await _get_space_and_member(db, space_id=space_id, user=user)
    policy = _effective_policy(space, member)
    await _enforce_token_quota(db, space_id=space_id, user_id=user.id, policy=policy)
    if payload.session_id is None:
        await _enforce_conversation_quota(db, space_id=space_id, user_id=user.id, policy=policy)

    allowed_models: list[str] = policy.get("allowed_models") or []
    selected_model = payload.model or get_chat_provider().model
    is_prompt_enhancement = _is_prompt_enhancement_request(payload.message)
    if payload.model and _is_package_token(payload.model):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Select a concrete model ID")
    if allowed_models:
        if payload.model and not _model_allowed_by_policy(payload.model, allowed_models):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Model not allowed in this space")
        if not _model_allowed_by_policy(selected_model, allowed_models):
            if getattr(settings, "STRICT_MODEL_SELECTION", True):
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Select an allowed model")
            selected_model = _pick_default_allowed_model(allowed_models) or selected_model

    if not _is_openai_compatible_model(selected_model):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Selected model is not supported by this deployment.",
        )

    logger.info(
        "Chat model resolved",
        extra={
            "space_id": space_id,
            "user_id": user.id,
            "session_id": payload.session_id,
            "model": selected_model,
        },
    )

    allowed_tools: list[str] = policy.get("allowed_tools") or []
    allowed_tools: list[str] = policy.get("allowed_tools") or []
    if is_prompt_enhancement:
        allowed_tools = []
    if user.role not in ("admin", "super_admin"):
        allowed_tools = [t for t in allowed_tools if t != "usage_query"]

    if allowed_tools:
        await _enforce_tool_quota(db, space_id=space_id, user_id=user.id, policy=policy)

    try:
        session = await chat_service.get_or_create_session(
            db,
            user_id=user.id,
            space_id=space_id,
            session_id=payload.session_id,
        )
    except PermissionError as exc:  # noqa: PERF203 (explicit message helpful)
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc

    await _ensure_session_trace(db, session=session, user=user, space_id=space_id)
    turn_span, turn_token = _bind_chat_turn_span(session=session, user=user, space_id=space_id, payload=payload)
    try:
        accessible_docs = await document_service.list_accessible_documents(db, user, space_id=space_id)
        allowed_ids = {doc.id for doc in accessible_docs}
        document_filter = None
        if payload.document_ids:
            invalid = set(payload.document_ids) - allowed_ids
            if invalid and user.role != "admin":
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Document access denied")
            document_filter = payload.document_ids
        elif user.role != "admin":
            document_filter = list(allowed_ids)

        await chat_service.append_message(
            db,
            session=session,
            role="user",
            content=payload.message,
            meta_payload={"document_ids": payload.document_ids or []},
        )

        history = await chat_service.get_history(db, session_id=session.id)

        contexts: list[dict] = []
        if not is_prompt_enhancement:
            effective_top_k = payload.top_k
            if _looks_exhaustive(payload.message):
                effective_top_k = min(30, max(effective_top_k, 20))

            summary_mode = _looks_doc_wide_summary(payload.message)

            selected_doc_id = None
            if payload.document_ids and len(payload.document_ids) == 1:
                selected_doc_id = payload.document_ids[0]

            if summary_mode and selected_doc_id:
                contexts = await _load_ordered_document_contexts(db, document_id=selected_doc_id, limit=effective_top_k)
            else:
                search_payload = await document_service.search_vectors(
                    payload.message,
                    effective_top_k,
                    allowed_document_ids=document_filter,
                    generate_answer=False,
                    space_id=space_id,
                )
                contexts = search_payload.get("results", [])
                if summary_mode and not selected_doc_id:
                    inferred = _infer_single_document_id(contexts)
                    if inferred:
                        contexts = await _load_ordered_document_contexts(db, document_id=inferred, limit=effective_top_k)

        # Normalize web tools: if legacy "web_search" is allowed, treat it as Tavily
        normalized_web = []
        for t in (allowed_tools or []):
            if t == "web_search_tavily":
                normalized_web.append("web_search_tavily")
            elif t == "web_search":
                normalized_web.append("web_search_tavily")
        web_tools = normalized_web
        if web_tools:
            decision = await get_chat_provider().decide_web_search(
                question=payload.message,
                has_context=bool(contexts),
                available_tools=web_tools,
                model=selected_model,
            )
            if decision.get("use_web_search"):
                query = decision.get("query") or _build_followup_web_search_query(payload.message, history)
                tool_name, tool_result = await _execute_web_search_with_fallback(
                    query,
                    allowed_tools=allowed_tools,
                    num_results=6,
                )
                reply = _format_web_search_results(tool_result)
                await chat_service.append_message(
                    db,
                    session=session,
                    role="assistant",
                    content=reply,
                    meta_payload={"source_count": 0, "web_search": True, "web_search_query": query},
                )
                updated_history = await chat_service.get_history(db, session_id=session.id)
                await chat_service.record_usage_event(
                    db,
                    space_id=space_id,
                    user_id=user.id,
                    session_id=session.id,
                    endpoint="chat.query",
                    model=selected_model,
                    usage_details=None,
                    cost_usd=None,
                    meta_payload={"source_count": 0, "web_search": True, "web_search_query": query},
                    tool_usage={tool_name: 1} if tool_name else None,
                )
                return ChatQueryResponse(
                    session_id=session.id,
                    reply=reply,
                    sources=[],
                    history=[ConversationMessage.model_validate(item) for item in updated_history],
                )

        tool_usage_sink: dict[str, int] = {}
        usage_sink: dict[str, int] = {}
        reply = await chat_service.generate_reply(
            message=payload.message,
            history=history,
            contexts=contexts,
            model=selected_model,
            allowed_tools=allowed_tools,
            tool_usage_sink=tool_usage_sink,
            usage_sink=usage_sink,
        )

        await chat_service.append_message(
            db,
            session=session,
            role="assistant",
            content=reply,
            meta_payload={"source_count": len(contexts)},
        )

        updated_history = await chat_service.get_history(db, session_id=session.id)

        cost_details = tracer.estimate_cost(selected_model, usage_sink) if usage_sink else {}
        cost_usd = float(cost_details.get("total_cost_usd")) if cost_details and cost_details.get("total_cost_usd") is not None else None
        await chat_service.record_usage_event(
            db,
            space_id=space_id,
            user_id=user.id,
            session_id=session.id,
            endpoint="chat.query",
            model=selected_model,
            usage_details=usage_sink or None,
            cost_usd=cost_usd,
            meta_payload={"source_count": len(contexts)},
            tool_usage=tool_usage_sink or None,
        )

        return ChatQueryResponse(
            session_id=session.id,
            reply=reply,
            sources=contexts,
            history=[ConversationMessage.model_validate(item) for item in updated_history],
        )
    finally:
        tracer.end_span(turn_span)
        tracer.reset_context(turn_token)


async def handle_list_models(user: User, db: AsyncSession, *, space_id: str) -> list[str]:
    """Return available OpenAI models for the authenticated user filtered by space policy."""
    space, member = await _get_space_and_member(db, space_id=space_id, user=user)
    policy = _effective_policy(space, member)
    allowed = policy.get("allowed_models") or []

    models = await get_chat_provider().list_models()

    # If no policy restrictions, return all available models
    if not allowed:
        # If OpenAI returns nothing, fallback to configured supported models
        if not models:
            supported = getattr(settings, "SUPPORTED_CHAT_MODELS", []) or []
            return supported if supported else ["gpt-5-nano", "gpt-4o", "gpt-4o-mini"]
        return models

    # Policy is explicit: return allowed models, expanding package tokens into concrete model IDs.
    # Keep package tokens visible so users can select a provider family if desired.
    expanded: set[str] = set()
    # Use the broader catalog list to expand package tokens, excluding package tokens.
    all_models = await handle_list_all_models(user, db, space_id=space_id)
    concrete_models = [m for m in all_models if not _is_package_token(m)]
    package_defaults = getattr(settings, "MODEL_PACKAGE_DEFAULTS", {}) or {}
    for token in allowed:
        if not token:
            continue
        if _is_package_token(token):
            matches = [m for m in concrete_models if _model_matches_package(m, token)]
            if matches:
                expanded.update(matches)
            else:
                default_model = package_defaults.get(str(token).strip())
                if default_model:
                    expanded.add(str(default_model))
        else:
            expanded.add(token)

    deduped: list[str] = []
    seen: set[str] = set()
    for model_id in expanded:
        if not model_id or model_id in seen:
            continue
        seen.add(model_id)
        deduped.append(model_id)
    return sorted(deduped)


PROVIDER_ERROR_MARKER = "[stream_error]"


def _sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


def _sse_error(detail: str, code: str, **extra) -> str:
    """Terminal SSE error. `detail` stays for existing clients; `code` is machine-readable."""
    return _sse("error", {"detail": detail, "code": code, **extra})


def _sse_done(session_id: str, user_message_id: str, message_id: str) -> str:
    return _sse("done", {"session_id": session_id, "user_message_id": user_message_id, "message_id": message_id})


async def handle_chat_query_stream(
    payload: ChatQueryRequest,
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
) -> StreamingResponse:
    """Stream a chat reply via Server-Sent Events (SSE)."""

    async def _event_stream():
        turn_span = None
        turn_token = None
        try:
            space, member = await _get_space_and_member(db, space_id=space_id, user=user)
            policy = _effective_policy(space, member)
            await _enforce_token_quota(db, space_id=space_id, user_id=user.id, policy=policy)
            if payload.session_id is None:
                await _enforce_conversation_quota(db, space_id=space_id, user_id=user.id, policy=policy)

            allowed_models: list[str] = policy.get("allowed_models") or []
            selected_model = payload.model or get_chat_provider().model
            is_prompt_enhancement = _is_prompt_enhancement_request(payload.message)
            if payload.model and _is_package_token(payload.model):
                yield _sse_error("Select a concrete model ID", "policy")
                return
            if allowed_models:
                if payload.model and not _model_allowed_by_policy(payload.model, allowed_models):
                    yield _sse_error("Model not allowed in this space", "policy")
                    return
                if not _model_allowed_by_policy(selected_model, allowed_models):
                    if getattr(settings, "STRICT_MODEL_SELECTION", True):
                        yield _sse_error("Select an allowed model", "policy")
                        return
                    selected_model = _pick_default_allowed_model(allowed_models) or selected_model

            if not _is_openai_compatible_model(selected_model):
                yield _sse_error("Selected model is not supported by this deployment.", "policy")
                return

            logger.info(
                "Chat model resolved (stream)",
                extra={
                    "space_id": space_id,
                    "user_id": user.id,
                    "session_id": payload.session_id,
                    "model": selected_model,
                },
            )

            try:
                session = await chat_service.get_or_create_session(
                    db,
                    user_id=user.id,
                    space_id=space_id,
                    session_id=payload.session_id,
                )
            except PermissionError as exc:  # noqa: PERF203
                yield _sse_error(str(exc), "session_not_found")
                return

            await _ensure_session_trace(db, session=session, user=user, space_id=space_id)
            turn_span, turn_token = _bind_chat_turn_span(session=session, user=user, space_id=space_id, payload=payload)

            accessible_docs = await document_service.list_accessible_documents(db, user, space_id=space_id)
            allowed_ids = {doc.id for doc in accessible_docs}

            document_filter = None
            if payload.document_ids:
                invalid = set(payload.document_ids) - allowed_ids
                if invalid:
                    yield _sse_error("Document access denied", "document_access_denied")
                    return
                document_filter = payload.document_ids
            else:
                document_filter = list(allowed_ids)

            user_message = await chat_service.append_message(
                db,
                session=session,
                role="user",
                content=payload.message,
                meta_payload={"document_ids": payload.document_ids or [], "model": payload.model},
            )
            await db.commit()

            history = await chat_service.get_history(db, session_id=session.id)

            allowed_tools: list[str] = policy.get("allowed_tools") or []
            if is_prompt_enhancement:
                allowed_tools = []
            if user.role not in ("admin", "super_admin"):
                allowed_tools = [t for t in allowed_tools if t != "usage_query"]
            if allowed_tools:
                try:
                    await _enforce_tool_quota(db, space_id=space_id, user_id=user.id, policy=policy)
                except HTTPException as exc:
                    yield _sse_error(str(exc.detail), "quota_exceeded")
                    return
            contexts: list[dict] = []
            # With no accessible documents retrieval is always empty; skip the embedding call.
            if not is_prompt_enhancement and document_filter:
                effective_top_k = payload.top_k
                if _looks_exhaustive(payload.message):
                    effective_top_k = min(30, max(effective_top_k, 20))

                summary_mode = _looks_doc_wide_summary(payload.message)

                selected_doc_id = None
                if payload.document_ids and len(payload.document_ids) == 1:
                    selected_doc_id = payload.document_ids[0]

                if summary_mode and selected_doc_id:
                    contexts = await _load_ordered_document_contexts(db, document_id=selected_doc_id, limit=effective_top_k)
                else:
                    search_payload = await document_service.search_vectors(
                        payload.message,
                        effective_top_k,
                        allowed_document_ids=document_filter,
                        generate_answer=False,
                        space_id=space_id,
                    )
                    contexts = search_payload.get("results", [])
                    if summary_mode and not selected_doc_id:
                        inferred = _infer_single_document_id(contexts)
                        if inferred:
                            contexts = await _load_ordered_document_contexts(db, document_id=inferred, limit=effective_top_k)

            # Normalize web tools: if legacy "web_search" is allowed, treat it as Tavily
            normalized_web = []
            for t in (allowed_tools or []):
                if t == "web_search_tavily":
                    normalized_web.append("web_search_tavily")
                elif t == "web_search":
                    normalized_web.append("web_search_tavily")
            web_tools = normalized_web
            if web_tools:
                decision = await get_chat_provider().decide_web_search(
                    question=payload.message,
                    has_context=bool(contexts),
                    available_tools=web_tools,
                    model=selected_model,
                )
                if decision.get("use_web_search"):
                    query = decision.get("query") or _build_followup_web_search_query(payload.message, history)
                    tool_name, tool_result = await _execute_web_search_with_fallback(
                        query,
                        allowed_tools=allowed_tools,
                        num_results=6,
                    )
                    reply = _format_web_search_results(tool_result)
                    meta = {"session_id": session.id, "user_message_id": user_message.id, "sources": []}
                    yield f"event: meta\ndata: {json.dumps(meta, ensure_ascii=False)}\n\n"
                    yield f"event: delta\ndata: {json.dumps({'text': reply}, ensure_ascii=False)}\n\n"
                    assistant_message = await chat_service.append_message(
                        db,
                        session=session,
                        role="assistant",
                        content=reply,
                        meta_payload={"source_count": 0, "web_search": True, "web_search_query": query},
                    )
                    await chat_service.record_usage_event(
                        db,
                        space_id=space_id,
                        user_id=user.id,
                        session_id=session.id,
                        endpoint="chat.query.stream",
                        model=selected_model,
                        usage_details=None,
                        cost_usd=None,
                        meta_payload={"source_count": 0, "web_search": True, "web_search_query": query},
                        tool_usage={tool_name: 1} if tool_name else None,
                    )
                    await db.commit()
                    yield _sse_done(session.id, user_message.id, assistant_message.id)
                    return

            meta = {"session_id": session.id, "user_message_id": user_message.id, "sources": contexts}
            yield f"event: meta\ndata: {json.dumps(meta, ensure_ascii=False)}\n\n"

            collected: list[str] = []
            usage_sink: dict[str, int] = {}
            provider_error: str | None = None
            async for delta in get_chat_provider().stream_with_memory(
                history=[{"role": item.role, "content": item.content} for item in history],
                question=payload.message,
                contexts=contexts,
                model=selected_model,
                usage_sink=usage_sink,
                user_industry=getattr(payload, "user_industry", None),
                user_language=getattr(payload, "user_language", None),
            ):
                if PROVIDER_ERROR_MARKER in delta:
                    # The provider reports failures in-band; never stream or store them as an answer.
                    before, _, provider_error = delta.partition(PROVIDER_ERROR_MARKER)
                    if before.strip():
                        collected.append(before)
                        yield _sse("delta", {"text": before})
                    break
                collected.append(delta)
                yield _sse("delta", {"text": delta})

            reply = "".join(collected).strip()
            if provider_error is not None:
                logger.warning(
                    "Chat provider failed during stream",
                    extra={"session_id": session.id, "model": selected_model, "partial": bool(reply)},
                )
                await chat_service.record_usage_event(
                    db,
                    space_id=space_id,
                    user_id=user.id,
                    session_id=session.id,
                    endpoint="chat.query.stream",
                    model=selected_model,
                    usage_details=usage_sink,
                    cost_usd=None,
                    meta_payload={"source_count": len(contexts), "provider_error": True},
                )
                await db.commit()
                yield _sse_error(
                    "The model provider could not complete the reply.",
                    "provider_error",
                    partial=bool(reply),
                )
                return

            assistant_message = await chat_service.append_message(
                db,
                session=session,
                role="assistant",
                content=reply,
                meta_payload={"source_count": len(contexts), "model": payload.model},
            )
            cost_details = tracer.estimate_cost(selected_model, usage_sink) if usage_sink else {}
            await chat_service.record_usage_event(
                db,
                space_id=space_id,
                user_id=user.id,
                session_id=session.id,
                endpoint="chat.query.stream",
                model=selected_model,
                usage_details=usage_sink,
                cost_usd=cost_details.get("total_cost_usd") if cost_details else None,
                meta_payload={"source_count": len(contexts)},
            )
            await db.commit()

            yield _sse_done(session.id, user_message.id, assistant_message.id)
            return
        except asyncio.CancelledError:
            await db.rollback()
            raise
        except HTTPException as exc:
            await db.rollback()
            code = {429: "quota_exceeded", 403: "forbidden", 404: "not_found"}.get(exc.status_code, "request_failed")
            yield _sse_error(str(exc.detail), code)
            return
        except Exception:
            await db.rollback()
            logger.exception("Chat stream failed", extra={"space_id": space_id, "user_id": user.id})
            yield _sse_error("The reply could not be completed.", "internal")
            return
        finally:
            tracer.end_span(turn_span)
            tracer.reset_context(turn_token)
            await db.close()

    return StreamingResponse(_event_stream(), media_type="text/event-stream")


async def handle_list_sessions(user: User, db: AsyncSession, *, space_id: str) -> list[ChatSessionSummary]:
    """Return all chat sessions for the caller sorted by recency."""
    await _get_space_and_member(db, space_id=space_id, user=user)
    sessions = await chat_service.list_sessions(db, user.id, space_id=space_id)
    return [ChatSessionSummary.model_validate(session) for session in sessions]


async def handle_get_session(
    session_id: str,
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
) -> ChatSessionDetail:
    """Return session metadata plus full history if permitted."""

    session = await chat_service.get_session(db, session_id)
    if session is None or session.user_id != user.id or session.space_id != space_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    history = await chat_service.get_history(db, session_id=session_id)
    return ChatSessionDetail(
        session=ChatSessionSummary.model_validate(session),
        history=[ConversationMessage.model_validate(item) for item in history],
    )


async def handle_branch_session(
    session_id: str,
    payload: BranchSessionRequest,
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
) -> BranchSessionResponse:
    try:
        await _get_space_and_member(db, space_id=space_id, user=user)
        new_session = await chat_service.branch_session(
            db,
            user_id=user.id,
            session_id=session_id,
            from_message_id=payload.from_message_id,
        )
        await db.commit()
        if new_session.space_id != space_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
        return BranchSessionResponse(session_id=new_session.id)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


async def handle_export_session(
    session_id: str,
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
    format: str = "json",
) -> Response:
    session = await chat_service.get_session(db, session_id)
    if session is None or session.user_id != user.id or session.space_id != space_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    history = await chat_service.get_history(db, session_id=session_id)

    fmt = (format or "json").lower().strip()
    if fmt == "md" or fmt == "markdown":
        body = chat_service.export_as_markdown(history)
        return Response(content=body, media_type="text/markdown")

    # default: json
    export_payload = {
        "session": ChatSessionSummary.model_validate(session).model_dump(mode="json"),
        "history": [ConversationMessage.model_validate(item).model_dump(mode="json") for item in history],
    }
    return Response(content=json.dumps(export_payload, ensure_ascii=False, indent=2), media_type="application/json")


async def handle_message_reaction(
    message_id: str,
    payload: MessageReactionRequest,
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
) -> MessageReactionResponse:
    reaction = (payload.reaction or "").strip().lower()
    if reaction not in {"up", "down"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid reaction")

    message = await db.get(ChatMessage, message_id)
    if message is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")

    session = await chat_service.get_session(db, message.session_id)
    if session is None or session.user_id != user.id or session.space_id != space_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")

    stmt = select(ChatMessageReaction).where(
        ChatMessageReaction.user_id == user.id,
        ChatMessageReaction.message_id == message_id,
    )
    existing = (await db.execute(stmt)).scalars().first()
    if existing is None:
        db.add(
            ChatMessageReaction(
                user_id=user.id,
                message_id=message_id,
                reaction=reaction,
            )
        )
    else:
        existing.reaction = reaction

    await db.commit()
    return MessageReactionResponse(success=True)


async def handle_get_session_summary(
    session_id: str,
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
) -> dict:
    """Generate an executive summary of the conversation using LLM."""

    session = await chat_service.get_session(db, session_id)
    if session is None or session.user_id != user.id or session.space_id != space_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    
    history = await chat_service.get_history(db, session_id=session_id)
    if not history:
        return {"summary": "No conversation history to summarize."}

    # Build a bounded transcript to avoid model context-length failures.
    # Keep the most recent turns and cap per-message size.
    tail = history[-40:]
    transcript_lines: list[str] = []
    for msg in tail:
        content = (msg.content or "").strip()
        if not content:
            continue
        transcript_lines.append(f"{msg.role}: {content[:4000]}")
    transcript = "\n".join(transcript_lines)
    
    usage_sink: dict[str, int] = {}
    try:
        # Summarize from the transcript. We disable tool-calling here because
        # summary generation should not trigger web search or other tools.
        summary = await get_chat_provider().answer_with_memory(
            history=[],
            question=(
                "Write a clear executive summary of the conversation transcript.\n"
                "Requirements:\n"
                "- Use Markdown with headings and bullets.\n"
                "- Include these sections exactly:\n"
                "  1) Overview\n"
                "  2) What Was Built/Changed\n"
                "  3) Current Issues (if any)\n"
                "  4) Next Steps\n"
                "- Do NOT dump raw extracted emails/links unless explicitly requested.\n"
                "- If the transcript contains technical logs/errors, summarize them and explain briefly.\n"
                "- If details are missing, say so plainly."
            ),
            contexts=[{"text": transcript, "filename": "Conversation"}],
            usage_sink=usage_sink,
            enable_tools=False,
        )
    except Exception as exc:
        logger.exception(
            "Failed to generate session summary",
            extra={"session_id": session_id, "space_id": space_id, "user_id": user.id},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate summary: {str(exc)}",
        ) from exc

    selected_model = get_chat_provider().model
    cost_details = tracer.estimate_cost(selected_model, usage_sink) if usage_sink else {}
    await chat_service.record_usage_event(
        db,
        space_id=space_id,
        user_id=user.id,
        session_id=session_id,
        endpoint="chat.summary",
        model=selected_model,
        usage_details=usage_sink,
        cost_usd=cost_details.get("total_cost_usd") if cost_details else None,
        meta_payload={"message_count": len(history)},
    )
    
    return {
        "session_id": session_id,
        "summary": summary,
        "message_count": len(history),
    }


async def handle_list_usage_events(
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
    limit: int = 100,
    session_id: str | None = None,
) -> list[UsageEvent]:
    await _get_space_and_member(db, space_id=space_id, user=user)
    stmt = select(LLMUsageEvent).where(LLMUsageEvent.user_id == user.id, LLMUsageEvent.space_id == space_id)
    if session_id:
        stmt = stmt.where(LLMUsageEvent.session_id == session_id)
    stmt = stmt.order_by(desc(LLMUsageEvent.created_at)).limit(min(max(limit, 1), 500))
    result = await db.execute(stmt)
    rows = result.scalars().all()
    return [UsageEvent.model_validate(row) for row in rows]


async def handle_usage_summary(
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
    days: int = 30,
    session_id: str | None = None,
) -> UsageSummary:
    await _get_space_and_member(db, space_id=space_id, user=user)
    end = datetime.utcnow()
    start = end - timedelta(days=min(max(days, 1), 365))
    stmt = select(LLMUsageEvent).where(
        LLMUsageEvent.user_id == user.id,
        LLMUsageEvent.space_id == space_id,
        LLMUsageEvent.created_at >= start,
        LLMUsageEvent.created_at <= end,
    )
    if session_id:
        stmt = stmt.where(LLMUsageEvent.session_id == session_id)
    stmt = stmt.order_by(desc(LLMUsageEvent.created_at))
    result = await db.execute(stmt)
    events = result.scalars().all()

    totals = {
        "requests": 0,
        "input_tokens": 0,
        "output_tokens": 0,
        "total_tokens": 0,
        "cost_usd": 0.0,
        "has_cost": False,
    }
    by_model: dict[str, dict] = {}

    for ev in events:
        totals["requests"] += int(ev.request_count or 0)
        totals["input_tokens"] += int(ev.input_tokens or 0)
        totals["output_tokens"] += int(ev.output_tokens or 0)
        totals["total_tokens"] += int(ev.total_tokens or 0)
        if ev.cost_usd is not None:
            totals["cost_usd"] += float(ev.cost_usd)
            totals["has_cost"] = True

        model = ev.model or "unknown"
        bucket = by_model.setdefault(
            model,
            {
                "requests": 0,
                "input_tokens": 0,
                "output_tokens": 0,
                "total_tokens": 0,
                "cost_usd": 0.0,
                "has_cost": False,
            },
        )
        bucket["requests"] += int(ev.request_count or 0)
        bucket["input_tokens"] += int(ev.input_tokens or 0)
        bucket["output_tokens"] += int(ev.output_tokens or 0)
        bucket["total_tokens"] += int(ev.total_tokens or 0)
        if ev.cost_usd is not None:
            bucket["cost_usd"] += float(ev.cost_usd)
            bucket["has_cost"] = True

    by_model_rows = [
        UsageSummaryRow(
            model=model,
            requests=data.get("requests", 0),
            input_tokens=data["input_tokens"],
            output_tokens=data["output_tokens"],
            total_tokens=data["total_tokens"],
            cost_usd=round(data["cost_usd"], 6) if data.get("has_cost") else None,
        )
        for model, data in sorted(by_model.items(), key=lambda kv: (kv[0] != "unknown", kv[0]))
    ]

    return UsageSummary(
        start=start,
        end=end,
        total_requests=totals["requests"],
        total_input_tokens=totals["input_tokens"],
        total_output_tokens=totals["output_tokens"],
        total_tokens=totals["total_tokens"],
        total_cost_usd=round(totals["cost_usd"], 6) if totals.get("has_cost") else None,
        by_model=by_model_rows,
    )


async def handle_usage_invoice(
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
    days: int = 30,
) -> UsageInvoice:
    space, member = await _get_space_and_member(db, space_id=space_id, user=user)
    policy = _effective_policy(space, member)

    end = datetime.utcnow()
    start = end - timedelta(days=min(max(days, 1), 365))

    stmt = select(LLMUsageEvent).where(
        LLMUsageEvent.user_id == user.id,
        LLMUsageEvent.space_id == space_id,
        LLMUsageEvent.created_at >= start,
        LLMUsageEvent.created_at <= end,
    )
    result = await db.execute(stmt)
    events = result.scalars().all()

    totals = {
        "requests": 0,
        "input_tokens": 0,
        "output_tokens": 0,
        "total_tokens": 0,
        "cost_usd": 0.0,
        "has_cost": False,
    }
    by_model: dict[str, dict] = {}

    for ev in events:
        totals["requests"] += int(ev.request_count or 0)
        totals["input_tokens"] += int(ev.input_tokens or 0)
        totals["output_tokens"] += int(ev.output_tokens or 0)
        totals["total_tokens"] += int(ev.total_tokens or 0)
        if ev.cost_usd is not None:
            totals["cost_usd"] += float(ev.cost_usd)
            totals["has_cost"] = True

        model = ev.model or "unknown"
        bucket = by_model.setdefault(
            model,
            {
                "requests": 0,
                "input_tokens": 0,
                "output_tokens": 0,
                "total_tokens": 0,
                "cost_usd": 0.0,
                "has_cost": False,
            },
        )
        bucket["requests"] += int(ev.request_count or 0)
        bucket["input_tokens"] += int(ev.input_tokens or 0)
        bucket["output_tokens"] += int(ev.output_tokens or 0)
        bucket["total_tokens"] += int(ev.total_tokens or 0)
        if ev.cost_usd is not None:
            bucket["cost_usd"] += float(ev.cost_usd)
            bucket["has_cost"] = True

    by_model_rows = [
        UsageSummaryRow(
            model=model,
            requests=data.get("requests", 0),
            input_tokens=data["input_tokens"],
            output_tokens=data["output_tokens"],
            total_tokens=data["total_tokens"],
            cost_usd=round(data["cost_usd"], 6) if data.get("has_cost") else None,
        )
        for model, data in sorted(by_model.items(), key=lambda kv: (kv[0] != "unknown", kv[0]))
    ]

    tool_usage_totals = _sum_tool_usage(events)
    tool_costs = _calc_tool_costs(tool_usage_totals)
    total_tool_cost = round(sum(tool_costs.values()), 6) if tool_costs else 0.0
    if total_tool_cost > 0:
        totals["cost_usd"] += total_tool_cost
        totals["has_cost"] = True
    tool_usage_rows = [
        ToolUsageSummary(tool=name, requests=count, cost_usd=tool_costs.get(name))
        for name, count in sorted(tool_usage_totals.items(), key=lambda kv: kv[0])
    ]

    # Daily window for alerting
    daily_start = end - timedelta(days=1)
    daily_stmt = select(LLMUsageEvent).where(
        LLMUsageEvent.user_id == user.id,
        LLMUsageEvent.space_id == space_id,
        LLMUsageEvent.created_at >= daily_start,
        LLMUsageEvent.created_at <= end,
    )
    daily_events = (await db.execute(daily_stmt)).scalars().all()
    daily_tool_usage = _sum_tool_usage(daily_events)
    daily_totals = {
        "requests": sum(int(ev.request_count or 0) for ev in daily_events),
        "total_tokens": sum(int(ev.total_tokens or 0) for ev in daily_events),
        "tool_requests": sum(int(v or 0) for v in daily_tool_usage.values()),
    }

    alerts: list[str] = []

    def _check_limit(label: str, used: int, limit: int | None, period: str) -> None:
        if limit is None or limit <= 0:
            return
        if used >= limit:
            alerts.append(f"Exceeded {period} {label} limit ({used:,} / {limit:,}).")
        elif used >= int(limit * 0.8):
            alerts.append(f"Approaching {period} {label} limit ({used:,} / {limit:,}).")

    _check_limit("token", totals["total_tokens"], policy.get("monthly_token_limit"), "monthly")
    _check_limit("request", totals["requests"], policy.get("monthly_request_limit"), "monthly")
    _check_limit("tool request", sum(tool_usage_totals.values()), policy.get("monthly_tool_request_limit"), "monthly")
    _check_limit("token", daily_totals["total_tokens"], policy.get("daily_token_limit"), "daily")
    _check_limit("request", daily_totals["requests"], policy.get("daily_request_limit"), "daily")
    _check_limit("tool request", daily_totals["tool_requests"], policy.get("daily_tool_request_limit"), "daily")

    # High price model usage alerts
    high_price_threshold = getattr(settings, "HIGH_PRICE_PER_1M_USD", 20.0)
    for row in by_model_rows:
        if row.total_tokens <= 0 or row.cost_usd is None or row.cost_usd <= 0:
            continue
        per_million = (row.cost_usd / row.total_tokens) * 1_000_000
        if per_million >= high_price_threshold:
            alerts.append(
                f"High-price model used: {row.model} (~${per_million:.2f} per 1M tokens)."
            )

    limits = UsageLimits(
        allowed_models=list(policy.get("allowed_models") or []),
        allowed_tools=list(policy.get("allowed_tools") or []),
        daily_token_limit=policy.get("daily_token_limit"),
        monthly_token_limit=policy.get("monthly_token_limit"),
        daily_request_limit=policy.get("daily_request_limit"),
        monthly_request_limit=policy.get("monthly_request_limit"),
        daily_tool_request_limit=policy.get("daily_tool_request_limit"),
        monthly_tool_request_limit=policy.get("monthly_tool_request_limit"),
    )

    return UsageInvoice(
        start=start,
        end=end,
        totals=UsageSummaryRow(
            model="total",
            requests=totals["requests"],
            input_tokens=totals["input_tokens"],
            output_tokens=totals["output_tokens"],
            total_tokens=totals["total_tokens"],
            cost_usd=round(totals["cost_usd"], 6) if totals.get("has_cost") else None,
        ),
        by_model=by_model_rows,
        tool_usage=tool_usage_rows,
        limits=limits,
        alerts=alerts,
    )


async def handle_usage_invoice_pdf(
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
    days: int = 30,
) -> Response:
    from io import BytesIO

    from reportlab.graphics.barcode import code128
    from reportlab.graphics.barcode.qr import QrCodeWidget
    from reportlab.graphics.shapes import Drawing
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import getSampleStyleSheet
    from reportlab.lib.units import mm
    from reportlab.platypus import Image, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

    invoice = await handle_usage_invoice(user, db, space_id=space_id, days=days)

    company_name = getattr(settings, "INVOICE_COMPANY_NAME", "TEIA") or "TEIA"
    company_address = getattr(settings, "INVOICE_COMPANY_ADDRESS", "") or ""
    company_email = getattr(settings, "INVOICE_COMPANY_EMAIL", "") or ""
    logo_path = (getattr(settings, "INVOICE_LOGO_PATH", "") or "").strip()
    verify_url = (getattr(settings, "INVOICE_VERIFY_URL", "") or "").strip()

    if logo_path:
        try:
            from pathlib import Path

            path_obj = Path(logo_path)
            if not path_obj.is_absolute():
                root_dir = Path(__file__).resolve().parents[5]
                path_obj = root_dir / path_obj
            logo_path = str(path_obj) if path_obj.exists() else ""
        except Exception:
            logo_path = ""

    invoice_number = f"INV-{space_id[:8]}-{invoice.end.strftime('%Y%m%d')}"
    issue_date = invoice.end.date().isoformat()

    styles = getSampleStyleSheet()
    style_title = styles["Title"]
    style_normal = styles["BodyText"]
    style_small = styles["BodyText"].clone("small")
    style_small.fontSize = 9
    style_small.leading = 11

    buf = BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=16 * mm,
        bottomMargin=16 * mm,
        title=f"Usage Invoice {invoice_number}",
    )

    story: list[object] = []

    header_left: list[object] = []
    if logo_path:
        try:
            header_left.append(Image(logo_path, width=40 * mm, height=14 * mm, kind="proportional"))
        except Exception:
            header_left.append(Paragraph(company_name, style_normal))
    else:
        header_left.append(Paragraph(company_name, style_normal))

    header_right_lines = [f"<b>{company_name}</b>"]
    if company_address:
        header_right_lines.append(company_address.replace("\n", "<br/>") )
    if company_email:
        header_right_lines.append(company_email)
    header_right = Paragraph("<br/>".join(header_right_lines), style_small)

    header_tbl = Table(
        [[header_left, header_right]],
        colWidths=[90 * mm, None],
        hAlign="LEFT",
    )
    header_tbl.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ALIGN", (1, 0), (1, 0), "RIGHT"),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(header_tbl)
    story.append(Spacer(1, 6))

    story.append(Paragraph("Usage Invoice", style_title))
    story.append(Spacer(1, 6))

    meta_tbl = Table(
        [
            ["Invoice #", invoice_number, "Issue date", issue_date],
            ["Billing period", f"{invoice.start.date()} → {invoice.end.date()}", "Space", space_id],
            ["Bill to", getattr(user, "email", "") or "", "User", getattr(user, "name", "") or ""],
        ],
        colWidths=[22 * mm, 75 * mm, 22 * mm, None],
        hAlign="LEFT",
    )
    meta_tbl.setStyle(
        TableStyle(
            [
                ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
                ("FONTSIZE", (0, 0), (-1, -1), 9),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("TEXTCOLOR", (0, 0), (-1, -1), colors.black),
                ("TEXTCOLOR", (0, 0), (0, -1), colors.grey),
                ("TEXTCOLOR", (2, 0), (2, -1), colors.grey),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(meta_tbl)
    story.append(Spacer(1, 10))

    totals = invoice.totals
    total_cost = float(totals.cost_usd or 0.0)
    summary_tbl = Table(
        [
            ["Requests", f"{totals.requests:,}"],
            ["Tokens", f"{totals.total_tokens:,} (in {totals.input_tokens:,} / out {totals.output_tokens:,})"],
            ["Total (USD)", f"${total_cost:,.4f}"],
        ],
        colWidths=[30 * mm, None],
        hAlign="LEFT",
    )
    summary_tbl.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.whitesmoke),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.lightgrey),
                ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
                ("FONTSIZE", (0, 0), (-1, -1), 9),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("BACKGROUND", (0, 2), (-1, 2), colors.whitesmoke),
            ]
        )
    )
    story.append(summary_tbl)
    story.append(Spacer(1, 12))

    story.append(Paragraph("Usage by model", styles["Heading3"]))
    by_model_rows = [["Model", "Requests", "Input", "Output", "Total", "Cost (USD)"]]
    for row in invoice.by_model:
        by_model_rows.append(
            [
                str(row.model),
                f"{row.requests:,}",
                f"{row.input_tokens:,}",
                f"{row.output_tokens:,}",
                f"{row.total_tokens:,}",
                f"${float(row.cost_usd or 0.0):,.4f}",
            ]
        )
    by_model_tbl = Table(by_model_rows, hAlign="LEFT")
    by_model_tbl.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#F2F2F2")),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.lightgrey),
                ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
                ("FONTSIZE", (0, 0), (-1, -1), 8.5),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ALIGN", (1, 1), (-1, -1), "RIGHT"),
            ]
        )
    )
    story.append(by_model_tbl)
    story.append(Spacer(1, 10))

    if invoice.tool_usage:
        story.append(Paragraph("Tool usage", styles["Heading3"]))
        tool_rows = [["Tool", "Calls", "Cost (USD)"]]
        for row in invoice.tool_usage:
            tool_rows.append(
                [
                    str(row.tool),
                    f"{row.requests:,}",
                    f"${float(row.cost_usd or 0.0):,.4f}" if row.cost_usd is not None else "—",
                ]
            )
        tool_tbl = Table(tool_rows, hAlign="LEFT")
        tool_tbl.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#F2F2F2")),
                    ("GRID", (0, 0), (-1, -1), 0.25, colors.lightgrey),
                    ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
                    ("FONTSIZE", (0, 0), (-1, -1), 9),
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("ALIGN", (1, 1), (-1, -1), "RIGHT"),
                ]
            )
        )
        story.append(tool_tbl)
        story.append(Spacer(1, 10))

    if invoice.alerts:
        story.append(Paragraph("Alerts", styles["Heading3"]))
        for alert in invoice.alerts:
            story.append(Paragraph(f"• {alert}", style_small))
        story.append(Spacer(1, 8))

    # Footer identifiers: barcode + QR
    barcode = code128.Code128(invoice_number, barHeight=12 * mm, humanReadable=True)
    qr_value = verify_url.format(invoice_number=invoice_number) if verify_url else invoice_number
    qr = QrCodeWidget(qr_value)
    bounds = qr.getBounds()
    qr_w = bounds[2] - bounds[0]
    qr_h = bounds[3] - bounds[1]
    qr_size = 24 * mm
    qr_drawing = Drawing(qr_size, qr_size, transform=[qr_size / qr_w, 0, 0, qr_size / qr_h, 0, 0])
    qr_drawing.add(qr)
    footer_tbl = Table([[barcode, qr_drawing]], colWidths=[None, 28 * mm], hAlign="LEFT")
    footer_tbl.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("ALIGN", (1, 0), (1, 0), "RIGHT"),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    story.append(footer_tbl)

    doc.build(story)
    pdf_bytes = buf.getvalue()
    buf.close()

    filename = f"{invoice_number}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )
