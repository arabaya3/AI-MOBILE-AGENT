-- Durable document processing state and upload receipts for reconciliation (mobile Phase 3).
-- Idempotent. Apply per environment by the owner; never run automatically.
BEGIN;

ALTER TABLE documents ADD COLUMN IF NOT EXISTS state VARCHAR(16);
ALTER TABLE documents ADD COLUMN IF NOT EXISTS state_error VARCHAR(32);
ALTER TABLE documents ADD COLUMN IF NOT EXISTS state_updated_at TIMESTAMP WITHOUT TIME ZONE;

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

-- One receipt per accepted client upload ID (per space and uploader), duplicates included.
CREATE TABLE IF NOT EXISTS document_upload_receipts (
    id VARCHAR PRIMARY KEY,
    space_id VARCHAR NOT NULL,
    user_id VARCHAR NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    upload_id VARCHAR(64) NOT NULL,
    document_id VARCHAR NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    file_hash VARCHAR(64) NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT uq_upload_receipts_scope UNIQUE (space_id, user_id, upload_id)
);
CREATE INDEX IF NOT EXISTS ix_document_upload_receipts_space_id ON document_upload_receipts (space_id);
CREATE INDEX IF NOT EXISTS ix_document_upload_receipts_user_id ON document_upload_receipts (user_id);
CREATE INDEX IF NOT EXISTS ix_document_upload_receipts_document_id ON document_upload_receipts (document_id);

COMMIT;
