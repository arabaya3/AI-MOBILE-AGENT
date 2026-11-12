#!/usr/bin/env bash
# Automated tests for tool/build_signed_staging_apk.sh --verify-only.
#
# Everything is synthetic and lives in a temporary directory that is deleted afterwards: the "APKs"
# are zip files with large libapp.so payloads, and apksigner/aapt2 are replaced by fixture scripts
# that print canned output (TEIA_APKSIGNER / TEIA_AAPT2). No key is created and nothing produced
# here is an installable or distributable APK. This tests the verifier's logic, not a signed build.
set -euo pipefail

cd "$(dirname "$0")/.."
TOOL="$PWD/tool/build_signed_staging_apk.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

PY=python3
command -v python3 >/dev/null && python3 -c 'import sys' 2>/dev/null || PY="py -3"

HOST=api.pilot-fixture.net            # fixture only; never contacted
GOOD_SIGNER=$(printf 'a1%.0s' $(seq 1 32))
OTHER_SIGNER=$(printf 'b2%.0s' $(seq 1 32))
pass=0
failures=0

printf '{"API_BASE_URL": "https://%s/api/v1"}\n' "$HOST" > "$T/staging.json"

# Fixture tools: print the sidecar files written next to each synthetic APK.
cat > "$T/apksigner" <<'EOF'
#!/usr/bin/env bash
apk="${@: -1}"
cat "$apk.certs"
exit "$(cat "$apk.certs.rc" 2>/dev/null || echo 0)"
EOF
cat > "$T/aapt2" <<'EOF'
#!/usr/bin/env bash
apk="${@: -1}"
if [ "$2" = "badging" ]; then cat "$apk.badging"; else cat "$apk.manifest"; fi
EOF
chmod +x "$T/apksigner" "$T/aapt2"

# make_apk <name> <payload spec ...>: each spec is "abi:needle@offset" (needle placed at a byte offset
# inside a 24 MiB random-looking payload). Writes sidecar tool outputs with the given signer.
make_apk() {
  local name=$1 signer=$2; shift 2
  $PY - "$T/$name.apk" "$@" <<'PYEOF'
import os, sys, zipfile
path, specs = sys.argv[1], sys.argv[2:]
size = 24 * 1024 * 1024
with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as z:
    z.writestr("AndroidManifest.xml", b"binary manifest placeholder")
    by_abi = {}
    for spec in specs:
        abi, rest = spec.split(":", 1)
        needle, offset = rest.rsplit("@", 1)
        by_abi.setdefault(abi, []).append((needle.encode(), int(offset)))
    for abi, needles in by_abi.items():
        data = bytearray(os.urandom(size))
        for needle, offset in needles:
            data[offset:offset + len(needle)] = needle
        z.writestr(f"lib/{abi}/libapp.so", bytes(data))
PYEOF
  {
    echo "Verifies"
    echo "Verified using v2 scheme (APK Signature Scheme v2): true"
    echo "Signer #1 certificate DN: CN=TEIA TEST-ONLY verifier fixture"
    echo "Signer #1 certificate SHA-256 digest: $signer"
  } > "$T/$name.apk.certs"
  echo "package: name='com.teia.aiassistant.staging' versionCode='7' versionName='1.0.0'" > "$T/$name.apk.badging"
  echo "A: http://schemas.android.com/apk/res/android:usesCleartextTraffic(0x010104ec)=false" > "$T/$name.apk.manifest"
}

# run_case <description> <expect: ok|fail> <expected output fragment> <apk> [env assignments...]
run_case() {
  local desc=$1 expect=$2 fragment=$3 apk=$4; shift 4
  local out rc=0
  out=$(env TEIA_APKSIGNER="$T/apksigner" TEIA_AAPT2="$T/aapt2" TEIA_STAGING_CONFIG="$T/staging.json" \
        TEIA_EXPECTED_CERT_SHA256="$GOOD_SIGNER" "$@" bash "$TOOL" --verify-only "$apk" 2>&1) || rc=$?
  local ok=1
  if [ "$expect" = ok ] && [ "$rc" -ne 0 ]; then ok=0; fi
  if [ "$expect" = fail ] && [ "$rc" -eq 0 ]; then ok=0; fi
  if ! grep -qF "$fragment" <<<"$out"; then ok=0; fi
  if [ "$ok" = 1 ]; then pass=$((pass + 1)); echo "PASS  $desc"
  else failures=$((failures + 1)); echo "FAIL  $desc (exit $rc)"; echo "$out" | sed 's/^/      /'; fi
}

# Valid: the host sits a few bytes into a large payload, so readers that stop early would cut the producer.
make_apk valid "$GOOD_SIGNER" "arm64-v8a:$HOST@64" "armeabi-v7a:$HOST@128" "x86_64:$HOST@4096"
run_case "valid APK, host near the start of large binaries" ok "matches TEIA_EXPECTED_CERT_SHA256" "$T/valid.apk"
run_case "colon-separated uppercase fingerprint accepted" ok "OK" "$T/valid.apk" \
  TEIA_EXPECTED_CERT_SHA256="$(sed 's/../&:/g; s/:$//' <<<"$GOOD_SIGNER" | tr 'a-f' 'A-F')"
[ -f "$T/valid.apk.sha256" ] && { pass=$((pass + 1)); echo "PASS  checksum file written"; } || { failures=$((failures + 1)); echo "FAIL  checksum file missing"; }

make_apk wrong "$OTHER_SIGNER" "arm64-v8a:$HOST@64"
run_case "wrong signer refused" fail "does not match TEIA_EXPECTED_CERT_SHA256" "$T/wrong.apk"

run_case "missing config refused" fail "is missing" "$T/valid.apk" TEIA_STAGING_CONFIG="$T/absent.json"
printf '{"API_BASE_URL": "https://api.example.com/api/v1"}\n' > "$T/reserved.json"
run_case "reserved-domain config refused" fail "not distributable" "$T/valid.apk" TEIA_STAGING_CONFIG="$T/reserved.json"
run_case "missing signer pin refused" fail "TEIA_EXPECTED_CERT_SHA256 is not set" "$T/valid.apk" TEIA_EXPECTED_CERT_SHA256=
run_case "malformed signer pin refused" fail "not a SHA-256 fingerprint" "$T/valid.apk" TEIA_EXPECTED_CERT_SHA256=abc

# Forbidden hosts near the start of one ABI, with the configured host also present early.
make_apk reserved_host "$GOOD_SIGNER" "arm64-v8a:$HOST@64" "armeabi-v7a:$HOST@64" "armeabi-v7a:https://api.example.com/x@256"
run_case "reserved test host in one ABI refused" fail "references a local or reserved test host" "$T/reserved_host.apk"
make_apk local_host "$GOOD_SIGNER" "arm64-v8a:$HOST@64" "arm64-v8a:http://10.0.2.2:8001/api@200"
run_case "emulator host refused" fail "references a local or reserved test host" "$T/local_host.apk"
make_apk missing_host "$GOOD_SIGNER" "arm64-v8a:$HOST@64" "x86_64:api.other-host.net@64"
run_case "ABI without the configured host refused" fail "does not contain the configured API host" "$T/missing_host.apk"

make_apk debug "$GOOD_SIGNER" "arm64-v8a:$HOST@64"
sed -i 's/CN=TEIA TEST-ONLY verifier fixture/CN=Android Debug, O=Android, C=US/' "$T/debug.apk.certs"
run_case "debug-signed APK refused" fail "Android debug key" "$T/debug.apk"
make_apk unsigned "$GOOD_SIGNER" "arm64-v8a:$HOST@64"
echo "DOES NOT VERIFY" > "$T/unsigned.apk.certs"; echo 1 > "$T/unsigned.apk.certs.rc"
run_case "unsigned APK refused" fail "signature does not verify" "$T/unsigned.apk"
make_apk debuggable "$GOOD_SIGNER" "arm64-v8a:$HOST@64"
echo "application-debuggable" >> "$T/debuggable.apk.badging"
run_case "debuggable APK refused" fail "APK is debuggable" "$T/debuggable.apk"
make_apk cleartext "$GOOD_SIGNER" "arm64-v8a:$HOST@64"
echo "A: usesCleartextTraffic(0x010104ec)=true" > "$T/cleartext.apk.manifest"
run_case "cleartext APK refused" fail "cleartext traffic is not disabled" "$T/cleartext.apk"

echo "$pass passed, $failures failed"
[ "$failures" -eq 0 ]
