"""OpenAI chat utilities for answering RAG queries."""

from __future__ import annotations

import asyncio
import json
import threading
import time
from typing import Any, Dict, List

from openai import OpenAI

from src.core.observability import tracer
from src.core.settings.config import settings
from src.core.settings.system_prompts import get_system_prompts


class OpenAIChatService:
    """Thin wrapper around OpenAI chat completions."""

    def __init__(self, model: str | None = None) -> None:
        self.model = model or settings.OPENAI_CHAT_MODEL
        self.api_key = settings.OPENAI_API_KEY
        self._client_instances: dict[str, OpenAI] = {}
        self._models_cache: list[str] | None = None
        self._models_cache_until: float = 0.0
        self._models_cache_lock = asyncio.Lock()

    @staticmethod
    def _provider_for_model(model_id: str) -> str:
        mid = (model_id or "").lower()
        if mid.startswith("deepseek"):
            return "deepseek"
        if mid.startswith("qwen"):
            return "qwen"
        if mid.startswith("gemini"):
            return "gemini"
        if mid.startswith("claude") or mid.startswith("anthropic"):
            return "anthropic"
        return "openai"

    def _get_client(self, model_id: str | None = None) -> OpenAI:
        provider = self._provider_for_model(model_id or self.model)
        key = provider

        if key in self._client_instances:
            return self._client_instances[key]

        if provider == "deepseek":
            api_key = (settings.DEEPSEEK_API_KEY or "").strip()
            base_url = (settings.DEEPSEEK_BASE_URL or "").strip() or None
        elif provider == "qwen":
            api_key = (settings.QWEN_API_KEY or settings.DASHSCOPE_API_KEY or "").strip()
            base_url = ((settings.QWEN_BASE_URL or "").strip() or (settings.DASHSCOPE_BASE_URL or "").strip() or None)
        elif provider == "gemini":
            api_key = (settings.GEMINI_API_KEY or settings.GOOGLE_API_KEY or "").strip()
            base_url = (settings.GEMINI_BASE_URL or "").strip() or None
        elif provider == "anthropic":
            api_key = (settings.ANTHROPIC_API_KEY or "").strip()
            base_url = (settings.ANTHROPIC_BASE_URL or "").strip() or None
        else:
            api_key = (settings.OPENAI_API_KEY or "").strip()
            base_url = (settings.OPENAI_BASE_URL or "").strip() or None

        if not api_key:
            raise RuntimeError(f"{provider.upper()}_API_KEY is not configured")
        if provider != "openai" and not base_url:
            raise RuntimeError(f"{provider.upper()}_BASE_URL is not configured")

        org_value = (settings.OPENAI_ORGANIZATION or settings.OPENAI_ORG_ID or "").strip()
        proj_value = (settings.OPENAI_PROJECT or settings.OPENAI_PROJECT_ID or "").strip()
        organization = org_value if org_value.startswith("org_") else None
        project = proj_value if proj_value.startswith("proj_") else None

        client = OpenAI(
            api_key=api_key,
            organization=organization if provider == "openai" else None,
            project=project if provider == "openai" else None,
            base_url=base_url,
        )
        self._client_instances[key] = client
        return client

    @classmethod
    def _format_provider_error(cls, model_id: str, exc: Exception) -> str:
        provider = cls._provider_for_model(model_id)
        raw = str(exc)
        # DashScope / Alibaba Cloud Model Studio uses OpenAI-compatible errors but with Aliyun hints.
        if provider == "qwen":
            lowered = raw.lower()
            if "help.aliyun.com" in lowered or "invalid_api_key" in lowered or "incorrect api key" in lowered:
                return (
                    f"{raw}\n\n"
                    "Qwen (DashScope/Model Studio) rejected the API key.\n"
                    "- Set `QWEN_API_KEY` or `DASHSCOPE_API_KEY` to your DashScope/Model Studio key (not an OpenAI key).\n"
                    "- Ensure `QWEN_BASE_URL` (or `DASHSCOPE_BASE_URL`) points to your DashScope OpenAI-compatible endpoint.\n"
                    "- Restart the backend after changing env vars."
                )
        return raw

    @staticmethod
    def _resolve_priced_model_id(model_id: str | None) -> str | None:
        mid = (model_id or "").strip()
        if not mid:
            return None
        aliases = getattr(settings, "MODEL_ALIASES", {}) or {}
        if isinstance(aliases, dict) and mid in aliases:
            mid = str(aliases.get(mid) or mid)
        pricing = getattr(settings, "MODEL_PRICING", {}) or {}
        if isinstance(pricing, dict) and mid in pricing:
            return mid
        return None

    @classmethod
    def _coerce_to_supported_model(cls, requested: str | None) -> tuple[str, str | None]:
        """Return (selected_model, requested_model).

        Ensures we only call OpenAI with a model that has pricing configured.
        """
        req = (requested or "").strip() or None
        aliases = getattr(settings, "MODEL_ALIASES", {}) or {}
        if req and isinstance(aliases, dict) and req in aliases:
            aliased = str(aliases.get(req) or req).strip()
            return aliased or req, req

        resolved = cls._resolve_priced_model_id(req) if req else None
        if resolved:
            return resolved, req
        if req:
            # Allow unpriced models when explicitly requested (pricing may be provided externally).
            return req, req

        default_resolved = cls._resolve_priced_model_id(settings.OPENAI_CHAT_MODEL) or settings.OPENAI_CHAT_MODEL
        return default_resolved, req

    @staticmethod
    def _supports_temperature(model_id: str) -> bool:
        mid = (model_id or "").strip().lower()
        if not mid:
            return True
        # Some newer/reasoning families only support the default temperature.
        if mid.startswith(("o1", "o3", "o4", "gpt-5")):
            return False
        return True

    async def answer_question(self, question: str, contexts: List[Dict[str, Any]]) -> str:
        """Use GPT-4o-mini to answer a question given retrieved chunks."""
        context_summaries = self._summarize_contexts(contexts)
        if not context_summaries:
            return ""

        context_block = "\n\n".join(context_summaries)
        prompts = get_system_prompts()
        system_prompt = prompts.get("answer_question_system_prompt") or ""
        user_prompt = (
            f"Context:\n{context_block}\n\n"
            f"Question: {question}\n\n"
            "Respond with a concise answer and mention relevant sources by their number when possible."
        )

        generation = tracer.start_generation(
            tracer.get_current_span(),
            name="openai.chat_completion",
            input={"question": question, "contexts": len(context_summaries)},
            metadata={"model": self.model},
            model=self.model,
        )
        try:
            create_kwargs: Dict[str, Any] = {
                "model": self.model,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
            }
            if self._supports_temperature(self.model):
                create_kwargs["temperature"] = 0.2
            response = await asyncio.to_thread(
                self._get_client(self.model).chat.completions.create,
                **create_kwargs,
            )
            if response.choices:
                message_content = response.choices[0].message.content or ""
                answer = message_content.strip()
            else:
                answer = ""
            usage_details = self._extract_usage_details(response)
            cost_details = (
                tracer.estimate_cost(self.model, usage_details)
                if usage_details
                else None
            )
            tracer.end_generation(
                generation,
                output=answer,
                metadata={"model": self.model, "contexts": len(context_summaries)},
                usage_details=usage_details or None,
                cost_details=cost_details,
            )
            return answer
        except Exception as exc:  # noqa: BLE001
            tracer.end_generation(generation, status_message=str(exc))
            raise

    async def decide_web_search(
        self,
        *,
        question: str,
        has_context: bool,
        available_tools: List[str],
        model: str | None = None,
    ) -> Dict[str, Any]:
        """Use the model to decide if web search is needed (no hardcoded triggers)."""
        prompts = get_system_prompts()
        decision_prompt = (prompts.get("web_search_decision_prompt") or "").strip()
        if not decision_prompt or not available_tools:
            return {"use_web_search": False, "tool_name": None, "query": None}

        # Force web search for explicit keywords
        question_lower = (question or "").lower()
        web_keywords = ["search in the internet", "search internet", "search online", "search the web", 
                        "search web", "latest news", "today's news", "current news", "recent news"]
        force_search = any(keyword in question_lower for keyword in web_keywords)
        
        if force_search and available_tools:
            tool_name = available_tools[0] if available_tools else None
            return {
                "use_web_search": True,
                "tool_name": tool_name,
                "query": question.replace("search in the internet", "").replace("search the internet", "")
                               .replace("search internet", "").replace("search online", "")
                               .replace("search web", "").replace("search the web", "").strip()
            }

        selected_model = model or self.model
        payload = {
            "question": question,
            "has_context": bool(has_context),
            "available_tools": list(available_tools),
        }
        messages = [
            {"role": "system", "content": decision_prompt},
            {"role": "user", "content": json.dumps(payload, ensure_ascii=False)},
        ]
        try:
            create_kwargs: Dict[str, Any] = {
                "model": selected_model,
                "messages": messages,
            }
            if self._supports_temperature(selected_model):
                create_kwargs["temperature"] = 0.0
            response = await asyncio.to_thread(
                self._get_client(selected_model).chat.completions.create,
                **create_kwargs,
            )
            content = (response.choices[0].message.content or "").strip() if response.choices else ""
        except Exception:  # noqa: BLE001
            return {"use_web_search": False, "tool_name": None, "query": None}

        def _parse_json(text: str) -> Dict[str, Any]:
            if not text:
                return {}
            try:
                return json.loads(text)
            except json.JSONDecodeError:
                start = text.find("{")
                end = text.rfind("}")
                if start != -1 and end != -1 and end > start:
                    try:
                        return json.loads(text[start : end + 1])
                    except json.JSONDecodeError:
                        return {}
                return {}

        decision = _parse_json(content)
        use_web_search = bool(decision.get("use_web_search")) if isinstance(decision, dict) else False
        tool_name = decision.get("tool_name") if isinstance(decision, dict) else None
        query = decision.get("query") if isinstance(decision, dict) else None

        if tool_name not in set(available_tools or []):
            tool_name = None
        if not isinstance(query, str) or not query.strip():
            query = None

        return {"use_web_search": use_web_search, "tool_name": tool_name, "query": query}

    def _summarize_contexts(self, contexts: List[Dict[str, Any]], limit: int | None = None) -> List[str]:
        """Convert retrieved chunks into compact context snippets.

        Note: do not aggressively truncate by default. The caller controls retrieval size.
        """
        summaries: List[str] = []
        sliced = contexts if limit is None else contexts[:limit]
        for idx, item in enumerate(sliced, start=1):
            snippet = (item.get("text") or "").strip()
            if not snippet:
                continue
            title = item.get("filename") or item.get("document_id") or "unknown source"
            chunk_index = item.get("chunk_index")
            score = item.get("score")
            score_text = f" score={float(score):.3f}" if score is not None else ""
            summaries.append(
                f"Source {idx}: {title} (chunk {chunk_index}){score_text}\n{snippet}"
            )
        return summaries

    async def answer_with_memory(
        self,
        *,
        history: List[Dict[str, str]],
        question: str,
        contexts: List[Dict[str, Any]],
        model: str | None = None,
        usage_sink: Dict[str, int] | None = None,
        enable_tools: bool = True,
        allowed_tools: List[str] | None = None,
        tool_usage_sink: Dict[str, int] | None = None,
    ) -> str:
        """Answer a chat turn while honoring prior conversation state."""
        # Check if tools are enabled
        if enable_tools and settings.ENABLE_FUNCTION_CALLING:
            from src.services.tools.executor import tool_executor
            from src.services.tools.registry import tool_registry

            tools = tool_registry.get_openai_tools(allowlist=allowed_tools)
            if tools:
                return await self._answer_with_tools(
                    history=history,
                    question=question,
                    contexts=contexts,
                    model=model,
                    usage_sink=usage_sink,
                    tools=tools,
                    tool_usage_sink=tool_usage_sink,
                )

        context_summaries = self._summarize_contexts(contexts)
        prompts = get_system_prompts()
        messages: List[Dict[str, str]] = [
            {
                "role": "system",
                "content": (prompts.get("memory_system_prompt") or ""),
            }
        ]

        for item in history[-8:]:
            role = item.get("role")
            content = (item.get("content") or "").strip()
            if role not in {"user", "assistant"} or not content:
                continue
            messages.append({"role": role, "content": content})

        user_prompt_sections: List[str] = []
        if context_summaries:
            user_prompt_sections.append(
                "Relevant document snippets:\n" + "\n\n".join(context_summaries)
            )
        else:
            user_prompt_sections.append(
                "No indexed documents were retrieved for this turn. Answer from policy "
                "knowledge or ask for more context."
            )
        user_prompt_sections.append(f"User question: {question}")
        user_prompt_sections.append("Consider the conversation above when replying.")

        messages.append({"role": "user", "content": "\n\n".join(user_prompt_sections)})

        selected_model, requested_model = self._coerce_to_supported_model(model or self.model)

        generation = tracer.start_generation(
            tracer.get_current_span(),
            name="openai.chat_completion",
            input={"question": question, "contexts": len(context_summaries), "history": len(history)},
            metadata={"model": selected_model, "requested_model": requested_model},
            model=selected_model,
        )

        try:
            create_kwargs: Dict[str, Any] = {
                "model": selected_model,
                "messages": messages,
            }
            if self._supports_temperature(selected_model):
                create_kwargs["temperature"] = 0.3
            response = await asyncio.to_thread(
                self._get_client(selected_model).chat.completions.create,
                **create_kwargs,
            )
            answer = (response.choices[0].message.content or "").strip() if response.choices else ""
            usage_details = self._extract_usage_details(response)
            if usage_sink is not None and usage_details:
                usage_sink.update(usage_details)
            cost_details = (
                tracer.estimate_cost(selected_model, usage_details)
                if usage_details
                else None
            )
            tracer.end_generation(
                generation,
                output=answer,
                metadata={"model": selected_model, "requested_model": requested_model, "contexts": len(context_summaries)},
                usage_details=usage_details or None,
                cost_details=cost_details,
            )
            return answer
        except Exception as exc:  # noqa: BLE001
            tracer.end_generation(generation, status_message=str(exc))
            raise RuntimeError(self._format_provider_error(selected_model, exc)) from exc

    @staticmethod
    def _extract_usage_details(response: Any) -> Dict[str, int]:
        """Pull token usage counters from an OpenAI response."""
        usage = getattr(response, "usage", None)
        if usage is None:
            return {}
        return {
            "input_tokens": int(getattr(usage, "prompt_tokens", 0) or 0),
            "output_tokens": int(getattr(usage, "completion_tokens", 0) or 0),
            "total_tokens": int(getattr(usage, "total_tokens", 0) or 0),
        }

    @staticmethod
    def _extract_usage_details_from_usage(usage: Any) -> Dict[str, int]:
        if usage is None:
            return {}
        if isinstance(usage, dict):
            return {
                "input_tokens": int(usage.get("prompt_tokens") or usage.get("input_tokens") or 0),
                "output_tokens": int(usage.get("completion_tokens") or usage.get("output_tokens") or 0),
                "total_tokens": int(usage.get("total_tokens") or 0),
            }
        return {
            "input_tokens": int(getattr(usage, "prompt_tokens", 0) or 0),
            "output_tokens": int(getattr(usage, "completion_tokens", 0) or 0),
            "total_tokens": int(getattr(usage, "total_tokens", 0) or 0),
        }

    async def stream_with_memory(
        self,
        *,
        history: List[Dict[str, str]],
        question: str,
        contexts: List[Dict[str, Any]],
        model: str | None = None,
        temperature: float = 0.3,
        usage_sink: Dict[str, int] | None = None,
    ):
        """Stream a chat completion as incremental text chunks (async generator)."""

        context_summaries = self._summarize_contexts(contexts)
        prompts = get_system_prompts()
        messages: List[Dict[str, str]] = [
            {
                "role": "system",
                "content": (prompts.get("stream_system_prompt") or ""),
            }
        ]

        for item in history[-8:]:
            role = item.get("role")
            content = (item.get("content") or "").strip()
            if role not in {"user", "assistant"} or not content:
                continue
            messages.append({"role": role, "content": content})

        user_prompt_sections: List[str] = []
        if context_summaries:
            user_prompt_sections.append("Relevant document snippets:\n" + "\n\n".join(context_summaries))
        else:
            user_prompt_sections.append(
                "No indexed documents were retrieved for this turn. If you cannot answer from snippets, say so and ask for more context."
            )
        user_prompt_sections.append(f"User question: {question}")
        user_prompt_sections.append("Consider the conversation above when replying.")
        messages.append({"role": "user", "content": "\n\n".join(user_prompt_sections)})

        selected_model, requested_model = self._coerce_to_supported_model(model or self.model)
        loop = asyncio.get_running_loop()
        queue: asyncio.Queue[tuple[str, Any] | None] = asyncio.Queue()

        generation = tracer.start_generation(
            tracer.get_current_span(),
            name="openai.chat_completion_stream",
            input={"question": question, "contexts": len(context_summaries), "history": len(history)},
            metadata={"model": selected_model, "requested_model": requested_model},
            model=selected_model,
        )

        def _run_stream() -> None:
            try:
                create_kwargs: Dict[str, Any] = {
                    "model": selected_model,
                    "messages": messages,
                    "stream": True,
                }
                if self._supports_temperature(selected_model):
                    create_kwargs["temperature"] = temperature
                try:
                    stream = self._get_client(selected_model).chat.completions.create(
                        **create_kwargs,
                        stream_options={"include_usage": True},
                    )
                except TypeError:
                    # Older clients may not support stream_options.
                    stream = self._get_client(selected_model).chat.completions.create(
                        **create_kwargs,
                    )
                for event in stream:
                    usage = getattr(event, "usage", None)
                    if usage is not None:
                        loop.call_soon_threadsafe(queue.put_nowait, ("usage", usage))
                    try:
                        delta = event.choices[0].delta.content if event.choices else None
                    except Exception:  # noqa: BLE001
                        delta = None
                    if delta:
                        loop.call_soon_threadsafe(queue.put_nowait, ("delta", str(delta)))
            except Exception as exc:  # noqa: BLE001
                loop.call_soon_threadsafe(queue.put_nowait, ("error", self._format_provider_error(selected_model, exc)))
            finally:
                loop.call_soon_threadsafe(queue.put_nowait, None)

        threading.Thread(target=_run_stream, daemon=True).start()

        collected: List[str] = []
        usage_details: Dict[str, int] = {}
        start = time.time()
        try:
            while True:
                item = await queue.get()
                if item is None:
                    break
                kind, payload = item
                if kind == "usage":
                    usage_details = self._extract_usage_details_from_usage(payload)
                    continue
                if kind == "error":
                    collected.append(f"\n\n[stream_error] {payload}")
                    yield f"\n\n[stream_error] {payload}"
                    continue
                if kind == "delta":
                    collected.append(str(payload))
                    yield str(payload)
            answer = "".join(collected).strip()
            if usage_sink is not None and usage_details:
                usage_sink.update(usage_details)
            cost_details = tracer.estimate_cost(selected_model, usage_details) if usage_details else None
            tracer.end_generation(
                generation,
                output=answer,
                metadata={"model": selected_model, "requested_model": requested_model, "contexts": len(context_summaries), "duration_s": round(time.time() - start, 3)},
                usage_details=usage_details or None,
                cost_details=cost_details or None,
            )
        except Exception as exc:  # noqa: BLE001
            tracer.end_generation(generation, status_message=str(exc))
            raise

    @staticmethod
    def _is_chat_model_id(model_id: str) -> bool:
        mid = (model_id or "").strip().lower()
        if not mid:
            return False
        if "*" in mid:
            return False
        # Keep chat-capable families; exclude obvious non-chat endpoints.
        if not mid.startswith((
            "gpt-",
            "o1-",
            "o3-",
            "o4-",
            "o1",
            "o3",
            "o4",
            "chatgpt-",
            "claude",
            "anthropic",
            "gemini",
            "qwen",
            "deepseek",
        )):
            return False
        blocked_substrings = (
            "text-embedding-",
            "embedding",
            "moderation",
            "realtime",
            "audio",
            "transcribe",
            "tts",
            "image",
            "dall-e",
            "whisper",
        )
        if any(b in mid for b in blocked_substrings):
            return False
        return True

    async def list_models(self) -> List[str]:
        """Return available chat-capable model IDs from the OpenAI account.

        This call is cached to avoid hammering OpenAI (and dev reload loops).
        Falls back to locally configured supported models when OpenAI is unavailable.
        """

        cache_ttl_s = float(getattr(settings, "OPENAI_LIST_MODELS_CACHE_TTL_S", 300) or 300)
        now = time.time()
        if self._models_cache and now < self._models_cache_until:
            return list(self._models_cache)

        async with self._models_cache_lock:
            now = time.time()
            if self._models_cache and now < self._models_cache_until:
                return list(self._models_cache)

        def _fetch() -> List[str]:
            models = self._get_client(settings.OPENAI_CHAT_MODEL).models.list()
            ids = [m.id for m in getattr(models, "data", []) if getattr(m, "id", None)]
            ids = [mid for mid in ids if self._is_chat_model_id(mid)]
            # Keep only models we can price (directly or via alias), so usage never shows "Not priced".
            supported_allowlist = getattr(settings, "SUPPORTED_CHAT_MODELS", []) or []
            supported_allowlist = [str(x) for x in supported_allowlist if str(x).strip()]
            if supported_allowlist:
                ids = [mid for mid in ids if mid in supported_allowlist]
            ids = [mid for mid in ids if self._resolve_priced_model_id(mid) is not None]
            ids = sorted(set(ids))
            return ids

        def _fallback() -> List[str]:
            supported = getattr(settings, "SUPPORTED_CHAT_MODELS", []) or []
            supported = [str(x) for x in supported if str(x).strip()]
            candidates = supported or [settings.OPENAI_CHAT_MODEL]
            ids = [mid for mid in candidates if self._is_chat_model_id(mid)]
            ids = [mid for mid in ids if self._resolve_priced_model_id(mid) is not None]
            ids = sorted(set(ids))
            return ids or sorted(set(candidates))

        try:
            ids = await asyncio.to_thread(_fetch)
        except Exception:  # noqa: BLE001
            ids = _fallback()

        self._models_cache = ids
        self._models_cache_until = time.time() + max(cache_ttl_s, 5.0)
        return list(ids)

    async def _answer_with_tools(
        self,
        *,
        history: List[Dict[str, str]],
        question: str,
        contexts: List[Dict[str, Any]],
        model: str | None = None,
        usage_sink: Dict[str, int] | None = None,
        tools: List[Dict],
        tool_usage_sink: Dict[str, int] | None = None,
    ) -> str:
        """Answer with tool calling support."""
        from src.services.tools.executor import tool_executor

        context_summaries = self._summarize_contexts(contexts)
        prompts = get_system_prompts()
        messages: List[Dict] = [
            {
                "role": "system",
                "content": (prompts.get("tools_system_prompt") or ""),
            }
        ]

        for item in history[-8:]:
            role = item.get("role")
            content = (item.get("content") or "").strip()
            if role in {"user", "assistant"} and content:
                messages.append({"role": role, "content": content})

        user_prompt_sections = []
        if context_summaries:
            user_prompt_sections.append("Document snippets:\n" + "\n\n".join(context_summaries))
        user_prompt_sections.append(f"Question: {question}")
        messages.append({"role": "user", "content": "\n\n".join(user_prompt_sections)})

        selected_model = model or self.model
        max_iterations = settings.MAX_TOOL_ITERATIONS

        tool_names = {
            ((t.get("function") or {}).get("name") if isinstance(t, dict) else None)
            for t in (tools or [])
        }
        available_tool_names = sorted({t for t in tool_names if isinstance(t, str) and t})
        web_tools = [t for t in available_tool_names if t in {"web_search", "web_search_tavily"}]

        forced_tool_choice: Dict[str, Any] | None = None
        if web_tools:
            try:
                decision_prompt = prompts.get("web_search_decision_prompt") or ""
                if decision_prompt:
                    decision_messages = [
                        {"role": "system", "content": decision_prompt},
                        {
                            "role": "user",
                            "content": json.dumps(
                                {
                                    "question": question,
                                    "has_context": bool(context_summaries),
                                    "available_tools": web_tools,
                                },
                                ensure_ascii=False,
                            ),
                        },
                    ]
                    decision_kwargs: Dict[str, Any] = {
                        "model": selected_model,
                        "messages": decision_messages,
                    }
                    if self._supports_temperature(selected_model):
                        decision_kwargs["temperature"] = 0.0
                    decision_resp = await asyncio.to_thread(
                        self._get_client(selected_model).chat.completions.create, **decision_kwargs
                    )
                    decision_text = (decision_resp.choices[0].message.content or "").strip()
                    decision = json.loads(decision_text) if decision_text else {}
                    if isinstance(decision, dict) and decision.get("use_web_search") is True:
                        tool_name = decision.get("tool_name") if decision.get("tool_name") in web_tools else None
                        query = decision.get("query") if isinstance(decision.get("query"), str) else None
                        if query:
                            messages.append(
                                {
                                    "role": "system",
                                    "content": f"If you perform web search, use this query: {query}",
                                }
                            )
                        if tool_name:
                            forced_tool_choice = {"type": "function", "function": {"name": tool_name}}
            except Exception:  # noqa: BLE001
                forced_tool_choice = None

        for iteration in range(max_iterations):
            create_kwargs: Dict[str, Any] = {
                "model": selected_model,
                "messages": messages,
                "tools": tools,
                "tool_choice": "auto",
            }
            if self._supports_temperature(selected_model):
                create_kwargs["temperature"] = 0.3
            if iteration == 0 and forced_tool_choice is not None:
                create_kwargs["tool_choice"] = forced_tool_choice

            response = await asyncio.to_thread(
                self._get_client(selected_model).chat.completions.create, **create_kwargs
            )

            usage_details = self._extract_usage_details(response)
            if usage_sink is not None and usage_details:
                for k, v in usage_details.items():
                    usage_sink[k] = usage_sink.get(k, 0) + v

            message = response.choices[0].message

            # If no tool calls, return the response
            if not message.tool_calls:
                answer = (message.content or "").strip()
                return answer

            # Add assistant message with tool calls
            messages.append(message.model_dump())

            # Execute tool calls (parallel when multiple calls are present)
            if len(message.tool_calls) == 1:
                tool_call = message.tool_calls[0]
                tool_name = tool_call.function.name
                try:
                    arguments = json.loads(tool_call.function.arguments)
                except json.JSONDecodeError:
                    arguments = {}
                result = await tool_executor.execute_tool_call(tool_name, arguments)
                if tool_usage_sink is not None:
                    tool_usage_sink[tool_name] = tool_usage_sink.get(tool_name, 0) + 1
                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": tool_call.id,
                        "content": json.dumps(result),
                    }
                )
            else:
                # Build OpenAI-like call dicts for executor
                call_dicts: List[Dict[str, Any]] = [
                    {
                        "id": tc.id,
                        "function": {"name": tc.function.name, "arguments": tc.function.arguments},
                    }
                    for tc in message.tool_calls
                ]
                results = await tool_executor.execute_parallel_tools(call_dicts)
                for tc, result in zip(message.tool_calls, results):
                    if tool_usage_sink is not None:
                        tool_usage_sink[tc.function.name] = tool_usage_sink.get(tc.function.name, 0) + 1
                    messages.append(
                        {
                            "role": "tool",
                            "tool_call_id": tc.id,
                            "content": json.dumps(result),
                        }
                    )

        # Max iterations reached
        return "I apologize, but I reached the maximum number of tool iterations. Please try rephrasing your question."


openai_chat_service = OpenAIChatService()
