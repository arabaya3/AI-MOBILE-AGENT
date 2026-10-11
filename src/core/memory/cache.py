"""Caching layer implementation."""

from __future__ import annotations

import asyncio
import time
from typing import Any, Optional

from src.core.settings.config import settings


class CacheBase:
	async def get(self, key: str) -> Any:
		raise NotImplementedError

	async def set(self, key: str, value: Any, ttl: int | None = None) -> None:
		raise NotImplementedError

	async def incr(self, key: str, ttl: int | None = None) -> int:
		raise NotImplementedError

	async def ping(self) -> bool:
		return True


class InMemoryCache(CacheBase):
	def __init__(self) -> None:
		self._store: dict[str, tuple[Any, float | None]] = {}
		self._lock = asyncio.Lock()

	async def get(self, key: str) -> Any:
		async with self._lock:
			item = self._store.get(key)
			if not item:
				return None
			value, expires_at = item
			if expires_at is not None and expires_at <= time.time():
				self._store.pop(key, None)
				return None
			return value

	async def set(self, key: str, value: Any, ttl: int | None = None) -> None:
		expires_at = time.time() + ttl if ttl else None
		async with self._lock:
			self._store[key] = (value, expires_at)

	async def incr(self, key: str, ttl: int | None = None) -> int:
		async with self._lock:
			item = self._store.get(key)
			current = 0
			if item:
				stored_value, expires_at = item
				if expires_at is None or expires_at > time.time():
					current = stored_value
			value = int(current) + 1
			expires_at = time.time() + ttl if ttl else None
			self._store[key] = (value, expires_at)
			return value


class RedisCache(CacheBase):
	def __init__(self, redis_url: str) -> None:
		import redis.asyncio as redis

		self._client = redis.from_url(redis_url, decode_responses=True)

	async def get(self, key: str) -> Any:
		return await self._client.get(key)

	async def set(self, key: str, value: Any, ttl: int | None = None) -> None:
		if ttl:
			await self._client.set(key, value, ex=ttl)
		else:
			await self._client.set(key, value)

	async def incr(self, key: str, ttl: int | None = None) -> int:
		value = await self._client.incr(key)
		if ttl:
			await self._client.expire(key, ttl)
		return int(value)

	async def ping(self) -> bool:
		try:
			return bool(await self._client.ping())
		except Exception:  # noqa: BLE001
			return False


_cache: Optional[CacheBase] = None


def get_cache() -> CacheBase:
	global _cache
	if _cache is not None:
		return _cache
	if getattr(settings, "REDIS_ENABLED", False):
		_cache = RedisCache(settings.redis_url)
	else:
		_cache = InMemoryCache()
	return _cache
