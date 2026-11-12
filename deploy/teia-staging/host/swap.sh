#!/usr/bin/env bash
# 4 GiB swap file for the shared host (owner-approved step; NOT run by the preparation work).
#
#   sudo ./swap.sh check            read-only: current swap, free space, filesystem, what apply would do
#   sudo ./swap.sh apply --yes      create /swapfile (idempotent), enable it now and at boot
#   sudo ./swap.sh rollback --yes   disable and remove it again
#
# Persistent configuration: one /etc/fstab line ("/swapfile none swap sw 0 0") and
# /etc/sysctl.d/99-teia-swap.conf (vm.swappiness=10, so swap is a safety margin, not working memory).
# No container memory limits are changed (MedicalHub stays as it is).
set -euo pipefail

SWAPFILE=/swapfile
SIZE_GIB=4
FSTAB_LINE="$SWAPFILE none swap sw 0 0"
SYSCTL_FILE=/etc/sysctl.d/99-teia-swap.conf
MARGIN_GIB=4   # free space that must remain on / after creating the file

die() { echo "FAIL: $*" >&2; exit 1; }
need_yes() { [ "${2:-}" = "--yes" ] || die "'$1' changes the host; re-run with --yes after review"; }

check() {
  echo "== active swap"; swapon --show || true
  echo "== memory"; free -h
  local fs avail_kb
  fs=$(findmnt -n -o FSTYPE --target /)
  avail_kb=$(df --output=avail -k / | tail -n 1 | tr -d ' ')
  echo "== root filesystem: $fs, available $((avail_kb / 1024 / 1024)) GiB"
  case "$fs" in
    ext4|xfs) echo "   swap files supported";;
    btrfs) die "btrfs needs a NOCOW swap file (btrfs filesystem mkswapfile); not handled here";;
    *) die "unverified filesystem '$fs' for swap files";;
  esac
  [ "$avail_kb" -ge $(((SIZE_GIB + MARGIN_GIB) * 1024 * 1024)) ] || die "needs at least $((SIZE_GIB + MARGIN_GIB)) GiB free on /"
  if [ -e "$SWAPFILE" ]; then echo "== $SWAPFILE exists ($(du -h "$SWAPFILE" | cut -f1)); apply will only (re)enable it"; fi
  grep -qxF "$FSTAB_LINE" /etc/fstab && echo "== fstab already has the swap line" || echo "== fstab: line would be added"
  [ -f "$SYSCTL_FILE" ] && echo "== $SYSCTL_FILE present" || echo "== $SYSCTL_FILE would be created (vm.swappiness=10)"
  echo "check: OK (nothing changed)"
}

apply() {
  check
  if [ ! -e "$SWAPFILE" ]; then
    fallocate -l "${SIZE_GIB}G" "$SWAPFILE" 2>/dev/null || dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((SIZE_GIB * 1024)) status=none
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE" >/dev/null
  fi
  [ "$(stat -c %a "$SWAPFILE")" = "600" ] || chmod 600 "$SWAPFILE"
  swapon --show=NAME --noheadings | grep -qxF "$SWAPFILE" || swapon "$SWAPFILE"
  grep -qxF "$FSTAB_LINE" /etc/fstab || { cp -a /etc/fstab "/etc/fstab.bak-teia-$(date +%Y%m%d%H%M%S)"; echo "$FSTAB_LINE" >> /etc/fstab; }
  [ -f "$SYSCTL_FILE" ] || echo "vm.swappiness=10" > "$SYSCTL_FILE"
  sysctl -q -p "$SYSCTL_FILE"
  swapon --show; free -h
}

rollback() {
  swapon --show=NAME --noheadings | grep -qxF "$SWAPFILE" && swapoff "$SWAPFILE"
  if grep -qxF "$FSTAB_LINE" /etc/fstab; then
    cp -a /etc/fstab "/etc/fstab.bak-teia-$(date +%Y%m%d%H%M%S)"
    grep -vxF "$FSTAB_LINE" /etc/fstab > /etc/fstab.teia-tmp && cat /etc/fstab.teia-tmp > /etc/fstab && rm /etc/fstab.teia-tmp
  fi
  rm -f "$SWAPFILE" "$SYSCTL_FILE"
  sysctl -q vm.swappiness=60
  swapon --show; free -h
}

[ "$(id -u)" -eq 0 ] || die "run as root"
case "${1:-}" in
  check) check;;
  apply) need_yes apply "${2:-}"; apply;;
  rollback) need_yes rollback "${2:-}"; rollback;;
  *) echo "usage: $0 check | apply --yes | rollback --yes"; exit 2;;
esac
