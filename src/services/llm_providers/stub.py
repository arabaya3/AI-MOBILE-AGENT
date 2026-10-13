"""Deterministic chat provider for local end-to-end tests. Never calls a paid API.

Enabled only when CHAT_PROVIDER_STUB=true AND APP_ENV is development or test
(see provider.py). Directives in the user's message select a scenario:
  [[fail-before]] provider failure before any output
  [[fail-after]]  provider failure after partial output
  [[raise]]       unexpected server exception
  [[slow]]        40 chunks, 250 ms apart (stop / disconnect tests)
  [[long]]        200 quick chunks (scrolling tests)
  [[md]]          Markdown sample with a link and code
"""

from __future__ import annotations

import asyncio
from typing import Any, Dict, List

STUB_MODELS = ["teia-stub-1", "teia-stub-2"]
PROVIDER_ERROR_MARKER = "[stream_error]"

_MARKDOWN_SAMPLE = (
    "## Summary\n\n"
    "- First point with **bold** text\n"
    "- Second point: الشؤون القانونية\n\n"
    "See [the documentation](https://example.com/docs) for details.\n\n"
    "```python\nprint('hello')\n```\n"
)


class StubChatProvider:
    model = STUB_MODELS[0]

    async def list_models(self) -> List[str]:
        return list(STUB_MODELS)

    def _is_chat_model_id(self, model_id: str) -> bool:
        return model_id in STUB_MODELS

    async def decide_web_search(self, **_: Any) -> Dict[str, Any]:
        return {"use_web_search": False}

    async def answer_with_memory(self, *, question: str, usage_sink: Dict[str, int] | None = None, **_: Any) -> str:
        if usage_sink is not None:
            usage_sink.update({"input_tokens": 40, "output_tokens": 12, "total_tokens": 52})
        if "executive summary" in question.lower():
            return "## Overview\n\nStub summary of the conversation.\n\n## Next Steps\n\n- None"
        return f"Stub answer: {question}"

    async def stream_with_memory(
        self,
        *,
        question: str,
        usage_sink: Dict[str, int] | None = None,
        contexts: List[Dict[str, Any]] | None = None,
        **_: Any,
    ):
        chunks: List[str]
        delay = 0.0
        if "[[md]]" in question:
            chunks = [_MARKDOWN_SAMPLE[i : i + 12] for i in range(0, len(_MARKDOWN_SAMPLE), 12)]
        elif "[[slow]]" in question:
            chunks, delay = [f"word{i} " for i in range(40)], 0.25
        elif "[[long]]" in question:
            chunks = [f"Line {i}: stub output.\n" for i in range(200)]
        else:
            text = f"Echo: {question.replace('[[fail-after]]', '').strip()}"
            if contexts:
                text += f"\n\nAnswered from {len(contexts)} document excerpt(s)."
            chunks = [text[i : i + 6] for i in range(0, len(text), 6)]

        if "[[raise]]" in question:
            raise RuntimeError("stub provider crashed")
        if "[[fail-before]]" in question:
            chunks = []

        emitted = 0
        for chunk in chunks[: 3 if "[[fail-after]]" in question else None]:
            if delay:
                await asyncio.sleep(delay)
            emitted += len(chunk)
            yield chunk

        if usage_sink is not None:
            usage_sink.update({"input_tokens": 30, "output_tokens": emitted // 4 + 1, "total_tokens": 31 + emitted // 4})
        if "[[fail-before]]" in question or "[[fail-after]]" in question:
            # Same shape the OpenAI service yields when the provider call fails.
            yield f"\n\n{PROVIDER_ERROR_MARKER} stub provider unavailable"


stub_chat_provider = StubChatProvider()
