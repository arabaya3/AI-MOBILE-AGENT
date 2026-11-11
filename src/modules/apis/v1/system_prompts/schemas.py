"""Schemas for system prompt management."""

from __future__ import annotations

from typing import Dict, Optional

from pydantic import BaseModel, Field


MAX_PROMPT = 20_000


class SystemPrompts(BaseModel):
    tools_system_prompt: str = Field(..., min_length=1)
    web_search_decision_prompt: str = Field(..., min_length=1)
    memory_system_prompt: str = Field(..., min_length=1)
    stream_system_prompt: str = Field(..., min_length=1)
    answer_question_system_prompt: str = Field(..., min_length=1)


class SystemPromptsUpdate(BaseModel):
    tools_system_prompt: Optional[str] = Field(default=None, max_length=MAX_PROMPT)
    web_search_decision_prompt: Optional[str] = Field(default=None, max_length=MAX_PROMPT)
    memory_system_prompt: Optional[str] = Field(default=None, max_length=MAX_PROMPT)
    stream_system_prompt: Optional[str] = Field(default=None, max_length=MAX_PROMPT)
    answer_question_system_prompt: Optional[str] = Field(default=None, max_length=MAX_PROMPT)


class PersonalPrompts(BaseModel):
    overrides: Dict[str, str] = Field(default_factory=dict)
    # Stated explicitly: replies are generated with the global prompts only.
    applied_to_generation: bool = False
