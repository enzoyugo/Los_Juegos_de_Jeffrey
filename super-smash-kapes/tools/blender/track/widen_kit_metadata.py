"""Widen 11 m sidecar JSON into kit_v8_15m collision metadata. Does not touch 11 m sources."""

from __future__ import annotations

import json
import math
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "assets" / "track" / "modules" / "generated" / "core"
DST = ROOT / "assets" / "track" / "processed" / "kit_v8_15m"

OLD_W = 11.0
NEW_W = 15.0
OLD_SHOULDER = 0.7
NEW_SHOULDER = 0.9
RAIL_THICK = 0.22
RAIL_H = 0.9


def _lateral() -> float:
    return NEW_W * 0.5 + NEW_SHOULDER + RAIL_THICK * 0.5


def _road_width_box() -> float:
    return NEW_W + 2.0 * NEW_SHOULDER


def _right(yaw: float) -> tuple[float, float]:
    return math.cos(yaw), -math.sin(yaw)


def widen_collision(boxes: list) -> list:
    out = []
    road_boxes = [b for b in boxes if str(b.get("kind")) == "road"]
    other = [b for b in boxes if str(b.get("kind")) not in ("road", "rail")]
    rails_new = []
    for box in road_boxes:
        n = dict(box)
        size = list(n.get("size", [12.4, 0.12, 1.0]))
        while len(size) < 3:
            size.append(1.0)
        origin = list(n.get("origin", [0.0, 0.0, 0.0]))
        while len(origin) < 3:
            origin.append(0.0)
        yaw = float(n.get("yaw", 0.0))
        pitch = float(n.get("pitch", 0.0))
        size[0] = _road_width_box()
        if abs(pitch) < 0.002:
            top = origin[1] + size[1] * 0.5
            size[1] = max(float(size[1]), 0.20)
            origin[1] = top - size[1] * 0.5
        # Longitudinal overlap so adjacent piece colliders do not leave a seam gap.
        size[2] = float(size[2]) + 0.10
        n["size"] = size
        n["origin"] = origin
        out.append(n)
        rx, rz = _right(yaw)
        lat = _lateral()
        for sign in (-1.0, 1.0):
            rails_new.append(
                {
                    "kind": "rail",
                    "origin": [
                        origin[0] + sign * lat * rx,
                        0.45,
                        origin[2] + sign * lat * rz,
                    ],
                    "yaw": yaw,
                    "pitch": pitch,
                    "size": [RAIL_THICK, RAIL_H, size[2]],
                }
            )
    out.extend(rails_new)
    out.extend(other)
    return out


def widen_doc(doc: dict) -> dict:
    n = json.loads(json.dumps(doc))
    n["road_width"] = NEW_W
    n["shoulder_width"] = NEW_SHOULDER
    n["kit"] = "kit_v8_15m"
    pid = str(n.get("piece_id", "piece"))
    glb = str(n.get("glb") or "")
    if not glb.endswith(".glb"):
        n["glb"] = "track_%s_v1.glb" % pid
    if "collision" in n:
        n["collision"] = widen_collision(list(n.get("collision") or []))
    return n


def main() -> None:
    DST.mkdir(parents=True, exist_ok=True)
    count = 0
    for src in sorted(SRC.glob("track_*.json")):
        doc = json.loads(src.read_text(encoding="utf-8"))
        out = widen_doc(doc)
        (DST / src.name).write_text(json.dumps(out, indent=2), encoding="utf-8")
        count += 1
    print("WIDENED", count, "json ->", DST)


if __name__ == "__main__":
    main()
