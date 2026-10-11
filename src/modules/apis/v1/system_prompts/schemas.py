"""Schemas for system prompt management."""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, Field


class SystemPrompts(BaseModel):
    tools_system_prompt: str = Field(..., min_length=1)
    web_search_decision_prompt: str = Field(..., min_length=1)
    memory_system_prompt: str = Field(..., min_length=1)
    stream_system_prompt: str = Field(..., min_length=1)
    answer_question_system_prompt: str = Field(..., min_length=1)


class SystemPromptsUpdate(BaseModel):
    tools_system_prompt: Optional[str] = None
    web_search_decision_prompt: Optional[str] = None
    memory_system_prompt: Optional[str] = None
    stream_system_prompt: Optional[str] = None
    answer_question_system_prompt: Optional[str] = None
