"""
Google ADK Agent Integration
============================
Wraps Google's Agent Development Kit (``google-adk``) to provide
orchestration-level capabilities on top of the existing chat and RAG
pipeline.

Install dependency::

    pip install google-adk          # or: pip install google-generativeai

Configuration (add to ``.env``)::

    GOOGLE_API_KEY=<your key>
    ADK_AGENT_MODEL=gemini-2.0-flash      # default
    ADK_AGENT_MAX_ITERATIONS=5            # default
    ADK_AGENT_TEMPERATURE=0.2             # default

Usage::

    from src.modules.agents.common.adk_agent import TEIAAgent

    agent = TEIAAgent()
    response = await agent.run(
        user_message="Summarise the Q3 audit report",
        space_id="...",
        conversation_history=[...],
        user_industry="Fintech",
        user_language="en",
    )
    print(response.text)
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Sequence

from src.core.settings.config import settings
from src.core.settings.logging import logger
from src.modules.agents.common.llm_factory import AgentLLMConfig, get_agent_llm_config
from src.services.llm_providers.openai.chat import build_user_context_prompt

# ─── Response type ─────────────────────────────────────────────────────────────


@dataclass
class AgentResponse:
    """Unified response returned by :class:`TEIAAgent`."""

    text: str
    """Final agent answer."""

    tool_calls: List[Dict[str, Any]] = field(default_factory=list)
    """All tool invocations the agent made (for tracing / audit)."""

    iterations: int = 0
    """Number of think-act iterations before convergence."""

    provider: str = "unknown"
    """Which backend executed the task (``adk``, ``langchain_google``, ``openai``)."""

    raw: Any = None
    """Raw response object from the underlying backend (optional)."""


# ─── TEIAAgent ─────────────────────────────────────────────────────────────────


class TEIAAgent:
    """
    Thin, extensible wrapper around Google ADK with a LangChain fallback.

    Decision tree
    -------------
    1. If ``google-adk`` is importable → use :meth:`_run_with_adk`.
    2. Else if ``langchain_google_genai`` is importable → use
       :meth:`_run_with_langchain_google`.
    3. Else → raise :class:`RuntimeError` with actionable install message.
    """

    def __init__(
        self,
        *,
        provider: str | None = None,
        model: str | None = None,
        temperature: float | None = None,
        max_iterations: int | None = None,
        tools: Sequence[Any] | None = None,
    ) -> None:
        _model = model or str(getattr(settings, "ADK_AGENT_MODEL", "gemini-2.0-flash"))
        _provider = provider or "google"
        self.llm_config: AgentLLMConfig = get_agent_llm_config(_provider, _model)

        self.temperature: float = temperature or float(
            getattr(settings, "ADK_AGENT_TEMPERATURE", 0.2)
        )
        self.max_iterations: int = max_iterations or int(
            getattr(settings, "ADK_AGENT_MAX_ITERATIONS", 5)
        )
        # Sequence of callables or google.adk FunctionTool objects.
        self.tools: List[Any] = list(tools or [])

    # ------------------------------------------------------------------ #
    # Public API                                                           #
    # ------------------------------------------------------------------ #

    async def run(
        self,
        user_message: str,
        *,
        space_id: str | None = None,
        conversation_history: List[Dict[str, str]] | None = None,
        user_industry: str | None = None,
        user_language: str | None = None,
        extra_system_prompt: str | None = None,
    ) -> AgentResponse:
        """
        Execute an agentic turn and return a structured :class:`AgentResponse`.

        Parameters
        ----------
        user_message:
            The end-user's query for this turn.
        space_id:
            Qdrant space / collection identifier (passed to retrieval tools).
        conversation_history:
            List of ``{"role": "user"|"assistant", "content": "..."}`` dicts.
        user_industry:
            User's industry context (injected into the system prompt).
        user_language:
            ISO-639-1 language code (injected into the system prompt).
        extra_system_prompt:
            Additional system instructions to append (e.g. custom prompts
            set by the user in the UI settings dialog).
        """
        system_prompt = self._build_system_prompt(
            user_industry=user_industry,
            user_language=user_language,
            extra=extra_system_prompt,
        )

        try:
            return await self._run_with_adk(
                user_message,
                system_prompt=system_prompt,
                conversation_history=conversation_history or [],
                space_id=space_id,
            )
        except ImportError:
            logger.info("google-adk not installed, falling back to LangChain Google")

        try:
            return await self._run_with_langchain_google(
                user_message,
                system_prompt=system_prompt,
                conversation_history=conversation_history or [],
            )
        except ImportError as exc:
            raise RuntimeError(
                "Neither 'google-adk' nor 'langchain-google-genai' is installed. "
                "Run: pip install google-adk  OR  pip install langchain-google-genai"
            ) from exc

    # ------------------------------------------------------------------ #
    # ADK backend                                                          #
    # ------------------------------------------------------------------ #

    async def _run_with_adk(
        self,
        user_message: str,
        *,
        system_prompt: str,
        conversation_history: List[Dict[str, str]],
        space_id: str | None,
    ) -> AgentResponse:
        """
        Execute via the official ``google-adk`` orchestrator.

        Requires: ``pip install google-adk``
        """
        from google.adk.agents import LlmAgent  # type: ignore[import]
        from google.adk.runners import InMemoryRunner  # type: ignore[import]
        from google.adk.sessions import InMemorySessionService  # type: ignore[import]
        from google.genai import types as genai_types  # type: ignore[import]

        api_key: str = str(
            getattr(settings, "GOOGLE_API_KEY", "")
            or getattr(settings, "GEMINI_API_KEY", "")
        )
        if not api_key:
            raise ValueError("GOOGLE_API_KEY or GEMINI_API_KEY must be set for ADK agent")

        agent = LlmAgent(
            name="teia_assistant",
            model=self.llm_config.model,
            description="TEIA enterprise AI assistant with RAG capabilities",
            instruction=system_prompt,
            tools=self.tools or [],
        )

        session_service = InMemorySessionService()
        runner = InMemoryRunner(agent=agent, app_name="teia", session_service=session_service)

        session = await session_service.create_session(
            app_name="teia",
            user_id="teia_user",
        )

        # Build ADK message content
        content = genai_types.Content(
            role="user",
            parts=[genai_types.Part.from_text(text=user_message)],
        )

        tool_calls: List[Dict[str, Any]] = []
        final_text = ""
        iterations = 0

        async for event in runner.run_async(
            user_id="teia_user",
            session_id=session.id,
            new_message=content,
        ):
            iterations += 1
            if hasattr(event, "is_final_response") and event.is_final_response():
                if event.content and event.content.parts:
                    final_text = "".join(
                        p.text for p in event.content.parts if hasattr(p, "text") and p.text
                    )
            if hasattr(event, "tool_calls"):
                for tc in (event.tool_calls or []):
                    tool_calls.append({"name": getattr(tc, "name", ""), "args": getattr(tc, "args", {})})

        return AgentResponse(
            text=final_text,
            tool_calls=tool_calls,
            iterations=iterations,
            provider="adk",
        )

    # ------------------------------------------------------------------ #
    # LangChain Google fallback                                            #
    # ------------------------------------------------------------------ #

    async def _run_with_langchain_google(
        self,
        user_message: str,
        *,
        system_prompt: str,
        conversation_history: List[Dict[str, str]],
    ) -> AgentResponse:
        """
        Execute via ``langchain-google-genai`` when google-adk is unavailable.

        Requires: ``pip install langchain-google-genai``
        """
        from langchain.schema import AIMessage, HumanMessage, SystemMessage
        from langchain_google_genai import ChatGoogleGenerativeAI  # type: ignore[import]

        api_key: str = str(
            getattr(settings, "GOOGLE_API_KEY", "")
            or getattr(settings, "GEMINI_API_KEY", "")
        )
        if not api_key:
            raise ValueError("GOOGLE_API_KEY or GEMINI_API_KEY must be set")

        llm = ChatGoogleGenerativeAI(
            model=self.llm_config.model,
            temperature=self.temperature,
            google_api_key=api_key,
        )

        messages = [SystemMessage(content=system_prompt)]
        for turn in conversation_history:
            if turn.get("role") == "user":
                messages.append(HumanMessage(content=turn["content"]))
            else:
                messages.append(AIMessage(content=turn["content"]))
        messages.append(HumanMessage(content=user_message))

        response = await asyncio.to_thread(llm.invoke, messages)
        return AgentResponse(
            text=str(response.content),
            iterations=1,
            provider="langchain_google",
            raw=response,
        )

    # ------------------------------------------------------------------ #
    # System prompt builder                                                #
    # ------------------------------------------------------------------ #

    def _build_system_prompt(
        self,
        *,
        user_industry: Optional[str],
        user_language: Optional[str],
        extra: Optional[str],
    ) -> str:
        """
        Compose the full system prompt for this agent turn.

        Layers (all optional):
        1. Base TEIA assistant instructions.
        2. User context block (industry + language) — same logic as
           :func:`~src.services.llm_providers.openai.chat.build_user_context_prompt`.
        3. Extra instructions from the user's Settings dialog.
        """
        base = (
            "You are the TEIA enterprise AI assistant. "
            "You answer questions thoroughly and cite relevant documents when available. "
            "You never fabricate information — if you are unsure, say so clearly."
        )
        user_ctx: Optional[str] = None
        if user_industry or (user_language and user_language != "en"):
            user_ctx = build_user_context_prompt(
                industry=user_industry or None,
                language=user_language or None,
            )

        parts = [p for p in [base, user_ctx, extra] if p]
        return "\n\n".join(parts)


# ─── Convenience factory ───────────────────────────────────────────────────────


def create_teia_agent(
    *,
    model: str | None = None,
    tools: Sequence[Any] | None = None,
) -> TEIAAgent:
    """
    Return a :class:`TEIAAgent` with sensible defaults from ``settings``.

    This is the recommended entry-point for dependency injection / FastAPI
    startup lifecycle hooks.
    """
    return TEIAAgent(model=model, tools=tools)
