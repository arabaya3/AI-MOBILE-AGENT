"""OpenAI request/response schemas."""

from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, Field


class OpenAIMessage(BaseModel):
	role: str
	content: str


class OpenAIChatRequest(BaseModel):
	model: str
	messages: List[OpenAIMessage]
	temperature: Optional[float] = None


class OpenAIChoice(BaseModel):
	index: int
	message: OpenAIMessage


class OpenAIUsage(BaseModel):
	prompt_tokens: int = 0
	completion_tokens: int = 0
	total_tokens: int = 0


class OpenAIChatResponse(BaseModel):
	id: str
	model: str
	choices: List[OpenAIChoice]
	usage: Optional[OpenAIUsage] = None
