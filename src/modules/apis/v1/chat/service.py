"""Chat service orchestrating session management and LLM calls."""

from __future__ import annotations

from datetime import datetime
from typing import Dict, List, Optional

from sqlalchemy import Select, desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from src.services.databases.postgresql.models import ChatMessage, ChatSession, LLMUsageEvent
from src.services.llm_providers.openai.chat import openai_chat_service


class ChatService:
    """Encapsulates chat session persistence and response generation."""

    HISTORY_LIMIT = 12

    async def list_sessions(self, db: AsyncSession, user_id: str, *, space_id: str) -> List[ChatSession]:
        stmt: Select[ChatSession] = (
            select(ChatSession)
            .where(ChatSession.user_id == user_id, ChatSession.space_id == space_id)
            .order_by(desc(ChatSession.updated_at))
        )
        result = await db.execute(stmt)
        return result.scalars().unique().all()

    async def get_session(self, db: AsyncSession, session_id: str) -> Optional[ChatSession]:
        return await db.get(ChatSession, session_id)

    async def get_or_create_session(
        self,
        db: AsyncSession,
        *,
        user_id: str,
        space_id: str,
        session_id: Optional[str] = None,
    ) -> ChatSession:
        if session_id:
            session = await self.get_session(db, session_id)
            if session is None or session.user_id != user_id or session.space_id != space_id:
                raise PermissionError("Session not found or access denied")
            return session
        session = ChatSession(user_id=user_id, space_id=space_id)
        db.add(session)
        await db.flush()
        return session

    async def append_message(
        self,
        db: AsyncSession,
        *,
        session: ChatSession,
        role: str,
        content: str,
        meta_payload: Optional[Dict] = None,
    ) -> ChatMessage:
        message = ChatMessage(
            session_id=session.id,
            role=role,
            content=content,
            meta_payload=meta_payload or {},
        )
        db.add(message)
        if role == "user" and not session.title:
            session.title = content[:60] or "Conversation"
        session.updated_at = datetime.utcnow()
        await db.flush()
        return message

    async def get_history(
        self,
        db: AsyncSession,
        *,
        session_id: str,
        limit: Optional[int] = None,
    ) -> List[ChatMessage]:
        stmt = (
            select(ChatMessage)
            .where(ChatMessage.session_id == session_id)
            .order_by(ChatMessage.created_at.asc())
        )
        if limit:
            stmt = stmt.limit(limit)
        result = await db.execute(stmt)
        return result.scalars().all()

    async def branch_session(
        self,
        db: AsyncSession,
        *,
        user_id: str,
        session_id: str,
        from_message_id: str,
    ) -> ChatSession:
        """Create a new session by copying history up to (and including) a message."""
        session = await self.get_session(db, session_id)
        if session is None or session.user_id != user_id:
            raise PermissionError("Session not found or access denied")

        history = await self.get_history(db, session_id=session_id)
        if not history:
            raise ValueError("No messages to branch")

        cutoff_index = None
        for idx, msg in enumerate(history):
            if msg.id == from_message_id:
                cutoff_index = idx
                break
        if cutoff_index is None:
            raise ValueError("Message not found in session")

        new_session = ChatSession(
            user_id=user_id,
            space_id=session.space_id,
            title=(session.title or "Conversation") + " (branch)",
        )
        db.add(new_session)
        await db.flush()

        for msg in history[: cutoff_index + 1]:
            db.add(
                ChatMessage(
                    session_id=new_session.id,
                    role=msg.role,
                    content=msg.content,
                    meta_payload=msg.meta_payload or {},
                )
            )

        new_session.updated_at = datetime.utcnow()
        await db.flush()
        return new_session

    @staticmethod
    def export_as_markdown(history: List[ChatMessage]) -> str:
        lines: List[str] = ["# Conversation export", ""]
        for msg in history:
            role = (msg.role or "").capitalize()
            lines.append(f"## {role}")
            lines.append("")
            lines.append(msg.content or "")
            lines.append("")
        return "\n".join(lines).strip() + "\n"

    async def generate_reply(
        self,
        *,
        message: str,
        history: List[ChatMessage],
        contexts: List[Dict],
        model: str | None = None,
        allowed_tools: List[str] | None = None,
        tool_usage_sink: Dict[str, int] | None = None,
        usage_sink: Dict[str, int] | None = None,
    ) -> str:
        history_payload = [
            {"role": item.role, "content": item.content}
            for item in history[-self.HISTORY_LIMIT :]
        ]
        return await openai_chat_service.answer_with_memory(
            history=history_payload,
            question=message,
            contexts=contexts,
            model=model,
            allowed_tools=allowed_tools,
            tool_usage_sink=tool_usage_sink,
            usage_sink=usage_sink,
        )

    async def record_usage_event(
        self,
        db: AsyncSession,
        *,
        space_id: str,
        user_id: str,
        session_id: str | None,
        endpoint: str,
        model: str | None,
        usage_details: Dict[str, int] | None = None,
        cost_usd: float | None = None,
        meta_payload: Optional[Dict] = None,
        tool_usage: Optional[Dict[str, int]] = None,
    ) -> LLMUsageEvent:
        details = usage_details or {}
        payload = dict(meta_payload or {})
        if tool_usage:
            payload["tools_used"] = tool_usage
        event = LLMUsageEvent(
            space_id=space_id,
            user_id=user_id,
            session_id=session_id,
            endpoint=endpoint,
            model=model,
            request_count=1,
            input_tokens=int(details.get("input_tokens") or 0),
            output_tokens=int(details.get("output_tokens") or 0),
            total_tokens=int(details.get("total_tokens") or 0),
            cost_usd=cost_usd,
            meta_payload=payload,
        )
        db.add(event)
        await db.flush()
        return event


chat_service = ChatService()
