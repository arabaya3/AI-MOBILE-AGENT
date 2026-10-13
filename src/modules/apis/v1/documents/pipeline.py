"""Document ingestion: durable state transitions, isolated extraction, idempotent indexing.

Processing runs inside the upload request (no job queue exists in this deployment). Every state change
is committed on its own so status is readable from other requests, and no transaction stays open
during extraction or embedding. Work lost to a restart surfaces as `failed/interrupted` once its
lease expires, and can be retried explicitly.
"""

from __future__ import annotations

import asyncio
import json
import os
import sys
import tempfile
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

from sqlalchemy import or_, update
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.settings.config import settings
from src.core.settings.logging import logger
from src.services.databases.postgresql.models import Document
from src.services.databases.qdrant.client import qdrant_vector_store
from src.services.llm_providers.provider import get_embedding_service

UPLOADED, PROCESSING, INDEXING, READY, FAILED = "uploaded", "processing", "indexing", "ready", "failed"
ACTIVE_STATES = (UPLOADED, PROCESSING, INDEXING)
WORK_DIR = Path(tempfile.gettempdir()) / "teia-uploads"
_REPO_ROOT = Path(__file__).resolve().parents[5]


def lease_seconds() -> int:
    return int(settings.PROCESSING_TIMEOUT_SECONDS) * 2 + 60


def effective_state(doc: Document, now: datetime | None = None) -> tuple[str, str | None]:
    """Active work whose lease has expired was lost (restart or crash) and is reported as failed."""
    state = doc.state or READY
    if state in ACTIVE_STATES and doc.state_updated_at is not None:
        if (now or datetime.utcnow()) - doc.state_updated_at > timedelta(seconds=lease_seconds()):
            return FAILED, "interrupted"
    return state, doc.state_error


async def _set_state(db: AsyncSession, doc: Document, state: str, error: str | None = None) -> None:
    doc.state = state
    doc.state_error = error
    doc.state_updated_at = datetime.utcnow()
    doc.status = {READY: "completed", FAILED: "failed"}.get(state, "processing")
    await db.commit()


async def claim_for_retry(db: AsyncSession, document_id: str) -> bool:
    """Atomically move a failed (or abandoned) document back to processing; only one caller wins."""
    stale_before = datetime.utcnow() - timedelta(seconds=lease_seconds())
    result = await db.execute(
        update(Document)
        .where(
            Document.id == document_id,
            or_(
                Document.state == FAILED,
                Document.state.in_(ACTIVE_STATES) & (Document.state_updated_at < stale_before),
            ),
        )
        .values(state=PROCESSING, state_error=None, state_updated_at=datetime.utcnow(), status="processing")
    )
    await db.commit()
    return result.rowcount == 1


def _limit_resources() -> None:  # pragma: no cover - runs in the child process on Linux
    import resource

    memory = int(settings.EXTRACTION_MEMORY_LIMIT_MB) * 1024 * 1024
    resource.setrlimit(resource.RLIMIT_AS, (memory, memory))
    cpu = int(settings.PROCESSING_TIMEOUT_SECONDS) + 5
    resource.setrlimit(resource.RLIMIT_CPU, (cpu, cpu))


async def run_extraction(path: Path, ext: str) -> dict[str, Any]:
    """Extract in a child process with a wall-clock limit; returns {"ok", "chunks"} or {"ok": False, "code"}."""
    output = path.with_name(path.name + ".json")
    process = await asyncio.create_subprocess_exec(
        sys.executable,
        "-m",
        "src.services.processors.extract_worker",
        str(path),
        ext,
        str(output),
        cwd=str(_REPO_ROOT),
        stdout=asyncio.subprocess.DEVNULL,
        stderr=asyncio.subprocess.DEVNULL,
        preexec_fn=_limit_resources if os.name == "posix" else None,
    )
    try:
        await asyncio.wait_for(process.wait(), timeout=int(settings.PROCESSING_TIMEOUT_SECONDS))
    except asyncio.TimeoutError:
        process.kill()
        await process.wait()
        return {"ok": False, "code": "timeout"}
    except BaseException:
        process.kill()
        raise
    finally:
        if process.returncode is None:
            await process.wait()
    try:
        return json.loads(output.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        # No result file: the worker was killed by its memory/CPU limit.
        return {"ok": False, "code": "too_complex"}
    finally:
        output.unlink(missing_ok=True)


async def index_document(doc: Document) -> dict[str, Any]:
    """Embed the document's chunks and replace its vectors. Raises on any failure."""
    from .service import document_service

    records, texts = document_service._prepare_vector_records(doc)
    if not records:
        raise RuntimeError("no chunks to index")
    embedder = get_embedding_service()
    vectors: list[list[float]] = []
    usage = {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0}
    batch = 64
    for start in range(0, len(texts), batch):
        batch_vectors, batch_usage = await embedder.embed_texts_with_usage(texts[start : start + batch])
        for key in usage:
            usage[key] += int((batch_usage or {}).get(key) or 0)
        vectors.extend(batch_vectors)
    if len(vectors) != len(records) or any(not any(v) for v in vectors):
        # The OpenAI service returns zero vectors when a batch fails; such a document is not searchable.
        raise RuntimeError("embedding failed")
    await qdrant_vector_store.delete_document_points(doc.id)
    indexed = await qdrant_vector_store.upsert_chunks_batched(records, vectors, batch_size=batch)
    if indexed != len(records):
        raise RuntimeError("indexing incomplete")
    return {"chunks_indexed": indexed, "embedding_model": getattr(embedder, "model", ""), "usage": usage}


async def process(db: AsyncSession, doc: Document, path: Path, ext: str) -> dict[str, Any] | None:
    """Extract and index a stored document. Leaves it `ready` or `failed`; returns indexing details on success."""
    if doc.state != PROCESSING:
        await _set_state(db, doc, PROCESSING)
    started = time.monotonic()
    result = await run_extraction(path, ext)
    if not result.get("ok"):
        logger.info("Document extraction rejected", extra={"document_id": doc.id, "code": result.get("code")})
        await _set_state(db, doc, FAILED, str(result.get("code") or "corrupt"))
        return None

    chunks = result["chunks"]
    doc.chunks_data = chunks
    doc.chunks_count = len(chunks)
    doc.processing_time = int((time.monotonic() - started) * 1000)
    await _set_state(db, doc, INDEXING)
    try:
        details = await index_document(doc)
    except Exception:  # noqa: BLE001
        logger.exception("Document indexing failed", extra={"document_id": doc.id})
        await _set_state(db, doc, FAILED, "indexing_failed")
        return None
    doc.processed_at = datetime.utcnow()
    await _set_state(db, doc, READY)
    return details
