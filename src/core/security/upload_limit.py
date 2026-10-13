"""Caps request bodies on multipart upload routes before the framework spools them to disk.

Handlers still check every file exactly; this stops oversized or endless (chunked) bodies early.
"""

from __future__ import annotations

import json

from starlette.exceptions import HTTPException

from src.core.settings.config import settings

MULTIPART_OVERHEAD = 64 * 1024
LIMITED_SUFFIXES = {"/documents/upload": 1, "/documents/upload-and-vectorize": 1, "/documents/upload-multiple": 10}


def _message() -> str:
    return f"Files must be {int(settings.MAX_UPLOAD_BYTES) // (1024 * 1024)} MiB or smaller."


class _BodyTooLarge(HTTPException):
    """Raised from receive(); FastAPI re-raises HTTPExceptions from body parsing, so this becomes a 413."""

    def __init__(self) -> None:
        super().__init__(status_code=413, detail=_message())


class UploadSizeLimitMiddleware:
    def __init__(self, app) -> None:
        self.app = app

    def _limit_for(self, path: str) -> int | None:
        for suffix, files in LIMITED_SUFFIXES.items():
            if path.endswith(suffix):
                return files * int(settings.MAX_UPLOAD_BYTES) + MULTIPART_OVERHEAD
        return None

    async def __call__(self, scope, receive, send):
        limit = self._limit_for(scope.get("path", "")) if scope["type"] == "http" else None
        if limit is None:
            await self.app(scope, receive, send)
            return

        declared = dict(scope.get("headers") or []).get(b"content-length")
        if declared is not None and declared.isdigit() and int(declared) > limit:
            await self._reject(send)
            return

        received = 0
        started = False

        async def limited_receive():
            nonlocal received
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > limit:
                    raise _BodyTooLarge
            return message

        async def tracking_send(message):
            nonlocal started
            if message["type"] == "http.response.start":
                started = True
            await send(message)

        try:
            await self.app(scope, limited_receive, tracking_send)
        except _BodyTooLarge:
            if not started:
                await self._reject(send)

    @staticmethod
    async def _reject(send) -> None:
        body = json.dumps({"detail": _message()}).encode()
        await send(
            {
                "type": "http.response.start",
                "status": 413,
                "headers": [(b"content-type", b"application/json"), (b"content-length", str(len(body)).encode())],
            }
        )
        await send({"type": "http.response.body", "body": body})
