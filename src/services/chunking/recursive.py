"""Recursive character-based text splitting with overlap."""

import asyncio
from typing import Any, Dict, List

import tiktoken
from langchain_text_splitters import RecursiveCharacterTextSplitter

from src.core.settings.config import settings
from .base import BaseChunker


class RecursiveChunker(BaseChunker):
    """Recursive character text splitter with configurable overlap."""

    def __init__(self, chunk_size: int = None, chunk_overlap: int = None):
        self.chunk_size = chunk_size or settings.CHUNK_SIZE
        self.chunk_overlap = chunk_overlap or settings.CHUNK_OVERLAP
        self.tokenizer = tiktoken.get_encoding("cl100k_base")
        self.splitter = RecursiveCharacterTextSplitter(
            chunk_size=self.chunk_size,
            chunk_overlap=self.chunk_overlap,
            length_function=self.estimate_tokens,
            separators=["\n\n", "\n", ". ", " ", ""],
            keep_separator=True,
        )

    def estimate_tokens(self, text: str) -> int:
        """Estimate token count using tiktoken."""
        return len(self.tokenizer.encode(text))

    async def chunk_text(self, text: str, metadata: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        """Split text into overlapping chunks respecting semantic boundaries."""
        if not text or not text.strip():
            return []

        metadata = metadata or {}
        chunks = await asyncio.to_thread(self.splitter.split_text, text)
        
        result = []
        for idx, chunk_text in enumerate(chunks):
            if chunk_text.strip():
                result.append({
                    "text": chunk_text.strip(),
                    "metadata": {
                        **metadata,
                        "chunk_index": idx,
                        "total_chunks": len(chunks),
                        "chunk_size": self.chunk_size,
                        "chunk_overlap": self.chunk_overlap,
                        "token_count": self.estimate_tokens(chunk_text),
                    },
                })
        
        return result


chunker = RecursiveChunker()
