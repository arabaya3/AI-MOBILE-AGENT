# TEIA staging — backup, restore and restore rehearsal

There is no backup destination yet. `backup.sh` won't copy anything until the owner sets `TEIA_BACKUP_DEST` to an off-host target, for example an SSH/rsync account on separate storage. None of this has run on the server.

## What a backup set contains

Each set is written to `backups/<UTC stamp>/` and holds:

| File | Content | How it is taken |
|---|---|---|
| `db.dump` | Postgres: users, spaces, conversations, citations, receipts, usage, invitations | `pg_dump --format=custom` with the API stopped; readability checked with `pg_restore --list` |
| `objects.tar.gz` | Documents: the SeaweedFS volume | copied after SeaweedFS is stopped |
| `qdrant.tar.gz` | Vectors: the Qdrant volume | copied after Qdrant is stopped |
| `prompts.tar.gz` | Global system prompts (`SYSTEM_PROMPTS_PATH` volume) | copied with the API stopped |
| `inventory.json` | Row counts, Qdrant point count and prompts SHA-256, recorded at the same moment | `tools/inventory.py` |
| `MANIFEST`, `SHA256SUMS` | Stamp, commit, API image and method; a checksum for every file | |

`teia-staging.env` is **not** in the set, because it holds secrets. Keep it in the owner's secret manager.

## Consistency: enforced stop-and-copy

`backup.sh` never copies a SeaweedFS or Qdrant volume while it is running. It works in this order:

1. **Wait for idle.** It waits until no document is being processed: the processing gate's Postgres advisory lock must be free. The wait is at most `TEIA_BACKUP_QUIESCE_WAIT` (600 s). If the lock is still held, the backup is refused and nothing is stopped.
2. **Stop the writer.** It stops the API, the only process that writes to the database, objects, vectors and prompts.
3. **Record and dump.** It records the inventory, then dumps the database.
4. **Stop and copy.** It stops Qdrant and SeaweedFS so their files are flushed and closed, then copies the three volumes.
5. **Restart.** It starts everything again and waits for each health check.

Because nothing can write between step 2 and step 5, the dump, the objects, the vectors and the prompts all describe the same moment.

Expected downtime is about 1.5 minutes (measured locally: 1 min 23 s, most of it the API restart). Schedule the backup at night, and tell pilot users about the window.

### Failure handling

- An EXIT trap always restarts whatever this run stopped, waits for health checks, and prints the final state of every service (`db: running/healthy`, …).
- An incomplete set is renamed `*.failed` and is never copied off-host.
- Exit codes:
  - `0`: OK.
  - `1`: the backup failed, but every service is running and healthy again.
  - `3`: the backup succeeded or failed, but **a service is not healthy afterwards**. Investigate at once.
- Local evidence:
  - a forced failure in the volume-copy step restored every service to `running/healthy` and left the set as `*.failed`;
  - a held processing lock made the run refuse after the wait limit, without stopping anything.

Schedule (owner, after approval), for example:

```
15 3 * * * cd /opt/teia-staging/deploy/teia-staging && TEIA_BACKUP_DEST=<target> ./backup.sh >> backups/backup.log 2>&1
```

Add an alert on a non-zero exit, for example through the cron mail or the monitoring the owner uses.

## Restore rehearsal (isolated): `restore.sh`

`restore/docker-compose.yml` defines a separate project, **`teia-restore`**:

- its own volumes `teia-restore-{pgdata,qdrant,objects,prompts}`;
- one `internal` network, `teia-restore-internal`: no internet, no edge network, so Caddy cannot reach it;
- no published ports and email off;
- it reuses the already-built API image.

Changing `-p` on the staging compose file is **not** enough for isolation, because that file pins network and volume names. That is why the rehearsal has its own file.

Guards, checked on every run before anything is created:

- **Isolation of the config.** The rendered config must have project `teia-restore`, no `teia-staging-*` volume or network name, no published ports, no external volume or network, and only the internal restore network.
- **Allowed targets.** Every target volume must be one of the four `teia-restore-*` names. `teia-staging-*` and any other name are refused (`assert_restore_target`).
- **No stale rehearsal.** The run refuses if `teia-restore-*` volumes already exist, so a stale rehearsal is not silently mixed in.
- **Checksums.** The set must pass `sha256sum -c`.

The restore then:

1. restores the database;
2. extracts the volumes;
3. starts the stack and waits for health;
4. verifies it against the backup-time inventory:
   - every table count;
   - every document object read back and its SHA-256 compared with `documents.file_hash`;
   - Qdrant point count;
   - prompts hash.

```bash
cd /opt/teia-staging/deploy/teia-staging
./backup.sh --local-only                          # or copy a set back from TEIA_BACKUP_DEST
./restore.sh backups/<stamp>                      # exit 0 only when everything matches
./restore.sh --cleanup                            # removes only the teia-restore stack and volumes
```

### Local demonstration (synthetic data, stub providers)

- **Staging stack.** Deployed with `deploy.sh`, then seeded:
  - 3 synthetic users, with the platform admin bootstrapped by `bootstrap-admin.sh`;
  - one space and 3 uploaded documents (txt, csv, md);
  - a conversation, a share link, and an edited global prompt.
- **Backup:** `backup.sh --local-only` produced a 787 KB set.
- **Restore:** `restore.sh` gave exit 0:
  - all 14 table counts matched;
  - documents: 3 of 3 objects SHA-256-verified;
  - Qdrant points: 180 of 180;
  - prompts hash matched.
- **Isolation:**
  - restore containers mounted only `teia-restore-*` volumes;
  - they were attached only to `teia-restore-internal`;
  - no ports were published, and there was no internet from the restore API;
  - the staging stack's inventory was unchanged.
- **Guards:**
  - a second run was refused (volumes exist);
  - overrides pointing a volume at `teia-staging-pgdata`, attaching `teia-staging-edge`, publishing a port, or using an unknown volume name were each refused before any action.

On the server, also check by hand in the rehearsal stack:
- sign in with a synthetic pilot account through `docker compose -f restore/docker-compose.yml exec api`;
- confirm that a past conversation still shows its saved citations.

Record the date, the set and the results. Rehearse before the pilot starts, then monthly.

## Restore into staging (real recovery)

Only after a successful rehearsal of the same set:

```bash
cd /opt/teia-staging/deploy/teia-staging
SET=backups/<stamp>; ( cd "$SET" && sha256sum -c SHA256SUMS )
C="docker compose --env-file teia-staging.env -f docker-compose.yml"
$C stop api web qdrant objects                    # no writers; volumes closed
$C exec -T db sh -c 'dropdb -U "$POSTGRES_USER" --if-exists "$POSTGRES_DB" && createdb -U "$POSTGRES_USER" "$POSTGRES_DB"'
$C exec -T db sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --exit-on-error' < "$SET/db.dump"
for v in objects qdrant prompts; do
  docker run --rm -v teia-staging-$v:/data -v "$PWD/$SET":/in:ro alpine:3.20 \
    sh -c "find /data -mindepth 1 -delete && tar -C /data -xzf /in/$v.tar.gz"
done
$C up -d && $C ps
$C exec -T api python - --verify-objects < tools/inventory.py   # compare with $SET/inventory.json
```

### Vectors without their backup: re-index

The documents and their extracted chunks live in Postgres and the object store, so Qdrant can be rebuilt:

1. Start with an empty Qdrant volume. The API recreates the collection.
2. For each `ready` document, call `POST /api/v1/documents/vectorize/{id}` as a space admin.
   - Do them one at a time; the processing gate allows one operation.
   - This calls the embedding provider again and costs tokens.
