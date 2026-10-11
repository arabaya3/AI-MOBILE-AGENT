"""Qdrant vector store client."""

from __future__ import annotations

import asyncio
import uuid
import warnings
from typing import Dict, List

from qdrant_client import QdrantClient
from qdrant_client.http import models
from qdrant_client.http.exceptions import UnexpectedResponse

from src.core.settings.config import settings
from src.core.settings.logging import logger


def _safe_int(value: object, default: int = 0) -> int:
    """Safely convert a value to int, handling float-strings like '120.0'."""
    try:
        return int(value)  # type: ignore[arg-type]
    except (ValueError, TypeError):
        try:
            return int(float(str(value)))
        except (ValueError, TypeError):
            return default


def _sanitize_payload(obj: object) -> object:
    """Recursively sanitize payload values so Qdrant can serialize them.

    * Float-strings like ``'120.0'`` are cast to ``int`` when they represent
      whole numbers, otherwise to ``float``.
    * ``None`` is preserved.
    * Dicts and lists are walked recursively.
    """
    if obj is None:
        return None
    if isinstance(obj, dict):
        return {k: _sanitize_payload(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [_sanitize_payload(v) for v in obj]
    if isinstance(obj, (int, float, bool)):
        return obj
    if isinstance(obj, str):
        # Try to coerce numeric-looking strings to proper numerics.
        try:
            f = float(obj)
            return int(f) if f == int(f) else f
        except (ValueError, OverflowError):
            return obj
    return obj


class QdrantVectorStore:
    """Wrapper around Qdrant client for document chunks."""

    def __init__(self) -> None:
        self.collection_name = settings.QDRANT_COLLECTION
        self.dimension = settings.QDRANT_VECTOR_SIZE
        self.default_timeout = _safe_int(getattr(settings, "QDRANT_TIMEOUT_SEC", 120), 120)
        self.max_retries = max(1, _safe_int(getattr(settings, "QDRANT_UPSERT_MAX_RETRIES", 3), 3))
        self.min_split_batch = max(1, _safe_int(getattr(settings, "QDRANT_MIN_UPSERT_BATCH_SIZE", 10), 10))
        self.url = settings.QDRANT_URL

        api_key = settings.QDRANT_API_KEY or None
        suppress_insecure_warning = bool(getattr(settings, "QDRANT_SUPPRESS_INSECURE_WARNING", True))
        if api_key and str(self.url).startswith("http://") and suppress_insecure_warning:
            warnings.filterwarnings(
                "ignore",
                message="Api key is used with an insecure connection.",
                category=UserWarning,
            )
        
        # Initialize client
        self.client = QdrantClient(
            url=self.url,
            api_key=api_key,
            timeout=self.default_timeout,
            prefer_grpc=False,
        )
        try:
            self._ensure_collection()
        except Exception as exc:  # network unreachable or Qdrant offline at startup
            import logging as _logging
            _logging.getLogger(__name__).warning(
                "Qdrant unreachable at startup – vector store will retry on first use. Error: %s", exc
            )

    def _ensure_collection(self) -> None:
        """Create collection if it does not exist."""
        try:
            self.client.get_collection(self.collection_name)
        except (UnexpectedResponse, ValueError):
            # Collection does not exist, create it
            distance = models.Distance.COSINE
            if settings.QDRANT_DISTANCE.lower() == "euclidean":
                distance = models.Distance.EUCLID
            elif settings.QDRANT_DISTANCE.lower() == "dot":
                distance = models.Distance.DOT

            self.client.create_collection(
                collection_name=self.collection_name,
                vectors_config=models.VectorParams(
                    size=self.dimension,
                    distance=distance
                )
            )
            
            # Create payload indexes for faster filtering
            self.client.create_payload_index(
                collection_name=self.collection_name,
                field_name="document_id",
                field_schema=models.PayloadSchemaType.KEYWORD
            )
            self.client.create_payload_index(
                collection_name=self.collection_name,
                field_name="space_id",
                field_schema=models.PayloadSchemaType.KEYWORD
            )
            self.client.create_payload_index(
                collection_name=self.collection_name,
                field_name="created_by",
                field_schema=models.PayloadSchemaType.KEYWORD
            )

    def _build_points(self, records: List[Dict[str, Any]], embeddings: List[List[float]]) -> List[models.PointStruct]:
        points: List[models.PointStruct] = []
        for record, vector in zip(records, embeddings):
            chunk_id_str = record["chunk_id"]
            point_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, chunk_id_str))
            raw_payload = {
                "chunk_id": chunk_id_str,
                "document_id": record["document_id"],
                "filename": record["filename"],
                "file_type": record["file_type"],
                "chunk_index": _safe_int(record["chunk_index"]),
                "metadata": {
                    **record.get("metadata", {}),
                    "text": record.get("text", ""),
                },
            }
            # Sanitize the entire payload so float-strings like '120.0' are
            # safely converted before reaching Qdrant's type validators.
            payload = _sanitize_payload(raw_payload)
            points.append(
                models.PointStruct(
                    id=point_id,
                    vector=vector,
                    payload=payload,
                )
            )
        return points

    async def _upsert_points(self, points: List[models.PointStruct]) -> None:
        """Upsert with timeout compatibility across qdrant-client versions."""

        def _run_upsert() -> None:
            kwargs = {
                "collection_name": self.collection_name,
                "points": points,
                "wait": True,
            }
            try:
                # qdrant-client supports request-level timeout in newer versions.
                self.client.upsert(**kwargs, timeout=self.default_timeout)  # type: ignore[arg-type]
            except TypeError:
                self.client.upsert(**kwargs)
            except Exception as exc:  # noqa: BLE001
                # qdrant-client < 1.16 may raise runtime validation errors instead of TypeError.
                if "Unknown arguments" in str(exc) and "timeout" in str(exc):
                    self.client.upsert(**kwargs)
                    return
                raise

        await asyncio.to_thread(_run_upsert)

    async def _upsert_with_retry(self, records: List[Dict[str, Any]], embeddings: List[List[float]]) -> int:
        if not records:
            return 0

        points = self._build_points(records, embeddings)
        last_error: Exception | None = None

        for attempt in range(1, self.max_retries + 1):
            try:
                await self._upsert_points(points)
                return len(points)
            except Exception as exc:  # noqa: BLE001
                last_error = exc
                logger.warning(
                    "Qdrant upsert batch failed",
                    extra={
                        "attempt": attempt,
                        "max_retries": self.max_retries,
                        "batch_size": len(points),
                        "error": str(exc),
                    },
                )
                if attempt < self.max_retries:
                    await asyncio.sleep(min(2 ** (attempt - 1), 8))

        if len(records) > self.min_split_batch:
            midpoint = len(records) // 2
            logger.warning(
                "Splitting Qdrant batch after retries were exhausted",
                extra={"original_batch_size": len(records), "left": midpoint, "right": len(records) - midpoint},
            )
            left = await self._upsert_with_retry(records[:midpoint], embeddings[:midpoint])
            right = await self._upsert_with_retry(records[midpoint:], embeddings[midpoint:])
            return left + right

        raise RuntimeError(
            f"Qdrant upsert failed after {self.max_retries} retries for batch size {len(records)}: {last_error}"
        )

    async def upsert_chunks(self, records: List[Dict[str, Any]], embeddings: List[List[float]]) -> int:
        """Insert or update chunk embeddings."""
        if not records or not embeddings:
            return 0
        if len(records) != len(embeddings):
            raise ValueError("records and embeddings must have equal lengths")

        indexed = await self._upsert_with_retry(records, embeddings)
        logger.debug("Upserted chunks into Qdrant", extra={"count": indexed})
        return indexed

    async def upsert_chunks_batched(
        self,
        records: List[Dict[str, Any]],
        embeddings: List[List[float]],
        *,
        batch_size: int | None = None,
    ) -> int:
        """Insert chunk embeddings in smaller batches to avoid large upsert failures."""
        if not records or not embeddings:
            return 0
        if len(records) != len(embeddings):
            raise ValueError("records and embeddings must have equal lengths")

        size = max(1, _safe_int(batch_size or getattr(settings, "QDRANT_UPSERT_BATCH_SIZE", 64), 64))
        total_indexed = 0
        for start in range(0, len(records), size):
            batch_records = records[start : start + size]
            batch_embeddings = embeddings[start : start + size]
            indexed = await self._upsert_with_retry(batch_records, batch_embeddings)
            total_indexed += indexed
        logger.info(
            "Finished batched Qdrant upsert",
            extra={
                "chunks": total_indexed,
                "batch_size": size,
                "collection": self.collection_name,
                "max_retries": self.max_retries,
            },
        )
        return total_indexed

    async def search(self, embedding: List[float], limit: int = 5) -> List[Dict[str, Any]]:
        """Search for similar chunks."""
        if not embedding:
            return []

        # qdrant-client >= 1.16 removed `QdrantClient.search` in favor of `query_points`.
        # Keep backward compatibility for older versions.
        if hasattr(self.client, "query_points"):
            query_response = await asyncio.to_thread(
                self.client.query_points,
                collection_name=self.collection_name,
                query=embedding,
                limit=limit,
                with_payload=True,
            )
            hits = getattr(query_response, "points", None)
            if hits is None:
                # Defensive fallback in case the response model changes.
                hits = query_response  # type: ignore[assignment]
        elif hasattr(self.client, "search"):
            hits = await asyncio.to_thread(
                self.client.search,
                collection_name=self.collection_name,
                query_vector=embedding,
                limit=limit,
                with_payload=True,
            )
        else:
            raise RuntimeError("Unsupported qdrant-client version: missing query method on QdrantClient")

        results = []
        for hit in hits:
            payload = hit.payload or {}
            # Prefer chunk_id from payload, fallback to hit.id if not found
            chunk_id = payload.get("chunk_id") or str(hit.id)
            
            results.append({
                "chunk_id": chunk_id,
                "score": hit.score,
                "document_id": payload.get("document_id"),
                "filename": payload.get("filename"),
                "file_type": payload.get("file_type"),
                "chunk_index": payload.get("chunk_index"),
                "metadata": payload.get("metadata", {})
            })
            
        return results


qdrant_vector_store = QdrantVectorStore()
