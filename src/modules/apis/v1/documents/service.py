"""Document processing service."""

import hashlib
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional
from uuid import uuid4
from src.core.settings.config import settings
from src.core.settings.logging import logger
import aiofiles
from fastapi import UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.services.cloud.aws.s3 import s3_service
from src.services.databases.qdrant.client import qdrant_vector_store
from src.services.databases.postgresql.models import (
    Document,
    SpaceMember,
    User,
    UserDocumentPermission,
)
from src.services.embeddings.openai import embedding_service
from src.services.llm_providers.openai.chat import openai_chat_service
from .schemas import DocumentType, DocumentStatus, DocumentProcessingResult
from langchain_text_splitters import RecursiveCharacterTextSplitter


GLOBAL_LAWS_SPACE_ID = "__global_laws__"


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

    def __init__(self, storage_path: str = "./data/documents"):
        """Initialize document service.
        
        Args:
            storage_path: Base path for document storage
        """
        self.storage_path = Path(storage_path)
        self.storage_path.mkdir(parents=True, exist_ok=True)

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

    async def save_file(
        self,
        file: UploadFile,
        document_id: str,
        *,
        space_id: str | None = None,
        bucket: str | None = None,
    ) -> tuple[Path, str, str]:
        """Save uploaded file to local storage and S3.
        
        Args:
            file: Uploaded file object
            document_id: Unique document identifier
            
        Returns:
            Tuple of (file_path, file_hash, s3_url)
        """
        
        file_ext = Path(file.filename).suffix.lower()
        logger.info(
            "Saving document",
            extra={
                "document_id": document_id,
                "original_filename": file.filename,
                "space_id": space_id,
                "bucket": bucket,
            },
        )
        file_path = self.storage_path / f"{document_id}{file_ext}"
        
        # Read and hash file content
        content = await file.read()
        file_hash = hashlib.sha256(content).hexdigest()
        
        # Save file locally (temporary)
        async with aiofiles.open(file_path, "wb") as f:
            await f.write(content)
        
        if space_id:
            s3_key = f"spaces/{space_id}/documents/{document_id}{file_ext}"
        else:
            s3_key = f"documents/{document_id}{file_ext}"
        s3_url = await s3_service.upload_file(file_path, s3_key, bucket=bucket)
        logger.info(
            "Uploaded document to S3",
            extra={"document_id": document_id, "space_id": space_id, "s3_key": s3_key, "s3_url": s3_url},
        )
    
        # Reset file pointer for potential reuse
        await file.seek(0)
        
        return file_path, file_hash, s3_url

    async def process_document(self, file_path: Path, file_type: DocumentType) -> Dict[str, Any]:
        """Process document and extract chunks using advanced processors."""
        start_time = time.time()
        
        try:
            file_ext = file_path.suffix.lower()
            
            if file_type == DocumentType.PDF or file_ext == ".pdf":
                from src.services.processors.pdf_advanced import pdf_processor
                chunks = await pdf_processor.process(file_path)
            elif file_type == DocumentType.DOCX or file_ext == ".docx":
                chunks = await self._process_docx(file_path)
            elif file_type == DocumentType.XLSX or file_ext == ".xlsx":
                from src.services.processors.excel_advanced import excel_processor
                chunks = await excel_processor.process(file_path)
            elif file_type == DocumentType.CSV or file_ext == ".csv":
                chunks = await self._process_csv(file_path)
            elif file_type == DocumentType.PPTX or file_ext == ".pptx":
                from src.services.processors.powerpoint_advanced import powerpoint_processor
                chunks = await powerpoint_processor.process(file_path)
            elif file_ext in [".json", ".jsonl"]:
                from src.services.processors.json_processor import json_processor
                chunks = await json_processor.process(file_path)
            elif file_ext in [".html", ".htm"]:
                from src.services.processors.html_processor import html_processor
                chunks = await html_processor.process(file_path)
            elif file_ext in [".md", ".markdown"]:
                from src.services.processors.markdown_processor import markdown_processor
                chunks = await markdown_processor.process(file_path)
            elif file_type == DocumentType.TXT or file_ext == ".txt":
                chunks = await self._process_txt(file_path)
            else:
                raise ValueError(f"Unsupported document type: {file_type}")
            
            processing_time = int((time.time() - start_time) * 1000)
            
            return {
                "chunks": chunks,
                "chunks_count": len(chunks),
                "processing_time": processing_time,
                "status": DocumentStatus.COMPLETED,
            }
            
        except Exception as e:
            return {
                "chunks": [],
                "chunks_count": 0,
                "processing_time": int((time.time() - start_time) * 1000),
                "status": DocumentStatus.FAILED,
                "error": str(e),
            }
    
    async def save_to_db(
        self,
        db: AsyncSession,
        document_id: str,
        space_id: str | None,
        filename: str,
        file_type: DocumentType,
        file_size: int,
        file_hash: str,
        s3_url: str,
        result: Dict[str, Any],
        *,
        uploaded_by_user_id: str | None = None,
    ) -> Document:
        """Save document metadata and chunks to database.
        
        Args:
            db: Database session
            document_id: Document ID
            filename: Original filename
            file_type: Document type
            file_size: File size in bytes
            file_hash: SHA-256 hash
            s3_url: S3 storage URL
            result: Processing result
            
        Returns:
            Document model instance
        """
        doc = Document(
            id=document_id,
            space_id=space_id,
            filename=filename,
            file_type=file_type.value,
            file_size=file_size,
            file_hash=file_hash,
            s3_url=s3_url,
            status=result["status"].value,
            chunks_count=result.get("chunks_count", 0),
            chunks_data=result.get("chunks", []),
            processing_time=result.get("processing_time"),
            error_message=result.get("error"),
            uploaded_by_user_id=uploaded_by_user_id,
            processed_at=datetime.utcnow() if result["status"] == DocumentStatus.COMPLETED else None
        )
        
        db.add(doc)
        await db.flush()
        return doc

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
                            "file_hash": document.file_hash,
                            "s3_url": document.s3_url,
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

    async def vectorize_document(self, db: AsyncSession, document_id: str) -> Dict[str, Any]:
        """Generate embeddings for a document and store them in Qdrant."""
        
        try:
            logger.info(f"Starting vectorization for document: {document_id}")
            
            document = await self.get_document(db, document_id)
            if document is None:
                logger.error(f"Document not found: {document_id}")
                raise ValueError("Document not found")

            logger.debug(f"Preparing vector records for document: {document_id}")
            records, texts = self._prepare_vector_records(document)
            
            if not records:
                logger.warning(f"Document has no processed chunks: {document_id}")
                raise ValueError("Document has no processed chunks to index")
            
            logger.info(f"Prepared {len(records)} records with {len(texts)} texts for document: {document_id}")

            embed_batch_size = max(1, int(getattr(settings, "EMBEDDING_BATCH_SIZE", 100)))
            upsert_batch_size = max(1, int(getattr(settings, "QDRANT_UPSERT_BATCH_SIZE", 50)))
            batch_size = min(embed_batch_size, upsert_batch_size, 50)
            indexed_total = 0
            usage_totals = {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0}

            try:
                logger.info(
                    "Vectorizing document in batches",
                    extra={
                        "document_id": document_id,
                        "chunks": len(records),
                        "batch_size": batch_size,
                    },
                )
                for start in range(0, len(records), batch_size):
                    batch_records = records[start : start + batch_size]
                    batch_texts = texts[start : start + batch_size]
                    batch_embeddings, batch_usage = await embedding_service.embed_texts_with_usage(batch_texts)

                    if len(batch_embeddings) != len(batch_records):
                        raise RuntimeError(
                            f"Embedding count mismatch (expected {len(batch_records)}, got {len(batch_embeddings)})"
                        )

                    indexed = await qdrant_vector_store.upsert_chunks_batched(
                        batch_records,
                        batch_embeddings,
                        batch_size=batch_size,
                    )
                    indexed_total += indexed
                    usage_totals["input_tokens"] += int((batch_usage or {}).get("input_tokens") or 0)
                    usage_totals["output_tokens"] += int((batch_usage or {}).get("output_tokens") or 0)
                    usage_totals["total_tokens"] += int((batch_usage or {}).get("total_tokens") or 0)

                    logger.debug(
                        "Indexed vectorization batch",
                        extra={
                            "document_id": document_id,
                            "batch_start": start,
                            "batch_size": len(batch_records),
                            "indexed_total": indexed_total,
                        },
                    )
            except Exception as e:
                logger.error(f"Embedding/indexing error for document {document_id}: {str(e)}", exc_info=True)
                logger.warning(f"Vectorization failed due to batched embedding/indexing error for document {document_id}.")
                return {
                    "document_id": document_id,
                    "collection": qdrant_vector_store.collection_name,
                    "chunks_indexed": indexed_total,
                    "error": f"Vectorization failed after indexing {indexed_total} chunks: {str(e)}",
                    "status": "failed"
                }

            logger.info(f"Successfully indexed {indexed_total} chunks for document: {document_id}")
            return {
                "document_id": document_id,
                "collection": qdrant_vector_store.collection_name,
                "chunks_indexed": indexed_total,
                "embedding_model": embedding_service.model,
                "embedding_usage": usage_totals,
                "status": "success"
            }
        except ValueError as e:
            logger.error(f"Validation error for document {document_id}: {str(e)}")
            return {
                "document_id": document_id,
                "collection": qdrant_vector_store.collection_name,
                "chunks_indexed": 0,
                "error": str(e),
                "status": "failed"
            }
        except Exception as e:
            logger.error(f"Unexpected error during vectorization for document {document_id}: {str(e)}", exc_info=True)
            return {
                "document_id": document_id,
                "collection": qdrant_vector_store.collection_name,
                "chunks_indexed": 0,
                "error": f"Unexpected error: {str(e)}",
                "status": "failed"
            }

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
        
        if query_embedding is None:
            embeddings = await embedding_service.embed_texts([query])
            query_embedding = embeddings[0] if embeddings else None

        if not query_embedding:
            return {"results": [], "answer": ""}

        dense_hits = await qdrant_vector_store.search(
            query_embedding,
            limit=getattr(settings, "RERANK_TOP_K", 50)
        )
        
        results: List[Dict[str, Any]] = []
        allowed_set = set(allowed_document_ids) if allowed_document_ids else None
        
        for hit in dense_hits:
            document_id = hit.get("document_id")
            if not document_id:
                continue
            if allowed_set is not None and document_id not in allowed_set:
                continue

            metadata = hit.get("metadata", {}) or {}
            hit_space_id = metadata.get("space_id")
            # Allow hits from the current space OR from the global laws library.
            if space_id and hit_space_id not in (space_id, GLOBAL_LAWS_SPACE_ID):
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
        """Return documents the user may access within a space, plus global law documents."""
        from src.modules.apis.v1.spaces.service import spaces_service
        from sqlalchemy import or_

        # Always fetch global laws documents (accessible to all authenticated users).
        global_laws_result = await db.execute(
            select(Document).where(Document.space_id == GLOBAL_LAWS_SPACE_ID)
        )
        global_laws_docs = list(global_laws_result.scalars().unique().all())

        # Fetch space-scoped documents.
        member = await spaces_service.require_active_member(db, space_id=space_id, user=user)
        if member.role == "admin" or user.role == "super_admin":
            result = await db.execute(select(Document).where(Document.space_id == space_id))
            space_docs = list(result.scalars().unique().all())
        else:
            # Non-admin members: see docs they were explicitly granted OR that they uploaded,
            # unless the document is explicitly hidden by an admin.
            from sqlalchemy import and_
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
            space_docs = list(result.scalars().unique().all())

        # Merge, deduplicating by document id (global laws first so space docs override if same id).
        seen: set[str] = set()
        merged: List[Document] = []
        for doc in global_laws_docs + space_docs:
            if doc.id not in seen:
                seen.add(doc.id)
                merged.append(doc)
        return merged

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

    async def _process_pdf(self, file_path: Path) -> List[Dict[str, Any]]:
        """Process PDF document (fallback for legacy compatibility)."""
        try:
            from unstructured.partition.pdf import partition_pdf
            from unstructured.chunking.title import chunk_by_title
            
            elements = partition_pdf(filename=str(file_path))
            chunks = chunk_by_title(elements, max_characters=1000, new_after_n_chars=800)
            
            return [
                {
                    "text": str(chunk),
                    "metadata": {
                        "type": getattr(chunk, "category", "text"),
                        "page": getattr(chunk, "metadata", {}).get("page_number", 0),
                    }
                }
                for chunk in chunks
            ]
        except ImportError:
            import PyPDF2
            from src.services.chunking.recursive import chunker
            
            all_text = []
            with open(file_path, "rb") as f:
                reader = PyPDF2.PdfReader(f)
                for i, page in enumerate(reader.pages):
                    text = page.extract_text()
                    if text.strip():
                        all_text.append(f"[Page {i+1}]\n{text}")
            
            full_text = "\n\n".join(all_text)
            return await chunker.chunk_text(full_text, metadata={"type": "pdf"})

    async def _process_docx(self, file_path: Path) -> List[Dict[str, Any]]:
        """Process Word document with advanced chunking."""
        from docx import Document
        from src.services.chunking.recursive import chunker
        
        doc = Document(file_path)
        full_text = "\n\n".join(para.text for para in doc.paragraphs if para.text.strip())
        
        return await chunker.chunk_text(full_text, metadata={"type": "docx"})

    async def _process_xlsx(self, file_path: Path) -> List[Dict[str, Any]]:
        """Process Excel document (legacy fallback)."""
        import pandas as pd
        from src.services.chunking.recursive import chunker
        
        excel_file = pd.ExcelFile(file_path)
        all_chunks = []
        
        for sheet_name in excel_file.sheet_names:
            df = pd.read_excel(excel_file, sheet_name=sheet_name)
            if not df.empty:
                text = f"Sheet: {sheet_name}\n\n{df.to_string()}"
                sheet_chunks = await chunker.chunk_text(
                    text,
                    metadata={
                        "type": "sheet",
                        "sheet_name": sheet_name,
                        "rows": len(df),
                        "columns": len(df.columns),
                    }
                )
                all_chunks.extend(sheet_chunks)
        return all_chunks

    async def _process_csv(self, file_path: Path) -> List[Dict[str, Any]]:
        """Process CSV file with improved chunking."""
        import pandas as pd
        from src.services.chunking.recursive import chunker
        
        df = pd.read_csv(file_path)
        text = f"CSV Data ({len(df)} rows, {len(df.columns)} columns)\n\nColumns: {', '.join(df.columns)}\n\n{df.to_string()}"
        
        return await chunker.chunk_text(
            text,
            metadata={"type": "csv", "rows": len(df), "columns": len(df.columns)}
        )

    async def _process_pptx(self, file_path: Path) -> List[Dict[str, Any]]:
        """Process PowerPoint document (legacy fallback)."""
        from pptx import Presentation
        from src.services.chunking.recursive import chunker
        
        prs = Presentation(file_path)
        all_chunks = []
        
        for i, slide in enumerate(prs.slides, 1):
            slide_text = []
            for shape in slide.shapes:
                if hasattr(shape, "text"):
                    slide_text.append(shape.text)
            
            if slide_text:
                text = f"Slide {i}\n\n" + "\n".join(slide_text)
                slide_chunks = await chunker.chunk_text(
                    text,
                    metadata={"type": "slide", "slide_number": i}
                )
                all_chunks.extend(slide_chunks)
        
        return all_chunks

    async def _process_txt(self, file_path: Path) -> List[Dict[str, Any]]:
        """Process text file with recursive chunking."""
        from src.services.chunking.recursive import chunker
        
        async with aiofiles.open(file_path, "r", encoding="utf-8") as f:
            content = await f.read()
        
        return await chunker.chunk_text(content, metadata={"type": "text"})

    def cleanup_file(self, file_path: Path) -> None:
        """Remove file from storage.
        
        Args:
            file_path: Path to file to remove
        """
        if file_path.exists():
            file_path.unlink()


document_service = DocumentService()
