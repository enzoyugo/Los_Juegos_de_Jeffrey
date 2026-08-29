"""Build a clean articulated Track car V3 GLB from immutable source.

Face-level ownership. Fail hard if wheel envelopes / components / radius gates fail.
Does not overwrite source. Does not consume V2 geometry as authority.
"""
from __future__ import annotations

import json
import math
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import track_car_v3_lib as lib

SOURCE = ROOT / "assets/vehicles/track/source/track_car_base_v1.glb"
DST = ROOT / "assets/vehicles/track/processed/track_car_base_v3_articulated_clean.glb"
OWNERSHIP = ROOT / "docs/generated/TRACK_CAR_V3_MESH_OWNERSHIP.json"


def _in_envelope(p, axle, r_max, half_w) -> bool:
    d = lib.sub(p, axle)
    if abs(d[0]) > half_w:
        return False
    if math.hypot(d[1], d[2]) > r_max:
        return False
    if lib.hypot3(d) > r_max:
        return False
    return True


def _face_owner(pts, axles, r_max, half_w):
    """A face belongs to a wheel only if ALL vertices sit in that wheel envelope."""
    hits = []
    for wid, axle in axles.items():
        if all(_in_envelope(p, axle, r_max, half_w) for p in pts):
            hits.append(wid)
    if len(hits) == 1:
        return hits[0]
    if len(hits) > 1:
        c = lib.centroid(pts)
        hits.sort(key=lambda w: lib.dist(c, axles[w]))
        return hits[0]
    return "Body"


def split_source(r_max=None, half_w=None):
    r_max = lib.MAX_WHEEL_RADIUS_SOURCE if r_max is None else r_max
    half_w = lib.MAX_WHEEL_HALF_WIDTH_SOURCE if half_w is None else half_w
    sha = lib.sha256_file(SOURCE)
    if sha != lib.SOURCE_SHA256:
        raise RuntimeError("SOURCE HASH DRIFT %s expected %s" % (sha, lib.SOURCE_SHA256))
    fused = lib.fused_source_mesh(SOURCE)
    # Canonical processed space: 180° Y so source +Z nose becomes -Z.
    fused = lib.transformed_copy(fused, lib.yaw180)
    axles = lib.processed_axles_from_source()
    faces = lib.faces_of(fused)
    owner = []
    buckets = defaultdict(list)
    for fi, tri in enumerate(faces):
        pts = [fused.positions[i] for i in tri]
        who = _face_owner(pts, axles, r_max, half_w)
        owner.append(who)
        buckets[who].append(fi)

    # Reassign stray wheel components (centroid outside envelope) back to Body.
    reassigned = []
    for wid in lib.WHEEL_IDS:
        wfaces = buckets.get(wid, [])
        if not wfaces:
            continue
        tris = [faces[i] for i in wfaces]
        comps = lib.connected_face_components(tris)
        keep = []
        for comp in comps:
            local_faces = [tris[i] for i in comp]
            verts = {idx for tri in local_faces for idx in tri}
            pts = [lib.sub(fused.positions[i], axles[wid]) for i in verts]
            c = lib.centroid(pts)
            box = lib.aabb_of(pts)
            max_r = max(lib.hypot3(p) for p in pts)
            stray = (
                lib.hypot3(c) > r_max
                or max(box["size"]) > lib.MAX_WHEEL_AABB_AXIS_SOURCE
                or max_r > r_max
            )
            if stray:
                for li in comp:
                    orig = wfaces[li]
                    owner[orig] = "Body"
                    buckets["Body"].append(orig)
                    reassigned.append({"wheel": wid, "faces": 1, "reason": "stray_component", "centroid_r": round(lib.hypot3(c), 5), "max_r": round(max_r, 5)})
            else:
                keep.extend(comp)
        buckets[wid] = [wfaces[i] for i in keep]

    discarded = []  # prefer 0
    parts = []
    ownership = {
        "source_sha256": sha,
        "source_faces": len(faces),
        "r_max": r_max,
        "half_width": half_w,
        "axles": {k: list(v) for k, v in axles.items()},
        "reassigned_to_body": len(reassigned),
        "reassigned_sample": reassigned[:24],
        "discarded": 0,
        "parts": {},
    }
    body_faces = [faces[i] for i, who in enumerate(owner) if who == "Body"]
    body = lib.remap_part(fused, body_faces, (0.0, 0.0, 0.0), "Body")
    body.translation = (0.0, 0.0, 0.0)
    parts.append(body)
    ownership["parts"]["Body"] = _part_record(body, body_faces, fused)

    for wid in lib.WHEEL_IDS:
        wfaces = [faces[i] for i, who in enumerate(owner) if who == wid]
        if not wfaces:
            raise RuntimeError("V3 split produced empty wheel %s" % wid)
        axle = axles[wid]
        wheel = lib.remap_part(fused, wfaces, axle, "Wheel_%s" % wid)
        parts.append(wheel)
        ownership["parts"][wid] = _part_record(wheel, wfaces, fused, axle)

    assigned = sum(len(ownership["parts"][k].get("faces_source", [0])) if False else ownership["parts"][k]["faces"] for k in ownership["parts"])
    # faces counts on remapped parts
    face_sum = sum(p["faces"] for p in ownership["parts"].values())
    if face_sum + len(discarded) != len(faces):
        raise RuntimeError("face ownership sum mismatch %d vs %d" % (face_sum, len(faces)))

    # Hard gates on wheels before export.
    defects = []
    for wid in lib.WHEEL_IDS:
        m = lib.wheel_metrics(next(p for p in parts if p.name == "Wheel_%s" % wid))
        ownership["parts"][wid]["metrics"] = m
        if not m["gates"]["pass"]:
            defects.append({"wheel": wid, "gates": m["gates"], "max_radius": m["max_radius"], "aabb": m["aabb"]["size"], "stray": m["stray_components"][:4]})
    morph = lib.semantic_orientation_metrics(body)
    ownership["semantic"] = morph
    if not morph.get("pass"):
        defects.append({"semantic": morph})
    if defects:
        raise RuntimeError("V3 wheel integrity gates failed: %s" % json.dumps(defects, indent=2))

    nose, rear = _semantic_markers(body)
    empties = [
        {"name": "NOSE_MARKER", "translation": list(nose)},
        {"name": "REAR_MARKER", "translation": list(rear)},
    ]
    semantic = lib.sub(nose, rear)
    if semantic[2] >= -0.05:
        raise RuntimeError("NOSE_MARKER is not on -Z vs REAR_MARKER: nose=%s rear=%s" % (nose, rear))
    lib.write_glb(DST, parts, empties)
    ownership["nose_marker"] = list(nose)
    ownership["rear_marker"] = list(rear)
    ownership["semantic_forward"] = [round(x, 5) for x in semantic]
    ownership["output"] = str(DST.relative_to(ROOT)).replace("\\", "/")
    ownership["bytes"] = DST.stat().st_size
    OWNERSHIP.parent.mkdir(parents=True, exist_ok=True)
    OWNERSHIP.write_text(json.dumps(ownership, indent=2), encoding="utf-8")
    return ownership


def _part_record(part, face_tris, fused, axle=(0.0, 0.0, 0.0)) -> dict:
    box = lib.aabb_of(part.positions)
    used = [part.positions[i] for i in lib.used_vertices(part)]
    return {
        "vertices": len(part.positions),
        "faces": len(face_tris),
        "aabb": {k: [round(x, 5) for x in v] if isinstance(v, list) else v for k, v in box.items()},
        "centroid": [round(x, 5) for x in lib.centroid(used)],
        "translation": [round(x, 5) for x in part.translation],
        "max_radius": round(max((lib.hypot3(p) for p in used), default=0.0), 5),
        "vertex_components": len(lib.vertex_components(part)),
    }


def _semantic_markers(body: lib.MeshPart):
    """Markers from body morphology, not centroid and not wheel labels.

    After 180° Y, source +Z nose is processed -Z. Nose = most-forward (min Z)
    among central, mid-height bumper verts. Rear = most-aft (max Z) among
    central high verts (wing / deck), not the wheel wells.
    """
    pts = [body.positions[i] for i in lib.used_vertices(body)]
    nose_cands = [p for p in pts if abs(p[0]) < 0.09 and 0.02 < p[1] < 0.16]
    rear_cands = [p for p in pts if abs(p[0]) < 0.16 and p[1] > 0.10]
    if not nose_cands:
        nose_cands = [p for p in pts if abs(p[0]) < 0.12]
    if not rear_cands:
        rear_cands = [p for p in pts if abs(p[0]) < 0.18]
    nose_p = min(nose_cands, key=lambda p: p[2])
    rear_p = max(rear_cands, key=lambda p: p[2])
    nose = (0.0, max(0.08, nose_p[1]), nose_p[2])
    rear = (0.0, max(0.10, rear_p[1]), rear_p[2])
    return nose, rear


def main():
    r_max = lib.MAX_WHEEL_RADIUS_SOURCE
    half_w = lib.MAX_WHEEL_HALF_WIDTH_SOURCE
    args = sys.argv[1:]
    for i, a in enumerate(args):
        if a == "--r-max" and i + 1 < len(args):
            r_max = float(args[i + 1])
        if a == "--half-width" and i + 1 < len(args):
            half_w = float(args[i + 1])
    ownership = split_source(r_max=r_max, half_w=half_w)
    print("[V3_BUILD] wrote %s faces_body=%d FL=%d FR=%d RL=%d RR=%d" % (
        DST,
        ownership["parts"]["Body"]["faces"],
        ownership["parts"]["FL"]["faces"],
        ownership["parts"]["FR"]["faces"],
        ownership["parts"]["RL"]["faces"],
        ownership["parts"]["RR"]["faces"],
    ))
    print("[V3_BUILD] semantic_forward=%s" % ownership["semantic_forward"])


if __name__ == "__main__":
    main()
