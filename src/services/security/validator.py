"""Input validation and security checks."""

from pathlib import Path
from typing import Tuple

from src.core.settings.config import settings


class InputValidator:
    """Validate uploaded files for security and constraints."""

    def __init__(self):
        self.max_file_size = getattr(settings, "MAX_FILE_SIZE_MB", 100) * 1024 * 1024

    def validate_file(self, file_path: Path, filename: str) -> Tuple[bool, str]:
        """Validate file meets security and size requirements."""
        if not file_path.exists():
            return False, "File does not exist"
        
        file_size = file_path.stat().st_size
        if file_size > self.max_file_size:
            return False, f"File exceeds maximum size of {self.max_file_size / (1024*1024):.0f}MB"
        
        if file_size == 0:
            return False, "File is empty"
        
        ext = Path(filename).suffix.lower()
        dangerous_extensions = [".exe", ".bat", ".cmd", ".sh", ".ps1", ".dll", ".so"]
        if ext in dangerous_extensions:
            return False, f"File type {ext} not allowed for security reasons"
        
        return True, "Valid"

    def sanitize_filename(self, filename: str) -> str:
        """Sanitize filename to prevent path traversal."""
        return Path(filename).name


validator = InputValidator()
