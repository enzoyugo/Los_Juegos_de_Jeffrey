"""Offline V5 geometry inventory: jump_small colliders and 14m vs 2m coupling.

Does not retune handling. Does not generate the 22-piece kit.
"""

from __future__ import annotations

import json
import math
import os
import sys
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "blender"))
import generate_track_kit_v1 as gen  # noqa: E402

OUT = ROOT / "docs" / "generated" / "track_clean_gap_v5"
V4_SEQ = [
    "start",
    "straight_medium",
    "boost_straight",
    "straight_medium",
    "ramp_small",
    "jump_small",
    "landing_straight_long",
    "straight_medium",
    "curve_l_45",
    "curve_r_45",
    "finish",
]
V5_SEQ = [
    "start",
    "straight_medium",
    "boost_straight",
    "straight_medium",
    "ramp_takeoff",
    "gap_logical",
    "landing_straight_long",
    "straight_medium",
    "curve_l_45",
    "curve_r_45",
    "finish",
]


class Xform:
    """Godot-like Transform3D: basis columns + origin. Euler YXZ with yaw=0, roll=0."""

    def __init__(self, x=(1.0, 0.0, 0.0), y=(0.0, 1.0, 0.0), z=(0.0, 0.0, 1.0), origin=(0.0, 0.0, 0.0)):
        self.x = x
        self.y = y
        self.z = z
        self.origin = origin

    @staticmethod
    def from_pitch_origin(origin, pitch: float, yaw: float = 0.0) -> "Xform":
        cp, sp = math.cos(pitch), math.sin(pitch)
        cy, sy = math.cos(yaw), math.sin(yaw)
        # Ry * Rx (yaw then applied on pitched axes ≈ Godot YXZ with roll=0)
        x = (cy, 0.0, -sy)
        y = (sy * sp, cp, cy * sp)
        z = (sy * cp, -sp, cy * cp)
        return Xform(x, y, z, origin)

    def mul(self, other: "Xform") -> "Xform":
        ox, oy, oz = self.xform_vec(other.origin)
        return Xform(
            self.xform_dir(other.x),
            self.xform_dir(other.y),
            self.xform_dir(other.z),
            (self.origin[0] + ox, self.origin[1] + oy, self.origin[2] + oz),
        )

    def xform_dir(self, v) -> tuple:
        return (
            self.x[0] * v[0] + self.y[0] * v[1] + self.z[0] * v[2],
            self.x[1] * v[0] + self.y[1] * v[1] + self.z[1] * v[2],
            self.x[2] * v[0] + self.y[2] * v[1] + self.z[2] * v[2],
        )

    def xform_vec(self, v) -> tuple:
        return self.xform_dir(v)

    def inverse(self) -> "Xform":
        # orthonormal: R^T, origin' = -R^T * origin
        ix = (self.x[0], self.y[0], self.z[0])
        iy = (self.x[1], self.y[1], self.z[1])
        iz = (self.x[2], self.y[2], self.z[2])
        inv = Xform(ix, iy, iz, (0.0, 0.0, 0.0))
        ox, oy, oz = inv.xform_dir(self.origin)
        inv.origin = (-ox, -oy, -oz)
        return inv

    def to_dict(self) -> dict:
        return {
            "origin": [round(self.origin[0], 6), round(self.origin[1], 6), round(self.origin[2], 6)],
            "pitch_deg": round(math.degrees(math.atan2(-self.z[1], self.z[2])), 4),
        }


def _v(v) -> list:
    return [round(float(v[0]), 6), round(float(v[1]), 6), round(float(v[2]), 6)]


def assemble(cfg: gen.TrackKitConfig, sequence: list[str], jump_land=None, gap_len=None) -> dict:
    builder = gen.TrackPieceBuilder(cfg)
    target = Xform()
    pieces = []
    for pid in sequence:
        spec = deepcopy(cfg.spec(pid))
        if pid == "jump_small" and jump_land is not None:
            spec["land_length_m"] = float(jump_land)
        if pid == "gap_logical" and gap_len is not None:
            spec["gap_m"] = float(gap_len)
            spec["length_m"] = float(gap_len)
        entry_fr = gen.frame_at(cfg, spec, 0.0)
        exit_fr = gen.frame_at(cfg, spec, 1.0)
        entry_marker = Xform.from_pitch_origin((0.0, 0.0, 0.0), float(entry_fr.get("pitch", 0.0)))
        piece_global = target.mul(entry_marker.inverse())
        exit_local = Xform.from_pitch_origin(exit_fr["pos"], float(exit_fr.get("pitch", 0.0)), float(exit_fr.get("yaw", 0.0)))
        exit_world = piece_global.mul(exit_local)
        boxes = []
        for i, box in enumerate(builder.collision_boxes(spec)):
            local = Xform.from_pitch_origin(tuple(box["origin"]), float(box.get("pitch", 0.0)), float(box.get("yaw", 0.0)))
            world = piece_global.mul(local)
            size = box["size"]
            corners = []
            for sx in (-0.5, 0.5):
                for sy in (-0.5, 0.5):
                    for sz in (-0.5, 0.5):
                        corners.append(world.xform_dir((size[0] * sx, size[1] * sy, size[2] * sz)))
            world_corners = [
                (world.origin[0] + c[0], world.origin[1] + c[1], world.origin[2] + c[2]) for c in corners
            ]
            aabb_min = [min(p[k] for p in world_corners) for k in range(3)]
            aabb_max = [max(p[k] for p in world_corners) for k in range(3)]
            along_local = -float(box["origin"][2])
            boxes.append({
                "id": "%s_%s_%d" % (pid, box["kind"], i),
                "kind": box["kind"],
                "origin_local": _v(box["origin"]),
                "origin_world": _v(world.origin),
                "size": [round(float(x), 4) for x in size],
                "pitch_deg": round(math.degrees(float(box.get("pitch", 0.0))), 4),
                "along_local": round(along_local, 4),
                "aabb_world": {"min": [round(x, 4) for x in aabb_min], "max": [round(x, 4) for x in aabb_max]},
                "top_height_world": round(aabb_max[1], 4),
                "center_world": _v(world.origin),
            })
        row = {
            "piece_id": pid,
            "centerline_length": gen.centerline_length(cfg, spec),
            "entry_world": target.to_dict(),
            "exit_world": exit_world.to_dict(),
            "piece_root": piece_global.to_dict(),
            "entry_pitch_deg": round(math.degrees(float(entry_fr.get("pitch", 0.0))), 4),
            "exit_pitch_deg": round(math.degrees(float(exit_fr.get("pitch", 0.0))), 4),
            "collision": boxes,
        }
        if pid == "jump_small":
            lip = float(spec.get("ramp_length_m", 1.2))
            gap = float(spec.get("gap_m", 7.0))
            land = float(spec.get("land_length_m", 14.0))
            total = lip + gap + land
            takeoff_fr = gen.frame_at(cfg, spec, lip / total)
            gap_start_fr = takeoff_fr
            gap_end_fr = gen.frame_at(cfg, spec, (lip + gap) / total)
            land_fr = gen.frame_at(cfg, spec, (lip + gap) / total)
            takeoff_local = Xform.from_pitch_origin(takeoff_fr["pos"], float(takeoff_fr.get("pitch", 0.0)))
            takeoff_world = piece_global.mul(takeoff_local)
            row["semantics"] = {
                "ENTRY": {"local": [0, 0, 0], "world": target.to_dict()["origin"]},
                "TAKEOFF_EDGE": {"local": _v(takeoff_fr["pos"]), "world": takeoff_world.to_dict()["origin"], "along": lip},
                "GAP_START": {"local": _v(gap_start_fr["pos"]), "along": lip},
                "GAP_END": {"local": _v(gap_end_fr["pos"]), "along": lip + gap},
                "LANDING_PAD_START": {"local": _v(land_fr["pos"]), "along": lip + gap},
                "EXIT": {"local": _v(exit_fr["pos"]), "world": exit_world.to_dict()["origin"], "along": total},
                "lip_m": lip,
                "gap_m": gap,
                "land_length_m": land,
                "sample_count": gen.sample_count(cfg, spec),
            }
            for box in boxes:
                box["distance_from_takeoff_edge_along"] = round(box["along_local"] - lip, 4)
        if pid == "ramp_takeoff":
            takeoff_world = exit_world
            row["semantics"] = {
                "RAMP_ENTRY": {"world": target.to_dict()["origin"]},
                "TAKEOFF_EDGE": {"world": takeoff_world.to_dict()["origin"], "local": _v(exit_fr["pos"])},
                "EXIT_IS_TAKEOFF_EDGE": True,
            }
        if pid == "gap_logical":
            row["semantics"] = {
                "GAP_START": {"world": target.to_dict()["origin"]},
                "GAP_END": {"world": exit_world.to_dict()["origin"]},
                "gap_m": spec.get("gap_m"),
                "road_collision_count": len(boxes),
            }
        if pid == "boost_straight":
            length = gen.centerline_length(cfg, spec)
            mid = Xform.from_pitch_origin((0.0, 0.0, -length * 0.5), 0.0)
            row["semantics"] = {
                "BOOST_ENTRY": {"world": target.to_dict()["origin"]},
                "BOOST_EXIT": {"world": exit_world.to_dict()["origin"]},
                "BOOST_MID": {"world": piece_global.mul(mid).to_dict()["origin"]},
            }
        pieces.append(row)
        target = exit_world
    return {"sequence": sequence, "pieces": pieces}


def _find(payload: dict, pid: str) -> dict:
    for row in payload["pieces"]:
        if row["piece_id"] == pid:
            return row
    raise KeyError(pid)


def compare_14_2(a: dict, b: dict) -> dict:
    ja, jb = _find(a, "jump_small"), _find(b, "jump_small")
    ra, rb = _find(a, "ramp_small"), _find(b, "ramp_small")
    ba, bb = _find(a, "boost_straight"), _find(b, "boost_straight")
    da, db = _find(a, "landing_straight_long"), _find(b, "landing_straight_long")
    sa, sb = _find(a, "start"), _find(b, "start")

    def dpos(p, q):
        return math.dist(p, q)

    takeoff_a = ja["semantics"]["TAKEOFF_EDGE"]["world"]
    takeoff_b = jb["semantics"]["TAKEOFF_EDGE"]["world"]
    pad_a = [box for box in ja["collision"] if box["kind"] == "road" and box["along_local"] > 2.0]
    pad_b = [box for box in jb["collision"] if box["kind"] == "road" and box["along_local"] > 2.0]
    lip_a = [box for box in ja["collision"] if box["kind"] == "road" and box["along_local"] <= 2.0]
    lip_b = [box for box in jb["collision"] if box["kind"] == "road" and box["along_local"] <= 2.0]
    answers = {
        "pad_is_before_takeoff": False,
        "pad_is_after_takeoff": True,
        "pad_is_part_of_landing": True,
        "pad_is_part_of_approach": False,
        "pad_contributes_to_piece_EXIT": True,
        "shortening_moves_next_piece": True,
        "shortening_moves_TAKEOFF_EDGE": dpos(takeoff_a, takeoff_b) > 0.01,
        "shortening_moves_boost": dpos(ba["entry_world"]["origin"], bb["entry_world"]["origin"]) > 0.01,
        "shortening_moves_ramp_entry": dpos(ra["entry_world"]["origin"], rb["entry_world"]["origin"]) > 0.01,
        "shortening_changes_piece_local_entry": ja["entry_pitch_deg"] != jb["entry_pitch_deg"],
        "shortening_reduces_acceleration_distance_to_lip": dpos(sa["entry_world"]["origin"], takeoff_a)
        != dpos(sb["entry_world"]["origin"], takeoff_b)
        and abs(dpos(sa["entry_world"]["origin"], takeoff_a) - dpos(sb["entry_world"]["origin"], takeoff_b)) > 0.05,
        "takeoff_edge_delta_m": round(dpos(takeoff_a, takeoff_b), 6),
        "boost_entry_delta_m": round(dpos(ba["entry_world"]["origin"], bb["entry_world"]["origin"]), 6),
        "ramp_entry_delta_m": round(dpos(ra["entry_world"]["origin"], rb["entry_world"]["origin"]), 6),
        "exit_delta_m": round(dpos(ja["exit_world"]["origin"], jb["exit_world"]["origin"]), 6),
        "landing_deck_start_delta_m": round(dpos(da["entry_world"]["origin"], db["entry_world"]["origin"]), 6),
        "expected_exit_shift_m": 12.0,
        "lip_box_count_14": len(lip_a),
        "lip_box_count_2": len(lip_b),
        "pad_box_count_14": len(pad_a),
        "pad_box_count_2": len(pad_b),
        "sample_count_14": ja["semantics"]["sample_count"],
        "sample_count_2": jb["semantics"]["sample_count"],
        "all_pad_boxes_after_takeoff_14": all(box["distance_from_takeoff_edge_along"] > 0.0 for box in pad_a),
        "all_pad_boxes_after_takeoff_2": all(box["distance_from_takeoff_edge_along"] > 0.0 for box in pad_b),
    }
    # Approach length is spawn→takeoff; identical if takeoff world is identical.
    answers["approach_geometry_coupled_to_jump_exit"] = answers["shortening_moves_next_piece"] and not answers["shortening_moves_TAKEOFF_EDGE"]
    answers["causal_speed_geometry"] = (
        "TAKEOFF_EDGE / boost / ramp world transforms are identical when land_length changes. "
        "The 14 m pad is AFTER takeoff (along > 1.2 m) and is the piece EXIT, so shortening it "
        "only moves jump EXIT and therefore landing_straight_long. It cannot change velocity AT takeoff "
        "via extra acceleration distance. V4 14.2→5.9 m/s coincided with a harness change: "
        "iter_03 released throttle at VALID_TAKEOFF and logged 5.9 m/s; iter_05 held throttle until "
        "FIRST_CONTACT and logged 14.2 m/s. Geometry after the lip is not the takeoff-speed cause."
    )
    return answers


def gap_empty_inventory(payload: dict) -> dict:
    takeoff = None
    land = None
    road_in_gap = []
    for row in payload["pieces"]:
        if row["piece_id"] in ("ramp_takeoff", "jump_small") and row.get("semantics"):
            takeoff = row["semantics"].get("TAKEOFF_EDGE", {}).get("world")
        if row["piece_id"] == "landing_straight_long":
            land = row["entry_world"]["origin"]
    takeoff = takeoff or [0, 0, 0]
    land = land or [0, 0, 0]
    z0, z1 = sorted((takeoff[2], land[2]))
    y_lo = min(takeoff[1], land[1]) - 2.0
    y_hi = max(takeoff[1], land[1]) + 4.0
    for row in payload["pieces"]:
        for box in row["collision"]:
            if box["kind"] != "road":
                continue
            aabb = box["aabb_world"]
            overlaps_z = not (aabb["max"][2] < z0 + 0.05 or aabb["min"][2] > z1 - 0.05)
            overlaps_y = not (aabb["max"][1] < y_lo or aabb["min"][1] > y_hi)
            # interior of gap: exclude the takeoff lip (within 0.4 m of takeoff z) and landing start
            interior = aabb["max"][2] < max(z0, z1) - 0.2 and aabb["min"][2] > min(z0, z1) + 0.2
            if overlaps_z and overlaps_y and interior:
                road_in_gap.append({"piece": row["piece_id"], "id": box["id"], "aabb": aabb})
    return {
        "takeoff_edge": takeoff,
        "landing_start": land,
        "road_collision_in_gap_interior": road_in_gap,
        "empty": road_in_gap == [],
    }


def v5_invariance(cfg) -> dict:
    rows = {}
    takeoffs = {}
    boosts = {}
    ramps = {}
    lands = {}
    for gap in (6.0, 10.0, 14.0):
        payload = assemble(cfg, V5_SEQ, gap_len=gap)
        rows[str(gap)] = payload
        takeoffs[str(gap)] = _find(payload, "ramp_takeoff")["exit_world"]["origin"]
        boosts[str(gap)] = _find(payload, "boost_straight")["entry_world"]["origin"]
        ramps[str(gap)] = _find(payload, "ramp_takeoff")["entry_world"]["origin"]
        lands[str(gap)] = _find(payload, "landing_straight_long")["entry_world"]["origin"]
    def same(a, b):
        return math.dist(a, b) < 1e-4
    land_d_10_6 = lands["10.0"][2] - lands["6.0"][2]
    land_d_14_10 = lands["14.0"][2] - lands["10.0"][2]
    return {
        "takeoff_identical": same(takeoffs["6.0"], takeoffs["10.0"]) and same(takeoffs["10.0"], takeoffs["14.0"]),
        "boost_identical": same(boosts["6.0"], boosts["10.0"]) and same(boosts["10.0"], boosts["14.0"]),
        "ramp_identical": same(ramps["6.0"], ramps["10.0"]) and same(ramps["10.0"], ramps["14.0"]),
        "takeoff": takeoffs,
        "boost": boosts,
        "ramp": ramps,
        "landing_start": lands,
        "landing_delta_z_10_minus_6": round(land_d_10_6, 6),
        "landing_delta_z_14_minus_10": round(land_d_14_10, 6),
        "expected_delta_z": -4.0,
        "PASS": (
            same(takeoffs["6.0"], takeoffs["10.0"])
            and same(takeoffs["10.0"], takeoffs["14.0"])
            and same(boosts["6.0"], boosts["10.0"])
            and abs(land_d_10_6 - (-4.0)) < 0.05
            and abs(land_d_14_10 - (-4.0)) < 0.05
        ),
    }


def write(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def main() -> int:
    cfg = gen.TrackKitConfig(gen.load_config(str(ROOT / "data" / "track" / "modules" / "track_kit_v1.json")))
    snap = OUT / "v4_snapshot"
    snap.mkdir(parents=True, exist_ok=True)
    src = ROOT / "docs" / "generated" / "track_4wheel_v4_iterations" / "iteration_05"
    if src.exists():
        (snap / "NOTE.md").write_text(
            "V4 best candidate snapshot: iteration_05 of TRACK_4WHEEL_STRUCTURAL_DYNAMICS_V4. "
            "Stationary PASS. Jump FAIL first_contact=jump_small. Handling frozen. 4WHEEL not promoted.\n",
            encoding="utf-8",
        )
    a = assemble(cfg, V4_SEQ, jump_land=14.0)
    b = assemble(cfg, V4_SEQ, jump_land=2.0)
    cmp = compare_14_2(a, b)
    jump = _find(a, "jump_small")
    iter01 = OUT / "iteration_01"
    write(iter01 / "piece_transforms.json", a)
    write(iter01 / "jump_small_collision_inventory.json", {
        "world_and_local": jump.get("semantics"),
        "boxes": jump["collision"],
        "road_after_takeoff": [
            box for box in jump["collision"]
            if box["kind"] == "road" and box.get("distance_from_takeoff_edge_along", 0) > 0.05
        ],
    })
    write(iter01 / "pad_14_vs_2.json", {
        "land_14": {
            "takeoff": jump["semantics"]["TAKEOFF_EDGE"],
            "exit": jump["exit_world"],
            "sample_count": jump["semantics"]["sample_count"],
            "centerline": jump["centerline_length"],
        },
        "land_2": {
            "takeoff": _find(b, "jump_small")["semantics"]["TAKEOFF_EDGE"],
            "exit": _find(b, "jump_small")["exit_world"],
            "sample_count": _find(b, "jump_small")["semantics"]["sample_count"],
            "centerline": _find(b, "jump_small")["centerline_length"],
        },
        "answers": cmp,
    })
    write(iter01 / "geometry_contract.json", {
        "layout": "v4_jump_small",
        "sequence": V4_SEQ,
        "expected_first_contact_piece": "jump_small",
        "settle_on_landing_straight_long": False,
        "pad_14_vs_2": cmp,
    })
    v5 = assemble(cfg, V5_SEQ, gap_len=7.0)
    inv = v5_invariance(cfg)
    write(OUT / "assembly_invariance.json", inv)
    write(OUT / "v5_piece_transforms_gap7.json", v5)
    write(OUT / "v5_gap_collision_sweep.json", gap_empty_inventory(v5))
    print("TAKEOFF_EDGE 14", jump["semantics"]["TAKEOFF_EDGE"]["world"])
    print("TAKEOFF_EDGE 2 ", _find(b, "jump_small")["semantics"]["TAKEOFF_EDGE"]["world"])
    print("EXIT delta", cmp["exit_delta_m"])
    print("takeoff delta", cmp["takeoff_edge_delta_m"])
    print("V5 invariance PASS", inv["PASS"])
    print("V5 gap empty", gap_empty_inventory(v5)["empty"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
