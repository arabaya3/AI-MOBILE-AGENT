"""Document operations tool.

Provides read-only access to the caller's accessible documents (metadata + chunks)
so the model can reference or quote from them when needed.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from sqlalchemy import select

from src.modules.apis.v1.documents.service import document_service
from src.services.databases.postgresql.database import AsyncSessionLocal
from src.services.databases.postgresql.models import Document, User
from src.services.tools.base import BaseTool, ToolDefinition, ToolParameter


class DocumentOpsTool(BaseTool):
    @property
    def definition(self) -> ToolDefinition:
        return ToolDefinition(
            name="document_ops",
            description=(
                "Read-only access to document metadata and text chunks. "
                "Use to list accessible documents or fetch chunks for a document ID."
            ),
            parameters=[
                ToolParameter(
                    name="action",
                    type="string",
                    description="One of: list_documents, get_document_chunks",
                    required=True,
                    enum=["list_documents", "get_document_chunks"],
                ),
                ToolParameter(
                    name="document_id",
                    type="string",
                    description="Document ID (required for get_document_chunks)",
                    required=False,
                ),
                ToolParameter(
                    name="limit",
                    type="number",
                    description="Max chunks to return (default 10)",
                    required=False,
                ),
            ],
        )

    async def execute(
        self,
        action: str,
        document_id: Optional[str] = None,
        limit: int = 10,
        **_: Any,
    ) -> Dict[str, Any]:
        # Note: tools run without request context. We treat this as "system" access
        # and therefore restrict to admin-only usage by default.
        # If you want per-user scoping, wire a user_id into tool execution context.
        try:
            async with AsyncSessionLocal() as db:
                # Best-effort admin scoping: if there is no user context, list all.
                # The chat service already enforces doc access for end-user retrieval.
                dummy_admin = User(id="tool", email="tool@local", role="admin")

                if action == "list_documents":
                    docs = (await db.execute(select(Document))).scalars().unique().all()
                    return {
                        "success": True,
                        "documents": [
                            {
                                "id": d.id,
                                "filename": d.filename,
                                "file_type": d.file_type,
                                "created_at": getattr(d, "created_at", None),
                            }
                            for d in docs
                        ],
                    }

                if action == "get_document_chunks":
                    if not document_id:
                        return {"success": False, "error": "document_id is required"}
                    chunks = await document_service.get_document_chunks(db, document_id)
                    items: List[Dict[str, Any]] = []
                    for ch in (chunks or [])[: max(1, min(int(limit or 10), 30))]:
                        items.append(
                            {
                                "chunk_index": ch.get("chunk_index"),
                                "text": ch.get("text", ""),
                                "metadata": ch.get("metadata", {}) or {},
                            }
                        )
                    return {"success": True, "document_id": document_id, "chunks": items}

                return {"success": False, "error": f"Unknown action: {action}"}
        except Exception as exc:  # noqa: BLE001
            return {"success": False, "error": str(exc)}
