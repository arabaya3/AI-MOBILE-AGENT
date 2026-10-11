"""Shared FastAPI dependencies for authentication and authorization."""

from typing import Callable, Optional

from fastapi import Depends, Header, HTTPException, Query, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.security.auth import decode_access_token
from src.modules.apis.v1.auth.service import auth_service
from src.services.databases.postgresql.database import get_db
from src.services.databases.postgresql.models import User


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/token")
oauth2_optional_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/token", auto_error=False)


async def _get_user_from_token(token: str, db: AsyncSession) -> User:
	payload = decode_access_token(token)
	user_id = payload.get("sub")
	if not user_id:
		raise HTTPException(
			status_code=status.HTTP_401_UNAUTHORIZED,
			detail="Invalid authentication credentials",
			headers={"WWW-Authenticate": "Bearer"},
		)
	user = await auth_service.get_user_by_id(db, user_id)
	if user is None or not user.is_active:
		raise HTTPException(
			status_code=status.HTTP_401_UNAUTHORIZED,
			detail="Inactive or unknown user",
			headers={"WWW-Authenticate": "Bearer"},
		)
	return user


async def get_current_user(
	token: str = Depends(oauth2_scheme),
	db: AsyncSession = Depends(get_db),
) -> User:
	"""Return the authenticated user for Bearer tokens."""
	return await _get_user_from_token(token, db)


async def get_optional_current_user(
	token: Optional[str] = Depends(oauth2_optional_scheme),
	db: AsyncSession = Depends(get_db),
) -> Optional[User]:
	"""Return the authenticated user when a token is supplied, else None."""
	if not token:
		return None
	try:
		return await _get_user_from_token(token, db)
	except HTTPException:
		return None


async def get_current_space_id(
	space_id: str | None = Header(default=None, alias="X-Space-Id"),
	space_id_query: str | None = Query(default=None, alias="space_id"),
	user: User = Depends(get_current_user),
	db: AsyncSession = Depends(get_db),
) -> str:
	"""Resolve the active space for this request.

	The UI may call space-scoped endpoints immediately after login before a space
	is selected. When `X-Space-Id` is missing, fall back to the caller's first
	active space membership (or any active space for super admins).
	"""
	requested_space_id = None
	if space_id and space_id.strip():
		requested_space_id = space_id.strip()
	elif space_id_query and space_id_query.strip():
		requested_space_id = space_id_query.strip()

	if requested_space_id:
		from sqlalchemy import select
		from src.services.databases.postgresql.models import Space
		from src.modules.apis.v1.spaces.service import spaces_service

		space = await db.get(Space, requested_space_id)
		if space is None or not space.is_active:
			raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Space not found")

		# Super admins may operate across spaces; others must be active members.
		if user.role != "super_admin":
			await spaces_service.require_active_member(db, space_id=requested_space_id, user=user)
		return requested_space_id

	from src.modules.apis.v1.spaces.service import spaces_service

	default_space = await spaces_service.get_default_space_id_for_user(db, user)
	if default_space:
		return default_space

	# Super admins may not be members of every space; pick the newest active space as a fallback.
	if user.role == "super_admin":
		from sqlalchemy import select
		from src.services.databases.postgresql.models import Space

		row = (await db.execute(select(Space.id).where(Space.is_active.is_(True)).order_by(Space.created_at.desc()).limit(1))).scalar()
		if row:
			return row

	raise HTTPException(
		status_code=status.HTTP_400_BAD_REQUEST,
		detail="No active space selected. Create a space or accept an invite token.",
	)


def require_space_roles(*space_roles: str) -> Callable[[User], User]:
	"""Ensure the caller is a member of the active space with one of the allowed space roles."""

	async def dependency(
		user: User = Depends(get_current_user),
		space_id: str = Depends(get_current_space_id),
		db: AsyncSession = Depends(get_db),
	) -> User:
		from src.modules.apis.v1.spaces.service import spaces_service

		member = await spaces_service.require_active_member(db, space_id=space_id, user=user)
		if space_roles and member.role not in space_roles:
			raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not enough permissions")
		return user

	return dependency


def require_space_document_uploader() -> Callable[[User], User]:
	"""Allow uploads for space admins or members with can_upload_documents."""

	async def dependency(
		user: User = Depends(get_current_user),
		space_id: str = Depends(get_current_space_id),
		db: AsyncSession = Depends(get_db),
	) -> User:
		from src.modules.apis.v1.spaces.service import spaces_service

		# Global super_admin can upload anywhere.
		if user.role == "super_admin":
			return user

		member = await spaces_service.require_active_member(db, space_id=space_id, user=user)
		if member.role == "admin" or bool(getattr(member, "can_upload_documents", False)):
			return user
		raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Upload permission required")

	return dependency


def require_roles(*roles: str) -> Callable[[User], User]:
	"""Ensure the caller has one of the allowed roles."""

	async def dependency(user: User = Depends(get_current_user)) -> User:
		if user.role not in roles:
			raise HTTPException(
				status_code=status.HTTP_403_FORBIDDEN,
				detail="Not enough permissions",
			)
		return user

	return dependency
