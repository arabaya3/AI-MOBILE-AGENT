#!/usr/bin/env bash
# Scenario tests for swap.sh that never touch a real host: everything runs in a throwaway container
# against scratch roots (TEIA_SWAP_ROOT) with stubbed swapon/swapoff/mkswap/sysctl/fallocate/findmnt/df.
#
#   ./test-swap.sh            (needs Docker; uses bash:5.2)
set -euo pipefail
cd "$(dirname "$0")"
if [ "${1:-}" != --inside ]; then
  P=$PWD; command -v cygpath >/dev/null && P=$(cygpath -m "$PWD")
  exec env MSYS_NO_PATHCONV=1 docker run --rm -v "$P:/host:ro" bash:5.2 bash /host/test-swap.sh --inside
fi

apk add -q coreutils findutils diffutils >/dev/null 2>&1 || true
STUBS=/tmp/stubs; mkdir -p $STUBS
stub() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$STUBS/$1"; chmod +x "$STUBS/$1"; }
stub swapon 'f=$TEIA_SWAP_ROOT$1; [ -f "$f" ] || { echo "swapon: $1: no such file" >&2; exit 1; }
[ -n "${FAIL_SWAPON:-}" ] && { echo "swapon: stub failure" >&2; exit 1; }
printf "%s\tfile\t4194300\t%s\t-2\n" "$1" "${SWAP_USED_KB:-0}" >> "$TEIA_SWAP_ROOT/proc/swaps"'
stub swapoff '[ -n "${FAIL_SWAPOFF:-}" ] && { echo "swapoff: stub failure" >&2; exit 1; }
awk -v f="$1" "\$1 != f" "$TEIA_SWAP_ROOT/proc/swaps" > /tmp/sw && cat /tmp/sw > "$TEIA_SWAP_ROOT/proc/swaps"'
stub mkswap '[ -n "${FAIL_MKSWAP:-}" ] && { echo "mkswap: stub failure" >&2; exit 1; }
[ -f "$TEIA_SWAP_ROOT$1" ]'
stub fallocate ': > "${@: -1}"'
stub sysctl 'for a in "$@"; do case $a in vm.swappiness=*) [ -n "${FAIL_SYSCTL:-}" ] && [ "${a#*=}" = 10 ] && { echo "sysctl: stub failure" >&2; exit 1; }; echo "${a#*=}" > "$TEIA_SWAP_ROOT/proc/sys/vm/swappiness";; esac; done'
stub findmnt 'echo ext4'
stub df 'printf "Avail\n%s\n" "${DF_AVAIL_KB:-20000000}"'
export PATH=$STUBS:$PATH
SW=/host/swap.sh
pass=0; failn=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; failn=$((failn + 1)); }

fresh() {   # new scratch root: a pre-existing, active /swapfile with its fstab line; swappiness 35
  TEIA_SWAP_ROOT=$(mktemp -d); export TEIA_SWAP_ROOT
  R=$TEIA_SWAP_ROOT
  mkdir -p "$R/etc/sysctl.d" "$R/proc/sys/vm" "$R/var/lib"
  printf 'Filename\tType\tSize\tUsed\tPriority\n/swapfile\tfile\t1048572\t2048\t-1\n' > "$R/proc/swaps"
  echo "MemAvailable:    2500000 kB" > "$R/proc/meminfo"
  echo 35 > "$R/proc/sys/vm/swappiness"
  printf 'UUID=abc / ext4 defaults 0 1\n/swapfile none swap sw 0 0\n' > "$R/etc/fstab"
  echo vm.swappiness=35 > "$R/etc/sysctl.d/90-owner.conf"
  head -c 4096 /dev/zero > "$R/swapfile"; chmod 600 "$R/swapfile"
  ORIG_FSTAB=$(cat "$R/etc/fstab"); ORIG_SWAPFILE=$(sha256sum < "$R/swapfile"; stat -c '%i %a' "$R/swapfile")
}
snap() { (cd "$TEIA_SWAP_ROOT" && find . -type d | sort && find . -type f | sort | xargs sha256sum); }
untouched_existing() {
  [ "$(sha256sum < "$R/swapfile"; stat -c '%i %a' "$R/swapfile")" = "$ORIG_SWAPFILE" ] \
    && grep -q '^/swapfile' "$R/proc/swaps" \
    && grep -qx '/swapfile none swap sw 0 0' "$R/etc/fstab" \
    && [ -f "$R/etc/sysctl.d/90-owner.conf" ]
}

echo "1. check is read-only and leaves /swapfile alone"
fresh; before=$(snap); out=$(bash $SW check 2>&1) || true
[ "$(snap)" = "$before" ] && ok "no file changed" || bad "check changed files"
echo "$out" | grep -q "/swapfile exists: not managed here" && ok "reports /swapfile as unmanaged" || bad "no unmanaged notice"

echo "2. apply creates only TEIA-owned items; existing /swapfile untouched; idempotent"
fresh
bash $SW apply --yes >/dev/null && ok "apply succeeded" || bad "apply failed"
[ -f "$R/teia-staging.swap" ] && grep -q '^/teia-staging.swap' "$R/proc/swaps" && ok "TEIA swap active" || bad "TEIA swap not active"
[ "$(cat "$R/proc/sys/vm/swappiness")" = 10 ] && ok "swappiness 10" || bad "swappiness not 10"
grep -q '^prev_swappiness=35$' "$R/var/lib/teia-staging-swap/state" && ok "previous swappiness 35 recorded" || bad "prev not recorded"
untouched_existing && ok "existing /swapfile, its fstab line and owner sysctl untouched" || bad "existing swap disturbed"
bash $SW apply --yes >/dev/null && [ "$(grep -c teia-staging.swap "$R/etc/fstab")" = 1 ] && ok "second apply idempotent (one fstab line)" || bad "second apply not idempotent"

echo "3. rollback restores the previous swappiness and fstab; existing /swapfile untouched"
bash $SW rollback --yes >/dev/null && ok "rollback succeeded" || bad "rollback failed"
[ "$(cat "$R/proc/sys/vm/swappiness")" = 35 ] && ok "swappiness restored to 35 (not a default)" || bad "swappiness is $(cat "$R/proc/sys/vm/swappiness")"
[ "$(cat "$R/etc/fstab")" = "$ORIG_FSTAB" ] && ok "fstab identical to original" || bad "fstab differs"
[ ! -e "$R/teia-staging.swap" ] && [ ! -e "$R/etc/sysctl.d/99-teia-staging-swap.conf" ] && [ ! -e "$R/var/lib/teia-staging-swap/state" ] && ok "TEIA file, sysctl and state removed" || bad "leftovers"
untouched_existing && ok "existing /swapfile still active and intact" || bad "existing swap disturbed"

echo "4. a foreign file at the TEIA path is refused, never adopted"
fresh; echo foreign > "$R/teia-staging.swap"; before=$(snap)
bash $SW apply --yes >/dev/null 2>&1 && bad "apply adopted a foreign file" || ok "apply refused"
bash $SW rollback --yes >/dev/null 2>&1 && bad "rollback acted without state" || ok "rollback refused (no state)"
[ "$(snap)" = "$before" ] && ok "nothing changed" || bad "files changed"

echo "5. a replaced file (inode differs from state) is refused by rollback"
fresh; bash $SW apply --yes >/dev/null
swapoff /teia-staging.swap; echo other > "$R/teia-staging.swap.new"; mv "$R/teia-staging.swap.new" "$R/teia-staging.swap"
bash $SW rollback --yes >/dev/null 2>&1 && bad "rollback deleted a replaced file" || ok "rollback refused"
[ -f "$R/teia-staging.swap" ] && ok "replaced file kept" || bad "replaced file deleted"

for step in MKSWAP SWAPON SYSCTL; do
  echo "6. failed apply at $step is undone completely"
  fresh; before=$(snap)
  out=$(env "FAIL_$step=1" bash $SW apply --yes 2>&1) && bad "apply should fail" || ok "apply failed as injected"
  echo "$out" | grep -q "host restored to its previous swap state" && ok "reports restored state" || bad "no clear state report: $out"
  [ "$(snap)" = "$before" ] && ok "scratch root identical to before" || { bad "leftovers after failed apply"; diff <(echo "$before") <(snap) || true; }
done

echo "7. rollback refuses when swap cannot safely be disabled (low memory)"
fresh; SWAP_USED_KB=2000000 bash $SW apply --yes >/dev/null
echo "MemAvailable:    1800000 kB" > "$R/proc/meminfo"; before=$(snap)
out=$(bash $SW rollback --yes 2>&1) && bad "rollback should refuse" || ok "rollback refused"
echo "$out" | grep -q "cannot safely disable swap" && ok "explains why" || bad "unclear: $out"
[ "$(snap)" = "$before" ] && grep -q '^/teia-staging.swap' "$R/proc/swaps" && ok "nothing changed, swap still active" || bad "changed"

echo "8. rollback stops cleanly when swapoff fails"
fresh; bash $SW apply --yes >/dev/null; before=$(snap)
FAIL_SWAPOFF=1 bash $SW rollback --yes >/dev/null 2>&1 && bad "rollback should fail" || ok "rollback failed"
[ "$(snap)" = "$before" ] && ok "fstab, sysctl, state and file unchanged" || bad "partial rollback"

echo "9. a stale fstab entry for the TEIA path without state is refused"
fresh; echo "/teia-staging.swap none swap sw 0 0" >> "$R/etc/fstab"; before=$(snap)
bash $SW apply --yes >/dev/null 2>&1 && bad "apply should refuse" || ok "apply refused"
[ "$(snap)" = "$before" ] && ok "nothing changed" || bad "changed"

echo "swap tests: $pass passed, $failn failed"
[ "$failn" = 0 ]
