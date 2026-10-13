"""Text extraction per format. Imported by the isolated extraction worker; no network clients here."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List

import aiofiles

MAX_PDF_PAGES = 2000


class ExtractionError(Exception):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def _check_pdf(path: Path) -> None:
    import fitz

    try:
        with fitz.open(path) as doc:
            if doc.needs_pass or doc.is_encrypted:
                raise ExtractionError("encrypted")
            if doc.page_count > MAX_PDF_PAGES:
                raise ExtractionError("too_complex")
    except ExtractionError:
        raise
    except Exception as exc:  # noqa: BLE001
        raise ExtractionError("corrupt") from exc


async def extract_chunks(path: Path, ext: str) -> List[Dict[str, Any]]:
    from src.services.chunking.recursive import chunker

    if ext == ".pdf":
        _check_pdf(path)
        from src.services.processors.pdf_advanced import pdf_processor

        return await pdf_processor.process(path)
    if ext == ".docx":
        from docx import Document

        doc = Document(path)
        text = "\n\n".join(p.text for p in doc.paragraphs if p.text.strip())
        return await chunker.chunk_text(text, metadata={"type": "docx"})
    if ext == ".xlsx":
        from src.services.processors.excel_advanced import excel_processor

        return await excel_processor.process(path)
    if ext == ".pptx":
        from src.services.processors.powerpoint_advanced import powerpoint_processor

        return await powerpoint_processor.process(path)
    if ext == ".csv":
        import pandas as pd

        df = pd.read_csv(path)
        text = f"CSV Data ({len(df)} rows, {len(df.columns)} columns)\n\nColumns: {', '.join(map(str, df.columns))}\n\n{df.to_string()}"
        return await chunker.chunk_text(text, metadata={"type": "csv", "rows": len(df), "columns": len(df.columns)})
    if ext in (".json", ".jsonl"):
        from src.services.processors.json_processor import json_processor

        return await json_processor.process(path)
    if ext in (".html", ".htm"):
        from src.services.processors.html_processor import html_processor

        return await html_processor.process(path)
    if ext in (".md", ".markdown"):
        from src.services.processors.markdown_processor import markdown_processor

        return await markdown_processor.process(path)
    if ext == ".txt":
        async with aiofiles.open(path, "r", encoding="utf-8-sig") as handle:
            content = await handle.read()
        return await chunker.chunk_text(content, metadata={"type": "text"})
    raise ExtractionError("unsupported_type")
