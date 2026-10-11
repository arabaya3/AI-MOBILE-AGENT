"""PostgreSQL client wrapper."""

from __future__ import annotations

from sqlalchemy import text

from src.services.databases.postgresql.database import engine


class PostgresClient:
	async def ping(self) -> bool:
		try:
			async with engine.connect() as conn:
				await conn.execute(text("SELECT 1"))
			return True
		except Exception:  # noqa: BLE001
			return False


postgres_client = PostgresClient()
