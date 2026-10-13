"""Upload safety checks: filenames, streaming size limit, and content inspection by bytes."""

from __future__ import annotations

import codecs
import hashlib
import os
import re
import tempfile
import unicodedata
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import AsyncIterator

TEXT_EXTENSIONS = {".txt", ".csv", ".json", ".jsonl", ".html", ".htm", ".md", ".markdown"}
OOXML_PARTS = {".docx": "word/document.xml", ".xlsx": "xl/workbook.xml", ".pptx": "ppt/presentation.xml"}
SUPPORTED_EXTENSIONS = TEXT_EXTENSIONS | set(OOXML_PARTS) | {".pdf"}

MAX_ZIP_ENTRIES = 10_000
MAX_ZIP_UNCOMPRESSED = 200 * 1024 * 1024
MAX_ZIP_RATIO = 200
OLE_MAGIC = b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"
_UNSAFE_CHARS = re.compile(r'[\x00-\x1f\x7f<>:"/\\|?*]')


class UploadRejected(Exception):
    """A client-safe rejection: `code` is stable for clients, `message` contains no internals."""

    def __init__(self, code: str, message: str, status_code: int = 422) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code


@dataclass
class ReceivedFile:
    path: Path
    size: int
    sha256: str


def sanitize_filename(raw: str | None) -> str:
    """Display-safe base name: no directories, control characters or reserved characters."""
    name = unicodedata.normalize("NFC", raw or "")
    name = name.replace("\\", "/").rsplit("/", 1)[-1]
    name = _UNSAFE_CHARS.sub("_", name).strip().strip(".")
    name = re.sub(r"\s+", " ", name)
    stem, ext = os.path.splitext(name)
    if len(name) > 180:
        name = stem[: 180 - len(ext)] + ext
    if not stem:
        name = f"document{ext.lower()}"
    return name


def extension_of(filename: str) -> str:
    ext = os.path.splitext(filename)[1].lower()
    if ext not in SUPPORTED_EXTENSIONS:
        raise UploadRejected("unsupported_type", "This file type is not supported.", 415)
    return ext


async def receive_to_temp(
    chunks: AsyncIterator[bytes],
    *,
    limit: int,
    directory: Path,
) -> ReceivedFile:
    """Write an upload to a private temp file, hashing as it goes and stopping past `limit` bytes."""
    directory.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix="upload-", dir=directory)
    path = Path(name)
    digest = hashlib.sha256()
    size = 0
    try:
        with os.fdopen(fd, "wb") as handle:
            async for chunk in chunks:
                if not chunk:
                    continue
                size += len(chunk)
                if size > limit:
                    raise UploadRejected("too_large", f"Files must be {limit // (1024 * 1024)} MiB or smaller.", 413)
                digest.update(chunk)
                handle.write(chunk)
    except BaseException:
        path.unlink(missing_ok=True)
        raise
    return ReceivedFile(path=path, size=size, sha256=digest.hexdigest())


def inspect_content(path: Path, ext: str) -> None:
    """Reject content that does not match its declared type, is encrypted, or is structurally unsafe."""
    if path.stat().st_size == 0:
        raise UploadRejected("empty", "The file is empty.")
    with path.open("rb") as handle:
        head = handle.read(8)
    if head.startswith(OLE_MAGIC):
        raise UploadRejected("encrypted", "Password-protected or legacy Office files are not supported.")
    if ext == ".pdf":
        if not head.startswith(b"%PDF-"):
            raise UploadRejected("invalid_content", "The file content does not match its type.", 415)
    elif ext in OOXML_PARTS:
        _inspect_ooxml(path, OOXML_PARTS[ext])
    else:
        _inspect_text(path)


def _inspect_ooxml(path: Path, required_part: str) -> None:
    if not zipfile.is_zipfile(path):
        raise UploadRejected("invalid_content", "The file content does not match its type.", 415)
    try:
        with zipfile.ZipFile(path) as archive:
            entries = archive.infolist()
            if len(entries) > MAX_ZIP_ENTRIES:
                raise UploadRejected("corrupt", "The file structure is not supported.")
            total = 0
            for entry in entries:
                if entry.flag_bits & 0x1:
                    raise UploadRejected("encrypted", "Password-protected files are not supported.")
                total += entry.file_size
                if entry.compress_size and entry.file_size / entry.compress_size > MAX_ZIP_RATIO:
                    raise UploadRejected("corrupt", "The file structure is not supported.")
            if total > MAX_ZIP_UNCOMPRESSED:
                raise UploadRejected("corrupt", "The file expands beyond the supported size.")
            if required_part not in archive.namelist():
                raise UploadRejected("invalid_content", "The file content does not match its type.", 415)
    except zipfile.BadZipFile as exc:
        raise UploadRejected("corrupt", "The file is damaged and cannot be read.") from exc


def _inspect_text(path: Path) -> None:
    decoder = codecs.getincrementaldecoder("utf-8")()
    try:
        with path.open("rb") as handle:
            while chunk := handle.read(64 * 1024):
                if b"\x00" in chunk:
                    raise UploadRejected("invalid_content", "The file content does not match its type.", 415)
                decoder.decode(chunk)
            decoder.decode(b"", final=True)
    except UnicodeDecodeError as exc:
        raise UploadRejected("unsupported_encoding", "Text files must be UTF-8 encoded.", 415) from exc
