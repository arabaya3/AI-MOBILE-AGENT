"""Citations persisted with assistant messages, re-authorized every time history is read."""

from __future__ import annotations

from typing import Any, Iterable

from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.apis.v1.documents.service import document_service
from src.services.databases.postgresql.models import ChatMessage, User

VERSION = 1
MAX_ITEMS = 12
MAX_EXCERPT_CHARS = 600


def _page(match: dict[str, Any]) -> int | None:
    metadata = match.get("metadata") or {}
    for source in (metadata, metadata.get("chunk_metadata") or {}):
        for key in ("page", "page_number"):
            value = source.get(key)
            if isinstance(value, int) and value > 0:
                return value
    return None


def build(contexts: Iterable[dict[str, Any]]) -> dict[str, Any] | None:
    """Bounded, versioned record of the sources an answer used. No storage URLs or internal metadata."""
    items: list[dict[str, Any]] = []
    seen: set[str] = set()
    for match in contexts:
        document_id = match.get("document_id")
        chunk_id = str(match.get("chunk_id") or "")
        if not document_id or chunk_id in seen:
            continue
        seen.add(chunk_id)
        text = str(match.get("text") or (match.get("metadata") or {}).get("text") or "")
        items.append(
            {
                "document_id": str(document_id),
                "filename": str(match.get("filename") or "")[:200],
                "chunk_id": chunk_id[:200],
                "chunk_index": int(match.get("chunk_index") or 0),
                "page": _page(match),
                "excerpt": text[:MAX_EXCERPT_CHARS],
            }
        )
        if len(items) == MAX_ITEMS:
            break
    return {"v": VERSION, "items": items} if items else None


def with_citations(meta_payload: dict[str, Any], contexts: list[dict[str, Any]]) -> dict[str, Any]:
    record = build(contexts)
    return {**meta_payload, "citations": record} if record else meta_payload


def _stored(message: ChatMessage) -> list[dict[str, Any]]:
    record = (message.meta_payload or {}).get("citations")
    if not isinstance(record, dict) or record.get("v") != VERSION:
        return []
    return [item for item in record.get("items") or [] if isinstance(item, dict)][:MAX_ITEMS]


async def render(db: AsyncSession, user: User, space_id: str, messages: list[ChatMessage]) -> dict[str, list[dict[str, Any]]]:
    """Citations per message id. Sources the user can no longer read come back without any content."""
    stored = {m.id: _stored(m) for m in messages if m.role == "assistant"}
    if not any(stored.values()):
        return {}
    accessible = await document_service.list_accessible_documents(db, user, space_id=space_id)
    allowed = {doc.id for doc in accessible}
    rendered: dict[str, list[dict[str, Any]]] = {}
    for message_id, items in stored.items():
        if not items:
            continue
        rendered[message_id] = [
            {
                "available": True,
                "document_id": item.get("document_id"),
                "filename": item.get("filename") or "",
                "chunk_index": item.get("chunk_index"),
                "page": item.get("page"),
                "excerpt": item.get("excerpt") or "",
            }
            if item.get("document_id") in allowed
            else {"available": False}
            for item in items
        ]
    return rendered
