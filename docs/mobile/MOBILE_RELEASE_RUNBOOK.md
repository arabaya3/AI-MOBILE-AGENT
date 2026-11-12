# TEIA AI — Mobile release runbook

Step-by-step instructions for the owner. The private Android staging pilot has its own guide: [ANDROID_PILOT.md](ANDROID_PILOT.md). Nothing here was run against a remote system. Placeholders in `<angle brackets>` are owner inputs; no domain, key or account is assumed. Status and evidence are in [MOBILE_RELEASE_READINESS.md](MOBILE_RELEASE_READINESS.md).

## 0. Inputs needed before starting

| Input | Used for |
|---|---|
| Staging and production API hosts (HTTPS, owner-controlled) | `config/staging.json`, `config/prod.json` |
| Web app host for emailed links (`FRONTEND_URL`) and, optionally, the same host for App Links / Universal Links | backend email links, `APP_LINK_HOSTS`, association files |
| Android upload keystore and Play Console app (`com.teia.aiassistant`, `.staging`) | signed AAB, Play App Signing fingerprint |
| Apple Developer Team ID, App IDs, provisioning profiles, App Store Connect apps | iOS archive and export |
| SMTP account per environment | invitations (required) and password reset |
| Durable object storage (S3-compatible) and a database backup location | documents, rollback |
| A persistent shared path for global prompts | `SYSTEM_PROMPTS_PATH` |
| Approved brand assets and Arabic terminology (`mobile/l10n/REVIEW.md`) | store listing, UI text |

## 1. Toolchain

- Flutter **3.41.6** stable (Dart 3.11.4). `mobile/pubspec.yaml` requires `>=3.41.6 <3.42.0`; CI pins the same version (`FLUTTER_VERSION` in `.github/workflows/mobile.yml`).
- Java 17+ and Android SDK platform 36 for Android; current stable Xcode on macOS for iOS.
- Install exact dependencies with `flutter pub get --enforce-lockfile` (fails if `pubspec.lock` would change).

## 2. Configuration

```bash
cd mobile
cp config/prod.example.json config/prod.json          # git-ignored
# edit: {"API_BASE_URL": "https://<api host>/api/v1", "APP_LINK_HOSTS": "<link host or empty>"}
python tool/check_release_config.py config/prod.json  # must print OK
```

The same rules run in three places, kept in agreement by the shared cases in `config/release_url_cases.json`: this script (all platforms), a Gradle pre-build check for staging/prod release builds (Android stops in seconds and names the broken rule without printing the URL), and the app's own startup validation (shows a configuration error screen, makes no calls). `config/*.example.json` deliberately fail. `cd android && ./gradlew :app:verifyReleaseConfigRules` re-checks the Gradle rules against the shared cases.

## 3. Android

### 3.1 Signing (outside git)

1. Create or obtain the upload keystore; store it and its passwords in the owner's secret store.
2. Create a `key.properties` from `docs/mobile/release/key.properties.template` **outside the repository**, and set `TEIA_KEY_PROPERTIES=<absolute path>` (or place it at `mobile/android/key.properties`, which is git-ignored, as are `*.jks` and `*.keystore`).
3. Without that file, release builds are **unsigned**. They are never signed with the debug key.

### 3.2 Build

```bash
cd mobile
flutter pub get --enforce-lockfile
python tool/check_release_config.py config/prod.json
flutter build appbundle --release --flavor prod -t lib/main_prod.dart \
  --dart-define-from-file=config/prod.json \
  --build-name=<x.y.z> --build-number=<monotonic integer> \
  [--android-project-arg=appLinkHost=<link host>]
# output: build/app/outputs/bundle/prodRelease/app-prod-release.aab
```

Staging: replace `prod` with `staging` and `config/staging.json`. Check the signature with `keytool -printcert -jarfile <aab>` (an unsigned bundle prints "Not a signed jar file").

### 3.3 App Links (optional, needs the owner host)

1. Build with `--android-project-arg=appLinkHost=<host>` and the same host in `APP_LINK_HOSTS`. This adds a verified (`autoVerify`) filter for `https://<host>/join-space`, `/auth` and `/reset-password` to staging/prod only.
2. Publish `https://<host>/.well-known/assetlinks.json` from `docs/mobile/release/assetlinks.json.template` with the **Play App Signing** SHA-256 fingerprint (Play Console → App signing), served as `application/json` without redirects.
3. After install, check `adb shell pm get-app-links com.teia.aiassistant` shows `verified`.

Without this, links open the web page, and users can paste the emailed link into the app's reset or invitation field (covered by `test/features/links/pending_link_test.dart`).

## 4. iOS (macOS only)

```bash
cd mobile
flutter pub get --enforce-lockfile
python tool/check_release_config.py config/prod.json
flutter build ipa --release --flavor prod -t lib/main_prod.dart \
  --dart-define-from-file=config/prod.json \
  --build-name=<x.y.z> --build-number=<monotonic integer> \
  --export-options-plist=<owner ExportOptions.plist (method app-store-connect, teamID)>
# output: build/ios/ipa/*.ipa (signed with the owner's distribution certificate/profile)
```

- Set the Team and provisioning in Xcode for the `prod` and `staging` schemes (`Release-prod`, `Release-staging`), or with automatic signing.
- Universal Links: copy `docs/mobile/release/Runner.entitlements.template` to `ios/Runner/Runner.entitlements`, set `CODE_SIGN_ENTITLEMENTS` for the staging/prod configurations, enable Associated Domains for the App IDs, and publish `https://<host>/.well-known/apple-app-site-association` from the template (no extension, `application/json`, no redirects).
- Export compliance: the app uses only standard HTTPS/TLS. The owner answers the App Store encryption questions (or adds `ITSAppUsesNonExemptEncryption`) — not set in the repository.
- The only iOS build verified so far is CI's **unsigned simulator debug** build. It does not verify signing, archiving or distribution.

## 5. Backend prerequisites for a mobile release

| Requirement | Why | Setting |
|---|---|---|
| HTTPS for API and web | apps refuse http outside dev | reverse proxy / ingress |
| SMTP | invitations are email-only (inviting fails with 503 without it); password reset | `EMAIL_ENABLED=true`, `SMTP_*`, `EMAIL_FROM`, `FRONTEND_URL=https://<web host>` |
| Durable object storage | uploaded documents and downloads | `AWS_S3_*` (real S3-compatible service; moto is test-only) |
| Shared persistent prompt file | global prompts edited by super admins | `SYSTEM_PROMPTS_PATH=<path on a volume shared by all workers/replicas>` |
| Stubs off | stub chat/embedding providers are refused outside development/test | do not set `CHAT_PROVIDER_STUB` / `EMBEDDING_PROVIDER_STUB` |
| Timeouts for synchronous uploads | documents are extracted, embedded and indexed inside the upload request (default limit `PROCESSING_TIMEOUT_SECONDS=300`) | proxy read/send timeout and app-server worker timeout **above 300 s** (e.g. 330 s); request body limit **≥ 26 MiB** (25 MiB file + overhead) |
| Streaming | chat uses SSE | disable proxy response buffering for `/api/v1/chat/query/stream` and `/api/v1/notifications/stream`; idle timeout above `PROVIDER_STREAM_IDLE_TIMEOUT_SECONDS` (120 s) |

**Topology limits (current code):**
- Live notifications use an in-process broadcaster: a client only receives events published by the same worker. Apps reload the list on reconnect and on resume, so delivery is eventually correct but not instant across workers.
- Global prompts are a single JSON file. Supported: one host with several workers sharing the file, or several replicas mounting the **same POSIX volume** (atomic rename, mtime/size reloads). Not supported: per-replica container filesystems (edits diverge and are lost on redeploy) or object storage paths.
- The `docker/Dockerfile` runs one uvicorn worker; the Makefile `prod` target runs four.

## 6. Database release (owner, per environment)

### 6.1 Order

Apply in this order (each file is idempotent and wraps its own transaction):

1. `20261011_0001_chat_shares.sql`
2. `20261012_0001_unique_pending_join_request.sql`
3. `20261013_0001_document_processing_state.sql`
4. `20261102_0001_generation_attempts_and_request_keys.sql`
5. `20261103_0001_conversation_creations.sql`
6. `20261111_0001_hashed_space_invites.sql`

Then deploy the backend; its startup `create_all` adds nothing further (rehearsed: identical schema to a fresh install).

### 6.2 Backup

```bash
pg_dump --format=custom --no-owner --file=teia-<env>-<date>.dump "$DATABASE_URL"
pg_restore --list teia-<env>-<date>.dump > /dev/null   # the backup is readable
```

Keep the object-storage bucket versioned or snapshotted at the same time (documents are not changed by the migrations).

### 6.3 Preflight (read-only)

```sql
SELECT version();
SELECT count(*) AS pending_invites FROM space_invites WHERE status = 'pending';            -- will need resending
SELECT count(*) AS documents_in_flight FROM documents WHERE status NOT IN ('completed','failed'); -- will become failed/interrupted
SELECT space_id, user_id, count(*) FROM space_requests WHERE type='join' AND status='pending'
  GROUP BY 1,2 HAVING count(*) > 1;                                                         -- duplicates to be closed
SELECT count(*) AS unused_reset_tokens FROM password_reset_tokens WHERE used = false;      -- will be invalidated
```

Announce a maintenance window: stop uploads (or the backend) so no document is mid-processing.

### 6.4 Apply

```bash
for f in migrations/sql/2026101{1,2,3}_0001_*.sql migrations/sql/2026110{2,3}_0001_*.sql migrations/sql/20261111_0001_*.sql; do
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$f" || break
done
```

Stop at the first error; the failed file's transaction is rolled back.

### 6.5 Validate

```sql
SELECT count(*) FROM space_invites WHERE token IS NOT NULL;                 -- 0
SELECT status, count(*) FROM space_invites GROUP BY 1;                      -- no 'cancelled'; former pending are 'expired'
SELECT state, state_error, count(*) FROM documents GROUP BY 1,2;            -- no NULL state
SELECT count(*) FROM conversation_creations;                                -- >= chat sessions with a space
SELECT to_regclass('document_upload_receipts'), to_regclass('generation_attempts'), to_regclass('chat_shares');
```

Then smoke-test with a non-production account: sign in, list spaces, chat, upload, invite (email arrives), accept.

### 6.6 What is not reversible

The migrations add tables and columns, but some data changes are one-way by design. Recovery from them is **restore from the backup** (6.2), not a down-migration:
- plaintext invitation tokens are deleted and pending invitations expire (admins resend);
- unused password-reset tokens are marked used (users request a new link);
- duplicate pending join requests are declined (oldest kept);
- documents not `completed` with chunks get a terminal `failed` state (`interrupted`, `processing_failed`, `no_text`);
- legacy share-by-session links stop working (owners create new share links).

Rolling back the application while keeping the migrated schema is possible (the changes are additive) but restores the pre-mobile behaviour, including the defects the migrations close; this was not rehearsed.

## 7. Secret rotation checklist (do not paste values anywhere)

Rotate in the provider console, store new values only in the secret manager, deploy, then revoke the old value:

- [ ] Provider keys that were committed to the upstream repository history (OpenAI and any other LLM, Tavily, Langfuse) — rotate first; history cannot be cleaned retroactively.
- [ ] `SECRET_KEY` (JWT signing) — rotating signs every user out; schedule it.
- [ ] Database password and connection strings.
- [ ] AWS / object-storage access keys (scope to the bucket).
- [ ] SMTP credentials.
- [ ] Android upload keystore passwords (if ever shared) and App Store Connect API keys.
- [ ] Remove any IP-literal fallbacks from client configuration; the web client still falls back to a raw IP when `VITE_API_BASE_URL` is unset (`Front-End/src/api/client.ts`) — set `VITE_API_BASE_URL` to the HTTPS host for production builds.
- [ ] Confirm nothing secret is in `mobile/config/*.json` (only `API_BASE_URL` and `APP_LINK_HOSTS` are allowed; the preflight rejects other keys).

## 8. Provider cancellation (before release)

Verified locally: a stopped or disconnected reply is recorded as `cancelled` with **unknown** usage, counted against token limits with `QUOTA_UNKNOWN_USAGE_TOKENS`, shown as "no reported usage", and never priced as zero; the adapter closes the upstream stream on stop, error and idle timeout.

Not verified (needs the owner's provider account, small test budget):
1. Start a long reply, stop it after the first tokens, note the time and request.
2. In the provider's usage dashboard, compare billed tokens for that request with a completed one.
3. Record whether output generation (and billing) stops at disconnect for each model family in use.
Until then, costs remain estimates and cancelled replies remain "unknown usage".

## 9. Store submission (owner)

Play: internal testing track first; Data safety form (account data, documents and chat content processed by the service, no ads); content rating; privacy policy URL. App Store: TestFlight first; privacy nutrition labels; export compliance; review notes with a test account. Screenshots in `docs/mobile/screenshots/` are from debug builds (they show a DEBUG banner) and are not store assets.
