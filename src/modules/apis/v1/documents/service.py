"""Document processing service."""

from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional
from src.core.settings.config import settings
from src.core.settings.logging import logger
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.services.databases.qdrant.client import qdrant_vector_store
from src.services.databases.postgresql.models import (
    Document,
    SpaceMember,
    User,
    UserDocumentPermission,
)
from src.services.llm_providers.provider import get_embedding_service
from src.services.llm_providers.openai.chat import openai_chat_service
from .schemas import DocumentType
from langchain_text_splitters import RecursiveCharacterTextSplitter


class DocumentService:
    """Service for document processing operations."""

    # Supported file extensions
    SUPPORTED_EXTENSIONS = {
        ".pdf": DocumentType.PDF,
        ".docx": DocumentType.DOCX,
        ".xlsx": DocumentType.XLSX,
        ".csv": DocumentType.CSV,
        ".pptx": DocumentType.PPTX,
        ".txt": DocumentType.TXT,
        ".json": DocumentType.TXT,
        ".jsonl": DocumentType.TXT,
        ".html": DocumentType.TXT,
        ".htm": DocumentType.TXT,
        ".md": DocumentType.TXT,
        ".markdown": DocumentType.TXT,
    }

    collection_name = qdrant_vector_store.collection_name

    # Retrieval metadata that clients may see; storage URLs, hashes and sizes stay server-side.
    PUBLIC_METADATA_KEYS = ("page", "page_number", "sheet_name", "slide_number", "type", "source_chunk_index", "sub_chunk_index")

    @staticmethod
    def ready_ids(documents: List[Document]) -> set[str]:
        """Only documents that finished indexing may be used for retrieval."""
        return {doc.id for doc in documents if (doc.state or "ready") == "ready"}

    @classmethod
    def public_match(cls, match: Dict[str, Any]) -> Dict[str, Any]:
        metadata = match.get("metadata") or {}
        chunk_meta = metadata.get("chunk_metadata") or {}
        public = {k: metadata[k] for k in cls.PUBLIC_METADATA_KEYS if k in metadata}
        public.update({k: chunk_meta[k] for k in cls.PUBLIC_METADATA_KEYS if k in chunk_meta})
        return {
            "chunk_id": match.get("chunk_id") or "",
            "score": float(match.get("score") or 0.0),
            "document_id": match.get("document_id"),
            "filename": match.get("filename") or "",
            "file_type": match.get("file_type") or "txt",
            "chunk_index": int(match.get("chunk_index") or 0),
            "text": match.get("text") or metadata.get("text") or "",
            "metadata": public,
        }

    def get_file_type(self, filename: str) -> DocumentType:
        """Determine document type from filename.
        
        Args:
            filename: Name of the file
            
        Returns:
            DocumentType enum value
            
        Raises:
            ValueError: If file type is not supported
        """
        ext = Path(filename).suffix.lower()
        if ext not in self.SUPPORTED_EXTENSIONS:
            raise ValueError(f"Unsupported file type: {ext}")
        return self.SUPPORTED_EXTENSIONS[ext]

    async def get_document(self, db: AsyncSession, document_id: str) -> Document | None:
        """Fetch document by ID."""
        result = await db.execute(select(Document).where(Document.id == document_id))
        return result.scalar_one_or_none()

    async def get_document_by_hash(self, db: AsyncSession, file_hash: str, *, space_id: str | None = None) -> Document | None:
        """Fetch document that matches a SHA-256 file hash.

        If space_id is provided, scope the lookup to that space.
        """
        stmt = select(Document).where(Document.file_hash == file_hash)
        if space_id:
            stmt = stmt.where(Document.space_id == space_id)
        result = await db.execute(stmt)
        return result.scalar_one_or_none()

    def _prepare_vector_records(self, document: Document) -> tuple[List[Dict[str, Any]], List[str]]:
        """Build records and text payloads for vector indexing."""
        records: List[Dict[str, Any]] = []
        texts: List[str] = []
        splitter = RecursiveCharacterTextSplitter(
            chunk_size=800,
            chunk_overlap=120,
            separators=["\n\n", "\n", ". ", " ", ""],
            keep_separator=True,
        )

        for idx, chunk in enumerate(document.chunks_data or []):
            chunk_data = chunk or {}
            raw_text = chunk_data.get("text", "").strip()
            if not raw_text:
                continue

            sub_chunks = splitter.split_text(raw_text)
            for sub_idx, text in enumerate(sub_chunks):
                clean = text.strip()
                if not clean:
                    continue
                chunk_id = f"{document.id}:{idx}:{sub_idx}"
                records.append(
                    {
                        "chunk_id": chunk_id,
                        "document_id": document.id,
                        "filename": document.filename,
                        "file_type": document.file_type,
                        "chunk_index": idx,
                        "metadata": {
                            "chunk_metadata": chunk_data.get("metadata", {}),
                            "source_chunk_index": idx,
                            "sub_chunk_index": sub_idx,
                            "file_size": document.file_size,
                            "uploaded_at": document.uploaded_at.isoformat() if document.uploaded_at else None,
                            "processed_at": document.processed_at.isoformat() if document.processed_at else None,
                            "space_id": document.space_id,
                            "document_id": document.id,
                        },
                        "text": clean,
                    }
                )
                texts.append(clean)

        return records, texts

    async def search_vectors(
        self,
        query: str,
        limit: int = 5,
        allowed_document_ids: Optional[List[str]] = None,
        *,
        generate_answer: bool = True,
        query_embedding: Optional[List[float]] = None,
        space_id: str | None = None,
    ) -> Dict[str, Any]:
        """Enhanced search with hybrid retrieval and reranking."""
        from src.core.settings.config import settings
        
        if allowed_document_ids is not None and not allowed_document_ids:
            return {"results": [], "answer": ""}
        if query_embedding is None:
            embeddings = await get_embedding_service().embed_texts([query])
            query_embedding = embeddings[0] if embeddings else None

        if not query_embedding or not any(query_embedding):
            return {"results": [], "answer": ""}

        dense_hits = await qdrant_vector_store.search(
            query_embedding,
            limit=getattr(settings, "RERANK_TOP_K", 50),
            document_ids=list(allowed_document_ids) if allowed_document_ids is not None else None,
        )
        
        results: List[Dict[str, Any]] = []
        allowed_set = set(allowed_document_ids) if allowed_document_ids is not None else None
        
        for hit in dense_hits:
            document_id = hit.get("document_id")
            if not document_id:
                continue
            if allowed_set is not None and document_id not in allowed_set:
                continue

            metadata = hit.get("metadata", {}) or {}
            if space_id and metadata.get("space_id") != space_id:
                continue

            chunk_id = hit.get("chunk_id") or metadata.get("chunk_id") or ""
            logger.debug(
                "Vector search match",
                extra={
                    "document_id": document_id,
                    "document_filename": hit.get("filename"),
                    "score": hit.get("score"),
                    "space_id": space_id,
                },
            )
            
            results.append(
                {
                    "chunk_id": chunk_id,
                    "score": hit.get("score", 0.0),
                    "document_id": document_id,
                    "filename": hit.get("filename"),
                    "file_type": hit.get("file_type"),
                    "chunk_index": hit.get("chunk_index", 0),
                    "text": metadata.get("text", ""),
                    "metadata": metadata,
                }
            )
        
        if getattr(settings, "ENABLE_RERANKING", True) and results:
            try:
                from src.services.search.reranker import reranker
                results = await reranker.rerank(
                    query,
                    results,
                    top_k=limit
                )
            except Exception as exc:
                logger.warning("Reranking failed: %s", exc)
                results = results[:limit]
        else:
            results = results[:limit]
        
        answer = ""
        if results and generate_answer:
            try:
                answer = await openai_chat_service.answer_question(query, results)
            except RuntimeError as exc:
                logger.warning("LLM answer failed: %s", exc)
        
        return {"results": results, "answer": answer}

    async def list_accessible_documents(self, db: AsyncSession, user: User, *, space_id: str) -> List[Document]:
        """Return documents the user may access within a space."""
        from src.modules.apis.v1.spaces.service import spaces_service

        member = await spaces_service.require_active_member(db, space_id=space_id, user=user)
        if member.role == "admin" or user.role == "super_admin":
            result = await db.execute(select(Document).where(Document.space_id == space_id))
            return result.scalars().unique().all()
        # Non-admin members: see docs they were explicitly granted OR that they uploaded,
        # unless the document is explicitly hidden by an admin.
        from sqlalchemy import and_, or_

        stmt = (
            select(Document)
            .outerjoin(UserDocumentPermission, UserDocumentPermission.document_id == Document.id)
            .where(
                Document.space_id == space_id,
                Document.is_hidden.is_(False),
                or_(
                    and_(UserDocumentPermission.user_id == user.id, UserDocumentPermission.space_id == space_id),
                    Document.uploaded_by_user_id == user.id,
                ),
            )
        )
        result = await db.execute(stmt)
        return result.scalars().unique().all()

    async def set_document_visibility(
        self,
        db: AsyncSession,
        *,
        document_id: str,
        space_id: str,
        is_hidden: bool,
    ) -> Document:
        """Update a document's visibility within a space."""
        doc = await self.get_document(db, document_id)
        if doc is None or doc.space_id != space_id:
            raise ValueError("Document not found")
        doc.is_hidden = bool(is_hidden)
        await db.flush()
        return doc

    async def grant_document_permissions(
        self,
        db: AsyncSession,
        *,
        space_id: str,
        user_id: str,
        document_ids: List[str],
    ) -> int:
        """Grant user access to the provided documents."""
        user_result = await db.execute(select(User).where(User.id == user_id))
        user = user_result.scalar_one_or_none()
        if user is None:
            raise ValueError("User not found")
        member_result = await db.execute(
            select(SpaceMember).where(
                SpaceMember.space_id == space_id,
                SpaceMember.user_id == user_id,
                SpaceMember.status == "active",
            )
        )
        if member_result.scalar_one_or_none() is None:
            raise ValueError("User is not an active member of this space")
        if not document_ids:
            return 0
        docs_result = await db.execute(
            select(Document.id).where(Document.id.in_(document_ids), Document.space_id == space_id)
        )
        valid_ids = set(docs_result.scalars().all())
        missing = set(document_ids) - valid_ids
        if missing:
            raise ValueError(f"Unknown document IDs: {', '.join(sorted(missing))}")
        existing_result = await db.execute(
            select(UserDocumentPermission.document_id)
            .where(
                UserDocumentPermission.user_id == user_id,
                UserDocumentPermission.space_id == space_id,
                UserDocumentPermission.document_id.in_(valid_ids),
            )
        )
        existing_ids = set(existing_result.scalars().all())
        new_ids = [doc_id for doc_id in valid_ids if doc_id not in existing_ids]
        for doc_id in new_ids:
            db.add(UserDocumentPermission(space_id=space_id, user_id=user_id, document_id=doc_id))
        await db.flush()
        return len(new_ids)

    async def revoke_document_permissions(
        self,
        db: AsyncSession,
        *,
        space_id: str,
        user_id: str,
        document_ids: List[str],
    ) -> int:
        """Revoke user access from the provided documents."""
        if not document_ids:
            return 0
        from sqlalchemy import delete
        stmt = delete(UserDocumentPermission).where(
            UserDocumentPermission.user_id == user_id,
            UserDocumentPermission.space_id == space_id,
            UserDocumentPermission.document_id.in_(document_ids),
        )
        result = await db.execute(stmt)
        await db.flush()
        return result.rowcount

    async def get_permission_user_sets(
        self,
        db: AsyncSession,
        *,
        space_id: str,
        document_ids: List[str],
    ) -> tuple[set[str], set[str]]:
        """Return (any_set, all_set) of user IDs with permissions for the selected documents."""
        from sqlalchemy import distinct, func

        unique_ids = [doc_id for doc_id in dict.fromkeys(document_ids) if doc_id]
        if not unique_ids:
            return set(), set()

        # Count how many of the selected docs each user currently has access to.
        stmt = (
            select(
                UserDocumentPermission.user_id,
                func.count(distinct(UserDocumentPermission.document_id)).label("doc_count"),
            )
            .where(
                UserDocumentPermission.space_id == space_id,
                UserDocumentPermission.document_id.in_(unique_ids),
            )
            .group_by(UserDocumentPermission.user_id)
        )
        rows = (await db.execute(stmt)).all()

        any_set: set[str] = set()
        all_set: set[str] = set()
        needed = len(unique_ids)
        for user_id, doc_count in rows:
            if not user_id:
                continue
            any_set.add(user_id)
            if int(doc_count or 0) >= needed:
                all_set.add(user_id)
        return any_set, all_set

    async def get_document_chunks(self, db: AsyncSession, document_id: str) -> List[Dict[str, Any]]:
        """Retrieve all chunks for a document with metadata."""
        doc = await self.get_document(db, document_id)
        if not doc:
            raise ValueError("Document not found")
        chunks = []
        for idx, chunk_data in enumerate(doc.chunks_data or []):
            chunks.append({
                "chunk_id": f"{doc.id}:{idx}",
                "chunk_index": idx,
                "text": chunk_data.get("text", ""),
                "metadata": chunk_data.get("metadata", {}),
            })
        return chunks



document_service = DocumentService()
