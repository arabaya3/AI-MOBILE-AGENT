"""JSON and JSONL document processor."""

import json
from pathlib import Path
from typing import Any, Dict, List

from src.services.chunking.recursive import chunker


class JSONProcessor:
    """Process JSON and JSONL files."""

    async def process(self, file_path: Path) -> List[Dict[str, Any]]:
        """Process JSON file with structured data awareness."""
        with open(file_path, "r", encoding="utf-8") as f:
            first_char = f.read(1)
            f.seek(0)
            
            if first_char == "[" or first_char == "{":
                data = json.load(f)
                text = self._format_json(data)
            else:
                lines = f.readlines()
                items = [json.loads(line) for line in lines if line.strip()]
                text = "\n\n".join(self._format_json(item) for item in items)
        
        return await chunker.chunk_text(text, metadata={"type": "json"})

    def _format_json(self, data: Any) -> str:
        """Format JSON data as readable text."""
        return json.dumps(data, indent=2, ensure_ascii=False)


json_processor = JSONProcessor()
