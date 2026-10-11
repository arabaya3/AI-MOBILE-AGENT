"""Authentication service layer."""

from __future__ import annotations

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.security.encryption import hash_password, verify_password
from src.services.databases.postgresql.models import PasswordResetToken, User

RESET_TOKEN_TTL_HOURS = 1


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
        token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        record = PasswordResetToken(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=datetime.now(timezone.utc) + timedelta(hours=RESET_TOKEN_TTL_HOURS),
        )
        db.add(record)
        await db.flush()
        return token

    async def reset_password(self, db: AsyncSession, *, token: str, new_password: str) -> None:
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        stmt = select(PasswordResetToken).where(PasswordResetToken.token_hash == token_hash)
        result = await db.execute(stmt)
        reset_token = result.scalar_one_or_none()
        if (
            reset_token is None
            or reset_token.used
            or reset_token.expires_at < datetime.now(timezone.utc)
        ):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired token")
        user = await self.get_user_by_id(db, reset_token.user_id)
        if user is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
        await self.set_user_password(db, user, new_password)
        reset_token.used = True
        await db.flush()


auth_service = AuthService()
