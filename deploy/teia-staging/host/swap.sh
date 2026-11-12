#!/usr/bin/env bash
# TEIA-owned 4 GiB swap file for the shared host (owner-approved step; NOT run by the preparation work).
#
#   sudo ./swap.sh check            read-only: what exists, who owns it, what apply/rollback would do
#   sudo ./swap.sh apply --yes      create and enable /teia-staging.swap (idempotent), persist it
#   sudo ./swap.sh rollback --yes   undo exactly what apply did, restoring the previous swappiness
#
# Ownership: the script only ever touches its own file (/teia-staging.swap), its own fstab line, its own
# sysctl file (/etc/sysctl.d/99-teia-staging-swap.conf) and its state file
# (/var/lib/teia-staging-swap/state, which records the previous vm.swappiness and what apply created).
# A pre-existing /swapfile or any other swap is never adopted, disabled, deleted or reconfigured.
# A file already at the TEIA path that this script did not create is refused, not adopted.
# A failed apply undoes the steps it completed and reports the resulting state.
# Rollback refuses when the swap cannot safely be disabled (its contents must fit in available memory
# with a margin) and changes nothing in that case.
# No container memory limits are changed (MedicalHub stays as it is).
#
# Tests run this script against a scratch root with stubbed system commands:
# TEIA_SWAP_ROOT=<dir> prefixes every path (default: the real root). See host/test-swap.sh.
set -euo pipefail

R=${TEIA_SWAP_ROOT:-}
SWAPFILE_NAME=/teia-staging.swap
SWAPFILE=$R$SWAPFILE_NAME
SIZE_GIB=4
MARGIN_GIB=4                      # free space that must remain on / after creating the file
ROLLBACK_MARGIN_KB=$((512 * 1024)) # MemAvailable must exceed swap-in volume by this much to swapoff
FSTAB=$R/etc/fstab
FSTAB_LINE="$SWAPFILE_NAME none swap sw 0 0   # teia-staging"
SYSCTL_FILE=$R/etc/sysctl.d/99-teia-staging-swap.conf
TEIA_SWAPPINESS=10
STATE_DIR=$R/var/lib/teia-staging-swap
STATE=$STATE_DIR/state
PROC_SWAPS=$R/proc/swaps
MEMINFO=$R/proc/meminfo
SWAPPINESS_PROC=$R/proc/sys/vm/swappiness

die() { echo "FAIL: $*" >&2; exit 1; }
need_yes() { [ "${2:-}" = "--yes" ] || die "'$1' changes the host; re-run with --yes after review"; }
state_get() { [ -f "$STATE" ] && sed -n "s/^$1=//p" "$STATE" | tail -n 1 || true; }
state_set() { mkdir -p "$STATE_DIR"; chmod 700 "$STATE_DIR"; echo "$1=$2" >> "$STATE"; }
is_active() { awk -v f="$SWAPFILE_NAME" 'NR > 1 && $1 == f { found = 1 } END { exit !found }' "$PROC_SWAPS"; }
used_kb() { awk -v f="$SWAPFILE_NAME" 'NR > 1 && $1 == f { print $4 }' "$PROC_SWAPS"; }
mem_available_kb() { awk '$1 == "MemAvailable:" { print $2 }' "$MEMINFO"; }
inode() { stat -c %i "$1"; }
owned() { [ -f "$STATE" ] && [ "$(state_get owner)" = teia-staging ]; }

# Ownership of what is at the TEIA path: none | ours | foreign
ownership() {
  if [ ! -e "$SWAPFILE" ]; then
    owned && [ "$(state_get created_file)" = 1 ] && { echo "ours-missing"; return; }
    echo none; return
  fi
  if owned && [ "$(state_get created_file)" = 1 ] && [ "$(state_get inode)" = "$(inode "$SWAPFILE")" ]; then echo ours; else echo foreign; fi
}

check() {
  echo "== active swap"; cat "$PROC_SWAPS"
  echo "== memory: MemAvailable $(( $(mem_available_kb) / 1024 )) MiB; vm.swappiness $(cat "$SWAPPINESS_PROC")"
  local fs avail_kb own
  fs=$(findmnt -n -o FSTYPE --target "${R:-/}")
  avail_kb=$(df --output=avail -k "${R:-/}" | tail -n 1 | tr -d ' ')
  echo "== root filesystem: $fs, available $((avail_kb / 1024 / 1024)) GiB"
  case "$fs" in
    ext4|xfs) echo "   swap files supported";;
    btrfs) die "btrfs needs a NOCOW swap file (btrfs filesystem mkswapfile); not handled here";;
    *) die "unverified filesystem '$fs' for swap files";;
  esac
  for other in $(awk 'NR > 1 { print $1 }' "$PROC_SWAPS"); do
    [ "$other" = "$SWAPFILE_NAME" ] || echo "== other swap $other: not managed here, left untouched"
  done
  [ -e "$R/swapfile" ] && echo "== $R/swapfile exists: not managed here, left untouched"
  own=$(ownership)
  case "$own" in
    none) [ "$avail_kb" -ge $(((SIZE_GIB + MARGIN_GIB) * 1024 * 1024)) ] || die "needs at least $((SIZE_GIB + MARGIN_GIB)) GiB free on /"
          [ -e "$SYSCTL_FILE" ] && ! owned && die "$SYSCTL_FILE exists but was not created by this script"
          grep -qF "$SWAPFILE_NAME " "$FSTAB" && ! owned && die "$FSTAB already references $SWAPFILE_NAME (not created by this script)"
          echo "== apply would create $SWAPFILE_NAME (${SIZE_GIB} GiB), add one fstab line, set vm.swappiness $(cat "$SWAPPINESS_PROC") -> $TEIA_SWAPPINESS";;
    ours) echo "== $SWAPFILE_NAME is owned by this script (state: $(state_get status)); active: $(is_active && echo yes || echo no)"
          echo "   previous vm.swappiness recorded: $(state_get prev_swappiness)";;
    ours-missing) die "state says $SWAPFILE_NAME was created here but it is missing; inspect $STATE manually";;
    foreign) die "$SWAPFILE exists and was not created by this script; refusing to adopt it";;
  esac
  echo "check: OK (nothing changed)"
}

# --- apply ------------------------------------------------------------------------------------------
UNDO=()   # steps completed in this run, undone in reverse order on failure
on_apply_error() {
  local rc=$? problems=()
  trap - ERR
  echo "apply FAILED (exit $rc); undoing the steps of this run" >&2
  local i
  for ((i = ${#UNDO[@]} - 1; i >= 0; i--)); do
    case "${UNDO[$i]}" in
      swapon) swapoff "$SWAPFILE_NAME" 2>/dev/null || problems+=("swap $SWAPFILE_NAME still active");;
      file) rm -f "$SWAPFILE" || problems+=("$SWAPFILE not removed");;
      fstab) if [ -n "${FSTAB_BACKUP:-}" ] && cat "$FSTAB_BACKUP" > "$FSTAB"; then rm -f "$FSTAB_BACKUP"; else problems+=("fstab not restored (backup ${FSTAB_BACKUP:-none})"); fi;;
      sysctl) rm -f "$SYSCTL_FILE" || problems+=("$SYSCTL_FILE not removed");;
      swappiness) sysctl -q -w "vm.swappiness=$PREV" >/dev/null || problems+=("vm.swappiness not restored to $PREV");;
      state) { rm -f "$STATE" && rmdir "$STATE_DIR" 2>/dev/null; } || [ ! -e "$STATE" ] || problems+=("$STATE not removed");;
    esac
  done
  if [ ${#problems[@]} -eq 0 ]; then
    echo "apply failed; host restored to its previous swap state (vm.swappiness $(cat "$SWAPPINESS_PROC"))" >&2
  else
    echo "apply failed AND THE HOST IS PARTIALLY CHANGED:" >&2; printf '  - %s\n' "${problems[@]}" >&2
  fi
  exit "$rc"
}

apply() {
  check
  if [ "$(ownership)" = ours ]; then
    [ "$(state_get status)" = applied ] || die "a previous apply did not finish (state $(state_get status)); run rollback --yes"
    is_active || { swapon "$SWAPFILE_NAME"; echo "re-enabled $SWAPFILE_NAME"; }
    echo "apply: already applied (idempotent; nothing else changed)"; return
  fi
  PREV=$(cat "$SWAPPINESS_PROC")
  trap on_apply_error ERR
  mkdir -p "$STATE_DIR"; chmod 700 "$STATE_DIR"; : > "$STATE"
  UNDO+=(state)
  state_set owner teia-staging; state_set status in-progress; state_set prev_swappiness "$PREV"
  fallocate -l "${SIZE_GIB}G" "$SWAPFILE" 2>/dev/null || dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((SIZE_GIB * 1024)) status=none
  UNDO+=(file)
  chmod 600 "$SWAPFILE"
  state_set created_file 1; state_set inode "$(inode "$SWAPFILE")"
  mkswap "$SWAPFILE_NAME" >/dev/null
  swapon "$SWAPFILE_NAME"
  UNDO+=(swapon)
  FSTAB_BACKUP="$FSTAB.bak-teia-$(date +%Y%m%d%H%M%S)"
  cp -a "$FSTAB" "$FSTAB_BACKUP"
  UNDO+=(fstab)
  echo "$FSTAB_LINE" >> "$FSTAB"
  state_set added_fstab 1
  echo "vm.swappiness=$TEIA_SWAPPINESS   # teia-staging; previous value $PREV is restored by swap.sh rollback" > "$SYSCTL_FILE"
  UNDO+=(sysctl)
  state_set created_sysctl 1
  UNDO+=(swappiness)
  sysctl -q -w "vm.swappiness=$TEIA_SWAPPINESS" >/dev/null
  state_set status applied
  trap - ERR
  rm -f "$FSTAB_BACKUP"
  cat "$PROC_SWAPS"
  echo "apply: OK ($SWAPFILE_NAME active, vm.swappiness $PREV -> $TEIA_SWAPPINESS)"
}

# --- rollback ---------------------------------------------------------------------------------------
rollback() {
  owned || die "no TEIA swap state at $STATE; nothing of this script's to roll back (other swap is never touched)"
  local own; own=$(ownership)
  [ "$own" = foreign ] && die "$SWAPFILE is not the file this script created (inode changed); refusing"
  local prev; prev=$(state_get prev_swappiness)
  [[ "$prev" =~ ^[0-9]+$ ]] || die "previous vm.swappiness missing from $STATE; refusing"
  if is_active; then
    local used avail
    used=$(used_kb); avail=$(mem_available_kb)
    [ "$avail" -ge $((used + ROLLBACK_MARGIN_KB)) ] \
      || die "cannot safely disable swap: ${used} KiB in $SWAPFILE_NAME, MemAvailable ${avail} KiB (needs +$((ROLLBACK_MARGIN_KB / 1024)) MiB margin). Nothing changed; free memory first (e.g. stop teia-staging)"
    swapoff "$SWAPFILE_NAME" || die "swapoff $SWAPFILE_NAME failed; nothing else changed"
  fi
  if grep -qxF "$FSTAB_LINE" "$FSTAB"; then
    cp -a "$FSTAB" "$FSTAB.bak-teia-$(date +%Y%m%d%H%M%S)"
    grep -vxF "$FSTAB_LINE" "$FSTAB" > "$FSTAB.teia-tmp" || true
    cat "$FSTAB.teia-tmp" > "$FSTAB"; rm -f "$FSTAB.teia-tmp"
  fi
  [ "$(state_get created_sysctl)" = 1 ] && rm -f "$SYSCTL_FILE"
  sysctl -q -w "vm.swappiness=$prev" >/dev/null
  [ "$own" = ours ] && rm -f "$SWAPFILE"
  rm -f "$STATE"; rmdir "$STATE_DIR" 2>/dev/null || true
  cat "$PROC_SWAPS"
  echo "rollback: OK (TEIA swap removed, vm.swappiness restored to $prev)"
}

[ "$(id -u)" -eq 0 ] || die "run as root"
case "${1:-}" in
  check) check;;
  apply) need_yes apply "${2:-}"; apply;;
  rollback) need_yes rollback "${2:-}"; rollback;;
  *) echo "usage: $0 check | apply --yes | rollback --yes"; exit 2;;
esac
