# TEIA staging — first deployment and rollback (owner-run; nothing has been executed on the server)

**Target.** `65.108.244.83`, shared with IIH IVR and MedicalHub.

**Hosts.** `teia-api.65-108-244-83.sslip.io` and `teia.65-108-244-83.sslip.io` are proposed and **unverified** until DNS resolves and Caddy issues certificates.

**Pilot.** Private, 2–5 users, one document processed at a time. The server enforces this with `MAX_CONCURRENT_DOCUMENT_PROCESSING=1`.

## Approvals and inputs required first

- Accept co-location with MedicalHub (medical data) on the same host.
- Approve the host changes:
  - the TEIA swap file (`host/swap.sh`);
  - the Caddy change (`caddy/README.md`: one snippet and two site blocks, one network attachment, a graceful reload of the IIH IVR Caddy).
- Inputs:
  - a staging SMTP account;
  - a staging AI provider credential, with a spending limit set in the provider console (not enforced or verified here);
  - an off-host backup destination.
  - Android signing material is needed later for the pilot APK, not for the server.

## What changes the host

| Command | Changes the host? |
|---|---|
| `./validate.sh`, `host/swap.sh check`, `host/capacity-check.sh preflight\|check`, `caddy/check-config.sh` | no (read-only) |
| `host/capacity-check.sh baseline` | writes `/var/lib/teia-staging-capacity/baseline` only |
| `host/swap.sh apply --yes` | yes: `/teia-staging.swap`, one fstab line, `/etc/sysctl.d/99-teia-staging-swap.conf`, state file |
| `./deploy.sh` | yes: `teia-staging-*` containers, networks, volumes only (no edge) |
| `./bootstrap-admin.sh <email>` | one row in the staging DB (role) |
| Caddy steps in `caddy/README.md` | yes: IIH IVR Caddyfile, Caddy network, reload |
| `./backup.sh` | stops and restarts TEIA services (~1.5 min); writes backups; copies off-host |
| `./restore.sh` | `teia-restore-*` containers and volumes only |
| `host/capacity-check.sh watch --enforce` | stops `teia-staging-*` containers on an abort criterion |

## Images: build off-host (recommended), or bounded on-host build

Building on the 2 vCPU / 3.7 GiB host competes with MedicalHub and IIH IVR, so the recommended path builds elsewhere. Run this on a workstation or CI runner at the reviewed commit, with the filled env file present so the web build argument is set:

```bash
cd deploy/teia-staging
export TEIA_STAGING_TAG=$(git rev-parse --short HEAD)
docker compose --env-file teia-staging.env -f docker-compose.yml build
docker save teia-staging-api:$TEIA_STAGING_TAG teia-staging-web:$TEIA_STAGING_TAG | gzip > teia-images-$TEIA_STAGING_TAG.tar.gz
scp teia-images-$TEIA_STAGING_TAG.tar.gz root@65.108.244.83:/opt/teia-staging/
# on the server:  gunzip -c /opt/teia-staging/teia-images-<tag>.tar.gz | docker load
```

`./deploy.sh --images-prebuilt` then only checks that `teia-staging-{api,web}:<commit>` exist.

If you build on the host instead (`./deploy.sh` without the flag):
- images are built one at a time, under `nice -n 19` and `ionice -c3`;
- `capacity-check.sh preflight` must pass before each build (MemAvailable ≥ 2 GiB, swap active).

Build memory was not measured on the server.

## First deployment

```bash
# 0. As root on the server. Code from the reviewed commit only.
mkdir -p /opt/teia-staging && cd /opt/teia-staging
git clone https://github.com/arabaya3/AI-MOBILE-AGENT.git . && git checkout <reviewed commit>
cd deploy/teia-staging

# 1. Configuration (values from the owner's secret manager; never the repository .env)
cp teia-staging.env.example teia-staging.env && chmod 600 teia-staging.env
${EDITOR:-nano} teia-staging.env
./validate.sh                                   # must end with "validate: OK"

# 2. TEIA swap file (approved step), then the host acceptance baseline before TEIA starts
host/swap.sh check
host/swap.sh apply --yes
host/capacity-check.sh preflight                # refuses if the host is already tight (or no swap)
host/capacity-check.sh baseline                 # state of IIH IVR / MedicalHub containers, OOM counter

# 3. TEIA up to (not including) the edge: fail-fast, writes .edge-ready-<commit> only on success
./deploy.sh --images-prebuilt                   # or ./deploy.sh (bounded on-host build)

# 4. Edge (approved step): caddy/README.md "Apply" (requires .edge-ready-<commit>)

# 5. First platform administrator: sign up through the web app, then (exactly one matching account required)
./bootstrap-admin.sh <admin email>

# 6. Backups (approved destination) and the first restore rehearsal (BACKUP.md)
TEIA_BACKUP_DEST=<off-host target> ./backup.sh
./restore.sh backups/<stamp> && ./restore.sh --cleanup

# 7. Acceptance window: 24 h of the criteria below, stopping TEIA automatically if one fails
nohup host/capacity-check.sh watch --enforce 1440 >> /var/log/teia-capacity.log 2>&1 &
```

What `deploy.sh` does, stopping at the first failure:
- **Checks.** `validate.sh`, a clean checkout of the reviewed commit, and the host preflight.
- **Images.** Built or checked, as above.
- **Services.**
  - starts db, qdrant and objects and waits for them to be healthy;
  - starts the api and waits for health (this creates the schema);
  - runs every `migrations/sql/*.sql` in name order. Each file is one `BEGIN … COMMIT`, and psql runs with `ON_ERROR_STOP=1`;
  - starts web, then runs internal smoke checks.
- **Marker.** Only after all of that does it write `.edge-ready-<commit>`.

On any failure it prints the step and the TEIA container state, and writes no marker. On a migration failure it also stops api and web, so a partially migrated schema is not served.

Local evidence:
- a clean run ended with `deploy: OK`;
- an injected broken migration stopped at that file with exit 3, api and web stopped, and no marker. Its table was absent afterwards, confirming the transaction was rolled back.

`bootstrap-admin.sh` grants `super_admin`, the supported platform-administration role: `super_admin` > `admin` > `viewer`, and `/api/v1/spaces/_superadmin/*` requires it. It runs in one transaction and refuses unless exactly one active account matches the email (case-insensitive) and no other `super_admin` exists.

Local evidence:
- before the grant: `role=viewer`, and `_superadmin/spaces` returned 403;
- after: `role=super_admin`, 200, while another account still got 403;
- the following were all refused:
  - an unknown email ("found 0");
  - a malformed value;
  - a second administrator ("bootstrap is one-time").
- re-running for the same account is a no-op.

## Acceptance and abort criteria (protecting the existing apps)

Swap is a safety margin for the host, **not** approval of capacity. TEIA is accepted only if these hold for 24 h of pilot use. `host/capacity-check.sh` measures them, and the thresholds can be overridden by environment variables.

| Criterion | Abort when |
|---|---|
| Host memory | MemAvailable < 300 MiB |
| Swap as margin, not working memory | swap in use > 1 GiB, or swap-in > 500 pages/s over a 10 s sample |
| Kernel OOM killer | any new OOM kill since the baseline |
| IIH IVR / MedicalHub containers | any one that was running is stopped, restarted (restart count or start time), OOM-killed, or newly unhealthy |
| Before starting | MemAvailable < 2 GiB, < 8 GiB free disk, or no swap active (`preflight` refuses) |

How the checks behave:
- Problems that already existed at baseline (for example the MedicalHub admin portal that was already unhealthy) are reported, not counted against TEIA.
- `watch --enforce` stops only the `teia-staging-*` containers when a criterion fails. MedicalHub limits and settings are never changed.
- After an abort:
  - keep TEIA stopped;
  - report the evidence from `/var/log/teia-capacity.log`;
  - revise the limits or move TEIA to its own host.

## Update

```bash
cd /opt/teia-staging && git fetch && git checkout <new reviewed commit> && cd deploy/teia-staging
./validate.sh && TEIA_BACKUP_DEST=<target> ./backup.sh
./deploy.sh --images-prebuilt                   # images for the new commit loaded first
```

## Rollback

- **Application only.** `git checkout <previous commit>`, load or build that commit's images, then `./deploy.sh --images-prebuilt`. Data volumes stay. A schema migration is not reversed automatically; if the new commit migrated the schema, restore the pre-update backup.
- **Data.** Restore the latest set (BACKUP.md "Restore into staging"), after rehearsing it with `restore.sh`.
- **Edge.** `caddy/README.md` "Rollback": restores the IIH IVR Caddyfile backup, reloads, detaches the network.
- **Remove TEIA staging entirely.** After the edge rollback:
  - `docker compose --env-file teia-staging.env -f docker-compose.yml down` keeps the volumes;
  - `... down -v` deletes the `teia-staging-*` volumes, which cannot be undone without a backup.
  - IIH IVR and MedicalHub are not touched by any of these commands.
- **Swap.** `host/swap.sh rollback --yes`:
  - It removes only what `apply` created and restores the recorded previous `vm.swappiness`.
  - It refuses, changing nothing, if the swap contents would not fit in available memory with a 512 MiB margin. In that case stop TEIA first.
  - A pre-existing `/swapfile` or any other swap is never adopted or touched.
