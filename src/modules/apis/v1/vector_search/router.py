"""Standalone vector search router using existing document handlers."""

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.apis.v1.documents.handlers import handle_vector_search
from src.modules.apis.v1.documents.schemas import (
    DocumentVectorSearchRequest,
    DocumentVectorSearchResponse,
)
from src.modules.apis.dependencies import get_current_user
from src.services.databases.postgresql.database import get_db
from src.services.databases.postgresql.models import User

router = APIRouter(prefix="/vector-search", tags=["vector-search"])


@router.post(
    "",
    response_model=DocumentVectorSearchResponse,
    status_code=status.HTTP_200_OK,
    summary="Vector search over indexed chunks",
    description="Search the Qdrant vector store and optionally synthesize an answer.",
)
async def vector_search_endpoint(
    payload: DocumentVectorSearchRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> DocumentVectorSearchResponse:
    """Proxy vector search requests to the document handler for reuse."""
    return await handle_vector_search(payload, current_user, db)
