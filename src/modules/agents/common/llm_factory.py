"""LLM provider factory for agent instantiation."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from src.core.settings.config import settings


@dataclass(frozen=True)
class AgentLLMConfig:
    """Minimal provider configuration that can be passed to ADK-style agent builders."""

    provider: str
    model: str
    temperature: float = 0.2


def get_agent_llm_config(provider: str | None = None, model: str | None = None) -> AgentLLMConfig:
    """Return normalized config for agent runtimes (LangChain or Google ADK wrappers)."""
    selected_provider = (provider or "openai").strip().lower()
    selected_model = (model or settings.OPENAI_CHAT_MODEL).strip()
    return AgentLLMConfig(provider=selected_provider, model=selected_model)


def create_langchain_llm(provider: str | None = None, model: str | None = None, *, temperature: float = 0.2) -> Any:
    """Instantiate a LangChain chat model for the selected provider."""
    cfg = get_agent_llm_config(provider, model)
    if cfg.provider in {"google", "gemini", "google_adk"}:
        from langchain_google_genai import ChatGoogleGenerativeAI

        api_key = settings.GOOGLE_API_KEY or settings.GEMINI_API_KEY
        return ChatGoogleGenerativeAI(model=cfg.model, temperature=temperature, google_api_key=api_key)

    from langchain_openai import ChatOpenAI

    return ChatOpenAI(
        model=cfg.model,
        temperature=temperature,
        api_key=settings.OPENAI_API_KEY,
        base_url=settings.OPENAI_BASE_URL or None,
    )
