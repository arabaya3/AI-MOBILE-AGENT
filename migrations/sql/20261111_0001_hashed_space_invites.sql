-- Hashed, revocable space invitations (mobile Phase 5, closes S10).
-- Idempotent. Apply per environment by the owner; never run automatically.
--
-- Existing invitations: plaintext tokens were returned to inviters by the old API, so they are
-- treated as exposed. Pending ones are marked expired (admins can resend them, which issues a new
-- emailed token) and every plaintext token is cleared. Accepted/revoked history is kept.
BEGIN;

ALTER TABLE space_invites ALTER COLUMN token DROP NOT NULL;
ALTER TABLE space_invites ADD COLUMN IF NOT EXISTS token_hash VARCHAR(64);
ALTER TABLE space_invites ADD COLUMN IF NOT EXISTS send_count INTEGER NOT NULL DEFAULT 1;
ALTER TABLE space_invites ADD COLUMN IF NOT EXISTS last_sent_at TIMESTAMP WITHOUT TIME ZONE;
ALTER TABLE space_invites ADD COLUMN IF NOT EXISTS accepted_by_user_id VARCHAR REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE space_invites ADD COLUMN IF NOT EXISTS responded_at TIMESTAMP WITHOUT TIME ZONE;

UPDATE space_invites SET status = 'revoked' WHERE status = 'cancelled';
UPDATE space_invites
SET status = 'expired', expires_at = LEAST(COALESCE(expires_at, now() AT TIME ZONE 'utc'), now() AT TIME ZONE 'utc')
WHERE status = 'pending' AND token_hash IS NULL;
UPDATE space_invites SET token = NULL WHERE token IS NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_space_invite_token_hash') THEN
        ALTER TABLE space_invites ADD CONSTRAINT uq_space_invite_token_hash UNIQUE (token_hash);
    END IF;
END $$;

-- At most one open invitation per space and address; resending reuses it.
CREATE UNIQUE INDEX IF NOT EXISTS uq_space_invite_open_email
    ON space_invites (space_id, lower(email)) WHERE status = 'pending';

COMMIT;
