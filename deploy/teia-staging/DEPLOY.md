# TEIA staging — first deployment and rollback (owner-run; nothing has been executed)

Target: `65.108.244.83` (shared with IIH IVR and MedicalHub). Proposed hosts `teia-api.65-108-244-83.sslip.io` and `teia.65-108-244-83.sslip.io` are **unverified** until DNS resolves and Caddy issues certificates. Private pilot: 2–5 users, one document processed at a time (enforced server-side by `MAX_CONCURRENT_DOCUMENT_PROCESSING=1`).

## Approvals and inputs required first

- Accepting co-location with MedicalHub (medical data) on the same host.
- Approving the host changes: the swap file (`host/swap.sh`) and the Caddy change (`caddy/README.md`: two site blocks, one network attachment, a graceful reload of the IIH IVR Caddy).
- Inputs: staging SMTP account, staging AI provider credential (with a spending limit set in the provider console; not enforced or verified here), an off-host backup destination. Android signing material is needed later for the pilot APK, not for the server.

## Mutation is separate from validation

| Step | Changes the host? |
|---|---|
| `./validate.sh` | no |
| `host/swap.sh check` | no |
| `host/swap.sh apply --yes` | yes (swap file, fstab, sysctl) |
| `docker compose ... up` | yes (TEIA containers, networks, volumes only) |
| Caddy steps in `caddy/README.md` | yes (IIH IVR Caddyfile, Caddy network, reload) |
| `./backup.sh` | writes backups; copies off-host |

## First deployment

```bash
# 0. As root on the server. Code from the reviewed commit only.
mkdir -p /opt/teia-staging && cd /opt/teia-staging
git clone --branch dev https://github.com/arabaya3/AI-MOBILE-AGENT.git . && git checkout <reviewed commit>
cd deploy/teia-staging

# 1. Configuration (values from the owner's secret manager; never the repository .env)
cp teia-staging.env.example teia-staging.env && chmod 600 teia-staging.env
${EDITOR:-nano} teia-staging.env
./validate.sh                                   # must end with "validate: OK"

# 2. Memory safety margin (approved step)
./host/swap.sh check
./host/swap.sh apply --yes

# 3. Build and start TEIA (no host ports; only the teia-staging-* networks and volumes are created)
export TEIA_STAGING_TAG=$(git rev-parse --short HEAD)
C="docker compose --env-file teia-staging.env -f docker-compose.yml"
$C build
$C up -d
$C ps                                           # all healthy within ~2 minutes

# 4. Database: the API's startup created the schema; apply the migrations (idempotent) in order
for f in ../../migrations/sql/2026101{1,2,3}_0001_*.sql ../../migrations/sql/2026110{2,3}_0001_*.sql ../../migrations/sql/20261111_0001_*.sql; do
  $C exec -T db sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < "$f" || break
done

# 5. Edge (approved step): follow caddy/README.md "Apply"

# 6. Smoke checks
curl -fsS https://teia-api.65-108-244-83.sslip.io/health
curl -fsSI https://teia.65-108-244-83.sslip.io/join-space | head -n 1
docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' | grep teia-staging

# 7. First admin: sign up through the web app, then promote that account (one-time, staging DB only)
$C exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "UPDATE users SET role = '"'"'admin'"'"' WHERE email = '"'"'<admin email>'"'"';"'

# 8. Backups (approved destination)
TEIA_BACKUP_DEST=<off-host target> ./backup.sh
```

## Update

```bash
cd /opt/teia-staging && git fetch && git checkout <new reviewed commit> && cd deploy/teia-staging
./validate.sh && TEIA_BACKUP_DEST=<target> ./backup.sh
export TEIA_STAGING_TAG=$(git rev-parse --short HEAD)
$C build && $C up -d && $C ps
```

## Rollback

- **Application only:** `git checkout <previous commit>`, rebuild with the previous tag, `$C up -d`. Data volumes stay.
- **Data:** restore the latest set (BACKUP.md).
- **Edge:** `caddy/README.md` "Rollback" (restores the IIH IVR Caddyfile backup, reloads, detaches the network).
- **Remove TEIA staging entirely:** after the edge rollback, `$C down` (keeps volumes) or `$C down -v` (deletes `teia-staging-*` volumes; irreversible without a backup). IIH IVR and MedicalHub are not touched by any of these commands.
- **Swap:** `./host/swap.sh rollback --yes`.
