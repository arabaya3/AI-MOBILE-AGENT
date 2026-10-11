"""Neo4j client wrapper."""

from __future__ import annotations

from neo4j import AsyncGraphDatabase

from src.core.settings.config import settings


class Neo4jClient:
	def __init__(self) -> None:
		self._driver = None

	def _get_driver(self):
		if self._driver is None:
			self._driver = AsyncGraphDatabase.driver(
				settings.NEO4J_URI,
				auth=(settings.NEO4J_USER, settings.NEO4J_PASSWORD),
			)
		return self._driver

	async def ping(self) -> bool:
		try:
			driver = self._get_driver()
			async with driver.session() as session:
				await session.run("RETURN 1")
			return True
		except Exception:  # noqa: BLE001
			return False


neo4j_client = Neo4jClient()
