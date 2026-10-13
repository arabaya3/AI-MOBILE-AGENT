"""Deterministic local embeddings (hashed bag of words). Never calls a network provider.

Texts that share words get similar vectors, so retrieval ranks chunks for real in local tests.
Enabled only through provider.get_embedding_service() under the development/test guard.
"""

from __future__ import annotations

import hashlib
import math
import re

from src.core.settings.config import settings

_TOKEN = re.compile(r"\w+", re.UNICODE)


class StubEmbeddingService:
    model = "teia-stub-embedding"

    def __init__(self, dimension: int | None = None) -> None:
        self.dimension = dimension or settings.QDRANT_VECTOR_SIZE

    def _embed(self, text: str) -> list[float]:
        vector = [0.0] * self.dimension
        for token in _TOKEN.findall(text.lower()):
            digest = hashlib.sha256(token.encode("utf-8")).digest()
            index = int.from_bytes(digest[:4], "big") % self.dimension
            vector[index] += 1.0 if digest[4] % 2 else -1.0
        norm = math.sqrt(sum(v * v for v in vector))
        if norm == 0:
            vector[0] = 1.0
            return vector
        return [v / norm for v in vector]

    async def embed_texts(self, texts: list[str]) -> list[list[float]]:
        return [self._embed(text) for text in texts]

    async def embed_texts_with_usage(self, texts: list[str]) -> tuple[list[list[float]], dict[str, int]]:
        return await self.embed_texts(texts), {}


stub_embedding_service = StubEmbeddingService()
