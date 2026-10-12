# TEIA AI mobile: setup

The Flutter project is in `mobile/`. It targets Android 8.0+ (API 26) and iOS 15+. It has no web or desktop targets.

## Toolchain

| Tool | Version |
|---|---|
| Flutter | **3.41.6** stable (pinned in `.github/workflows/mobile.yml`) |
| Dart | 3.11.4 (bundled) |
| Java | 17 or newer for Gradle |
| Android SDK | Platform 36 and build-tools; an emulator image for API 26 or newer |
| Xcode | Current stable, macOS only |

Dependencies are locked in `mobile/pubspec.lock`. Use `flutter pub get --enforce-lockfile` in CI.

## Environments

| Flavor | Entry point | Android applicationId / iOS bundle ID | Config file |
|---|---|---|---|
| dev | `lib/main_dev.dart` | `com.teia.aiassistant.dev` | `config/dev.json` (tracked) |
| staging | `lib/main_staging.dart` | `com.teia.aiassistant.staging` | `config/staging.json` (**not tracked**) |
| prod | `lib/main_prod.dart` | `com.teia.aiassistant` | `config/prod.json` (**not tracked**) |

Each config file provides one value: `API_BASE_URL`. It never contains credentials.

- **Staging and prod files:** create them from `config/*.example.json` using the owner-controlled HTTPS endpoint. No endpoint is committed, because none has been provided yet.
- **Startup validation:**
  - Staging and prod require `https` and a real host name (not an IP address or `localhost`), in every build.
  - Release builds of any flavor reject `http`.
  - When validation fails, the app shows a configuration error screen and makes no network calls.
- **Cleartext HTTP (dev flavor only):**
  - Android allows it to `10.0.2.2`, `localhost` and `127.0.0.1` (`android/app/src/dev/res/xml/network_security_config.xml`).
  - iOS adds `NSAllowsLocalNetworking` only when `APP_FLAVOR=dev` (the "Allow local networking (dev only)" build phase).
- **Local backend:** run it with a **local** database, never the shared remote one. A physical Android device can reach the host backend through `adb reverse tcp:8001 tcp:8001`, with `API_BASE_URL` set to `http://localhost:8001/api/v1`.

## Windows / Android

```bash
cd mobile
flutter pub get
flutter test
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=config/dev.json
flutter build apk --debug --flavor dev -t lib/main_dev.dart --dart-define-from-file=config/dev.json
```

- Run `flutter doctor --android-licenses` once.
- If `flutter doctor` reports that `cmdline-tools` is missing, install "Android SDK Command-line Tools" from the Android Studio SDK Manager. Gradle builds still work without it.
- Release builds need a signing configuration that is kept outside the repository (Phase 6).

## macOS / iOS

```bash
cd mobile
flutter pub get
flutter build ios --simulator --debug --flavor dev -t lib/main_dev.dart --dart-define-from-file=config/dev.json
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=config/dev.json   # with a simulator open
```

- The `dev`, `staging` and `prod` schemes map to `Debug-<flavor>`, `Release-<flavor>` and `Profile-<flavor>` configurations.
- `tool/configure_ios_flavors.py` created these configurations. It is idempotent, so re-run it after regenerating the iOS project.
- Signing and App Store identifiers are set up in Phase 6. The bundle IDs are provisional.

## Quality gates

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

- **Localizations:** `lib/l10n/app_*.arb`. Generated code in `lib/l10n/gen` is committed, and CI checks that it is up to date.
- **Arabic terms for owner review:** listed in `mobile/l10n/REVIEW.md`.
- **Icons:** placeholder launcher icons come from `tool/generate_placeholder_icons.py`. Replace them when brand assets are approved.

## Local backend for end-to-end checks

Use disposable local services only. Never point the app or the backend at a shared or remote database.

```bash
docker network create teia-e2e-net
docker run -d --name teia-e2e-db --network teia-e2e-net -e POSTGRES_PASSWORD=<local> -e POSTGRES_DB=teia_e2e postgres:16-alpine
docker run -d --name teia-e2e-redis --network teia-e2e-net redis:7-alpine
# Local email sink with STARTTLS (self-signed cert in ./mailcert); web UI and API on :8025
docker run -d --name teia-e2e-mail --network teia-e2e-net -p 8025:8025 -v "$PWD/mailcert:/certs:ro" \
  -e MP_SMTP_TLS_CERT=/certs/cert.pem -e MP_SMTP_TLS_KEY=/certs/key.pem \
  -e MP_SMTP_AUTH_ACCEPT_ANY=true -e MP_SMTP_AUTH_ALLOW_INSECURE=true axllent/mailpit:v1.27
```

Then run the backend from this branch's `src/` **without an `.env` file**, passing every setting explicitly:
- `POSTGRES_*` and `REDIS_*` → the containers above.
- `EMAIL_ENABLED=true`, `SMTP_HOST=teia-e2e-mail`, `SMTP_PORT=1025`, `SMTP_USE_TLS=true`.
- `FRONTEND_URL=http://localhost:5174`.
- A random `SECRET_KEY`, dummy `AWS_*` values, and empty AI-provider keys.

Publish the backend on port 8001; the Android emulator reaches it at `http://10.0.2.2:8001/api/v1`. Create synthetic users through `POST /api/v1/auth/signup`.

### Chat without a paid provider

For chat checks, add `APP_ENV=development`, `CHAT_PROVIDER_STUB=true`, `DEFAULT_ALLOWED_MODELS='["teia-stub-1","teia-stub-2"]'` and `OPENAI_CHAT_MODEL=teia-stub-1`, and set `QDRANT_URL` to an unreachable local address. The stub answers deterministically and never calls the network. The backend refuses to start with the stub in any other `APP_ENV`, including the default `production`.

Put a directive in the prompt to pick a scenario:

| Directive | Result |
|---|---|
| none | `Echo: <prompt>` |
| `[[md]]` | Markdown with a list, a link and code |
| `[[slow]]` | 40 chunks, 250 ms apart (Stop and disconnect checks) |
| `[[long]]` | 200 quick chunks (scrolling) |
| `[[fail-before]]` / `[[fail-after]]` | Provider failure before or after some text |
| `[[raise]]` | Unexpected server exception (generic `internal` error) |

The backend test suite sets the same variables in `tests/conftest.py`.

## Reset and invitation links

| Build | Accepted links |
|---|---|
| dev | `teia-dev://reset-password?token=…`, `teia-dev://join-space?token=…`, plus https links from `APP_LINK_HOSTS` |
| staging / prod | Only `https://<APP_LINK_HOSTS>/auth?token=…` and `/join-space?token=…` |

- **Dev testing on Android:**
  ```bash
  adb shell am start -a android.intent.action.VIEW -d "teia-dev://reset-password?token=<token>" com.teia.aiassistant.dev
  ```
  Take the token from the email in Mailpit.
- **Path to verified links in production:**
  1. Choose the owner-controlled HTTPS host that serves the web app, and set `APP_LINK_HOSTS` to it.
  2. Publish `/.well-known/assetlinks.json` with the release signing certificate fingerprint, and `/.well-known/apple-app-site-association` with the Team ID and bundle IDs.
  3. Add an `autoVerify` intent filter (Android) and the Associated Domains entitlement `applinks:<host>` (iOS).

  Until that is done, users can paste the emailed link into the reset or invitation field.
- **Token handling:** tokens are held in memory only. They never appear in routes, logs or storage, and Flutter's built-in deep linking is disabled so URLs cannot reach the router.

## Sign-out

Sign-out is **local**: it removes the token from secure storage and clears the selected space and in-flight requests. The backend has no revocation endpoint, so a token that was already issued stays valid until it expires (`JWT_EXPIRATION_HOURS`).
