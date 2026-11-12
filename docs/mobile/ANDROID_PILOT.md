# TEIA AI — Private Android pilot (staging)

A signed **staging** APK (`com.teia.aiassistant.staging`, label "TEIA AI Staging", orange **STAGING** ribbon on every screen) installed on owner-authorized phones, talking to an isolated staging backend over HTTPS. Not a store release. Release-wide procedures stay in [MOBILE_RELEASE_RUNBOOK.md](MOBILE_RELEASE_RUNBOOK.md).

## 1. Inputs (checked 2026-11-12, without reading secret values)

| Input | Status | Needed for |
|---|---|---|
| Owner-controlled staging API and web HTTPS hosts | **Missing**: no `mobile/config/staging.json`; only `staging.example.json` (empty) | building the APK |
| Isolated staging database, object storage, SMTP, vector store | **Missing**: none configured. The repository `.env` is the shared non-isolated configuration and must not be used for staging | running the pilot |
| Android signing key outside git | **Missing**: no `key.properties`, `TEIA_KEY_PROPERTIES` unset. A keystore of an unrelated project exists on the build machine and must not be used | signing |
| Authorized Android phone over adb | **Missing**: `adb devices` lists none | installing and the checklist |

## 2. Signing key (owner, once)

The key that signs the first pilot install must sign every later update of `com.teia.aiassistant.staging` on those phones; losing it means uninstalling (and losing local app data) on every device. So this is a **permanent** key, created and kept like a production secret. No throwaway key is used, even for testing.

```bash
# On the owner's machine, outside any repository. keytool prompts for the passwords (never pass them on
# the command line, never commit them).
keytool -genkeypair -v -storetype PKCS12 \
  -keystore "<secure path outside git>/teia-android-upload.jks" \
  -alias teia-upload -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=<organization>, O=<organization>, C=<country code>"

keytool -list -v -keystore "<secure path>/teia-android-upload.jks" -alias teia-upload | grep 'SHA256:'
```

- **Store:** the `.jks` and both passwords in the owner's secret manager (or password manager) plus one offline encrypted backup. Not in git, not in chat, not in CI logs.
- **Use the same key later as the Play upload key** for `com.teia.aiassistant` (Play App Signing then manages the app signing key), or create a separate staging key stored the same way. Either way, record which key signs which package.
- **key.properties:** create it from `docs/mobile/release/key.properties.template` next to the keystore (outside git) and export `TEIA_KEY_PROPERTIES=<its path>`. Keep `TEIA_EXPECTED_CERT_SHA256=<the SHA256 above>` to pin the signer.

## 3. Build and verify (repeatable)

```bash
cd mobile
cp config/staging.example.json config/staging.json     # git-ignored
# set {"API_BASE_URL": "https://<staging API host>/api/v1", "APP_LINK_HOSTS": ""}
export TEIA_KEY_PROPERTIES=<path outside git>/key.properties
export TEIA_EXPECTED_CERT_SHA256=<upload certificate SHA-256>
bash tool/build_signed_staging_apk.sh <build-name, e.g. 1.0.0> <build-number, increases every build>
```

The script stops on the first problem and prints no secrets:

| Step | Refuses |
|---|---|
| `check_release_config.py --distribution` | http, credentials/query/fragment, IPs, localhost, invalid hosts, **reserved test domains** (`example.com/.net/.org`, `*.example`, `*.test`, `*.invalid`, `*.local`, `*.localhost`), unknown keys |
| signing input | missing `key.properties` |
| Gradle pre-build check | same URL rules (shared cases in `config/release_url_cases.json`) |
| `apksigner verify --print-certs` | unsigned or corrupt APK, no v2 signature, the Android debug key, a signer other than `TEIA_EXPECTED_CERT_SHA256` |
| `aapt2` badging / manifest | wrong package, debuggable, cleartext allowed, dev link scheme, dev network security config |
| compiled Dart code (`libapp.so`, every ABI) | missing configured host; any `localhost`, `10.0.2.2`, `127.0.0.1` or `example.*` host |

On success it prints the package, the signer certificate SHA-256 and the APK SHA-256, and writes `app-staging-release.apk.sha256`. Output: `mobile/build/app/outputs/flutter-apk/app-staging-release.apk`. Share it only with pilot phones over a private channel; it is not published anywhere.

Verified locally so far (no key, no host available): the script refuses a missing config, a reserved host, a missing key, the debug-signed dev APK and an unsigned staging release APK. For that unsigned staging APK (built against `api.pilot-check.invalid`, then deleted) the manifest and code checks were confirmed by hand: correct package and label, not debuggable, cleartext off, backup off, no dev scheme, host compiled into all three ABIs. The success path of the script has **not** run, because it needs the real key.

## 4. Install and upgrade

1. On the phone: Developer options → USB debugging on; connect; accept the computer's key. `adb devices` must list it as `device`.
2. First install, or upgrade keeping data:
   ```bash
   adb install -r mobile/build/app/outputs/flutter-apk/app-staging-release.apk
   ```
   `-r` replaces the app and keeps its data. Never run `adb uninstall` or clear data without the phone owner's agreement.
3. Upgrades need the **same signing key** and a **higher build number**. `INSTALL_FAILED_UPDATE_INCOMPATIBLE` means a different key; stop and check the key, do not uninstall to work around it.
4. **One-time sign-out:** builds since Phase 6 delete a session left by a previous install on their first start (the iOS Keychain survives uninstall; Android uses the same rule). A phone upgrading from an older pilot build, or reinstalling, signs in again once. Later updates keep the session. If storage is unavailable at that moment the app shows "storage unavailable" with Retry and does not use the old session.
5. Without a computer: send the APK over a private channel, allow "Install unknown apps" for the file manager, open the APK, and compare its SHA-256 with the `.sha256` file first.

## 5. Device checklist

Use a synthetic pilot account in the staging space. Record pass / fail / not run, with the device model and Android version.

| # | Check | Expected |
|---|---|---|
| 1 | Launch | "TEIA AI Staging" icon label; orange STAGING ribbon; no configuration error |
| 2 | Sign in; wrong password | Signed in; a wrong password shows a clear error and no session |
| 3 | Spaces | List, select, switch; a space the account cannot access is not offered |
| 4 | Streaming | A reply streams token by token; Markdown renders |
| 5 | Stop | Stop ends the reply on the device; the turn is marked stopped; usage shows "no reported usage" rather than zero cost |
| 6 | Reconnect | Airplane mode during a reply → interrupted turn explained; after reconnecting a new message works; nothing is resent automatically |
| 7 | Upload | Pick a PDF/DOCX/TXT ≤ 25 MB → processing → ready; over 25 MB is refused before upload |
| 8 | Citations after restart | Ask about the upload → sources shown → force-stop and relaunch → same conversation still shows the sources and saved excerpts |
| 9 | Notifications | An admin action (request approval or space policy change) shows a live notification and badge; opening it goes to the right place |
| 10 | Arabic / English | Switch language: full RTL layout in Arabic, Western digits, mixed-language text readable |
| 11 | Large text | System font size at maximum and display size large: no cut-off controls on home, chat, documents, usage |
| 12 | Dark mode | Readable contrast throughout |
| 13 | Sign-out | Returns to sign-in; relaunch does not restore the session; downloaded copies are removed |
| 14 | Upgrade | Install a higher build with `adb install -r`: data kept; one-time sign-out only when upgrading from a build without the install marker |

## 6. Staging backend proposal (not provisioned)

Same code and images as production, separate everything else. Nothing below has been deployed, no DNS changed, no paid service created.

### Services

| Service | Proposal | Notes |
|---|---|---|
| Backend API | `docker/Dockerfile` image, 2 uvicorn workers behind the proxy | live notifications are per worker (apps reload on reconnect) |
| PostgreSQL 16 | new isolated instance or container with a volume; new credentials | never the shared/production database |
| Qdrant | container with a persistent volume (`QDRANT_URL`) | the existing `docker-compose.yml` has no Qdrant service |
| Object storage | a new S3-compatible bucket (e.g. MinIO container or a separate cloud bucket) with versioning | `AWS_S3_*`; never the production bucket |
| SMTP | a separate sending identity or sandbox SMTP with a staging `EMAIL_FROM` | invitations require email; pilot recipients only |
| Reverse proxy + TLS | Caddy (automatic certificates) for `<staging API host>` and `<staging web host>` | timeouts and SSE settings below |
| Web app (optional) | `Front-End` built with `VITE_API_BASE_URL=https://<staging API host>/api/v1`, served by the proxy | invitation and reset links open here |
| AI provider | an owner-funded **staging-only** key with a hard monthly spending cap | the stub providers refuse to run outside `APP_ENV=development/test`; never reuse the production key |

Not needed for the pilot: Neo4j, Redis, Prometheus/Grafana (the readiness probe reports them, but the mobile flows do not use them).

### Environment (names only; values from the secret manager)

`APP_ENV=staging`, `SECRET_KEY` (new), `POSTGRES_HOST/PORT/DB/USER/PASSWORD`, `QDRANT_URL`, `QDRANT_API_KEY` (if enabled), `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_S3_BUCKET`, `AWS_S3_ENDPOINT_URL` (MinIO), `OPENAI_API_KEY` (staging key) and `OPENAI_CHAT_MODEL`, `EMAIL_ENABLED=true`, `SMTP_HOST/PORT/USER/PASSWORD`, `SMTP_USE_TLS=true`, `EMAIL_FROM`, `FRONTEND_URL=https://<staging web host>`, `CORS_ALLOW_ORIGINS=["https://<staging web host>"]` (the default list contains production origins and must be overridden), `SYSTEM_PROMPTS_PATH=/data/prompts/system_prompts.json` (persistent volume), `PROCESSING_TIMEOUT_SECONDS=300`, `RATE_LIMIT_ENABLED=true`. Do not set `CHAT_PROVIDER_STUB` or `EMBEDDING_PROVIDER_STUB`.

### Proxy settings

- Read/send timeout ≥ 330 s and worker timeout above 300 s (uploads are processed inside the request).
- Request body limit ≥ 26 MiB.
- No response buffering for `/api/v1/chat/query/stream` and `/api/v1/notifications/stream`; idle timeout above 120 s.
- HTTP → HTTPS redirect; HSTS once the certificates work.

### Database, backup, migrations

1. New empty database → start the backend once (startup creates the schema) → apply the six migrations in order (runbook §6.1). On an empty database they are no-ops apart from creating indexes and tables, as rehearsed in Phase 6 (fresh install, each file run twice, schema identical to an upgraded one).
2. Nightly `pg_dump --format=custom` kept off the host; bucket versioning on; test one restore before the pilot starts.
3. Validate with runbook §6.5, then create the pilot space, a space admin and synthetic pilot accounts; invite pilot users through the app (email).

### Exit criteria for the pilot

All checklist items pass on at least two phones (one recent Android, one at the minimum supported Android 8.0 if available), no data or access issue found, and the provider usage dashboard reviewed for the cancellation question (runbook §8).

## 7. Inputs needed for the next action

1. The staging **API host** (and web host) under owner control, with HTTPS.
2. The **signing key** created as in §2 and `key.properties` stored outside git, plus its certificate SHA-256.
3. The staging **backend** running per §6 (or confirmation of an existing isolated one), including a staging-only provider key with a spending cap.
4. An authorized **phone** connected over adb, with the owner's consent to install.
