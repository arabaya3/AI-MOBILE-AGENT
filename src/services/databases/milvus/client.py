"""Milvus vector store client."""

from __future__ import annotations

import asyncio
from typing import Any, Dict, List

from pymilvus import CollectionSchema, DataType, FieldSchema, MilvusClient
from pymilvus.exceptions import MilvusException

from src.core.settings.config import settings
from src.core.settings.logging import logger


class MilvusVectorStore:
    """Lightweight wrapper around Milvus client for document chunks."""

    def __init__(self) -> None:
        self.collection_name = settings.MILVUS_COLLECTION
        self.dimension = settings.MILVUS_DIMENSION
        self.client = MilvusClient(
            uri=settings.MILVUS_URI,
            user=settings.MILVUS_USERNAME or None,
            password=settings.MILVUS_PASSWORD or None,
            secure=settings.MILVUS_SECURE,
        )
        self._ensure_collection()

    def _ensure_collection(self) -> None:
        """Create collection and index if they do not exist."""
        if self.client.has_collection(self.collection_name):
            self._ensure_default_index()
            self._load_collection_with_index()
            return

        schema = CollectionSchema(
            fields=[
                FieldSchema(
                    name="chunk_id",
                    dtype=DataType.VARCHAR,
                    is_primary=True,
                    max_length=64,
                    description="Chunk identifier",
                ),
                FieldSchema(
                    name="vector",
                    dtype=DataType.FLOAT_VECTOR,
                    dim=self.dimension,
                    description="Embedding vector",
                ),
                FieldSchema(name="document_id", dtype=DataType.VARCHAR, max_length=64),
                FieldSchema(name="filename", dtype=DataType.VARCHAR, max_length=256),
                FieldSchema(name="file_type", dtype=DataType.VARCHAR, max_length=32),
                FieldSchema(name="chunk_index", dtype=DataType.INT64),
                FieldSchema(name="metadata", dtype=DataType.JSON),
            ],
            description="Document chunk embeddings",
            enable_dynamic_field=False,
        )

        self.client.create_collection(
            collection_name=self.collection_name,
            schema=schema,
            consistency_level="Session",
        )
        self._create_default_index()
        self._load_collection_with_index()

    def _ensure_default_index(self) -> None:
        """Create default index if none exist (e.g., legacy collection)."""
        indexes = self.client.list_indexes(self.collection_name)
        if indexes:
            return
        self._create_default_index()

    def _create_default_index(self) -> None:
        """Create optimized index based on configuration."""
        index_params = self.client.prepare_index_params()
        
        index_type = getattr(settings, "MILVUS_INDEX_TYPE", "HNSW")
        metric_type = getattr(settings, "MILVUS_METRIC_TYPE", "COSINE")
        
        if index_type == "HNSW":
            params = {
                "M": getattr(settings, "MILVUS_HNSW_M", 16),
                "efConstruction": getattr(settings, "MILVUS_HNSW_EF_CONSTRUCTION", 256),
            }
        elif index_type == "IVF_FLAT":
            params = {"nlist": 128}
        elif index_type == "DISKANN":
            params = {"max_degree": 56, "search_list_size": 128}
        else:
            params = {"nlist": 128}
        
        index_params.add_index(
            field_name="vector",
            index_type=index_type,
            metric_type=metric_type,
            params=params,
        )
        self.client.create_index(
            collection_name=self.collection_name,
            index_params=index_params,
        )

    def _load_collection_with_index(self) -> None:
        """Load collection, recreating index if Milvus complains."""
        try:
            self.client.load_collection(self.collection_name)
        except MilvusException as exc:  # pragma: no cover - defensive path
            if exc.code == 700 and "index not found" in str(exc):
                self._create_default_index()
                self.client.load_collection(self.collection_name)
                return
            raise

    async def upsert_chunks(self, records: List[Dict[str, Any]], embeddings: List[List[float]]) -> int:
        """Insert or update chunk embeddings."""
        if not records or not embeddings:
            return 0

        payload = []
        for record, vector in zip(records, embeddings):
            payload.append(
                {
                    "chunk_id": record["chunk_id"],
                    "vector": vector,
                    "document_id": record["document_id"],
                    "filename": record["filename"],
                    "file_type": record["file_type"],
                    "chunk_index": record["chunk_index"],
                    "metadata": {**record.get("metadata", {}), "text": record.get("text", "")},
                }
            )

        await asyncio.to_thread(
            self.client.upsert,
            collection_name=self.collection_name,
            data=payload,
        )
        logger.debug("Upserted chunks into Milvus", extra={"count": len(payload)})
        return len(payload)

    async def search(self, embedding: List[float], limit: int = 5) -> List[Dict[str, Any]]:
        """Search for similar chunks with optimized parameters."""
        if not embedding:
            return []

        self.client.load_collection(self.collection_name)
        
        index_type = getattr(settings, "MILVUS_INDEX_TYPE", "HNSW")
        if index_type == "HNSW":
            search_params = {
                "metric_type": getattr(settings, "MILVUS_METRIC_TYPE", "COSINE"),
                "params": {"ef": getattr(settings, "MILVUS_HNSW_EF_SEARCH", 128)},
            }
        else:
            search_params = {
                "metric_type": getattr(settings, "MILVUS_METRIC_TYPE", "COSINE"),
                "params": {"nprobe": 10},
            }
        
        results = await asyncio.to_thread(
            self.client.search,
            collection_name=self.collection_name,
            data=[embedding],
            limit=limit,
            search_params=search_params,
            output_fields=["document_id", "filename", "file_type", "chunk_index", "metadata"],
        )

        hits = results[0] if results else []
        logger.debug("Milvus search completed", extra={"hits": len(hits), "limit": limit})
        formatted: List[Dict[str, Any]] = []
        for hit in hits:
            entity = hit.get("entity", {})
            formatted.append(
                {
                    "chunk_id": hit.get("id") or entity.get("chunk_id"),
                    "score": float(hit.get("distance", 0.0)),
                    "document_id": entity.get("document_id"),
                    "filename": entity.get("filename"),
                    "file_type": entity.get("file_type"),
                    "chunk_index": entity.get("chunk_index", 0),
                    "metadata": entity.get("metadata", {}),
                }
            )
        return formatted


milvus_vector_store = MilvusVectorStore()
