"""Spaces handlers (thin wrapper around service)."""

from __future__ import annotations

import re

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.services.databases.postgresql.models import Space, SpaceRequest, User

from .schemas import (
    AcceptInviteRequest,
    AcceptInviteResponse,
    CreateSpaceRequest,
    CreateSpaceResponse,
    InviteMemberRequest,
    InviteSummary,
    SpaceCatalog,
    CatalogItem,
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
from . import catalog, invitations
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


async def _invite_summaries(db: AsyncSession, invites) -> list[InviteSummary]:
    from sqlalchemy import select

    inviter_ids = {i.invited_by_user_id for i in invites if i.invited_by_user_id}
    emails = {}
    if inviter_ids:
        emails = dict((await db.execute(select(User.id, User.email).where(User.id.in_(inviter_ids)))).all())
    return [
        InviteSummary(
            id=i.id,
            email=i.email,
            status=invitations.effective_status(i),
            expires_at=i.expires_at,
            created_at=i.created_at,
            last_sent_at=i.last_sent_at,
            send_count=i.send_count or 1,
            invited_by_email=emails.get(i.invited_by_user_id),
        )
        for i in invites
    ]


async def handle_invite_member(space_id: str, payload: InviteMemberRequest, user: User, db: AsyncSession) -> InviteSummary:
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    space = await spaces_service._ensure_space(db, space_id)
    invite = await invitations.create_or_resend(db, space=space, inviter=user, email=str(payload.email))
    return (await _invite_summaries(db, [invite]))[0]


async def handle_list_invites(space_id: str, user: User, db: AsyncSession) -> list[InviteSummary]:
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    return await _invite_summaries(db, await invitations.list_for_space(db, space_id=space_id))


async def handle_resend_invite(space_id: str, invite_id: str, user: User, db: AsyncSession) -> InviteSummary:
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    space = await spaces_service._ensure_space(db, space_id)
    invite = await invitations.resend(db, space=space, inviter=user, invite_id=invite_id)
    return (await _invite_summaries(db, [invite]))[0]


async def handle_revoke_invite(space_id: str, invite_id: str, user: User, db: AsyncSession) -> InviteSummary:
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    invite = await invitations.revoke(db, space_id=space_id, invite_id=invite_id)
    return (await _invite_summaries(db, [invite]))[0]


async def handle_accept_invite(payload: AcceptInviteRequest, user: User, db: AsyncSession) -> AcceptInviteResponse:
    member = await invitations.accept(db, token=payload.token, user=user)
    return AcceptInviteResponse(space_id=member.space_id, status=member.status)


async def handle_catalog(space_id: str, user: User, db: AsyncSession) -> SpaceCatalog:
    if user.role != "super_admin":
        await spaces_service.require_active_member(db, space_id=space_id, user=user)
    return SpaceCatalog(
        models=[CatalogItem(id=m) for m in await catalog.model_ids()],
        tools=[CatalogItem(id=t) for t in catalog.tool_ids()],
    )


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
    await _check_lists(fields, already_models=space.allowed_models, already_tools=space.allowed_tools)
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
        await _check_lists(overrides, already_models=member.allowed_models, already_tools=member.allowed_tools)

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
        req = await spaces_service.create_join_request(db, space_id=space_id, user=user)
        return SpaceRequestSummary.model_validate(req)
    member = await spaces_service.require_active_member(db, space_id=space_id, user=user)
    clean, dedupe_key = validate_request_payload(type_value, payload.payload or {}, member=member)
    req = await spaces_service.create_keyed_request(
        db, space_id=space_id, user=user, type_value=type_value, payload=clean, dedupe_key=dedupe_key
    )
    return SpaceRequestSummary.model_validate(req)


async def _check_lists(fields: dict, *, already_models, already_tools) -> None:
    if fields.get("allowed_models") is not None:
        fields["allowed_models"] = catalog.reject_unknown("models", fields["allowed_models"], await catalog.model_ids(), already_models)
    if fields.get("allowed_tools") is not None:
        fields["allowed_tools"] = catalog.reject_unknown("tools", fields["allowed_tools"], catalog.tool_ids(), already_tools)


async def _check_approvable(req: SpaceRequest) -> None:
    """Access approvals must name something this deployment actually supports."""
    payload = req.payload or {}
    if req.type == "model_access":
        catalog.reject_unknown("models", [payload.get("model") or ""], await catalog.model_ids())
    elif req.type == "tool_access":
        catalog.reject_unknown("tools", [payload.get("tool") or ""], catalog.tool_ids())


_TOOL_NAME = re.compile(r"^[a-z0-9_]{1,64}$")
_QUOTA_FIELDS = ("daily_token_limit", "monthly_token_limit", "daily_request_limit", "monthly_request_limit")


def _reason(payload: dict, *, required: bool = False) -> dict:
    reason = payload.get("reason")
    if reason is None or (isinstance(reason, str) and not reason.strip()):
        if required:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="A reason is required")
        return {}
    if not isinstance(reason, str) or len(reason) > 500:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Reason must be text of at most 500 characters")
    return {"reason": reason.strip()}


def validate_request_payload(type_value: str, payload: dict, *, member) -> tuple[dict, str | None]:
    """Only the fields each request type needs; returns the stored payload and its de-duplication key."""
    if not isinstance(payload, dict):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid request details")
    if type_value == "model_access":
        model = payload.get("model")
        if not isinstance(model, str) or not model.strip() or len(model) > 100:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Choose a model")
        model = model.strip()
        if model in (member.allowed_models or []):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="You already have access to this model")
        return {"model": model, **_reason(payload)}, f"model_access:{model}"
    if type_value == "tool_access":
        tool = payload.get("tool")
        if not isinstance(tool, str) or not _TOOL_NAME.match(tool.strip()):
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Choose a tool")
        tool = tool.strip()
        if tool in (member.allowed_tools or []):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="You already have access to this tool")
        return {"tool": tool, **_reason(payload)}, f"tool_access:{tool}"
    if type_value == "upload_access":
        if member.role == "admin" or member.can_upload_documents:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="You can already upload documents")
        return {"can_upload_documents": True, **_reason(payload)}, "upload_access"
    if type_value == "quota_change":
        limits: dict[str, int] = {}
        for key in _QUOTA_FIELDS:
            value = payload.get(key)
            if value is None:
                continue
            if isinstance(value, bool) or not isinstance(value, int) or not 0 < value <= 1_000_000_000:
                raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=f"Invalid {key}")
            limits[key] = value
        if not limits:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Request at least one limit")
        # Never accept model lists here: approving a quota change must not rewrite model access.
        return {**limits, **_reason(payload)}, "quota_change"
    return _reason(payload, required=True), None


async def handle_list_my_requests(user: User, db: AsyncSession) -> list[SpaceRequestSummary]:
    rows = await spaces_service.list_user_requests(db, user_id=user.id)
    return [SpaceRequestSummary.model_validate(r) for r in rows]


async def handle_list_requests(space_id: str, user: User, db: AsyncSession, *, status_value: str | None = None) -> list[SpaceRequestSummary]:
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    rows = await spaces_service.list_requests(db, space_id=space_id, status_filter=status_value)
    from sqlalchemy import select

    ids = {r.user_id for r in rows}
    emails = dict((await db.execute(select(User.id, User.email).where(User.id.in_(ids)))).all()) if ids else {}
    return [SpaceRequestSummary.model_validate(r).model_copy(update={"user_email": emails.get(r.user_id)}) for r in rows]


async def handle_review_request(space_id: str, request_id: str, payload: ReviewSpaceRequest, user: User, db: AsyncSession) -> SpaceRequestSummary:
    await spaces_service.require_space_admin(db, space_id=space_id, user=user)
    from sqlalchemy import select

    # Locked so concurrent reviews of one request run one after another; only the first applies.
    req = (await db.execute(select(SpaceRequest).where(SpaceRequest.id == request_id).with_for_update())).scalars().first()
    if req is None or req.space_id != space_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found")
    if req.status != "pending":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This request was already reviewed")
    if req.user_id == user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You cannot review your own request")
    if payload.decision.strip().lower() == "approved":
        await _check_approvable(req)
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
