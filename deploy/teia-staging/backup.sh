#!/usr/bin/env bash
# Off-host backup of TEIA staging: database, documents (object store), vector store and global prompts.
# Runs on the server from deploy/teia-staging. Writes a dated set under ./backups/, then copies it to
# TEIA_BACKUP_DEST (owner-provided rsync/ssh target, e.g. user@host:/path). Refuses to run without it.
#
#   TEIA_BACKUP_DEST=<target> ./backup.sh          # create + copy + keep the last 7 local sets
#   ./backup.sh --local-only                       # create the set only (for a restore rehearsal)
# Prints no secrets. Restores: see BACKUP.md.
set -euo pipefail
cd "$(dirname "$0")"
ENV_FILE=teia-staging.env
COMPOSE=(docker compose --env-file "$ENV_FILE" -f docker-compose.yml)
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUT=backups/$STAMP
LOCAL_ONLY=0
[ "${1:-}" = "--local-only" ] && LOCAL_ONLY=1

die() { echo "FAIL: $*" >&2; exit 1; }
[ -f "$ENV_FILE" ] || die "$ENV_FILE missing"
[ "$LOCAL_ONLY" = 1 ] || [ -n "${TEIA_BACKUP_DEST:-}" ] || die "TEIA_BACKUP_DEST is not set (owner-provided off-host destination)"
mkdir -p "$OUT"
chmod 700 backups "$OUT"

volume_tar() {  # <volume> <file>
  docker run --rm -v "$1":/data:ro -v "$PWD/$OUT":/out alpine:3.20 tar -C /data -czf "/out/$2" .
}

echo "== database"
"${COMPOSE[@]}" exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom --no-owner' > "$OUT/db.dump"
"${COMPOSE[@]}" exec -T db pg_restore --list < "$OUT/db.dump" > /dev/null   # readable archive

echo "== documents (object store volume)"
# Uploads are processed one at a time; run outside upload activity (nightly) for a consistent copy.
volume_tar teia-staging-objects objects.tar.gz

echo "== vector store (Qdrant volume; can also be rebuilt by re-indexing, see BACKUP.md)"
volume_tar teia-staging-qdrant qdrant.tar.gz

echo "== global prompts"
volume_tar teia-staging-prompts prompts.tar.gz

( cd "$OUT" && sha256sum ./* > SHA256SUMS )
echo "set: $OUT ($(du -sh "$OUT" | cut -f1))"

if [ "$LOCAL_ONLY" = 0 ]; then
  echo "== copy off-host"
  rsync -a --partial "$OUT" "$TEIA_BACKUP_DEST/"
  # Keep the 7 newest local sets; the destination keeps its own retention.
  ls -1d backups/*/ | sort | head -n -7 | xargs -r rm -rf
fi
echo "backup: OK"
