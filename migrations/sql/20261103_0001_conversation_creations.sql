-- Conversation-start ledger for conversation limits (mobile Phase 4 review).
-- Idempotent. Apply per environment by the owner; never run automatically.
--
-- Backfill: one 'backfill' row per existing conversation at its original created_at, so limits that
-- are already in effect keep counting the same conversations. Conversations deleted before this
-- migration cannot be recovered; the delete endpoint ships together with this ledger, so in practice
-- none exist. Branches created before the migration are counted like any other conversation.
BEGIN;

CREATE TABLE IF NOT EXISTS conversation_creations (
    id VARCHAR PRIMARY KEY,
    space_id VARCHAR NOT NULL,
    user_id VARCHAR NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id VARCHAR REFERENCES chat_sessions(id) ON DELETE SET NULL,
    kind VARCHAR(16) NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_conversation_creations_space_id ON conversation_creations (space_id);
CREATE INDEX IF NOT EXISTS ix_conversation_creations_user_id ON conversation_creations (user_id);
CREATE INDEX IF NOT EXISTS ix_conversation_creations_session_id ON conversation_creations (session_id);
CREATE INDEX IF NOT EXISTS ix_conversation_creations_created_at ON conversation_creations (created_at);

INSERT INTO conversation_creations (id, space_id, user_id, session_id, kind, created_at)
SELECT 'backfill-' || s.id, s.space_id, s.user_id, s.id, 'backfill', s.created_at
FROM chat_sessions s
WHERE s.space_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM conversation_creations c WHERE c.session_id = s.id);

COMMIT;
