"""Models and tools a space may allow: identifiers only."""

from __future__ import annotations

from fastapi import HTTPException, status

from src.core.settings.config import settings


def tool_ids() -> list[str]:
    """Tools registered at startup (`init_tools`), i.e. the ones this deployment can run."""
    from src.services.tools.registry import tool_registry

    return sorted({definition.name for definition in tool_registry.list_tools()})


async def model_ids() -> list[str]:
    from src.modules.apis.v1.chat.handlers import _is_package_token
    from src.services.llm_providers.provider import get_chat_provider

    provider = get_chat_provider()
    configured = [
        *(getattr(settings, "SUPPORTED_CHAT_MODELS", []) or []),
        *(getattr(settings, "CATALOG_CHAT_MODELS", []) or []),
        *((getattr(settings, "MODEL_PRICING", {}) or {}).keys()),
        *(getattr(settings, "DEFAULT_ALLOWED_MODELS", []) or []),
    ]
    try:
        remote = await provider.list_models()
    except Exception:  # noqa: BLE001
        remote = []
    ids = {str(m).strip() for m in [*configured, *remote] if str(m).strip()}
    chat = {m for m in ids if _is_package_token(m) or provider._is_chat_model_id(m)}
    chat |= {str(p).strip() for p in getattr(settings, "MODEL_PACKAGES", []) or [] if str(p).strip()}
    return sorted(chat)


def reject_unknown(kind: str, requested: list[str], supported: list[str], already: list[str] | None = None) -> list[str]:
    """Clean list; identifiers already stored stay valid so legacy policies can still be saved."""
    clean = [item.strip() for item in requested if isinstance(item, str) and item.strip()]
    allowed = set(supported) | set(already or [])
    unknown = sorted({item for item in clean if item not in allowed})
    if unknown:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=f"Unsupported {kind}: {', '.join(unknown)[:200]}")
    return list(dict.fromkeys(clean))
