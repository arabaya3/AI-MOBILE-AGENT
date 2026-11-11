"""System prompts: the global configuration (super admins only) and personal overrides (owner only).

Generation reads only the global configuration (`get_system_prompts`). Personal overrides are
stored per user but are not applied to replies.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.settings.system_prompts import get_system_prompts, save_system_prompts
from src.modules.apis.dependencies import get_current_user, require_roles
from src.modules.apis.v1.system_prompts.schemas import PersonalPrompts, SystemPrompts, SystemPromptsUpdate
from src.services.databases.postgresql.database import get_db
from src.services.databases.postgresql.models import User


router = APIRouter(prefix="/system-prompts", tags=["system-prompts"])

require_super_admin = require_roles("super_admin")


@router.get("/global", response_model=SystemPrompts)
async def get_global_prompts(_: User = Depends(require_super_admin)) -> SystemPrompts:
    return SystemPrompts.model_validate(get_system_prompts())


@router.put("/global", response_model=SystemPrompts)
async def update_global_prompts(payload: SystemPromptsUpdate, _: User = Depends(require_super_admin)) -> SystemPrompts:
    """Changes the prompts used for every user and space."""
    return SystemPrompts.model_validate(save_system_prompts(payload.model_dump(exclude_none=True)))


def _personal(user: User) -> PersonalPrompts:
    stored = user.custom_system_prompts if isinstance(user.custom_system_prompts, dict) else {}
    known = set(SystemPromptsUpdate.model_fields)
    return PersonalPrompts(overrides={k: v for k, v in stored.items() if k in known and isinstance(v, str)})


@router.get("/me", response_model=PersonalPrompts)
async def get_personal_prompts(user: User = Depends(get_current_user)) -> PersonalPrompts:
    """The caller's own overrides only; never the global configuration."""
    return _personal(user)


@router.put("/me", response_model=PersonalPrompts)
async def update_personal_prompts(
    payload: SystemPromptsUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PersonalPrompts:
    """Stores the caller's overrides (an empty string removes one). Never changes global prompts."""
    overrides = dict(_personal(user).overrides)
    for key, value in payload.model_dump(exclude_none=True).items():
        if value.strip():
            overrides[key] = value
        else:
            overrides.pop(key, None)
    user.custom_system_prompts = overrides
    db.add(user)
    await db.flush()
    return _personal(user)
