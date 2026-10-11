"""Authentication handlers."""

from typing import Optional

from fastapi import BackgroundTasks, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.security.auth import create_access_token
from src.core.settings.config import settings
from src.core.settings.logging import logger
from src.modules.apis.v1.auth.schemas import (
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    ResetPasswordRequest,
    ChangePasswordRequest,
    ChangePasswordResponse,
    SignUpRequest,
    TokenResponse,
    UserResponse,
    UserRole,
    ValidateResetTokenRequest,
    ValidateResetTokenResponse,
)
from src.modules.apis.v1.auth.service import auth_service
from src.services.databases.postgresql.models import User
from src.services.email.service import email_service


async def handle_signup(
    payload: SignUpRequest,
    db: AsyncSession,
    current_user: Optional[User],
) -> UserResponse:
    """Register a new user with optional admin-provided role."""

    desired_role = (payload.role or UserRole.VIEWER).value
    if payload.role and payload.role != UserRole.VIEWER:
        if payload.role == UserRole.SUPER_ADMIN:
            if current_user is None or current_user.role != UserRole.SUPER_ADMIN.value:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Super admin approval required for super_admin role",
                )
        else:
            if current_user is None or current_user.role not in {UserRole.ADMIN.value, UserRole.SUPER_ADMIN.value}:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin approval required for elevated roles")
    user = await auth_service.create_user(
        db,
        email=payload.email,
        password=payload.password,
        role=desired_role,
        first_name=payload.first_name or None,
        last_name=payload.last_name or None,
        date_of_birth=payload.date_of_birth or None,
        phone_number=payload.phone_number or None,
        country=payload.country or None,
        job_title=payload.job_title or None,
        company=payload.company or None,
        industry=payload.industry or None,
        preferred_language=payload.preferred_language or None,
    )
    return UserResponse(id=user.id, email=user.email, role=user.role)


async def handle_login(payload: LoginRequest, db: AsyncSession) -> TokenResponse:
    """Authenticate a user and emit a JWT."""

    user = await auth_service.authenticate_user(db, email=payload.email, password=payload.password)
    expires_in = settings.JWT_EXPIRATION_HOURS * 3600
    token = create_access_token(
        subject=user.id,
        scopes=[user.role],
    )
    return TokenResponse(access_token=token, expires_in=expires_in)


FORGOT_PASSWORD_MESSAGE = "If an account exists for this email, a password reset link has been sent."


async def handle_forgot_password(
    payload: ForgotPasswordRequest, db: AsyncSession, background_tasks: BackgroundTasks
) -> ForgotPasswordResponse:
    """Issue a reset link by email; the response never reveals whether the account exists."""

    user = await auth_service.get_user_by_email(db, payload.email)
    if user is not None and user.is_active:
        if not email_service.enabled:
            logger.warning("Password reset requested but email delivery is disabled", extra={"user_id": user.id})
        else:
            token = await auth_service.create_password_reset_token(db, user)
            await db.commit()
            background_tasks.add_task(email_service.send_password_reset_email, user.email, token, user.first_name)
    return ForgotPasswordResponse(message=FORGOT_PASSWORD_MESSAGE)


async def handle_validate_reset_token(payload: ValidateResetTokenRequest, db: AsyncSession) -> ValidateResetTokenResponse:
    return ValidateResetTokenResponse(valid=await auth_service.is_reset_token_valid(db, payload.token))


async def handle_reset_password(payload: ResetPasswordRequest, db: AsyncSession) -> dict[str, str]:
    """Apply a password reset token."""

    await auth_service.reset_password(db, token=payload.token, new_password=payload.new_password)
    return {"message": "Password updated successfully"}


async def handle_change_password(
    payload: ChangePasswordRequest,
    user: User,
    db: AsyncSession,
) -> ChangePasswordResponse:
    """Change password for the authenticated user after verifying current password."""
    # Verify current password
    from src.core.security.encryption import verify_password

    if not verify_password(payload.current_password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Current password is incorrect")

    await auth_service.set_user_password(db, user, payload.new_password)
    return ChangePasswordResponse(message="Password updated successfully")


async def handle_list_users(db: AsyncSession):
    """List all users."""
    from src.modules.apis.v1.auth.schemas import UserListResponse
    from sqlalchemy import select
    
    result = await db.execute(select(User))
    users = result.scalars().all()
    return UserListResponse(
        users=[UserResponse(id=u.id, email=u.email, role=u.role) for u in users]
    )
