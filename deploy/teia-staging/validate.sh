#!/usr/bin/env bash
# Read-only checks for the TEIA staging package. Changes nothing, starts nothing, prints no secret values.
#
#   ./validate.sh [env-file]          # default: teia-staging.env next to this script
#   TEIA_SKIP_CADDY=1 ./validate.sh   # skip the Caddy syntax check (needs Docker and caddy:2.8-alpine)
set -euo pipefail
cd "$(dirname "$0")"
ENV_FILE=${1:-teia-staging.env}
problems=0
note() { echo "  - $*"; }
bad() { echo "FAIL: $*"; problems=$((problems + 1)); }

echo "== env file"
[ -f "$ENV_FILE" ] || { echo "FAIL: $ENV_FILE not found (copy teia-staging.env.example)"; exit 1; }
if git -C . ls-files --error-unmatch "$ENV_FILE" >/dev/null 2>&1; then bad "$ENV_FILE is tracked by git"; fi
if command -v stat >/dev/null && [ "$(uname -s)" = "Linux" ]; then
  mode=$(stat -c %a "$ENV_FILE")
  [ "$mode" = "600" ] || [ "$mode" = "400" ] || bad "$ENV_FILE permissions are $mode (use chmod 600)"
fi

# Parse KEY=VALUE without sourcing (values are never echoed).
declare -A env
while IFS= read -r line || [ -n "$line" ]; do
  line=${line%$'\r'}
  [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
  [[ "$line" =~ ^([A-Z0-9_]+)=(.*)$ ]] || { bad "unparseable line in $ENV_FILE"; continue; }
  env[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
done < "$ENV_FILE"

required=(SECRET_KEY POSTGRES_PASSWORD QDRANT_API_KEY AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY OPENAI_API_KEY
          SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASSWORD EMAIL_FROM FRONTEND_URL CORS_ALLOW_ORIGINS TEIA_WEB_API_BASE_URL
          AWS_S3_BUCKET QDRANT_VECTOR_SIZE OPENAI_EMBEDDING_MODEL)
for key in "${required[@]}"; do
  value=${env[$key]:-}
  if [ -z "$value" ]; then bad "$key is empty"; continue; fi
  case "${value,,}" in change-me|changeme|secret|password|todo|xxx|"<"*) bad "$key is a placeholder";; esac
done
min_len() { local v=${env[$1]:-}; [ "${#v}" -ge "$2" ] || bad "$1 must be at least $2 characters"; }
min_len SECRET_KEY 32
min_len POSTGRES_PASSWORD 16
min_len QDRANT_API_KEY 24
min_len AWS_SECRET_ACCESS_KEY 24
min_len AWS_ACCESS_KEY_ID 8

echo "== origins (proposed; unverified until deployed)"
for key in FRONTEND_URL TEIA_WEB_API_BASE_URL; do
  [[ "${env[$key]:-}" =~ ^https://[a-z0-9.-]+(/.*)?$ ]] || bad "$key must be an https URL"
done
[[ "${env[CORS_ALLOW_ORIGINS]:-}" =~ ^\[\"https://[a-z0-9.-]+\"(,\"https://[a-z0-9.-]+\")*\]$ ]] \
  || bad "CORS_ALLOW_ORIGINS must be a JSON list of https origins only"
web_origin=$(sed -E 's#^(https://[^/]+).*#\1#' <<<"${env[FRONTEND_URL]:-}")
grep -qF "\"$web_origin\"" <<<"${env[CORS_ALLOW_ORIGINS]:-}" || bad "CORS_ALLOW_ORIGINS does not include FRONTEND_URL's origin"
if grep -qE '87\.106\.87\.218|cloudfront|s3-website|localhost' <<<"${env[CORS_ALLOW_ORIGINS]:-}${env[FRONTEND_URL]:-}"; then
  bad "origins contain production or local hosts"
fi
note "web: $web_origin"
note "api: $(sed -E 's#^(https://[^/]+).*#\1#' <<<"${env[TEIA_WEB_API_BASE_URL]:-}")"

echo "== model / vector size"
case "${env[OPENAI_EMBEDDING_MODEL]:-}:${env[QDRANT_VECTOR_SIZE]:-}" in
  text-embedding-3-large:3072|text-embedding-3-small:1536|text-embedding-ada-002:1536) note "embedding dimension matches";;
  *) bad "QDRANT_VECTOR_SIZE does not match OPENAI_EMBEDDING_MODEL";;
esac

echo "== stubs and local-only settings"
for key in CHAT_PROVIDER_STUB EMBEDDING_PROVIDER_STUB; do
  [[ "${env[$key]:-false}" =~ ^(false|0)?$ ]] || bad "$key must not be enabled in staging"
done
[ -z "${env[APP_ENV]:-}" ] || [ "${env[APP_ENV]}" = "staging" ] || bad "APP_ENV must be staging (compose sets it)"

echo "== compose"
if command -v docker >/dev/null; then
  docker compose --env-file "$ENV_FILE" -f docker-compose.yml config -q && note "docker compose config: OK" || bad "docker compose config failed"
  rendered=$(docker compose --env-file "$ENV_FILE" -f docker-compose.yml config 2>/dev/null)
  if grep -qE '^[[:space:]]+(ports|published):' <<<"$rendered"; then
    bad "compose publishes host ports"
  else
    note "no host ports published"
  fi
else
  note "docker not available here; compose not checked"
fi

echo "== caddy snippet"
if [ "${TEIA_SKIP_CADDY:-}" != "1" ] && command -v docker >/dev/null; then
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  { echo "existing-site.invalid {"; echo "	respond \"existing\""; echo "}"; cat caddy/teia-staging.caddy; } > "$tmp/Caddyfile"
  mount=$tmp
  if command -v cygpath >/dev/null; then mount=$(cygpath -w "$tmp"); fi
  if MSYS_NO_PATHCONV=1 docker run --rm -v "$mount:/cfg:ro" caddy:2.8-alpine caddy validate --config /cfg/Caddyfile --adapter caddyfile >"$tmp/out" 2>&1; then
    note "caddy 2.8 validate: OK"
  else
    bad "caddy 2.8 validate failed"; sed 's/^/    /' "$tmp/out" | tail -5
  fi
else
  note "caddy check skipped"
fi

echo
if [ "$problems" -eq 0 ]; then echo "validate: OK (no changes were made)"; else echo "validate: $problems problem(s)"; exit 1; fi
