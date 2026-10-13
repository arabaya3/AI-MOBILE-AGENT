"""Isolated extraction process: `python -m src.services.processors.extract_worker <input> <ext> <output.json>`.

Runs in a child process so a hostile or huge document cannot block or exhaust the API process;
the parent enforces the time limit and (on Linux) memory and CPU limits.
"""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path


def main() -> int:
    source, ext, output = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    from src.services.processors.extraction import ExtractionError, extract_chunks

    try:
        chunks = asyncio.run(extract_chunks(source, ext))
        result = {"ok": True, "chunks": chunks} if chunks else {"ok": False, "code": "no_text"}
    except ExtractionError as exc:
        result = {"ok": False, "code": exc.code}
    except MemoryError:
        result = {"ok": False, "code": "too_complex"}
    except Exception:  # noqa: BLE001 - details stay in this process; the caller gets a safe code
        result = {"ok": False, "code": "corrupt"}
    output.write_text(json.dumps(result, ensure_ascii=False, default=str), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
