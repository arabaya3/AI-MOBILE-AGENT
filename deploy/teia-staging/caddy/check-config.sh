#!/usr/bin/env bash
# Read-only check of the Caddy config a running container would load (run AFTER appending the TEIA
# blocks and BEFORE any reload). It changes nothing: `caddy validate` and `caddy adapt` only read.
#
#   ./check-config.sh [container] [config]     defaults: iih-ivr-caddy-1 /etc/caddy/Caddyfile
#
# Fails when the TEIA log redaction could be bypassed by inherited/global logging:
#   - a DEBUG log level anywhere (handled proxy errors carrying raw URIs are logged at DEBUG),
#   - log_credentials enabled on a server (Authorization/Cookie headers in logs),
#   - a server-wide default access logger (would log TEIA hosts unfiltered),
#   - a logger including all access logs ("http.log.access" without a site suffix),
#   - a TEIA host without its own logger, or with a logger that does not redact URIs.
set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows only; no effect elsewhere
C=${1:-iih-ivr-caddy-1}
CF=${2:-/etc/caddy/Caddyfile}
HOSTS=${TEIA_HOSTS:-teia-api.65-108-244-83.sslip.io teia.65-108-244-83.sslip.io}
die() { echo "FAIL: $*" >&2; exit 1; }

docker exec "$C" caddy version
if ! docker exec "$C" caddy validate --config "$CF" --adapter caddyfile >/dev/null 2>&1; then
  docker exec "$C" caddy validate --config "$CF" --adapter caddyfile 2>&1 | tail -n 5
  die "caddy validate failed"
fi
echo "validate: Valid configuration"
# One JSON document; '>' is written as > by caddy adapt. Normalise it for matching.
J=$(docker exec "$C" caddy adapt --config "$CF" --adapter caddyfile 2>/dev/null | sed 's/\\u003e/>/g')

has() { printf '%s' "$J" | grep -qE "$1"; }
has '"level":"(debug|DEBUG)"' && die "a logger runs at DEBUG level"
has '"should_log_credentials":true' && die "log_credentials is enabled"
has '"default_logger_name"' && die "a server-wide default access logger is configured"
has '"http\.log\.access"' && die "a logger includes every access log"

for h in $HOSTS; do
  hq=${h//./\\.}
  names=$(printf '%s' "$J" | grep -oE "\"$hq\":\[[^]]*\]" | sed -E 's/^"[^"]*"://' | grep -oE '[A-Za-z0-9_]+' | sort -u || true)
  [ -n "$names" ] || die "no access logger mapped for $h"
  for n in $names; do
    def=$(printf '%s' "$J" | grep -oE "\"$n\":\{\"writer\".*\"include\":\[\"http\.log\.access\.$n\"\]" || true)
    [ -n "$def" ] || die "logger $n for $h not found"
    printf '%s' "$def" | grep -qE '"request>uri":\{"filter":"regexp"' || die "logger $n for $h does not redact URIs"
  done
  echo "logging: $h -> $(echo $names) (URI redaction present)"
done
echo "check-config: OK (nothing changed)"
