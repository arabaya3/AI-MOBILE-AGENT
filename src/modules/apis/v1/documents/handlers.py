"""Document API handlers."""

import re
from pathlib import Path
from typing import AsyncIterator, List, Optional
from urllib.parse import quote

from fastapi import HTTPException, Request, UploadFile, status
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.observability import tracer
from src.core.settings.config import settings
from src.services.databases.postgresql.models import Document, Space, User
from src.services.security.file_inspection import (
    UploadRejected,
    extension_of,
    receive_to_temp,
    sanitize_filename,
)
from . import ingest, pipeline
from .schemas import (
    AccessibleDocument,
    DocumentPermissionGrantRequest,
    DocumentPermissionGrantResponse,
    DocumentPermissionStatusRequest,
    DocumentPermissionStatusResponse,
    DocumentStatus,
    DocumentType,
    DocumentUploadAndVectorizeResponse,
    DocumentUploadResponse,
    DocumentVectorSearchRequest,
    DocumentVectorSearchResponse,
    DocumentVectorizeResponse,
    DocumentVisibilityUpdateRequest,
    DocumentVisibilityUpdateResponse,
)
from .service import document_service

_UPLOAD_ID = re.compile(r"^[A-Za-z0-9-]{8,64}$")
RETRYABLE_ERRORS = {"interrupted", "timeout", "indexing_failed", "processing_failed"}
_MEDIA_TYPES = {
    "pdf": "application/pdf",
    "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "csv": "text/csv; charset=utf-8",
    "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "txt": "text/plain; charset=utf-8",
}


def _rejection(exc: UploadRejected, *, legacy: bool = False) -> HTTPException:
    detail = exc.message if legacy else {"code": exc.code, "message": exc.message}
    return HTTPException(status_code=exc.status_code, detail=detail)


async def _space_context(db: AsyncSession, user: User, space_id: str) -> tuple[Space, bool]:
    from src.modules.apis.v1.spaces.service import spaces_service

    member = await spaces_service.require_active_member(db, space_id=space_id, user=user)
    space = await db.get(Space, space_id)
    if space is None or not space.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Space not found")
    return space, member.role == "admin" or user.role == "super_admin"


def document_out(doc: Document, *, user: User, is_admin: bool) -> AccessibleDocument:
    state, error = pipeline.effective_state(doc)
    may_manage = is_admin or doc.uploaded_by_user_id == user.id
    return AccessibleDocument(
        id=doc.id,
        filename=doc.filename,
        file_type=DocumentType(doc.file_type),
        uploaded_at=doc.uploaded_at,
        uploaded_by_user_id=doc.uploaded_by_user_id,
        is_hidden=bool(doc.is_hidden),
        file_size=doc.file_size,
        state=state,
        error_code=error if state == pipeline.FAILED else None,
        chunks_count=int(doc.chunks_count or 0),
        state_updated_at=doc.state_updated_at,
        can_retry=bool(may_manage and state == pipeline.FAILED and error in RETRYABLE_ERRORS and doc.s3_url),
    )


async def _accessible_document(db: AsyncSession, user: User, document_id: str, space_id: str) -> Document:
    accessible = await document_service.list_accessible_documents(db, user, space_id=space_id)
    doc = next((d for d in accessible if d.id == document_id), None)
    if doc is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")
    return doc


def _check_upload_id(upload_id: str) -> None:
    if not _UPLOAD_ID.match(upload_id):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid upload ID")


async def handle_stream_upload(
    request: Request,
    upload_id: str,
    filename: str,
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
) -> tuple[AccessibleDocument, bool]:
    """Raw-body upload. Authorization has already run; the body is read only now, in bounded chunks."""
    _check_upload_id(upload_id)
    space, is_admin = await _space_context(db, user, space_id)
    name = sanitize_filename(filename)
    try:
        ext = extension_of(name)
    except UploadRejected as exc:
        raise _rejection(exc) from exc

    existing = await ingest.find_by_upload_id(db, space_id=space_id, user_id=user.id, upload_id=upload_id)
    if existing is not None:
        return document_out(existing, user=user, is_admin=is_admin), False

    limit = int(settings.MAX_UPLOAD_BYTES)
    declared = request.headers.get("content-length")
    if declared and declared.isdigit() and int(declared) > limit:
        raise _rejection(UploadRejected("too_large", f"Files must be {limit // (1024 * 1024)} MiB or smaller.", 413))

    received = None
    try:
        received = await receive_to_temp(request.stream(), limit=limit, directory=pipeline.WORK_DIR)
        result = await ingest.ingest(
            db, user=user, space=space, received=received, filename=name, ext=ext, upload_id=upload_id
        )
    except UploadRejected as exc:
        raise _rejection(exc) from exc
    finally:
        if received is not None:
            received.path.unlink(missing_ok=True)
    await db.refresh(result.document)
    return document_out(result.document, user=user, is_admin=is_admin), result.created


async def handle_get_upload(upload_id: str, user: User, db: AsyncSession, *, space_id: str) -> AccessibleDocument:
    """Reconcile an upload whose response was lost: the uploader can look it up by its client ID."""
    _check_upload_id(upload_id)
    _, is_admin = await _space_context(db, user, space_id)
    doc = await ingest.find_by_upload_id(db, space_id=space_id, user_id=user.id, upload_id=upload_id)
    if doc is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Upload not found")
    return document_out(doc, user=user, is_admin=is_admin)


async def handle_get_document(document_id: str, user: User, db: AsyncSession, *, space_id: str) -> AccessibleDocument:
    _, is_admin = await _space_context(db, user, space_id)
    doc = await _accessible_document(db, user, document_id, space_id)
    return document_out(doc, user=user, is_admin=is_admin)


async def handle_retry_document(document_id: str, user: User, db: AsyncSession, *, space_id: str) -> AccessibleDocument:
    _, is_admin = await _space_context(db, user, space_id)
    doc = await _accessible_document(db, user, document_id, space_id)
    if not document_out(doc, user=user, is_admin=is_admin).can_retry:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This document cannot be retried")
    if not await pipeline.claim_for_retry(db, doc.id):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Processing is already running")
    await ingest.retry(db, doc, Path(doc.s3_url).suffix.lower())
    await db.refresh(doc)
    return document_out(doc, user=user, is_admin=is_admin)


async def _upload_file_chunks(file: UploadFile) -> AsyncIterator[bytes]:
    await file.seek(0)
    while chunk := await file.read(64 * 1024):
        yield chunk


async def handle_upload_document(
    file: UploadFile,
    db: AsyncSession,
    user: Optional[User] = None,
    *,
    space_id: str,
) -> DocumentUploadResponse:
    """Legacy multipart upload (web). Same validation and pipeline as the streaming route."""
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
    span = tracer.start_child_span(tracer.get_current_span(), "documents.upload", input={})
    space, _ = await _space_context(db, user, space_id)
    name = sanitize_filename(file.filename)
    received = None
    try:
        ext = extension_of(name)
        received = await receive_to_temp(
            _upload_file_chunks(file), limit=int(settings.MAX_UPLOAD_BYTES), directory=pipeline.WORK_DIR
        )
        result = await ingest.ingest(db, user=user, space=space, received=received, filename=name, ext=ext)
    except UploadRejected as exc:
        tracer.end_span(span, status_message=exc.code)
        raise _rejection(exc, legacy=True) from exc
    finally:
        if received is not None:
            received.path.unlink(missing_ok=True)
    doc = result.document
    await db.refresh(doc)
    state, error = pipeline.effective_state(doc)
    tracer.end_span(span, metadata={"document_id": doc.id, "state": state})
    message = "Document already uploaded; returning existing record." if result.duplicate else (
        "Document processed successfully" if state == pipeline.READY else f"Document processing failed ({error})"
    )
    return DocumentUploadResponse(
        document_id=doc.id,
        filename=doc.filename,
        file_type=DocumentType(doc.file_type),
        file_size=doc.file_size,
        status=DocumentStatus.COMPLETED if state == pipeline.READY else (
            DocumentStatus.FAILED if state == pipeline.FAILED else DocumentStatus.PROCESSING
        ),
        chunks_count=doc.chunks_count,
        uploaded_at=doc.uploaded_at,
        message=message,
    )


async def handle_upload_documents(
    files: List[UploadFile],
    db: AsyncSession,
    user: Optional[User] = None,
    *,
    space_id: str,
) -> List[DocumentUploadResponse]:
    """Uploads run one after another: they share one database session."""
    results = []
    for file in files:
        try:
            results.append(await handle_upload_document(file, db, user, space_id=space_id))
        except HTTPException as exc:
            results.append(exc)
    return results


async def handle_vectorize_document(document_id: str, user: User, db: AsyncSession, *, space_id: str) -> DocumentVectorizeResponse:
    """Re-index an extracted document. Indexing replaces the document's vectors, so repeats are safe."""
    doc = await _accessible_document(db, user, document_id, space_id)
    if not doc.chunks_data:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Document has no extracted text")
    await pipeline._set_state(db, doc, pipeline.INDEXING)
    try:
        details = await pipeline.index_document(doc)
    except Exception as exc:  # noqa: BLE001
        await pipeline._set_state(db, doc, pipeline.FAILED, "indexing_failed")
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Document indexing failed") from exc
    await pipeline._set_state(db, doc, pipeline.READY)
    return DocumentVectorizeResponse(
        document_id=doc.id,
        chunks_indexed=details["chunks_indexed"],
        collection=document_service.collection_name,
        message="Document chunks stored in vector database",
    )


async def handle_upload_and_vectorize(
    file: UploadFile,
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
) -> DocumentUploadAndVectorizeResponse:
    """Legacy web route: the pipeline already indexes, so this reports the result of one upload."""
    upload = await handle_upload_document(file, db, user, space_id=space_id)
    if upload.status != DocumentStatus.COMPLETED:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=upload.message)
    return DocumentUploadAndVectorizeResponse(
        upload=upload,
        vectorization=DocumentVectorizeResponse(
            document_id=upload.document_id,
            chunks_indexed=int(upload.chunks_count or 0),
            collection=document_service.collection_name,
        ),
    )


async def handle_vector_search(
    payload: DocumentVectorSearchRequest,
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
) -> DocumentVectorSearchResponse:
    """Semantic search over the caller's ready documents."""
    ready = document_service.ready_ids(await document_service.list_accessible_documents(db, user, space_id=space_id))
    if payload.document_ids:
        if set(payload.document_ids) - ready:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Document access denied")
        selected = list(payload.document_ids)
    else:
        selected = list(ready)
    if not selected:
        return DocumentVectorSearchResponse(query=payload.query, limit=payload.limit, results=[], answer="")
    try:
        search_payload = await document_service.search_vectors(
            payload.query, payload.limit, allowed_document_ids=selected, space_id=space_id
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Search is unavailable") from exc
    return DocumentVectorSearchResponse(
        query=payload.query,
        limit=payload.limit,
        results=[document_service.public_match(r) for r in search_payload.get("results", [])],
        answer=search_payload.get("answer", ""),
    )


async def handle_list_accessible_documents(user: User, db: AsyncSession, *, space_id: str) -> List[AccessibleDocument]:
    _, is_admin = await _space_context(db, user, space_id)
    documents = await document_service.list_accessible_documents(db, user, space_id=space_id)
    return [document_out(doc, user=user, is_admin=is_admin) for doc in documents]


async def handle_grant_permissions(
    payload: DocumentPermissionGrantRequest,
    db: AsyncSession,
    *,
    space_id: str,
) -> DocumentPermissionGrantResponse:
    try:
        granted = await document_service.grant_document_permissions(
            db,
            space_id=space_id,
            user_id=payload.user_id,
            document_ids=payload.document_ids,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return DocumentPermissionGrantResponse(granted=granted)


async def handle_revoke_permissions(payload, db: AsyncSession, *, space_id: str):
    from .schemas import DocumentPermissionRevokeResponse

    try:
        revoked = await document_service.revoke_document_permissions(
            db,
            space_id=space_id,
            user_id=payload.user_id,
            document_ids=payload.document_ids,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return DocumentPermissionRevokeResponse(revoked=revoked)


async def handle_permission_status(
    payload: DocumentPermissionStatusRequest,
    db: AsyncSession,
    *,
    space_id: str,
) -> DocumentPermissionStatusResponse:
    any_set, all_set = await document_service.get_permission_user_sets(
        db,
        space_id=space_id,
        document_ids=payload.document_ids,
    )
    return DocumentPermissionStatusResponse(any_user_ids=sorted(any_set), all_user_ids=sorted(all_set))


async def handle_get_document_chunks(document_id: str, user: User, db: AsyncSession, *, space_id: str):
    """Chunks of a document the caller may read (previously any space member could read any document's chunks)."""
    from .schemas import ChunkDetail, DocumentChunksResponse

    doc = await _accessible_document(db, user, document_id, space_id)
    chunks = await document_service.get_document_chunks(db, document_id)
    return DocumentChunksResponse(
        document_id=document_id,
        filename=doc.filename,
        chunks=[ChunkDetail(**chunk) for chunk in chunks],
    )


def content_disposition(filename: str, disposition: str = "inline") -> str:
    ascii_name = sanitize_filename(filename).encode("ascii", "replace").decode("ascii").replace("?", "_")
    ascii_name = ascii_name.replace('"', "_")
    return f"{disposition}; filename=\"{ascii_name}\"; filename*=UTF-8''{quote(sanitize_filename(filename))}"


async def handle_download_document(
    document_id: str,
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
) -> StreamingResponse:
    """Stream the stored original from object storage through the API; storage URLs never reach clients."""
    from src.services.cloud.aws.s3 import s3_service

    doc = await _accessible_document(db, user, document_id, space_id)
    if not doc.s3_url:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="The file was not stored")
    stream = s3_service.iter_object(doc.s3_url)
    try:
        first = await stream.__anext__()
    except StopAsyncIteration:
        first = b""
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="The file is unavailable") from exc

    async def body():
        yield first
        async for chunk in stream:
            yield chunk

    headers = {
        "Content-Disposition": content_disposition(doc.filename),
        "Cache-Control": "no-store",
        "X-Content-Type-Options": "nosniff",
        "Content-Security-Policy": "sandbox; default-src 'none'",
    }
    if doc.file_size:
        headers["Content-Length"] = str(doc.file_size)
    media_type = _MEDIA_TYPES.get((doc.file_type or "").lower(), "application/octet-stream")
    return StreamingResponse(body(), media_type=media_type, headers=headers)


async def handle_update_visibility(
    document_id: str,
    payload: DocumentVisibilityUpdateRequest,
    db: AsyncSession,
    *,
    space_id: str,
) -> DocumentVisibilityUpdateResponse:
    try:
        doc = await document_service.set_document_visibility(
            db,
            document_id=document_id,
            space_id=space_id,
            is_hidden=payload.is_hidden,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return DocumentVisibilityUpdateResponse(document_id=doc.id, is_hidden=bool(doc.is_hidden))
