"""Spaces service layer."""

from __future__ import annotations

import secrets
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import HTTPException, status
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.settings.config import settings
from src.services.cloud.aws.s3 import s3_service
from src.services.databases.postgresql.models import (
    Document,
    ChatMessage,
    ChatSession,
    LLMUsageEvent,
    Space,
    SpaceInvite,
    SpaceMember,
    SpaceRequest,
    User,
)

from .schemas import DashboardStats, SuperAdminUsageRow, UsageTotals, TopModelStats, SpaceUsageStats, DailyUsageStats, ToolUsageStats
from src.core.settings.logging import logger


class SpacesService:
    INVITE_TTL_HOURS = 24 * 7

    @staticmethod
    def _validate_quota_fields(fields: dict) -> None:
        """Validate token/request quotas.

        Rules:
        - Limits must be non-negative when provided.
        - Daily <= Monthly when both provided.
        """

        def _validate_pair(daily_key: str, monthly_key: str) -> None:
            daily = fields.get(daily_key)
            monthly = fields.get(monthly_key)

            # Define minimum meaningful values for token limits
            min_daily_tokens = 1000 if "token" in daily_key else 0
            min_monthly_tokens = 10000 if "token" in monthly_key else 0

            if daily is not None:
                try:
                    daily_int = int(daily)
                except Exception as exc:  # noqa: BLE001
                    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid {daily_key}") from exc
                
                if "token" in daily_key and daily_int > 0 and daily_int < min_daily_tokens:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST, 
                        detail=f"{daily_key} must be at least {min_daily_tokens:,} tokens for meaningful usage"
                    )
                if daily_int < 0:
                    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"{daily_key} must be >= 0")
                fields[daily_key] = daily_int

            if monthly is not None:
                try:
                    monthly_int = int(monthly)
                except Exception as exc:  # noqa: BLE001
                    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid {monthly_key}") from exc
                
                if "token" in monthly_key and monthly_int > 0 and monthly_int < min_monthly_tokens:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST, 
                        detail=f"{monthly_key} must be at least {min_monthly_tokens:,} tokens for meaningful usage"
                    )
                if monthly_int < 0:
                    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"{monthly_key} must be >= 0")
                fields[monthly_key] = monthly_int

            if daily is not None and monthly is not None:
                if int(fields[daily_key]) > int(fields[monthly_key]):
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"{daily_key} must be <= {monthly_key}",
                    )

        _validate_pair("daily_token_limit", "monthly_token_limit")
        _validate_pair("daily_request_limit", "monthly_request_limit")
        _validate_pair("daily_tool_request_limit", "monthly_tool_request_limit")

    async def _ensure_user(self, db: AsyncSession, user_id: str) -> User:
        user = await db.get(User, user_id)
        if user is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
        return user

    async def _ensure_space(self, db: AsyncSession, space_id: str) -> Space:
        space = await db.get(Space, space_id)
        if space is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Space not found")
        return space

    async def get_member(self, db: AsyncSession, *, space_id: str, user_id: str) -> Optional[SpaceMember]:
        stmt = select(SpaceMember).where(and_(SpaceMember.space_id == space_id, SpaceMember.user_id == user_id))
        return (await db.execute(stmt)).scalars().first()

    async def require_active_member(self, db: AsyncSession, *, space_id: str, user: User) -> SpaceMember:
        member = await self.get_member(db, space_id=space_id, user_id=user.id)
        if member is None or member.status != "active":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Space access denied")
        logger.debug(
            "Validated active space member",
            extra={"space_id": space_id, "user_id": user.id, "member_id": member.id},
        )
        return member

    async def require_space_admin(self, db: AsyncSession, *, space_id: str, user: User) -> SpaceMember:
        if user.role == "super_admin":
            # global super admin can administer any space
            member = await self.get_member(db, space_id=space_id, user_id=user.id)
            if member is None:
                member = SpaceMember(space_id=space_id, user_id=user.id, role="admin", status="active")
                db.add(member)
                await db.flush()
            logger.debug(
                "Super admin auto-provisioned as space admin",
                extra={"space_id": space_id, "user_id": user.id, "member_id": member.id},
            )
            return member
        member = await self.require_active_member(db, space_id=space_id, user=user)
        if member.role != "admin":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Space admin required")
        logger.debug(
            "Validated space admin",
            extra={"space_id": space_id, "user_id": user.id, "member_id": member.id},
        )
        return member

    async def list_my_spaces(self, db: AsyncSession, user: User) -> List[Space]:
        stmt = (
            select(Space)
            .join(SpaceMember, SpaceMember.space_id == Space.id)
            .where(
                and_(
                    SpaceMember.user_id == user.id,
                    SpaceMember.status == "active",
                    Space.is_active.is_(True),
                )
            )
            .order_by(Space.created_at.desc())
        )
        rows = (await db.execute(stmt)).scalars().all()
        logger.debug("User listing spaces", extra={"user_id": user.id, "count": len(rows)})
        return rows

    async def list_available_spaces(self, db: AsyncSession, user: User) -> List[Space]:
        member_subquery = (
            select(SpaceMember.space_id)
            .where(
                and_(
                    SpaceMember.user_id == user.id,
                    SpaceMember.status != "revoked",
                )
            )
        )
        stmt = (
            select(Space)
            .where(
                and_(
                    Space.is_active.is_(True),
                    ~Space.id.in_(member_subquery),
                )
            )
            .order_by(Space.created_at.desc())
        )
        rows = (await db.execute(stmt)).scalars().all()
        logger.debug("User listing available spaces", extra={"user_id": user.id, "count": len(rows)})
        return rows

    async def get_default_space_id_for_user(self, db: AsyncSession, user: User) -> str | None:
        """Return a default active space ID for the user.

        Used when the caller doesn't yet send `X-Space-Id`.
        """
        stmt = (
            select(SpaceMember.space_id)
            .join(Space, Space.id == SpaceMember.space_id)
            .where(
                and_(
                    SpaceMember.user_id == user.id,
                    SpaceMember.status == "active",
                    Space.is_active.is_(True),
                )
            )
            .order_by(SpaceMember.created_at.asc())
            .limit(1)
        )
        return (await db.execute(stmt)).scalars().first()

    async def create_space(self, db: AsyncSession, *, name: str, creator: User) -> Space:
        default_bucket = (getattr(settings, "AWS_S3_BUCKET", "") or "").strip()
        if not default_bucket:
            logger.error("Storage bucket not configured; cannot create space", extra={"user_id": creator.id})
            raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Storage bucket not configured")

        per_space_enabled = bool(getattr(settings, "AWS_S3_PER_SPACE_BUCKET", False))
        bucket_prefix = (getattr(settings, "AWS_S3_SPACE_BUCKET_PREFIX", "") or "").strip().lower()

        # Default to shared bucket unless explicitly configured for per-space buckets.
        target_bucket = default_bucket

        if per_space_enabled:
            if not bucket_prefix:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="Per-space bucket mode requires AWS_S3_SPACE_BUCKET_PREFIX",
                )

            # Create the space record first to get a stable UUID.
            space = Space(
                name=name,
                s3_bucket=default_bucket,  # temporary; updated after bucket creation
                created_by_user_id=creator.id,
                allowed_models=list(getattr(settings, "DEFAULT_ALLOWED_MODELS", []) or []),
                allowed_tools=list(getattr(settings, "DEFAULT_ALLOWED_TOOLS", []) or []),
            )
            db.add(space)
            await db.flush()

            candidate = f"{bucket_prefix}-{space.id}".lower()
            target_bucket = candidate[:63].rstrip("-")
            if not await s3_service.create_bucket(target_bucket):
                logger.error(
                    "Unable to create per-space bucket",
                    extra={"bucket": target_bucket, "space_id": space.id, "user_id": creator.id},
                )
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="Unable to create space storage bucket",
                )
            space.s3_bucket = target_bucket
        else:
            # Shared bucket mode (default)
            if not await s3_service.create_bucket(default_bucket):
                logger.error("Unable to access shared bucket", extra={"bucket": default_bucket})
                raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Storage bucket unavailable")

            space = Space(
                name=name,
                s3_bucket=default_bucket,
                created_by_user_id=creator.id,
                allowed_models=list(getattr(settings, "DEFAULT_ALLOWED_MODELS", []) or []),
                allowed_tools=list(getattr(settings, "DEFAULT_ALLOWED_TOOLS", []) or []),
            )
            db.add(space)
            await db.flush()

        storage_prefix = f"spaces/{space.id}"
        # Prefix is still useful in per-space buckets to keep objects organized.
        await s3_service.ensure_prefix(space.s3_bucket, storage_prefix)
        logger.info(
            "Created space",
            extra={
                "space_id": space.id,
                "space_name": space.name,
                "creator_id": creator.id,
                "bucket": space.s3_bucket,
                "prefix": storage_prefix,
            },
        )
        db.add(SpaceMember(space_id=space.id, user_id=creator.id, role="admin", status="active"))
        await db.flush()
        return space

    async def update_space(self, db: AsyncSession, *, space: Space, name: str | None, is_active: bool | None) -> Space:
        if name is not None:
            space.name = name
        if is_active is not None:
            space.is_active = bool(is_active)
        await db.flush()
        logger.info(
            "Updated space",
            extra={"space_id": space.id, "space_name": space.name, "is_active": space.is_active},
        )
        return space

    async def update_policy(self, db: AsyncSession, *, space: Space, **fields) -> Space:
        from src.services.notifications.service import notification_service
        from src.services.notifications.broadcaster import broadcaster
        
        self._validate_quota_fields(fields)
        for key, value in fields.items():
            if value is None:
                continue
            if key == "allowed_models":
                space.allowed_models = list(value)
            elif key == "allowed_tools":
                space.allowed_tools = list(value)
            else:
                setattr(space, key, value)
        await db.flush()
        
        # Notify all active members about policy update
        stmt = select(SpaceMember).where(
            and_(
                SpaceMember.space_id == space.id,
                SpaceMember.status == "active"
            )
        )
        members = (await db.execute(stmt)).scalars().all()
        
        for member in members:
            notification = await notification_service.notify_policy_updated(
                db,
                user_id=member.user_id,
                space_id=space.id,
                space_name=space.name,
            )
            # Broadcast real-time
            await broadcaster.broadcast_to_user(
                member.user_id,
                "notification",
                {
                    "id": notification.id,
                    "type": notification.type,
                    "title": notification.title,
                    "message": notification.message,
                    "link": notification.link,
                    "read": False,
                    "created_at": notification.created_at.isoformat(),
                }
            )
        
        logger.info(
            "Updated space policy",
            extra={
                "space_id": space.id,
                "allowed_models": space.allowed_models,
                "allowed_tools": getattr(space, "allowed_tools", None),
                "daily_token_limit": space.daily_token_limit,
                "monthly_token_limit": space.monthly_token_limit,
                "daily_request_limit": space.daily_request_limit,
                "monthly_request_limit": space.monthly_request_limit,
                "daily_tool_request_limit": getattr(space, "daily_tool_request_limit", None),
                "monthly_tool_request_limit": getattr(space, "monthly_tool_request_limit", None),
            },
        )
        return space

    async def invite_member(self, db: AsyncSession, *, space: Space, inviter: User, email: str) -> SpaceInvite:
        from src.services.email.service import email_service
        
        token = secrets.token_urlsafe(32)
        invite = SpaceInvite(
            space_id=space.id,
            email=email.lower().strip(),
            invited_by_user_id=inviter.id,
            token=token,
            status="pending",
            expires_at=datetime.utcnow() + timedelta(hours=self.INVITE_TTL_HOURS),
        )
        db.add(invite)
        await db.flush()
        
        # Send invitation email
        email_service.send_space_invitation_email(
            to_email=invite.email,
            space_name=space.name,
            inviter_name=inviter.email,
            invite_token=token,
        )
        
        logger.info(
            "Invited member",
            extra={"space_id": space.id, "inviter_id": inviter.id, "email": invite.email},
        )
        return invite

    async def accept_invite(self, db: AsyncSession, *, token: str, user: User) -> SpaceMember:
        stmt = select(SpaceInvite).where(SpaceInvite.token == token)
        invite = (await db.execute(stmt)).scalars().first()
        if invite is None or invite.status != "pending":
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invite not found")
        if invite.expires_at is not None and invite.expires_at < datetime.utcnow():
            invite.status = "expired"
            await db.flush()
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invite expired")
        if invite.email.lower() != user.email.lower():
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invite email mismatch")

        member = await self.get_member(db, space_id=invite.space_id, user_id=user.id)
        if member is None:
            member = SpaceMember(space_id=invite.space_id, user_id=user.id, role="member", status="active")
            db.add(member)
        else:
            member.status = "active"
        invite.status = "accepted"
        await db.flush()
        logger.info(
            "Accepted invite",
            extra={"space_id": invite.space_id, "user_id": user.id, "member_id": member.id},
        )
        return member

    async def list_members(self, db: AsyncSession, *, space_id: str) -> List[SpaceMember]:
        stmt = select(SpaceMember).where(SpaceMember.space_id == space_id).order_by(SpaceMember.created_at.asc())
        rows = (await db.execute(stmt)).scalars().all()
        logger.debug("Listed space members", extra={"space_id": space_id, "count": len(rows)})
        return rows

    async def update_member(
        self,
        db: AsyncSession,
        *,
        member: SpaceMember,
        role: str | None,
        status_value: str | None,
        can_upload_documents: bool | None,
        overrides: dict | None,
    ) -> SpaceMember:
        if role is not None:
            role = role.strip().lower()
            if role not in {"admin", "member"}:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid member role")
            member.role = role
        if status_value is not None:
            status_value = status_value.strip().lower()
            if status_value not in {"active", "revoked"}:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid member status")
            member.status = status_value
        if can_upload_documents is not None:
            member.can_upload_documents = bool(can_upload_documents)
        if overrides:
            self._validate_quota_fields(overrides)
            # Map UpdatePolicyRequest-style payload.
            if "allowed_models" in overrides and overrides["allowed_models"] is not None:
                member.allowed_models = list(overrides["allowed_models"])
            if "allowed_tools" in overrides and overrides["allowed_tools"] is not None:
                member.allowed_tools = list(overrides["allowed_tools"])
            for k in (
                "daily_token_limit",
                "monthly_token_limit",
                "daily_request_limit",
                "monthly_request_limit",
                "daily_tool_request_limit",
                "monthly_tool_request_limit",
            ):
                if k in overrides and overrides[k] is not None:
                    setattr(member, k, overrides[k])
        await db.flush()
        logger.info(
            "Updated member",
            extra={
                "member_id": member.id,
                "space_id": member.space_id,
                "user_id": member.user_id,
                "role": member.role,
                "status": member.status,
            },
        )
        return member

    async def create_request(self, db: AsyncSession, *, space_id: str, user: User, type_value: str, payload: dict) -> SpaceRequest:
        req = SpaceRequest(space_id=space_id, user_id=user.id, type=type_value, payload=payload or {}, status="pending")
        db.add(req)
        await db.flush()
        logger.info(
            "Created space request",
            extra={"space_id": space_id, "request_id": req.id, "type": type_value, "user_id": user.id},
        )
        return req

    async def find_pending_request(self, db: AsyncSession, *, space_id: str, user_id: str, type_value: str) -> Optional[SpaceRequest]:
        stmt = select(SpaceRequest).where(
            and_(
                SpaceRequest.space_id == space_id,
                SpaceRequest.user_id == user_id,
                SpaceRequest.type == type_value,
                SpaceRequest.status == "pending",
            )
        )
        return (await db.execute(stmt)).scalars().first()

    async def list_user_requests(self, db: AsyncSession, *, user_id: str) -> List[SpaceRequest]:
        stmt = select(SpaceRequest).where(SpaceRequest.user_id == user_id).order_by(SpaceRequest.created_at.desc())
        return list((await db.execute(stmt)).scalars().all())

    async def list_requests(self, db: AsyncSession, *, space_id: str, status_filter: str | None = None) -> List[SpaceRequest]:
        stmt = select(SpaceRequest).where(SpaceRequest.space_id == space_id)
        if status_filter:
            stmt = stmt.where(SpaceRequest.status == status_filter)
        stmt = stmt.order_by(SpaceRequest.created_at.desc())
        rows = (await db.execute(stmt)).scalars().all()
        logger.debug(
            "Listed space requests", extra={"space_id": space_id, "count": len(rows), "status": status_filter}
        )
        return rows

    async def review_request(self, db: AsyncSession, *, req: SpaceRequest, reviewer: User, decision: str, note: str | None) -> SpaceRequest:
        from src.services.notifications.service import notification_service
        from src.services.notifications.broadcaster import broadcaster
        from src.services.email.service import email_service
        
        decision = decision.strip().lower()
        if decision not in {"approved", "declined"}:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid decision")
        
        req.status = decision
        req.review_note = note
        req.reviewed_by_user_id = reviewer.id
        req.reviewed_at = datetime.utcnow()

        if decision == "approved":
            await self._apply_approved_request(db, req=req)
        
        await db.flush()
        
        # Get space and user for notification
        space = await self._ensure_space(db, req.space_id)
        user = await self._ensure_user(db, req.user_id)
        
        # Send notification
        if decision == "approved":
            notification = await notification_service.notify_request_approved(
                db,
                user_id=req.user_id,
                space_id=req.space_id,
                space_name=space.name,
                request_type=req.type,
            )
        else:
            notification = await notification_service.notify_request_declined(
                db,
                user_id=req.user_id,
                space_id=req.space_id,
                space_name=space.name,
                request_type=req.type,
                reason=note,
            )
        
        # Broadcast real-time notification
        await broadcaster.broadcast_to_user(
            req.user_id,
            "notification",
            {
                "id": notification.id,
                "type": notification.type,
                "title": notification.title,
                "message": notification.message,
                "link": notification.link,
                "read": False,
                "created_at": notification.created_at.isoformat(),
            }
        )
        
        # Send email notification
        email_service.send_request_status_email(
            to_email=user.email,
            space_name=space.name,
            request_type=req.type,
            status=decision,
            reviewer_note=note,
        )
        
        logger.info(
            "Reviewed space request",
            extra={
                "space_id": req.space_id,
                "request_id": req.id,
                "decision": decision,
                "reviewer_id": reviewer.id,
            },
        )
        return req

    async def _apply_approved_request(self, db: AsyncSession, *, req: SpaceRequest) -> None:
        type_value = (req.type or "").strip().lower()

        if type_value == "join":
            member = await self.get_member(db, space_id=req.space_id, user_id=req.user_id)
            if member is None:
                db.add(SpaceMember(space_id=req.space_id, user_id=req.user_id, role="member", status="active"))
            else:
                member.status = "active"
            logger.info(
                "Approved join request",
                extra={"space_id": req.space_id, "request_id": req.id, "user_id": req.user_id},
            )
            return

        member = await self.get_member(db, space_id=req.space_id, user_id=req.user_id)
        if member is None or member.status != "active":
            # For non-join requests, user must be an active member.
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Request user is not an active member")

        payload = req.payload or {}

        if type_value == "model_access":
            requested = []
            if isinstance(payload.get("allowed_models"), list):
                requested = [str(x).strip() for x in payload.get("allowed_models") if str(x).strip()]
            elif payload.get("model"):
                requested = [str(payload.get("model")).strip()]
            requested = [m for m in requested if m]
            if requested:
                existing = list(member.allowed_models or []) if member.allowed_models is not None else []
                merged = sorted(set(existing).union(requested))
                member.allowed_models = merged
                logger.info(
                    "Granted model access",
                    extra={
                        "space_id": req.space_id,
                        "request_id": req.id,
                        "user_id": req.user_id,
                        "models": merged,
                    },
                )
            return

        if type_value == "tool_access":
            requested = []
            if isinstance(payload.get("allowed_tools"), list):
                requested = [str(x).strip() for x in payload.get("allowed_tools") if str(x).strip()]
            elif payload.get("tool"):
                requested = [str(payload.get("tool")).strip()]
            requested = [t for t in requested if t]
            if requested:
                existing = list(member.allowed_tools or []) if member.allowed_tools is not None else []
                merged = sorted(set(existing).union(requested))
                member.allowed_tools = merged
                logger.info(
                    "Granted tool access",
                    extra={
                        "space_id": req.space_id,
                        "request_id": req.id,
                        "user_id": req.user_id,
                        "tools": merged,
                    },
                )
            return

        if type_value == "upload_access":
            # Allow upload permission for the requesting member
            allow_upload = payload.get("can_upload_documents", True)
            member.can_upload_documents = bool(allow_upload)
            logger.info(
                "Updated upload permission",
                extra={
                    "space_id": req.space_id,
                    "request_id": req.id,
                    "user_id": req.user_id,
                    "can_upload_documents": member.can_upload_documents,
                },
            )
            return

        if type_value == "quota_change":
            self._validate_quota_fields(payload)
            for key in ("daily_token_limit", "monthly_token_limit", "daily_request_limit", "monthly_request_limit"):
                if key in payload and payload[key] is not None:
                    try:
                        setattr(member, key, int(payload[key]))
                    except Exception:
                        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid {key}")
            if "allowed_models" in payload and payload["allowed_models"] is not None:
                if not isinstance(payload["allowed_models"], list):
                    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="allowed_models must be a list")
                member.allowed_models = [str(x).strip() for x in payload["allowed_models"] if str(x).strip()]
            logger.info(
                "Updated member quotas",
                extra={
                    "space_id": req.space_id,
                    "request_id": req.id,
                    "user_id": req.user_id,
                    "payload": payload,
                },
            )
            return

    async def usage_summary(self, db: AsyncSession, *, space_id: str, days: int = 30):
        days_i = max(1, min(int(days or 30), 365))
        end = datetime.utcnow()
        start = end - timedelta(days=days_i)

        base = (
            select(
                LLMUsageEvent.model,
                func.coalesce(func.sum(LLMUsageEvent.input_tokens), 0),
                func.coalesce(func.sum(LLMUsageEvent.output_tokens), 0),
                func.coalesce(func.sum(LLMUsageEvent.total_tokens), 0),
                func.coalesce(func.sum(LLMUsageEvent.request_count), 0),
                func.coalesce(func.sum(LLMUsageEvent.cost_usd), 0.0),
            )
            .where(
                LLMUsageEvent.space_id == space_id,
                LLMUsageEvent.created_at >= start,
                LLMUsageEvent.created_at <= end,
            )
            .group_by(LLMUsageEvent.model)
        )
        rows = (await db.execute(base)).all()
        return start, end, rows

    async def superadmin_usage_rollup(self, db: AsyncSession, *, days: int = 30) -> list[SuperAdminUsageRow]:
        days_i = max(1, min(int(days or 30), 365))
        end = datetime.utcnow()
        start = end - timedelta(days=days_i)

        stmt = (
            select(
                Space.id,
                Space.name,
                func.coalesce(func.sum(LLMUsageEvent.input_tokens), 0),
                func.coalesce(func.sum(LLMUsageEvent.output_tokens), 0),
                func.coalesce(func.sum(LLMUsageEvent.total_tokens), 0),
                func.coalesce(func.sum(LLMUsageEvent.request_count), 0),
                func.coalesce(func.sum(LLMUsageEvent.cost_usd), 0.0),
            )
            .select_from(Space)
            .outerjoin(LLMUsageEvent, and_(LLMUsageEvent.space_id == Space.id, LLMUsageEvent.created_at >= start, LLMUsageEvent.created_at <= end))
            .group_by(Space.id, Space.name)
            .order_by(Space.name.asc())
        )

        rows = (await db.execute(stmt)).all()
        result: list[SuperAdminUsageRow] = []
        for space_id, name, inp, out, tot, reqs, cost in rows:
            totals = UsageTotals(
                input_tokens=int(inp or 0),
                output_tokens=int(out or 0),
                total_tokens=int(tot or 0),
                requests=int(reqs or 0),
                cost_usd=round(float(cost or 0.0), 6) if cost is not None else None,
            )
            result.append(SuperAdminUsageRow(space_id=space_id, space_name=name, start=start, end=end, totals=totals))
        return result

    async def get_dashboard_stats(self, db: AsyncSession) -> DashboardStats:
        """Get comprehensive dashboard statistics."""
        # 1. Basic Counts
        total_users = await db.scalar(select(func.count(User.id))) or 0
        active_spaces = await db.scalar(select(func.count(Space.id)).where(Space.is_active == True)) or 0
        total_messages = await db.scalar(select(func.count(ChatMessage.id))) or 0
        total_sessions = await db.scalar(select(func.count(ChatSession.id))) or 0
        total_documents = await db.scalar(select(func.count(Document.id))) or 0
        total_requests = await db.scalar(select(func.count(SpaceRequest.id))) or 0

        thirty_days_ago = datetime.utcnow() - timedelta(days=30)
        new_users_30d = await db.scalar(select(func.count(User.id)).where(User.created_at >= thirty_days_ago)) or 0
        active_users_30d = (
            await db.scalar(
                select(func.count(func.distinct(ChatSession.user_id))).where(ChatSession.updated_at >= thirty_days_ago)
            )
            or 0
        )
        admins_count = (
            await db.scalar(select(func.count(User.id)).where(User.role.in_(["admin", "super_admin"])))
            or 0
        )
        members_count = max(int(total_users) - int(admins_count), 0)
        
        # 2. Usage Totals
        usage_res = (await db.execute(
            select(
                func.sum(LLMUsageEvent.total_tokens),
                func.sum(LLMUsageEvent.cost_usd)
            )
        )).first()
        total_tokens = int(usage_res[0] or 0)
        total_cost = float(usage_res[1] or 0.0)
        
        # 3. Top Models (by usage count)
        top_models_res = (await db.execute(
            select(
                LLMUsageEvent.model,
                func.count(LLMUsageEvent.id),
                func.sum(LLMUsageEvent.cost_usd)
            )
            .where(LLMUsageEvent.model.isnot(None))
            .group_by(LLMUsageEvent.model)
            .order_by(func.count(LLMUsageEvent.id).desc())
            .limit(5)
        )).all()
        top_models = [
            TopModelStats(name=row[0], usage=row[1], cost=float(row[2] or 0)) 
            for row in top_models_res
        ]
        
        # 4. Usage by Space (Top 20 by cost)
        space_usage_res = (await db.execute(
            select(
                Space.id,
                Space.name,
                func.sum(LLMUsageEvent.total_tokens),
                func.count(LLMUsageEvent.id),
                func.sum(LLMUsageEvent.cost_usd)
            )
            .join(Space, Space.id == LLMUsageEvent.space_id)
            .group_by(Space.id, Space.name)
            .order_by(func.sum(LLMUsageEvent.cost_usd).desc())
            .limit(20)
        )).all()
        usage_by_space = [
            SpaceUsageStats(
                space_id=row[0], 
                space_name=row[1], 
                tokens=int(row[2] or 0), 
                requests=int(row[3] or 0),
                cost=float(row[4] or 0)
            )
            for row in space_usage_res
        ]

        # 5. Daily Usage (Last 30 days)
        daily_res = (await db.execute(
            select(
                func.date_trunc('day', LLMUsageEvent.created_at).label('day'),
                func.sum(LLMUsageEvent.total_tokens),
                func.count(LLMUsageEvent.id),
                func.sum(LLMUsageEvent.cost_usd)
            )
            .where(LLMUsageEvent.created_at >= thirty_days_ago)
            .group_by('day')
            .order_by('day')
        )).all()
        daily_usage = [
            DailyUsageStats(
                date=row[0].strftime("%Y-%m-%d") if row[0] else "", 
                tokens=int(row[1] or 0), 
                requests=int(row[2] or 0), 
                cost=float(row[3] or 0)
            )
            for row in daily_res
        ]
        
        return DashboardStats(
            total_users=total_users,
            active_spaces=active_spaces,
            total_messages=total_messages,
            total_sessions=total_sessions,
            total_documents=total_documents,
            total_requests=total_requests,
            new_users_30d=new_users_30d,
            active_users_30d=active_users_30d,
            admins_count=admins_count,
            members_count=members_count,
            total_tokens=total_tokens,
            total_cost=total_cost,
            avg_response_time=0.0, # Placeholder
            success_rate=100.0, # Placeholder
            top_models=top_models,
            usage_by_space=usage_by_space,
            daily_usage=daily_usage,
            tool_usage=[] # Placeholder
        )


    

    async def get_space_dashboard_stats(self, db: AsyncSession, space_id: str) -> DashboardStats:
        """Get dashboard statistics for a specific space."""
        # 1. Basic Counts
        total_users = await db.scalar(select(func.count(SpaceMember.id)).where(SpaceMember.space_id == space_id)) or 0
        active_spaces = 1
        total_sessions = (
            await db.scalar(select(func.count(ChatSession.id)).where(ChatSession.space_id == space_id))
            or 0
        )
        total_documents = (
            await db.scalar(select(func.count(Document.id)).where(Document.space_id == space_id))
            or 0
        )
        total_requests = (
            await db.scalar(select(func.count(SpaceRequest.id)).where(SpaceRequest.space_id == space_id))
            or 0
        )

        thirty_days_ago = datetime.utcnow() - timedelta(days=30)
        new_users_30d = (
            await db.scalar(
                select(func.count(SpaceMember.id)).where(
                    and_(SpaceMember.space_id == space_id, SpaceMember.created_at >= thirty_days_ago)
                )
            )
            or 0
        )
        active_users_30d = (
            await db.scalar(
                select(func.count(func.distinct(ChatSession.user_id))).where(
                    and_(ChatSession.space_id == space_id, ChatSession.updated_at >= thirty_days_ago)
                )
            )
            or 0
        )
        admins_count = (
            await db.scalar(
                select(func.count(SpaceMember.id)).where(
                    and_(SpaceMember.space_id == space_id, SpaceMember.role == "admin")
                )
            )
            or 0
        )
        members_count = max(int(total_users) - int(admins_count), 0)
        
        # Messages in space
        total_messages = await db.scalar(
            select(func.count(ChatMessage.id))
            .join(ChatSession, ChatMessage.session_id == ChatSession.id)
            .where(ChatSession.space_id == space_id)
        ) or 0
        
        # 2. Usage Totals
        usage_res = (await db.execute(
            select(
                func.sum(LLMUsageEvent.total_tokens),
                func.sum(LLMUsageEvent.cost_usd)
            ).where(LLMUsageEvent.space_id == space_id)
        )).first()
        total_tokens = int(usage_res[0] or 0)
        total_cost = float(usage_res[1] or 0.0)
        
        # 3. Top Models (by usage count)
        top_models_res = (await db.execute(
            select(
                LLMUsageEvent.model,
                func.count(LLMUsageEvent.id),
                func.sum(LLMUsageEvent.cost_usd)
            )
            .where(and_(LLMUsageEvent.model.isnot(None), LLMUsageEvent.space_id == space_id))
            .group_by(LLMUsageEvent.model)
            .order_by(func.count(LLMUsageEvent.id).desc())
            .limit(5)
        )).all()
        top_models = [
            TopModelStats(name=row[0], usage=row[1], cost=float(row[2] or 0)) 
            for row in top_models_res
        ]
        
        # 4. Usage by Space (Single space)
        usage_by_space = [
            SpaceUsageStats(
                space_id=space_id, 
                space_name="Current Space", 
                tokens=total_tokens, 
                requests=int(await db.scalar(select(func.count(LLMUsageEvent.id)).where(LLMUsageEvent.space_id == space_id)) or 0),
                cost=total_cost
            )
        ]

        # 5. Daily Usage (Last 30 days)
        daily_res = (await db.execute(
            select(
                func.date_trunc('day', LLMUsageEvent.created_at).label('day'),
                func.sum(LLMUsageEvent.total_tokens),
                func.count(LLMUsageEvent.id),
                func.sum(LLMUsageEvent.cost_usd)
            )
            .where(and_(LLMUsageEvent.created_at >= thirty_days_ago, LLMUsageEvent.space_id == space_id))
            .group_by('day')
            .order_by('day')
        )).all()
        daily_usage = [
            DailyUsageStats(
                date=row[0].strftime("%Y-%m-%d") if row[0] else "", 
                tokens=int(row[1] or 0), 
                requests=int(row[2] or 0), 
                cost=float(row[3] or 0)
            )
            for row in daily_res
        ]
        
        return DashboardStats(
            total_users=total_users,
            active_spaces=active_spaces,
            total_messages=total_messages,
            total_sessions=total_sessions,
            total_documents=total_documents,
            total_requests=total_requests,
            new_users_30d=new_users_30d,
            active_users_30d=active_users_30d,
            admins_count=admins_count,
            members_count=members_count,
            total_tokens=total_tokens,
            total_cost=total_cost,
            avg_response_time=0.0,
            success_rate=100.0, 
            top_models=top_models,
            usage_by_space=usage_by_space,
            daily_usage=daily_usage,
            tool_usage=[] 
        )


spaces_service = SpacesService()
