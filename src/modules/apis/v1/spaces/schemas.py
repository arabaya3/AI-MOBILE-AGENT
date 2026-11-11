"""Schemas for multi-tenant spaces."""

from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field, StrictInt


class SpacePolicy(BaseModel):
    allowed_models: List[str] = Field(default_factory=list)
    allowed_tools: List[str] = Field(default_factory=list)
    daily_token_limit: Optional[int] = None
    monthly_token_limit: Optional[int] = None
    daily_request_limit: Optional[int] = None
    monthly_request_limit: Optional[int] = None
    daily_tool_request_limit: Optional[int] = None
    monthly_tool_request_limit: Optional[int] = None


class SpaceSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    s3_bucket: str
    is_active: bool = True
    policy: SpacePolicy = Field(default_factory=SpacePolicy)
    created_at: datetime


class SpaceMemberSummary(BaseModel):
    user_id: str
    email: Optional[str] = None
    role: str
    status: str
    can_upload_documents: bool = False
    created_at: datetime
    updated_at: datetime
    overrides: SpacePolicy = Field(default_factory=SpacePolicy)


class CreateSpaceRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=80)


class CreateSpaceResponse(BaseModel):
    space: SpaceSummary


class InviteMemberRequest(BaseModel):
    email: EmailStr


class InviteSummary(BaseModel):
    """Never carries the token: it is delivered only by email."""

    id: str
    email: str
    status: str  # pending | accepted | revoked | expired
    expires_at: Optional[datetime] = None
    created_at: datetime
    last_sent_at: Optional[datetime] = None
    send_count: int = 1
    invited_by_email: Optional[str] = None


class AcceptInviteRequest(BaseModel):
    token: str = Field(..., min_length=1, max_length=256)


class AcceptInviteResponse(BaseModel):
    space_id: str
    status: str


class UpdateSpaceRequest(BaseModel):
    name: Optional[str] = Field(default=None, min_length=2, max_length=80)
    is_active: Optional[bool] = None


LIMIT_FIELDS = (
    "daily_token_limit",
    "monthly_token_limit",
    "daily_request_limit",
    "monthly_request_limit",
    "daily_tool_request_limit",
    "monthly_tool_request_limit",
)


class UpdatePolicyRequest(BaseModel):
    """Limits: a number sets it (0 blocks use); an explicit null clears it (space: unlimited, member: inherit).
    Omitted fields are unchanged."""

    allowed_models: Optional[List[str]] = Field(default=None, max_length=200)
    allowed_tools: Optional[List[str]] = Field(default=None, max_length=200)
    daily_token_limit: Optional[StrictInt] = None
    monthly_token_limit: Optional[StrictInt] = None
    daily_request_limit: Optional[StrictInt] = None
    monthly_request_limit: Optional[StrictInt] = None
    daily_tool_request_limit: Optional[StrictInt] = None
    monthly_tool_request_limit: Optional[StrictInt] = None


class UpdateMemberRequest(BaseModel):
    role: Optional[str] = Field(default=None, description="admin|member")
    status: Optional[str] = Field(default=None, description="active|revoked")
    can_upload_documents: Optional[bool] = None
    overrides: Optional[UpdatePolicyRequest] = None


class MySpaceMembership(BaseModel):
    """Compact membership payload for the current user."""

    space_id: str
    user_id: str
    role: str
    status: str
    can_upload_documents: bool = False
    overrides: SpacePolicy = Field(default_factory=SpacePolicy)


class SpaceRequestCreate(BaseModel):
    type: str = Field(..., description="join|model_access|tool_access|quota_change|upload_access|other")
    payload: Dict[str, Any] = Field(default_factory=dict)


class SpaceRequestSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    space_id: str
    user_id: str
    user_email: Optional[str] = None
    type: str
    payload: Dict[str, Any] = Field(default_factory=dict)
    status: str
    review_note: Optional[str] = None
    created_at: datetime
    reviewed_at: Optional[datetime] = None


class ReviewSpaceRequest(BaseModel):
    decision: str = Field(..., description="approved|declined")
    note: Optional[str] = Field(default=None, max_length=500)


class CatalogItem(BaseModel):
    id: str


class SpaceCatalog(BaseModel):
    """Identifiers an admin may allow and a member may request; no provider or tool configuration."""

    models: List[CatalogItem]
    tools: List[CatalogItem]


class UsageTotals(BaseModel):
    input_tokens: int = 0
    output_tokens: int = 0
    total_tokens: int = 0
    requests: int = 0
    cost_usd: Optional[float] = None


class SpaceUsageSummary(BaseModel):
    start: datetime
    end: datetime
    totals: UsageTotals
    by_model: Dict[str, UsageTotals] = Field(default_factory=dict)


class SuperAdminUsageRow(BaseModel):
    space_id: str
    space_name: str
    start: datetime
    end: datetime
    totals: UsageTotals


class SuperAdminSpacesResponse(BaseModel):
    spaces: List[SpaceSummary]

class TopModelStats(BaseModel):
    name: str
    usage: int
    cost: float

class SpaceUsageStats(BaseModel):
    space_id: str
    space_name: str
    tokens: int
    requests: int
    cost: float

class DailyUsageStats(BaseModel):
    date: str
    tokens: int
    requests: int
    cost: float

class ToolUsageStats(BaseModel):
    tool: str
    count: int

class DashboardStats(BaseModel):
    total_users: int
    active_spaces: int
    total_messages: int
    total_sessions: int
    total_documents: int
    total_requests: int
    new_users_30d: int
    active_users_30d: int
    admins_count: int
    members_count: int
    total_tokens: int
    total_cost: float
    avg_response_time: float
    success_rate: float
    top_models: List[TopModelStats]
    usage_by_space: List[SpaceUsageStats]
    daily_usage: List[DailyUsageStats]
    tool_usage: List[ToolUsageStats]
