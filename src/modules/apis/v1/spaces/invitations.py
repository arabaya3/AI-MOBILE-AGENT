"""Space invitations: random tokens delivered only by email, stored as SHA-256 hashes.

Rules
- One open invitation per space and address; inviting again rotates its token (a resend).
- Rotating, revoking or accepting invalidates the previous token. Accepted invitations are single use.
- The recipient must be signed in with the invited address, and the space must be active.
- No email delivery means no invitation: the token is never returned by the API.
"""

from __future__ import annotations

import asyncio
import hashlib
import secrets
from datetime import datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.settings.logging import logger
from src.services.databases.postgresql.models import Space, SpaceInvite, SpaceMember, User

INVITE_TTL = timedelta(days=7)
NOT_VALID = "Invitation not found or no longer valid"


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def effective_status(invite: SpaceInvite, now: datetime | None = None) -> str:
    if invite.status == "pending" and invite.expires_at is not None and invite.expires_at <= (now or datetime.utcnow()):
        return "expired"
    return invite.status


async def _deliver(space: Space, inviter: User, email: str, token: str) -> None:
    from src.services.email.service import email_service

    sent = await asyncio.to_thread(
        email_service.send_space_invitation_email,
        to_email=email,
        space_name=space.name,
        inviter_name=inviter.email,
        invite_token=token,
    )
    if not sent:
        # Raising rolls the request back, so no unusable invitation or rotated token is kept.
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Invitation email could not be sent")


def _rotate(invite: SpaceInvite) -> str:
    token = secrets.token_urlsafe(32)
    now = datetime.utcnow()
    invite.token_hash = hash_token(token)
    invite.status = "pending"
    invite.expires_at = now + INVITE_TTL
    invite.last_sent_at = now
    return token


async def _open_invite(db: AsyncSession, space_id: str, email: str) -> SpaceInvite | None:
    stmt = (
        select(SpaceInvite)
        .where(SpaceInvite.space_id == space_id, func.lower(SpaceInvite.email) == email, SpaceInvite.status == "pending")
        .with_for_update()
    )
    return (await db.execute(stmt)).scalars().first()


async def create_or_resend(db: AsyncSession, *, space: Space, inviter: User, email: str) -> SpaceInvite:
    email = email.strip().lower()
    if not space.is_active:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This space is not active")
    existing_user = (await db.execute(select(User).where(func.lower(User.email) == email))).scalars().first()
    if existing_user is not None:
        member = (
            await db.execute(select(SpaceMember).where(SpaceMember.space_id == space.id, SpaceMember.user_id == existing_user.id))
        ).scalars().first()
        if member is not None and member.status == "active":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Already a member of this space")

    invite = await _open_invite(db, space.id, email)
    if invite is not None:
        token = _rotate(invite)
        invite.send_count = (invite.send_count or 1) + 1
        invite.invited_by_user_id = inviter.id
    else:
        invite = SpaceInvite(space_id=space.id, email=email, invited_by_user_id=inviter.id, send_count=1)
        token = _rotate(invite)
        try:
            async with db.begin_nested():
                db.add(invite)
                await db.flush()
        except IntegrityError:
            # A concurrent request opened the invitation first; rotate that one instead.
            invite = await _open_invite(db, space.id, email)
            if invite is None:
                raise
            token = _rotate(invite)
            invite.send_count = (invite.send_count or 1) + 1
    await db.flush()
    await _deliver(space, inviter, email, token)
    logger.info("Space invitation sent", extra={"space_id": space.id, "invite_id": invite.id, "inviter_id": inviter.id})
    return invite


async def _get_for_admin(db: AsyncSession, space_id: str, invite_id: str) -> SpaceInvite:
    invite = (
        await db.execute(select(SpaceInvite).where(SpaceInvite.id == invite_id, SpaceInvite.space_id == space_id).with_for_update())
    ).scalars().first()
    if invite is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invitation not found")
    return invite


async def resend(db: AsyncSession, *, space: Space, inviter: User, invite_id: str) -> SpaceInvite:
    invite = await _get_for_admin(db, space.id, invite_id)
    if invite.status not in {"pending", "expired"}:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Only open or expired invitations can be resent")
    if invite.status == "expired":
        other = await _open_invite(db, space.id, invite.email.lower())
        if other is not None and other.id != invite.id:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="A newer invitation is already open")
    if not space.is_active:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This space is not active")
    token = _rotate(invite)
    invite.send_count = (invite.send_count or 1) + 1
    invite.invited_by_user_id = inviter.id
    await db.flush()
    await _deliver(space, inviter, invite.email, token)
    return invite


async def revoke(db: AsyncSession, *, space_id: str, invite_id: str) -> SpaceInvite:
    invite = await _get_for_admin(db, space_id, invite_id)
    if invite.status == "accepted":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This invitation was already accepted")
    if invite.status != "revoked":
        invite.status = "revoked"
        invite.token_hash = None
        invite.responded_at = datetime.utcnow()
        await db.flush()
    return invite


async def list_for_space(db: AsyncSession, *, space_id: str) -> list[SpaceInvite]:
    stmt = select(SpaceInvite).where(SpaceInvite.space_id == space_id).order_by(SpaceInvite.created_at.desc())
    return list((await db.execute(stmt)).scalars().all())


async def accept(db: AsyncSession, *, token: str, user: User) -> SpaceMember:
    if not token or len(token) > 256:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=NOT_VALID)
    # The row lock makes concurrent acceptances of one token run one after another.
    invite = (
        await db.execute(select(SpaceInvite).where(SpaceInvite.token_hash == hash_token(token)).with_for_update())
    ).scalars().first()
    if invite is None or invite.status not in {"pending", "expired"}:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=NOT_VALID)
    if effective_status(invite) == "expired":
        invite.status = "expired"
        await db.commit()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invitation expired")
    space = await db.get(Space, invite.space_id)
    if space is None or not space.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=NOT_VALID)
    if (user.email or "").strip().lower() != invite.email.strip().lower():
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="This invitation was sent to a different email address")

    member = (
        await db.execute(select(SpaceMember).where(SpaceMember.space_id == space.id, SpaceMember.user_id == user.id).with_for_update())
    ).scalars().first()
    if member is None:
        member = SpaceMember(space_id=space.id, user_id=user.id, role="member", status="active")
        db.add(member)
    elif member.status != "active":
        # A revoked or pending member returns as an ordinary member; earlier admin rights are not restored.
        member.status = "active"
        member.role = "member"
    invite.status = "accepted"
    invite.token_hash = None
    invite.accepted_by_user_id = user.id
    invite.responded_at = datetime.utcnow()
    await db.flush()
    logger.info("Accepted invite", extra={"space_id": space.id, "user_id": user.id, "invite_id": invite.id})
    return member
