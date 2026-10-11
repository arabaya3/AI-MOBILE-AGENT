"""Authentication service layer."""

from __future__ import annotations

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.security.encryption import hash_password, verify_password
from src.core.settings.config import settings
from src.services.databases.postgresql.models import PasswordResetToken, User

def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class AuthService:
    """Business logic for user authentication flows."""

    async def get_user_by_email(self, db: AsyncSession, email: str) -> Optional[User]:
        stmt = select(User).where(User.email == email.lower())
        result = await db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_user_by_id(self, db: AsyncSession, user_id: str) -> Optional[User]:
        stmt = select(User).where(User.id == user_id)
        result = await db.execute(stmt)
        return result.scalar_one_or_none()

    async def create_user(
        self,
        db: AsyncSession,
        *,
        email: str,
        password: str,
        role: str,
        first_name: str | None = None,
        last_name: str | None = None,
        date_of_birth=None,
        phone_number: str | None = None,
        country: str | None = None,
        job_title: str | None = None,
        company: str | None = None,
        industry: str | None = None,
        preferred_language: str | None = None,
    ) -> User:
        existing = await self.get_user_by_email(db, email)
        if existing is not None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")
        user = User(
            email=email.lower(),
            hashed_password=hash_password(password),
            role=role,
            first_name=first_name or None,
            last_name=last_name or None,
            date_of_birth=date_of_birth or None,
            phone_number=phone_number or None,
            country=country or None,
            job_title=job_title or None,
            company=company or None,
            industry=industry or None,
            preferred_language=preferred_language or None,
        )
        db.add(user)
        await db.flush()
        return user

    async def authenticate_user(self, db: AsyncSession, *, email: str, password: str) -> User:
        user = await self.get_user_by_email(db, email)
        if user is None or not verify_password(password, user.hashed_password):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
        if not user.is_active:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Inactive account")
        return user

    async def set_user_password(self, db: AsyncSession, user: User, new_password: str) -> None:
        user.hashed_password = hash_password(new_password)
        await db.flush()

    async def create_password_reset_token(self, db: AsyncSession, user: User) -> str:
        await self._invalidate_reset_tokens(db, user.id)
        token = secrets.token_urlsafe(32)
        db.add(
            PasswordResetToken(
                user_id=user.id,
                token_hash=_hash_token(token),
                expires_at=_utcnow() + timedelta(minutes=settings.PASSWORD_RESET_TTL_MINUTES),
            )
        )
        await db.flush()
        return token

    async def _find_valid_reset_token(
        self, db: AsyncSession, token: str, *, for_update: bool = False
    ) -> Optional[PasswordResetToken]:
        stmt = select(PasswordResetToken).where(PasswordResetToken.token_hash == _hash_token(token))
        if for_update:
            stmt = stmt.with_for_update()
        record = (await db.execute(stmt)).scalar_one_or_none()
        if record is None or record.used or record.expires_at <= _utcnow():
            return None
        return record

    async def is_reset_token_valid(self, db: AsyncSession, token: str) -> bool:
        return await self._find_valid_reset_token(db, token) is not None

    async def reset_password(self, db: AsyncSession, *, token: str, new_password: str) -> None:
        record = await self._find_valid_reset_token(db, token, for_update=True)
        user = await self.get_user_by_id(db, record.user_id) if record else None
        if record is None or user is None or not user.is_active:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired token")
        await self.set_user_password(db, user, new_password)
        await self._invalidate_reset_tokens(db, user.id)

    async def _invalidate_reset_tokens(self, db: AsyncSession, user_id: str) -> None:
        await db.execute(
            update(PasswordResetToken)
            .where(PasswordResetToken.user_id == user_id, PasswordResetToken.used.is_(False))
            .values(used=True)
        )


auth_service = AuthService()
