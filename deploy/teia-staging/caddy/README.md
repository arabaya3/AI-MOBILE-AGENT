# Caddy integration (owner approval required; not applied)

The IIH IVR project owns ports 80/443 with its Caddy container (`iih-ivr-caddy-1`, Caddy 2.8.4 locally validated against `caddy:2.8-alpine`). Its config is the bind-mounted host file `/opt/iih-ivr/current/deploy/Caddyfile`. TEIA staging adds **two site blocks** (`teia-staging.caddy`) and **one network attachment**; every existing site and global option stays as it is.

Key facts:
- Inside the Caddy container, `127.0.0.1` / `localhost` is the Caddy container itself, not the host. The TEIA API is reached by container name (`teia-staging-api:8000`) over the `teia-staging-edge` network, so Caddy must join that network.
- `flush_interval -1` streams chat replies and notifications without buffering.
- `response_header_timeout 330s` covers synchronous document processing (`PROCESSING_TIMEOUT_SECONDS=300`); Caddy 2.8 has no default read/write timeout on servers, so long uploads are not cut by Caddy. `request_body max_size 26MB` matches the 25 MiB upload limit.
- `/metrics` is answered with 404 at the edge.
- The Caddyfile is a **single-file bind mount**: edit it in place (append), do not replace it with an editor that writes a new file (the container would keep seeing the old inode).

## Apply (after approval)

```bash
CF=/opt/iih-ivr/current/deploy/Caddyfile
TS=$(date -u +%Y%m%dT%H%M%SZ)

# 1. Backup
cp -a "$CF" "$CF.bak-teia-$TS"

# 2. Network (TEIA project must be up so teia-staging-edge exists)
docker network connect teia-staging-edge iih-ivr-caddy-1

# 3. Append the TEIA sites in place (preserves the inode of the bind-mounted file)
printf '\n' >> "$CF"
cat /opt/teia-staging/deploy/teia-staging/caddy/teia-staging.caddy >> "$CF"

# 4. Validate inside the running container (same binary and modules), then reload gracefully
docker exec iih-ivr-caddy-1 caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec iih-ivr-caddy-1 caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile

# 5. Check (first request triggers certificate issuance for the sslip.io names; unverified until then)
curl -fsS https://teia-api.65-108-244-83.sslip.io/health
curl -fsSI https://teia.65-108-244-83.sslip.io/ | head -n 1
curl -fsSI https://65-108-244-83.sslip.io/ | head -n 1     # existing IIH IVR site still answers
```

If step 4's `validate` fails, do not reload; restore the backup (below).

## Rollback

```bash
cp -a "$CF.bak-teia-$TS" /tmp/Caddyfile.restore && cat /tmp/Caddyfile.restore > "$CF"   # in-place restore
docker exec iih-ivr-caddy-1 caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec iih-ivr-caddy-1 caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
docker network disconnect teia-staging-edge iih-ivr-caddy-1
```

## Persistence note

`docker network connect` does not survive a recreation of the Caddy container (for example `docker compose up` in the IIH IVR project after a config change to that service). Two options, both changing the IIH IVR project and therefore needing its owner's approval:
1. Re-run step 2 after any IIH IVR redeploy (documented operational step), or
2. Add `teia-staging-edge` as an `external: true` network of the IIH IVR `caddy` service in that project's compose file.
