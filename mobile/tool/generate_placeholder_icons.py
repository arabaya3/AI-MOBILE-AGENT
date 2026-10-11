"""Generates the temporary launcher icons (no brand artwork). Usage: python tool/generate_placeholder_icons.py"""

import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ACCENT = (0x1B, 0x6B, 0x53)
WHITE = (0xFF, 0xFF, 0xFF)
SAMPLES = 4


def coverage(x: float, y: float) -> float:
    """1.0 where the mark (a ring with a centre dot) is drawn, in unit coordinates."""
    dx, dy = x - 0.5, y - 0.5
    r = math.hypot(dx, dy)
    ring = 0.22 <= r <= 0.30
    dot = r <= 0.085
    return 1.0 if ring or dot else 0.0


def render(size: int) -> bytes:
    rows = []
    for py in range(size):
        row = bytearray([0])
        for px in range(size):
            hit = 0.0
            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    hit += coverage((px + (sx + 0.5) / SAMPLES) / size, (py + (sy + 0.5) / SAMPLES) / size)
            a = hit / (SAMPLES * SAMPLES)
            row += bytes(round(ACCENT[i] * (1 - a) + WHITE[i] * a) for i in range(3))
        rows.append(bytes(row))
    raw = zlib.compress(b"".join(rows), 9)

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", raw) + chunk(b"IEND", b"")


def main() -> None:
    android = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for density, size in android.items():
        (ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png").write_bytes(render(size))

    ios_dir = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for name in sorted(p.name for p in ios_dir.glob("Icon-App-*.png")):
        spec = name.removeprefix("Icon-App-").removesuffix(".png")
        base, scale = spec.split("@")
        size = round(float(base.split("x")[0]) * int(scale.removesuffix("x")))
        (ios_dir / name).write_bytes(render(size))


if __name__ == "__main__":
    main()
