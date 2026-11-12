#!/usr/bin/env bash
# TEIA staging deployment up to, and NOT including, edge exposure. Fail-fast: the first failing step stops
# the run, explains what state TEIA is in, and no edge marker is written, so the Caddy step (which checks
# the marker) cannot proceed. Changes only teia-staging-* containers, networks and volumes.
#
#   ./deploy.sh                       build images on this host (bounded, one at a time) and deploy
#   ./deploy.sh --images-prebuilt     use teia-staging-{api,web}:<commit> already loaded (docker load)
#
# Steps: validate config -> clean reviewed checkout -> host preflight -> images -> data services ->
# api (creates the schema) -> SQL migrations in name order (each file is one BEGIN..COMMIT transaction),
# psql ON_ERROR_STOP, first failure stops everything -> web ->
# internal smoke -> marker .edge-ready-<commit>. Then follow caddy/README.md (separately approved).
set -Eeuo pipefail
cd "$(dirname "$0")"
ENV_FILE=${TEIA_ENV_FILE:-teia-staging.env}
COMPOSE=(docker compose --env-file "$ENV_FILE" -f docker-compose.yml ${TEIA_COMPOSE_OVERRIDE:+-f "$TEIA_COMPOSE_OVERRIDE"})
PREBUILT=0; [ "${1:-}" = --images-prebuilt ] && PREBUILT=1
MIGRATIONS_DIR=../../migrations/sql
STEP=start

on_error() {
  local rc=$?
  trap - ERR
  echo >&2
  echo "DEPLOYMENT STOPPED at step '$STEP' (exit $rc). The edge was NOT changed: no .edge-ready marker." >&2
  case "$STEP" in
    migrations:*)
      echo "Stopping api and web so a partially migrated schema is not served." >&2
      "${COMPOSE[@]}" stop api web >/dev/null 2>&1 || true
      echo "The failed migration file is one transaction and was rolled back; earlier files are committed (they are idempotent)." >&2
      echo "Fix the cause, then re-run ./deploy.sh, or restore the pre-deploy backup (BACKUP.md)." >&2;;
  esac
  echo "TEIA state:" >&2
  "${COMPOSE[@]}" ps --format '   {{.Service}}: {{.State}} {{.Health}}' >&2 2>/dev/null || true
  exit "$rc"
}
trap on_error ERR
step() { STEP=$1; echo; echo "== $1"; }

wait_healthy() {  # <service>...
  local s cid st deadline=$((SECONDS + 240))
  for s in "$@"; do
    until cid=$("${COMPOSE[@]}" ps -q "$s") && [ -n "$cid" ] && st=$(docker inspect -f '{{.State.Health.Status}}' "$cid") && [ "$st" = healthy ]; do
      [ $SECONDS -lt $deadline ] || { echo "$s not healthy after 240 s (${st:-absent})" >&2; return 1; }
      sleep 3
    done
    echo "   $s healthy"
  done
}

step validate
./validate.sh

step checkout
git diff --quiet HEAD -- ../.. ':(exclude)Front-End/package-lock.json' || { echo "working tree differs from the reviewed commit" >&2; false; }
TAG=$(git rev-parse --short HEAD)
export TEIA_STAGING_TAG=$TAG
echo "   commit $TAG"
rm -f .edge-ready-*

step preflight
if [ "${TEIA_SKIP_HOST_PREFLIGHT:-0}" = 1 ]; then echo "   skipped (TEIA_SKIP_HOST_PREFLIGHT=1; local rehearsal only)"; else
  host/capacity-check.sh preflight
  [ -f "${TEIA_CAPACITY_STATE:-/var/lib/teia-staging-capacity}/baseline" ] || host/capacity-check.sh baseline
fi

step images
if [ "$PREBUILT" = 1 ]; then
  docker image inspect "teia-staging-api:$TAG" "teia-staging-web:$TAG" >/dev/null
  echo "   using prebuilt teia-staging-api:$TAG and teia-staging-web:$TAG"
else
  # Bounded on-host build: one image at a time, lowest CPU/IO priority, memory re-checked before each.
  for s in api web; do
    [ "${TEIA_SKIP_HOST_PREFLIGHT:-0}" = 1 ] || host/capacity-check.sh preflight >/dev/null
    LOWPRIO=(nice -n 19); command -v ionice >/dev/null && LOWPRIO+=(ionice -c3)
    COMPOSE_PARALLEL_LIMIT=1 "${LOWPRIO[@]}" "${COMPOSE[@]}" build "$s" 2>&1 | tail -n 3
  done
fi

step data-services
"${COMPOSE[@]}" up -d db qdrant objects
wait_healthy db qdrant objects

step api
"${COMPOSE[@]}" up -d --no-deps api
wait_healthy api

psql_file() {
  "${COMPOSE[@]}" exec -T db sh -c 'psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < "$1"
}
shopt -s nullglob
files=("$MIGRATIONS_DIR"/*.sql)
[ ${#files[@]} -gt 0 ] || { STEP=migrations:none; echo "no migrations found in $MIGRATIONS_DIR" >&2; false; }
for f in "${files[@]}"; do
  step "migrations:$(basename "$f")"
  psql_file "$f"
done

step web
"${COMPOSE[@]}" up -d --no-deps web
wait_healthy web

step smoke
"${COMPOSE[@]}" exec -T api python -c "import urllib.request,json; print('   api /health', json.load(urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=5)).get('status'))"
"${COMPOSE[@]}" exec -T web wget -q -O /dev/null http://127.0.0.1/ && echo "   web index served"
"${COMPOSE[@]}" ps --format '   {{.Service}}: {{.State}} {{.Health}}'
docker stats --no-stream --format '   {{.Name}} {{.MemUsage}}' $("${COMPOSE[@]}" ps -q)

step marker
date -u +%FT%TZ > ".edge-ready-$TAG"
trap - ERR
echo
echo "deploy: OK (commit $TAG). TEIA runs internally only; nothing is exposed yet."
echo "Next (separately approved): caddy/README.md 'Apply', which requires .edge-ready-$TAG."
