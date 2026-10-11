"""Database models."""

from datetime import datetime
from uuid import uuid4

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Float,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()


class Document(Base):
    """Document metadata and processing results."""

    __tablename__ = "documents"
    __table_args__ = (UniqueConstraint("space_id", "file_hash", name="uq_documents_space_hash"),)

    id = Column(String, primary_key=True)
    space_id = Column(String, nullable=True, index=True)
    filename = Column(String, nullable=False)
    file_type = Column(String, nullable=False)
    file_size = Column(Integer, nullable=False)
    file_hash = Column(String, nullable=False)
    s3_url = Column(String, nullable=False)
    status = Column(String, nullable=False)
    chunks_count = Column(Integer, default=0)
    chunks_data = Column(JSON, default=list)
    processing_time = Column(Integer, nullable=True)
    error_message = Column(Text, nullable=True)
    uploaded_by_user_id = Column(String, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    is_hidden = Column(Boolean, default=False, nullable=False)
    uploaded_at = Column(DateTime, default=datetime.utcnow)
    processed_at = Column(DateTime, nullable=True)


class User(Base):
    """Application user."""

    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    role = Column(String, default="viewer", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    email_verified = Column(Boolean, default=False, nullable=False)
    custom_system_prompts = Column(JSON, nullable=True)
    # Core identity
    first_name = Column(String(100), nullable=True)
    last_name = Column(String(100), nullable=True)
    date_of_birth = Column(Date, nullable=True)
    phone_number = Column(String(30), nullable=True)
    country = Column(String(80), nullable=True)
    # Professional context
    job_title = Column(String(120), nullable=True)
    company = Column(String(150), nullable=True)
    # Personalisation profile — drives AI system-prompt injection
    industry = Column(String(120), nullable=True)
    preferred_language = Column(String(10), nullable=True)
    # Admin overrides to standard policy
    daily_request_limit_override = Column(Integer, nullable=True)
    monthly_request_limit_override = Column(Integer, nullable=True)
    allowed_models_override = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class UserDocumentPermission(Base):
    """Mapping between users and documents they may access."""

    __tablename__ = "user_document_permissions"
    __table_args__ = (UniqueConstraint("user_id", "document_id", name="uq_user_document"),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    space_id = Column(String, nullable=True, index=True)
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    document_id = Column(String, ForeignKey("documents.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class PasswordResetToken(Base):
    """Password reset token storage."""

    __tablename__ = "password_reset_tokens"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    token_hash = Column(String, unique=True, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    used = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class ChatSession(Base):
    """Conversation container for chat interactions."""

    __tablename__ = "chat_sessions"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    space_id = Column(String, nullable=True, index=True)
    user_id = Column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title = Column(String, nullable=True)
    # Langfuse trace linkage (one trace per chat session).
    langfuse_trace_id = Column(String, nullable=True, index=True)
    langfuse_root_span_id = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class ChatMessage(Base):
    """Persisted chat messages with lightweight metadata."""

    __tablename__ = "chat_messages"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    session_id = Column(
        String,
        ForeignKey("chat_sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    role = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    meta_payload = Column(JSON, default=dict)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class ChatMessageReaction(Base):
    """User feedback on assistant messages."""

    __tablename__ = "chat_message_reactions"
    __table_args__ = (UniqueConstraint("user_id", "message_id", name="uq_user_message_reaction"),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    message_id = Column(String, ForeignKey("chat_messages.id", ondelete="CASCADE"), nullable=False, index=True)
    reaction = Column(String, nullable=False)  # up | down
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class LLMUsageEvent(Base):
    """Ledger of LLM usage for billing/analytics."""

    __tablename__ = "llm_usage_events"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    space_id = Column(String, nullable=True, index=True)
    user_id = Column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    session_id = Column(
        String,
        ForeignKey("chat_sessions.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    endpoint = Column(String, nullable=False)
    model = Column(String, nullable=True)
    request_count = Column(Integer, default=1, nullable=False)
    input_tokens = Column(Integer, default=0, nullable=False)
    output_tokens = Column(Integer, default=0, nullable=False)
    total_tokens = Column(Integer, default=0, nullable=False)
    cost_usd = Column(Float, nullable=True)
    meta_payload = Column(JSON, default=dict)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class Space(Base):
    """Tenant workspace ("space") container."""

    __tablename__ = "spaces"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    name = Column(String, nullable=False)
    s3_bucket = Column(String, nullable=False)
    created_by_user_id = Column(String, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    is_active = Column(Boolean, default=True, nullable=False)
    allowed_models = Column(JSON, default=list)
    allowed_tools = Column(JSON, default=list)
    daily_token_limit = Column(Integer, nullable=True)
    monthly_token_limit = Column(Integer, nullable=True)
    daily_request_limit = Column(Integer, nullable=True)
    monthly_request_limit = Column(Integer, nullable=True)
    daily_tool_request_limit = Column(Integer, nullable=True)
    monthly_tool_request_limit = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class SpaceMember(Base):
    """User membership in a space with per-space role and optional overrides."""

    __tablename__ = "space_members"
    __table_args__ = (UniqueConstraint("space_id", "user_id", name="uq_space_member"),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    space_id = Column(String, ForeignKey("spaces.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    role = Column(String, default="member", nullable=False)  # admin | member
    status = Column(String, default="active", nullable=False)  # active | pending | revoked
    can_upload_documents = Column(Boolean, default=False, nullable=False)
    allowed_models = Column(JSON, nullable=True)  # override
    allowed_tools = Column(JSON, nullable=True)  # override
    daily_token_limit = Column(Integer, nullable=True)  # override
    monthly_token_limit = Column(Integer, nullable=True)  # override
    daily_request_limit = Column(Integer, nullable=True)  # override
    monthly_request_limit = Column(Integer, nullable=True)  # override
    daily_tool_request_limit = Column(Integer, nullable=True)  # override
    monthly_tool_request_limit = Column(Integer, nullable=True)  # override
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class SpaceInvite(Base):
    """Email-based invite into a space."""

    __tablename__ = "space_invites"
    __table_args__ = (UniqueConstraint("token", name="uq_space_invite_token"),)

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    space_id = Column(String, ForeignKey("spaces.id", ondelete="CASCADE"), nullable=False, index=True)
    email = Column(String, nullable=False, index=True)
    invited_by_user_id = Column(String, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    token = Column(String, nullable=False)
    status = Column(String, default="pending", nullable=False)  # pending | accepted | cancelled | expired
    expires_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class SpaceRequest(Base):
    """User requests inside a space that admins can approve/decline."""

    __tablename__ = "space_requests"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    space_id = Column(String, ForeignKey("spaces.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    type = Column(String, nullable=False)  # join | model_access | quota_change | other
    payload = Column(JSON, default=dict)
    status = Column(String, default="pending", nullable=False)  # pending | approved | declined
    reviewed_by_user_id = Column(String, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    review_note = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    reviewed_at = Column(DateTime, nullable=True)


class Notification(Base):
    """User notifications for system events."""

    __tablename__ = "notifications"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    space_id = Column(String, ForeignKey("spaces.id", ondelete="CASCADE"), nullable=True, index=True)
    type = Column(String, nullable=False)  # request_approved | request_declined | policy_updated | space_invite | model_access_granted | quota_warning | system_message
    title = Column(String, nullable=False)
    message = Column(Text, nullable=False)
    link = Column(String, nullable=True)  # Optional link to related resource
    notification_metadata = Column(JSON, default=dict)  # Additional context (renamed from metadata to avoid SQLAlchemy conflict)
    read = Column(Boolean, default=False, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)


class EmailVerification(Base):
    """Email verification tokens."""

    __tablename__ = "email_verifications"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    email = Column(String, nullable=False)
    token_hash = Column(String, unique=True, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    verified = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class UserRequest(Base):
    """User requests for quota or model access."""

    __tablename__ = "user_requests"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    request_type = Column(String, nullable=False)  # 'quota_increase' | 'model_access'
    status = Column(String, default="pending", nullable=False)  # pending | approved | rejected
    payload = Column(JSON, default=dict)  # e.g. {"requested_model": "gpt-4", "reason": "..."}
    admin_response = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

