"""A client disconnecting mid-stream, against a real uvicorn server and the app's pooled database engine.

Documented behavior: the user message stays, the partial reply is rolled back, the generation attempt
(committed before the provider call) is finalized as `cancelled` with `usage_state = unknown`, no
zero-token usage row is written, and the provider stream is closed. Whether the provider stops billing
when its stream is closed cannot be observed locally and is not claimed.
"""

import asyncio
import socket

import httpx
import pytest
import uvicorn
from fastapi import FastAPI
from sqlalchemy import func, select

from src.modules.apis.v1.chat.router import router as chat_router
from src.services.databases.postgresql import database
from src.services.databases.postgresql.models import ChatMessage, ChatSession, GenerationAttempt, LLMUsageEvent
from src.services.llm_providers.stub import StubChatProvider

from tests.conftest import auth_headers

STREAM = "/api/v1/chat/query/stream"


def _port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


@pytest.fixture
async def live_server(engine):
    app = FastAPI()
    app.include_router(chat_router, prefix="/api/v1")
    port = _port()
    server = uvicorn.Server(uvicorn.Config(app, host="127.0.0.1", port=port, log_level="warning", lifespan="off"))
    task = asyncio.create_task(server.serve())
    while not server.started:
        await asyncio.sleep(0.05)
    yield f"http://127.0.0.1:{port}"
    server.should_exit = True
    await task
    # The app engine's pool belongs to this test's event loop.
    await database.engine.dispose()


async def test_disconnect_mid_stream_keeps_the_server_healthy(live_server, factory, session_factory):
    alice = await factory.user("alice@example.com")
    team = await factory.space("Team")
    await factory.member(team, alice)
    headers = auth_headers(alice, team)
    closed_before = StubChatProvider.closed_early

    async with httpx.AsyncClient(base_url=live_server, timeout=15) as client:
        for _ in range(2):
            async with client.stream("POST", STREAM, json={"message": "[[slow]] cut"}, headers=headers) as response:
                assert response.status_code == 200
                async for line in response.aiter_lines():
                    if line.startswith("event: delta"):
                        break
            # Leaving the block closes the connection mid-stream; give the server time to notice.
            await asyncio.sleep(1.0)
            for _ in range(4):
                follow_up = await client.get("/api/v1/chat/models", headers=headers)
                assert follow_up.status_code == 200

    async with session_factory() as db:
        sessions = (await db.execute(select(ChatSession).where(ChatSession.user_id == alice.id))).scalars().all()
        assert len(sessions) == 2
        for session in sessions:
            roles = (await db.execute(select(ChatMessage.role).where(ChatMessage.session_id == session.id))).scalars().all()
            assert roles == ["user"]
            usage_rows = await db.scalar(
                select(func.count()).select_from(LLMUsageEvent).where(LLMUsageEvent.session_id == session.id)
            )
            assert usage_rows == 0
            attempts = (await db.execute(select(GenerationAttempt).where(GenerationAttempt.session_id == session.id))).scalars().all()
            assert [(a.outcome, a.usage_state, a.error_code, a.total_tokens) for a in attempts] == [
                ("cancelled", "unknown", "client_disconnected", None)
            ]
    assert StubChatProvider.closed_early - closed_before == 2
