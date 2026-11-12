#!/usr/bin/env bash
# One-time platform-administrator bootstrap for TEIA staging (owner-run, after the account signed up).
#
#   ./bootstrap-admin.sh <email>
#
# Grants the supported platform-administration role, super_admin (src/modules/apis/v1/auth/schemas.py:
# super_admin > admin > viewer; super_admin-only routes include /api/v1/spaces/_superadmin/*, global
# prompts and space creation for others). Fails closed, in one transaction, unless:
#   - exactly one active account has that email (case-insensitive), and
#   - no other super_admin exists yet (bootstrap is one-time; later grants go through the app).
# Re-running for the same account is a no-op. Prints the resulting role; prints no other user data.
set -Eeuo pipefail
cd "$(dirname "$0")"
ENV_FILE=${TEIA_ENV_FILE:-teia-staging.env}
COMPOSE=(docker compose --env-file "$ENV_FILE" -f docker-compose.yml ${TEIA_COMPOSE_OVERRIDE:+-f "$TEIA_COMPOSE_OVERRIDE"})
EMAIL=${1:?usage: $0 <email of the account that signed up>}
[[ "$EMAIL" =~ ^[^[:space:]@\']+@[^[:space:]@\']+\.[^[:space:]@\']+$ ]] || { echo "FAIL: not an email address" >&2; exit 1; }

"${COMPOSE[@]}" exec -T db sh -c 'psql -X -q -At -v ON_ERROR_STOP=1 -v email="$0" -U "$POSTGRES_USER" -d "$POSTGRES_DB"' "$EMAIL" <<'SQL'
BEGIN;
SELECT set_config('teia.admin_email', lower(:'email'), true) \gset ignored_
DO $$
DECLARE
  target text := current_setting('teia.admin_email');
  matches int;
  active_matches int;
  other_admins int;
BEGIN
  SELECT count(*), count(*) FILTER (WHERE is_active) INTO matches, active_matches FROM users WHERE lower(email) = target;
  IF matches <> 1 THEN
    RAISE EXCEPTION 'expected exactly one account with that email, found %', matches;
  END IF;
  IF active_matches <> 1 THEN
    RAISE EXCEPTION 'the account is not active';
  END IF;
  SELECT count(*) INTO other_admins FROM users WHERE role = 'super_admin' AND lower(email) <> target;
  IF other_admins > 0 THEN
    RAISE EXCEPTION 'a super_admin already exists (% account(s)); bootstrap is one-time', other_admins;
  END IF;
  UPDATE users SET role = 'super_admin' WHERE lower(email) = target;
END $$;
SELECT 'role=' || role FROM users WHERE lower(email) = current_setting('teia.admin_email');
COMMIT;
SQL
echo "bootstrap-admin: OK (the account now has platform administration; sign out and in again)"
