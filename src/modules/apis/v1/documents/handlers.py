"""Document upload handlers."""

import asyncio
import hashlib
from datetime import datetime
from typing import List, Optional
from uuid import uuid4

from fastapi import HTTPException, UploadFile, status
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.observability import tracer
from src.services.databases.postgresql.models import User
from .schemas import (
    AccessibleDocument,
    DocumentPermissionGrantRequest,
    DocumentPermissionGrantResponse,
    DocumentPermissionStatusRequest,
    DocumentPermissionStatusResponse,
    DocumentType,
    DocumentUploadAndVectorizeResponse,
    DocumentUploadResponse,
    DocumentStatus,
    DocumentVisibilityUpdateRequest,
    DocumentVisibilityUpdateResponse,
    DocumentVectorSearchRequest,
    DocumentVectorSearchResponse,
    DocumentVectorizeResponse,
)
from .service import document_service


async def handle_upload_document(
    file: UploadFile,
    db: AsyncSession,
    user: Optional[User] = None,
    *,
    space_id: str,
) -> DocumentUploadResponse:
    """Handle single document upload and processing.
    
    Args:
        file: Uploaded file
        
    Returns:
        DocumentUploadResponse with upload details
        
    Raises:
        HTTPException: If file type not supported or processing fails
    """
    parent_span = tracer.get_current_span()
    span = tracer.start_child_span(
        parent_span,
        "documents.upload",
        input={
            "filename": file.filename,
            "content_type": file.content_type,
        },
    )

    try:
        file_type = document_service.get_file_type(file.filename)
    except ValueError as exc:
        tracer.end_span(span, status_message=str(exc))
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc)
        ) from exc

    try:
        await file.seek(0)
        file_bytes = await file.read()
        duplicate_hash = hashlib.sha256(file_bytes).hexdigest()
    finally:
        await file.seek(0)

    existing_doc = await document_service.get_document_by_hash(db, duplicate_hash, space_id=space_id)
    if existing_doc is not None:
        if user is not None:
            try:
                await document_service.grant_document_permissions(
                    db,
                    space_id=space_id,
                    user_id=user.id,
                    document_ids=[existing_doc.id],
                )
            except Exception:
                pass
        existing_status = DocumentStatus(existing_doc.status)
        response = DocumentUploadResponse(
            document_id=existing_doc.id,
            filename=existing_doc.filename,
            file_type=DocumentType(existing_doc.file_type),
            file_size=existing_doc.file_size,
            status=existing_status,
            chunks_count=existing_doc.chunks_count,
            uploaded_at=existing_doc.uploaded_at or datetime.utcnow(),
            message="Document already uploaded; returning existing record.",
        )
        tracer.end_span(
            span,
            metadata={
                "document_id": existing_doc.id,
                "status": existing_status.value,
                "duplicate": True,
            },
        )
        return response

    document_id = str(uuid4())

    file_path = None

    try:
        from src.services.databases.postgresql.models import Space

        space = await db.get(Space, space_id)
        if space is None or not space.is_active:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Space not found")

        file_path, file_hash, s3_url = await document_service.save_file(
            file,
            document_id,
            space_id=space_id,
            bucket=space.s3_bucket,
        )
        file_size = file_path.stat().st_size
        result = await document_service.process_document(file_path, file_type)
        await document_service.save_to_db(
            db,
            document_id,
            space_id,
            file.filename,
            file_type,
            file_size,
            file_hash,
            s3_url,
            result,
            uploaded_by_user_id=user.id if user is not None else None,
        )
        if user is not None:
            try:
                await document_service.grant_document_permissions(
                    db,
                    space_id=space_id,
                    user_id=user.id,
                    document_ids=[document_id],
                )
            except Exception:
                pass
    except Exception as exc:  # noqa: BLE001
        tracer.end_span(span, status_message=str(exc))
        raise
    finally:
        if file_path is not None:
            document_service.cleanup_file(file_path)

    response = DocumentUploadResponse(
        document_id=document_id,
        filename=file.filename,
        file_type=file_type,
        file_size=file_size,
        status=result["status"],
        chunks_count=result.get("chunks_count", 0),
        message=result.get("error", "Document processed successfully"),
    )

    tracer.end_span(
        span,
        metadata={
            "document_id": document_id,
            "status": response.status.value,
            "chunks_count": response.chunks_count,
        },
    )

    return response


async def handle_upload_documents(
    files: List[UploadFile],
    db: AsyncSession,
    user: Optional[User] = None,
    *,
    space_id: str,
) -> List[DocumentUploadResponse]:
    """Handle multiple document uploads and processing.
    
    Args:
        files: List of uploaded files
        db: Database session
        
    Returns:
        List of DocumentUploadResponse for each file
    """
    span = tracer.start_child_span(
        tracer.get_current_span(),
        "documents.upload_batch",
        input={"files": len(files)},
    )
    try:
        tasks = [handle_upload_document(file, db, user, space_id=space_id) for file in files]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        tracer.end_span(span, metadata={"files": len(files)})
        return results
    except Exception as exc:  # noqa: BLE001
        tracer.end_span(span, status_message=str(exc))
        raise


async def handle_vectorize_document(document_id: str, user: User, db: AsyncSession, *, space_id: str) -> DocumentVectorizeResponse:
    """Index document chunks into the vector store."""
    span = tracer.start_child_span(
        tracer.get_current_span(),
        "documents.vectorize",
        input={"document_id": document_id},
    )
    try:
        doc = await document_service.get_document(db, document_id)
        if doc is None or doc.space_id != space_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")
        result = await document_service.vectorize_document(db, document_id)
        if str(result.get("status")) != "success" or int(result.get("chunks_indexed") or 0) <= 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=str(result.get("error") or "Document vectorization failed"),
            )
    except ValueError as exc:
        tracer.end_span(span, status_message=str(exc))
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except RuntimeError as exc:
        tracer.end_span(span, status_message=str(exc))
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc)) from exc

    embedding_model = result.get("embedding_model")
    embedding_usage = result.get("embedding_usage") or {}
    if embedding_model and embedding_usage:
        from src.modules.apis.v1.chat.service import chat_service
        from src.core.observability import tracer as _tracer

        cost_details = _tracer.estimate_cost(str(embedding_model), embedding_usage)
        await chat_service.record_usage_event(
            db,
            space_id=space_id,
            user_id=user.id,
            session_id=None,
            endpoint="documents.vectorize.embed",
            model=str(embedding_model),
            usage_details=embedding_usage,
            cost_usd=cost_details.get("total_cost_usd") if cost_details else None,
            meta_payload={"document_id": document_id, "chunks_indexed": int(result.get("chunks_indexed") or 0)},
        )

    response = DocumentVectorizeResponse(
        document_id=result["document_id"],
        chunks_indexed=result["chunks_indexed"],
        collection=result["collection"],
        message="Document chunks stored in vector database",
    )
    tracer.end_span(
        span,
        metadata={
            "document_id": document_id,
            "chunks_indexed": response.chunks_indexed,
        },
    )
    return response


async def handle_vector_search(
    payload: DocumentVectorSearchRequest,
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
) -> DocumentVectorSearchResponse:
    """Perform a semantic search over indexed chunks honoring user permissions."""
    span = tracer.start_child_span(
        tracer.get_current_span(),
        "documents.vector_search",
        input={"query": payload.query, "limit": payload.limit, "user_id": user.id},
    )
    accessible_docs = await document_service.list_accessible_documents(db, user, space_id=space_id)
    if not accessible_docs:
        tracer.end_span(span, metadata={"results": 0, "answer_present": False})
        return DocumentVectorSearchResponse(query=payload.query, limit=payload.limit, results=[], answer="")
    allowed_ids = {doc.id for doc in accessible_docs}
    selected_ids = None
    if payload.document_ids:
        invalid = set(payload.document_ids) - allowed_ids
        if invalid:
            tracer.end_span(span, status_message="Unauthorized document access requested")
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Document access denied")
        selected_ids = payload.document_ids
    else:
        selected_ids = list(allowed_ids)
    try:
        # Capture embedding usage for query vectorization.
        from src.services.embeddings.openai import embedding_service
        from src.modules.apis.v1.chat.service import chat_service
        from src.core.observability import tracer as _tracer

        query_embeddings, usage_details = await embedding_service.embed_texts_with_usage([payload.query])
        query_embedding = query_embeddings[0] if query_embeddings else None

        if usage_details:
            cost_details = _tracer.estimate_cost(embedding_service.model, usage_details)
            await chat_service.record_usage_event(
                db,
                space_id=space_id,
                user_id=user.id,
                session_id=None,
                endpoint="documents.vector_search.embed",
                model=embedding_service.model,
                usage_details=usage_details,
                cost_usd=cost_details.get("total_cost_usd") if cost_details else None,
                meta_payload={"limit": payload.limit},
            )

        search_payload = await document_service.search_vectors(
            payload.query,
            payload.limit,
            allowed_document_ids=selected_ids,
            query_embedding=query_embedding,
            space_id=space_id,
        )
    except RuntimeError as exc:
        tracer.end_span(span, status_message=str(exc))
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc)) from exc

    response = DocumentVectorSearchResponse(
        query=payload.query,
        limit=payload.limit,
        results=search_payload.get("results", []),
        answer=search_payload.get("answer", ""),
    )

    tracer.end_span(
        span,
        metadata={
            "results": len(response.results),
            "answer_present": bool(response.answer),
        },
    )

    return response


async def handle_list_accessible_documents(user: User, db: AsyncSession, *, space_id: str) -> List[AccessibleDocument]:
    """Return documents available to the current user."""
    span = tracer.start_child_span(
        tracer.get_current_span(),
        "documents.list_accessible",
        input={"user_id": user.id},
    )
    documents = await document_service.list_accessible_documents(db, user, space_id=space_id)
    response = [
        AccessibleDocument(
            id=doc.id,
            filename=doc.filename,
            file_type=DocumentType(doc.file_type),
            uploaded_at=doc.uploaded_at,
            uploaded_by_user_id=getattr(doc, "uploaded_by_user_id", None),
            is_hidden=bool(getattr(doc, "is_hidden", False)),
        )
        for doc in documents
    ]
    tracer.end_span(span, metadata={"count": len(response)})
    return response


async def handle_grant_permissions(
    payload: DocumentPermissionGrantRequest,
    db: AsyncSession,
    *,
    space_id: str,
) -> DocumentPermissionGrantResponse:
    """Grant document access to a user."""
    span = tracer.start_child_span(
        tracer.get_current_span(),
        "documents.grant_permissions",
        input={"user_id": payload.user_id, "documents": len(payload.document_ids)},
    )
    try:
        granted = await document_service.grant_document_permissions(
            db,
            space_id=space_id,
            user_id=payload.user_id,
            document_ids=payload.document_ids,
        )
    except ValueError as exc:
        tracer.end_span(span, status_message=str(exc))
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    tracer.end_span(span, metadata={"granted": granted})
    return DocumentPermissionGrantResponse(granted=granted)


async def handle_upload_and_vectorize(
    file: UploadFile,
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
) -> DocumentUploadAndVectorizeResponse:
    """Upload a document and immediately index it into the vector store."""

    span = tracer.start_child_span(
        tracer.get_current_span(),
        "documents.upload_and_vectorize",
        input={"filename": file.filename},
    )
    try:
        upload_response = await handle_upload_document(file, db, user, space_id=space_id)
        if (
            upload_response.status != DocumentStatus.COMPLETED
            or int(upload_response.chunks_count or 0) <= 0
        ):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    upload_response.message
                    or "Document has no extractable text. For scanned PDFs, ensure OCR dependencies (Tesseract) are installed."
                ),
            )
        vector_response = await handle_vectorize_document(upload_response.document_id, user, db, space_id=space_id)
    except Exception as exc:  # noqa: BLE001
        tracer.end_span(span, status_message=str(exc))
        raise

    combined = DocumentUploadAndVectorizeResponse(
        upload=upload_response,
        vectorization=vector_response,
    )
    tracer.end_span(span, metadata={"document_id": upload_response.document_id})
    return combined


async def handle_revoke_permissions(
    payload,
    db: AsyncSession,
    *,
    space_id: str,
):
    """Revoke document access from a user."""
    from .schemas import DocumentPermissionRevokeRequest, DocumentPermissionRevokeResponse
    
    span = tracer.start_child_span(
        tracer.get_current_span(),
        "documents.revoke_permissions",
        input={"user_id": payload.user_id, "documents": len(payload.document_ids)},
    )
    try:
        revoked = await document_service.revoke_document_permissions(
            db,
            space_id=space_id,
            user_id=payload.user_id,
            document_ids=payload.document_ids,
        )
    except ValueError as exc:
        tracer.end_span(span, status_message=str(exc))
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    tracer.end_span(span, metadata={"revoked": revoked})
    return DocumentPermissionRevokeResponse(revoked=revoked)


async def handle_permission_status(
    payload: DocumentPermissionStatusRequest,
    db: AsyncSession,
    *,
    space_id: str,
) -> DocumentPermissionStatusResponse:
    """Return user-id sets used to filter grant vs revoke lists in the UI."""
    span = tracer.start_child_span(
        tracer.get_current_span(),
        "documents.permission_status",
        input={"documents": len(payload.document_ids)},
    )
    any_set, all_set = await document_service.get_permission_user_sets(
        db,
        space_id=space_id,
        document_ids=payload.document_ids,
    )
    response = DocumentPermissionStatusResponse(
        any_user_ids=sorted(any_set),
        all_user_ids=sorted(all_set),
    )
    tracer.end_span(span, metadata={"any": len(any_set), "all": len(all_set)})
    return response


async def handle_get_document_chunks(
    document_id: str,
    db: AsyncSession,
    *,
    space_id: str,
):
    """Retrieve all chunks for a document."""
    from .schemas import DocumentChunksResponse, ChunkDetail
    
    span = tracer.start_child_span(
        tracer.get_current_span(),
        "documents.get_chunks",
        input={"document_id": document_id},
    )
    try:
        doc = await document_service.get_document(db, document_id)
        if not doc or doc.space_id != space_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Document not found",
            )
        chunks = await document_service.get_document_chunks(db, document_id)
    except ValueError as exc:
        tracer.end_span(span, status_message=str(exc))
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    
    response = DocumentChunksResponse(
        document_id=document_id,
        filename=doc.filename,
        chunks=[ChunkDetail(**chunk) for chunk in chunks],
    )
    tracer.end_span(span, metadata={"chunks_count": len(chunks)})
    return response


async def handle_download_document(
    document_id: str,
    user: User,
    db: AsyncSession,
    *,
    space_id: str,
) -> Response:
    """Stream the original document bytes back to the client."""

    # Ensure the user can access this document within the current space.
    accessible = await document_service.list_accessible_documents(db, user, space_id=space_id)
    doc = next((d for d in accessible if d.id == document_id), None)
    if doc is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")

    s3_url = (doc.s3_url or "").strip()
    if not s3_url.startswith("s3://"):
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Document storage URL is invalid")

    # Parse s3://bucket/key
    _, _, remainder = s3_url.partition("s3://")
    bucket, _, key = remainder.partition("/")
    if not bucket or not key:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Document storage URL is invalid")

    from src.services.cloud.aws.s3 import s3_service

    content_types = {
        "pdf": "application/pdf",
        "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "csv": "text/csv",
        "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        "txt": "text/plain",
    }
    media_type = content_types.get((doc.file_type or "").lower(), "application/octet-stream")

    async with s3_service.session.client("s3") as s3:
        try:
            obj = await s3.get_object(Bucket=bucket, Key=key)
            body = obj.get("Body")
            if body is None:
                raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Document body is missing")
            content = await body.read()
        except HTTPException:
            raise
        except Exception as exc:  # noqa: BLE001
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to fetch document: {exc}") from exc
        finally:
            try:
                body_close = getattr(locals().get("body"), "close", None)
                if callable(body_close):
                    result = body_close()
                    if asyncio.iscoroutine(result):
                        await result
            except Exception:
                pass

    headers = {
        "Content-Disposition": f'inline; filename="{doc.filename}"',
        "Cache-Control": "no-store",
    }
    return Response(content=content, media_type=media_type, headers=headers)


async def handle_update_visibility(
    document_id: str,
    payload: DocumentVisibilityUpdateRequest,
    db: AsyncSession,
    *,
    space_id: str,
) -> DocumentVisibilityUpdateResponse:
    """Allow an admin to hide/unhide a document within a space."""
    span = tracer.start_child_span(
        tracer.get_current_span(),
        "documents.update_visibility",
        input={"document_id": document_id, "is_hidden": payload.is_hidden},
    )
    try:
        doc = await document_service.set_document_visibility(
            db,
            document_id=document_id,
            space_id=space_id,
            is_hidden=payload.is_hidden,
        )
    except ValueError as exc:
        tracer.end_span(span, status_message=str(exc))
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc

    response = DocumentVisibilityUpdateResponse(document_id=doc.id, is_hidden=bool(doc.is_hidden))
    tracer.end_span(span, metadata={"document_id": doc.id, "is_hidden": response.is_hidden})
    return response
