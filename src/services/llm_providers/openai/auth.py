"""OpenAI authentication."""

from __future__ import annotations

from src.core.settings.config import settings


def get_openai_api_key() -> str:
	api_key = (settings.OPENAI_API_KEY or "").strip()
	if not api_key:
		raise RuntimeError("OPENAI_API_KEY is not configured")
	return api_key


def openai_headers() -> dict[str, str]:
	return {"Authorization": f"Bearer {get_openai_api_key()}"}
