"""Spaces router."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.apis.dependencies import get_current_user
from src.services.databases.postgresql.database import get_db
from src.services.databases.postgresql.models import User

from .handlers import (
    handle_accept_invite,
    handle_create_request,
    handle_create_space,
    handle_delete_space,
    handle_invite_member,
    handle_list_members,
    handle_list_my_spaces,
    handle_list_available_spaces,
    handle_list_my_requests,
    handle_list_requests,
    handle_review_request,
    handle_space_usage,
    handle_superadmin_list_spaces,
    handle_my_membership,
    handle_update_member,
    handle_update_policy,
    handle_update_space,
    handle_dashboard_stats,
    handle_space_dashboard_stats,
)
from .schemas import (
    AcceptInviteRequest,
    AcceptInviteResponse,
    CreateSpaceRequest,
    CreateSpaceResponse,
    InviteMemberRequest,
    InviteMemberResponse,
    ReviewSpaceRequest,
    SpaceMemberSummary,
    SpacePolicy,
    SpaceRequestCreate,
    SpaceRequestSummary,
    SpaceSummary,
    SpaceUsageSummary,
    SuperAdminUsageRow,
    MySpaceMembership,
    UpdateMemberRequest,
    UpdatePolicyRequest,
    UpdateSpaceRequest,
    DashboardStats,
)


router = APIRouter(prefix="/spaces", tags=["spaces"])


@router.get("", response_model=list[SpaceSummary])
async def list_my_spaces(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[SpaceSummary]:
    return await handle_list_my_spaces(current_user, db)


@router.get("/available", response_model=list[SpaceSummary])
async def list_available_spaces(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[SpaceSummary]:
    return await handle_list_available_spaces(current_user, db)


@router.get("/requests/mine", response_model=list[SpaceRequestSummary])
async def list_my_space_requests(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[SpaceRequestSummary]:
    """The caller's own requests across all spaces (for showing pending access)."""
    return await handle_list_my_requests(current_user, db)


@router.post("", response_model=CreateSpaceResponse, status_code=status.HTTP_201_CREATED)
async def create_space(
    payload: CreateSpaceRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> CreateSpaceResponse:
    return await handle_create_space(payload, current_user, db)


@router.patch("/{space_id}", response_model=SpaceSummary)
async def update_space(
    space_id: str,
    payload: UpdateSpaceRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SpaceSummary:
    return await handle_update_space(space_id, payload, current_user, db)


@router.delete("/{space_id}", response_model=SpaceSummary)
async def delete_space(
    space_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SpaceSummary:
    return await handle_delete_space(space_id, current_user, db)


@router.post("/{space_id}/invites", response_model=InviteMemberResponse)
async def invite_member(
    space_id: str,
    payload: InviteMemberRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> InviteMemberResponse:
    return await handle_invite_member(space_id, payload, current_user, db)


@router.post("/invites/accept", response_model=AcceptInviteResponse)
async def accept_invite(
    payload: AcceptInviteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> AcceptInviteResponse:
    return await handle_accept_invite(payload, current_user, db)


@router.get("/{space_id}/members", response_model=list[SpaceMemberSummary])
async def list_members(
    space_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[SpaceMemberSummary]:
    return await handle_list_members(space_id, current_user, db)


@router.get("/{space_id}/me", response_model=MySpaceMembership)
async def my_membership(
    space_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MySpaceMembership:
    return await handle_my_membership(space_id, current_user, db)


@router.patch("/{space_id}/members/{user_id}", response_model=SpaceMemberSummary)
async def update_member(
    space_id: str,
    user_id: str,
    payload: UpdateMemberRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SpaceMemberSummary:
    return await handle_update_member(space_id, user_id, payload, current_user, db)


@router.patch("/{space_id}/policy", response_model=SpaceSummary)
async def update_policy(
    space_id: str,
    payload: UpdatePolicyRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SpaceSummary:
    return await handle_update_policy(space_id, payload, current_user, db)


@router.post("/{space_id}/requests", response_model=SpaceRequestSummary, status_code=status.HTTP_201_CREATED)
async def create_space_request(
    space_id: str,
    payload: SpaceRequestCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SpaceRequestSummary:
    return await handle_create_request(space_id, payload, current_user, db)


@router.get("/{space_id}/requests", response_model=list[SpaceRequestSummary])
async def list_space_requests(
    space_id: str,
    status_value: str | None = Query(default=None, alias="status"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[SpaceRequestSummary]:
    return await handle_list_requests(space_id, current_user, db, status_value=status_value)


@router.post("/{space_id}/requests/{request_id}/review", response_model=SpaceRequestSummary)
async def review_space_request(
    space_id: str,
    request_id: str,
    payload: ReviewSpaceRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SpaceRequestSummary:
    return await handle_review_request(space_id, request_id, payload, current_user, db)


@router.get("/{space_id}/usage", response_model=SpaceUsageSummary)
async def space_usage(
    space_id: str,
    days: int = 30,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SpaceUsageSummary:
    return await handle_space_usage(space_id, current_user, db, days=days)


@router.get("/_superadmin/spaces", response_model=list[SpaceSummary])
async def superadmin_spaces(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[SpaceSummary]:
    return await handle_superadmin_list_spaces(current_user, db)


@router.get("/_superadmin/usage", response_model=list[SuperAdminUsageRow])
async def superadmin_usage(
    days: int = 30,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[SuperAdminUsageRow]:
    from .service import spaces_service
    if current_user.role != "super_admin":
        from fastapi import HTTPException

        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Super admin required")
    return await spaces_service.superadmin_usage_rollup(db, days=days)

@router.get("/admin/dashboard", response_model=DashboardStats)
async def get_dashboard_stats_endpoint(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> DashboardStats:
    return await handle_dashboard_stats(user, db)

@router.get("/{space_id}/dashboard", response_model=DashboardStats)
async def get_space_dashboard_stats_endpoint(
    space_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> DashboardStats:
    return await handle_space_dashboard_stats(space_id, user, db)
