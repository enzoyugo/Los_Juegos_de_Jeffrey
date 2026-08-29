"""SVG plots + ballistic summary for V6 jump artifacts."""

from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _load(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def _xy(samples: list, ix: int, iz: int) -> list[tuple[float, float]]:
    out = []
    for row in samples:
        if isinstance(row, dict):
            pos = row.get("pos") or [0, 0, 0]
        else:
            pos = row
        if not isinstance(pos, list) or len(pos) < 3:
            continue
        out.append((float(pos[ix]), float(pos[iz])))
    return out


def _svg_polyline(pts: list[tuple[float, float]], scale, color: str, width: float = 2.0) -> str:
    if len(pts) < 2:
        return ""
    d = " ".join("%.1f,%.1f" % scale(p) for p in pts)
    return f'<polyline fill="none" stroke="{color}" stroke-width="{width}" points="{d}"/>'


def write_topdown(folder: Path) -> None:
    traj = _load(folder / "trajectory.json")
    geo = _load(folder / "geometry_contract.json")
    take = _load(folder / "takeoff_metrics.json")
    fc = _load(folder / "first_contact.json")
    samples = traj.get("samples") or []
    pred = traj.get("predicted") or []
    actual = _xy(samples, 0, 2)
    predicted = []
    for p in pred:
        if isinstance(p, list) and len(p) >= 3:
            predicted.append((float(p[0]), float(p[2])))
    xs = [p[0] for p in actual + predicted] or [0.0]
    zs = [p[1] for p in actual + predicted] or [0.0]
    land = (geo.get("landing_start") or [0, 0, -91])[2]
    takeoff_z = (geo.get("takeoff_edge") or [0, 0, -81])[2]
    deck = float(geo.get("deck_length") or 36.0)
    xs.extend([-5.5, 5.5])
    zs.extend([takeoff_z, land - deck])
    minx, maxx = min(xs) - 4, max(xs) + 4
    minz, maxz = min(zs) - 4, max(zs) + 4
    w, h = 720, 980

    def sc(p):
        x = (p[0] - minx) / max(maxx - minx, 0.001) * (w - 40) + 20
        z = (p[1] - minz) / max(maxz - minz, 0.001) * (h - 40) + 20
        return x, z

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">',
        '<rect width="100%" height="100%" fill="#111820"/>',
        _svg_polyline([(-5.5, takeoff_z), (-5.5, land - deck)], sc, "#446058", 1.5),
        _svg_polyline([(5.5, takeoff_z), (5.5, land - deck)], sc, "#446058", 1.5),
        _svg_polyline([(0, takeoff_z), (0, land - deck)], sc, "#2a3340", 1),
        _svg_polyline(predicted, sc, "#ff8c1a", 3),
        _svg_polyline(actual, sc, "#3ad0ff", 2.5),
    ]
    for name, pos, col in (
        ("TO", (geo.get("takeoff_edge") or [0, 0, takeoff_z])[0:3:2], "#7dff9a"),
        ("LS", (geo.get("landing_start") or [0, 0, land])[0:3:2], "#ffd24a"),
        ("FC", (fc.get("pos") or [0, 0, 0])[0:3:2], "#ff5ad5"),
    ):
        if len(pos) >= 2:
            x, z = sc((float(pos[0]), float(pos[1] if len(pos) == 2 else pos[-1])))
            parts.append(f'<circle cx="{x:.1f}" cy="{z:.1f}" r="5" fill="{col}"/>')
            parts.append(f'<text x="{x + 8:.1f}" y="{z:.1f}" fill="{col}" font-size="14">{name}</text>')
    to = take.get("takeoff") or {}
    parts.append(
        f'<text x="24" y="28" fill="#eee" font-size="16">topdown vx={to.get("vx")} yaw={to.get("yaw_deg")} speed={to.get("speed")}</text>'
    )
    parts.append("</svg>")
    (folder / "topdown_trajectory.svg").write_text("\n".join(parts), encoding="utf-8")


def write_side(folder: Path) -> None:
    traj = _load(folder / "trajectory.json")
    samples = traj.get("samples") or []
    pred = traj.get("predicted") or []
    actual = _xy(samples, 2, 1)
    predicted = []
    for p in pred:
        if isinstance(p, list) and len(p) >= 3:
            predicted.append((float(p[2]), float(p[1])))
    zs = [p[0] for p in actual + predicted] or [0.0]
    ys = [p[1] for p in actual + predicted] or [0.0]
    minz, maxz = min(zs) - 2, max(zs) + 2
    miny, maxy = min(ys) - 1, max(ys) + 2
    w, h = 980, 360

    def sc(p):
        x = (p[0] - minz) / max(maxz - minz, 0.001) * (w - 40) + 20
        y = h - 20 - (p[1] - miny) / max(maxy - miny, 0.001) * (h - 40)
        return x, y

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">',
        '<rect width="100%" height="100%" fill="#111820"/>',
        _svg_polyline(predicted, sc, "#ff8c1a", 3),
        _svg_polyline(actual, sc, "#3ad0ff", 2.5),
        "</svg>",
    ]
    (folder / "side_trajectory.svg").write_text("\n".join(parts), encoding="utf-8")


def summarize(folder: Path) -> dict:
    audit = _load(folder / "audit.json")
    ballistic = _load(folder / "ballistic.json")
    lat = _load(folder / "lateral_origin.json")
    return {
        "result": audit.get("result"),
        "takeoff_vx": audit.get("takeoff_vx"),
        "takeoff_yaw_deg": audit.get("takeoff_yaw_deg"),
        "deck_station": audit.get("deck_station"),
        "remaining_deck_m": audit.get("remaining_deck_m"),
        "ballistic_t": (ballistic or {}).get("t_hit"),
        "ballistic_station": (ballistic or {}).get("predicted_deck_station"),
        "first_vx_t": (lat.get("first_vx") or {}).get("t"),
        "first_vx_piece": (lat.get("first_vx") or {}).get("piece"),
        "first_yaw_t": (lat.get("first_yaw") or {}).get("t"),
        "first_yaw_piece": (lat.get("first_yaw") or {}).get("piece"),
        "impulse_x": lat.get("impulse_x"),
        "yaw_impulse": lat.get("yaw_impulse"),
        "left_lat": lat.get("left_lat"),
        "right_lat": lat.get("right_lat"),
    }


def plot_folder(folder: Path) -> dict:
    write_topdown(folder)
    write_side(folder)
    summary = summarize(folder)
    (folder / "plot_summary.json").write_text(json.dumps(summary, indent="\t"), encoding="utf-8")
    return summary


def main() -> None:
    import sys

    rel = sys.argv[1] if len(sys.argv) > 1 else "docs/generated/track_jump_v6/iteration_01"
    folder = ROOT / rel
    print(json.dumps(plot_folder(folder), indent=2))


if __name__ == "__main__":
    main()
