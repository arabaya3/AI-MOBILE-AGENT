# TEIA staging — backup and recovery

No backup destination exists yet; `backup.sh` refuses to copy until the owner sets `TEIA_BACKUP_DEST` to an off-host target (for example an SSH/rsync account on separate storage). Nothing here has run on the server.

## What is backed up

| Item | Source | Method | Notes |
|---|---|---|---|
| Database (users, spaces, conversations, citations, receipts, usage, invitations) | `teia-staging-db` | `pg_dump --format=custom`, checked with `pg_restore --list` | consistent online snapshot |
| Documents (original files) | volume `teia-staging-objects` (SeaweedFS) | volume tar | run outside upload activity (nightly) |
| Vector store | volume `teia-staging-qdrant` | volume tar | can instead be rebuilt from the documents (below) |
| Global system prompts | volume `teia-staging-prompts` (`SYSTEM_PROMPTS_PATH`) | volume tar | edited by super admins on the web |
| Configuration | `teia-staging.env` | **not** in the set (secrets) | kept in the owner's secret manager |

Schedule (owner, after approval): nightly via cron, for example `15 3 * * * cd /opt/teia-staging/deploy/teia-staging && TEIA_BACKUP_DEST=<target> ./backup.sh >> backups/backup.log 2>&1`.

## Restore (into the staging project)

```bash
cd /opt/teia-staging/deploy/teia-staging
SET=backups/<stamp>                      # or copy a set back from TEIA_BACKUP_DEST
( cd "$SET" && sha256sum -c SHA256SUMS )
C="docker compose --env-file teia-staging.env -f docker-compose.yml"
$C stop api                              # no writes during restore

# Database: replace the schema contents
$C exec -T db sh -c 'dropdb -U "$POSTGRES_USER" --if-exists "$POSTGRES_DB" && createdb -U "$POSTGRES_USER" "$POSTGRES_DB"'
$C exec -T db sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner' < "$SET/db.dump"

# Volumes (documents, vectors, prompts): stop their users, replace contents, start again
$C stop objects qdrant
for v in objects qdrant prompts; do
  docker run --rm -v teia-staging-$v:/data -v "$PWD/$SET":/in:ro alpine:3.20 \
    sh -c "find /data -mindepth 1 -delete && tar -C /data -xzf /in/$v.tar.gz"
done
$C up -d
```

### Vector store without its backup: re-index

The documents and their extracted chunks live in Postgres and the object store, so Qdrant can be rebuilt:
1. Start with an empty `teia-staging-qdrant` volume; the API recreates the collection.
2. For each document in state `ready`, call `POST /api/v1/documents/vectorize/{id}` as a space admin (one at a time; the processing gate allows one operation). This calls the embedding provider again and costs tokens.

## Restore rehearsal (before the pilot starts, then monthly)

1. `./backup.sh --local-only` on the server.
2. Restore that set into a **separate** throwaway project on the same host (`docker compose -p teia-restore-test ...` with its own volume names and no Caddy attachment), or on a workstation.
3. Recovery checks:
   - `SELECT count(*)` of `users`, `spaces`, `chat_sessions`, `documents`, `generation_attempts`, `conversation_creations` match the source;
   - sign in with a synthetic pilot account; a past conversation shows its saved citations;
   - download one document through the API (object store restored);
   - ask a question that needs a document (vectors restored or re-indexed);
   - the global prompts match the source file (`sha256sum`).
4. Delete the throwaway project and its volumes. Record date, set and results.
