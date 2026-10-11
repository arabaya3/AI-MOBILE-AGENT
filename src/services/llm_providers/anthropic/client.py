"""Anthropic client wrapper."""

from __future__ import annotations

from typing import Any

from anthropic import Anthropic
from tenacity import retry, stop_after_attempt, wait_exponential_jitter

from src.core.settings.config import settings


class AnthropicClient:
	def __init__(self) -> None:
		self._client: Anthropic | None = None

	def _get_client(self) -> Anthropic:
		if self._client is None:
			if not settings.ANTHROPIC_API_KEY:
				raise RuntimeError("ANTHROPIC_API_KEY is not configured")
			self._client = Anthropic(api_key=settings.ANTHROPIC_API_KEY, base_url=(settings.ANTHROPIC_BASE_URL or None))
		return self._client

	@retry(stop=stop_after_attempt(3), wait=wait_exponential_jitter(min=0.5, max=4))
	def messages(self, **kwargs: Any) -> Any:
		return self._get_client().messages.create(**kwargs)


anthropic_client = AnthropicClient()
