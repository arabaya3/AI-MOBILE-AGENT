-- Generation attempt ledger and request de-duplication (mobile Phase 4).
-- Idempotent. Apply per environment by the owner; never run automatically.
BEGIN;

CREATE TABLE IF NOT EXISTS generation_attempts (
    id VARCHAR PRIMARY KEY,
    space_id VARCHAR NOT NULL,
    user_id VARCHAR NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id VARCHAR REFERENCES chat_sessions(id) ON DELETE SET NULL,
    user_message_id VARCHAR,
    endpoint VARCHAR(64) NOT NULL,
    model VARCHAR,
    outcome VARCHAR(16) NOT NULL DEFAULT 'started',
    usage_state VARCHAR(16) NOT NULL DEFAULT 'unknown',
    input_tokens INTEGER,
    output_tokens INTEGER,
    total_tokens INTEGER,
    error_code VARCHAR(32),
    usage_event_id VARCHAR UNIQUE REFERENCES llm_usage_events(id) ON DELETE SET NULL,
    started_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    finished_at TIMESTAMP WITHOUT TIME ZONE
);
CREATE INDEX IF NOT EXISTS ix_generation_attempts_space_id ON generation_attempts (space_id);
CREATE INDEX IF NOT EXISTS ix_generation_attempts_user_id ON generation_attempts (user_id);
CREATE INDEX IF NOT EXISTS ix_generation_attempts_session_id ON generation_attempts (session_id);
CREATE INDEX IF NOT EXISTS ix_generation_attempts_started_at ON generation_attempts (started_at);

ALTER TABLE space_requests ADD COLUMN IF NOT EXISTS dedupe_key VARCHAR(200);

-- Existing duplicate pending requests cannot be keyed without guessing; only new requests get a key.
CREATE UNIQUE INDEX IF NOT EXISTS uq_space_requests_pending_key
    ON space_requests (space_id, user_id, dedupe_key)
    WHERE dedupe_key IS NOT NULL AND status = 'pending';

COMMIT;
