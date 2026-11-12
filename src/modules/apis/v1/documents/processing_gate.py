"""Deployment-wide cap on concurrent document processing (extraction, embedding, indexing).

`MAX_CONCURRENT_DOCUMENT_PROCESSING` = 0 means unlimited. Otherwise each operation must hold one of
that many Postgres advisory locks, taken on a dedicated connection for the whole operation, so the cap
holds across workers and containers sharing the database. Postgres releases the lock if the connection
dies. Callers that find every slot taken get 503 with Retry-After; nothing has been stored by then.
"""

from __future__ import annotations

from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import HTTPException, status
from sqlalchemy import text

from src.core.settings.config import settings
from src.core.settings.logging import logger
from src.services.databases.postgresql import database

LOCK_BASE = 742_000  # arbitrary namespace for this lock family
RETRY_AFTER_SECONDS = 30


def busy() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail={"code": "processing_busy", "message": "Another document is being processed. Try again shortly."},
        headers={"Retry-After": str(RETRY_AFTER_SECONDS)},
    )


@asynccontextmanager
async def processing_slot() -> AsyncIterator[None]:
    limit = int(getattr(settings, "MAX_CONCURRENT_DOCUMENT_PROCESSING", 0) or 0)
    if limit <= 0:
        yield
        return
    conn = await database.engine.connect()
    held: int | None = None
    try:
        for key in range(LOCK_BASE, LOCK_BASE + limit):
            if (await conn.execute(text("SELECT pg_try_advisory_lock(:k)"), {"k": key})).scalar():
                held = key
                break
        await conn.commit()  # end the implicit transaction; session-level locks persist
        if held is None:
            raise busy()
        yield
    finally:
        try:
            if held is not None:
                await conn.execute(text("SELECT pg_advisory_unlock(:k)"), {"k": held})
                await conn.commit()
        except Exception:  # noqa: BLE001
            # Never return a connection that may still hold the lock to the pool.
            logger.warning("Processing slot unlock failed; discarding connection", exc_info=True)
            await conn.invalidate()
        finally:
            await conn.close()
