"""Image generation tool using OpenAI-compatible models."""

from __future__ import annotations

import base64
from typing import Any, Dict, Optional

from openai import OpenAI

from src.core.settings.config import settings
from src.services.tools.base import BaseTool, ToolDefinition, ToolParameter


class ImageGenerationTool(BaseTool):
    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="image_generation",
            description="Generate an image from a text prompt.",
            parameters=[
                ToolParameter(
                    name="prompt",
                    type="string",
                    description="Text prompt for the image",
                    required=True,
                ),
                ToolParameter(
                    name="size",
                    type="string",
                    description="Image size (e.g., 1024x1024)",
                    required=False,
                ),
                ToolParameter(
                    name="model",
                    type="string",
                    description="Image generation model (default: gpt-image-1)",
                    required=False,
                ),
            ],
        )

    async def execute(
        self,
        prompt: str,
        size: Optional[str] = None,
        model: Optional[str] = None,
        **_: Any,
    ) -> Dict[str, Any]:
        try:
            api_key = (settings.OPENAI_API_KEY or "").strip()
            if not api_key:
                return {"success": False, "error": "OPENAI_API_KEY is not configured"}

            client = OpenAI(api_key=api_key, base_url=(settings.OPENAI_BASE_URL or None))
            model_id = (model or "gpt-image-1").strip()
            response = client.images.generate(
                model=model_id,
                prompt=prompt,
                size=size or "1024x1024",
            )
            data = response.data[0]
            if getattr(data, "b64_json", None):
                image_b64 = data.b64_json
            else:
                image_url = getattr(data, "url", None)
                if image_url:
                    return {"success": True, "url": image_url, "model": model_id}
                image_b64 = None
            return {"success": True, "image_base64": image_b64, "model": model_id}
        except Exception as exc:  # noqa: BLE001
            return {"success": False, "error": str(exc)}
