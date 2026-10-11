"""Document upload schemas."""

from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class DocumentStatus(str, Enum):
    """Document processing status."""

    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class DocumentType(str, Enum):
    """Supported document types."""

    PDF = "pdf"
    DOCX = "docx"
    XLSX = "xlsx"
    CSV = "csv"
    PPTX = "pptx"
    TXT = "txt"


class DocumentUploadResponse(BaseModel):
    """Response for document upload."""

    document_id: str = Field(..., description="Unique document identifier")
    filename: str = Field(..., description="Original filename")
    file_type: DocumentType = Field(..., description="Document type")
    file_size: int = Field(..., description="File size in bytes")
    status: DocumentStatus = Field(default=DocumentStatus.PENDING, description="Processing status")
    chunks_count: Optional[int] = Field(None, description="Number of chunks extracted")
    uploaded_at: datetime = Field(default_factory=datetime.utcnow, description="Upload timestamp")
    message: str = Field(default="Document uploaded successfully", description="Status message")


class DocumentProcessingResult(BaseModel):
    """Document processing result."""

    document_id: str
    status: DocumentStatus
    chunks_count: int
    processing_time: float
    error_message: Optional[str] = None


class DocumentVectorizeResponse(BaseModel):
    """Response for vectorizing a document."""

    document_id: str
    collection: str
    chunks_indexed: int
    message: str = Field(default="Document indexed successfully")


class DocumentUploadAndVectorizeResponse(BaseModel):
    """Response payload for upload+vectorize pipeline."""

    upload: DocumentUploadResponse
    vectorization: DocumentVectorizeResponse
    message: str = Field(default="Document uploaded and vectorized successfully")


class AccessibleDocument(BaseModel):
    """Document entry visible to the caller."""

    id: str
    filename: str
    file_type: DocumentType
    uploaded_at: Optional[datetime]
    uploaded_by_user_id: Optional[str] = None
    is_hidden: bool = False


class DocumentVisibilityUpdateRequest(BaseModel):
    """Update document visibility within a space."""

    is_hidden: bool = Field(..., description="Hide document from non-admin users")


class DocumentVisibilityUpdateResponse(BaseModel):
    """Response for document visibility updates."""

    document_id: str
    is_hidden: bool
    message: str = Field(default="Document visibility updated")


class DocumentVectorSearchRequest(BaseModel):
    """Request payload for semantic search."""

    query: str = Field(..., min_length=3, description="Search query")
    limit: int = Field(5, ge=1, le=20, description="Number of matches to return")
    document_ids: Optional[List[str]] = Field(
        default=None,
        description="Subset of document IDs the user wants to search within",
    )


class VectorSearchMatch(BaseModel):
    """Single vector search match."""

    chunk_id: str
    score: float
    document_id: str
    filename: str
    file_type: DocumentType
    chunk_index: int
    text: str
    metadata: Dict[str, Any]


class DocumentVectorSearchResponse(BaseModel):
    """Response containing vector search matches."""

    query: str
    limit: int
    results: List[VectorSearchMatch] = Field(default_factory=list)
    answer: Optional[str] = Field(default=None, description="LLM synthesized answer")


class DocumentPermissionGrantRequest(BaseModel):
    """Assign documents to a user."""

    user_id: str
    document_ids: List[str] = Field(..., min_items=1)


class DocumentPermissionGrantResponse(BaseModel):
    """Result of granting permissions."""

    granted: int
    message: str = Field(default="Permissions updated")


class DocumentPermissionRevokeRequest(BaseModel):
    """Revoke document access from a user."""

    user_id: str
    document_ids: List[str] = Field(..., min_items=1)


class DocumentPermissionRevokeResponse(BaseModel):
    """Result of revoking permissions."""

    revoked: int
    message: str = Field(default="Permissions revoked")


class DocumentPermissionStatusRequest(BaseModel):
    """Compute which users currently have access to selected documents."""

    document_ids: List[str] = Field(..., min_items=1)


class DocumentPermissionStatusResponse(BaseModel):
    """Return user sets for filtering grant vs revoke UI."""

    any_user_ids: List[str] = Field(default_factory=list, description="Users that have access to at least one selected document")
    all_user_ids: List[str] = Field(default_factory=list, description="Users that have access to all selected documents")


class ChunkDetail(BaseModel):
    """Detailed chunk information for debugging."""

    chunk_id: str
    chunk_index: int
    text: str
    metadata: Dict[str, Any]


class DocumentChunksResponse(BaseModel):
    """Response containing all chunks for a document."""

    document_id: str
    filename: str
    chunks: List[ChunkDetail]
