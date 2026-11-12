#!/usr/bin/env bash
# Restore rehearsal: restores a backup set into the separate teia-restore stack and verifies it.
# Never writes to teia-staging-* volumes; never attaches to the edge network; publishes no port.
#
#   ./restore.sh <backup-set-dir>      restore and verify (refuses if teia-restore-* volumes already exist)
#   ./restore.sh --cleanup             stop the rehearsal stack and delete ONLY teia-restore-* volumes
#
# Verification compares the restored stack with the inventory recorded at backup time:
# row counts, Qdrant points, prompts hash; and reads back every document object, comparing its SHA-256
# with documents.file_hash. Exit 0 only when everything matches.
set -Eeuo pipefail
cd "$(dirname "$0")"
ENV_FILE=${TEIA_ENV_FILE:-teia-staging.env}
export TEIA_ENV_FILE=$PWD/$ENV_FILE
RC=(docker compose --env-file "$ENV_FILE" -f restore/docker-compose.yml ${TEIA_RESTORE_OVERRIDE:+-f "$TEIA_RESTORE_OVERRIDE"})
VOLUMES=(teia-restore-pgdata teia-restore-qdrant teia-restore-objects teia-restore-prompts)
die() { echo "FAIL: $*" >&2; exit 1; }
log() { echo "[$(date -u +%H:%M:%S)] $*"; }

# The only volumes this script may write to. Anything else (above all teia-staging-*) is refused.
assert_restore_target() {
  case "$1" in
    teia-staging-*) die "refusing to restore into staging volume '$1'";;
    teia-restore-pgdata|teia-restore-qdrant|teia-restore-objects|teia-restore-prompts) ;;
    *) die "refusing unknown restore target volume '$1'";;
  esac
}

# The rendered rehearsal config must be isolated from staging: checked on every run, not assumed.
assert_isolated_config() {
  local cfg
  cfg=$("${RC[@]}" config) || die "restore compose config does not render"
  printf '%s\n' "$cfg" | grep -qx 'name: teia-restore' || die "project name is not teia-restore"
  printf '%s\n' "$cfg" | grep -q 'teia-staging-' && die "restore config references teia-staging-* resources"
  printf '%s\n' "$cfg" | grep -qE '^\s+(ports|published):' && die "restore config publishes ports"
  printf '%s\n' "$cfg" | grep -qE '^\s+external: true' && die "restore config uses an external network or volume"
  local v
  for v in $(printf '%s\n' "$cfg" | awk '/^volumes:/{f=1;next} f&&/^[^ ]/{f=0} f&&/^    name:/{print $2}'); do
    assert_restore_target "$v"
  done
  [ "$(printf '%s\n' "$cfg" | awk '/^networks:/{f=1;next} f&&/^[^ ]/{f=0} f&&/^    name:/{print $2}')" = teia-restore-internal ] \
    || die "restore config must use only the teia-restore-internal network"
  printf '%s\n' "$cfg" | awk '/^networks:/{f=1;next} f&&/^[^ ]/{f=0} f' | grep -q 'internal: true' || die "restore network is not internal"
}

wait_healthy() {
  local s cid st deadline=$((SECONDS + 240))
  for s in "$@"; do
    until cid=$("${RC[@]}" ps -q "$s") && [ -n "$cid" ] && st=$(docker inspect -f '{{.State.Health.Status}}' "$cid") && [ "$st" = healthy ]; do
      [ $SECONDS -lt $deadline ] || die "$s not healthy (${st:-absent})"
      sleep 3
    done
  done
}

if [ "${1:-}" = --cleanup ]; then
  assert_isolated_config
  "${RC[@]}" down --remove-orphans
  for v in "${VOLUMES[@]}"; do assert_restore_target "$v"; docker volume rm "$v" >/dev/null 2>&1 || true; done
  echo "cleanup: teia-restore stack and teia-restore-* volumes removed (teia-staging untouched)"
  exit 0
fi

SET=${1:?usage: $0 <backup-set-dir> | --cleanup}
[ -f "$ENV_FILE" ] || die "$ENV_FILE missing"
for f in db.dump objects.tar.gz qdrant.tar.gz prompts.tar.gz inventory.json MANIFEST SHA256SUMS; do
  [ -f "$SET/$f" ] || die "$SET/$f missing"
done
( cd "$SET" && sha256sum -c --quiet SHA256SUMS ) || die "checksum mismatch in $SET"
assert_isolated_config
for v in "${VOLUMES[@]}"; do
  docker volume inspect "$v" >/dev/null 2>&1 && die "volume $v already exists (previous rehearsal?); run $0 --cleanup first"
done
log "set $SET verified; restoring into teia-restore (isolated)"

SETP=$(cd "$SET" && pwd); command -v cygpath >/dev/null && SETP=$(cygpath -m "$SETP")
for pair in objects:objects qdrant:qdrant prompts:prompts; do
  v=teia-restore-${pair%%:*}; assert_restore_target "$v"
  docker volume create --label teia.restore=1 "$v" >/dev/null
  MSYS_NO_PATHCONV=1 docker run --rm -v "$v":/data -v "$SETP":/in:ro alpine:3.20 tar -C /data -xzf "/in/${pair#*:}.tar.gz"
done
assert_restore_target teia-restore-pgdata
docker volume create --label teia.restore=1 teia-restore-pgdata >/dev/null

log "database"
"${RC[@]}" up -d db
wait_healthy db
"${RC[@]}" exec -T db sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --exit-on-error' < "$SET/db.dump"

log "object store, vector store, api"
"${RC[@]}" up -d objects qdrant
wait_healthy objects qdrant
"${RC[@]}" up -d api
wait_healthy api

log "verification"
"${RC[@]}" exec -T api python - --verify-objects < tools/inventory.py > "$SET/restored-inventory.json"
TOOLSP=$PWD/tools; command -v cygpath >/dev/null && TOOLSP=$(cygpath -m "$TOOLSP")
MSYS_NO_PATHCONV=1 docker run --rm --network none -v "$SETP":/in:ro -v "$TOOLSP":/tools:ro "teia-staging-api:${TEIA_STAGING_TAG:-local}" \
  python /tools/compare_inventory.py /in/inventory.json /in/restored-inventory.json \
  || die "restored data does not match the backup inventory (stack left running for inspection; $0 --cleanup removes it)"
echo "restore rehearsal: OK — teia-restore matches $SET. Remove with: $0 --cleanup"
