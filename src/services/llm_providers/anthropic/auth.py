"""Anthropic authentication."""

from __future__ import annotations

from src.core.settings.config import settings


def get_anthropic_api_key() -> str:
	api_key = (settings.ANTHROPIC_API_KEY or "").strip()
	if not api_key:
		raise RuntimeError("ANTHROPIC_API_KEY is not configured")
	return api_key


def anthropic_headers() -> dict[str, str]:
	return {
		"x-api-key": get_anthropic_api_key(),
		"anthropic-version": "2023-06-01",
	}
