"""Chat router wiring conversation handlers."""

from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.apis.dependencies import get_current_space_id, get_current_user
from src.modules.apis.v1.chat.handlers import (
    handle_message_reaction,
    handle_chat_query,
    handle_chat_query_stream,
    handle_export_session,
    handle_get_session,
    handle_list_models,
    handle_list_sessions,
    handle_list_usage_events,
    handle_branch_session,
    handle_usage_summary,
    handle_list_all_models,
    handle_usage_invoice,
    handle_usage_invoice_pdf,
    handle_list_model_pricing,
)
from src.modules.apis.v1.chat.schemas import (
    MessageReactionRequest,
    MessageReactionResponse,
    BranchSessionRequest,
    BranchSessionResponse,
    ChatQueryRequest,
    ChatQueryResponse,
    ChatSessionDetail,
    ChatSessionSummary,
    UsageEvent,
    UsageSummary,
    UsageInvoice,
    ModelPricingResponse,
)
from src.services.databases.postgresql.database import get_db
from src.services.databases.postgresql.models import User

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post(
    "/query",
    response_model=ChatQueryResponse,
    status_code=status.HTTP_200_OK,
    summary="Chat with memory-aware RAG agent",
)
async def chat_query(
    payload: ChatQueryRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> ChatQueryResponse:
    return await handle_chat_query(payload, current_user, db, space_id=space_id)


@router.post(
    "/query/stream",
    status_code=status.HTTP_200_OK,
    summary="Stream a chat reply (SSE)",
)
async def chat_query_stream(
    payload: ChatQueryRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
):
    return await handle_chat_query_stream(payload, current_user, db, space_id=space_id)


@router.get(
    "/models",
    response_model=List[str],
    summary="List available models",
)
async def list_models(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> List[str]:
    return await handle_list_models(current_user, db, space_id=space_id)

@router.get(
    "/models/all",
    response_model=List[str],
    summary="List all available models without policy filtering",
)
async def list_all_models(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> List[str]:
    return await handle_list_all_models(current_user, db, space_id=space_id)


@router.get(
    "/models/pricing",
    response_model=ModelPricingResponse,
    summary="Get model pricing and aliases",
)
async def list_model_pricing(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> ModelPricingResponse:
    return await handle_list_model_pricing(current_user, db, space_id=space_id)


@router.get(
    "/sessions",
    response_model=List[ChatSessionSummary],
    summary="List chat sessions",
)
async def list_chat_sessions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> List[ChatSessionSummary]:
    return await handle_list_sessions(current_user, db, space_id=space_id)


@router.get(
    "/sessions/{session_id}",
    response_model=ChatSessionDetail,
    summary="Fetch chat session history",
)
async def get_chat_session(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> ChatSessionDetail:
    return await handle_get_session(session_id, current_user, db, space_id=space_id)


@router.post(
    "/sessions/{session_id}/branch",
    response_model=BranchSessionResponse,
    summary="Branch a conversation from a message",
)
async def branch_chat_session(
    session_id: str,
    payload: BranchSessionRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> BranchSessionResponse:
    return await handle_branch_session(session_id, payload, current_user, db, space_id=space_id)


@router.get(
    "/sessions/{session_id}/export",
    summary="Export a conversation (json or markdown)",
)
async def export_chat_session(
    session_id: str,
    format: str = "json",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
):
    return await handle_export_session(session_id, current_user, db, space_id=space_id, format=format)


@router.post(
    "/messages/{message_id}/reaction",
    response_model=MessageReactionResponse,
    summary="React to a message (thumbs up/down)",
)
async def react_to_message(
    message_id: str,
    payload: MessageReactionRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> MessageReactionResponse:
    return await handle_message_reaction(message_id, payload, current_user, db, space_id=space_id)


@router.get(
    "/sessions/{session_id}/summary",
    response_model=dict,
    summary="Generate conversation summary",
)
async def get_session_summary(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
):
    from .handlers import handle_get_session_summary
    return await handle_get_session_summary(session_id, current_user, db, space_id=space_id)


@router.get(
    "/usage",
    response_model=List[UsageEvent],
    summary="List LLM usage events",
)
async def list_usage(
    limit: int = 100,
    session_id: str | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> List[UsageEvent]:
    return await handle_list_usage_events(current_user, db, space_id=space_id, limit=limit, session_id=session_id)


@router.get(
    "/usage/summary",
    response_model=UsageSummary,
    summary="Invoice-style usage summary (totals + per-model)",
)
async def usage_summary(
    days: int = 30,
    session_id: str | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> UsageSummary:
    return await handle_usage_summary(current_user, db, space_id=space_id, days=days, session_id=session_id)


@router.get(
    "/usage/invoice",
    response_model=UsageInvoice,
    summary="Usage invoice (limits, alerts, tool usage)",
)
async def usage_invoice(
    days: int = 30,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> UsageInvoice:
    return await handle_usage_invoice(current_user, db, space_id=space_id, days=days)


@router.get(
    "/usage/invoice/pdf",
    summary="Download usage invoice PDF",
)
async def usage_invoice_pdf(
    days: int = 30,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
):
    return await handle_usage_invoice_pdf(current_user, db, space_id=space_id, days=days)
