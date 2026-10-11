"""Observability and monitoring implementation."""

from __future__ import annotations

from src.core.observability.metrics import metrics


def record_http_request(method: str, path: str, status_code: int, duration_s: float) -> None:
	metrics.record_request(method, path, status_code, duration_s)
