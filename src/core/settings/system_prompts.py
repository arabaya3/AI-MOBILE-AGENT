"""Runtime-configurable system prompts."""

from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path
from threading import Lock
from typing import Dict, Tuple

from src.core.settings.config import settings
from src.core.settings.logging import logger


DEFAULT_PROMPTS: Dict[str, str] = {
    "tools_system_prompt": (
        "You are TEIA's enterprise assistant with access to tools. "
        "Use the provided document snippets and conversation context first. "
        "Decide whether web search is needed for current or external information; if needed, call a web search tool before answering. "
        "Never fabricate facts or sources. "
        "If web search returns results, summarize them and include a Sources list of URLs. "
        "If a tool fails or returns no results, say so clearly and suggest the next step. "
        "Use calculator for math, analyze_data for CSV/Excel, code_executor for safe math expressions, document_ops for document retrieval, and usage_query for usage/costs. "
        "Respond in English with concise, well-structured Markdown."
    ),
    "web_search_decision_prompt": (
        "You are a tool-routing agent. Decide whether a web search is necessary to answer the user. "
        "ALWAYS use web search if the user explicitly asks for: 'search', 'internet', 'web', 'online', 'latest news', 'today', 'current', or 'recent' information. "
        "Also use web search for time-sensitive queries about news, sports, stocks, weather, or any real-world events. "
        "Respond ONLY as a compact JSON object with keys: use_web_search (boolean), tool_name (string or null), query (string or null). "
        "tool_name must be one of the available tools passed to you (usually 'web_search_tavily'). "
        "If you set use_web_search=false, set tool_name and query to null. "
        "If you set use_web_search=true, extract a clear search query from the user's question."
    ),
    "memory_system_prompt": (
        "You are TEIA's enterprise assistant. "
        "Answer using ONLY the provided document snippets and the conversation context. "
        "If information is missing, say what is missing and how to provide it (e.g., upload the document or specify a section). "
        "Do not fabricate details. "
        "Respond in English with concise, well-structured Markdown."
    ),
    "stream_system_prompt": (
        "You are TEIA's enterprise assistant. "
        "Answer using ONLY the provided document snippets and the conversation context. "
        "If information is missing, say what is missing and how to provide it (e.g., upload the document or specify a section). "
        "Do not fabricate details. "
        "Respond in English with concise, well-structured Markdown."
    ),
    "answer_question_system_prompt": (
        "You are a helpful assistant that answers using ONLY the provided document snippets. "
        "If the user requests a complete list, extract and list items faithfully. "
        "If the question is broad, provide a structured summary from the snippets and state what is missing. "
        "Do not fabricate details. "
        "Prefer clear Markdown. "
        "Respond in English."
    ),
}

_prompt_lock = Lock()
_current_prompts: Dict[str, str] = dict(DEFAULT_PROMPTS)
# Identity of the file the cache was loaded from: (mtime_ns, size), or None when it did not exist.
# Comparing whole signatures (not "newer than") also catches a file another worker created after
# this one started, and changes within the filesystem's timestamp granularity that alter the size.
_current_signature: Tuple[int, int] | None = None


def _prompts_path() -> Path:
    configured = (getattr(settings, "SYSTEM_PROMPTS_PATH", "") or "").strip()
    path = Path(configured or "configs/system_prompts.json")
    return path


def _signature(path: Path) -> Tuple[int, int] | None:
    try:
        stat = path.stat()
    except OSError:
        return None
    return (stat.st_mtime_ns, stat.st_size)


def _merge(base: Dict[str, str], data: object) -> Dict[str, str]:
    merged = dict(base)
    if isinstance(data, dict):
        for key, value in data.items():
            if key in merged and isinstance(value, str) and value.strip():
                merged[key] = value
    return merged


def _load_from_disk(path: Path) -> Dict[str, str]:
    if not path.exists():
        return dict(DEFAULT_PROMPTS)
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        logger.warning("Failed to read system prompts; using defaults", extra={"error": str(exc), "path": str(path)})
        return dict(DEFAULT_PROMPTS)
    return _merge(DEFAULT_PROMPTS, data)


def load_system_prompts() -> Dict[str, str]:
    global _current_prompts, _current_signature
    with _prompt_lock:
        path = _prompts_path()
        # Signature first: a write landing in between makes the next read reload again.
        signature = _signature(path)
        _current_prompts = _load_from_disk(path)
        _current_signature = signature
        return dict(_current_prompts)


def get_system_prompts() -> Dict[str, str]:
    """Current prompts; reloads whenever the file appeared, changed or disappeared since the last load."""
    if _signature(_prompts_path()) != _current_signature:
        return load_system_prompts()
    return dict(_current_prompts)


def save_system_prompts(updated: Dict[str, str]) -> Dict[str, str]:
    """Persists atomically (temp file + rename), then updates memory. A failed write raises and leaves
    both the file and the in-memory prompts unchanged."""
    global _current_prompts, _current_signature
    with _prompt_lock:
        path = _prompts_path()
        # Start from what is on disk now, so a concurrent writer's keys are not silently reverted.
        base = _load_from_disk(path) if _signature(path) != _current_signature else _current_prompts
        merged = _merge(base, updated or {})
        path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                json.dump(merged, handle, ensure_ascii=False, indent=2)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(tmp, path)
        except BaseException:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise
        _current_prompts = merged
        _current_signature = _signature(path)
        return dict(_current_prompts)


# Load once at import time.
load_system_prompts()
