"""Schemas for conversational chat endpoints."""

from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field

from src.modules.apis.v1.documents.schemas import VectorSearchMatch


class ConversationMessage(BaseModel):
    """Single chat message returned to the client."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    role: str
    content: str
    created_at: datetime


class ChatSessionSummary(BaseModel):
    """Lightweight session row for the sidebar."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    title: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class ChatQueryRequest(BaseModel):
    """Payload for chatting with the agent."""

    message: str = Field(..., min_length=1, max_length=8000)
    session_id: Optional[str] = Field(default=None, description="Existing session to continue")
    document_ids: Optional[List[str]] = Field(
        default=None,
        description="Restrict retrieval to these document IDs",
    )
    top_k: int = Field(default=10, ge=1, le=30, description="How many chunks to retrieve")
    model: Optional[str] = Field(
        default=None,
        description="OpenAI chat model to use for this request (defaults to server configuration)",
    )
    use_web_search: Optional[bool] = Field(
        default=None,
        description="Explicitly enable (true) or disable (false) web search. None means auto-decide.",
    )


class ChatQueryResponse(BaseModel):
    """Response when submitting a chat turn."""

    session_id: str
    reply: str
    sources: List[VectorSearchMatch]
    history: List[ConversationMessage]


class ChatSessionDetail(BaseModel):
    """Full transcript for a session."""

    session: ChatSessionSummary
    history: List[ConversationMessage]


class UsageEvent(BaseModel):
    """Single usage ledger row."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    created_at: datetime
    session_id: Optional[str] = None
    endpoint: str
    model: Optional[str] = None
    request_count: int = 1
    input_tokens: int = 0
    output_tokens: int = 0
    total_tokens: int = 0
    cost_usd: Optional[float] = None


class UsageSummaryRow(BaseModel):
    model: str
    requests: int = 0
    input_tokens: int = 0
    output_tokens: int = 0
    total_tokens: int = 0
    cost_usd: Optional[float] = None


class UsageSummary(BaseModel):
    start: datetime
    end: datetime
    total_requests: int = 0
    total_input_tokens: int = 0
    total_output_tokens: int = 0
    total_tokens: int = 0
    total_cost_usd: Optional[float] = None
    by_model: List[UsageSummaryRow] = Field(default_factory=list)


class ToolUsageSummary(BaseModel):
    tool: str
    requests: int = 0
    cost_usd: Optional[float] = None


class UsageLimits(BaseModel):
    allowed_models: List[str] = Field(default_factory=list)
    allowed_tools: List[str] = Field(default_factory=list)
    daily_token_limit: Optional[int] = None
    monthly_token_limit: Optional[int] = None
    daily_request_limit: Optional[int] = None
    monthly_request_limit: Optional[int] = None
    daily_tool_request_limit: Optional[int] = None
    monthly_tool_request_limit: Optional[int] = None


class UsageInvoice(BaseModel):
    start: datetime
    end: datetime
    totals: UsageSummaryRow
    by_model: List[UsageSummaryRow] = Field(default_factory=list)
    tool_usage: List[ToolUsageSummary] = Field(default_factory=list)
    limits: UsageLimits
    alerts: List[str] = Field(default_factory=list)


class ModelPricingEntry(BaseModel):
    input: float
    output: float


class ModelPricingResponse(BaseModel):
    pricing: dict[str, ModelPricingEntry] = Field(default_factory=dict)
    aliases: dict[str, str] = Field(default_factory=dict)


class BranchSessionRequest(BaseModel):
    """Create a new session branched from a specific message."""

    from_message_id: str = Field(..., description="Message ID to branch from (inclusive)")


class BranchSessionResponse(BaseModel):
    session_id: str


class MessageReactionRequest(BaseModel):
    reaction: str = Field(..., description="One of: up, down")


class MessageReactionResponse(BaseModel):
    success: bool = True
