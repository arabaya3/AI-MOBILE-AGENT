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
