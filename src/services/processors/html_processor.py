"""HTML document processor."""

from pathlib import Path
from typing import Any, Dict, List

from bs4 import BeautifulSoup

from src.services.chunking.recursive import chunker


class HTMLProcessor:
    """Process HTML files with structure preservation."""

    async def process(self, file_path: Path) -> List[Dict[str, Any]]:
        """Extract clean text from HTML."""
        with open(file_path, "r", encoding="utf-8") as f:
            html_content = f.read()
        
        soup = BeautifulSoup(html_content, "lxml")
        
        for script in soup(["script", "style"]):
            script.decompose()
        
        title = soup.title.string if soup.title else ""
        text_parts = []
        
        if title:
            text_parts.append(f"Title: {title}\n")
        
        for tag in soup.find_all(["h1", "h2", "h3", "h4", "h5", "h6", "p", "li", "td"]):
            text = tag.get_text().strip()
            if text:
                text_parts.append(text)
        
        full_text = "\n\n".join(text_parts)
        
        return await chunker.chunk_text(
            full_text,
            metadata={"type": "html", "title": title}
        )


html_processor = HTMLProcessor()
