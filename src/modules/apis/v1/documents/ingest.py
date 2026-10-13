"""Shared ingestion path for every upload route: validate, deduplicate, store, then process."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.settings.logging import logger
from src.services.cloud.aws.s3 import s3_service
from src.services.databases.postgresql.models import Document, Space, User
from src.services.security.file_inspection import ReceivedFile, inspect_content

from . import pipeline
from .service import document_service

_FILE_TYPES = {".pdf": "pdf", ".docx": "docx", ".xlsx": "xlsx", ".pptx": "pptx", ".csv": "csv"}


@dataclass
class IngestResult:
    document: Document
    created: bool
    duplicate: bool = False
    details: dict[str, Any] | None = None


async def find_by_upload_id(db: AsyncSession, *, space_id: str, user_id: str, upload_id: str) -> Document | None:
    result = await db.execute(
        select(Document).where(
            Document.space_id == space_id,
            Document.uploaded_by_user_id == user_id,
            Document.client_upload_id == upload_id,
        )
    )
    return result.scalar_one_or_none()


async def ingest(
    db: AsyncSession,
    *,
    user: User,
    space: Space,
    received: ReceivedFile,
    filename: str,
    ext: str,
    upload_id: str | None = None,
) -> IngestResult:
    """Caller owns `received.path` and must delete it. Raises UploadRejected for unacceptable content."""
    await asyncio.to_thread(inspect_content, received.path, ext)

    existing = await document_service.get_document_by_hash(db, received.sha256, space_id=space.id)
    if existing is not None:
        # Unchanged behavior: identical bytes in a space resolve to the existing document for the uploader.
        await document_service.grant_document_permissions(
            db, space_id=space.id, user_id=user.id, document_ids=[existing.id]
        )
        await db.commit()
        return IngestResult(existing, created=False, duplicate=True)

    doc = Document(
        id=str(uuid4()),
        space_id=space.id,
        filename=filename,
        file_type=_FILE_TYPES.get(ext, "txt"),
        file_size=received.size,
        file_hash=received.sha256,
        s3_url="",
        status="pending",
        state=pipeline.UPLOADED,
        uploaded_by_user_id=user.id,
        client_upload_id=upload_id,
    )
    db.add(doc)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        # A concurrent request with the same upload ID or the same bytes won the insert.
        winner = None
        if upload_id:
            winner = await find_by_upload_id(db, space_id=space.id, user_id=user.id, upload_id=upload_id)
        winner = winner or await document_service.get_document_by_hash(db, received.sha256, space_id=space.id)
        if winner is None:
            raise
        return IngestResult(winner, created=False, duplicate=True)

    await document_service.grant_document_permissions(db, space_id=space.id, user_id=user.id, document_ids=[doc.id])
    key = f"spaces/{space.id}/documents/{doc.id}{ext}"
    try:
        doc.s3_url = await s3_service.upload_file(received.path, key, bucket=space.s3_bucket)
    except Exception:  # noqa: BLE001
        logger.exception("Document storage failed", extra={"document_id": doc.id})
        await pipeline._set_state(db, doc, pipeline.FAILED, "storage_failed")
        return IngestResult(doc, created=True)
    await db.commit()

    details = await pipeline.process(db, doc, received.path, ext)
    return IngestResult(doc, created=True, details=details)


async def retry(db: AsyncSession, doc: Document, ext: str) -> dict[str, Any] | None:
    """Re-run processing from the stored original. Caller must have won `pipeline.claim_for_retry`."""
    pipeline.WORK_DIR.mkdir(parents=True, exist_ok=True)
    path = pipeline.WORK_DIR / f"retry-{uuid4().hex}{ext}"
    try:
        await s3_service.download_to_file(doc.s3_url, path)
        await db.refresh(doc)
        return await pipeline.process(db, doc, path, ext)
    except Exception:  # noqa: BLE001
        logger.exception("Document retry failed", extra={"document_id": doc.id})
        await pipeline._set_state(db, doc, pipeline.FAILED, "processing_failed")
        return None
    finally:
        Path(path).unlink(missing_ok=True)
