"""Authentication API routes."""

from typing import Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.apis.dependencies import get_current_user, get_optional_current_user
from src.services.databases.postgresql.database import get_db
from src.services.databases.postgresql.models import User

from .handlers import (
    handle_forgot_password,
    handle_login,
    handle_reset_password,
    handle_signup,
    handle_validate_reset_token,
)
from .schemas import (
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    ResetPasswordRequest,
    ChangePasswordRequest,
    ChangePasswordResponse,
    SignUpRequest,
    TokenResponse,
    UserListResponse,
    UserResponse,
    ValidateResetTokenRequest,
    ValidateResetTokenResponse,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def signup(
    payload: SignUpRequest,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_current_user),
) -> UserResponse:
    """Register a new account."""

    return await handle_signup(payload, db, current_user)


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)) -> TokenResponse:
    """Obtain a JWT by exchanging credentials.
    
    **Request Body:**
    - `email` (string, required): User email address
    - `password` (string, required): User password
    
    **Example:**
    ```json
    {
        "email": "user@example.com",
        "password": "securepassword123"
    }
    ```
    """
    return await handle_login(payload, db)


@router.post(
    "/token",
    response_model=TokenResponse,
    summary="OAuth2 token",
    description="OAuth2 Password Flow endpoint for Swagger UI (x-www-form-urlencoded).",
)
async def token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Obtain a JWT using OAuth2 Password Flow.

    Swagger's built-in Authorize button uses `username`/`password` form fields.
    We map `username` to our email-based login.
    """
    payload = LoginRequest(email=form_data.username, password=form_data.password)
    return await handle_login(payload, db)


@router.post("/forgot-password", response_model=ForgotPasswordResponse)
async def forgot_password(
    payload: ForgotPasswordRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
) -> ForgotPasswordResponse:
    """Start the password reset flow."""

    return await handle_forgot_password(payload, db, background_tasks)


@router.post("/reset-password/validate", response_model=ValidateResetTokenResponse)
async def validate_reset_token(
    payload: ValidateResetTokenRequest, db: AsyncSession = Depends(get_db)
) -> ValidateResetTokenResponse:
    """Check whether a reset token is still usable without consuming it."""

    return await handle_validate_reset_token(payload, db)


@router.post("/reset-password")
async def reset_password(payload: ResetPasswordRequest, db: AsyncSession = Depends(get_db)) -> dict[str, str]:
    """Complete password reset."""

    return await handle_reset_password(payload, db)


@router.post("/change-password", response_model=ChangePasswordResponse)
async def change_password(
    payload: ChangePasswordRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ChangePasswordResponse:
    """Change password for the authenticated user."""
    from .handlers import handle_change_password

    return await handle_change_password(payload, current_user, db)


@router.get("/users", response_model=UserListResponse)
async def list_users(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_optional_current_user),
) -> UserListResponse:
    """List all users (admin only)."""
    from .handlers import handle_list_users
    
    if not current_user or current_user.role not in {"admin", "super_admin"}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    
    return await handle_list_users(db)
