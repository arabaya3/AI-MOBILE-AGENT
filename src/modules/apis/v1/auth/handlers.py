"""Authentication handlers."""

from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.security.auth import create_access_token
from src.core.settings.config import settings
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
)
from src.modules.apis.v1.auth.service import auth_service
from src.services.databases.postgresql.models import User


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


async def handle_forgot_password(payload: ForgotPasswordRequest, db: AsyncSession) -> ForgotPasswordResponse:
    """Initiate password reset and return opaque token for local use."""

    user = await auth_service.get_user_by_email(db, payload.email)
    if user is None:
        # Do not leak which emails exist
        return ForgotPasswordResponse(message="If the email exists, a reset token has been created.")
    token = await auth_service.create_password_reset_token(db, user)
    return ForgotPasswordResponse(
        message="Reset token created. Provide it to /reset-password to complete the flow.",
        reset_token=token,
    )


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
