"""Selects the chat provider. The deterministic stub can never serve production."""

from __future__ import annotations

from src.core.settings.config import settings
from src.services.llm_providers.openai.chat import openai_chat_service

STUB_ALLOWED_ENVS = {"development", "test"}


def stub_enabled() -> bool:
    if not settings.CHAT_PROVIDER_STUB:
        return False
    if settings.APP_ENV.strip().lower() not in STUB_ALLOWED_ENVS:
        raise RuntimeError("CHAT_PROVIDER_STUB is only allowed when APP_ENV is development or test")
    return True


def assert_provider_configuration() -> None:
    """Called at startup so a misconfigured deployment fails fast instead of serving stub replies."""
    stub_enabled()


def get_chat_provider():
    if stub_enabled():
        from src.services.llm_providers.stub import stub_chat_provider

        return stub_chat_provider
    return openai_chat_service
