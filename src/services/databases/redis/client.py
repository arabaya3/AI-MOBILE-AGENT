"""Redis client wrapper."""

from __future__ import annotations

from src.core.settings.config import settings


class RedisClient:
	def __init__(self) -> None:
		self._client = None

	def _get_client(self):
		if self._client is None:
			import redis.asyncio as redis

			self._client = redis.from_url(settings.redis_url, decode_responses=True)
		return self._client

	async def ping(self) -> bool:
		try:
			if not settings.REDIS_ENABLED:
				return False
			return bool(await self._get_client().ping())
		except Exception:  # noqa: BLE001
			return False


redis_client = RedisClient()
