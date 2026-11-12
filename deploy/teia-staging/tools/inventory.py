"""Inventory of a TEIA stack's data, printed as one JSON line (no secrets, no personal data).

Runs inside the API image with the stack's own settings, piped on stdin:
    docker compose ... run --rm --no-deps -T api python - [--verify-objects] < tools/inventory.py

- row counts of the main tables,
- documents: how many have an s3 object; with --verify-objects every object is read back and its SHA-256
  compared with documents.file_hash (used by the restore rehearsal),
- Qdrant: points in the configured collection,
- global prompts: SHA-256 of SYSTEM_PROMPTS_PATH (or "absent").
"""

import asyncio
import hashlib
import json
import os
import sys
import urllib.request

from sqlalchemy import text

from src.core.settings.config import settings
from src.services.cloud.aws.s3 import s3_service
from src.services.databases.postgresql import database

TABLES = [
    "users", "spaces", "space_members", "space_invites", "chat_sessions", "chat_messages", "chat_shares",
    "documents", "document_upload_receipts", "user_document_permissions", "conversation_creations",
    "generation_attempts", "llm_usage_events", "notifications",
]


async def table_counts(conn) -> dict:
    counts = {}
    for table in TABLES:
        exists = (await conn.execute(text("SELECT to_regclass(:t) IS NOT NULL"), {"t": f"public.{table}"})).scalar()
        counts[table] = (await conn.execute(text(f'SELECT count(*) FROM "{table}"'))).scalar() if exists else None
    return counts


async def documents(conn, verify: bool) -> dict:
    rows = (await conn.execute(text("SELECT id, s3_url, file_hash FROM documents ORDER BY id"))).all()
    result = {"total": len(rows), "with_object_url": sum(1 for r in rows if (r.s3_url or "").startswith("s3://"))}
    if not verify:
        return result
    ok = missing = mismatch = 0
    for row in rows:
        if not (row.s3_url or "").startswith("s3://"):
            continue
        digest = hashlib.sha256()
        try:
            async for chunk in s3_service.iter_object(row.s3_url):
                digest.update(chunk)
        except Exception:
            missing += 1
            continue
        if digest.hexdigest() == row.file_hash:
            ok += 1
        else:
            mismatch += 1
    result.update(objects_verified=ok, objects_missing=missing, objects_hash_mismatch=mismatch)
    return result


def qdrant_points():
    url = f"{settings.QDRANT_URL.rstrip('/')}/collections/{settings.QDRANT_COLLECTION}"
    request = urllib.request.Request(url, headers={"api-key": settings.QDRANT_API_KEY or ""})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return json.load(response)["result"].get("points_count")
    except urllib.error.HTTPError as error:
        return "no-collection" if error.code == 404 else f"http-{error.code}"
    except Exception as error:  # unreachable: reported, not hidden
        return f"unreachable:{type(error).__name__}"


def prompts_digest() -> str:
    path = settings.SYSTEM_PROMPTS_PATH
    if not path or not os.path.exists(path):
        return "absent"
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


async def main() -> None:
    verify = "--verify-objects" in sys.argv
    async with database.engine.connect() as conn:
        out = {"tables": await table_counts(conn), "documents": await documents(conn, verify)}
    out["qdrant_points"] = qdrant_points()
    out["prompts_sha256"] = prompts_digest()
    await database.engine.dispose()
    print(json.dumps(out, sort_keys=True))


asyncio.run(main())
