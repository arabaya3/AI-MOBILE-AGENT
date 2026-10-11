"""OpenAI utilities."""

from __future__ import annotations

from typing import List

import tiktoken


def count_tokens(text: str, model: str = "gpt-4o-mini") -> int:
	try:
		enc = tiktoken.encoding_for_model(model)
	except Exception:  # noqa: BLE001
		enc = tiktoken.get_encoding("cl100k_base")
	return len(enc.encode(text or ""))


def count_message_tokens(messages: List[dict], model: str = "gpt-4o-mini") -> int:
	return sum(count_tokens((m.get("content") or ""), model=model) for m in messages)
