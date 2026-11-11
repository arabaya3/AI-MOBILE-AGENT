# TEIA Mobile — Implementation Plan

| | |
|---|---|
| Product | TEIA AI Assistant |
| Baseline | `origin/dev` @ `a02aa7191485041981b1f166ee517195cf210482` |
| Repository | `arabaya3/AI-MOBILE-AGENT` (no changes to any original TEIA repository) |
| Decisions | D1–D11 resolved 2026-10-11 (§9) |
| Current phase | Phase 5 in review (§6): space administration and secure invitations. Phases 0–4 merged (latest `a34d70f`). |

API evidence for every statement here is in [MOBILE_DISCOVERY.md](MOBILE_DISCOVERY.md).

Every item in this plan carries one of three labels:

- **[Confirmed]**: a requirement verified in the existing product or decided by the owner.
- **[Recommended]**: an engineering proposal.
- **[Open]**: an external dependency that is still unresolved.

---

## 1. Scope

**[Confirmed]** The app is a native Flutter client for Android and iOS, built against the existing FastAPI backend. It covers all of the following:

- Authentication.
- Spaces.
- Chat with streaming.
- Model selection.
- Documents and citations.
- Message actions.
- Export and share.
- In-app notifications.
- Requests.
- Usage and invoices.
- Profile, theme and language.
- **Space administration**, which means members, roles, document permissions, approved models and tools, quotas, requests, usage and workspace system prompts (D1, D5).

**[Confirmed]** The following stay on the web for v1 and are recorded in the parity matrix (§10):

- Global super-admin operations.
- Global system prompts.
- Background push notifications (D4).

**[Confirmed]** The app never holds AI-provider keys or backend secrets. The backend enforces authorization, model policy and quotas; hiding a control in the UI is never treated as enforcement.

---

## 2. Architecture

### 2.1 Location and layout

```
mobile/
  lib/
    main_dev.dart / main_staging.dart / main_prod.dart
    app/            app widget, router, theme, localization setup
    core/
      config/       AppConfig + release-safety validation
      network/      ApiClient (Dio), interceptors, ApiException, SseClient
      storage/      SecureTokenStore, Preferences
      auth/         session state (token, expiry, current user)
      widgets/      shared state views (loading/empty/error/offline)
    features/
      auth/ spaces/ chat/ documents/ notifications/ requests/ usage/ profile/ space_admin/
        data/           DTOs, API class, repository
        application/    Riverpod notifiers
        presentation/   screens and widgets
    l10n/           app_en.arb, app_ar.arb
  test/  integration_test/
```

Widgets never call the network directly. Repositories return typed models and throw a sealed `ApiException`.

### 2.2 Library choices

| Concern | Choice | Justification |
|---|---|---|
| State and DI | `flutter_riverpod` with `riverpod_annotation` | Compile-safe providers and test overrides. `AsyncValue` maps directly onto the loading, error and data states. |
| Routing | `go_router` | Redirect guards for auth and space selection. Deep links for password reset, invite accept and shared conversation. |
| HTTP | `dio` | Interceptors for the `Authorization` and `X-Space-Id` headers, cancel tokens, multipart progress, and `ResponseType.stream` for SSE. |
| SSE | In-house incremental parser over the Dio byte stream | The endpoint is a POST with headers. The parser handles arbitrary byte and UTF-8 boundaries, CRLF/LF/CR line endings, multi-line `data:` fields, comments and cancellation, and is fully unit-tested. |
| Models and state unions | Dart 3 `sealed` classes; `freezed` + `json_serializable` when API DTOs arrive (Phase 1+) | Phase 0 needs only small exhaustive unions (`ApiException`, `ChatStreamEvent`), and sealed classes cover them without code generation. Freezed will be added once copyWith/equality on DTOs saves real code. |
| Token storage | `flutter_secure_storage` | iOS Keychain and Android Keystore. |
| Preferences | `shared_preferences` | Theme, locale, last space, model and `top_k`. No secrets. |
| Files | `file_picker`, `path_provider`, `open_filex`, `share_plus` | Downloads require the Bearer header, so files are fetched to temporary storage and then opened or shared. |
| Markdown | `flutter_markdown_plus` | Assistant replies are Markdown. |
| Connectivity | `connectivity_plus` | Offline banner. |
| i18n | `flutter_localizations` + `intl` (gen-l10n) | First-party tooling with RTL support. |
| Tests | `flutter_test`, `mocktail`, `integration_test` | |

There is no Firebase in v1 (D4), no second state-management library and no local database (§5).

**Compatibility (D11).** The installed toolchain is Flutter 3.41.6 / Dart 3.11.4. Flutter's own minimums are Android API 24 and iOS 13. The targets, Android 8.0 (API 26) and iOS 15, sit above both, so no increase is required by Flutter. **Verified in Phase 0:** every chosen package resolves and builds with Android `minSdk = 26` and an iOS 15 deployment target. Two newer major versions need Dart ≥ 3.12, which is a newer SDK than the pinned one: Riverpod 3.4 and go_router 18. The resolved versions are therefore Riverpod **3.3.2**, go_router **17.5**, Dio **5.11** and flutter_secure_storage **11.2**. Upgrading means raising the pinned Flutter SDK, which is a deliberate later step.

### 2.3 Configuration and identity (D2, D9)

| Flavor | Application ID / bundle ID | Display name | API base URL |
|---|---|---|---|
| dev | `com.teia.aiassistant.dev` | TEIA AI Dev | `http://10.0.2.2:8001/api/v1` (Android emulator) or `http://localhost:8001/api/v1` (iOS simulator), overridable |
| staging | `com.teia.aiassistant.staging` | TEIA AI Staging | **[Open]** owner-controlled HTTPS URL |
| prod | `com.teia.aiassistant` | TEIA AI | **[Open]** owner-controlled HTTPS URL |

- **URL source.** The URL is supplied with `--dart-define-from-file=config/<flavor>.json`. The config files contain URLs only, never secrets.
- **Startup validation.** `AppConfig.validate()` runs at startup. In staging, in prod, and in any release build, it rejects a non-`https` scheme, an empty host, `localhost` / `10.0.2.2` and raw IP literals. The build fails fast instead of shipping an insecure configuration.
- **Cleartext traffic.** It is allowed only in the dev flavor: through the Android debug `network_security_config`, and through an iOS ATS exception in the Debug configuration only.
- **Placeholders.** Domains are never invented and the production IP is never reused as staging. Missing HTTPS endpoints block release only (§8).
- **Identifiers.** All IDs are provisional and must be checked for availability and ownership before store submission. A simple temporary icon is used until approved brand assets arrive.

### 2.4 Networking rules

- **Headers.** An interceptor adds `Authorization: Bearer` and `X-Space-Id`.
- **401.** The token is cleared and the user is routed to login with a "session expired" message. There is no refresh token, which was verified, so there is no retry loop.
- **Proactive sign-out.** Scheduled from `expires_in`, with the JWT `exp` claim as a cross-check.
- **429.** Both the plain-text rate-limiter body and the JSON quota body map to `RateLimited` / `QuotaExceeded`.
- **`ApiException` cases:** `Unauthorized`, `Forbidden`, `NotFound`, `Validation`, `RateLimited`, `QuotaExceeded`, `PayloadTooLarge`, `Server`, `Network`, `Timeout`.
- **Uploads (D6).**
  - The client validates the file type and the 25 MiB limit before sending.
  - The receive timeout is configurable, 5 minutes by default.
  - **Uploads are never retried automatically.** A timeout after the bytes were sent shows "status unknown — refresh documents"; the server de-duplicates by content hash.
  - There is no fake processing percentage. Upload progress is real, and server processing is shown as an indeterminate state.

### 2.5 Streaming design

`ChatStreamController` consumes `Stream<ChatStreamEvent>`:

| Event | Handling |
|---|---|
| `Meta(sessionId, sources)` | Attach the session and citations. |
| `Delta(text)` | Append text, coalescing rebuilds per frame. |
| `Done` | Mark complete, then refetch the session for server message IDs. |
| `Error(detail)` | Show an inline error with retry. A detail starting with `429:` maps to a quota message. |
| Delta text containing `[stream_error]` | Render as a failed message. The marker is removed and the content is kept, because the server stores it. |
| Connection lost before `done` | Mark as interrupted and offer retry. |
| Stop | Cancel the Dio request and warn that the partial answer is not saved, because the server rolls it back. |

### 2.6 Security

- The token lives in secure storage only and is never logged. Logging is disabled outside dev.
- Android sets `allowBackup=false`.
- Downloaded and exported files go to temporary storage and are cleared on sign-out.
- Deep-link tokens are used once and never persisted.
- No screenshot or recording blocking (D7).

---

## 3. Navigation and screens

**Entry routing:**

- Not signed in → Auth stack.
- Signed in with no space → Space picker.
- Otherwise → app shell: bottom navigation on phones, navigation rail on tablets.

| Area | Screens |
|---|---|
| Auth | Login, Register, Forgot password, Reset password (deep link `…/auth?token=`) |
| Space | Switcher sheet, Accept invite (deep link), Request access |
| Chat | Sessions list → Conversation (composer, model selector, document chips, `top_k`), message actions (copy, regenerate, edit-and-resend, branch, react), citation sheet → document viewer, summary, export, share link management (create / copy / revoke) |
| Documents | Accessible list, upload (validation and progress), detail (open, chunks) |
| Notifications | List, unread badge, mark read / all, delete, link navigation |
| Account | Profile, change password, preferences (theme, app language, response language, industry), usage and invoice PDF, my requests, personal instructions (only if the backend scopes them to the user, §D5), sign out |
| Space admin (role-gated in the UI, enforced by the backend) | Members and roles, upload rights, document permissions, allowed models and tools, quotas and overrides, requests review, invites, space usage, workspace system prompts |

**Required states:**

- Loading, with skeletons and pull-to-refresh.
- Empty, with the primary action.
- Error, with retry and the safe server `detail`.
- Session expired.
- Offline, as a banner; sending and uploading are disabled.
- Interrupted stream.
- Forbidden.

**Localization (D3).**

- Arabic and English UI, with English as the fallback.
- Full RTL mirroring via the locale.
- Each message gets its own direction from its first strong character, so mixed-language messages render correctly.
- Directional (start/end) layout throughout.
- Text scaling up to 200% without clipping.
- Translations are written and reviewed during implementation. Uncertain terminology is collected in `mobile/l10n/REVIEW.md` for owner sign-off.

**Accessibility.**

- Semantics labels.
- 48 dp touch targets.
- WCAG AA contrast in both themes.
- `SafeArea` and a keyboard-aware composer.
- Reduced motion is respected.

---

## 4. Testing and quality gates

Every mobile PR must pass these gates:

1. `dart format --set-exit-if-changed`
2. `flutter analyze`
3. `flutter test`
4. Android build
5. iOS build, on macOS CI only

iOS is never reported as verified from this Windows environment.

**Mobile tests:**

- **Unit tests:**
  - The SSE parser: split bytes, split UTF-8, CRLF, multi-line data, comments, `[stream_error]`, `error` events, a missing `done`, and cancellation.
  - Config validation.
  - Error mapping.
  - Token-expiry scheduling.
  - Repositories against a mocked Dio.
- **Widget tests:** every state of every screen, RTL goldens, and role gating.
- **Integration tests:** run against a local docker-compose backend with seeded data. They never touch production.

**Backend tests:**

- Every contract change ships with pytest coverage.
- The security suite runs in `.github/workflows/backend-tests.yml`. It uses a disposable Postgres service container, read-only permissions and no secrets, and has no deployment steps.

---

## 5. Offline

v1 is online-first, with in-memory caching of the last session list and the open conversation. Sending, uploading and admin actions require connectivity. There is no local database.

---

## 6. Phased delivery

All work goes on feature branches from `origin/dev`, through PRs that target `dev`. There is no direct push, no auto-merge and no deployment (D8).

### Phase S — Security preparation (current)
- **Scope:**
  - Replace session-id sharing with hashed, expiring, revocable share tokens (R2).
  - Fix password recovery so tokens go by email only, with a generic response and single-use hashed tokens (R3).
  - Explicit SQL migration.
  - Regression tests and backend CI.
  - Web callers updated.
  - Narrow `deploy.yml` fix: mobile-only pushes cannot deploy.
- **Acceptance:**
  - A session ID never grants access.
  - Unshared, expired, revoked and invalid tokens all return 404.
  - Reset tokens never appear in responses or logs.
  - Known and unknown accounts get identical responses.
  - Replay and expiry are rejected.
  - The tests pass in a clean container.
  - No production system was touched.

### Phase 0 — Flutter foundation and CI
- **Scope:** `mobile/` with the three flavors and identifiers, config validation, theme, en/ar localization scaffolding with RTL, router, ApiClient and error model, secure storage, shared state widgets, and the `mobile.yml` workflow (Ubuntu for Android, macOS for iOS; no secrets).
- **Acceptance:**
  - The gates are green.
  - The dev flavor runs on the Android emulator against the local backend.
  - A release build with an `http` or IP URL fails validation, proven by a test.
  - The iOS build passes on macOS CI, or is reported as unverified.

**Phase 0 results (2026-10-11, branch `feature/mobile-foundation`):**

Implemented:
- **Project:** a `mobile/` Flutter project with Android and iOS targets only.
- **Flavors:**
  - `dev`, `staging` and `prod` flavors with the identifiers `com.teia.aiassistant[.dev|.staging]`, on Android (`productFlavors`) and on iOS (`Debug/Release/Profile-<flavor>` configurations and schemes).
  - Minimums: Android API 26 and iOS 15.0.
- **Configuration:**
  - Typed `AppConfig` with startup validation. Release builds and staging/prod reject `http`, IP literals and local hosts.
  - Dev allows cleartext only to local development hosts. The Android dev network-security config and the iOS dev-only ATS build phase match this.
- **Networking:**
  - `ApiClient` (Dio) with the Bearer and `X-Space-Id` headers, three request kinds (`authenticated`, `public`, `credentialCheck`), timeouts, cancellation, and normalized `ApiException` types.
  - Errors handled: FastAPI string detail, FastAPI validation arrays, plain-text versus JSON 429, transport failures.
- **Session expiry:** `SessionManager` ends the session once even when many 401s arrive together. It ignores stale tokens and never retries. A `TokenStore` abstraction has a secure implementation and an in-memory one for tests.
- **Streaming:**
  - Incremental `SseParser`, following the WHATWG rules: arbitrary byte and UTF-8 boundaries, CR/LF/CRLF line endings, multi-line data, comments and ids, a BOM, and cancellation propagated to the source.
  - `ChatStreamDecoder` for `meta`, `delta` (including the `[stream_error]` marker), `done` and `error` (including quota errors).
- **UI foundation:**
  - Arabic and English localization with English as the fallback, a persisted locale choice, RTL, and per-message direction for mixed content.
  - Light and dark themes with neutral surfaces and one accent, 48 dp targets, and AA contrast.
  - Shared state widgets.
  - An honest preview screen: upcoming destinations are disabled and labelled "Not available yet", and developer details appear only in dev debug builds.
- **CI:** `mobile.yml` with read-only permissions and no secrets. It runs on PRs and on pushes to `dev` that touch `mobile/**` or the workflow itself. It checks formatting, analysis, tests, generated localizations, the Android dev debug APK, and an iOS simulator build on macOS without signing.

Verified locally on Windows:
- `dart format --set-exit-if-changed`: clean.
- `flutter analyze`: no issues.
- `flutter test`: 67 tests passing.
- `flutter build apk --debug --flavor dev`: succeeds.
- **On the Pixel 5 emulator (API 36), at a compact 360×760 dp size:**
  - Launch, English/light rendering, switching to Arabic/dark, RTL layout and mixed-direction samples.
  - The choices persist across a restart.
  - Screenshots are in `docs/mobile/screenshots/phase0/`.

Not verified:
- iOS on this Windows machine; that is left to the macOS CI job.
- Any backend integration, since no backend calls exist yet.

Intentionally deferred: login, chat, uploads, administration, and Freezed DTOs. These belong to Phases 1–5.

### Phase 1 — Authentication and spaces
- **Scope:** login, register, forgot/reset password with a deep link, session expiry, sign-out, space switcher with `X-Space-Id`, accept invite, request access. Backend: R4 (`GET /auth/me`) and S1.
- **Acceptance:**
  - Expiry always lands on login with no loops.
  - Switching spaces refreshes all space-scoped data.
  - The token appears in secure storage only.
  - Backend tests cover `/auth/me` and the change-password status code.

**Phase 1 results (2026-10-12, branch `feature/mobile-auth-spaces`):**

Implemented:
- **Authentication:**
  - Screens for sign-in, registration (the role is never sent), forgot password (generic response), reset password (token validated first), account details from `/auth/me`, change password, and local sign-out.
  - Localized and accessible, with autofill hints and password managers supported.
  - Inactive-account, rate-limit, network and field errors each have their own message.
  - Duplicate submissions are blocked, and mutations are never retried automatically.
- **Session concurrency:**
  - `SessionManager` serializes secure-storage writes and deletes in the same order as the in-memory changes.
  - An epoch counter discards stale restores, stale `/me` responses and 401s for older tokens.
  - A failed deletion overwrites the stored token instead of leaving it behind.
  - `ApiClient` cancels every in-flight request on sign-out or account change, and only the space-scoped ones on a space switch.
  - The session state is available immediately to late subscribers.
- **Restore:**
  - The stored token is verified with `/auth/me`.
  - An offline or server failure shows retry or sign-out and keeps the token.
  - An unreadable keystore offers retry.
  - A rejected token requires signing in again.
- **Spaces:**
  - Accessible spaces come from `GET /spaces`, and each selection is confirmed with `/spaces/{id}/me` before `X-Space-Id` is sent.
  - The selection is saved per account and cleared on sign-out or expiry.
  - Inactive spaces, revoked memberships and spaces the backend rejects are never selected; the user sees an "access lost" notice.
  - Late responses after a switch are discarded.
  - Users can browse other spaces, request to join (shown as pending), and accept invitations.
- **Links:**
  - Reset and invite tokens arrive through a link and are held only in memory, never in routes, logs or storage.
  - Flutter's built-in deep linking is disabled on both platforms.
  - The development-only `teia-dev://` scheme exists only in the dev flavor (Android intent filter, iOS build phase).
  - Release builds accept only `https` links from `APP_LINK_HOSTS`, which is empty until an owner domain exists; verified links are therefore **not** claimed.
  - As a fallback, users can paste the emailed link.
- **Home:** an honest authenticated screen showing the account, the space, the role and upload permission. Features not built yet are labelled unavailable; space administration appears only for space admins, and also as unavailable.

Verified:
- **Mobile:**
  - Formatting, analysis and **122** passing Flutter tests: session race tests with controlled storage, ApiClient scoping, links, redirects, auth and space controllers, and full-app flows in en/ar × light/dark at 2× text.
  - Android dev debug APK built.
- **Backend:** **41** pytest tests passing, 14 of them new for `/auth/me`, change-password, signup role restrictions and spaces access.
- **End to end:**
  - Android emulator (API 36, 360 dp) against a **local** FastAPI backend with a new local Postgres, Redis and a Mailpit email sink.
  - Flows: sign-in → `/me` → spaces → select → restart (restored and re-validated) → switch to an Arabic-named space → Arabic/dark UI → sign-out (no restore after relaunch).
  - Password recovery: email in Mailpit → dev link → reset → sign-in with the new password; replay rejected; unknown email got no mail.
  - In-app registration → admin invitation email → dev link → accept → home.
  - Membership revoked during use → access-lost notice.
  - Screenshots are in `docs/mobile/screenshots/phase1/`.

Not verified: iOS on this machine (left to the macOS CI job), verified App Links/Universal Links (no owner domain), and push notifications (out of scope).

### Phase 2 — Chat and streaming
- **Scope:** sessions, conversation, SSE streaming, stop and retry, model selector, message actions, summary, Markdown, mixed-direction rendering, share-link management. Backend: S2, S5, S6.
- **Acceptance:**
  - Rendering is incremental.
  - The error, `[stream_error]`, quota and interrupted cases each have a distinct UI state.
  - Reactions and branching work right after streaming.
  - The SSE parser has full unit coverage.
  - The integration test for login → stream → history passes.

**Phase 2 results (2026-10-12, branch `feature/mobile-chat-streaming`):**

Review findings fixed first:
- **`SessionManager._end`:** the delete and its overwrite fallback now run as one serialized storage operation, so a sign-in that follows a failed sign-out can no longer be erased by a late fallback write. Regression test reproduced the old order `[delete, write:new, write:]`.
- **Stale side effects:** `login` drops a token that arrives after sign-out or an account change; `signOut` only reports signed-out when no newer session exists; the space controller re-checks its generation after every awaited storage call.
- **Join-request concurrency:** a partial unique index (`uq_space_requests_pending_join`) plus an insert inside a savepoint. Concurrent requests return the same pending request. The integration test reproduced 6 duplicates before the fix. Migration `20261012_0001_unique_pending_join_request.sql` closes existing duplicates (keeping the oldest) before creating the index; it was run only on the local e2e database.

Implemented:
- **Conversations:** list, new conversation, history, model picker (saved per account), Markdown with selectable text, copy, mixed-direction rendering, and links that open only for `http(s)` after the user confirms the host.
- **Composer:** duplicate-submit protection, Stop, drafts kept in memory per account and space, and an attachment button that says attachments arrive later.
- **Streaming:**
  - Tokens update a `ValueNotifier`, so the message list is not rebuilt per token.
  - The view follows new text only when the user is already at the bottom, with a "jump to latest" button.
  - A `[stream_error]` marker is detected even when split across deltas, and is never shown.
  - EOF without `done` is an interruption, not a success. Malformed events fail the turn.
  - Error events in HTTP 200 responses map to distinct states: policy, quota, provider error, session not found, document access, network, interrupted and stopped.
  - Every event is checked against the current account and space synchronously. Sign-out, account change, space switch and leaving the screen cancel the request.
- **After `done`:** the confirmed IDs are applied, then history is fetched again. Reactions and branching are enabled only for server IDs. Nothing is ever resent automatically; "Send again" is an explicit user action.
- **Sources:** citations from `meta` render as chips with an excerpt sheet that says they are not saved with the conversation (S4 still open).
- **Menu:** summary (explains that it uses the model and counts toward usage), export (copies Markdown), and share links with a plain explanation of what a link exposes, plus a list of active links with revoke.

Stop and interruption behavior (precise):
- **Stop** aborts the HTTP request on the device. The server sees the disconnect, rolls back the assistant reply and keeps the already-saved user message. No usage event is recorded for that turn, but the provider call may keep running and consume tokens (no server-side cancellation exists). The app then reloads history and shows "You stopped this reply…".
- **Interrupted** (connection lost or EOF without `done`): the app reloads history. If the server did save the reply, the notice disappears and the saved reply is shown; otherwise the notice says the reply was not saved.
- If history cannot be reloaded, the local view stays as it is until the user retries.

Backend changes (backward compatible with the web client):
- **S5:** `meta` carries `user_message_id`; `done` carries `session_id`, `user_message_id` and `message_id`. The web client now replaces its temporary IDs with them.
- **S6:** provider failures are intercepted. The marker is never streamed or stored, no assistant message is saved, usage is still recorded, and the client receives `error` with `code: provider_error` and `partial`.
- Every `error` event carries a `code`. Unexpected exceptions return a generic `internal` error and are logged server-side, without exception text.
- Retrieval is skipped when no documents are selected.
- `pool_pre_ping` on the database engine. Before it, the first request after a client disconnected mid-stream failed with 500 "connection is closed" (reproduced every time; after the fix 9 of 9 follow-up requests returned 200).
- A deterministic local provider stub (below).

**Provider stub:** `CHAT_PROVIDER_STUB=true` works only when `APP_ENV` is `development` or `test`. In any other environment, including the default `production`, the backend refuses to start. The stub never calls a network provider. Directives in the prompt drive scenarios: `[[md]]`, `[[slow]]`, `[[long]]`, `[[fail-before]]`, `[[fail-after]]`, `[[raise]]`.

Verified:
- **Mobile:** formatting, analysis and **147** passing Flutter tests: controller tests for split markers, EOF, malformed events, quota/policy, scope changes, stop, reconciliation, and full-app flows in en/ar × light/dark at 2× text with the keyboard open. Android dev debug APK built.
- **Backend:** **54** pytest tests, including 12 stream tests through the real FastAPI routes (meta/done IDs, provider failure not stored, generic internal error, policy, quota, cross-user and cross-space session access, sources) and the join-request concurrency test.
- **Web:** `tsc -b` passes; lint counts unchanged.
- **End to end:** Android emulator against a local backend with the stub and a local database: Markdown reply and link confirmation, Stop (user message kept, no reply stored), provider failure, leaving the screen mid-stream (cancelled, no reply stored), share link created and revoked (checked on the server), and the Arabic/dark UI at 2× text and 360 dp with the keyboard open. Screenshots are in `docs/mobile/screenshots/phase2/`.

Not done in Phase 2: rename/delete sessions (S2), persisted citations (S4), regenerate/edit, and attachments.

### Phase 3 — Documents and citations
- **Scope:**
  - List documents.
  - Upload with 25 MiB and type validation.
  - Document selection for chat, with `top_k`.
  - Citation sheet.
  - Authenticated open of documents.
  - Chunks view.
- **Backend:**
  - S3: enforce 25 MiB while streaming the request body, including chunked requests without `Content-Length`, and return 413.
  - A configurable processing timeout.
  - S4: persist citations.
  - S8: chunk permission check.
- **Acceptance:**
  - Oversized files are rejected on both client and server.
  - Timeouts never trigger a duplicate upload.
  - Citations survive a restart.
  - The integration test for upload → ask → open citation passes.

**Phase 3 results (2026-10-13, branch `feature/mobile-documents-citations`):**

Backend (details and the behavior found before the changes are in `MOBILE_DISCOVERY.md` §10):
- **Uploads:**
  - New `PUT /documents/uploads/{upload_id}?filename=` takes the raw file body.
  - Authorization runs before a single byte is read.
  - The hard 25 MiB limit (`MAX_UPLOAD_BYTES`) is enforced while streaming, including chunked bodies without `Content-Length`; anything over gets 413 and the partial file is deleted.
  - `upload_id` is chosen by the client. Every accepted ID gets a receipt (`document_upload_receipts`, unique per space, uploader and ID), duplicates included.
  - `GET /documents/uploads/{upload_id}` resolves the receipt, re-checking that the uploader can still read the document; otherwise 404.
  - Repeating an ID with the same bytes returns the original result. Different bytes get 409 `upload_id_reused`.
  - **Deduplication never grants access:** identical bytes already in the space resolve to that document only when the uploader can currently read it. Otherwise the answer is a generic 409 `duplicate_conflict`, with no metadata, no new permission and no change to the original document. Concurrent races resolve through the same checks.
  - The web's multipart routes keep their response shapes. They now go through the same pipeline, plus an ASGI middleware that caps the body before the framework spools it.
- **Validation:**
  - Content is checked by bytes, not by name or client MIME: PDF magic, OOXML structure with zip-bomb bounds, encrypted or legacy Office rejected, UTF-8-only text.
  - Filenames are sanitized (no directories or control characters).
- **Processing:**
  - States are `uploaded → processing → indexing → ready`, or `failed` with a safe code. Each transition is committed on its own; no transaction is open during extraction or embedding.
  - Extraction runs in a child process with a wall-clock limit (`PROCESSING_TIMEOUT_SECONDS`, 300 s) and, on Linux, memory and CPU limits.
  - Indexing replaces a document's vectors (deterministic point IDs plus delete-before-upsert), so a retry or re-index never duplicates. Zero-vector embedding failures now fail the document instead of reporting success.
- **Processing architecture (honest status):**
  - Processing still runs inside the upload request; this deployment has no job queue (S22).
  - Status is readable independently (`GET /documents/{id}`, `/documents/accessible`).
  - Work lost to a restart shows as `failed/interrupted` once its lease (2 × timeout + 60 s) expires.
  - `POST /documents/{id}/retry` (uploader or space admin, retryable codes only) claims the document with one conditional update, so only one retry can run.
  - The server cannot cancel processing.
- **Retrieval:**
  - Only `ready` documents are searched.
  - An explicit selection that is inaccessible or not ready fails with `document_access_denied` / `document_not_ready`; it never widens to all documents.
  - No selection means all of the caller's ready documents in the space.
  - Qdrant now filters by document ID instead of filtering a global top 50.
- **Citations (S4):**
  - Stored as a versioned, bounded record (`v: 1`, at most 12 items, 600-character excerpts, page only when the PDF provides one) on the assistant message, for both the streaming and non-streaming paths. Copied when branching.
  - Every history read re-checks access: sources the reader can no longer read come back as `{"available": false}` with no filename or excerpt.
  - Shares and exports never include them. Stream `sources` no longer contain storage URLs, hashes or sizes.
- **Downloads:** streamed through the API with sanitized `Content-Disposition`, `nosniff`, a sandboxing CSP and `no-store`. Storage URLs never reach clients.
- **Fixed on the way:**
  - `/documents/{id}/chunks` had no per-user check (S8).
  - The `/vector-search` router never passed the space and always failed (500).
  - Branching wrote the new session before checking its space.
  - Concurrent uploads in `/upload-multiple` shared one database session.
- **Local verification support:**
  - Deterministic embedding stub (`EMBEDDING_PROVIDER_STUB`), refused outside development and test like the chat stub.
  - `AWS_S3_ENDPOINT_URL` for a local S3-compatible server.
  - `QDRANT_URL=:memory:` for the test suite.

Mobile:
- **Documents screen:**
  - Search, filters (all, ready, in progress, failed), clear state labels, empty, offline and error states.
  - An upload button only for space admins and members with upload rights.
- **Upload:**
  - System file picker; no storage permissions (the broad permissions a dependency declares are removed in the manifest).
  - Local 25 MB and type checks first.
  - Real byte progress, then an indeterminate "server is processing" state; no percentage is invented.
  - The upload ID is recorded before sending. Uncertain failures and app restarts reconcile with the server by that ID. Nothing is retried automatically.
  - "Cancel upload" / "Stop waiting" stop this device only, and the UI says the server may still process the file.
- **Status:** bounded backoff polling (2–30 s) while anything is active. It pauses in the background, resumes on return, and stops on sign-out, account or space change.
- **Details:** state with an explanation per error code, retry only when the server allows it, "Use in chat", and open.
- **Open:**
  - Authenticated download into an app-private cache directory, per account and space session (sanitized names, one folder per document).
  - Redirects are refused so the token never follows them. Copies are deleted on sign-out or space switch and stale copies on start.
  - The screen explains that copies shared to other apps can't be recalled.
- **Chat:**
  - Document button with a selection sheet (ready documents only).
  - A scope line ("Searching all your ready documents" / "Searching N selected documents").
  - Selection is cleared on account or space change and pruned when documents disappear or stop being ready, with an explanation.
  - "Send again" reuses the turn's exact selection. After a document error the action becomes "Review documents".
  - Persisted citations are shown from history (unavailable ones as "Source unavailable"), with real page numbers and "Open document".
- **Markdown images:** never fetched; a placeholder offers the link, which still asks for confirmation. Link launch failures are reported.

Verified:
- **Backend:**
  - **94** pytest tests (8 for deduplication and receipts, 7 of which fail on the code before the review fix) through the real routes, the real extraction subprocess, a local S3-compatible server (moto), Qdrant local mode and the embedding stub.
  - Coverage: size boundary (exact, +1 byte, real 25 MiB + 1, chunked without `Content-Length`), content and encryption checks, traversal, authorization, cross-user and cross-space access, retry claims, lease expiry, timeout, idempotent re-indexing, selected-document retrieval, citations on both paths plus branching, revocation, hidden documents, shares, legacy multipart and the middleware cap.
- **Disconnect regression:** a new test runs a real uvicorn server with the app's pooled engine. It fails with `500 connection is closed` when `pool_pre_ping` is removed and passes with it.
- **Interruption reconciliation:** the Phase 2 regression test fails without its fix ("Expected null, Actual PendingTurn") and passes with it.
- **Migration:** `20261013_0001` was applied twice to the local e2e database and checked on a scratch copy with legacy rows (`completed` with chunks → `ready`; without chunks → `failed/no_text`; `failed` → `failed/processing_failed`; stuck → `failed/interrupted`) and on a fresh `create_all` schema.
- **Mobile:** **175** Flutter tests, analyze clean, Android dev debug APK built (only the `INTERNET` permission).
- **Web:** `tsc -b` and `vite build` pass; no new lint problems.
- **End to end:**
  - Local backend, local Postgres, moto S3, Qdrant and stub providers; no remote services.
  - API: chunked upload, idempotent upload ID, 413, 415, 403, selected-document retrieval, persisted citation, revocation (citation unavailable, download 404), safe download headers, share without sources.
  - Android emulator: upload (byte progress → processing → ready), PDF with real page citations, oversized file refused locally, select in chat → answer with citations → app restart → citations remain → open the document through the authenticated download in the system PDF viewer → revoked access shown as "Source unavailable" for another user → Arabic, dark, 2× text, 360 dp with the keyboard open.
  - Screenshots are in `docs/mobile/screenshots/phase3/`.

Not done in Phase 3: a chunks view on mobile, document delete (no backend endpoint; admin "hide" stays web-only), and a durable job queue (S22).

### Phase 4 — Remaining user features
- **Scope:** in-app notifications (list, badge, foreground SSE while open, refresh on resume), my requests, usage and invoice PDF, export through the share sheet, profile and preferences, and personal instructions as scoped by D5.
- **Acceptance:** every end-user item in §10 is marked "Mobile v1" and works.

**Phase 4 results (2026-11-02, branch `feature/mobile-user-features`):**

Baseline: `origin/dev` at `38b3d67` (Phase 3 merge); nothing newer. Reused: authenticated SSE parsing, scoped cancellation, private-file and download handling from Phases 2 and 3.

Generation accounting (closes the cancelled-generation blocker S21 as far as it can be closed locally):
- **Ledger:** `generation_attempts` (migration `20261102_0001`). An attempt is committed **before** the provider is called, so a disconnect cannot erase it.
- **Finalization:** one conditional update (`outcome = 'started'`), so completion, failure, cancellation and retries account a turn exactly once.
  - Outcomes: `completed`, `failed`, `cancelled`.
  - `usage_state`: `reported` or `unknown`.
- **Usage rows:** written only when the provider reported tokens. Unknown usage is never stored as zero.
- **Client disconnect:** the stream handler finalizes the attempt from a separate, shielded session as `cancelled` / `client_disconnected`, then closes the provider stream.
  - The OpenAI adapter closes the HTTP stream to the provider from the consumer side when the reply completes, fails, times out or is cancelled. Closing from that side also unblocks a reader thread that is waiting on a stalled provider; the thread then stops without reading or queueing anything more.
  - A provider that sends nothing for `PROVIDER_STREAM_IDLE_TIMEOUT_SECONDS` (default 120) is ended as a provider error and closed.
  - Evidence: the real adapter against a controlled fake upstream (`tests/unit/test_openai_stream_cleanup.py`): completion, upstream error, cancellation while blocked, idle stall, a provider that keeps sending after close, and a cancel while the request is still being created. Every case closes the stream and the worker thread exits. Against the previous adapter the stalled-stream case hung.
  - One worker thread per streamed reply, which ends when the stream closes. Its queue holds only what the provider sent before the close.
  - **Not claimed:** that the provider stops generating or billing when its stream is closed. The provider reports usage only at the end of a stream, so a cancelled turn has unknown usage and no local cost.
- **Quotas:** every attempt with unknown usage (including in-flight ones) counts `QUOTA_UNKNOWN_USAGE_TOKENS` (default 4,000) against token limits, so stopping replies cannot bypass them. This is a quota rule, not recorded usage.
- **Usage reporting:** usage and invoices show these attempts as "no reported usage", and costs as incomplete or unavailable.
- **Conversation limits (review fix, S28):** limits count conversations *started*, from a `conversation_creations` ledger (migration `20261103_0001`), not from existing conversations. Deleting a conversation keeps its ledger row, so it cannot reset a limit.
  - A new conversation and a branch each add one row; continuing a conversation adds none. Branching is checked against the same daily and monthly limits.
  - A per-user, per-space transaction lock serializes check-and-create, so concurrent starts cannot exceed a limit.
  - The usage overview reports conversation limits from the same ledger.
  - Backfill: one row per existing conversation at its original creation time. Conversations deleted before the migration cannot be counted; the delete endpoint ships in the same PR, so none exist in practice.

Backend (all backward compatible):
- `GET /chat/usage/overview?days=1..365`: rolling UTC window, requests with reported and unknown usage (with causes), tokens, estimated cost with `complete` and `requests_without_cost`, per-model and tool rows, and limits as used/remaining or `null` for no limit.
- The invoice PDF says costs are estimates, prints "Unavailable" instead of `$0.0000`, and states how many requests are excluded.
- `PATCH /chat/sessions/{id}` (rename) and `DELETE /chat/sessions/{id}` (messages and share links removed; usage and attempt records kept with an empty session reference). Owner and space only.
- Space requests:
  - Strict per-type payloads; `quota_change` can no longer smuggle `allowed_models`.
  - A `dedupe_key` with a partial unique index makes resubmission return the pending request, even concurrently.
  - Upload or model requests for access the user already has get 409.
- Global `/requests` no longer returns exception text.
- Notifications:
  - Metadata now includes `space_name`, `request_type`, `request_id` and `note`.
  - Live events carry the same fields as the list.
  - The list serializes `metadata` as the web client already expected (it previously sent `notification_metadata`).
- `PATCH /auth/me` updates only `preferred_language` (`en`/`ar`/null) and `industry`. Other fields are rejected.

Mobile:
- **Notifications:**
  - Bell with unread badge, list, mark read and mark all read.
  - Live updates over the authenticated SSE stream (bearer header, never a query token).
  - The authoritative list is reloaded after every (re)connect; events are de-duplicated by ID.
  - Reconnect backoff is 1–30 s. The stream pauses in the background and is discarded on account change.
  - Opening a notification re-checks access with the server (space membership) before navigating. Unreachable targets are explained. Approvals refresh membership and chat models.
- **Usage:**
  - Periods of 24 hours and 7, 30 and 90 days, with the window shown in local time and labelled rolling.
  - Requests and tokens, estimated cost (never shown as zero when unknown), and limits with remaining allowance or "no limit".
  - Per-model and tool rows.
  - The invoice PDF is downloaded through the API into private storage and handed to the system share sheet.
- **Requests:**
  - History with status, reviewer notes and space.
  - Account-level requests read-only.
  - New request form: model access, upload rights, higher limits, other. Tool access is hidden because no tool catalog endpoint exists.
  - Single in-flight submission. An uncertain result reloads the list instead of resending.
- **Conversations:** rename; delete with an explicit confirmation of what is removed and kept; "Share as file" (Markdown through the share sheet) alongside "Copy as Markdown".
- **Account:** reply language (automatic, English, Arabic) saved to the account.
- **Home:** notifications, usage and requests are live; only space administration remains marked unavailable (admins only).

Verified:
- **Backend:** **134** pytest tests (121 plus 13 from the review fixes: conversation-limit deletion bypass for daily and monthly, monthly window, continuing, branching, concurrent starts, user/space isolation, and six adapter cleanup cases), including accounting (completion, missing usage, provider failure, unexpected failure, duplicate finalization, quota reservation, invoice PDF) and the real-uvicorn disconnect (attempt `cancelled` / `unknown`, no usage row, provider stream closed, server healthy). Also requests (contract, smuggling, concurrent dedupe, approval effect, privacy), rename/delete, notifications privacy and metadata, and preferences.
- **Mobile:** **195** Flutter tests, analyze clean, Android dev APK built (still only the `INTERNET` permission).
  - Notifications: dedupe, bounded backoff with authoritative reload, lifecycle, account isolation, read counts.
  - Widget flows: usage with unknown cost, invoice share and refusal, requests and an uncertain submit, rename, share file, delete and cancel, notification to destination, inaccessible target, preferences, and Arabic/English light/dark at 2×.
  - A lifecycle bug in the rename dialog was found by the tests and fixed.
- **Migration:** `20261103_0001` was applied twice to the local e2e database (17 existing conversations backfilled, second run a no-op). `20261102_0001` was applied twice to the local e2e database and checked on a fresh `create_all` schema together with all earlier migrations.
- **End to end** (local backend, Postgres, Mailpit, moto S3, Qdrant, stub providers):
  - API: disconnect accounting, unknown usage, invoice PDF, request deduplication and self-review 403, admin approval delivered live over SSE with metadata, upload permission applied, owner-only rename, delete keeping attempts.
  - Android emulator:
    - Upload request from the device, approved through the local admin API, unread badge updated live.
    - Notification opened to Requests ("Approved" with the note); home showed uploads allowed without signing in again.
    - Usage with unknown cost, then period change, then invoice in the share sheet.
    - Rename, export through the share sheet, delete with confirmation (attempts kept on the server).
    - Arabic, dark, 2× text, 360 dp.
  - Screenshots are in `docs/mobile/screenshots/phase4/`.

Deferred from Phase 4:
- Edit/regenerate (not implemented; no prompt is resent silently).
- Tool-access requests (no tool catalog endpoint).
- Notification delete and background push (D4).
- Personal instructions (D5; per-user `/system-prompts` exists but its scope is unresolved).
- Calendar-month quota periods (the server uses rolling windows).

### Phase 5 — Space administration
- **Scope:** all D1 space-admin items, plus workspace system prompts as specified by D5.

**Phase 5 results (2026-11-11, branch `feature/mobile-space-admin`):**

Baseline: `origin/dev` at `a34d70f` (Phase 4 merge, identical to the reviewed `a279d5b`); nothing newer.

Permission rules (unchanged role model; the server re-checks every call):
- **Space admin** (`space_members.role = admin`, `status = active`, or a global super admin) may: rename the space, list and edit members (role, access, upload right, limit overrides, granted models/tools), invite/resend/revoke, review requests, edit space models/tools and default limits, change document visibility and per-member document access, and read space usage.
- **Members** may: read their own membership (now with `effective_tools`), read the space catalog, create and read their own requests.
- **Outsiders** get 403 on every space route; cross-space ids give 403/404.
- **Last admin:** a change that would leave a space without an active admin (demote or revoke) is refused with 409. The space row is locked first, so two admins demoting each other concurrently leave exactly one.
- **Reviews:** a request is locked and must still be pending (409 otherwise), so concurrent approve/decline applies once with one audit record and one notification. Reviewers cannot review their own requests (403). Each type changes only its own field, read from its own key; legacy payload fields (for example `allowed_models` in a `quota_change`) are ignored. Model/tool approvals must name a supported identifier.
- **Limits:** whole numbers 0–1,000,000,000 (booleans and strings rejected); token limits above 0 have the existing minimums; daily ≤ monthly is checked against the resulting values. A number sets a limit (0 blocks), an explicit `null` clears it (space: unlimited; member: inherit the space default), omitted fields are unchanged. Previously `null` was ignored, so limits could not be removed.
- **Models and tools:** new identifiers must come from `GET /spaces/{id}/catalog` (ids only: chat models the deployment supports, tools registered at startup). Identifiers already stored stay accepted so legacy policies can still be saved.

Secure invitations (closes S10 and S11):
- Tokens: `secrets.token_urlsafe(32)`, delivered only by the configured email service, stored only as SHA-256 (`token_hash`). No API response, list, log line or analytics event contains the token.
- If email delivery fails or is disabled the request fails with 503 and nothing is stored: there is no token-exposure fallback.
- Expiring (7 days), revocable, single use. Accepting locks the invitation row, so concurrent acceptances join once.
- One open invitation per space and address (partial unique index). Inviting again or "resend" rotates the token (the previous link stops working) and increments `send_count`; membership is never duplicated.
- Binding: the signed-in account's current email must equal the invited address (403 otherwise). Changing the account email after the invitation breaks the binding; the admin re-invites the new address.
- Existing active members cannot be invited (409). Revoked or pending members who accept return as ordinary members (earlier admin rights are not restored). Inactive spaces refuse invites and acceptance.
- **Migration `20261111_0001_hashed_space_invites.sql`:** adds the hash and audit columns, renames `cancelled` to `revoked`, marks every pending plaintext invitation **expired** and clears all plaintext tokens. Old links stop working; admins resend from the Invitations screen (expired invitations can be resent).
- **Web:** `/join-space` captures the token into memory before the app renders and removes it from the address bar; nothing is written to local/session storage or the URL afterwards. Sign-in and sign-up return to `/join-space` (in-app navigation keeps the token; a full reload drops it and the emailed link must be opened again). Acceptance is an explicit button. The admin dialog no longer displays tokens. The service worker no longer caches navigations or any URL with a query string and drops the old cache.
- **Mobile:** unchanged contract for acceptance; tokens stay in memory; the dev-only `teia-dev://` scheme and the verified-host rules are unchanged. App Links / Universal Links remain unverified until an owner-controlled domain exists.

Web live notifications (closes S26):
- The stream is opened with `fetch` and the bearer token in the `Authorization` header (the API never accepts query tokens). It reconnects with 1–30 s backoff, reloads the list and unread count after every connect, de-duplicates by id, stops on 401/403, and is closed on logout or account change (state is cleared and late responses from the previous account are ignored).
- The bell component existed but was never mounted, and it read a storage key that does not exist; it is now in the header.

Mobile administration ("Manage space", admins only):
- Entry on the home screen only for an active admin; the membership is re-checked before it opens. Routes under `/admin` redirect non-admins.
- Screens: overview and rename; members (search, role, access, upload right, limit overrides, granted models/tools); invitations (send, resend, revoke); requests (pending/history, approve/decline with note); models and tools; space default limits; document visibility and per-member access; space usage (1/7/30/90 days, cost never shown as zero when unknown).
- Values: "No limit", "0 (blocked)", explicit numbers and "Space default: …" are distinct; each limit saves on its own; setting a space limit to 0 asks for confirmation.
- Confirmations for removing access, demotion (including self), removing granted models/tools, revoking invitations, hiding documents and removing document access.
- Access loss: all admin data lives under an admin scope (`account/space`, admin role). A 403 from any admin call re-checks the membership; losing the role (or switching account or space) drops all admin state and closes the admin screens at once. Late results for a previous scope are discarded.
- Duplicate submissions are blocked while a mutation runs; uncertain outcomes (network, timeout, 5xx other than 503) reload the affected list and say so.
- Members can now request tool access, chosen from the catalog minus the tools they already have.
- Hidden on purpose: creating and deactivating spaces, global settings and global system prompts (web only).

System prompts (D5, S9, S29):
- **Global** prompts (`configs/system_prompts.json`, or `SYSTEM_PROMPTS_PATH`) are the only prompts generation uses. `GET/PUT /system-prompts/global` require a super admin (401 anonymous, 403 members and space admins). The web editor is shown only to super admins and labelled platform-wide.
- **Personal overrides:** `GET/PUT /system-prompts/me` read and write only the caller's own overrides (an empty string removes one) and never return or change global prompts. **They are stored but not applied to replies** (`applied_to_generation: false`), so no app presents them as working; personal instructions stay deferred.
- The former combined `GET/PUT /system-prompts` (global text to any user, personal writes presented as settings) is removed.
- **Workspace prompts: not implemented** (no space-scoped storage or enforcement exists).

Verified:
- **Backend:** **167** pytest tests (134 before; 8 added in review for S29/S7: anonymous, member, space admin and super admin on global prompts, owner-only personal overrides, cross-user isolation, chat unchanged, generation reading the global prompt through the real adapter, super-admin routes reachable and restricted, route order, missing space 404), including invitations (hash-only storage and no token in API or logs, binding, expiry, revocation, resend, replay, concurrent acceptance and creation, email failure, inactive space, revoked member, email change), admin boundaries (member, outsider, admin of another space), last admin (sequential and concurrent), limits (unlimited/0/values, clearing, invalid values), overrides (inherit vs explicit), catalog validation, concurrent review exactly once, self-review, legacy payloads, tool requests, space usage cost and effective tools.
- **Web:** typecheck and production build; **10** Vitest tests (global prompt calls use `/system-prompts/global`; SSE parser, header-only token, backoff and reload on reconnect, 401 stop, abort on close, de-duplication, token capture and URL scrubbing without storage).
- **Mobile:** **222** Flutter tests, analyze clean, Android dev APK built. Admin flows: no entry or route for members, re-check on entry, role loss while a screen is open, 403 re-check, late result after a space switch, distinct limit values, clear-to-default, confirmed zero limit, demotion and last-admin message, cancelled and confirmed access removal, single invitation on double tap, uncertain and email-failure messages, revoke confirmation, approve with note, already-reviewed, own request, models saved from the catalog, document hide and grant, member tool request, and layout in en/ar × light/dark at 2× text on a 320 dp phone.
- **Migration:** `20261111_0001` applied twice to a legacy-shaped table (pending → expired, cancelled → revoked, every plaintext token cleared, second run a no-op) and twice to a current schema.
- **End to end** (local Postgres, Mailpit with STARTTLS, moto S3, stub providers):
  - API script, 23/23: invitation without token in responses, token only in Mailpit, rotation, wrong account 403, superseded token 404, accept, replay 404, revoked 404, member 403 on admin routes, self-review 403, concurrent review once, effective permission and one notification, decline with note, document grant/revoke and member 403, space limit 0 blocks and member override lifts it, invalid limit and unsupported model 422, last admin 409.
  - Web (Chromium): emailed link → token removed from the URL, nothing in storage or caches → sign-up → back on `/join-space` → accept → joined; notification stream opened with no token in the URL, live policy notification shown.
  - Android emulator: admin invites from the app, email arrives; recipient signs in, opens the dev link, accepts, has no admin entry; recipient requests uploads (tool access offered from the catalog); admin approves with a note and declines a tool request; recipient sees both notifications and "uploads allowed"; admin grants then removes document access (member's list changes both ways); admin sets a 0 conversation limit (confirmed) and adds a model; recipient's new conversation is refused by the limit; admin's role is removed by another admin while a member screen is open, and the next action returns to home without administration; Arabic, dark, 2× text.
  - Screenshots: `docs/mobile/screenshots/phase5/`.

### Phase 6 — Verification and release preparation
- **Scope:** full integration suite on Android (emulator and a device) and iOS (macOS), plus accessibility, RTL and performance passes, icons and splash, signing outside the repository, store metadata, privacy forms, and production HTTPS configuration.
- **Acceptance:**
  - Signed release builds.
  - No cleartext traffic and no secrets in the binary.
  - Release checklist signed off.
  - Blocked until the §8 dependencies are resolved.

---

## 7. Backend change register

| ID | Change | Phase | Status |
|---|---|---|---|
| R1 | Owner-controlled HTTPS endpoints | 6 | **External dependency** |
| R2 | Secure share tokens with expiry and revocation | S | **Done in this phase** |
| R3 | Email-only reset tokens, generic response, single use | S | **Done in this phase** |
| R4 | `GET /auth/me` | 1 | **Done (Phase 1)** |
| S1 | change-password returns 400, not 401, for a wrong password | 1 | **Done (Phase 1)** |
| S2 | Rename and delete sessions | 2 | **Done (Phase 4)**; usage/attempt records kept |
| S3 | 25 MiB streaming upload limit (413) and processing timeout | 3 | **Done (Phase 3)** |
| S4 | Persist citations | 3 | **Done (Phase 3)**; re-authorized on every read |
| S5 | Message IDs in `meta` and `done` | 2 | **Done (Phase 2)** |
| S6 | Provider failure as an `error` event, not stored | 2 | **Done (Phase 2)** |
| S7 | Super-admin usage route order (web feature) | 5 | **Done (Phase 5 review)**: fixed `/_superadmin/*` and `/admin/dashboard` declared before `/{space_id}/...`; a super admin on a missing space gets 404 instead of a 500 |
| S8 | Per-user check on `/documents/{id}/chunks` | 3 | **Done (Phase 3)** |
| S9 | Workspace system prompts, space-admin only (D5) | 5 | **Not implemented**: backend has per-user prompts only; no space-scoped storage |
| S10 | Hash space invite tokens and stop returning them to the inviter | 5 | **Done (Phase 5)**: hashed, email-only, expiring, revocable, single use; plaintext invitations expired by migration |
| S11 | Web `/join-space` route so emailed invite links work on the web | 5 | **Done (Phase 5)**: token kept in memory through sign-in/up and removed from the URL |
| S12 | Validate join requests (space exists and active, not already a member, idempotent) and add `GET /spaces/requests/mine` | 1 | **Done (Phase 1)**; concurrency fixed in Phase 2 |
| S13 | Typed `code` on every stream `error` event; generic `internal` error | 2 | **Done (Phase 2)** |
| S14 | `pool_pre_ping` so a client disconnect does not break the next request | 2 | **Done (Phase 2)** |
| S15 | Local chat provider stub, refused outside development and test | 2 | **Done (Phase 2)** |
| S16 | Durable document states, upload receipts for reconciliation, authorized single retry | 3 | **Done (Phase 3)** |
| S25 | Strict space-request payloads and pending-request de-duplication | 4 | **Done (Phase 4)** |
| S26 | Web notification stream sends the token as a query parameter the API ignores, so the web live stream never connects | 5 | **Done (Phase 5)**: header-authenticated fetch stream, reconnect, de-duplication, logout; bell mounted |
| S27 | Invoice PDF printed unknown cost as `$0.0000` | 4 | **Done (Phase 4)** |
| S29 | `GET /system-prompts` returned the global system prompt texts to any signed-in user | 5 | **Done (Phase 5 review)**: `/system-prompts/global` (GET/PUT) super admins only; `/system-prompts/me` own overrides only; combined route removed |
| S30 | Last active admin could be demoted or revoked; concurrent reviews could apply twice; self-review allowed; limits could not be cleared; approvals applied legacy payload fields | 5 | **Done (Phase 5)** |
| S31 | Space usage summed unknown costs as $0; invitation and request emails did not escape space names and notes | 5 | **Done (Phase 5)** |
| S28 | Deleting conversations reset conversation limits (limits counted existing conversations) | 4 | **Done (Phase 4 review)**: start ledger, transaction lock, branch limited |
| S24 | Identical-bytes deduplication granted the uploader access to the existing document (pre-existing) | 3 | **Done (Phase 3 review)**: access re-checked, generic 409, no grant |
| S17 | Content validation by bytes, filename sanitizing, isolated and bounded extraction | 3 | **Done (Phase 3)** |
| S18 | Streaming authorized download with safe headers; no storage metadata in sources | 3 | **Done (Phase 3)** |
| S19 | `/vector-search` router passed no space (always 500) | 3 | **Done (Phase 3)** |
| S20 | Branching checked the space only after writing | 3 | **Done (Phase 3)** |
| S21 | Usage of generations cancelled by a disconnect is not recorded | 2 | **Done locally (Phase 4)**: attempt ledger, unknown-usage quota charge; provider stream closed on every exit path (fake-upstream tests); provider billing after close still unverifiable |
| S22 | Durable job queue for document processing (currently in-request, lease-based recovery) | 3 | Open (recommended before scale) |
| S23 | Embedding service returns zero vectors on failure | 3 | Mitigated (pipeline fails the document); service unchanged |

Deferred: refresh tokens, push device registration (D4), document delete, a job queue for processing (S22), confirmation that the provider stops generating once its stream is closed (unverified locally), pagination.

---

## 8. Release dependencies and risks

**External release dependencies** (none of them block local implementation):

- Staging and production HTTPS endpoints under owner control (D2).
- Availability and ownership of the `com.teia.aiassistant*` identifiers on Google Play and the Apple Developer account (D9).
- Approved brand assets (D9).
- Owner review of flagged Arabic terminology (D3).
- A macOS environment for iOS builds and signing.
- Configured SMTP for password-reset email in each environment. Without it, reset requests are accepted silently and nothing is sent, by design.
- Rotation of the provider keys that were committed to the upstream repository history.
- **Provider charges after a disconnect (S21 remainder):** the attempt is recorded as cancelled with unknown usage and the provider stream is closed, but whether the provider stops generating or billing on close cannot be verified locally; confirm with the provider before release. Costs remain estimates from list prices.
- **Migration order (owner, per environment, never automatic):** `20261011_0001_chat_shares`, `20261012_0001_unique_pending_join_request`, `20261013_0001_document_processing_state`, `20261102_0001_generation_attempts_and_request_keys`, `20261103_0001_conversation_creations`, `20261111_0001_hashed_space_invites`. All are idempotent; each was run only locally.
- **Invitation cutover:** after `20261111_0001`, every invitation sent before it stops working and shows as expired; admins resend the ones still needed. SMTP must be configured, or inviting fails with 503 by design.
- **Migrations to apply per environment (owner, never automatic):** `20261012_0001_unique_pending_join_request.sql` and `20261013_0001_document_processing_state.sql`. The second backfills existing documents (completed with chunks → `ready`, otherwise `failed` with a code), assuming completed web uploads were indexed, as `upload-and-vectorize` always did.
- **Extraction limits:** memory and CPU limits apply on Linux only. The tokenizer (`tiktoken`) downloads its public encoding file on first use unless the image pre-caches it.
- **Phase 1 release items S10 and S11 are closed in Phase 5** (pending owner review and the invitation cutover above).
- **App Links / Universal Links** are not verified: they need the owner-controlled HTTPS host (see setup). Until then invitation links open the web page; on mobile the link can be pasted.
- The join-request migration `20261012_0001_unique_pending_join_request.sql` must be applied by the owner in each environment; it was run only locally.

**Risks:**

- **Synchronous uploads.** Mitigated by the 25 MiB limit, the timeout, and no auto-retry.
- **In-memory notification broadcaster.** It only reaches clients on the same worker, so mobile treats SSE as best-effort and refreshes the list on resume.
- **Production deploys on merge.** A merge of a backend PR into `dev` still triggers `deploy.yml`, which is pre-existing behavior. Only mobile-only changes are excluded. Merges remain owner-controlled.
- **Startup DDL.** The backend runs `Base.metadata.create_all` at startup, so a deployment would also create `chat_shares` implicitly. The explicit SQL migration is the reviewed path, and it is idempotent.

---

## 9. Resolved decisions

| ID | Decision |
|---|---|
| D1 | Mobile includes space administration: members, roles, document permissions, approved models and tools, quotas, requests, usage. Global super-admin operations stay on the web for v1. The backend enforces all authorization. |
| D2 | Development uses the local backend, with HTTP allowed in dev only. Staging and production use owner-controlled HTTPS; no invented domains and no reuse of the production IP. Release builds reject insecure configuration. Missing endpoints are a release dependency. |
| D3 | Arabic and English, with English as the fallback. Full localization, RTL, mixed-language messages and text scaling. Uncertain terms are flagged for owner review. |
| D4 | Authenticated in-app notifications with unread state. Background push is deferred, with no Firebase in v1. |
| D5 | Workspace system prompts are a space-admin feature. Global prompts belong to web super-admins. Personal instructions stay user-scoped. **Verified:** today `GET/PUT /system-prompts` is per-user with no role check and no space scope, so workspace prompts need backend work (S9). |
| D6 | 25 MiB per file, enforced by the server while reading the body, with matching client validation. Processing timeout is configurable, 5 minutes by default. No automatic retries. File types and server-side validation are unchanged. No fake processing percentage. |
| D7 | No screenshot protection in v1. |
| D8 | Feature branches from `origin/dev`, PRs to `dev`, no direct push, no auto-merge, no deployment. The local `Front-End/package-lock.json` change is preserved and stays uncommitted. `deploy.yml` ignores pushes that only touch `mobile/**` or `docs/mobile/**`. |
| D9 | Display name "TEIA AI". IDs `com.teia.aiassistant`, with the suffixes `.dev` and `.staging`. All provisional. Temporary icon. |
| D10 | Backend changes go into `arabaya3/AI-MOBILE-AGENT` on feature branches from `dev`. No original TEIA repository is modified. |
| D11 | Android 8.0+ (API 26) and iOS 15+. Compatible with Flutter 3.41.6; package floors are checked in Phase 0. |

---

## 10. Feature parity matrix

| Capability | Web (dev) | Mobile v1 | Notes |
|---|---|---|---|
| Login / register / logout | ✔ | ✔ | |
| Forgot / reset password | ✔ (fixed in S) | ✔ | Email link, deep link |
| Email verification | ✘ (model only) | ✘ | Not implemented in the backend |
| Profile view and edit | Local only | ✔ (after R4) | |
| Change password | ✔ | ✔ | |
| Space list / switch / accept invite / request access | ✔ | ✔ | |
| Chat sessions, history, streaming | ✔ | ✔ (Phase 2) | Stop is device-only |
| Rename / delete session | ✘ | ✔ (Phase 4) | Usage records kept |
| Model selection | ✔ | ✔ (Phase 2) | Server policy |
| Copy / regenerate / edit / branch / react | Partial | Partial (Phase 2) | Copy, branch, react done; regenerate/edit later |
| Citations | ✔ (Phase 3: from history) | ✔ (Phase 3) | Persisted, re-authorized on read; real pages only |
| Summary | ✔ | ✔ (Phase 2) | |
| Export md/json | ✔ | ✔ Markdown (Phase 4) | Share sheet file and copy; JSON export on web only |
| Share links (create / revoke) | ✔ (create; fixed in S) | ✔ (Phase 2) | Revocation UI on mobile; web gets the API |
| Document upload / list / open / chunks | ✔ | ✔ upload, list, status, retry, open (Phase 3); chunks view later | 25 MiB, states, upload IDs |
| Document delete | ✘ (admin hide) | ✘ | No backend endpoint; hide stays web-only |
| In-app notifications | ✔ (Phase 5, S26 fixed) | ✔ (Phase 4) | Live over header-authenticated SSE on both |
| Background push | ✘ | ✘ (deferred, D4) | |
| Requests (space) | ✔ | ✔ own requests (Phase 4), tool access (Phase 5), review for admins (Phase 5) | Self-review refused |
| Usage and invoice PDF | ✔ | ✔ (Phase 4) | Unknown usage and cost explicit |
| Personal instructions | ✘ (stored via `/system-prompts/me`, not applied to replies) | ✘ deferred (D5) | Not used by generation |
| **Space admin**: members, roles, access, upload rights, overrides | ✔ | ✔ (Phase 5) | Last active admin protected |
| Space admin: invitations (send, list, resend, revoke) | ✔ send only; tokens no longer shown | ✔ (Phase 5) | Tokens only by email |
| Space admin: request review | ✔ | ✔ (Phase 5) | Exactly once |
| Space admin: models and tools, default limits | ✔ | ✔ (Phase 5) | From the catalog |
| Space admin: document visibility and access | ✔ | ✔ (Phase 5) | |
| Space admin: usage | ✔ (+ dashboard charts) | ✔ totals and per model (Phase 5) | Dashboard charts web only |
| Rename space | ✔ | ✔ (Phase 5) | |
| Deactivate space | ✔ | ✘ **Web only** | Irreversible from the app; inactive spaces disappear from lists |
| Invitation acceptance by link | ✔ `/join-space` (Phase 5) | ✔ dev link / paste | Verified links need the owner domain |
| Workspace system prompts | ✘ (per-user only) | ✘ **Missing capability** | No space-scoped storage or enforcement in the backend (S9) |
| **Super admin**: all spaces, global usage, global admin dashboard, global user requests, user list | ✔ | ✘ **Web only in v1** | D1 |
| Global system prompts | ✔ super admins only (Phase 5 review) | ✘ **Web only** | D5, S29 |
| Create space (global admin) | ✔ | ✘ **Web only in v1** | Global operation |
