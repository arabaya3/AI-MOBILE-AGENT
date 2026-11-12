# TEIA staging deployment package — readiness (2026-11-12)

Package for owner review. **Nothing has been deployed or changed on 65.108.244.83** (no containers, swap, Caddy edit, network attachment, DNS, firewall or migration). Local verification used Docker Desktop on the development machine, synthetic accounts, the local Mailpit sink and stub providers; no paid provider was called and no real email was sent.

## Verified locally

| Check | Evidence |
|---|---|
| Compose and config validation | `./validate.sh` passes on a filled env file (compose renders, **no host ports published**, origins https-only and not production/local, embedding size matches the model, stubs off) and refuses the blank template (every missing secret and weak value listed, no values printed) |
| Caddy patch | `caddy validate` with `caddy:2.8-alpine` (v2.8.4, the installed major/minor) on the two TEIA site blocks appended after a stand-in existing site: "Valid configuration" |
| Isolation | from `teia-staging-edge` only `teia-staging-api` and `teia-staging-web` resolve; db/qdrant/objects do not; `teia-staging-internal` has no internet; the API reaches HTTPS and SMTP via `teia-staging-egress` |
| All services healthy | api, db (Postgres 16), qdrant (v1.15.5), objects (SeaweedFS 3.97), web (nginx) |
| Functional journey on the stack | 23/23 (auth, spaces, invitations via Mailpit, request review, document grant/revoke, limits, last-admin rule) with SeaweedFS storage and the Qdrant server |
| Redis not needed | the stack runs with `REDIS_ENABLED=false`; Redis only backs the rate-limit cache, which falls back to in-process memory (one worker); the journey and all Phase 4–6 end-to-end runs used no Redis |
| One processing operation at a time | new deployment-wide gate (`MAX_CONCURRENT_DOCUMENT_PROCESSING`, Postgres advisory locks) on the streaming upload, legacy upload, retry and re-index routes: 5 backend tests (concurrent uploads → one 201, others 503 `processing_busy` with Retry-After and nothing stored; retry and re-index refused while busy without claiming; lock released after a crash; N=2 allows exactly two; 0 = unlimited); on the stack two simultaneous uploads gave 201 + 503. Mobile shows a specific "another document is being processed" message (test) |
| Startup refuses weak secrets | non-local `APP_ENV` with an empty, default (`change-me`) or short `SECRET_KEY`, or a wildcard CORS origin, stops startup (11 tests) |
| Backend / mobile | backend **228** tests; Flutter format and analyze clean, **267** tests |
| Swap script | `bash -n` clean; `apply` refuses without `--yes`; `check` refuses unsupported filesystems (the server root is ext4) |

### Measured memory (cgroup `memory.peak`, local Docker Desktop, stub embeddings)

| Service | Proposed | Result | Final limit | Peak at final limit |
|---|---|---|---|---|
| api (incl. extraction subprocess) | 1 GiB, extraction 512 MiB | 512 MiB extraction failed a valid 24 MiB CSV (`MemoryError` → `too_complex`); 768 MiB failed too; 1024 MiB processed it (10,992 chunks); peak 843 MiB at 1 GiB | **1280 MiB**, extraction **1024 MiB** | 779 MiB |
| db | 384 MiB | fine | 384 MiB | 248 MiB |
| qdrant | 512 MiB | fine | 512 MiB | 308 MiB |
| objects | 256 MiB (MinIO) | MinIO images not pullable (Docker Hub repository unavailable, quay.io 401) → SeaweedFS; at 256 MiB it **restarted during a 25 MB upload** | **512 MiB** | 424 MiB |
| web | 64 MiB | fine | 64 MiB | 15 MiB |
| **Total limits** | 2.25 GiB | | **2.69 GiB** | ≈ 1.8 GiB summed peaks |

Server context (from the read-only assessment): 3.7 GiB RAM, ~2.8 GiB available, no swap, MedicalHub containers unlimited. With the revised limits TEIA fits **only with the 4 GiB swap file** as a safety margin; peaks were measured one upload at a time on a faster machine, with stub embeddings (real embeddings add network time, not API memory). These are tested targets, not verified server capacity.

## Unverified until deployment

- DNS and certificates for `teia-api.65-108-244-83.sslip.io` / `teia.65-108-244-83.sslip.io` (proposed; sslip.io is third-party DNS with Let's Encrypt rate limits).
- Caddy validation inside the running IIH IVR container and its graceful reload; behaviour of the existing site afterwards.
- Real provider embeddings/chat and SMTP delivery; memory on the actual server; image build time on 2 vCPU.
- The provider spending limit (configured in the provider console; not enforced or verified by this package).
- Backups to a real off-host destination and a restore rehearsal (procedure in BACKUP.md).

## Blocked on owner inputs

- Staging **SMTP** account.
- Staging **AI provider credential**.
- **Off-host backup destination**.
- **Android signing material** (for the pilot APK, see docs/mobile/ANDROID_PILOT.md; not needed for the server).

## Approvals required before deployment

- Accept co-location of TEIA staging with **MedicalHub** (medical data) on the same host.
- Approve the concrete host changes: the 4 GiB swap file (`host/swap.sh`) and the **IIH IVR Caddy** change (two site blocks appended, `teia-staging-edge` attached, graceful reload; `caddy/README.md`).

## Notes for the owner

- The API image is built from `requirements.lock.txt` (exact versions taken from the image that ran the full app in Phases 5–6) instead of the repository's Poetry setup, which has no lock file and installs PyTorch via sentence-transformers although nothing imports it with reranking off.
- The web image installs from `package.json` without the lock file (the committed lock file is out of sync), so web builds are not byte-reproducible yet.
- The new startup guard also applies to production: before this backend is deployed anywhere outside development, its `SECRET_KEY` must be at least 32 random characters.
