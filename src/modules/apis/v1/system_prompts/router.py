"""API routes for managing system prompts."""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.settings.system_prompts import get_system_prompts
from src.modules.apis.dependencies import get_current_user
from src.modules.apis.v1.system_prompts.schemas import SystemPrompts, SystemPromptsUpdate
from src.services.databases.postgresql.database import get_db
from src.services.databases.postgresql.models import User


router = APIRouter(prefix="/system-prompts", tags=["system-prompts"])


@router.get("", response_model=SystemPrompts)
async def get_prompts(user: User = Depends(get_current_user)) -> SystemPrompts:
    """Get system prompts, merging global defaults with user overrides."""
    global_prompts = get_system_prompts()
    user_prompts = user.custom_system_prompts or {}
    
    # Merge: user prompts override global
    merged = {**global_prompts, **user_prompts}
    
    return SystemPrompts.model_validate(merged)


@router.put("", response_model=SystemPrompts)
async def update_prompts(
    payload: SystemPromptsUpdate, 
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> SystemPrompts:
    """Update user-specific system prompts."""
    # Get current user prompts
    current_user_prompts = user.custom_system_prompts or {}
    if not isinstance(current_user_prompts, dict):
        current_user_prompts = {}
        
    # Update with new values
    new_updates = payload.model_dump(exclude_none=True)
    updated_user_prompts = {**current_user_prompts, **new_updates}
    
    # Save to DB
    user.custom_system_prompts = updated_user_prompts
    db.add(user)
    await db.commit()
    await db.refresh(user)
    
    # Return full merged view
    global_prompts = get_system_prompts()
    merged = {**global_prompts, **updated_user_prompts}
    
    return SystemPrompts.model_validate(merged)
