#!/usr/bin/env bash
# Consistent backup of TEIA staging: database, documents (object store), vectors (Qdrant) and global prompts.
#
#   TEIA_BACKUP_DEST=<target> ./backup.sh     create a set, copy it off-host, keep the 7 newest local sets
#   ./backup.sh --local-only                  create the set only (restore rehearsal)
#
# Consistency: stop-and-copy with an enforced quiesce (a few minutes of API downtime; run nightly).
#   1. wait until no document is being processed (the processing gate's advisory lock is free), refuse otherwise
#   2. stop the API: nothing writes to Postgres, the object store, Qdrant or the prompts file any more
#   3. record an inventory (row counts, Qdrant points, prompts hash) and pg_dump the database
#   4. stop Qdrant and the object store so their files are flushed and closed, then copy the volumes
#   5. start everything again and wait for health checks
# All four parts therefore describe the same moment. Live volume copies of SeaweedFS/Qdrant are never taken.
#
# Failure handling: an EXIT trap always restarts what this run stopped, waits for health, and prints the
# final state of every service. An incomplete set is renamed *.failed and never copied off-host.
# Exit codes: 0 OK; 1 backup failed, services running again; 3 backup failed or succeeded but services NOT healthy.
# Prints no secrets. Restore and rehearsal: BACKUP.md and restore.sh.
set -Eeuo pipefail
cd "$(dirname "$0")"
ENV_FILE=${TEIA_ENV_FILE:-teia-staging.env}
COMPOSE=(docker compose --env-file "$ENV_FILE" -f docker-compose.yml ${TEIA_COMPOSE_OVERRIDE:+-f "$TEIA_COMPOSE_OVERRIDE"})
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUT=backups/$STAMP
LOCAL_ONLY=0
[ "${1:-}" = "--local-only" ] && LOCAL_ONLY=1
QUIESCE_WAIT=${TEIA_BACKUP_QUIESCE_WAIT:-600}   # seconds to wait for an in-flight document to finish
LOCK_BASE=742000                                # src/modules/apis/v1/documents/processing_gate.py

STOPPED=()
COMPLETE=0
log() { echo "[$(date -u +%H:%M:%S)] $*"; }
die() { echo "FAIL: $*" >&2; exit 1; }

wait_healthy() {  # <service>...
  local s cid status deadline=$((SECONDS + 180))
  for s in "$@"; do
    while :; do
      cid=$("${COMPOSE[@]}" ps -q "$s" 2>/dev/null || true)
      status=$([ -n "$cid" ] && docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || echo missing)
      [ "$status" = healthy ] && break
      [ $SECONDS -ge $deadline ] && return 1
      sleep 3
    done
  done
}

finish() {
  local rc=$? unhealthy=() s i
  trap - EXIT
  if [ ${#STOPPED[@]} -gt 0 ]; then
    log "restarting what this run stopped"
    for ((i = ${#STOPPED[@]} - 1; i >= 0; i--)); do
      "${COMPOSE[@]}" start "${STOPPED[$i]}" >/dev/null 2>&1 || true
      wait_healthy "${STOPPED[$i]}" || true
    done
  fi
  echo "== service state after backup"
  for s in db qdrant objects api web; do
    cid=$("${COMPOSE[@]}" ps -q "$s" 2>/dev/null || true)
    st=$([ -n "$cid" ] && docker inspect -f '{{.State.Status}}/{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$cid" 2>/dev/null || echo absent)
    echo "   $s: $st"
    case "$st" in running/healthy) ;; *) unhealthy+=("$s:$st");; esac
  done
  if [ "$COMPLETE" != 1 ] && [ -d "$OUT" ]; then mv "$OUT" "$OUT.failed"; echo "incomplete set kept as $OUT.failed (not copied off-host)"; fi
  if [ ${#unhealthy[@]} -gt 0 ]; then
    echo "SERVICES NOT HEALTHY AFTER BACKUP: ${unhealthy[*]} — investigate now (docker compose ps / logs)" >&2
    exit 3
  fi
  [ "$rc" = 0 ] && echo "backup: OK ($OUT)" || echo "backup FAILED (exit $rc); all services are running and healthy again" >&2
  exit "$rc"
}

[ -f "$ENV_FILE" ] || die "$ENV_FILE missing"
[ "$LOCAL_ONLY" = 1 ] || [ -n "${TEIA_BACKUP_DEST:-}" ] || die "TEIA_BACKUP_DEST is not set (owner-provided off-host destination)"
for s in db qdrant objects api; do
  wait_healthy "$s" || die "service $s is not healthy; not starting a backup on a degraded stack"
done
trap finish EXIT

mkdir -p "$OUT"; chmod 700 backups "$OUT"
psql_db() { "${COMPOSE[@]}" exec -T db sh -c 'psql -X -At -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$0"' "$1"; }

log "quiesce: waiting for the document-processing gate to be free (max ${QUIESCE_WAIT}s)"
deadline=$((SECONDS + QUIESCE_WAIT))
until [ "$(psql_db "SELECT count(*) FROM pg_locks WHERE locktype = 'advisory' AND granted AND objid BETWEEN $LOCK_BASE AND $((LOCK_BASE + 99))")" = 0 ]; do
  [ $SECONDS -lt $deadline ] || die "a document is still being processed after ${QUIESCE_WAIT}s; backup not started"
  sleep 5
done

log "quiesce: stopping api (no writers from here on)"
STOPPED+=(api)
"${COMPOSE[@]}" stop -t 30 api >/dev/null

log "inventory (row counts, Qdrant points, prompts hash)"
"${COMPOSE[@]}" run --rm --no-deps -T api python - < tools/inventory.py > "$OUT/inventory.json"

log "database"
"${COMPOSE[@]}" exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom --no-owner' > "$OUT/db.dump"
"${COMPOSE[@]}" exec -T db pg_restore --list < "$OUT/db.dump" > /dev/null

log "stopping qdrant and objects (flush and close their files)"
STOPPED+=(objects qdrant)
"${COMPOSE[@]}" stop -t 60 qdrant objects >/dev/null

volume_tar() {  # <volume> <file>
  docker run --rm -v "$1":/data:ro -v "$PWD/$OUT":/out alpine:3.20 tar -C /data -czf "/out/$2" .
}
log "volumes: documents, vectors, prompts"
volume_tar teia-staging-objects objects.tar.gz
volume_tar teia-staging-qdrant qdrant.tar.gz
volume_tar teia-staging-prompts prompts.tar.gz

{
  echo "stamp=$STAMP"
  echo "commit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  echo "api_image=$(docker inspect -f '{{.Config.Image}}' "$("${COMPOSE[@]}" ps -aq api | head -n 1)" 2>/dev/null || echo unknown)"
  echo "method=stop-and-copy (api, qdrant, objects stopped; db dumped with no writers)"
} > "$OUT/MANIFEST"
( cd "$OUT" && sha256sum ./* > SHA256SUMS )
COMPLETE=1

log "restarting services"
for ((i = ${#STOPPED[@]} - 1; i >= 0; i--)); do
  "${COMPOSE[@]}" start "${STOPPED[$i]}" >/dev/null
  wait_healthy "${STOPPED[$i]}" || die "${STOPPED[$i]} did not become healthy after the backup"
done
STOPPED=()
log "set: $OUT ($(du -sh "$OUT" | cut -f1))"

if [ "$LOCAL_ONLY" = 0 ]; then
  log "copy off-host"
  rsync -a --partial "$OUT" "$TEIA_BACKUP_DEST/"
  ls -1d backups/*/ | grep -v '\.failed/$' | sort | head -n -7 | xargs -r rm -rf
fi
