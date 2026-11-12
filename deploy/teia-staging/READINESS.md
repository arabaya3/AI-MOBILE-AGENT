# TEIA staging deployment package — readiness (2026-11-12)

Package for owner review. **Nothing has been deployed or changed on 65.108.244.83** (no containers, swap, Caddy edit, network attachment, DNS, firewall or migration). Local verification used Docker Desktop on the development machine, synthetic accounts, the local Mailpit sink and stub providers; no paid provider was called and no real email was sent.

## Verified locally

| Check | Evidence |
|---|---|
| Compose and config validation | `./validate.sh` passes on a filled env file (compose renders, **no host ports published**, origins https-only and not production/local, embedding size matches the model, stubs off) and refuses the blank template (every missing secret and weak value listed, no values printed) |
| Caddy patch | `caddy validate` with `caddy:2.8-alpine` (v2.8.4, matching the installed major/minor version) on the TEIA snippet and site blocks appended after a stand-in global block and existing site: "Valid configuration" |
| Isolation | from `teia-staging-edge` only `teia-staging-api` and `teia-staging-web` resolve; db/qdrant/objects do not; `teia-staging-internal` has no internet; the API reaches HTTPS and SMTP via `teia-staging-egress` |
| All services healthy | api, db (Postgres 16), qdrant (v1.15.5), objects (SeaweedFS 3.97), web (nginx) |
| Functional journey on the stack | 23/23 (auth, spaces, invitations via Mailpit, request review, document grant/revoke, limits, last-admin rule) with SeaweedFS storage and the Qdrant server |
| Redis not needed | the stack runs with `REDIS_ENABLED=false`; Redis only backs the rate-limit cache, which falls back to in-process memory (one worker); the journey and all Phase 4–6 end-to-end runs used no Redis |
| One processing operation at a time | new deployment-wide gate (`MAX_CONCURRENT_DOCUMENT_PROCESSING`, Postgres advisory locks) on the streaming upload, legacy upload, retry and re-index routes: 5 backend tests (concurrent uploads → one 201, others 503 `processing_busy` with Retry-After and nothing stored; retry and re-index refused while busy without claiming; lock released after a crash; N=2 allows exactly two; 0 = unlimited); on the stack two simultaneous uploads gave 201 + 503. Mobile shows a specific "another document is being processed" message (test) |
| Startup refuses weak secrets | non-local `APP_ENV` with an empty, default (`change-me`) or short `SECRET_KEY`, or a wildcard CORS origin, stops startup (11 tests) |
| Backend / mobile | backend **228** tests; Flutter format and analyze clean, **267** tests |
| Swap script | `host/test-swap.sh`: 34 checks pass in a throwaway container against a scratch root with stubbed system commands, so the real host was never touched. Covered: an existing active `/swapfile`, its fstab line and the owner's sysctl stay untouched through apply and rollback; a foreign file at the TEIA path is refused; a replaced file is refused at rollback; failed applies (mkswap, swapon, sysctl) are fully undone; the previous swappiness (35) is restored rather than a default; rollback refuses under low memory and when swapoff fails, changing nothing |
| Consistent backup | `backup.sh` waits for the processing lock, then stops the API, dumps the database, stops Qdrant and SeaweedFS, and copies the volumes. Locally: a 787 KB set, about 1.5 min of API downtime. A forced failure restarted every service to `running/healthy` and marked the set `.failed`; a held processing lock refused the backup without stopping anything |
| Isolated restore | `restore.sh` into the separate `teia-restore` project (own volumes, internal-only network, no ports, no internet). With synthetic data, 14/14 table counts matched, 3/3 documents were SHA-256-verified, Qdrant points matched (180) and the prompts hash matched. Refused: a second run, and overrides that pointed a volume at `teia-staging-pgdata`, attached `teia-staging-edge`, published a port or used an unknown volume |
| Fail-closed deploy | `deploy.sh` ran clean to `deploy: OK`. A dirty checkout stopped it at `checkout`. An injected broken migration stopped it with exit 3: api and web stopped, no `.edge-ready` marker, and the migration's own transaction was rolled back |
| First admin | `bootstrap-admin.sh` grants `super_admin`. Before: `viewer`, 403 on `/spaces/_superadmin/spaces`. After: 200, while another account still got 403. Refused: an unknown email, a malformed value and a second admin. Re-running for the same account is a no-op |
| Proxy log privacy | `caddy/test-log-redaction.sh` against Caddy 2.8.4: 12 requests carrying synthetic share, JWT (notification stream), reset, invite, verify and cookie tokens, including 502s with upstreams down. No token appeared in any Caddy log line (access or error). `check-config.sh` refuses an inherited global `debug`. The API container runs uvicorn with `--no-access-log` |
| Capacity criteria | `host/capacity-check.sh` on Docker Desktop flagged a healthy non-TEIA container that was restarted or stopped, and simulated memory pressure; `watch --enforce` stopped only `teia-staging-*`; a container already failing at baseline was reported but not counted as TEIA's abort |

### Measured memory (cgroup `memory.peak`, local Docker Desktop, stub embeddings)

| Service | Proposed | Result | Final limit | Peak at final limit |
|---|---|---|---|---|
| api (incl. extraction subprocess) | 1 GiB, extraction 512 MiB | 512 MiB extraction failed a valid 24 MiB CSV (`MemoryError` → `too_complex`); 768 MiB failed too; 1024 MiB processed it (10,992 chunks); peak 843 MiB at 1 GiB | **1280 MiB**, extraction **1024 MiB** | 779 MiB |
| db | 384 MiB | fine | 384 MiB | 248 MiB |
| qdrant | 512 MiB | fine | 512 MiB | 308 MiB |
| objects | 256 MiB (MinIO) | MinIO images not pullable (Docker Hub repository unavailable, quay.io 401) → SeaweedFS; at 256 MiB it **restarted during a 25 MB upload** | **512 MiB** | 424 MiB |
| web | 64 MiB | fine | 64 MiB | 15 MiB |
| **Total limits** | 2.25 GiB | | **2.69 GiB** | ≈ 1.8 GiB summed peaks |

**These figures don't establish capacity.** They are limits tested locally: one upload at a time, on a faster machine, with stub embeddings. Real embeddings add network time, not API memory. Server facts from the read-only assessment:
- 3.7 GiB RAM, about 2.8 GiB available;
- no swap;
- MedicalHub containers have no memory limits.

The summed limits (2.69 GiB) are a ceiling, not a reservation. Measured peaks sum to about 1.8 GiB.

**Swap policy (intended, and not capacity approval):**
- **No container swap for TEIA.** Every TEIA service has `memswap_limit` equal to `mem_limit`, which gives the container **no swap at all**. A TEIA service that exceeds its limit is OOM-killed inside its own cgroup, and Docker restarts it. Its memory cannot spill into swap at the expense of the other apps. This is deliberate.
- **Host swap is a margin for the host.** The 4 GiB TEIA swap file (`host/swap.sh`, `vm.swappiness` 10) protects the host and the uncapped MedicalHub and IIH IVR processes against short spikes. It doesn't make room for TEIA, and swap use is itself an abort signal (below).
- **Acceptance is measured on the server.** TEIA is accepted only if the criteria below hold for 24 h of pilot use. Otherwise it is stopped and the limits are revised, or TEIA moves to its own host. MedicalHub settings are not changed.

**Build-time resources:**
- **Recommended:** build the images off-host and `docker load` them (`deploy.sh --images-prebuilt`).
- **Fallback:** an on-host build runs one image at a time under `nice -n 19` and `ionice -c3`, after a memory preflight.
- Build memory was not measured on the server.

**Acceptance and abort criteria** (`host/capacity-check.sh`; see DEPLOY.md):
- **Before starting:** MemAvailable ≥ 2 GiB, ≥ 8 GiB free disk, and swap active.
- **While running, abort if any of these happens:**
  - MemAvailable < 300 MiB;
  - swap in use > 1 GiB;
  - swap-in > 500 pages/s;
  - a new kernel OOM kill;
  - any IIH IVR or MedicalHub container stops, restarts, is OOM-killed or becomes unhealthy compared with the baseline.
- On an abort, `watch --enforce` stops only the TEIA containers.

## Unverified until deployment

- DNS and certificates for `teia-api.65-108-244-83.sslip.io` / `teia.65-108-244-83.sslip.io` (proposed; sslip.io is third-party DNS with Let's Encrypt rate limits).
- Caddy validation inside the running IIH IVR container and its graceful reload; behaviour of the existing site afterwards.
- Real provider embeddings/chat and SMTP delivery; memory on the actual server; image build time on 2 vCPU.
- The provider spending limit (configured in the provider console; not enforced or verified by this package).
- Backups to a real off-host destination, and a restore rehearsal on the server (verified locally only; see BACKUP.md).
- The acceptance criteria on the real host: the baseline, the 24 h watch and the actual memory headroom next to MedicalHub.
- `check-config.sh` against the live IIH IVR config: its global logging options are unknown until checked.
- Not tested locally:
  - the `backup.sh` exit-3 path (a service that will not restart);
  - `bootstrap-admin.sh` with two accounts whose emails differ only in letter case. The logic refuses this case, but no test exercised it.

## Blocked on owner inputs

- Staging **SMTP** account.
- Staging **AI provider credential**.
- **Off-host backup destination**.
- **Android signing material** (for the pilot APK, see docs/mobile/ANDROID_PILOT.md; not needed for the server).

## Approvals required before deployment

- Accept co-location of TEIA staging with **MedicalHub** (medical data) on the same host.
- Approve the concrete host changes:
  - the TEIA-owned 4 GiB swap file `/teia-staging.swap` (`host/swap.sh`);
  - the **IIH IVR Caddy** change: one snippet and two site blocks appended, `teia-staging-edge` attached, graceful reload (`caddy/README.md`).
- Accept the capacity criteria and the 24 h acceptance window (DEPLOY.md), including the automatic stop of TEIA when a criterion fails.

## Notes for the owner

- The API image is built from `requirements.lock.txt` (exact versions taken from the image that ran the full app in Phases 5–6) instead of the repository's Poetry setup, which has no lock file and installs PyTorch via sentence-transformers although nothing imports it with reranking off.
- The web image installs from `package.json` without the lock file (the committed lock file is out of sync), so web builds are not byte-reproducible yet.
- The new startup guard also applies to production: before this backend is deployed anywhere outside development, its `SECRET_KEY` must be at least 32 random characters.
