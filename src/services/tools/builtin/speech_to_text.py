"""Speech-to-text tool using OpenAI-compatible audio transcription."""

from __future__ import annotations

import base64
import io
from typing import Any, Dict, Optional

from openai import OpenAI

from src.core.settings.config import settings
from src.services.tools.base import BaseTool, ToolDefinition, ToolParameter


class SpeechToTextTool(BaseTool):
    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="speech_to_text",
            description="Transcribe audio to text.",
            parameters=[
                ToolParameter(
                    name="audio_base64",
                    type="string",
                    description="Base64-encoded audio file content",
                    required=True,
                ),
                ToolParameter(
                    name="filename",
                    type="string",
                    description="Filename with extension (e.g., audio.wav)",
                    required=False,
                ),
                ToolParameter(
                    name="model",
                    type="string",
                    description="Transcription model (default: gpt-4o-mini-transcribe)",
                    required=False,
                ),
            ],
        )

    async def execute(
        self,
        audio_base64: str,
        filename: Optional[str] = None,
        model: Optional[str] = None,
        **_: Any,
    ) -> Dict[str, Any]:
        try:
            api_key = (settings.OPENAI_API_KEY or "").strip()
            if not api_key:
                return {"success": False, "error": "OPENAI_API_KEY is not configured"}

            client = OpenAI(api_key=api_key, base_url=(settings.OPENAI_BASE_URL or None))
            audio_bytes = base64.b64decode(audio_base64)
            file_like = io.BytesIO(audio_bytes)
            file_like.name = filename or "audio.wav"
            model_id = (model or "gpt-4o-mini-transcribe").strip()
            response = client.audio.transcriptions.create(
                model=model_id,
                file=file_like,
            )
            return {"success": True, "text": getattr(response, "text", ""), "model": model_id}
        except Exception as exc:  # noqa: BLE001
            return {"success": False, "error": str(exc)}
