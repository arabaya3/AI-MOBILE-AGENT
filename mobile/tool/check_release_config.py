"""Validates a staging/prod --dart-define-from-file config before a release build.

Usage: python tool/check_release_config.py config/prod.json
Exit code 0 when valid; otherwise prints every problem and exits 1. Mirrors AppConfig.parse and the
Android Gradle check, so iOS builds fail early too. It never contacts the hosts.
"""

from __future__ import annotations

import ipaddress
import json
import re
import sys
from urllib.parse import urlsplit

# Same pattern as the Gradle check and AppConfig.parse (labels may not start or end with "-").
HOST = re.compile(r"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\.[a-z]{2,}$")


def problems(config: dict) -> list[str]:
    found = []
    allowed = {"API_BASE_URL", "APP_LINK_HOSTS"}
    for key in sorted(set(config) - allowed):
        found.append(f"unknown key {key!r} (allowed: {', '.join(sorted(allowed))})")
    api = str(config.get("API_BASE_URL", "")).strip()
    if not api:
        found.append("API_BASE_URL is missing or empty")
    else:
        parts = urlsplit(api)
        host = (parts.hostname or "").lower()
        if parts.scheme != "https":
            found.append("API_BASE_URL must use https")
        if parts.username or parts.password or parts.query or parts.fragment:
            found.append("API_BASE_URL must not contain credentials, a query or a fragment")
        try:
            ipaddress.ip_address(host)
            found.append("API_BASE_URL must use a host name, not an IP address")
        except ValueError:
            if host == "localhost" or host.endswith(".localhost") or not HOST.match(host):
                found.append(f"API_BASE_URL host {host!r} is not a public host name")
    hosts = [h.strip().lower() for h in str(config.get("APP_LINK_HOSTS", "")).split(",") if h.strip()]
    for host in hosts:
        if not HOST.match(host) or host == "localhost" or host.endswith(".localhost"):
            found.append(f"APP_LINK_HOSTS contains an invalid host {host!r}")
    return found


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[2])
        return 2
    try:
        with open(argv[1], encoding="utf-8") as handle:
            config = json.load(handle)
    except (OSError, ValueError) as exc:
        print(f"{argv[1]}: cannot read config: {exc}")
        return 1
    if not isinstance(config, dict):
        print(f"{argv[1]}: config must be a JSON object")
        return 1
    found = problems(config)
    for item in found:
        print(f"{argv[1]}: {item}")
    if not found:
        links = config.get("APP_LINK_HOSTS") or "none (links can be pasted in the app)"
        print(f"{argv[1]}: OK (API host {urlsplit(config['API_BASE_URL']).hostname}; link hosts: {links})")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
