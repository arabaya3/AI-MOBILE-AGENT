"""Revocable, expiring conversation share links."""

from __future__ import annotations

import hashlib
import logging
import re
import secrets
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.settings.config import settings
from src.modules.apis.dependencies import get_current_space_id, get_current_user
from src.services.databases.postgresql.database import get_db
from src.services.databases.postgresql.models import (
    ChatMessage,
    ChatSession,
    ChatShare,
    Space,
    SpaceMember,
    User,
)

SHARED_PATH_PREFIX = "/api/v1/chat/shared/"
_SHARED_TOKEN_RE = re.compile(re.escape(SHARED_PATH_PREFIX) + r"[^\s?\"']+")

router = APIRouter(prefix="/chat", tags=["chat-sharing"])


class CreateShareRequest(BaseModel):
    expires_in_hours: Optional[int] = Field(default=None, ge=1)


class ShareCreatedResponse(BaseModel):
    share_id: str
    token: str
    share_url: str
    expires_at: datetime


class ShareSummary(BaseModel):
    share_id: str
    created_at: datetime
    expires_at: datetime
    revoked_at: Optional[datetime] = None
    active: bool


class SharedMessage(BaseModel):
    role: str
    content: str
    created_at: datetime


class SharedConversation(BaseModel):
    title: str
    shared_at: datetime
    expires_at: datetime
    messages: List[SharedMessage]


def redact_share_path(path: str) -> str:
    if path.startswith(SHARED_PATH_PREFIX):
        return f"{SHARED_PATH_PREFIX}{{token}}"
    return path


class ShareTokenLogFilter(logging.Filter):
    """Masks share tokens in uvicorn access log records."""

    def filter(self, record: logging.LogRecord) -> bool:
        if isinstance(record.args, tuple) and SHARED_PATH_PREFIX in str(record.args):
            record.args = tuple(
                _SHARED_TOKEN_RE.sub(f"{SHARED_PATH_PREFIX}{{token}}", a) if isinstance(a, str) else a
                for a in record.args
            )
        return True


def _utcnow() -> datetime:
    return datetime.utcnow()


def hash_share_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _not_found() -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shared conversation not found")


async def _owned_session(db: AsyncSession, session_id: str, user: User, space_id: str) -> ChatSession:
    session = await db.get(ChatSession, session_id)
    if session is None or session.user_id != user.id or session.space_id != space_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    return session


def _summary(share: ChatShare, now: datetime) -> ShareSummary:
    return ShareSummary(
        share_id=share.id,
        created_at=share.created_at,
        expires_at=share.expires_at,
        revoked_at=share.revoked_at,
        active=share.revoked_at is None and share.expires_at > now,
    )


@router.post("/sessions/{session_id}/share", response_model=ShareCreatedResponse, status_code=status.HTTP_201_CREATED)
async def create_share(
    session_id: str,
    payload: Optional[CreateShareRequest] = None,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> ShareCreatedResponse:
    if not settings.CHAT_SHARE_ENABLED:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Conversation sharing is disabled")
    session = await _owned_session(db, session_id, user, space_id)
    space = await db.get(Space, space_id)
    if space is None or not space.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Space is not active")

    hours = (payload.expires_in_hours if payload else None) or settings.CHAT_SHARE_DEFAULT_TTL_HOURS
    if hours > settings.CHAT_SHARE_MAX_TTL_HOURS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"expires_in_hours must be at most {settings.CHAT_SHARE_MAX_TTL_HOURS}",
        )

    token = secrets.token_urlsafe(32)
    now = _utcnow()
    share = ChatShare(
        session_id=session.id,
        space_id=space_id,
        created_by_user_id=user.id,
        token_hash=hash_share_token(token),
        created_at=now,
        expires_at=now + timedelta(hours=hours),
    )
    db.add(share)
    await db.flush()
    return ShareCreatedResponse(
        share_id=share.id,
        token=token,
        share_url=f"{SHARED_PATH_PREFIX}{token}",
        expires_at=share.expires_at,
    )


@router.get("/sessions/{session_id}/shares", response_model=List[ShareSummary])
async def list_shares(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> List[ShareSummary]:
    await _owned_session(db, session_id, user, space_id)
    rows = await db.execute(
        select(ChatShare)
        .where(ChatShare.session_id == session_id, ChatShare.created_by_user_id == user.id)
        .order_by(ChatShare.created_at.desc())
    )
    now = _utcnow()
    return [_summary(share, now) for share in rows.scalars()]


@router.delete("/shares/{share_id}", response_model=ShareSummary)
async def revoke_share(
    share_id: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ShareSummary:
    share = await db.get(ChatShare, share_id)
    if share is None or share.created_by_user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Share not found")
    now = _utcnow()
    if share.revoked_at is None:
        share.revoked_at = now
        await db.flush()
    return _summary(share, now)


@router.get("/shared/{token}", response_model=SharedConversation)
async def view_shared(token: str, response: Response, db: AsyncSession = Depends(get_db)) -> SharedConversation:
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["X-Robots-Tag"] = "noindex"

    if not settings.CHAT_SHARE_ENABLED or not token or len(token) > 128:
        raise _not_found()
    share = (
        await db.execute(select(ChatShare).where(ChatShare.token_hash == hash_share_token(token)))
    ).scalar_one_or_none()
    now = _utcnow()
    if share is None or share.revoked_at is not None or share.expires_at <= now:
        raise _not_found()

    session = await db.get(ChatSession, share.session_id)
    space = await db.get(Space, share.space_id)
    owner = await db.get(User, share.created_by_user_id)
    membership = (
        await db.execute(
            select(SpaceMember).where(
                SpaceMember.space_id == share.space_id,
                SpaceMember.user_id == share.created_by_user_id,
            )
        )
    ).scalar_one_or_none()
    owner_is_super_admin = owner is not None and owner.role == "super_admin"
    if (
        session is None
        or session.user_id != share.created_by_user_id
        or session.space_id != share.space_id
        or space is None
        or not space.is_active
        or owner is None
        or not owner.is_active
        or not (owner_is_super_admin or (membership is not None and membership.status == "active"))
    ):
        raise _not_found()

    rows = await db.execute(
        select(ChatMessage)
        .where(
            ChatMessage.session_id == session.id,
            ChatMessage.created_at <= share.created_at,
            ChatMessage.role.in_(("user", "assistant")),
        )
        .order_by(ChatMessage.created_at.asc())
    )
    return SharedConversation(
        title=session.title or "Shared conversation",
        shared_at=share.created_at,
        expires_at=share.expires_at,
        messages=[SharedMessage(role=m.role, content=m.content, created_at=m.created_at) for m in rows.scalars()],
    )
