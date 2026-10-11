"""Authentication schemas."""

from __future__ import annotations

from datetime import date, datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, EmailStr, Field, field_validator


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
    # Core identity
    first_name: Optional[str] = Field(default=None, max_length=100)
    last_name: Optional[str] = Field(default=None, max_length=100)
    date_of_birth: Optional[date] = Field(
        default=None,
        description="ISO-8601 date. Must be at least 18 years in the past.",
    )
    phone_number: Optional[str] = Field(default=None, max_length=30)
    country: Optional[str] = Field(default=None, max_length=80)
    # Professional context
    job_title: Optional[str] = Field(default=None, max_length=120)
    company: Optional[str] = Field(default=None, max_length=150)
    # AI personalisation
    industry: Optional[str] = Field(
        default=None,
        max_length=120,
        description="User's professional industry for AI personalisation (e.g. Fintech, Law)",
    )
    preferred_language: Optional[str] = Field(
        default=None,
        max_length=10,
        description="BCP-47 language tag for preferred response language (e.g. en, ar, fr)",
    )

    @field_validator("date_of_birth", mode="after")
    @classmethod
    def must_be_18_or_older(cls, v: Optional[date]) -> Optional[date]:
        if v is None:
            return v
        today = datetime.utcnow().date()
        age = today.year - v.year - ((today.month, today.day) < (v.month, v.day))
        if age < 18:
            raise ValueError("User must be at least 18 years old to register")
        return v


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


class ValidateResetTokenRequest(BaseModel):
    token: str = Field(..., min_length=1, max_length=256)


class ValidateResetTokenResponse(BaseModel):
    valid: bool


class ResetPasswordRequest(BaseModel):
    """Reset an account password via provided token."""

    token: str = Field(..., min_length=1, max_length=256)
    new_password: str = Field(..., min_length=8)


class ChangePasswordRequest(BaseModel):
    """Change password for an authenticated user."""

    current_password: str = Field(..., min_length=8)
    new_password: str = Field(..., min_length=8)


class ChangePasswordResponse(BaseModel):
    """Response after changing password."""

    message: str
