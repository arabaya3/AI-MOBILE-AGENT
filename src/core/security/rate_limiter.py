"""Rate limiting and throttling."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from src.core.memory.cache import get_cache


@dataclass
class RateLimitResult:
	allowed: bool
	remaining: int
	reset_seconds: int


class RateLimiter:
	def __init__(self, window_seconds: int = 60) -> None:
		self.window_seconds = window_seconds
		self.cache = get_cache()

	async def hit(self, key: str, limit: int) -> RateLimitResult:
		if limit <= 0:
			return RateLimitResult(allowed=True, remaining=limit, reset_seconds=self.window_seconds)

		current = await self.cache.incr(key, ttl=self.window_seconds)
		remaining = max(0, limit - current)
		return RateLimitResult(
			allowed=current <= limit,
			remaining=remaining,
			reset_seconds=self.window_seconds,
		)


rate_limiter = RateLimiter()
