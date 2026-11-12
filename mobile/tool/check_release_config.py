"""Validates a staging/prod --dart-define-from-file config before a release build.

Usage: python tool/check_release_config.py [--distribution] config/prod.json
--distribution additionally refuses reserved documentation/test domains (example.com, *.test, ...),
for builds that will be installed on real devices. Exit code 0 when valid; otherwise prints every problem and exits 1. Mirrors AppConfig.parse and the
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


# RFC 2606 / RFC 6761 names that can never be a real deployment.
RESERVED_SUFFIXES = ("example", "example.com", "example.net", "example.org", "test", "invalid", "localhost", "local")


def is_reserved(host: str) -> bool:
    return any(host == s or host.endswith("." + s) for s in RESERVED_SUFFIXES)


def distribution_problems(config: dict) -> list[str]:
    """Extra checks for an APK/IPA that will be installed on real devices."""
    found = problems(config)
    host = (urlsplit(str(config.get("API_BASE_URL", "")).strip()).hostname or "").lower()
    if host and is_reserved(host):
        found.append(f"API_BASE_URL host {host!r} is a reserved test domain; not for distribution")
    for link in [h.strip().lower() for h in str(config.get("APP_LINK_HOSTS", "")).split(",") if h.strip()]:
        if is_reserved(link):
            found.append(f"APP_LINK_HOSTS host {link!r} is a reserved test domain; not for distribution")
    return found


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
    args = argv[1:]
    distribution = "--distribution" in args
    args = [a for a in args if a != "--distribution"]
    if len(args) != 1:
        print(__doc__.strip().splitlines()[2])
        return 2
    argv = [argv[0], args[0]]
    try:
        with open(argv[1], encoding="utf-8") as handle:
            config = json.load(handle)
    except (OSError, ValueError) as exc:
        print(f"{argv[1]}: cannot read config: {exc}")
        return 1
    if not isinstance(config, dict):
        print(f"{argv[1]}: config must be a JSON object")
        return 1
    found = distribution_problems(config) if distribution else problems(config)
    for item in found:
        print(f"{argv[1]}: {item}")
    if not found:
        links = config.get("APP_LINK_HOSTS") or "none (links can be pasted in the app)"
        print(f"{argv[1]}: OK (API host {urlsplit(config['API_BASE_URL']).hostname}; link hosts: {links})")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
