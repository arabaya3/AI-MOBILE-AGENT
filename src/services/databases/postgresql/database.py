"""Database connection and session management."""

from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.exc import InvalidRequestError
from sqlalchemy import text
from sqlalchemy.orm import sessionmaker

from src.core.settings.config import settings
from .models import Base

engine = create_async_engine(settings.database_url, echo=False)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def init_db() -> None:
    """Initialize database tables."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

        # Minimal in-place migrations (create_all does not add columns to existing tables).
        # Keep these idempotent for local/dev environments.
        await conn.execute(text("ALTER TABLE IF EXISTS documents ADD COLUMN IF NOT EXISTS space_id VARCHAR"))
        await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_documents_space_id ON documents(space_id)"))
        await conn.execute(text("ALTER TABLE IF EXISTS documents ADD COLUMN IF NOT EXISTS uploaded_by_user_id VARCHAR"))
        await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_documents_uploaded_by_user_id ON documents(uploaded_by_user_id)"))
        await conn.execute(text("ALTER TABLE IF EXISTS documents ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT FALSE"))

        # Allow the same file hash across different spaces.
        # Older schema used a global unique constraint on file_hash.
        await conn.execute(text("ALTER TABLE IF EXISTS documents DROP CONSTRAINT IF EXISTS documents_file_hash_key"))
        await conn.execute(text("DROP INDEX IF EXISTS documents_file_hash_key"))
        await conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS uq_documents_space_hash ON documents(space_id, file_hash)"))

        await conn.execute(text("ALTER TABLE IF EXISTS chat_sessions ADD COLUMN IF NOT EXISTS space_id VARCHAR"))
        await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_chat_sessions_space_id ON chat_sessions(space_id)"))

        await conn.execute(text("ALTER TABLE IF EXISTS llm_usage_events ADD COLUMN IF NOT EXISTS space_id VARCHAR"))
        await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_llm_usage_events_space_id ON llm_usage_events(space_id)"))

        await conn.execute(text("ALTER TABLE IF EXISTS llm_usage_events ADD COLUMN IF NOT EXISTS request_count INTEGER DEFAULT 1"))

        await conn.execute(text("ALTER TABLE IF EXISTS user_document_permissions ADD COLUMN IF NOT EXISTS space_id VARCHAR"))
        await conn.execute(text("CREATE INDEX IF NOT EXISTS ix_user_document_permissions_space_id ON user_document_permissions(space_id)"))

        await conn.execute(text("ALTER TABLE IF EXISTS space_members ADD COLUMN IF NOT EXISTS can_upload_documents BOOLEAN DEFAULT FALSE"))

        await conn.execute(text("ALTER TABLE IF EXISTS spaces ADD COLUMN IF NOT EXISTS allowed_tools JSON"))
        await conn.execute(text("ALTER TABLE IF EXISTS spaces ADD COLUMN IF NOT EXISTS daily_tool_request_limit INTEGER"))
        await conn.execute(text("ALTER TABLE IF EXISTS spaces ADD COLUMN IF NOT EXISTS monthly_tool_request_limit INTEGER"))

        await conn.execute(text("ALTER TABLE IF EXISTS space_members ADD COLUMN IF NOT EXISTS allowed_tools JSON"))
        await conn.execute(text("ALTER TABLE IF EXISTS space_members ADD COLUMN IF NOT EXISTS daily_tool_request_limit INTEGER"))
        await conn.execute(text("ALTER TABLE IF EXISTS space_members ADD COLUMN IF NOT EXISTS monthly_tool_request_limit INTEGER"))

        await conn.execute(text("ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE"))
        await conn.execute(text("ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS custom_system_prompts JSON"))
        await conn.execute(text("ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS daily_request_limit_override INTEGER"))
        await conn.execute(text("ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS monthly_request_limit_override INTEGER"))
        await conn.execute(text("ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS allowed_models_override JSON"))



async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Get database session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            try:
                await session.commit()
            except InvalidRequestError:
                # Streaming handlers may close the session early on disconnect.
                pass
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()