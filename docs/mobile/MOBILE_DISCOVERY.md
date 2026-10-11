# TEIA Mobile — Discovery

| | |
|---|---|
| Source branch | `dev` |
| Commit | `a02aa7191485041981b1f166ee517195cf210482` (`origin/dev`) |
| Date | 2026-10-11 |
| Method | Direct reading of `src/` (FastAPI) and `Front-End/src/` (React). Documentation treated as secondary. |
| AGENTS.md | None present in the repository. |

Status legend: **Implemented** (backend + web client work end-to-end), **Incomplete** (partially built or functionally broken), **Described only** (docs or DB model only, no working route).

All backend routes are mounted under `/api/v1` (`src/main.py:150-158`). Error bodies use FastAPI's default `{"detail": ...}`; 422 returns a `detail` array. The rate limiter returns **plain-text** 429.

---

## 1. Cross-cutting contracts

### 1.1 Authentication tokens

| Aspect | Finding | Evidence |
|---|---|---|
| Format | JWT, HS256 (`JWT_ALGORITHM`), signed with `SECRET_KEY` | `src/core/security/auth.py:18-47`, `config.py:30-32` |
| Claims | `sub` = user id, `scopes` = `[role]`, `exp` | `auth.py:18-35`, `auth/handlers.py:43-46` |
| Lifetime | `JWT_EXPIRATION_HOURS`, default 24. Login response returns `expires_in` in seconds. | `config.py:32`, `auth/handlers.py:41` |
| Validation | `OAuth2PasswordBearer` → `_get_user_from_token`. 401 if invalid, user missing or inactive. | `dependencies.py:15-43` |
| Refresh tokens | **None.** No refresh route, claim or table. | `auth/router.py` |
| Logout | **None server-side.** Token remains valid until `exp`. | — |
| Profile endpoint | **None** (`/me` does not exist). Web client derives id/role from JWT and email from the login form. | `Front-End/src/context/AuthContext.tsx:43-64` |

Consequence for mobile: an expired or invalid token can only be handled by re-login. A role change is not visible until the next login.

### 1.2 Active space

- Header `X-Space-Id` (fallback query `?space_id=`), resolved by `get_current_space_id` (`src/modules/apis/dependencies.py:59-109`).
- Missing header → user's first active space; super_admin without membership → newest active space; otherwise 400.
- A space the caller is not an active member of → 404 "Space not found".
- `/spaces/{id}/...` routes take the space from the path instead.

### 1.3 Rate limiting and CORS

- Global middleware on `/api/*`: `RATE_LIMIT_PER_MINUTE` (default 300) keyed by `client_ip + path`, 429 plain text with `X-RateLimit-*` headers (`src/main.py:84-105`). No stricter auth-specific limit or lockout.
- CORS has an explicit origin list (`config.py:125-131`). Irrelevant for native Android/iOS; relevant only if Flutter Web is ever targeted.

### 1.4 Transport security

- Production web points at `http://87.106.87.218:8001/api/v1` (`Front-End/.env.production`, `client.ts:4-32`) — **plain HTTP on a raw IP**. iOS App Transport Security and Android's default cleartext policy block this. A TLS hostname is required for mobile release.

---

## 2. Capability map

### 2.1 Authentication and account

| Capability | Backend | Web client | Status |
|---|---|---|---|
| Login | `POST /auth/login` `{email, password}` → `{access_token, token_type, expires_in}`; 401 invalid, 403 inactive (`auth/router.py:46`) | `api/auth.ts`, `AuthContext.tsx:100-111` | Implemented |
| OAuth2 form login | `POST /auth/token` (form `username`, `password`) (`auth/router.py:65`) | Swagger only | Implemented |
| Registration | `POST /auth/signup` → 201 `{user_id, email, role}`. Fields: `email`, `password` (≥8), `role` (default viewer; elevated roles require admin token), optional `first_name`, `last_name`, `date_of_birth` (18+), `phone_number`, `country`, `job_title`, `company`, `industry`, `preferred_language`. 409 on duplicate. (`auth/router.py:35`, `auth/schemas.py:20`) | `AuthPage.tsx`; auto-login after signup | Implemented |
| Email verification | `User.email_verified` column and `EmailVerification` table only (`models.py:58, 283-295`) | — | **Described only** |
| Forgot password | On `dev`: token in body for existing accounts (500 on Postgres), no email — see §7.2. **Fixed in Phase S.** | `api/auth.ts` | Fixed (Phase S) |
| Reset password | `POST /auth/reset-password` `{token, new_password}` (1h TTL) | `api/auth.ts` | Implemented |
| Validate reset token | Web calls `POST /auth/reset-password/validate` (`api/auth.ts:79-80`) — **route does not exist** | | **Broken** |
| Change password | `POST /auth/change-password` `{current_password, new_password}`. Wrong current password returns **401**, which the web interceptor treats as session expiry. | `UserProfileSettingsDialog.tsx` | Implemented, with contract defect |
| Session expiry | No refresh. Web client clears storage on any 401 and emits `teia-auth-changed` (`client.ts:58-70`). | | Implemented (re-login only) |
| Profile read/update | **No endpoint.** Profile columns are written only at signup. `industry` / `preferred_language` edited in the web app are kept in localStorage and sent per chat request as `user_industry` / `user_language`. | `UserProfileSettingsDialog.tsx`, `AuthContext.tsx:173-180` | **Incomplete** |
| User list (admin) | `GET /auth/users` → `{users: [{user_id, email, role}]}`, global admin/super_admin | Admin dialogs | Implemented |
| User update / deactivate | None. `User.*_override` columns unused. | | **Described only** |

### 2.2 Spaces, membership, roles

Roles — global `User.role`: `super_admin | admin | viewer`. Space `SpaceMember.role`: `admin | member`; status `active | pending | revoked`. Invites expire after 7 days.

| Capability | Backend (`spaces/router.py`) | Auth | Status |
|---|---|---|---|
| List my spaces | `GET /spaces` → `SpaceSummary[]` (`{id, name, s3_bucket, is_active, created_at, policy}`) | user | Implemented |
| Available spaces | `GET /spaces/available` | user | Implemented |
| Create space | `POST /spaces` `{name}` → 201; 503 without storage bucket | global admin | Implemented |
| Rename / deactivate | `PATCH /spaces/{id}` `{name?, is_active?}`; `DELETE /spaces/{id}` (soft) | space admin | Implemented |
| Invite / accept | `POST /spaces/{id}/invites` `{email}` (sends email); `POST /spaces/invites/accept` `{token}` | admin / user | Implemented |
| My membership | `GET /spaces/{id}/me` → `{space_id, user_id, role, status, can_upload_documents, overrides}` | member | Implemented |
| Members | `GET /spaces/{id}/members`; `PATCH /spaces/{id}/members/{user_id}` `{role?, status?, can_upload_documents?, overrides?}` | space admin | Implemented |
| Policy | `PATCH /spaces/{id}/policy` (allowed models/tools, daily/monthly token, request and tool limits) | space admin | Implemented |
| Space requests | `POST /spaces/{id}/requests` `{type: join\|model_access\|tool_access\|quota_change\|upload_access\|other, payload}`; `GET …/requests?status=`; `POST …/requests/{rid}/review` `{decision: approved\|declined, note?}` — approval applies the change, notifies and emails | member / admin | Implemented |
| Space usage | `GET /spaces/{id}/usage?days=30` | space admin | Implemented |
| Dashboards | `GET /spaces/admin/dashboard` (global admin), `GET /spaces/{id}/dashboard` (space admin) → `DashboardStats` | admin | Implemented |
| Super-admin spaces | `GET /spaces/_superadmin/spaces` | super_admin | Implemented |
| Super-admin usage | `GET /spaces/_superadmin/usage` is **shadowed** by `GET /{space_id}/usage` declared earlier (`router.py:191` vs `:209`) | super_admin | **Broken** |
| Switching | Client-side only: store id, send `X-Space-Id`. Web re-polls `GET /spaces` every 60 s. | | Implemented |

### 2.3 Chat

Routes in `src/modules/apis/v1/chat/router.py`, handlers in `chat/handlers.py`.

| Capability | Backend | Status |
|---|---|---|
| Create session | Implicit on first message without `session_id`; title = first 60 chars. Counts against conversation quota. | Implemented |
| List sessions | `GET /chat/sessions` → `[{id, title?, created_at, updated_at}]`, newest first, **no pagination** | Implemented |
| History | `GET /chat/sessions/{id}` → `{session, history: [{id, role, content, created_at}]}`, **no pagination, no sources** | Implemented |
| Rename / delete session | None | **Not implemented** |
| Summary | `GET /chat/sessions/{id}/summary` → `{session_id, summary, message_count}` (LLM call, billed) | Implemented |
| Streaming query | `POST /chat/query/stream` (see §3) | Implemented |
| Non-stream query | `POST /chat/query` → `{session_id, reply, sources, history}`; supports tool calling; ignores `user_industry`/`user_language` | Implemented |
| Models | `GET /chat/models` (allowed for caller), `GET /chat/models/all`, `GET /chat/models/pricing` | Implemented |
| Regenerate | Client-only: resend previous user text. Server appends a duplicate pair. | **Incomplete** |
| Edit message | Client-only truncation; server history keeps the original. | **Incomplete** |
| Branch | `POST /chat/sessions/{id}/branch` `{from_message_id}` → `{session_id}`. Needs real message IDs (stream does not return them). | Implemented |
| Feedback | `POST /chat/messages/{id}/reaction` `{reaction: up\|down}` (upsert). No read-back or removal. | Implemented (write-only) |
| Copy | Not in web UI | Not implemented (client-side feature) |
| Citations | `VectorSearchMatch {chunk_id, score, document_id, filename, file_type, chunk_index, text, metadata}` in `meta.sources`. **Not persisted**; web caches in `sessionStorage`. | Implemented (ephemeral) |
| Export | `GET /chat/sessions/{id}/export?format=json\|md` — no `Content-Disposition` | Implemented |
| Share | `POST /chat/sessions/{id}/share` → `{share_id: <session_id>, share_url: "/api/v1/chat/shared/<id>"}`. `GET /chat/shared/{id}` has **no authentication** and accepts **any** session id. No share table, expiry or revocation. No viewer page. **Replaced in Phase S (§7).** | Fixed (Phase S) |

Model policy (`chat/handlers.py:154-204`): allowed = space list ∪ member list, else `DEFAULT_ALLOWED_MODELS`. `STRICT_MODEL_SELECTION=True`. Web client remembers the choice in `teia_chat_model`.

### 2.4 Documents and retrieval

Routes in `src/modules/apis/v1/documents/router.py`.

| Capability | Backend | Status |
|---|---|---|
| Upload + index (used by web) | `POST /documents/upload-and-vectorize`, multipart field `file` → `{upload: {...}, vectorization: {...}, message}`; 422 if no text extractable | Implemented |
| Upload only / multiple | `POST /documents/upload` (`file`), `POST /documents/upload-multiple` (`files`, fragile on partial failure) | Implemented / fragile |
| Allowed types | Extension check only: pdf, docx, xlsx, csv, pptx, txt, json, jsonl, html, htm, md, markdown (`service.py:34-73`). Web picker: pdf, docx, xlsx, csv, pptx, txt. | Implemented |
| Size limit | `MAX_FILE_SIZE_MB=100` defined but **never enforced** (`security/validator.py` unused) | **Missing** |
| Processing | **Synchronous** inside the request (extraction, OCR fallback, chunking, embedding). Status values exist (`pending/processing/completed/failed`) but only final states are written. | Implemented (blocking) |
| Status polling | None | Not implemented |
| Duplicates | SHA-256 per space; returns existing record | Implemented |
| List | `GET /documents/accessible` → `[{id, filename, file_type, uploaded_at, uploaded_by_user_id, is_hidden}]`, no pagination, no status | Implemented |
| Selection for chat | `document_ids[]` + `top_k` (1-30) in chat request. UI label "chunks per doc" is actually total chunks. | Implemented |
| Download / preview | `GET /documents/{id}/download` → bytes, `Content-Disposition: inline`, auth header required (no presigned URLs) | Implemented |
| Chunks | `GET /documents/{id}/chunks` — **space check only, no per-user permission check** | Implemented, permission gap |
| Delete | **No endpoint**; admin can hide via `PATCH /documents/{id}/visibility` `{is_hidden}` | Not implemented |
| Permissions | `POST/DELETE /documents/permissions` `{user_id, document_ids[]}`, `POST /documents/permissions/status` (space admin). Upload requires super_admin, space admin, or `can_upload_documents`. | Implemented |
| Standalone search | `POST /documents/vector-search` works; `POST /vector-search` raises TypeError (missing `space_id`) | Partially broken |
| Legal module | `src/modules/apis/v1/legal/*` are empty files, not registered | Leftover — ignore |

Retrieval filters allowed documents **after** a top-50 dense search (`documents/service.py:398-482`), so selected documents can be missed in large spaces.

### 2.5 Notifications

| Capability | Backend (`notifications/router.py`) | Status |
|---|---|---|
| List | `GET /notifications/?unread_only&limit≤100&offset` → `[{id, user_id, space_id?, type, title, message, link?, metadata, read, created_at}]` | Implemented |
| Unread count | `GET /notifications/unread-count` → `{count}` | Implemented |
| Mark read / all / delete | `POST /{id}/read`, `POST /mark-all-read`, `DELETE /{id}` | Implemented |
| Live stream | `GET /notifications/stream` SSE: `event: connected`, `event: notification`, `: keepalive` every 30 s. Requires Bearer header; the declared `?token=` is ignored. **In-memory, single process only.** | Works with header; **broken in web client** (wrong storage key, EventSource can't send header) |
| Producers | Space request review, policy update. `notify_quota_warning` never called. | Partial |
| Email | SMTP (`EMAIL_ENABLED` default false): invites, request status | Implemented, off by default |
| Mobile push (FCM/APNs) | **None** — no device-token model or endpoint | Described only (`docs/IMPLEMENTATION_SUMMARY.md:267-268`) |

### 2.6 Requests, usage, quotas, cost

- **Space requests** (§2.2): the working approval workflow.
- **Global `/requests`** (`requests/router.py`): `POST /requests/` `{request_type, payload}`, `GET /requests/`, `PUT /requests/{id}` `{status, admin_response?}`. Approval has **no side effect** and status is unvalidated → **Incomplete**.
- **Quota enforcement** is server-side in chat handlers: token (`handlers.py:240-266`), conversation (`:269-291`), tool (`:61-78`). Rolling 1-day / 30-day windows; member overrides space.
- **Usage endpoints**: `GET /chat/usage`, `/chat/usage/summary?days`, `/chat/usage/invoice?days` (includes `alerts` at 80 % of limits), `/chat/usage/invoice/pdf` (attachment).

### 2.7 System prompts

`GET/PUT /system-prompts` — five prompt fields stored **per user** in `User.custom_system_prompts`, **no role check**, although the web UI surfaces them in admin dialogs. Implemented; product intent unclear.

### 2.8 Theme and languages

- i18next configured for **`en` and `ar`** (~13 keys) but **no component uses translations**; UI is effectively English only (`Front-End/src/i18n.ts`).
- **No RTL support** in the web client.
- Response language is separate: `preferred_language` sent per chat request as `user_language`; Arabic text streams as UTF-8.
- Theme (`light`/`dark`, OS default) and industry palette are client-only localStorage.

---

## 3. Streaming contract (`POST /api/v1/chat/query/stream`)

**Request** (`chat/schemas.py:35-58`):

```json
{"message": "…", "session_id": "uuid?", "document_ids": ["…"], "top_k": 10,
 "model": "gemini-2.5-flash-lite", "user_industry": "…", "user_language": "ar"}
```

**Response**: `text/event-stream`, frames `event: <name>\ndata: <json>\n\n`, no `id:`/`retry:`, no cache headers.

| Event | Data | Notes |
|---|---|---|
| `meta` | `{"session_id": "…", "sources": [VectorSearchMatch]}` | Once, before deltas |
| `delta` | `{"text": "…"}` | Many; web-search path sends one large delta |
| `done` | `{}` | Terminal success |
| `error` | `{"detail": "…"}` | Terminal; no `done` follows |

Behaviour that a client must handle:

1. Policy and quota failures arrive as `error` events with **HTTP 200**; quota errors look like `"429: Daily token limit reached"` (`handlers.py:828-909, 1032-1034`).
2. Provider failures arrive as **`delta` text** containing `\n\n[stream_error] …`, followed by `done`, and are **saved into history** (`openai/chat.py:600-602`).
3. No message IDs or usage in the stream — refetch `GET /chat/sessions/{id}` after `done`.
4. **Cancellation**: no endpoint; server never checks disconnects. On disconnect, `CancelledError` rolls back the assistant message, the already-committed user message remains, and the provider thread keeps consuming tokens.
5. HTTP errors before streaming: 401, 404 (space), 422.

The web client parses with `fetch` + `ReadableStream` (`Front-End/src/api/chat.ts:94-152`).

---

## 4. Required vs. recommended API changes for mobile

### Required (blocking a secure or functional mobile release)

| # | Change | Reason |
|---|---|---|
| R1 | HTTPS endpoint with a hostname | iOS ATS / Android cleartext policy |
| R2 | **Done (Phase S)** — Secure sharing: share table with random token, owner-only creation, revocation; stop serving arbitrary session ids unauthenticated | Current endpoint exposes every conversation |
| R3 | **Done (Phase S)** — Stop returning `reset_token` from `/auth/forgot-password`; send it by email with a deep link | Account takeover risk |
| R4 | `GET /auth/me` returning id, email, role, profile fields | Mobile cannot otherwise display or refresh identity |

### Strongly recommended

| # | Change | Reason |
|---|---|---|
| S1 | `change-password` wrong password → 400/403, not 401 | Prevents forced logout |
| S2 | Rename / delete session endpoints | Basic chat hygiene on mobile |
| S3 | Server-side file size limit (enforce `MAX_FILE_SIZE_MB`) | Mobile uploads over cellular |
| S4 | Persist citations with assistant messages | Citations vanish after reload on any client |
| S5 | Include assistant `message_id` in `done` | Reactions/branching right after streaming |
| S6 | Distinct `error` event for provider failures instead of `[stream_error]` delta text | Reliable error UI |
| S7 | Fix `/_superadmin/usage` route order | Broken admin feature |
| S8 | Per-user permission check on `/documents/{id}/chunks` | Data exposure inside a space |

### Optional / later

Refresh tokens, push notification device registration (FCM/APNs), document delete, async upload with status, stream cancel endpoint, pagination for sessions/history/documents, `PATCH /auth/me` for profile.

---

## 5. Mobile-relevant web UI observations

- `MobileDrawer.tsx` (used) exposes: New chat, Manage access, Space admin, Super admin, Diagnostics, Summary, Usage, Export — gated by role and state.
- `MobileBottomBar.tsx` (New / Sessions / Docs / Menu) is **not imported** — dead code.
- Web stores: `teia_access_token`, `teia_user_profile`, `teia_active_space_id`, `teia_chat_model`, `teia_chat_top_k`, `theme-mode`.

## 6. Repository health relevant to mobile work

- **Tests**: `tests/{unit,integration,e2e}` contain only `__init__.py` — effectively none.
- **CI**: only `.github/workflows/deploy.yml` (SSH deploy as root to `87.106.87.218` on push to `dev`/`main`; no lint/test). Any push to `dev` triggers a production deploy attempt.
- **Secrets**: the upstream repository history contains live provider keys in `.env-local` (removed from this copy). They must be rotated.
- **Local tooling** (this machine): Flutter 3.41.6 / Dart 3.11.4, Android SDK, JDK 21, Windows only — **iOS builds cannot be verified here**.

---

## 7. Security phase verification (2026-10-11)

These claims were re-verified against code and a local Postgres before any change was made. Corrections to §2–4 are listed below.

### 7.1 Shared conversations: confirmed
- `GET /chat/shared/{share_id}` had no auth dependency. It loaded **any** `ChatSession` by id and returned its full history (`chat/router.py` and `handle_get_shared_session` on `dev`).
- `POST …/share` returned the session id itself as the "share id". There was no share record, expiry or revocation.
- **Additional defect found:** the web client built the link as `origin + "/api/v1" + share_url`. Because `share_url` already starts with `/api/v1`, every copied link was `/api/v1/api/v1/...`, so it was broken in practice. The exposure was nonetheless real for anyone who knew or obtained a session id.
- **Additional exposure:** the request middleware and uvicorn access logs record URL paths. The fix therefore masks share tokens in application logs, metrics labels, the rate-limit key and uvicorn access-log arguments.

### 7.2 Password recovery: confirmed, with a correction
- The code returned `reset_token` in the `/auth/forgot-password` body for existing accounts, and used a different message for unknown ones.
- **Correction:** on PostgreSQL, the request for an *existing* account actually fails with HTTP 500 before the token is returned. `create_password_reset_token` writes a timezone-aware datetime into a `timestamp without time zone` column (asyncpg `DataError`).
  - This was reproduced by running the new regression tests against `origin/dev`: 9 of 9 failed.
  - The practical vulnerability was therefore **account enumeration** (500 vs 200), not token disclosure.
  - The token-disclosure code path still existed and would leak on any database or driver that accepted the value.
- **Additional defects found:**
  - The web client called `POST /auth/reset-password/validate`, which did not exist, so applying a reset always failed.
  - The email reset link pointed at `/reset-password`, which the web router redirects to `/auth` while discarding the token.
  - Earlier tokens stayed valid after a new request.
  - Tokens were not invalidated after a password change.
  - The single-use check had no row lock.

### 7.3 Status after Phase S
| Item | Before | After |
|---|---|---|
| Share access | Any session id, unauthenticated | Random 256-bit token, stored as SHA-256. 7-day default and 30-day maximum expiry. Owner-only creation, listing and revocation. Requires an active space and an active owner membership. Snapshot limited to user/assistant messages up to the moment of sharing. No ids, emails, metadata or document URLs. `Cache-Control: no-store`. |
| Reset request | Token in body; 500 vs 200 enumeration | Identical generic 200 for known, unknown and inactive accounts. Token delivered only by email through a background task. If email is disabled, no token is created and only the user id is logged. |
| Reset tokens | Reusable after a new request; aware/naive crash | Hashed, configurable TTL (60 min), single-use with a row lock. All outstanding tokens are invalidated on a new request and after a successful reset. |
| Web flow | Validate endpoint missing; email link lost the token | `POST /auth/reset-password/validate` added; the email link targets `/auth?token=…`. |
