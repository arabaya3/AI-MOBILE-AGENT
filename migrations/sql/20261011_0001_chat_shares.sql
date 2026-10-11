-- Revocable, expiring conversation share links (replaces session-id sharing).
-- Apply manually: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f migrations/sql/20261011_0001_chat_shares.sql

BEGIN;

CREATE TABLE IF NOT EXISTS chat_shares (
    id VARCHAR PRIMARY KEY,
    session_id VARCHAR NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
    space_id VARCHAR NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    created_by_user_id VARCHAR NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    revoked_at TIMESTAMP WITHOUT TIME ZONE
);

CREATE INDEX IF NOT EXISTS ix_chat_shares_session_id ON chat_shares (session_id);
CREATE INDEX IF NOT EXISTS ix_chat_shares_space_id ON chat_shares (space_id);
CREATE INDEX IF NOT EXISTS ix_chat_shares_created_by_user_id ON chat_shares (created_by_user_id);

-- Reset tokens issued by the previous implementation were returned in API responses.
UPDATE password_reset_tokens SET used = TRUE WHERE used = FALSE;

COMMIT;
