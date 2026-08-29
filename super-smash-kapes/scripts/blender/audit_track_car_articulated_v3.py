"""Auditor for Track articulated car GLBs (V2 baseline or V3 candidate).

Does not modify the candidate. Writes iteration folder metrics, renders, verdict.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import track_car_v3_lib as lib

SOURCE = ROOT / "assets/vehicles/track/source/track_car_base_v1.glb"
V2 = ROOT / "assets/vehicles/track/processed/track_car_base_v2_articulated.glb"
V3 = ROOT / "assets/vehicles/track/processed/track_car_base_v3_articulated_clean.glb"
ITERS = ROOT / "docs/generated/track_car_v3_iterations"

VIEWS = ("FRONT", "REAR", "LEFT", "RIGHT")
WHEEL_ANGLES = (0.0, 90.0, 180.0, 270.0)


def audit(label: str, glb: Path, out_dir: Path, compare_source: bool = True) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    renders = out_dir / "renders"
    renders.mkdir(exist_ok=True)
    defects = []

    src_sha = lib.sha256_file(SOURCE)
    if src_sha != lib.SOURCE_SHA256:
        defects.append("SOURCE_HASH_DRIFT")

    src = lib.fused_source_mesh(SOURCE)
    src180 = lib.transformed_copy(src, lib.yaw180)
    topo = lib.source_topology(src)
    parts = lib.extract_meshes(glb)

    mesh_metrics = {
        "label": label,
        "glb": str(glb.relative_to(ROOT)).replace("\\", "/"),
        "source_sha256": src_sha,
        "source_topology": topo,
        "nodes": sorted(parts.keys()),
        "embedded_images": _has_images(glb),
        "wheels": {},
        "body": {},
    }

    # Source vs candidate orientation renders (source always yaw-180).
    if compare_source:
        lib.render_parts([src180], renders / "source_front.png", "FRONT")
        lib.render_parts([src180], renders / "source_rear.png", "REAR")
        lib.render_parts([src180], renders / "source_left.png", "LEFT")
        lib.render_parts([src180], renders / "source_right.png", "RIGHT")

    cand_parts = list(parts.values())
    lib.render_parts(cand_parts, renders / "v3_front.png" if label != "V2" else renders / "v3_front.png", "FRONT")
    # Keep filenames from the spec even when auditing V2.
    lib.render_parts(cand_parts, renders / "v3_rear.png", "REAR")
    lib.render_parts(cand_parts, renders / "v3_left.png", "LEFT")
    lib.render_parts(cand_parts, renders / "v3_right.png", "RIGHT")

    body = parts.get("Body")
    if body is None:
        defects.append("MISSING_BODY")
    else:
        lib.render_parts([body], renders / "body_only_front.png", "FRONT")
        lib.render_parts([body], renders / "body_only_rear.png", "REAR")
        box = lib.aabb_of(body.positions)
        zmin, zmax = box["min"][2], box["max"][2]
        # Semantic: more geometry should exist on the nose (-Z) bumper AND a distinct rear wing at +Z.
        mesh_metrics["body"] = {
            "vertices": len(body.positions),
            "faces": len(body.indices) // 3,
            "aabb": box,
            "centroid": [round(x, 5) for x in lib.centroid(body.positions)],
            "z_min": round(zmin, 5),
            "z_max": round(zmax, 5),
        }
        morph = lib.semantic_orientation_metrics(body)
        mesh_metrics["body"]["semantic"] = morph
        if zmin >= -0.05:
            defects.append("BODY_NOSE_NOT_MINUS_Z")
        if not morph.get("pass"):
            defects.append("SEMANTIC_ORIENTATION_WING_NOT_PLUS_Z")

    for wid in lib.WHEEL_IDS:
        node = "Wheel_%s" % wid
        part = parts.get(node)
        if part is None:
            defects.append("MISSING_%s" % node)
            continue
        metrics = lib.wheel_metrics(part)
        mesh_metrics["wheels"][wid] = metrics
        if not metrics["gates"]["pass"]:
            defects.append("WHEEL_%s_GEOMETRY" % wid)
            for k, ok in metrics["gates"].items():
                if k != "pass" and not ok:
                    defects.append("WHEEL_%s_%s" % (wid, k.upper()))
        for ang in WHEEL_ANGLES:
            rad = math.radians(ang)
            # Look along the axle (+X) so the tire reads as a circle. FRONT is edge-on.
            lib.render_parts([part], renders / ("%s_%03d.png" % (wid, int(ang))), "LEFT", spin_x=rad)

    # Markers
    doc, _blob = lib.load_glb(glb)
    names = [n.get("name") for n in doc.get("nodes", [])]
    mesh_metrics["has_nose_marker"] = "NOSE_MARKER" in names
    mesh_metrics["has_rear_marker"] = "REAR_MARKER" in names
    if label.startswith("V3"):
        if "NOSE_MARKER" not in names or "REAR_MARKER" not in names:
            defects.append("MISSING_SEMANTIC_MARKERS")
        for n in doc.get("nodes", []):
            if n.get("name") in ("Body", "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"):
                sc = n.get("scale", [1, 1, 1])
                if any(abs(float(s) - 1.0) > 0.001 for s in sc):
                    defects.append("NON_UNIT_SCALE_%s" % n.get("name"))

    if mesh_metrics["embedded_images"]:
        defects.append("EMBEDDED_IMAGES")

    # Face ownership for V3 if report exists
    face_own = {}
    own_path = ROOT / "docs/generated/TRACK_CAR_V3_MESH_OWNERSHIP.json"
    if own_path.exists() and label.startswith("V3"):
        face_own = json.loads(own_path.read_text(encoding="utf-8"))
        src_faces = int(face_own.get("source_faces", 0))
        s = sum(int(face_own["parts"][k]["faces"]) for k in face_own.get("parts", {}))
        if src_faces and s != src_faces:
            defects.append("FACE_OWNERSHIP_SUM")

    semantic_ok = (
        "BODY_NOSE_NOT_MINUS_Z" not in defects
        and "SEMANTIC_ORIENTATION_WING_NOT_PLUS_Z" not in defects
    )
    wheel_pass = {wid: mesh_metrics["wheels"].get(wid, {}).get("gates", {}).get("pass", False) for wid in lib.WHEEL_IDS}
    sweep_ok = all(mesh_metrics["wheels"].get(wid, {}).get("spin_sweep", {}).get("pass", False) for wid in lib.WHEEL_IDS)
    aabb_ok = all(mesh_metrics["wheels"].get(wid, {}).get("gates", {}).get("aabb_compact", False) for wid in lib.WHEEL_IDS)
    radius_ok = all(mesh_metrics["wheels"].get(wid, {}).get("gates", {}).get("radius", False) for wid in lib.WHEEL_IDS)

    overall = "PASS" if not defects else "FAIL"
    verdict = {
        "label": label,
        "overall": overall,
        "semantic_orientation_pass": semantic_ok and "MISSING_SEMANTIC_MARKERS" not in defects if label.startswith("V3") else semantic_ok,
        "body_integrity_pass": body is not None and "BODY_NOSE_NOT_MINUS_Z" not in defects,
        "wheel_fl_geometry_pass": wheel_pass.get("FL", False),
        "wheel_fr_geometry_pass": wheel_pass.get("FR", False),
        "wheel_rl_geometry_pass": wheel_pass.get("RL", False),
        "wheel_rr_geometry_pass": wheel_pass.get("RR", False),
        "wheel_spin_sweep_pass": sweep_ok,
        "wheel_aabb_pass": aabb_ok,
        "wheel_radius_pass": radius_ok,
        "pivot_center_pass": None,
        "airborne_state_pass": None,
        "landing_telemetry_pass": None,
        "atlas_pass": None,
        "d3d12_pass": None,
        "validator_pass": None,
        "source_hash_pass": src_sha == lib.SOURCE_SHA256,
        "embedded_images_pass": not mesh_metrics["embedded_images"],
        "defects": defects,
        "visual_audit": "PENDING_IMAGE_INSPECTION",
    }
    (out_dir / "mesh_metrics.json").write_text(json.dumps(mesh_metrics, indent=2), encoding="utf-8")
    (out_dir / "face_ownership.json").write_text(json.dumps(face_own or {"note": "ownership filled after V3 build"}, indent=2), encoding="utf-8")
    (out_dir / "runtime_metrics.json").write_text(json.dumps({"status": "geometry_only_this_pass"}, indent=2), encoding="utf-8")
    (out_dir / "audit_verdict.json").write_text(json.dumps(verdict, indent=2), encoding="utf-8")
    (out_dir / "AUDIT.md").write_text(_audit_md(verdict, mesh_metrics), encoding="utf-8")
    print("[V3_AUDIT] %s overall=%s defects=%s" % (label, overall, defects))
    return verdict


def _has_images(path: Path) -> bool:
    doc, _ = lib.load_glb(path)
    return bool(doc.get("images") or doc.get("textures"))


def _audit_md(verdict: dict, metrics: dict) -> str:
    lines = [
        "# AUDIT %s" % verdict["label"],
        "",
        "## PRIMARY VERDICT",
        "",
        verdict["overall"],
        "",
        "## SEMANTIC ORIENTATION",
        "",
        str(verdict["semantic_orientation_pass"]),
        "",
        "## BODY",
        "",
        json.dumps(metrics.get("body", {}), indent=2),
        "",
        "## WHEELS",
        "",
    ]
    for wid in lib.WHEEL_IDS:
        w = metrics.get("wheels", {}).get(wid, {})
        lines.append("### %s" % wid)
        lines.append("verts=%s faces=%s max_r=%s aabb=%s comps=%s stray=%s sweep=%s pass=%s" % (
            w.get("vertices"), w.get("faces"), w.get("max_radius"),
            w.get("aabb", {}).get("size"), w.get("vertex_components"),
            len(w.get("stray_components", [])), w.get("spin_sweep", {}).get("pass"),
            w.get("gates", {}).get("pass"),
        ))
        lines.append("")
    lines += [
        "## DEFECTS TO FIX NEXT",
        "",
    ]
    if verdict["defects"]:
        for d in verdict["defects"]:
            lines.append("- %s" % d)
    else:
        lines.append("- none")
    lines.append("")
    return "\n".join(lines)


def main():
    label = "V2"
    glb = V2
    out = ITERS / "iteration_01"
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--label" and i + 1 < len(args):
            label = args[i + 1]
            i += 2
            continue
        if args[i] == "--glb" and i + 1 < len(args):
            glb = Path(args[i + 1])
            if not glb.is_absolute():
                glb = ROOT / glb
            i += 2
            continue
        if args[i] == "--out" and i + 1 < len(args):
            out = Path(args[i + 1])
            if not out.is_absolute():
                out = ROOT / out
            i += 2
            continue
        i += 1
    audit(label, glb, out)


if __name__ == "__main__":
    main()
