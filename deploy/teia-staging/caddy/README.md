# Caddy integration (owner approval required; not applied)

The IIH IVR project owns ports 80/443 through its Caddy container, `iih-ivr-caddy-1` (Caddy 2.8.4; locally validated against `caddy:2.8-alpine`). Its config is the bind-mounted host file `/opt/iih-ivr/current/deploy/Caddyfile`.

TEIA staging adds:
- **one snippet and two site blocks** (`teia-staging.caddy`);
- **one network attachment**.

Every existing site and global option stays as it is.

Key facts:
- **Addressing.** Inside the Caddy container, `127.0.0.1` / `localhost` is the Caddy container itself, not the host. The TEIA API is therefore reached by name, `teia-staging-api:8000`, over the `teia-staging-edge` network, and Caddy must join that network.
- **Streaming.** `flush_interval -1` streams chat replies and notifications without buffering.
- **Timeouts and body size.**
  - `response_header_timeout 330s` covers synchronous document processing (`PROCESSING_TIMEOUT_SECONDS=300`).
  - Caddy 2.8 has no default read/write timeout on servers, so Caddy does not cut off long uploads.
  - `request_body max_size 26MB` matches the 25 MiB upload limit.
- **Metrics.** `/metrics` is answered with 404 at the edge.
- **Bind mount.** The Caddyfile is a **single-file bind mount**. Edit it in place by appending. Do not replace it with an editor that writes a new file: the container would keep seeing the old inode.

## Access-log privacy

TEIA URLs carry bearer secrets:
- `/api/v1/shared/<share token>`;
- the notification stream's `?token=<JWT>`;
- the web links `/join-space?token=` (invite), `/auth?token=` (password reset) and `/verify-email?token=`.

How the snippet handles them:
- **Filtered access logs.** The snippet `teia_staging_redacted_log` gives both TEIA sites their own access logger. It rewrites `request>uri`, replacing every query string and everything after `/shared/` with `REDACTED`, and deletes the `Authorization`, `Cookie`, `Referer` and `Set-Cookie` headers before a line is written.
- **Error logs.** Caddy writes handler errors to its *default* logger with the raw URI, which the filter does not cover. Example: an unreachable upstream on `/shared/<token>`. Both sites therefore answer errors through `handle_errors`; handled errors are logged at DEBUG only.
- **Referer.** The web site sends `Referrer-Policy: no-referrer`, so tokens in page URLs don't leak to other origins either.
- **API container.** It runs uvicorn with `--no-access-log`, because uvicorn's access line contains the raw query. The app's own request log has the path only, with share tokens masked.

Inherited/global logging could bypass this. `check-config.sh` (read-only) runs `caddy validate` and `caddy adapt` in the container, then refuses:
- a DEBUG level;
- `log_credentials`;
- a server-wide default access logger;
- a logger that includes all access logs;
- a TEIA host without a URI-redacting logger.

Local evidence (`./test-log-redaction.sh`, against `caddy:2.8-alpine`):
- **Setup:** a stand-in global block and existing site, with the TEIA blocks appended.
- **Requests sent:** 12, carrying synthetic share, JWT, reset, invite, verify and cookie tokens. They included requests with the upstreams stopped, which produce 502 errors.
- **Result:** 11 access-log lines and 21 lines of Caddy output in total, with **no token present**. Example: `"uri":"/api/v1/notifications/stream?REDACTED"`.
- **check-config.sh:** passes on that config, and refuses the same config once a global `debug` is added.

## Apply (after approval)

Prerequisites:
- `deploy.sh` finished and wrote `.edge-ready-<commit>` (TEIA healthy, migrations applied);
- a fresh backup exists.

```bash
cd /opt/teia-staging/deploy/teia-staging
ls .edge-ready-"$(git rev-parse --short HEAD)"    # must exist; otherwise stop here
CF=/opt/iih-ivr/current/deploy/Caddyfile
TS=$(date -u +%Y%m%dT%H%M%SZ)

# 0. Read-only: the CURRENT config must already pass the logging checks (TEIA hosts are not in it yet)
docker exec iih-ivr-caddy-1 caddy adapt --config /etc/caddy/Caddyfile --adapter caddyfile | grep -c '"level":"DEBUG"'   # expect 0

# 1. Backup
cp -a "$CF" "$CF.bak-teia-$TS"

# 2. Network (TEIA project must be up so teia-staging-edge exists)
docker network connect teia-staging-edge iih-ivr-caddy-1

# 3. Append the TEIA snippet and sites in place (preserves the inode of the bind-mounted file)
printf '\n' >> "$CF"
cat caddy/teia-staging.caddy >> "$CF"

# 4. Validate + logging checks inside the running container (same binary and modules); reload only on success
caddy/check-config.sh iih-ivr-caddy-1 /etc/caddy/Caddyfile \
  && docker exec iih-ivr-caddy-1 caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile

# 5. Check (the first request triggers certificate issuance for the sslip.io names; unverified until then)
curl -fsS https://teia-api.65-108-244-83.sslip.io/health
curl -fsSI https://teia.65-108-244-83.sslip.io/ | head -n 1
curl -fsSI https://65-108-244-83.sslip.io/ | head -n 1     # existing IIH IVR site still answers
docker logs --since 5m iih-ivr-caddy-1 2>&1 | grep -c 'token=' # expect 0 (redaction live)
```

If step 4 fails, nothing is reloaded. Run the rollback below.

## Rollback

```bash
cat "$CF.bak-teia-$TS" > "$CF"                    # in-place restore (same inode)
docker exec iih-ivr-caddy-1 caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile \
  && docker exec iih-ivr-caddy-1 caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
docker network disconnect teia-staging-edge iih-ivr-caddy-1
curl -fsSI https://65-108-244-83.sslip.io/ | head -n 1     # existing site still answers
```

## Persistence note

`docker network connect` does not survive a recreation of the Caddy container, for example `docker compose up` in the IIH IVR project after a config change to that service. There are two options, and both change the IIH IVR project, so both need its owner's approval:
1. Re-run step 2 after any IIH IVR redeploy (a documented operational step).
2. Add `teia-staging-edge` as an `external: true` network of the IIH IVR `caddy` service in that project's compose file.
