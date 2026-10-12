-- At most one pending join request per (space, user); makes join requests idempotent under concurrency.
-- Apply manually: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f migrations/sql/20261012_0001_unique_pending_join_request.sql

BEGIN;

-- Existing duplicates would block the index: keep the oldest pending request, close the rest.
WITH ranked AS (
    SELECT id, row_number() OVER (PARTITION BY space_id, user_id ORDER BY created_at, id) AS rn
    FROM space_requests
    WHERE type = 'join' AND status = 'pending'
)
UPDATE space_requests r
SET status = 'declined',
    review_note = 'Duplicate pending join request closed by migration 20261012_0001',
    reviewed_at = now()
FROM ranked
WHERE r.id = ranked.id AND ranked.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS uq_space_requests_pending_join
    ON space_requests (space_id, user_id)
    WHERE type = 'join' AND status = 'pending';

COMMIT;
