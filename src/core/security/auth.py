"""Authentication helpers for JWT issuance and validation."""

from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

from fastapi import HTTPException, status
from jose import JWTError, jwt

from src.core.settings.config import settings


def _get_secret_key() -> str:
	if not settings.SECRET_KEY:
		raise RuntimeError("SECRET_KEY is not configured")
	return settings.SECRET_KEY


def create_access_token(
	subject: str,
	*,
	scopes: Optional[list[str]] = None,
	expires_delta: Optional[timedelta] = None,
	extra_claims: Optional[Dict[str, Any]] = None,
) -> str:
	"""Create a signed JWT for the provided subject."""
	expires_delta = expires_delta or timedelta(hours=settings.JWT_EXPIRATION_HOURS)
	expire = datetime.now(timezone.utc) + expires_delta
	to_encode: Dict[str, Any] = {
		"sub": subject,
		"scopes": scopes or [],
		"exp": expire,
	}
	if extra_claims:
		to_encode.update(extra_claims)
	return jwt.encode(to_encode, _get_secret_key(), algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> Dict[str, Any]:
	"""Decode and validate a JWT access token."""
	try:
		return jwt.decode(token, _get_secret_key(), algorithms=[settings.JWT_ALGORITHM])
	except JWTError as exc:
		raise HTTPException(
			status_code=status.HTTP_401_UNAUTHORIZED,
			detail="Invalid authentication credentials",
			headers={"WWW-Authenticate": "Bearer"},
		) from exc
