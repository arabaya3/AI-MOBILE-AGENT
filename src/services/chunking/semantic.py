"""Semantic chunking based on embedding similarity."""

import asyncio
import os
from typing import Any, Dict, List

import numpy as np
import tiktoken
from sentence_transformers import SentenceTransformer

from src.core.settings.config import settings
from .base import BaseChunker
from src.core.settings.logging import logger

# Suppress huggingface transformers download progress bars
os.environ["HF_HUB_DISABLE_PROGRESS_BARS"] = "1"


class SemanticChunker(BaseChunker):
    """Chunks text based on semantic similarity between sentences."""

    def __init__(self, threshold: float = None):
        self.threshold = threshold or getattr(settings, "SEMANTIC_THRESHOLD", 0.75)
        self.tokenizer = tiktoken.get_encoding("cl100k_base")
        self.model = None
        self._model_lock = asyncio.Lock()

    async def _get_model(self) -> SentenceTransformer:
        """Lazy load sentence transformer model."""
        if self.model is None:
            async with self._model_lock:
                if self.model is None:
                    logger.info("Loading semantic chunker model: all-MiniLM-L6-v2")
                    try:
                        self.model = await asyncio.to_thread(
                            SentenceTransformer, "all-MiniLM-L6-v2"
                        )
                        logger.info("Successfully loaded semantic chunker model")
                    except Exception as e:
                        logger.error(f"Failed to load semantic chunker model: {str(e)}", exc_info=True)
                        raise
        return self.model

    def estimate_tokens(self, text: str) -> int:
        """Estimate token count using tiktoken."""
        return len(self.tokenizer.encode(text))

    def _split_into_sentences(self, text: str) -> List[str]:
        """Simple sentence splitting."""
        import re
        sentences = re.split(r'(?<=[.!?])\s+', text)
        return [s.strip() for s in sentences if s.strip()]

    async def chunk_text(self, text: str, metadata: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        """Split text into semantically coherent chunks."""
        if not text or not text.strip():
            return []

        sentences = self._split_into_sentences(text)
        if len(sentences) <= 1:
            return [{
                "text": text.strip(),
                "metadata": {**(metadata or {}), "chunk_index": 0, "total_chunks": 1}
            }]

        model = await self._get_model()
        embeddings = await asyncio.to_thread(model.encode, sentences)
        
        chunks = []
        current_chunk = [sentences[0]]
        
        for i in range(1, len(sentences)):
            similarity = np.dot(embeddings[i-1], embeddings[i]) / (
                np.linalg.norm(embeddings[i-1]) * np.linalg.norm(embeddings[i])
            )
            
            if similarity >= self.threshold:
                current_chunk.append(sentences[i])
            else:
                if current_chunk:
                    chunks.append(" ".join(current_chunk))
                current_chunk = [sentences[i]]
        
        if current_chunk:
            chunks.append(" ".join(current_chunk))
        
        result = []
        for idx, chunk_text in enumerate(chunks):
            if chunk_text.strip():
                result.append({
                    "text": chunk_text.strip(),
                    "metadata": {
                        **(metadata or {}),
                        "chunk_index": idx,
                        "total_chunks": len(chunks),
                        "token_count": self.estimate_tokens(chunk_text),
                        "chunking_method": "semantic",
                    },
                })
        
        return result


semantic_chunker = SemanticChunker()
