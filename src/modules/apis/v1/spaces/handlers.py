"""Spaces handlers (thin wrapper around service)."""

from __future__ import annotations

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.services.databases.postgresql.models import Space, SpaceRequest, User

from .schemas import (
    AcceptInviteRequest,
    AcceptInviteResponse,
    CreateSpaceRequest,
    CreateSpaceResponse,
    InviteMemberRequest,
    InviteMemberResponse,
    ReviewSpaceRequest,
    SpaceMemberSummary,
    MySpaceMembership,
    SpacePolicy,
    SpaceRequestCreate,
    SpaceRequestSummary,
    SpaceSummary,
    SpaceUsageSummary,
    UpdateMemberRequest,
    UpdatePolicyRequest,
    UpdateSpaceRequest,
    UsageTotals,
    DashboardStats,
)
from .service import spaces_service


def _policy_from_space(space) -> SpacePolicy:
    return SpacePolicy(
        allowed_models=list(space.allowed_models or []),
        allowed_tools=list(getattr(space, "allowed_tools", None) or []),
        daily_token_limit=space.daily_token_limit,
        monthly_token_limit=space.monthly_token_limit,
        daily_request_limit=space.daily_request_limit,
        monthly_request_limit=space.monthly_request_limit,
        daily_tool_request_limit=getattr(space, "daily_tool_request_limit", None),
        monthly_tool_request_limit=getattr(space, "monthly_tool_request_limit", None),
    )


def _policy_from_member(member) -> SpacePolicy:
    return SpacePolicy(
        allowed_models=list(member.allowed_models or []),
        allowed_tools=list(getattr(member, "allowed_tools", None) or []),
        daily_token_limit=member.daily_token_limit,
        monthly_token_limit=member.monthly_token_limit,
        daily_request_limit=member.daily_request_limit,
        monthly_request_limit=member.monthly_request_limit,
        daily_tool_request_limit=getattr(member, "daily_tool_request_limit", None),
        monthly_tool_request_limit=getattr(member, "monthly_tool_request_limit", None),
    )


def _membership_from_member(member) -> MySpaceMembership:
    return MySpaceMembership(
        space_id=member.space_id,
        user_id=member.user_id,
        role=member.role,
        status=member.status,
        can_upload_documents=bool(getattr(member, "can_upload_documents", False)),
        overrides=_policy_from_member(member),
    )


async def handle_list_my_spaces(user: User, db: AsyncSession) -> list[SpaceSummary]:
    spaces = await spaces_service.list_my_spaces(db, user)
    return [
        SpaceSummary(
            id=space.id,
            name=space.name,
            s3_bucket=space.s3_bucket,
            is_active=space.is_active,
            policy=_policy_from_space(space),
            created_at=space.created_at,
        )
        for space in spaces
    ]


async def handle_list_available_spaces(user: User, db: AsyncSession) -> list[SpaceSummary]:
    spaces = await spaces_service.list_available_spaces(db, user)
    return [
        SpaceSummary(
            id=space.id,
            name=space.name,
            s3_bucket=space.s3_bucket,
            is_active=space.is_active,
            policy=_policy_from_space(space),
            created_at=space.created_at,
        )
        for space in spaces
    ]


async def handle_create_space(payload: CreateSpaceRequest, user: User, db: AsyncSession) -> CreateSpaceResponse:
    if user.role not in {"admin", "super_admin"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required to create spaces")
    space = await spaces_service.create_space(db, name=payload.name, creator=user)
    return CreateSpaceResponse(
        space=SpaceSummary(
            id=space.id,
            name=space.name,
            s3_bucket=space.s3_bucket,
            is_active=space.is_active,
            policy=_policy_from_space(space),
            created_at=space.created_at,
        )
    )


async def handle_update_space(space_id: str, payload: UpdateSpaceRequest, user: User, db: AsyncSession) -> SpaceSummary:
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    space = await spaces_service._ensure_space(db, space_id)
    space = await spaces_service.update_space(db, space=space, name=payload.name, is_active=payload.is_active)
    return SpaceSummary(
        id=space.id,
        name=space.name,
        s3_bucket=space.s3_bucket,
        is_active=space.is_active,
        policy=_policy_from_space(space),
        created_at=space.created_at,
    )


async def handle_delete_space(space_id: str, user: User, db: AsyncSession) -> SpaceSummary:
    """Deactivate a space (admin only)."""
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    space = await spaces_service._ensure_space(db, space_id)
    space = await spaces_service.update_space(db, space=space, name=None, is_active=False)
    return SpaceSummary(
        id=space.id,
        name=space.name,
        s3_bucket=space.s3_bucket,
        is_active=space.is_active,
        policy=_policy_from_space(space),
        created_at=space.created_at,
    )


async def handle_invite_member(space_id: str, payload: InviteMemberRequest, user: User, db: AsyncSession) -> InviteMemberResponse:
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    space = await spaces_service._ensure_space(db, space_id)
    invite = await spaces_service.invite_member(db, space=space, inviter=user, email=payload.email)
    return InviteMemberResponse(invite_token=invite.token, status=invite.status)


async def handle_accept_invite(payload: AcceptInviteRequest, user: User, db: AsyncSession) -> AcceptInviteResponse:
    member = await spaces_service.accept_invite(db, token=payload.token, user=user)
    return AcceptInviteResponse(space_id=member.space_id, status=member.status)


async def handle_list_members(space_id: str, user: User, db: AsyncSession) -> list[SpaceMemberSummary]:
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    members = await spaces_service.list_members(db, space_id=space_id)

    # best-effort email expansion for UI
    user_ids = [m.user_id for m in members]
    emails = {}
    if user_ids:
        from sqlalchemy import select
        from src.services.databases.postgresql.models import User as UserModel

        rows = (await db.execute(select(UserModel).where(UserModel.id.in_(user_ids)))).scalars().all()
        emails = {u.id: u.email for u in rows}

    return [
        SpaceMemberSummary(
            user_id=m.user_id,
            email=emails.get(m.user_id),
            role=m.role,
            status=m.status,
            can_upload_documents=bool(getattr(m, "can_upload_documents", False)),
            created_at=m.created_at,
            updated_at=m.updated_at,
            overrides=_policy_from_member(m),
        )
        for m in members
    ]


async def handle_update_policy(space_id: str, payload: UpdatePolicyRequest, user: User, db: AsyncSession) -> SpaceSummary:
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    space = await spaces_service._ensure_space(db, space_id)
    fields = payload.model_dump(exclude_unset=True)
    space = await spaces_service.update_policy(db, space=space, **fields)
    return SpaceSummary(
        id=space.id,
        name=space.name,
        s3_bucket=space.s3_bucket,
        is_active=space.is_active,
        policy=_policy_from_space(space),
        created_at=space.created_at,
    )


async def handle_update_member(space_id: str, target_user_id: str, payload: UpdateMemberRequest, user: User, db: AsyncSession) -> SpaceMemberSummary:
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)

    member = await spaces_service.get_member(db, space_id=space_id, user_id=target_user_id)
    if member is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Member not found")

    overrides = None
    if payload.overrides is not None:
        overrides = payload.overrides.model_dump(exclude_unset=True)

    member = await spaces_service.update_member(
        db,
        member=member,
        role=payload.role,
        status_value=payload.status,
        can_upload_documents=payload.can_upload_documents,
        overrides=overrides,
    )

    # email expansion
    target_user = await spaces_service._ensure_user(db, target_user_id)

    return SpaceMemberSummary(
        user_id=member.user_id,
        email=target_user.email,
        role=member.role,
        status=member.status,
        can_upload_documents=bool(getattr(member, "can_upload_documents", False)),
        created_at=member.created_at,
        updated_at=member.updated_at,
        overrides=_policy_from_member(member),
    )


async def handle_my_membership(space_id: str, user: User, db: AsyncSession) -> MySpaceMembership:
    if user.role == "super_admin":
        member = await spaces_service.get_member(db, space_id=space_id, user_id=user.id)
        if member is None:
            member = await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    else:
        member = await spaces_service.require_active_member(db, space_id=space_id, user=user)
    return _membership_from_member(member)


async def handle_create_request(space_id: str, payload: SpaceRequestCreate, user: User, db: AsyncSession) -> SpaceRequestSummary:
    type_value = (payload.type or "").strip().lower()
    allowed_types = {"join", "model_access", "tool_access", "quota_change", "upload_access", "other"}
    if type_value not in allowed_types:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unsupported request type")
    if type_value == "join":
        space = await db.get(Space, space_id)
        if space is None or not space.is_active:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Space not found")
        member = await spaces_service.get_member(db, space_id=space_id, user_id=user.id)
        if member is not None and member.status == "active":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Already a member of this space")
        pending = await spaces_service.find_pending_request(db, space_id=space_id, user_id=user.id, type_value="join")
        if pending is not None:
            return SpaceRequestSummary.model_validate(pending)
    else:
        await spaces_service.require_active_member(db, space_id=space_id, user=user)
    req = await spaces_service.create_request(db, space_id=space_id, user=user, type_value=type_value, payload=payload.payload)
    return SpaceRequestSummary.model_validate(req)


async def handle_list_my_requests(user: User, db: AsyncSession) -> list[SpaceRequestSummary]:
    rows = await spaces_service.list_user_requests(db, user_id=user.id)
    return [SpaceRequestSummary.model_validate(r) for r in rows]


async def handle_list_requests(space_id: str, user: User, db: AsyncSession, *, status_value: str | None = None) -> list[SpaceRequestSummary]:
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    rows = await spaces_service.list_requests(db, space_id=space_id, status_filter=status_value)
    return [SpaceRequestSummary.model_validate(r) for r in rows]


async def handle_review_request(space_id: str, request_id: str, payload: ReviewSpaceRequest, user: User, db: AsyncSession) -> SpaceRequestSummary:
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    req = await db.get(SpaceRequest, request_id)
    if req is None or req.space_id != space_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found")
    req = await spaces_service.review_request(db, req=req, reviewer=user, decision=payload.decision, note=payload.note)
    return SpaceRequestSummary.model_validate(req)


async def handle_space_usage(space_id: str, user: User, db: AsyncSession, *, days: int = 30) -> SpaceUsageSummary:
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    start, end, rows = await spaces_service.usage_summary(db, space_id=space_id, days=days)

    totals = UsageTotals()
    by_model: dict[str, UsageTotals] = {}

    has_cost = False
    total_cost = 0.0

    for model, inp, out, tot, reqs, cost in rows:
        key = model or "unknown"
        by_model[key] = UsageTotals(
            input_tokens=int(inp or 0),
            output_tokens=int(out or 0),
            total_tokens=int(tot or 0),
            requests=int(reqs or 0),
            cost_usd=float(cost) if cost is not None else None,
        )
        totals.input_tokens += int(inp or 0)
        totals.output_tokens += int(out or 0)
        totals.total_tokens += int(tot or 0)
        totals.requests += int(reqs or 0)
        if cost is not None:
            total_cost += float(cost)
            has_cost = True

    totals.cost_usd = round(total_cost, 6) if has_cost else None

    return SpaceUsageSummary(start=start, end=end, totals=totals, by_model=by_model)


async def handle_superadmin_list_spaces(user: User, db: AsyncSession) -> list[SpaceSummary]:
    if user.role != "super_admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Super admin required")
    from sqlalchemy import select
    from src.services.databases.postgresql.models import Space

    spaces = (await db.execute(select(Space).order_by(Space.created_at.desc()))).scalars().all()
    return [
        SpaceSummary(
            id=s.id,
            name=s.name,
            s3_bucket=s.s3_bucket,
            is_active=s.is_active,
            policy=_policy_from_space(s),
            created_at=s.created_at,
        )
        for s in spaces
    ]

async def handle_dashboard_stats(user: User, db: AsyncSession) -> DashboardStats:
    if user.role not in {"admin", "super_admin"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return await spaces_service.get_dashboard_stats(db)


async def handle_space_dashboard_stats(space_id: str, user: User, db: AsyncSession) -> DashboardStats:
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    return await spaces_service.get_space_dashboard_stats(db, space_id)
