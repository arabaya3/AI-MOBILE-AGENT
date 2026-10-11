"""Reranking using cross-encoder models."""

import asyncio
import os
from typing import Any, Dict, List

from sentence_transformers import CrossEncoder

from src.core.settings.config import settings
from src.core.settings.logging import logger

# Suppress huggingface transformers download progress bars
os.environ["HF_HUB_DISABLE_PROGRESS_BARS"] = "1"
os.environ["TRANSFORMERS_OFFLINE"] = "0"


class Reranker:
    """Cross-encoder based reranking for improved relevance."""

    def __init__(self, model_name: str = None):
        self.model_name = model_name or getattr(
            settings,
            "RERANK_MODEL",
            "cross-encoder/ms-marco-MiniLM-L-6-v2"
        )
        self.model = None
        self._model_lock = asyncio.Lock()

    async def _get_model(self) -> CrossEncoder:
        """Lazy load cross-encoder model."""
        if self.model is None:
            async with self._model_lock:
                if self.model is None:
                    logger.info(f"Loading reranker model: {self.model_name}")
                    try:
                        self.model = await asyncio.to_thread(
                            CrossEncoder, self.model_name
                        )
                        logger.info(f"Successfully loaded reranker model: {self.model_name}")
                    except Exception as e:
                        logger.error(f"Failed to load reranker model: {str(e)}", exc_info=True)
                        raise
        return self.model

    async def rerank(
        self,
        query: str,
        results: List[Dict[str, Any]],
        top_k: int = None,
    ) -> List[Dict[str, Any]]:
        """Rerank search results using cross-encoder."""
        if not results:
            return []
        
        top_k = top_k or getattr(settings, "FINAL_TOP_K", 10)
        
        model = await self._get_model()
        
        pairs = [
            [query, result.get("text", result.get("metadata", {}).get("text", ""))]
            for result in results
        ]
        
        scores = await asyncio.to_thread(model.predict, pairs)
        
        for result, score in zip(results, scores):
            result["rerank_score"] = float(score)
            result["original_score"] = result.get("score", 0.0)
        
        reranked = sorted(results, key=lambda x: x["rerank_score"], reverse=True)
        return reranked[:top_k]


reranker = Reranker()
