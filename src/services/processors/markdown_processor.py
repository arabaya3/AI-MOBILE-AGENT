"""Markdown document processor."""

from pathlib import Path
from typing import Any, Dict, List

from src.services.chunking.recursive import chunker


class MarkdownProcessor:
    """Process Markdown files with structure awareness."""

    async def process(self, file_path: Path) -> List[Dict[str, Any]]:
        """Process Markdown preserving structure."""
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
        
        return await chunker.chunk_text(
            content,
            metadata={"type": "markdown"}
        )


markdown_processor = MarkdownProcessor()
