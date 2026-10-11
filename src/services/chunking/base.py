"""Base interface for document chunking strategies."""

from abc import ABC, abstractmethod
from typing import Any, Dict, List


class BaseChunker(ABC):
    """Abstract base class for text chunking strategies."""

    @abstractmethod
    async def chunk_text(self, text: str, metadata: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        """Split text into chunks with metadata."""
        pass

    @abstractmethod
    def estimate_tokens(self, text: str) -> int:
        """Estimate token count for text."""
        pass
