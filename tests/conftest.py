"""Shared fixtures. Tests run only against a disposable local PostgreSQL database."""

import os
import socket


def _free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


S3_PORT = _free_port()

_DB = {
    "POSTGRES_HOST": os.environ.get("TEST_POSTGRES_HOST", "localhost"),
    "POSTGRES_PORT": os.environ.get("TEST_POSTGRES_PORT", "5432"),
    "POSTGRES_DB": os.environ.get("TEST_POSTGRES_DB", "teia_test"),
    "POSTGRES_USER": os.environ.get("TEST_POSTGRES_USER", "postgres"),
    "POSTGRES_PASSWORD": os.environ.get("TEST_POSTGRES_PASSWORD", "postgres"),
}
if _DB["POSTGRES_HOST"] not in {"localhost", "127.0.0.1", "postgres", "teia-test-db"} or not _DB["POSTGRES_DB"].endswith("_test"):
    raise RuntimeError("Refusing to run tests against a non-local or non-test database")
os.environ.update(_DB)
os.environ.update(
    {
        "SECRET_KEY": "test-only-secret",
        "EMAIL_ENABLED": "true",
        "SMTP_HOST": "smtp.invalid",
        "FRONTEND_URL": "https://app.example.test",
        "RATE_LIMIT_ENABLED": "false",
        "APP_ENV": "test",
        "CHAT_PROVIDER_STUB": "true",
        "DEFAULT_ALLOWED_MODELS": '["teia-stub-1", "teia-stub-2"]',
        "OPENAI_CHAT_MODEL": "teia-stub-1",
        "QDRANT_URL": ":memory:",
        "QDRANT_VECTOR_SIZE": "64",
        "EMBEDDING_PROVIDER_STUB": "true",
        "ENABLE_RERANKING": "false",
        "AWS_S3_ENDPOINT_URL": f"http://127.0.0.1:{S3_PORT}",
        "AWS_ACCESS_KEY_ID": "test",
        "AWS_SECRET_ACCESS_KEY": "test",
        "AWS_REGION": "us-east-1",
        "AWS_S3_BUCKET": "test-bucket",
    }
)

from datetime import datetime  # noqa: E402

import httpx  # noqa: E402
import pytest  # noqa: E402
from fastapi import FastAPI  # noqa: E402
from sqlalchemy import text  # noqa: E402
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine  # noqa: E402
from sqlalchemy.pool import NullPool  # noqa: E402

from src.core.security.auth import create_access_token  # noqa: E402
from src.core.settings.config import settings  # noqa: E402
from src.modules.apis.v1.auth.router import router as auth_router  # noqa: E402
from src.modules.apis.v1.auth.service import auth_service  # noqa: E402
from src.modules.apis.v1.sharing.router import router as sharing_router  # noqa: E402
from src.modules.apis.v1.spaces.router import router as spaces_router  # noqa: E402
from src.modules.apis.v1.chat.router import router as chat_router  # noqa: E402
from src.modules.apis.v1.documents.router import router as documents_router  # noqa: E402
from src.core.security.upload_limit import UploadSizeLimitMiddleware  # noqa: E402
from src.services.databases.postgresql.database import get_db  # noqa: E402
from src.services.databases.postgresql.models import (  # noqa: E402
    Base,
    ChatMessage,
    ChatSession,
    Space,
    SpaceMember,
)
from src.services.email import service as email_module  # noqa: E402


class EmailSink:
    """Local stand-in for smtplib.SMTP that records messages instead of sending them."""

    messages: list = []

    def __init__(self, host, port, *args, **kwargs):
        pass

    def starttls(self):
        pass

    def login(self, user, password):
        pass

    def send_message(self, msg):
        EmailSink.messages.append(msg)

    def quit(self):
        pass


@pytest.fixture(scope="session", autouse=True)
def local_s3():
    """moto's S3-compatible server on localhost: real HTTP object storage, no AWS account."""
    from moto.server import ThreadedMotoServer

    server = ThreadedMotoServer(ip_address="127.0.0.1", port=S3_PORT)
    server.start()
    yield
    server.stop()


@pytest.fixture
async def engine():
    eng = create_async_engine(settings.database_url, poolclass=NullPool)
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield eng
    await eng.dispose()


@pytest.fixture
def session_factory(engine):
    return async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


@pytest.fixture
def email_sink(monkeypatch):
    EmailSink.messages = []
    monkeypatch.setattr(email_module.smtplib, "SMTP", EmailSink)
    monkeypatch.setattr(email_module.smtplib, "SMTP_SSL", EmailSink)
    monkeypatch.setattr(email_module.email_service, "enabled", True)
    return EmailSink


@pytest.fixture
async def client(session_factory, email_sink):
    app = FastAPI()
    app.add_middleware(UploadSizeLimitMiddleware)
    app.include_router(documents_router, prefix="/api/v1")
    app.include_router(auth_router, prefix="/api/v1")
    app.include_router(sharing_router, prefix="/api/v1")
    app.include_router(spaces_router, prefix="/api/v1")
    app.include_router(chat_router, prefix="/api/v1")

    async def _get_db():
        async with session_factory() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    app.dependency_overrides[get_db] = _get_db
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as c:
        yield c


@pytest.fixture
def factory(session_factory):
    class Factory:
        async def user(self, email: str, password: str = "Password123!", role: str = "viewer", active: bool = True):
            async with session_factory() as db:
                user = await auth_service.create_user(db, email=email, password=password, role=role)
                user.is_active = active
                await db.commit()
                return user

        async def space(self, name: str = "Space", active: bool = True):
            async with session_factory() as db:
                space = Space(name=name, s3_bucket="test-bucket", is_active=active)
                db.add(space)
                await db.commit()
                return space

        async def member(self, space, user, role: str = "member", status: str = "active"):
            async with session_factory() as db:
                db.add(SpaceMember(space_id=space.id, user_id=user.id, role=role, status=status))
                await db.commit()

        async def session(self, space, user, messages=(("user", "Hello"), ("assistant", "Hi there"))):
            async with session_factory() as db:
                chat = ChatSession(space_id=space.id, user_id=user.id, title="Quarterly plan")
                db.add(chat)
                await db.flush()
                for role, content in messages:
                    db.add(
                        ChatMessage(
                            session_id=chat.id,
                            role=role,
                            content=content,
                            meta_payload={"internal": "s3://bucket/key"},
                            created_at=datetime.utcnow(),
                        )
                    )
                await db.commit()
                return chat

        async def execute(self, sql: str, **params):
            async with session_factory() as db:
                result = await db.execute(text(sql), params)
                await db.commit()
                return result

    return Factory()


def auth_headers(user, space=None) -> dict:
    headers = {"Authorization": f"Bearer {create_access_token(subject=user.id, scopes=[user.role])}"}
    if space is not None:
        headers["X-Space-Id"] = space.id
    return headers
