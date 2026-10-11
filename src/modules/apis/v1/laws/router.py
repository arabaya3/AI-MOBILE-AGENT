"""Global laws (Palestinian law library) API routes.

These endpoints manage a global document library that is automatically included
in every user's accessible document set regardless of their active space.
Upload/delete is restricted to super_admin users; listing is open to any
authenticated user.
"""

from typing import List
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.apis.dependencies import get_current_user, require_roles
from src.modules.apis.v1.documents.schemas import (
    AccessibleDocument,
    DocumentType,
    DocumentUploadAndVectorizeResponse,
)
from src.modules.apis.v1.documents.service import GLOBAL_LAWS_SPACE_ID, document_service
from src.services.databases.postgresql.database import get_db
from src.services.databases.postgresql.models import User

router = APIRouter(prefix="/laws", tags=["laws"])


# ---------------------------------------------------------------------------
# List all global law documents (any authenticated user)
# ---------------------------------------------------------------------------


@router.get(
    "",
    response_model=List[AccessibleDocument],
    summary="List global law documents",
    description="Return all documents in the Palestinian law library (visible to all users).",
)
async def list_global_laws(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> List[AccessibleDocument]:
    from src.services.databases.postgresql.models import Document as DocumentModel

    result = await db.execute(
        select(DocumentModel).where(DocumentModel.space_id == GLOBAL_LAWS_SPACE_ID).order_by(DocumentModel.uploaded_at.desc())
    )
    docs = result.scalars().unique().all()
    return [
        AccessibleDocument(
            id=doc.id,
            filename=doc.filename,
            file_type=DocumentType(doc.file_type),
            uploaded_at=doc.uploaded_at,
            uploaded_by_user_id=getattr(doc, "uploaded_by_user_id", None),
            is_hidden=bool(getattr(doc, "is_hidden", False)),
        )
        for doc in docs
    ]


# ---------------------------------------------------------------------------
# Upload + vectorize a law document (super_admin only)
# ---------------------------------------------------------------------------


@router.post(
    "/upload",
    response_model=DocumentUploadAndVectorizeResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Upload a law document",
    description="Upload, process, and index a Palestinian law document (super_admin only).",
)
async def upload_law(
    file: UploadFile = File(..., description="Law document to upload"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("super_admin")),
) -> DocumentUploadAndVectorizeResponse:
    from src.modules.apis.v1.documents.handlers import handle_upload_document, handle_vectorize_document
    from src.modules.apis.v1.documents.schemas import DocumentStatus

    upload_response = await handle_upload_document(file, db, current_user, space_id=GLOBAL_LAWS_SPACE_ID)
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
    vector_response = await handle_vectorize_document(upload_response.document_id, current_user, db, space_id=GLOBAL_LAWS_SPACE_ID)
    return DocumentUploadAndVectorizeResponse(upload=upload_response, vectorization=vector_response)


# ---------------------------------------------------------------------------
# Delete a law document (super_admin only)
# ---------------------------------------------------------------------------


@router.delete(
    "/{document_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a law document",
    description="Remove a law document from the global library and de-index it (super_admin only).",
)
async def delete_law(
    document_id: str,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_roles("super_admin")),
) -> None:
    from src.services.databases.postgresql.models import Document as DocumentModel
    from src.services.databases.qdrant.client import qdrant_vector_store

    doc = await document_service.get_document(db, document_id)
    if doc is None or doc.space_id != GLOBAL_LAWS_SPACE_ID:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Law document not found")

    # Remove from Qdrant vector store (best-effort).
    try:
        await qdrant_vector_store.delete_document(document_id)
    except Exception:
        pass  # vector cleanup failures should not block the DB deletion

    await db.delete(doc)
    await db.commit()
