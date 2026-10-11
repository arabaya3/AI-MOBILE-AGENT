"""Metrics collection and reporting."""

from __future__ import annotations

from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest


class Metrics:
	def __init__(self) -> None:
		self.http_requests_total = Counter(
			"http_requests_total",
			"Total HTTP requests",
			["method", "path", "status"],
		)
		self.http_request_duration = Histogram(
			"http_request_duration_seconds",
			"HTTP request duration in seconds",
			["method", "path"],
		)

	def record_request(self, method: str, path: str, status_code: int, duration_s: float) -> None:
		self.http_requests_total.labels(method=method, path=path, status=str(status_code)).inc()
		self.http_request_duration.labels(method=method, path=path).observe(duration_s)

	@staticmethod
	def render() -> tuple[bytes, str]:
		return generate_latest(), CONTENT_TYPE_LATEST


metrics = Metrics()
