"""Generate first-party stylized portrait/victory PNGs for new Smash fighters."""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

FIGHTERS = {
    "cartes": {
        "bg": (28, 42, 72),
        "body": (196, 156, 110),
        "accent": (198, 40, 40),
        "suit": (36, 48, 68),
        "label": "HC",
    },
    "fort": {
        "bg": (48, 28, 58),
        "body": (232, 190, 150),
        "accent": (240, 200, 72),
        "suit": (245, 245, 248),
        "label": "RF",
    },
    "pajaro_campana": {
        "bg": (18, 64, 72),
        "body": (240, 210, 70),
        "accent": (255, 230, 120),
        "suit": (90, 140, 70),
        "label": "PC",
    },
}


def _chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, rgba: bytes) -> None:
    raw = b"".join(b"\x00" + rgba[y * width * 4 : (y + 1) * width * 4] for y in range(height))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + _chunk(b"IHDR", ihdr) + _chunk(b"IDAT", zlib.compress(raw, 9)) + _chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def _fill(buf: bytearray, w: int, h: int, color: tuple[int, int, int], a: int = 255) -> None:
    r, g, b = color
    for i in range(0, w * h * 4, 4):
        buf[i : i + 4] = bytes((r, g, b, a))


def _rect(buf: bytearray, w: int, x0: int, y0: int, x1: int, y1: int, color: tuple[int, int, int]) -> None:
    r, g, b = color
    for y in range(max(0, y0), min(h := len(buf) // (w * 4), y1)):
        for x in range(max(0, x0), min(w, x1)):
            i = (y * w + x) * 4
            buf[i : i + 4] = bytes((r, g, b, 255))


def _circle(buf: bytearray, w: int, cx: int, cy: int, rad: int, color: tuple[int, int, int]) -> None:
    r, g, b = color
    h = len(buf) // (w * 4)
    rr = rad * rad
    for y in range(max(0, cy - rad), min(h, cy + rad + 1)):
        for x in range(max(0, cx - rad), min(w, cx + rad + 1)):
            if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= rr:
                i = (y * w + x) * 4
                buf[i : i + 4] = bytes((r, g, b, 255))


def paint(spec: dict, size: int) -> bytes:
    buf = bytearray(size * size * 4)
    _fill(buf, size, size, spec["bg"])
    cx = size // 2
    # body / suit
    _rect(buf, size, cx - size // 5, size // 2, cx + size // 5, size - size // 10, spec["suit"])
    # head
    _circle(buf, size, cx, size // 3, size // 6, spec["body"])
    # accent sash / crest
    _rect(buf, size, cx - size // 4, int(size * 0.55), cx + size // 4, int(size * 0.62), spec["accent"])
    # eyes
    _circle(buf, size, cx - size // 14, size // 3, size // 40, (20, 20, 24))
    _circle(buf, size, cx + size // 14, size // 3, size // 40, (20, 20, 24))
    return bytes(buf)


def main() -> None:
    for fid, spec in FIGHTERS.items():
        portrait = paint(spec, 256)
        victory = paint(spec, 512)
        write_png(ROOT / f"assets/ui/portraits/{fid}_portrait.png", 256, 256, portrait)
        write_png(ROOT / f"assets/ui/victory/{fid}/{fid}_victory.png", 512, 512, victory)
        print("wrote", fid)


if __name__ == "__main__":
    main()
