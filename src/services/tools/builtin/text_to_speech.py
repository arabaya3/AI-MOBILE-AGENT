"""Text-to-speech tool using OpenAI-compatible models."""

from __future__ import annotations

import base64
from typing import Any, Dict, Optional

from openai import OpenAI

from src.core.settings.config import settings
from src.services.tools.base import BaseTool, ToolDefinition, ToolParameter


class TextToSpeechTool(BaseTool):
    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="text_to_speech",
            description="Convert text to spoken audio.",
            parameters=[
                ToolParameter(
                    name="text",
                    type="string",
                    description="Text to synthesize",
                    required=True,
                ),
                ToolParameter(
                    name="voice",
                    type="string",
                    description="Voice name (default: alloy)",
                    required=False,
                ),
                ToolParameter(
                    name="model",
                    type="string",
                    description="TTS model (default: gpt-4o-mini-tts)",
                    required=False,
                ),
            ],
        )

    async def execute(
        self,
        text: str,
        voice: Optional[str] = None,
        model: Optional[str] = None,
        **_: Any,
    ) -> Dict[str, Any]:
        try:
            api_key = (settings.OPENAI_API_KEY or "").strip()
            if not api_key:
                return {"success": False, "error": "OPENAI_API_KEY is not configured"}

            client = OpenAI(api_key=api_key, base_url=(settings.OPENAI_BASE_URL or None))
            model_id = (model or "gpt-4o-mini-tts").strip()
            response = client.audio.speech.create(
                model=model_id,
                voice=voice or "alloy",
                input=text,
            )
            audio_bytes = response.read()
            audio_b64 = base64.b64encode(audio_bytes).decode("utf-8")
            return {"success": True, "audio_base64": audio_b64, "model": model_id, "voice": voice or "alloy"}
        except Exception as exc:  # noqa: BLE001
            return {"success": False, "error": str(exc)}
