"""Langfuse-powered tracing utilities."""

from __future__ import annotations

from contextvars import ContextVar, Token
import json
import os
from typing import Any, Dict, List, Optional

from langfuse import Langfuse, LangfuseGeneration, LangfuseSpan

from src.core.settings.config import settings


class LangfuseTracer:
	"""Lazy Langfuse client wrapper with helper utilities."""

	def __init__(self) -> None:
		# Use pricing from settings
		self._PRICING_PER_TOKEN = {}
		if hasattr(settings, "MODEL_PRICING"):
			# Convert per-1M-token to per-token
			for model, prices in settings.MODEL_PRICING.items():
				self._PRICING_PER_TOKEN[model] = {
					"input": prices["input"] / 1_000_000,
					"output": prices["output"] / 1_000_000,
				}
		
		# Allow override from JSON config
		custom_pricing_raw = getattr(settings, "OPENAI_PRICING_PER_TOKEN_JSON", "") or ""
		if custom_pricing_raw.strip():
			try:
				custom = json.loads(custom_pricing_raw)
				if isinstance(custom, dict):
					self._PRICING_PER_TOKEN.update(custom)
			except Exception:
				pass
		self._client: Optional[Langfuse] = None
		self._enabled = bool(
			getattr(settings, "LANGFUSE_SECRET_KEY", None)
			and getattr(settings, "LANGFUSE_PUBLIC_KEY", None)
		)
		self._span_context: ContextVar[Optional[LangfuseSpan]] = ContextVar(
			"langfuse_current_span", default=None
		)

	def _get_client(self) -> Optional[Langfuse]:
		if not self._enabled:
			return None
		if self._client is None:
			# Disable Langfuse's OTEL HTTP tracing to avoid per-request noise.
			os.environ.setdefault("LANGFUSE_OTEL_ENABLED", "false")
			timeout_s = float(getattr(settings, "LANGFUSE_TIMEOUT_SECONDS", 15) or 15)
			self._client = Langfuse(
				public_key=getattr(settings, "LANGFUSE_PUBLIC_KEY", None),
				secret_key=getattr(settings, "LANGFUSE_SECRET_KEY", None),
				host=getattr(settings, "LANGFUSE_BASE_URL", None),
				environment=getattr(settings, "APP_ENV", None),
				release=getattr(settings, "APP_VERSION", None),
				timeout=timeout_s,
			)
		return self._client

	def start_trace(
		self,
		name: str,
		*,
		trace_id: Optional[str] = None,
		parent_span_id: Optional[str] = None,
		input: Optional[Any] = None,
		metadata: Optional[Dict[str, Any]] = None,
		tags: Optional[List[str]] = None,
	) -> Optional[LangfuseSpan]:
		client = self._get_client()
		if client is None:
			return None
		merged_metadata = self._with_environment(metadata)
		trace_context = None
		if trace_id:
			trace_context = {"trace_id": str(trace_id)}
			if parent_span_id:
				trace_context["parent_span_id"] = str(parent_span_id)
		span = client.start_span(name=name, input=input, metadata=merged_metadata, trace_context=trace_context)
		span.update_trace(
			metadata=merged_metadata,
			tags=tags or [name],
			version=getattr(settings, "APP_VERSION", None),
		)
		return span

	def start_child_span(
		self,
		parent: Optional[LangfuseSpan],
		name: str,
		*,
		input: Optional[Any] = None,
		metadata: Optional[Dict[str, Any]] = None,
	) -> Optional[LangfuseSpan]:
		if parent is None:
			return None
		merged_metadata = self._with_environment(metadata)
		return parent.start_span(name=name, input=input, metadata=merged_metadata)

	def end_span(
		self,
		span: Optional[LangfuseSpan],
		*,
		output: Optional[Any] = None,
		metadata: Optional[Dict[str, Any]] = None,
		status_message: Optional[str] = None,
	) -> None:
		if span is None:
			return
		update_kwargs: Dict[str, Any] = {}
		if output is not None:
			update_kwargs["output"] = output
		if metadata is not None:
			update_kwargs["metadata"] = self._with_environment(metadata)
		if status_message:
			update_kwargs["status_message"] = status_message
			update_kwargs["level"] = "ERROR"
		if update_kwargs:
			span.update(**update_kwargs)
		span.end()

	def start_generation(
		self,
		parent: Optional[LangfuseSpan],
		*,
		name: str,
		input: Optional[Any] = None,
		metadata: Optional[Dict[str, Any]] = None,
		model: Optional[str] = None,
	) -> Optional[LangfuseGeneration]:
		if parent is None:
			return None
		merged_metadata = self._with_environment(metadata)
		return parent.start_generation(
			name=name,
			input=input,
			metadata=merged_metadata,
			model=model,
		)

	def end_generation(
		self,
		generation: Optional[LangfuseGeneration],
		*,
		output: Optional[Any] = None,
		metadata: Optional[Dict[str, Any]] = None,
		usage_details: Optional[Dict[str, int]] = None,
		cost_details: Optional[Dict[str, float]] = None,
		status_message: Optional[str] = None,
	) -> None:
		if generation is None:
			return
		update_kwargs: Dict[str, Any] = {}
		if output is not None:
			update_kwargs["output"] = output
		if metadata is not None:
			update_kwargs["metadata"] = self._with_environment(metadata)
		if usage_details:
			update_kwargs["usage_details"] = usage_details
		if cost_details:
			update_kwargs["cost_details"] = cost_details
		if status_message:
			update_kwargs["status_message"] = status_message
			update_kwargs["level"] = "ERROR"
		if update_kwargs:
			generation.update(**update_kwargs)
		generation.end()

	def estimate_cost(self, model: str, usage_details: Dict[str, int]) -> Dict[str, float]:
		resolved = model
		aliases = getattr(settings, "MODEL_ALIASES", {}) or {}
		if isinstance(aliases, dict) and model in aliases:
			resolved = aliases.get(model) or model
		pricing = self._PRICING_PER_TOKEN.get(resolved)
		if not pricing or not usage_details:
			return {}
		input_tokens = usage_details.get("input_tokens") or usage_details.get("prompt_tokens") or 0
		output_tokens = (
			usage_details.get("output_tokens")
			or usage_details.get("completion_tokens")
			or usage_details.get("generated_tokens")
			or 0
		)
		input_cost = round(input_tokens * pricing["input"], 6)
		output_cost = round(output_tokens * pricing["output"], 6)
		return {
			"input_cost_usd": input_cost,
			"output_cost_usd": output_cost,
			"total_cost_usd": round(input_cost + output_cost, 6),
		}

	def _with_environment(self, metadata: Optional[Dict[str, Any]]) -> Dict[str, Any]:
		merged = {"environment": getattr(settings, "APP_ENV", "development")}
		if metadata:
			merged.update(metadata)
		return merged

	def bind_span(self, span: Optional[LangfuseSpan]) -> Optional[Token]:
		if span is None:
			return None
		return self._span_context.set(span)

	def reset_context(self, token: Optional[Token]) -> None:
		if token is None:
			return
		self._span_context.reset(token)

	def get_current_span(self) -> Optional[LangfuseSpan]:
		return self._span_context.get()


tracer = LangfuseTracer()

__all__ = ["tracer", "LangfuseTracer"]
