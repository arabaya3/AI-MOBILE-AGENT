# TEIA AI — Mobile release readiness

Status on branch `feature/mobile-release-prep` (from `dev` at `c31eca8`, the Phase 5 merge; its post-merge Mobile CI passed). Every check below ran locally with synthetic accounts, a local Postgres, Mailpit, moto S3 and stub providers. Nothing was deployed, published, emailed for real, or run against a remote database or a paid provider. How to perform the remaining steps: [MOBILE_RELEASE_RUNBOOK.md](MOBILE_RELEASE_RUNBOOK.md).

**Verdict:** the code is release-ready for an internal test track once the owner inputs in §4 exist. It is **not** distributable today: no signed build, no HTTPS endpoints, no verified links, no store accounts.

## 1. Artifacts

| Artifact | Type | What it proves | What it does not prove |
|---|---|---|---|
| `app-dev-debug.apk` (Android, dev flavor) | **Debug build**, debug-signed | The journey in §3 on an Android 16 (API 36) emulator, Pixel 5 profile | Release behaviour, signing |
| `app-prod-release.aab` (Android, prod flavor) | **Unsigned release build** (`keytool`: "Not a signed jar file") built with a rehearsal config pointing at the reserved `example.com` | Release compilation, R8/tree-shaking, merged manifest (no cleartext, no backup, no dev scheme, App Links filter present only when a host is given), Gradle config check | Signing, Play acceptance, a real endpoint. Not uploaded anywhere. |
| iOS simulator app (CI) | **Unsigned simulator debug build** | The iOS project compiles with the dev flavor | Device signing, archive, export, App Store / TestFlight |
| Signed AAB / IPA | — | **Not produced**: no keystore, Team ID or profiles were provided | — |

## 2. Results

### Verified

| Area | Evidence |
|---|---|
| Phase 5 post-merge CI | Mobile workflow on `c31eca8`: success |
| Release signing never uses the debug key | `build.gradle.kts`: signing only from an external `key.properties` (`TEIA_KEY_PROPERTIES`); otherwise unsigned (unsigned AAB above) |
| Missing or unsafe release config fails clearly, with one rule set | The Gradle pre-build check (`preStaging/ProdReleaseBuild`, stops in seconds), `tool/check_release_config.py` and the app's `AppConfig.parse` enforce the same rules: https only; no credentials, query or fragment; no IP literals (IPv4/IPv6) or localhost; a public host name whose labels do not start or end with "-". One shared case file, `mobile/config/release_url_cases.json` (17 cases, 3 valid), is checked by all three: Gradle `:app:verifyReleaseConfigRules` (also in CI; a planted disagreement makes it fail), backend-suite tests for the script, and Flutter tests for staging and prod. Build errors name the rule, never the URL (a URL with `user:secret@` was refused without echoing it) |
| Identifiers, versions, OS minimums | Android `com.teia.aiassistant[.dev/.staging]`, minSdk 26, version from `--build-name/--build-number`; iOS bundle IDs per configuration, deployment target 15.0 |
| HTTPS / cleartext | Main manifest `usesCleartextTraffic=false`; cleartext only in the dev flavor's network security config; iOS local networking only for `APP_FLAVOR=dev` |
| Backup | `allowBackup=false`, data-extraction rules exclude everything |
| Permissions | Only `INTERNET` (storage/media permissions removed) |
| Secure storage | Token in the iOS Keychain (`first_unlock_this_device`) / Android Keystore-backed secure storage. **Fixed:** the iOS Keychain survives uninstall, so a reinstall resumed the previous session. Cleanup now **fails closed**: on a fresh install (no marker) the old token is deleted inside the session manager's storage queue *before* any read; if the deletion or the marker write fails, nothing is read, no request is made, and the app shows the existing "storage unavailable" retry screen; retrying repeats the cleanup first. The marker is saved only after the deletion succeeded. Tests: failed delete with a readable old token → no restored session and no request; retry → old token cleared, normal start; marked install → normal restore; marker not saved on failure. Existing installs are signed out once on upgrade (observed on the emulator before this change) |
| Logs and secrets | No request/response logging; the only `debugPrint` is a config error in debug mode; no keys in `lib/` or `config/`; AAB contains no config files |
| Debug features | Developer preview route only when `isDev && !kReleaseMode`; stub providers are refused by the backend outside development/test |
| Account/space change clears cached data | Downloaded documents and exports live in a random per-account/space folder deleted on change and on next start (existing tests); admin state scoped (Phase 5) |
| Invitation/reset links | Dev scheme only in the dev flavor; release accepts https links from `APP_LINK_HOSTS` only; paste fallback (`pending_link_test.dart`); **added** optional verified App Links for staging/prod (`-PappLinkHost`), merged manifest checked |
| Authenticated downloads | Through the API with the bearer header into app-private storage (Phase 3 tests) |
| Licenses | Direct dependencies: 10 BSD-3-Clause, 4 MIT, 1 Apache-2.0 (no copyleft). **Added** an "Open-source licenses" page (Flutter's license registry, includes transitive packages) |
| Toolchain pinned | `pubspec.yaml` `flutter: ">=3.41.6 <3.42.0"` matching CI; `pubspec.lock` changed only in that bound; no package upgrades |
| Database: migration order and idempotency | Isolated Postgres. **Upgrade** from the pre-mobile schema (`a02aa71` models) with representative data, all six migrations run twice, then current startup DDL; **fresh** install, startup DDL then migrations twice. 24/24 checks; upgraded and fresh schemas identical (columns, types, nullability, indexes) |
| Database: data outcomes | Pending plaintext invitations → expired, cancelled → revoked, accepted kept, every plaintext token cleared, no hashes invented; documents → `ready` / `failed` with a code; one `backfill` conversation-creation row per conversation; duplicate pending join requests reduced to one; unused reset tokens invalidated; receipts, generation attempts, shares and creation tables present; existing conversations and usage preserved |
| Current backend on the upgraded database | Phase 5 API journey 23/23 (invitations via Mailpit, reviews, document grant/revoke, limits, last-admin rule) |
| Provider cancellation accounting | Backend suite: real-uvicorn disconnect (attempt `cancelled` / unknown usage, stream closed), fake-upstream adapter cleanup (stop, error, stall, late events), unknown-usage quota charge, cost never zero |
| Global prompt persistence | File reload across workers, atomic writes (Phase 5 review). **Fixed:** `SYSTEM_PROMPTS_PATH` was read but not declared in settings, so it could not be configured; now a setting (test) |
| Mobile journey (English) | Sign-in → space picker → Field Notes → upload (system picker) → ready → chat answer citing the file → force-stop and relaunch → citation and saved excerpt still shown → live notification (badge 6→7) → usage (unknown cost shown as unavailable) → licenses → sign-out. Screenshots `screenshots/phase6/01–10` |
| Arabic, RTL, dark, large text | Same screens at font scale 1.6 in Arabic/dark (`11–13`). **Fixed:** an LTR conversation title in the Arabic UI was cut on the wrong side ("…Who leads the Har"); now follows the title's direction. **Fixed:** the app used two Arabic terms for *space* ("مساحة العمل" and "المساحة") on the same screens; unified on "مساحة العمل" pending owner approval |
| Quality gates | Backend **203** tests; Flutter format clean, analyze clean, **263** tests; web typecheck + build and **10** Vitest tests (web code unchanged by the review fixes); Android dev debug APK and unsigned prod AAB rebuilt after the review fixes |

### Failed / found and left open

| Item | Detail |
|---|---|
| Committed web lockfile out of sync | `npm ci` with the committed `Front-End/package-lock.json` fails: "Missing: jsdom@26.1.0 … Invalid: lock file's vite@7.2.5 does not satisfy vite@5.4.19". CI uses `npm install --no-package-lock`, so web builds are not reproducible from the lockfile. The owner's local lockfile change was not touched (checksum unchanged) and decides the fix |
| Web client IP fallback | `Front-End/src/api/client.ts` falls back to a raw IP over the page's protocol when `VITE_API_BASE_URL` is unset (pre-existing; web). Production web builds must set `VITE_API_BASE_URL` |

### Blocked on owner inputs

| Item | Needs |
|---|---|
| Signed Android AAB, Play internal track | Upload keystore (outside git), Play Console apps, Play App Signing |
| Signed iOS archive/IPA, TestFlight | macOS with Xcode, Team ID, App IDs, profiles, export options |
| Staging/prod builds | Owner HTTPS API hosts in `config/staging.json` / `config/prod.json` |
| Verified App Links / Universal Links | Owner link host, `assetlinks.json` with the Play signing fingerprint, AASA with the Team ID, Associated Domains entitlement (templates in `docs/mobile/release/`) |
| Production migrations | Owner runs the runbook §6 per environment (backup first; some data changes are one-way) |
| Provider billing after cancellation | A provider account and test budget (runbook §8); until then cancelled replies stay "unknown usage" |
| SMTP, durable object storage, shared prompt volume, proxy timeouts | Runbook §5 |
| Secret rotation | Runbook §7 (keys exposed in upstream history) |
| Store listings | Brand assets, privacy policy URL, data-safety / privacy labels, export compliance answer |
| Arabic terminology sign-off | `mobile/l10n/REVIEW.md` |

### Deferred by decision (not release blockers)

Background push (D4), workspace system prompts (S9: no backend storage), personal instructions (stored but not used by generation), document job queue (S22; uploads stay synchronous with the documented timeouts), document delete (no endpoint), regenerate/edit messages, refresh tokens, global super-admin operations and space creation/deactivation (web only).

## 3. Mobile journey evidence

| Step | Screenshot |
|---|---|
| Space picker with two spaces | `phase6/01-space-picker.png` |
| Upload ready | `02-upload-ready.png` |
| Answer citing the uploaded file | `03-chat-with-sources.png` |
| Citation after force-stop and relaunch, excerpt opened | `04-citation-after-restart.png`, `05-citation-opened.png` |
| Live notification and list | `06-notification-badge.png`, `07-notifications.png` |
| Usage (unknown cost explicit) | `08-usage.png` |
| Account with licenses, signed out | `09-account-licenses.png`, `10-signed-out.png` |
| Arabic, dark, font scale 1.6 | `11a`, `11`, `12-ar-dark-chat-title-fixed.png`, `13` |

Screens are debug builds (DEBUG banner) and use the stub provider ("Echo: …").

## 4. Exact owner inputs, in order

1. Approve or change the Arabic terms in `mobile/l10n/REVIEW.md`.
2. Provide staging and production HTTPS hosts for the API and the web app; create `mobile/config/staging.json` and `prod.json`; run `tool/check_release_config.py`.
3. Configure SMTP, durable object storage, a shared persistent `SYSTEM_PROMPTS_PATH`, proxy timeouts and SSE settings per environment (runbook §5).
4. Rotate exposed secrets (runbook §7).
5. Back up, preflight, migrate and validate staging, then production (runbook §6).
6. Provide the Android upload keystore and Play Console apps; build and upload the signed AAB to internal testing.
7. Provide the Apple Team ID, App IDs and profiles; archive and upload to TestFlight from macOS.
8. Optionally publish `assetlinks.json` / `apple-app-site-association` and build with the link host.
9. Run the provider cancellation billing check (runbook §8).
10. Complete store listings, privacy forms and export compliance.
