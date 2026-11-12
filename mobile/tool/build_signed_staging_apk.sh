#!/usr/bin/env bash
# Builds and verifies the signed staging APK for the private Android pilot.
#
#   tool/build_signed_staging_apk.sh <build-name> <build-number>   # build, then verify
#   tool/build_signed_staging_apk.sh --verify-only <path/to.apk>   # verify an existing APK
#
# Both modes require:
#   config/staging.json (or TEIA_STAGING_CONFIG=<path>)  distribution-valid: owner HTTPS host, no test domains
#   TEIA_EXPECTED_CERT_SHA256                             the pilot signing certificate's SHA-256 (pinned)
# Building also requires a key.properties outside git (TEIA_KEY_PROPERTIES=<path>, or android/key.properties).
# Tool paths can be overridden with TEIA_APKSIGNER / TEIA_AAPT2 (used by tool/test_apk_verifier.sh).
# Prints no secrets. Producers are never piped into early-exiting readers (grep -q under pipefail can
# fail a valid check when the producer is cut off), so inputs are captured or extracted to files first.
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG=${TEIA_STAGING_CONFIG:-config/staging.json}
PACKAGE=com.teia.aiassistant.staging
APK=build/app/outputs/flutter-apk/app-staging-release.apk
WORK=""

fail() { echo "FAIL: $*" >&2; exit 1; }
cleanup() { if [ -n "$WORK" ] && [ -d "$WORK" ]; then rm -rf "$WORK"; fi; }
trap cleanup EXIT

python_cmd() {
  local candidate
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null && "$candidate" -c 'import sys; sys.exit(sys.version_info < (3, 8))' 2>/dev/null; then
      echo "$candidate"; return
    fi
  done
  echo "py -3"
}

sdk_tool() {
  local name=$1 sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-${LOCALAPPDATA:-}/Android/Sdk}}
  local dirs latest candidate
  dirs=$(ls -d "$sdk"/build-tools/*/ 2>/dev/null || true)
  latest=$(sort -V <<<"$dirs" | tail -n 1)
  for candidate in "$latest$name" "$latest$name.bat" "$latest$name.exe"; do
    if [ -n "$latest" ] && [ -f "$candidate" ]; then echo "$candidate"; return; fi
  done
  fail "Android build-tools '$name' not found under $sdk/build-tools"
}

normalize_sha256() { tr -d ': \r\n' <<<"$1" | tr 'A-F' 'a-f'; }

require_inputs() {
  [ -f "$CONFIG" ] || fail "$CONFIG is missing (copy config/staging.example.json and set the owner's HTTPS host)"
  $(python_cmd) tool/check_release_config.py --distribution "$CONFIG" >/dev/null || {
    $(python_cmd) tool/check_release_config.py --distribution "$CONFIG" >&2 || true
    fail "$CONFIG is not distributable"
  }
  [ -n "${TEIA_EXPECTED_CERT_SHA256:-}" ] || fail "TEIA_EXPECTED_CERT_SHA256 is not set (pin the pilot signing certificate)"
  EXPECTED_SIGNER=$(normalize_sha256 "$TEIA_EXPECTED_CERT_SHA256")
  [[ "$EXPECTED_SIGNER" =~ ^[0-9a-f]{64}$ ]] || fail "TEIA_EXPECTED_CERT_SHA256 is not a SHA-256 fingerprint"
  API_HOST=$($(python_cmd) -c "import json,sys,urllib.parse;print(urllib.parse.urlsplit(json.load(open(sys.argv[1]))['API_BASE_URL']).hostname)" "$CONFIG")
  API_HOST=${API_HOST%$'\r'}
}

verify() {
  local apk=$1
  [ -f "$apk" ] || fail "APK not found: $apk"
  local apksigner aapt2 certs badging manifest signer
  apksigner=${TEIA_APKSIGNER:-}
  [ -n "$apksigner" ] || apksigner=$(sdk_tool apksigner)
  aapt2=${TEIA_AAPT2:-}
  [ -n "$aapt2" ] || aapt2=$(sdk_tool aapt2)

  certs=$("$apksigner" verify --verbose --print-certs "$apk" 2>&1) || fail "signature does not verify (unsigned or corrupt)"
  grep -q "Verified using v2 scheme (APK Signature Scheme v2): true" <<<"$certs" || fail "APK is not v2-signed"
  if grep -qi "CN=Android Debug" <<<"$certs"; then fail "signed with the Android debug key"; fi
  signer=$(awk -F'certificate SHA-256 digest: ' 'NF > 1 { print $2; exit }' <<<"$certs")
  signer=$(normalize_sha256 "$signer")
  [ -n "$signer" ] || fail "no signer certificate found"
  [ "$signer" = "$EXPECTED_SIGNER" ] || fail "signer certificate does not match TEIA_EXPECTED_CERT_SHA256"

  badging=$("$aapt2" dump badging "$apk")
  grep -q "package: name='$PACKAGE'" <<<"$badging" || fail "package is not $PACKAGE"
  if grep -q "application-debuggable" <<<"$badging"; then fail "APK is debuggable"; fi
  manifest=$("$aapt2" dump xmltree --file AndroidManifest.xml "$apk")
  grep -q 'usesCleartextTraffic.*=false' <<<"$manifest" || fail "cleartext traffic is not disabled"
  if grep -q 'teia-dev' <<<"$manifest"; then fail "dev link scheme present"; fi
  if grep -q 'networkSecurityConfig' <<<"$manifest"; then fail "dev network security config present"; fi

  # The compiled Dart code (one libapp.so per ABI) is extracted to files and searched there in full.
  WORK=$(mktemp -d)
  local entries lib count=0
  entries=$(unzip -Z1 "$apk")
  while IFS= read -r lib; do
    [[ "$lib" == */libapp.so ]] || continue
    count=$((count + 1))
    unzip -q -o "$apk" "$lib" -d "$WORK"
    LC_ALL=C grep -aqF "$API_HOST" "$WORK/$lib" || fail "$lib does not contain the configured API host"
    if LC_ALL=C grep -aqE '://(10\.0\.2\.2|localhost|127\.0\.0\.1)[:/]|[a-z0-9.-]*\.example\.(com|net|org)' "$WORK/$lib"; then
      fail "$lib references a local or reserved test host"
    fi
  done <<<"$entries"
  [ "$count" -gt 0 ] || fail "no compiled Dart code (libapp.so) found"

  local sum
  sum=$(sha256sum "$apk")
  sum=${sum%% *}
  echo "$sum  $(basename "$apk")" > "$apk.sha256"
  echo "OK  $apk"
  echo "    package:          $PACKAGE (not debuggable, cleartext off)"
  echo "    API host:         $API_HOST (found in $count ABI(s); no local or test hosts)"
  echo "    signer SHA-256:   $signer (matches TEIA_EXPECTED_CERT_SHA256)"
  echo "    APK SHA-256:      $sum (also in $apk.sha256)"
}

if [ "${1:-}" = "--verify-only" ]; then
  require_inputs
  verify "${2:?path to APK}"
  exit 0
fi

BUILD_NAME=${1:?build name, e.g. 1.0.0}
BUILD_NUMBER=${2:?build number, a monotonic integer}

require_inputs
KEYPROPS=${TEIA_KEY_PROPERTIES:-android/key.properties}
[ -f "$KEYPROPS" ] || fail "signing key.properties not found (set TEIA_KEY_PROPERTIES to the file kept outside git)"

flutter pub get --enforce-lockfile
flutter build apk --release --flavor staging -t lib/main_staging.dart \
  --dart-define-from-file="$CONFIG" --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"
verify "$APK"
