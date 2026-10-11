"""Document upload API routes."""

from typing import List

from fastapi import APIRouter, Depends, File, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.services.databases.postgresql.database import get_db
from .handlers import (
    handle_download_document,
    handle_get_document_chunks,
    handle_grant_permissions,
    handle_list_accessible_documents,
    handle_permission_status,
    handle_revoke_permissions,
    handle_upload_and_vectorize,
    handle_upload_document,
    handle_upload_documents,
    handle_vector_search,
    handle_vectorize_document,
    handle_update_visibility,
)
from .schemas import (
    AccessibleDocument,
    ChunkDetail,
    DocumentChunksResponse,
    DocumentPermissionGrantRequest,
    DocumentPermissionGrantResponse,
    DocumentPermissionStatusRequest,
    DocumentPermissionStatusResponse,
    DocumentPermissionRevokeRequest,
    DocumentPermissionRevokeResponse,
    DocumentUploadResponse,
    DocumentUploadAndVectorizeResponse,
    DocumentVectorizeResponse,
    DocumentVectorSearchRequest,
    DocumentVectorSearchResponse,
    DocumentVisibilityUpdateRequest,
    DocumentVisibilityUpdateResponse,
)
from src.modules.apis.dependencies import get_current_space_id, get_current_user, require_space_document_uploader, require_space_roles
from src.services.databases.postgresql.models import User

router = APIRouter(prefix="/documents", tags=["documents"])


@router.post(
    "/upload",
    response_model=DocumentUploadResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Upload single document",
    description="Upload and process a document (PDF, DOCX, XLSX, CSV, PPTX, TXT)",
)
async def upload_document(
    file: UploadFile = File(..., description="Document file to upload"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_space_document_uploader()),
    space_id: str = Depends(get_current_space_id),
) -> DocumentUploadResponse:
    """Upload and process a single document."""
    return await handle_upload_document(file, db, current_user, space_id=space_id)


@router.post(
    "/upload-and-vectorize",
    response_model=DocumentUploadAndVectorizeResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Upload and index a document",
    description="Upload, process, and immediately index a document into Qdrant",
)
async def upload_and_vectorize(
    file: UploadFile = File(..., description="Document file to upload and index"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_space_document_uploader()),
    space_id: str = Depends(get_current_space_id),
) -> DocumentUploadAndVectorizeResponse:
    """Upload a document and trigger vectorization in a single call."""
    return await handle_upload_and_vectorize(file, current_user, db, space_id=space_id)


@router.post(
    "/upload-multiple",
    response_model=List[DocumentUploadResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Upload multiple documents",
    description="Upload and process multiple documents in parallel",
)
async def upload_multiple_documents(
    files: List[UploadFile] = File(..., description="Multiple document files to upload"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_space_document_uploader()),
    space_id: str = Depends(get_current_space_id),
) -> List[DocumentUploadResponse]:
    """Upload and process multiple documents."""
    return await handle_upload_documents(files, db, current_user, space_id=space_id)


@router.post(
    "/vectorize/{document_id}",
    response_model=DocumentVectorizeResponse,
    status_code=status.HTTP_200_OK,
    summary="Index document chunks",
    description="Generate embeddings for a processed document and store them in Qdrant",
)
async def vectorize_document(
    document_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_space_document_uploader()),
    space_id: str = Depends(get_current_space_id),
) -> DocumentVectorizeResponse:
    """Vectorize a processed document."""
    return await handle_vectorize_document(document_id, current_user, db, space_id=space_id)


@router.post(
    "/vector-search",
    response_model=DocumentVectorSearchResponse,
    status_code=status.HTTP_200_OK,
    summary="Semantic search",
    description="Search indexed document chunks via Qdrant",
)
async def vector_search(
    payload: DocumentVectorSearchRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> DocumentVectorSearchResponse:
    """Search the vector store for similar chunks."""
    return await handle_vector_search(payload, current_user, db, space_id=space_id)


@router.get(
    "/accessible",
    response_model=List[AccessibleDocument],
    summary="List accessible documents",
    description="Return documents the authenticated user may search across",
)
async def list_accessible_documents(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> List[AccessibleDocument]:
    """List documents available to the caller."""
    return await handle_list_accessible_documents(current_user, db, space_id=space_id)


@router.post(
    "/permissions",
    response_model=DocumentPermissionGrantResponse,
    summary="Grant document permissions",
    description="Allow an admin to share documents with a user",
)
async def grant_document_permissions(
    payload: DocumentPermissionGrantRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_space_roles("admin")),
    space_id: str = Depends(get_current_space_id),
) -> DocumentPermissionGrantResponse:
    """Grant a user permission to read documents."""
    return await handle_grant_permissions(payload, db, space_id=space_id)


@router.delete(
    "/permissions",
    response_model=DocumentPermissionRevokeResponse,
    summary="Revoke document permissions",
    description="Remove user access to specific documents",
)
async def revoke_document_permissions(
    payload: DocumentPermissionRevokeRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_space_roles("admin")),
    space_id: str = Depends(get_current_space_id),
) -> DocumentPermissionRevokeResponse:
    """Revoke a user's permission to read documents."""
    return await handle_revoke_permissions(payload, db, space_id=space_id)


@router.post(
    "/permissions/status",
    response_model=DocumentPermissionStatusResponse,
    summary="Permission status for selected documents",
    description="Return user sets (any vs all) for the selected documents to power admin filtering UI",
)
async def permission_status(
    payload: DocumentPermissionStatusRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_space_roles("admin")),
    space_id: str = Depends(get_current_space_id),
) -> DocumentPermissionStatusResponse:
    return await handle_permission_status(payload, db, space_id=space_id)


@router.get(
    "/{document_id}/download",
    summary="Download document",
    description="Return the raw document bytes for preview/open in the UI",
)
async def download_document(
    document_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
):
    return await handle_download_document(document_id, current_user, db, space_id=space_id)

@router.patch(
    "/{document_id}/visibility",
    response_model=DocumentVisibilityUpdateResponse,
    summary="Update document visibility",
    description="Hide or unhide a document for non-admin users",
)
async def update_document_visibility(
    document_id: str,
    payload: DocumentVisibilityUpdateRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(require_space_roles("admin")),
    space_id: str = Depends(get_current_space_id),
) -> DocumentVisibilityUpdateResponse:
    """Update document visibility (admin only)."""
    return await handle_update_visibility(document_id, payload, db, space_id=space_id)


@router.get(
    "/{document_id}/chunks",
    response_model=DocumentChunksResponse,
    summary="Get document chunks",
    description="Retrieve all chunks for debugging and inspection",
)
async def get_document_chunks(
    document_id: str,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
    space_id: str = Depends(get_current_space_id),
) -> DocumentChunksResponse:
    """Return all chunks for a document."""
    return await handle_get_document_chunks(document_id, db, space_id=space_id)
