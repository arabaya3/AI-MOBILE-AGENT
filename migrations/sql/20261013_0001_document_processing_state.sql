-- Durable document processing state and upload reconciliation (mobile Phase 3).
-- Idempotent. Apply per environment by the owner; never run automatically.
BEGIN;

ALTER TABLE documents ADD COLUMN IF NOT EXISTS state VARCHAR(16);
ALTER TABLE documents ADD COLUMN IF NOT EXISTS state_error VARCHAR(32);
ALTER TABLE documents ADD COLUMN IF NOT EXISTS state_updated_at TIMESTAMP WITHOUT TIME ZONE;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS client_upload_id VARCHAR(64);

-- Existing rows: completed documents with chunks were indexed by the web upload-and-vectorize flow.
UPDATE documents
SET state = CASE
        WHEN status = 'completed' AND COALESCE(chunks_count, 0) > 0 THEN 'ready'
        ELSE 'failed'
    END,
    state_error = CASE
        WHEN status = 'completed' AND COALESCE(chunks_count, 0) > 0 THEN NULL
        WHEN status = 'completed' THEN 'no_text'
        WHEN status = 'failed' THEN 'processing_failed'
        ELSE 'interrupted'
    END,
    state_updated_at = COALESCE(processed_at, uploaded_at, now())
WHERE state IS NULL;

ALTER TABLE documents ALTER COLUMN state SET DEFAULT 'uploaded';
ALTER TABLE documents ALTER COLUMN state SET NOT NULL;
ALTER TABLE documents ALTER COLUMN state_updated_at SET DEFAULT now();
ALTER TABLE documents ALTER COLUMN state_updated_at SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_documents_client_upload
    ON documents (space_id, uploaded_by_user_id, client_upload_id)
    WHERE client_upload_id IS NOT NULL;

COMMIT;
