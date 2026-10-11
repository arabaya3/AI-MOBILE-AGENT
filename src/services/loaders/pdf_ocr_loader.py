"""
Enhanced PDF OCR Loader
=======================
Fixes Bug #1 — PyMuPDF failing to extract text from image-based PDFs.

Strategy (applied in order):
1. PyMuPDF native text extraction (fast, works for digitally-born PDFs).
2. PyMuPDF built-in OCR via ``page.get_textpage_ocr()`` (requires Tesseract).
3. ``pymupdf4llm`` markdown extraction as a secondary fallback when steps
   1 & 2 produce insufficient text.

The loader is a drop-in companion to ``AdvancedPDFProcessor``.  Import it
where you need richer OCR capabilities.

Usage::

    from src.services.loaders.pdf_ocr_loader import ocr_loader
    chunks = await ocr_loader.load(Path("/path/to/scan.pdf"))
"""

from __future__ import annotations

import asyncio
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import fitz  # PyMuPDF

from src.core.settings.config import settings
from src.core.settings.logging import logger
from src.services.chunking.recursive import chunker

# Minimum characters per page to consider the extraction successful.
MIN_CHARS_PER_PAGE = 50
MIN_TOTAL_CHARS = 120
DEFAULT_OCR_LANGUAGE = "eng"
DEFAULT_OCR_DPI = 300


class PDFOCRLoader:
    """
    Three-tier PDF text extraction with Tesseract OCR fallback.

    Tier 1 – PyMuPDF native ``get_text("text")``:
        Zero overhead.  Works perfectly for digitally-authored PDFs.

    Tier 2 – PyMuPDF OCR via ``page.get_textpage_ocr()``:
        Uses the embedded Tesseract runtime inside PyMuPDF (requires
        Tesseract to be installed on the host OS or the ``pymupdf-open``
        docker image).  Activated *per-page* when Tier 1 produces
        insufficient text.

    Tier 3 – pymupdf4llm markdown extraction:
        Only activated when the entire document still has insufficient text
        after Tiers 1 & 2.  ``pymupdf4llm`` is an optional dependency.
    """

    # ------------------------------------------------------------------ #
    # Public API                                                           #
    # ------------------------------------------------------------------ #

    async def load(self, file_path: Path) -> List[Dict[str, Any]]:
        """
        Extract text from a PDF and split it into retrieval-ready chunks.

        Returns:
            List of chunk dicts with ``text`` and ``metadata`` keys.
        """
        pages_data, extraction_method = await self._extract(file_path)
        logger.info(
            "PDF extracted",
            extra={
                "file": str(file_path),
                "method": extraction_method,
                "pages": len(pages_data),
                "total_chars": sum(len(t) for t, _ in pages_data),
            },
        )
        chunks: List[Dict[str, Any]] = []
        for page_text, page_num in pages_data:
            if not page_text.strip():
                continue
            page_chunks = await chunker.chunk_text(
                page_text,
                metadata={
                    "page": page_num,
                    "source": str(file_path.name),
                    "extraction_method": extraction_method,
                },
            )
            chunks.extend(page_chunks)
        return chunks

    # ------------------------------------------------------------------ #
    # Extraction pipeline                                                  #
    # ------------------------------------------------------------------ #

    async def _extract(
        self, file_path: Path
    ) -> Tuple[List[Tuple[str, int]], str]:
        """Run the three-tier extraction pipeline."""
        # --- Tier 1 + 2 (PyMuPDF native + OCR) --------------------------
        pages_data = await asyncio.to_thread(self._tier1_and_tier2, file_path)
        total_chars = sum(len(t) for t, _ in pages_data)

        if total_chars >= MIN_TOTAL_CHARS:
            return pages_data, "pymupdf_ocr"

        # --- Tier 3 (pymupdf4llm) -----------------------------------------
        logger.info(
            "PyMuPDF OCR yielded insufficient text — trying pymupdf4llm",
            extra={"file": str(file_path), "chars_so_far": total_chars},
        )
        pymupdf4llm_pages = await asyncio.to_thread(
            self._tier3_pymupdf4llm, file_path
        )
        if pymupdf4llm_pages:
            t4llm_chars = sum(len(t) for t, _ in pymupdf4llm_pages)
            if t4llm_chars > total_chars:
                logger.info(
                    "pymupdf4llm produced better extraction",
                    extra={"file": str(file_path), "chars": t4llm_chars},
                )
                return pymupdf4llm_pages, "pymupdf4llm"

        # Return whatever Tier 1/2 gave us (could be empty).
        return pages_data, "pymupdf_ocr"

    # ------------------------------------------------------------------ #
    # Tier 1 + 2 implementation                                           #
    # ------------------------------------------------------------------ #

    def _tier1_and_tier2(self, file_path: Path) -> List[Tuple[str, int]]:
        """
        Extract text page-by-page.

        For each page:
        * Try native text extraction first (Tier 1).
        * If insufficient, fall back to PyMuPDF OCR (Tier 2).
        """
        ocr_available = True
        first_ocr_error: Optional[str] = None
        language = self._ocr_language()
        dpi = self._ocr_dpi()
        tessdata = self._tessdata_path()
        result: List[Tuple[str, int]] = []

        with fitz.open(str(file_path)) as doc:
            for page_idx, page in enumerate(doc, start=1):
                # Tier 1
                text = (page.get_text("text") or "").strip()

                # Tier 2 — only if Tier 1 text is sparse
                if len(text) < MIN_CHARS_PER_PAGE and ocr_available:
                    try:
                        tp = page.get_textpage_ocr(
                            flags=0,
                            language=language,
                            dpi=dpi,
                            full=True,
                            tessdata=tessdata,
                        )
                        ocr_text = (page.get_text("text", textpage=tp) or "").strip()
                        if len(ocr_text) > len(text):
                            text = ocr_text
                    except Exception as exc:  # noqa: BLE001
                        if first_ocr_error is None:
                            first_ocr_error = str(exc)
                        err_low = str(exc).lower()
                        if "tesseract" in err_low or "tessdata" in err_low:
                            ocr_available = False
                            logger.warning(
                                "Tesseract unavailable — OCR disabled for this document",
                                extra={"file": str(file_path), "error": str(exc)},
                            )

                result.append((self._normalise(text), page_idx))

        if first_ocr_error and not ocr_available:
            logger.warning(
                "PyMuPDF OCR encountered errors",
                extra={"error": first_ocr_error, "language": language, "tessdata": tessdata},
            )

        return result

    # ------------------------------------------------------------------ #
    # Tier 3 – pymupdf4llm                                                #
    # ------------------------------------------------------------------ #

    @staticmethod
    def _tier3_pymupdf4llm(file_path: Path) -> List[Tuple[str, int]]:
        """
        Use ``pymupdf4llm`` to produce a richer markdown extraction.

        Returns an empty list if the package is not installed, so callers
        can safely fall through to the Tier 1/2 result.

        Install with: ``pip install pymupdf4llm``
        """
        try:
            import pymupdf4llm  # type: ignore[import]
        except ImportError:
            logger.debug("pymupdf4llm not installed — Tier 3 skipped")
            return []

        try:
            # ``to_markdown()`` accepts a file path string and returns a
            # single markdown document covering all pages.
            md: str = pymupdf4llm.to_markdown(str(file_path))
            if not md or not md.strip():
                return []
            # Split by page markers if present, else treat as one "page".
            return [(md.strip(), 1)]
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "pymupdf4llm extraction failed",
                extra={"file": str(file_path), "error": str(exc)},
            )
            return []

    # ------------------------------------------------------------------ #
    # Helpers                                                              #
    # ------------------------------------------------------------------ #

    @staticmethod
    def _normalise(text: str) -> str:
        """Strip noise lines and collapse whitespace."""
        lines = []
        for raw in (text or "").splitlines():
            line = raw.strip()
            if not line:
                continue
            if re.fullmatch(r"[-_=]{3,}", line):
                continue
            lines.append(line)
        return "\n".join(lines)

    @staticmethod
    def _ocr_language() -> str:
        val = str(getattr(settings, "PDF_OCR_LANGUAGE", DEFAULT_OCR_LANGUAGE) or DEFAULT_OCR_LANGUAGE).strip()
        return val or DEFAULT_OCR_LANGUAGE

    @staticmethod
    def _ocr_dpi() -> int:
        try:
            val = int(getattr(settings, "PDF_OCR_DPI", DEFAULT_OCR_DPI))
        except (TypeError, ValueError):
            val = DEFAULT_OCR_DPI
        return max(150, min(600, val))

    @staticmethod
    def _tessdata_path() -> Optional[str]:
        val = str(getattr(settings, "PDF_OCR_TESSDATA", "") or "").strip()
        return val or None


# ─── Singleton ────────────────────────────────────────────────────────────────
ocr_loader = PDFOCRLoader()
