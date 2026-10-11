"""PyMuPDF-only PDF processing pipeline."""

from __future__ import annotations

import asyncio
import re
from pathlib import Path
from typing import Any, Dict, List, Tuple

import fitz

from src.core.settings.config import settings
from src.core.settings.logging import logger
from src.services.chunking.recursive import chunker

MIN_EXTRACTED_CHARS = 120
DEFAULT_OCR_LANGUAGE = "eng"
DEFAULT_OCR_DPI = 300


class AdvancedPDFProcessor:
    """PDF processor that only uses PyMuPDF extraction and OCR APIs."""

    async def process(self, file_path: Path) -> List[Dict[str, Any]]:
        """Process PDF with a PyMuPDF-only extraction pipeline."""
        pages_data, source = await self.extract_pdf_with_ocr_fallback(file_path)
        chunks: List[Dict[str, Any]] = []
        for page_text, page_num in pages_data:
            if not page_text.strip():
                continue
            page_chunks = await chunker.chunk_text(
                page_text,
                metadata={"page": page_num, "source": source},
            )
            chunks.extend(page_chunks)
        return chunks

    async def extract_pdf_with_ocr_fallback(self, file_path: Path) -> Tuple[List[Tuple[str, int]], str]:
        """Extract text using only PyMuPDF; no non-PyMuPDF fallback engines are used."""
        pages_data = await self._extract_with_pymupdf_ocr(file_path)

        low_text_pages = self._low_text_pages(pages_data)
        if low_text_pages:
            logger.info(
                "PyMuPDF-only extraction left low-text pages",
                extra={"file_path": str(file_path), "pages": low_text_pages[:20], "count": len(low_text_pages)},
            )

        total_chars = self._count_chars(pages_data)
        if total_chars == 0:
            logger.warning(
                "PyMuPDF-only extraction returned no text",
                extra={
                    "file_path": str(file_path),
                    "chars": total_chars,
                    "page_count": len(pages_data),
                    "low_pages": len(low_text_pages),
                },
            )
        elif total_chars < MIN_EXTRACTED_CHARS:
            logger.info(
                "PyMuPDF-only extraction returned limited text",
                extra={
                    "file_path": str(file_path),
                    "chars": total_chars,
                    "page_count": len(pages_data),
                    "low_pages": len(low_text_pages),
                },
            )

        return pages_data, "pymupdf_ocr"

    async def _extract_with_pymupdf_ocr(
        self,
        file_path: Path,
        page_numbers: List[int] | None = None,
    ) -> List[Tuple[str, int]]:
        """Extract text page by page using PyMuPDF text and OCR APIs."""
        selected_pages = set(page_numbers or [])
        filter_pages = bool(selected_pages)
        language = self._get_ocr_language()
        dpi = self._get_ocr_dpi()
        tessdata = self._get_tessdata_path()

        def _extract() -> List[Tuple[str, int]]:
            result: List[Tuple[str, int]] = []
            first_ocr_error: str | None = None
            ocr_available = True
            with fitz.open(file_path) as doc:
                for page_num, page in enumerate(doc, 1):
                    if filter_pages and page_num not in selected_pages:
                        continue
                    text = (page.get_text("text") or "").strip()
                    if not text and ocr_available:
                        try:
                            textpage = page.get_textpage_ocr(
                                flags=0,
                                language=language,
                                dpi=dpi,
                                full=True,
                                tessdata=tessdata,
                            )
                            text = (page.get_text("text", textpage=textpage) or "").strip()
                        except Exception as exc:  # noqa: BLE001
                            if first_ocr_error is None:
                                first_ocr_error = str(exc)
                            # Avoid repeating expensive OCR attempts when OCR runtime is unavailable.
                            lowered_error = str(exc).lower()
                            if "tesseract" in lowered_error or "tessdata" in lowered_error:
                                ocr_available = False
                    result.append((self._normalize_text(text), page_num))
            if first_ocr_error:
                logger.warning(
                    "PyMuPDF OCR page extraction had errors: %s. Ensure Tesseract is installed and OCR language data is available.",
                    first_ocr_error,
                    extra={
                        "language": language,
                        "dpi": dpi,
                        "tessdata": tessdata,
                    },
                )
            return result

        try:
            return await asyncio.to_thread(_extract)
        except Exception as exc:  # noqa: BLE001
            logger.warning("PyMuPDF OCR extraction failed", extra={"error": str(exc)})
            return []

    @staticmethod
    def _normalize_text(text: str) -> str:
        cleaned_lines: List[str] = []
        for raw_line in (text or "").splitlines():
            line = raw_line.strip()
            if not line:
                continue
            # Drop markdown divider noise from converter output.
            if re.fullmatch(r"[-_=]{3,}", line):
                continue
            cleaned_lines.append(line)
        return "\n".join(cleaned_lines)

    @staticmethod
    def _get_ocr_language() -> str:
        value = str(getattr(settings, "PDF_OCR_LANGUAGE", DEFAULT_OCR_LANGUAGE) or DEFAULT_OCR_LANGUAGE).strip()
        return value or DEFAULT_OCR_LANGUAGE

    @staticmethod
    def _get_ocr_dpi() -> int:
        try:
            value = int(getattr(settings, "PDF_OCR_DPI", DEFAULT_OCR_DPI))
        except (TypeError, ValueError):
            value = DEFAULT_OCR_DPI
        return max(150, min(600, value))

    @staticmethod
    def _get_tessdata_path() -> str | None:
        value = str(getattr(settings, "PDF_OCR_TESSDATA", "") or "").strip()
        return value or None

    @staticmethod
    def _count_chars(pages: List[Tuple[str, int]]) -> int:
        return sum(len((text or "").strip()) for text, _ in pages)

    @staticmethod
    def _low_text_pages(pages: List[Tuple[str, int]]) -> List[int]:
        return [page_num for text, page_num in pages if not (text or "").strip()]


pdf_processor = AdvancedPDFProcessor()
