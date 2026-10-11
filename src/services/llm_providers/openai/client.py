"""OpenAI client wrapper."""

from __future__ import annotations

from typing import Any, Dict

from openai import OpenAI
from tenacity import retry, stop_after_attempt, wait_exponential_jitter

from src.core.settings.config import settings


class OpenAIClient:
	def __init__(self) -> None:
		self._client: OpenAI | None = None

	def _get_client(self) -> OpenAI:
		if self._client is None:
			if not settings.OPENAI_API_KEY:
				raise RuntimeError("OPENAI_API_KEY is not configured")
			self._client = OpenAI(api_key=settings.OPENAI_API_KEY, base_url=(settings.OPENAI_BASE_URL or None))
		return self._client

	@retry(stop=stop_after_attempt(3), wait=wait_exponential_jitter(min=0.5, max=4))
	def chat_completion(self, **kwargs: Any) -> Any:
		return self._get_client().chat.completions.create(**kwargs)

	@retry(stop=stop_after_attempt(3), wait=wait_exponential_jitter(min=0.5, max=4))
	def embeddings(self, **kwargs: Any) -> Any:
		return self._get_client().embeddings.create(**kwargs)


openai_client = OpenAIClient()
