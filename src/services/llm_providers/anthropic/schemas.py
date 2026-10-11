"""Anthropic request/response schemas."""

from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, Field


class AnthropicMessage(BaseModel):
	role: str
	content: str


class AnthropicMessageRequest(BaseModel):
	model: str
	max_tokens: int = Field(default=1024)
	messages: List[AnthropicMessage]


class AnthropicContentBlock(BaseModel):
	type: str
	text: Optional[str] = None


class AnthropicUsage(BaseModel):
	input_tokens: int = 0
	output_tokens: int = 0


class AnthropicMessageResponse(BaseModel):
	id: str
	model: str
	content: List[AnthropicContentBlock]
	usage: Optional[AnthropicUsage] = None
