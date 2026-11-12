"""Compare a backup-time inventory with a restored-stack inventory (tools/inventory.py output).

    python compare_inventory.py <backup inventory.json> <restored inventory.json>
Exit 0 only when every table count, every document object (read back, SHA-256 checked),
the Qdrant point count and the global prompts hash match.
"""

import json
import sys


def main(backup_path: str, restored_path: str) -> int:
    with open(backup_path) as handle:
        src = json.load(handle)
    with open(restored_path) as handle:
        dst = json.load(handle)
    problems = []
    for table, count in src["tables"].items():
        if dst["tables"].get(table) != count:
            problems.append(f"table {table}: backup {count}, restored {dst['tables'].get(table)}")
    docs, src_docs = dst["documents"], src["documents"]
    if docs["total"] != src_docs["total"]:
        problems.append(f"documents: backup {src_docs['total']}, restored {docs['total']}")
    if docs.get("objects_verified") != src_docs["with_object_url"]:
        problems.append(
            f"objects verified {docs.get('objects_verified')} of {src_docs['with_object_url']} "
            f"(missing {docs.get('objects_missing')}, hash mismatch {docs.get('objects_hash_mismatch')})"
        )
    if dst["qdrant_points"] != src["qdrant_points"]:
        problems.append(f"qdrant points: backup {src['qdrant_points']}, restored {dst['qdrant_points']}")
    if dst["prompts_sha256"] != src["prompts_sha256"]:
        problems.append("global prompts differ")

    print("tables:", ", ".join(f"{k}={v}" for k, v in sorted(dst["tables"].items()) if v))
    print(
        f"documents: {docs['total']}, objects verified by SHA-256: {docs.get('objects_verified')}; "
        f"qdrant points: {dst['qdrant_points']}; prompts: "
        f"{'match' if dst['prompts_sha256'] == src['prompts_sha256'] else 'DIFFER'}"
    )
    for problem in problems:
        print("MISMATCH:", problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
