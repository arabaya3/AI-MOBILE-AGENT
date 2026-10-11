"""Logging configuration and setup."""

from __future__ import annotations

import logging
import os
from typing import Optional

from src.core.settings.logging import logger as app_logger


DEFAULT_FORMAT = "%(asctime)s [%(levelname)s] %(name)s %(message)s"


def setup_logging(*, level: Optional[str] = None) -> None:
	"""Configure application logging once with sane defaults."""

	if getattr(setup_logging, "_configured", False):  # type: ignore[attr-defined]
		return

	log_level = (level or os.getenv("LOG_LEVEL", "INFO")).upper()
	app_logger.setLevel(log_level)

	root_logger = logging.getLogger()
	root_logger.setLevel(log_level)

	if not root_logger.handlers:
		for handler in app_logger.handlers:
			root_logger.addHandler(handler)

	logging.getLogger("aioboto3").setLevel(logging.WARNING)
	logging.getLogger("botocore").setLevel(logging.WARNING)
	logging.getLogger("urllib3").setLevel(logging.WARNING)
	logging.getLogger("opentelemetry").setLevel(logging.CRITICAL)
	logging.getLogger("opentelemetry.sdk").setLevel(logging.CRITICAL)
	logging.getLogger("opentelemetry.sdk._shared_internal").setLevel(logging.CRITICAL)

	setattr(setup_logging, "_configured", True)  # type: ignore[attr-defined]
