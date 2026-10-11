"""Image understanding tool using OpenAI-compatible vision models."""

from __future__ import annotations

import base64
from typing import Any, Dict, Optional

from openai import OpenAI

from src.core.settings.config import settings
from src.services.tools.base import BaseTool, ToolDefinition, ToolParameter


class ImageUnderstandingTool(BaseTool):
    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="image_understanding",
            description="Analyze an image and answer a prompt about it.",
            parameters=[
                ToolParameter(
                    name="image_url",
                    type="string",
                    description="Public URL of the image to analyze",
                    required=False,
                ),
                ToolParameter(
                    name="image_base64",
                    type="string",
                    description="Base64-encoded image content (no data: prefix)",
                    required=False,
                ),
                ToolParameter(
                    name="prompt",
                    type="string",
                    description="Question or instruction about the image",
                    required=False,
                ),
                ToolParameter(
                    name="model",
                    type="string",
                    description="Vision-capable model (default: OPENAI_CHAT_MODEL)",
                    required=False,
                ),
            ],
        )

    async def execute(
        self,
        image_url: Optional[str] = None,
        image_base64: Optional[str] = None,
        prompt: Optional[str] = None,
        model: Optional[str] = None,
        **_: Any,
    ) -> Dict[str, Any]:
        try:
            if not image_url and not image_base64:
                return {"success": False, "error": "image_url or image_base64 is required"}

            api_key = (settings.OPENAI_API_KEY or "").strip()
            if not api_key:
                return {"success": False, "error": "OPENAI_API_KEY is not configured"}

            client = OpenAI(api_key=api_key, base_url=(settings.OPENAI_BASE_URL or None))
            model_id = (model or settings.OPENAI_CHAT_MODEL).strip()

            if image_base64:
                try:
                    base64.b64decode(image_base64)
                except Exception:  # noqa: BLE001
                    return {"success": False, "error": "Invalid image_base64"}
                image_url = f"data:image/png;base64,{image_base64}"

            content = []
            if prompt:
                content.append({"type": "text", "text": prompt})
            content.append({"type": "image_url", "image_url": {"url": image_url}})

            response = client.chat.completions.create(
                model=model_id,
                messages=[{"role": "user", "content": content}],
            )
            message = response.choices[0].message.content if response.choices else ""
            return {"success": True, "result": (message or "").strip(), "model": model_id}
        except Exception as exc:  # noqa: BLE001
            return {"success": False, "error": str(exc)}
