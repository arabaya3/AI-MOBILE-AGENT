#!/usr/bin/env bash
# Local check (no server access): runs caddy:2.8-alpine with the TEIA site blocks behind a stand-in
# existing site and a stand-in upstream, sends requests carrying synthetic share/reset/invite/JWT tokens,
# and fails if any token appears in Caddy's output (access logs and error logs).
set -euo pipefail
cd "$(dirname "$0")"
NET=teia-logtest-$$
WORK=$(mktemp -d)
cleanup() { docker rm -f "$NET-caddy" "$NET-api" "$NET-web" >/dev/null 2>&1 || true; docker network rm "$NET" >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

# Stand-in for the existing IIH IVR config: a global block and a site of its own.
{
  printf '{\n\tauto_https off\n}\n\nhttp://existing.test:80 {\n\trespond "existing" 200\n}\n\n'
  # Same TEIA blocks, served over plain HTTP locally (certificates are not part of this check).
  sed -e 's#^teia-api.65-108-244-83.sslip.io {#http://teia-api.test:80 {#' \
      -e 's#^teia.65-108-244-83.sslip.io {#http://teia-web.test:80 {#' \
      -e "s#teia-staging-api:8000#$NET-api:8000#" -e "s#teia-staging-web:80#$NET-web:80#" teia-staging.caddy
} > "$WORK/Caddyfile"
P=$WORK; command -v cygpath >/dev/null && P=$(cygpath -m "$WORK")

docker network create "$NET" >/dev/null
for s in api web; do
  # shellcheck disable=SC2046
  docker run -d --name "$NET-$s" --network "$NET" caddy:2.8-alpine caddy respond --listen :$([ $s = api ] && echo 8000 || echo 80) --body "$s" >/dev/null
done
sed 's/^\tauto_https off$/\tauto_https off\n\tdebug/' "$WORK/Caddyfile" > "$WORK/Caddyfile.debug"
MSYS_NO_PATHCONV=1 docker run -d --name "$NET-caddy" --network "$NET" -v "$P:/work:ro" caddy:2.8-alpine \
  caddy run --config /work/Caddyfile --adapter caddyfile >/dev/null
sleep 2
export TEIA_HOSTS="teia-api.test teia-web.test"
./check-config.sh "$NET-caddy" /work/Caddyfile
# Negative: an inherited global DEBUG level must be refused.
out=$(./check-config.sh "$NET-caddy" /work/Caddyfile.debug 2>&1) && { echo "FAIL: global debug not refused"; exit 1; }
echo "$out" | grep -q "DEBUG level" || { echo "FAIL: refused for another reason: $out"; exit 1; }
echo "check-config refuses an inherited global debug level: OK"

SHARE=SyntheticShareTok_7f3a91 JWT=eyJSyntheticJwt.payload.sig_44c2 RESET=SyntheticResetTok_b81e INVITE=SyntheticInviteTok_19d0 VERIFY=SyntheticVerifyTok_5aa2 COOKIE=SyntheticCookie_e0f1
req() { docker run --rm --network "$NET" curlimages/curl:8.10.1 -s -o /dev/null -w '%{http_code} ' "$@"; }
U=http://$NET-caddy
api() { req -H Host:teia-api.test "$@"; }
web() { req -H Host:teia-web.test "$@"; }
api "$U/api/v1/shared/$SHARE"
api "$U/api/v1/shared/$SHARE/extra?x=1"
api "$U/api/v1/notifications/stream?token=$JWT"
api -H "Authorization: Bearer $JWT" -H "Cookie: s=$COOKIE" -H "Referer: https://teia.test/auth?token=$RESET" "$U/api/v1/auth/me"
web "$U/join-space?token=$INVITE"
web "$U/auth?token=$RESET"
web "$U/verify-email?token=$VERIFY"
web "$U/shared/$SHARE"
# Upstream down: error logs must not carry the token either.
docker stop "$NET-api" "$NET-web" >/dev/null
api "$U/api/v1/notifications/stream?token=$JWT"
api "$U/api/v1/shared/$SHARE"
web "$U/join-space?token=$INVITE"
req -H Host:existing.test "$U/"
echo
sleep 1
docker logs "$NET-caddy" > "$WORK/log" 2>&1
lines=$(grep -c '"http.log.access' "$WORK/log" || true)
echo "access log lines: $lines"
[ "$lines" -ge 10 ] || { echo "FAIL: expected access log lines"; exit 1; }
grep -q 'REDACTED' "$WORK/log" || { echo "FAIL: no redaction marker"; exit 1; }
fail=0
for t in "$SHARE" "$JWT" "$RESET" "$INVITE" "$VERIFY" "$COOKIE" Synthetic; do
  if grep -q "$t" "$WORK/log"; then echo "FAIL: token found in Caddy output: ${t:0:12}..."; fail=1; fi
done
[ "$fail" = 0 ] || { grep -n Synthetic "$WORK/log" | sed 's/Synthetic[A-Za-z0-9_.]*/<TOKEN>/g' | head; exit 1; }
echo "sample: $(grep -m1 'notifications' "$WORK/log" | grep -o '"uri":"[^"]*"')"
echo "log redaction: OK (no synthetic token in $(wc -l < "$WORK/log") lines of Caddy output)"
