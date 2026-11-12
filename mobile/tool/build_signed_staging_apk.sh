#!/usr/bin/env bash
# Builds and verifies the signed staging APK for the private Android pilot.
#
#   tool/build_signed_staging_apk.sh <build-name> <build-number>   # build, then verify
#   tool/build_signed_staging_apk.sh --verify-only <path/to.apk>   # verify an existing APK
#
# Needs: config/staging.json (owner HTTPS host; never committed) and a key.properties outside git
# (TEIA_KEY_PROPERTIES=<path>, or android/key.properties). Optional: TEIA_EXPECTED_CERT_SHA256 (the
# upload certificate's SHA-256, colon-separated or not) to pin the signer. Prints no secrets.
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG=config/staging.json
PACKAGE=com.teia.aiassistant.staging
APK=build/app/outputs/flutter-apk/app-staging-release.apk

fail() { echo "FAIL: $*" >&2; exit 1; }
python_cmd() { command -v python3 || command -v python || echo "py -3"; }

sdk_tool() {
  local name=$1 sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-${LOCALAPPDATA:-}/Android/Sdk}}
  local found
  found=$(ls -d "$sdk"/build-tools/*/ 2>/dev/null | sort -V | tail -1)
  for candidate in "$found$name" "$found$name.bat" "$found$name.exe"; do
    [ -f "$candidate" ] && { echo "$candidate"; return; }
  done
  fail "Android build-tools '$name' not found under $sdk/build-tools"
}

verify() {
  local apk=$1
  [ -f "$apk" ] || fail "APK not found: $apk"
  local apksigner aapt2 certs badging manifest
  apksigner=$(sdk_tool apksigner)
  aapt2=$(sdk_tool aapt2)

  certs=$("$apksigner" verify --verbose --print-certs "$apk" 2>&1) || fail "signature does not verify (unsigned or corrupt)"
  echo "$certs" | grep -q "Verified using v2 scheme (APK Signature Scheme v2): true" || fail "APK is not v2-signed"
  if echo "$certs" | grep -qi "CN=Android Debug"; then fail "signed with the Android debug key"; fi
  local signer
  signer=$(echo "$certs" | sed -n 's/.*certificate SHA-256 digest: //p' | head -1 | tr -d ':' | tr 'A-F' 'a-f')
  [ -n "$signer" ] || fail "no signer certificate found"
  if [ -n "${TEIA_EXPECTED_CERT_SHA256:-}" ]; then
    local expected
    expected=$(echo "$TEIA_EXPECTED_CERT_SHA256" | tr -d ': ' | tr 'A-F' 'a-f')
    [ "$signer" = "$expected" ] || fail "signer certificate does not match TEIA_EXPECTED_CERT_SHA256"
  fi

  badging=$("$aapt2" dump badging "$apk")
  echo "$badging" | grep -q "package: name='$PACKAGE'" || fail "package is not $PACKAGE"
  if echo "$badging" | grep -q "application-debuggable"; then fail "APK is debuggable"; fi
  manifest=$("$aapt2" dump xmltree --file AndroidManifest.xml "$apk")
  echo "$manifest" | grep -q 'usesCleartextTraffic.*=false' || fail "cleartext traffic is not disabled"
  if echo "$manifest" | grep -q 'teia-dev'; then fail "dev link scheme present"; fi
  if echo "$manifest" | grep -q 'networkSecurityConfig'; then fail "dev network security config present"; fi

  # The compiled Dart code must target the configured host and nothing local or reserved.
  local libs host
  libs=$(unzip -Z1 "$apk" | grep '/libapp.so$' || true)
  [ -n "$libs" ] || fail "no compiled Dart code (libapp.so) found"
  if [ -f "$CONFIG" ]; then
    host=$($(python_cmd) -c "import json,sys,urllib.parse;print(urllib.parse.urlsplit(json.load(open(sys.argv[1]))['API_BASE_URL']).hostname)" "$CONFIG")
    for lib in $libs; do
      unzip -p "$apk" "$lib" | LC_ALL=C grep -aq "$host" || fail "$lib does not contain the configured API host"
    done
  fi
  for lib in $libs; do
    if unzip -p "$apk" "$lib" | LC_ALL=C grep -aqE '://(10\.0\.2\.2|localhost|127\.0\.0\.1)[:/]|[a-z0-9.-]*\.example\.(com|net|org)'; then
      fail "$lib references a local or reserved test host"
    fi
  done

  local sum
  sum=$(sha256sum "$apk" | cut -d' ' -f1)
  echo "$sum  $(basename "$apk")" > "$apk.sha256"
  echo "OK  $apk"
  echo "    package:          $PACKAGE (not debuggable, cleartext off)"
  echo "    signer SHA-256:   $signer"
  echo "    APK SHA-256:      $sum (also in $apk.sha256)"
}

if [ "${1:-}" = "--verify-only" ]; then
  verify "${2:?path to APK}"
  exit 0
fi

BUILD_NAME=${1:?build name, e.g. 1.0.0}
BUILD_NUMBER=${2:?build number, a monotonic integer}

[ -f "$CONFIG" ] || fail "$CONFIG is missing (copy config/staging.example.json and set the owner's HTTPS host)"
$(python_cmd) tool/check_release_config.py --distribution "$CONFIG" || fail "staging config is not distributable"
KEYPROPS=${TEIA_KEY_PROPERTIES:-android/key.properties}
[ -f "$KEYPROPS" ] || fail "signing key.properties not found (set TEIA_KEY_PROPERTIES to the file kept outside git)"

flutter pub get --enforce-lockfile
flutter build apk --release --flavor staging -t lib/main_staging.dart \
  --dart-define-from-file="$CONFIG" --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"
verify "$APK"
