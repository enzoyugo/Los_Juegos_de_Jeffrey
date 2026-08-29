"""Offline future-fighter rig validator (Blender 2.83).

blender --background --python validate_future_rig.py -- --fbx <path> [--json <out>]
"""
import argparse
import json
import math
import os
import sys
import traceback

import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import find_armature, import_fbx, reset_scene, write_json  # noqa: E402
from overnight_deformation_forensics import bind_audit, evaluated_mesh_aabb, find_skinned_mesh, skin_weight_audit  # noqa: E402


HUMANOID_NEEDLES = (
    "Hip", "Hips", "Pelvis", "Spine", "Head",
    "Upperarm", "UpperArm", "Arm", "Forearm", "ForeArm", "Hand",
    "Thigh", "UpLeg", "Calf", "Leg", "Foot",
)

ACTORCORE_CRITICAL = (
    "CC_Base_Hip", "CC_Base_Spine01", "CC_Base_Head",
    "CC_Base_L_Upperarm", "CC_Base_L_Forearm", "CC_Base_L_Hand",
    "CC_Base_R_Upperarm", "CC_Base_R_Forearm", "CC_Base_R_Hand",
    "CC_Base_L_Thigh", "CC_Base_L_Calf", "CC_Base_L_Foot",
    "CC_Base_R_Thigh", "CC_Base_R_Calf", "CC_Base_R_Foot",
)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--fbx", required=True)
    p.add_argument("--json", default="")
    return p.parse_args(argv)


def verdict_from(report):
    rejects = report["reject_reasons"]
    reviews = report["review_reasons"]
    if rejects:
        return "REJECT"
    if reviews:
        return "MANUAL_REVIEW"
    return "AUTO_ACCEPT"


def main():
    args = parse_args()
    reset_scene()
    import_fbx(args.fbx)
    arm = find_armature()
    mesh = find_skinned_mesh(arm) if arm else None
    report = {
        "fbx": args.fbx,
        "armature": arm.name if arm else None,
        "mesh": mesh.name if mesh else None,
        "reject_reasons": [],
        "review_reasons": [],
    }
    if arm is None:
        report["reject_reasons"].append("no_armature")
    if mesh is None:
        report["reject_reasons"].append("no_skinned_mesh")
    if arm and mesh:
        bind = bind_audit(arm)
        skin = skin_weight_audit(arm)
        report["bone_count"] = bind.get("bone_count")
        report["bind"] = {"pose_bones_not_identity": bind.get("pose_bones_not_identity_count")}
        report["skin"] = skin
        names = [b.name for b in arm.data.bones]
        missing_actorcore = [n for n in ACTORCORE_CRITICAL if n not in names]
        if missing_actorcore:
            report["review_reasons"].append("not_actorcore_canonical: missing %s" % ",".join(missing_actorcore[:8]))
        humanoid_hits = sum(1 for needle in HUMANOID_NEEDLES if any(needle.lower() in n.lower() for n in names))
        if humanoid_hits < 8:
            report["reject_reasons"].append("not_enough_humanoid_bones hits=%d" % humanoid_hits)
        if bind.get("bone_count", 0) < 20:
            report["reject_reasons"].append("too_few_bones")
        skin0 = skin[0] if skin else {}
        if skin0.get("unweighted_ratio", 1) > 0.02:
            report["reject_reasons"].append("unweighted_vertices")
        if skin0.get("over_4_ratio", 0) > 0.25:
            report["review_reasons"].append("many_vertices_over_4_influences")
        if skin0.get("max_total_weight_deviation_from_1", 0) > 0.15:
            report["review_reasons"].append("weight_sum_not_normalized")
        xform = bind.get("armature") if isinstance(bind.get("armature"), dict) else {}
        if xform.get("negative_scale"):
            report["reject_reasons"].append("negative_armature_scale")
        bbox = evaluated_mesh_aabb(mesh)
        report["rest_bbox"] = bbox
        size = bbox.get("axis_size") or [0, 0, 0]
        if min(size) <= 0.001:
            report["reject_reasons"].append("degenerate_rest_bbox")
        vol = bbox.get("volume") or 0
        if vol <= 0:
            report["reject_reasons"].append("zero_volume_mesh")
    report["verdict"] = verdict_from(report)
    out = args.json or os.path.splitext(args.fbx)[0] + "_RIG_VALIDATION.json"
    write_json(out, report)
    print("FUTURE_RIG_VALIDATOR %s %s" % (report["verdict"], args.fbx))
    sys.exit(0 if report["verdict"] != "REJECT" else 2)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
