"""Authentication schemas."""

from enum import Enum
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


class UserRole(str, Enum):
    """Supported user roles."""

    SUPER_ADMIN = "super_admin"
    ADMIN = "admin"
    VIEWER = "viewer"


class SignUpRequest(BaseModel):
    """Payload for creating a new user account."""

    email: EmailStr
    password: str = Field(..., min_length=8)
    role: Optional[UserRole] = Field(default=UserRole.VIEWER)


class UserResponse(BaseModel):
    """Public view of a user profile."""

    user_id: str = Field(..., alias="id")
    email: EmailStr
    role: UserRole

    class Config:
        populate_by_name = True


class UserListResponse(BaseModel):
    """List of users."""

    users: list[UserResponse]


class LoginRequest(BaseModel):
    """User login payload."""

    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    """Access token response body."""

    access_token: str
    token_type: str = Field(default="bearer")
    expires_in: int


class ForgotPasswordRequest(BaseModel):
    """Request password reset link."""

    email: EmailStr


class ForgotPasswordResponse(BaseModel):
    """Response after initiating password reset."""

    message: str
    reset_token: Optional[str] = None


class ResetPasswordRequest(BaseModel):
    """Reset an account password via provided token."""

    token: str
    new_password: str = Field(..., min_length=8)


class ChangePasswordRequest(BaseModel):
    """Change password for an authenticated user."""

    current_password: str = Field(..., min_length=8)
    new_password: str = Field(..., min_length=8)


class ChangePasswordResponse(BaseModel):
    """Response after changing password."""

    message: str
