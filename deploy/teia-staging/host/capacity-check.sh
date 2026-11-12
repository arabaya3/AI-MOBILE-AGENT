#!/usr/bin/env bash
# Measurable acceptance / abort criteria protecting the existing apps (IIH IVR, MedicalHub) on the host.
# Read-only except: `baseline` writes its state file; `watch --enforce` stops TEIA staging (only TEIA).
#
#   ./capacity-check.sh preflight          before building/starting TEIA: refuse if the host is already tight
#   ./capacity-check.sh baseline           record the state of every non-TEIA container and kernel counters
#   ./capacity-check.sh check              compare now with the baseline; exit 2 on any abort criterion
#   ./capacity-check.sh watch [--enforce] [minutes]   run `check` every 60 s (default 1440 min = 24 h);
#                                          with --enforce, an abort stops the teia-staging containers
#
# Thresholds (override via environment, values in MiB unless stated):
#   PREFLIGHT_MIN_AVAILABLE=2048   MemAvailable needed before TEIA starts (TEIA peaks measured ~1.8 GiB)
#   PREFLIGHT_MIN_DISK_GIB=8       free space on / (images, volumes, backups)
#   ABORT_MIN_AVAILABLE=300        MemAvailable floor while TEIA runs
#   ABORT_MAX_SWAP_USED=1024       total swap in use (swap is a safety margin, not working memory)
#   ABORT_MAX_SWAPIN_PER_S=500     pages swapped in per second over the sample (sustained thrashing)
# Abort criteria (any one): MemAvailable below floor; swap use above limit; swap-in rate above limit;
# a new kernel OOM kill; any non-TEIA container that was running is stopped, restarted (restart count
# grew), OOM-killed, or turned unhealthy compared with the baseline. Pre-existing problems recorded in the
# baseline (for example an already unhealthy MedicalHub portal) are reported but are not TEIA's abort.
set -Eeuo pipefail
cd "$(dirname "$0")"
STATE_DIR=${TEIA_CAPACITY_STATE:-/var/lib/teia-staging-capacity}
BASELINE=$STATE_DIR/baseline
PREFLIGHT_MIN_AVAILABLE=${PREFLIGHT_MIN_AVAILABLE:-2048}
PREFLIGHT_MIN_DISK_GIB=${PREFLIGHT_MIN_DISK_GIB:-8}
ABORT_MIN_AVAILABLE=${ABORT_MIN_AVAILABLE:-300}
ABORT_MAX_SWAP_USED=${ABORT_MAX_SWAP_USED:-1024}
ABORT_MAX_SWAPIN_PER_S=${ABORT_MAX_SWAPIN_PER_S:-500}
die() { echo "FAIL: $*" >&2; exit 1; }

mem() { awk -v k="$1:" '$1 == k { print int($2 / 1024) }' /proc/meminfo; }
vmstat() { awk -v k="$1" '$1 == k { print $2 }' /proc/vmstat; }
others() {  # name|status|health|restarts|oomkilled for every non-TEIA container
  docker ps -a --format '{{.Names}}' | grep -v '^teia-staging-' | grep -v '^teia-restore-' | sort | while read -r n; do
    docker inspect -f "$n|{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}|{{.RestartCount}}|{{.State.OOMKilled}}" "$n"
  done
}

preflight() {
  local avail disk_gib
  avail=$(mem MemAvailable); disk_gib=$(( $(df --output=avail -k / | tail -n 1) / 1024 / 1024 ))
  echo "MemAvailable ${avail} MiB (need >= $PREFLIGHT_MIN_AVAILABLE); free on / ${disk_gib} GiB (need >= $PREFLIGHT_MIN_DISK_GIB); swap total $(( $(mem SwapTotal) )) MiB"
  [ "$avail" -ge "$PREFLIGHT_MIN_AVAILABLE" ] || die "not enough available memory to start TEIA without pressuring existing apps"
  [ "$disk_gib" -ge "$PREFLIGHT_MIN_DISK_GIB" ] || die "not enough free disk"
  [ "$(mem SwapTotal)" -gt 0 ] || [ "${TEIA_ALLOW_NO_SWAP:-0}" = 1 ] || die "no swap active; apply host/swap.sh first (approved step) or set TEIA_ALLOW_NO_SWAP=1 consciously"
  echo "preflight: OK"
}

baseline() {
  mkdir -p "$STATE_DIR"; chmod 700 "$STATE_DIR"
  { echo "oom_kill=$(vmstat oom_kill)"; others | sed 's/^/c=/'; } > "$BASELINE"
  echo "baseline recorded ($(grep -c '^c=' "$BASELINE") non-TEIA containers):"; sed -n 's/^c=/   /p' "$BASELINE"
}

check() {
  [ -f "$BASELINE" ] || die "no baseline; run '$0 baseline' before starting TEIA"
  local problems=() notes=() avail swap_used in1 in2 rate line n st he rc oom b_st b_he b_rc
  avail=$(mem MemAvailable); swap_used=$(( $(mem SwapTotal) - $(mem SwapFree) ))
  in1=$(vmstat pswpin); sleep 10; in2=$(vmstat pswpin); rate=$(( (in2 - in1) / 10 ))
  [ "$avail" -ge "$ABORT_MIN_AVAILABLE" ] || problems+=("MemAvailable ${avail} MiB < ${ABORT_MIN_AVAILABLE}")
  [ "$swap_used" -le "$ABORT_MAX_SWAP_USED" ] || problems+=("swap used ${swap_used} MiB > ${ABORT_MAX_SWAP_USED}")
  [ "$rate" -le "$ABORT_MAX_SWAPIN_PER_S" ] || problems+=("swap-in ${rate} pages/s > ${ABORT_MAX_SWAPIN_PER_S}")
  [ "$(vmstat oom_kill)" -le "$(sed -n 's/^oom_kill=//p' "$BASELINE")" ] || problems+=("kernel OOM kills since baseline: $(( $(vmstat oom_kill) - $(sed -n 's/^oom_kill=//p' "$BASELINE") ))")
  while IFS='|' read -r n st he rc oom; do
    line=$(grep "^c=$n|" "$BASELINE" || true)
    if [ -z "$line" ]; then notes+=("$n: new container since baseline"); continue; fi
    IFS='|' read -r _ b_st b_he b_rc _ <<< "${line#c=}"
    [ "$b_st" = running ] && [ "$st" != running ] && problems+=("$n stopped ($st)")
    [ "$rc" -gt "$b_rc" ] && problems+=("$n restarted ($b_rc -> $rc)")
    [ "$oom" = true ] && problems+=("$n OOM-killed")
    if [ "$he" = unhealthy ]; then
      [ "$b_he" = unhealthy ] && notes+=("$n unhealthy already at baseline") || problems+=("$n became unhealthy")
    fi
  done < <(others)
  echo "MemAvailable ${avail} MiB, swap used ${swap_used} MiB, swap-in ${rate} pages/s"
  for x in "${notes[@]}"; do echo "   note: $x"; done
  if [ ${#problems[@]} -gt 0 ]; then
    printf 'ABORT: %s\n' "${problems[@]}" >&2
    return 2
  fi
  echo "check: OK (acceptance criteria met)"
}

case "${1:-}" in
  preflight) preflight;;
  baseline) baseline;;
  check) check;;
  watch)
    shift; ENFORCE=0; [ "${1:-}" = --enforce ] && { ENFORCE=1; shift; }
    end=$((SECONDS + ${1:-1440} * 60))
    while [ $SECONDS -lt $end ]; do
      if ! check; then
        if [ "$ENFORCE" = 1 ]; then
          echo "enforcing: stopping teia-staging containers (existing apps untouched)" >&2
          docker ps --format '{{.Names}}' | grep '^teia-staging-' | xargs -r docker stop -t 30 >&2
        fi
        exit 2
      fi
      sleep 50
    done
    echo "watch: criteria held for the whole window";;
  *) echo "usage: $0 preflight | baseline | check | watch [--enforce] [minutes]"; exit 2;;
esac
