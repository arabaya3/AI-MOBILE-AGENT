"""Shared ingestion path for every upload route: validate, deduplicate, store, then process.

Deduplication never grants access. Identical bytes resolve to the existing document only when the
uploader can already read it; otherwise the upload is refused without revealing anything about it.
Every accepted client upload ID gets a receipt so a lost response can be reconciled later.
"""

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
from src.services.databases.postgresql.models import Document, DocumentUploadReceipt, Space, User
from src.services.security.file_inspection import ReceivedFile, UploadRejected, inspect_content

from . import pipeline
from .service import document_service

_FILE_TYPES = {".pdf": "pdf", ".docx": "docx", ".xlsx": "xlsx", ".pptx": "pptx", ".csv": "csv"}


def duplicate_conflict() -> UploadRejected:
    # Deliberately generic: says nothing about who owns the matching file or whether it is hidden.
    return UploadRejected("duplicate_conflict", "This file can't be added to this space.", 409)


def upload_id_reused() -> UploadRejected:
    return UploadRejected("upload_id_reused", "This upload ID was already used for a different file.", 409)


@dataclass
class IngestResult:
    document: Document
    created: bool
    duplicate: bool = False
    details: dict[str, Any] | None = None


async def _reload(db: AsyncSession, *objects) -> None:
    """A rollback expires every loaded object; async sessions cannot lazy-load them back."""
    for obj in objects:
        await db.refresh(obj)


async def can_read(db: AsyncSession, user: User, space_id: str, document_id: str) -> bool:
    accessible = await document_service.list_accessible_documents(db, user, space_id=space_id)
    return any(doc.id == document_id for doc in accessible)


async def find_receipt(db: AsyncSession, *, space_id: str, user_id: str, upload_id: str) -> DocumentUploadReceipt | None:
    result = await db.execute(
        select(DocumentUploadReceipt).where(
            DocumentUploadReceipt.space_id == space_id,
            DocumentUploadReceipt.user_id == user_id,
            DocumentUploadReceipt.upload_id == upload_id,
        )
    )
    return result.scalar_one_or_none()


async def resolve_receipt(db: AsyncSession, user: User, space_id: str, upload_id: str) -> Document | None:
    """The document an accepted upload ID resolved to, if the uploader can still read it."""
    receipt = await find_receipt(db, space_id=space_id, user_id=user.id, upload_id=upload_id)
    if receipt is None or not await can_read(db, user, space_id, receipt.document_id):
        return None
    return await document_service.get_document(db, receipt.document_id)


async def _replay(db: AsyncSession, user: User, space: Space, upload_id: str, sha256: str) -> IngestResult | None:
    """A repeated upload ID: same bytes return the original result, different bytes are refused."""
    receipt = await find_receipt(db, space_id=space.id, user_id=user.id, upload_id=upload_id)
    if receipt is None:
        return None
    if receipt.file_hash != sha256:
        raise upload_id_reused()
    if not await can_read(db, user, space.id, receipt.document_id):
        raise duplicate_conflict()
    return IngestResult(await document_service.get_document(db, receipt.document_id), created=False, duplicate=True)


async def _accept_duplicate(db: AsyncSession, user: User, space: Space, existing: Document, upload_id: str | None, sha256: str) -> IngestResult:
    if not await can_read(db, user, space.id, existing.id):
        raise duplicate_conflict()
    if upload_id:
        db.add(DocumentUploadReceipt(space_id=space.id, user_id=user.id, upload_id=upload_id, document_id=existing.id, file_hash=sha256))
        try:
            await db.commit()
        except IntegrityError:
            await db.rollback()
            await _reload(db, user, space)
            # The same upload ID was accepted concurrently; answer like a repeat.
            replay = await _replay(db, user, space, upload_id, sha256)
            if replay is None:
                raise
            return replay
    return IngestResult(existing, created=False, duplicate=True)


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
    if upload_id:
        replay = await _replay(db, user, space, upload_id, received.sha256)
        if replay is not None:
            return replay

    await asyncio.to_thread(inspect_content, received.path, ext)

    existing = await document_service.get_document_by_hash(db, received.sha256, space_id=space.id)
    if existing is not None:
        return await _accept_duplicate(db, user, space, existing, upload_id, received.sha256)

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
    )
    try:
        db.add(doc)
        await db.flush()  # the receipt references the document, so it must exist first
        if upload_id:
            db.add(DocumentUploadReceipt(space_id=space.id, user_id=user.id, upload_id=upload_id, document_id=doc.id, file_hash=received.sha256))
        await db.commit()
    except IntegrityError:
        await db.rollback()
        # Otherwise the failed insert stays pending and the next query flushes it again.
        if doc in db:
            db.expunge(doc)
        await _reload(db, user, space)
        # A concurrent request inserted the same upload ID or the same bytes first.
        if upload_id:
            replay = await _replay(db, user, space, upload_id, received.sha256)
            if replay is not None:
                return replay
        winner = await document_service.get_document_by_hash(db, received.sha256, space_id=space.id)
        if winner is None:
            raise
        return await _accept_duplicate(db, user, space, winner, upload_id, received.sha256)

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
