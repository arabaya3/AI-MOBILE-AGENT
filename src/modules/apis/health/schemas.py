"""Health check response schemas."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
	"""Base health response model."""

	status: str = Field(..., examples=["ok"])
	service: str = Field(..., examples=["Lex-Tech-ai-agents"])
	version: str = Field(..., examples=["0.1.0"])
	timestamp: datetime = Field(default_factory=datetime.utcnow)
	details: Optional[dict] = Field(default=None)

