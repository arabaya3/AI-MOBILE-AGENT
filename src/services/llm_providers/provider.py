"""Selects chat and embedding providers. The deterministic stubs can never serve production."""

from __future__ import annotations

from src.core.settings.config import settings
from src.services.llm_providers.openai.chat import openai_chat_service

STUB_ALLOWED_ENVS = {"development", "test"}


def _stub_allowed(flag: str) -> bool:
    if not getattr(settings, flag, False):
        return False
    if settings.APP_ENV.strip().lower() not in STUB_ALLOWED_ENVS:
        raise RuntimeError(f"{flag} is only allowed when APP_ENV is development or test")
    return True


def stub_enabled() -> bool:
    return _stub_allowed("CHAT_PROVIDER_STUB")


def embedding_stub_enabled() -> bool:
    return _stub_allowed("EMBEDDING_PROVIDER_STUB")


def assert_provider_configuration() -> None:
    """Called at startup so a misconfigured deployment fails fast instead of serving stub output."""
    stub_enabled()
    embedding_stub_enabled()


def get_chat_provider():
    if stub_enabled():
        from src.services.llm_providers.stub import stub_chat_provider

        return stub_chat_provider
    return openai_chat_service


def get_embedding_service():
    if embedding_stub_enabled():
        from src.services.embeddings.stub import stub_embedding_service

        return stub_embedding_service
    from src.services.embeddings.openai import embedding_service

    return embedding_service
