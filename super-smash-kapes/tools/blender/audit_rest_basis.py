"""Phase 6: Mixamo vs ActorCore rest basis audit for both characters."""
import os
import sys

import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import (  # noqa: E402
    find_armature,
    import_fbx,
    mapped_pairs_from_bone_map,
    quat_delta_degrees,
    reset_scene,
    write_json,
)
from actorcore_paths import BONE_MAP_JSON, CHARACTERS, IDLE_FBX, REST_BASIS_JSON


def _load_json(path):
    import json
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _extract_rest_quats(arm, bone_names) -> dict:
    out = {}
    for name in bone_names:
        if name in arm.data.bones:
            q = arm.data.bones[name].matrix_local.to_quaternion().copy()
            out[name] = q
    return out


def _quat_list(q) -> list:
    return [round(q.w, 6), round(q.x, 6), round(q.y, 6), round(q.z, 6)]


def audit_character(character_key: str, pairs: list, mixamo_rest: dict) -> dict:
    cfg = CHARACTERS[character_key]
    reset_scene()
    import_fbx(cfg["fbx"])
    target_arm = find_armature()
    bones = {}
    deltas = []
    target_rest = {}
    for pair in pairs:
        src = pair["source"]
        dst = pair["target"]
        if src not in mixamo_rest or dst not in target_arm.data.bones:
            continue
        s_q = mixamo_rest[src]
        t_q = target_arm.data.bones[dst].matrix_local.to_quaternion()
        target_rest[dst] = t_q.copy()
        corr = t_q.inverted() @ s_q
        angle = quat_delta_degrees(s_q, t_q)
        entry = {
            "source": src,
            "target": dst,
            "source_rest_quat": _quat_list(s_q),
            "target_rest_quat": _quat_list(t_q),
            "rest_correction_quat": _quat_list(corr),
            "rest_angle_delta_degrees": round(angle, 4),
        }
        bones["%s->%s" % (src, dst)] = entry
        deltas.append(angle)
    return {
        "character": character_key,
        "mapped_bones": len(bones),
        "mean_rest_angle_delta_degrees": round(sum(deltas) / max(len(deltas), 1), 4),
        "max_rest_angle_delta_degrees": round(max(deltas) if deltas else 0.0, 4),
        "bones": bones,
        "target_rest_quats": {k: _quat_list(v) for k, v in target_rest.items()},
        "note": "Large Mixamo vs ActorCore rest angles are expected (axis convention). Rest-relative transfer absorbs them.",
    }


def compare_actorcore_rests(terere: dict, jaguarete: dict) -> dict:
    t_rest = terere.get("target_rest_quats", {})
    j_rest = jaguarete.get("target_rest_quats", {})
    common = sorted(set(t_rest) & set(j_rest))
    deltas = []
    per_bone = {}
    from mathutils import Quaternion
    for name in common:
        tq = Quaternion(t_rest[name])
        jq = Quaternion(j_rest[name])
        angle = quat_delta_degrees(tq, jq)
        per_bone[name] = round(angle, 4)
        deltas.append(angle)
    max_delta = max(deltas) if deltas else 999.0
    mean_delta = sum(deltas) / max(len(deltas), 1)
    return {
        "common_mapped_bones": len(common),
        "mean_cross_character_rest_delta_degrees": round(mean_delta, 4),
        "max_cross_character_rest_delta_degrees": round(max_delta, 4),
        "per_bone_degrees": per_bone,
        "generic_retarget_viable": max_delta < 45.0,
        "note": "ActorCore vs ActorCore rest bases must match for one shared retarget implementation. Angles are shortest-arc; proportion differences (SHORT vs TALL) of tens of degrees are expected.",
    }


def main() -> None:
    bone_map = _load_json(BONE_MAP_JSON)
    pairs = mapped_pairs_from_bone_map(bone_map)
    source_names = [p["source"] for p in pairs]
    reset_scene()
    import_fbx(IDLE_FBX)
    mixamo_arm = find_armature()
    mixamo_rest = _extract_rest_quats(mixamo_arm, source_names)
    report = {
        "terere": audit_character("terere", pairs, mixamo_rest),
        "jaguarete": audit_character("jaguarete", pairs, mixamo_rest),
    }
    report["cross_character"] = compare_actorcore_rests(report["terere"], report["jaguarete"])
    report["both_generic_viable"] = report["cross_character"]["generic_retarget_viable"]
    write_json(REST_BASIS_JSON, report)
    print("Wrote %s generic_viable=%s" % (REST_BASIS_JSON, report["both_generic_viable"]))


if __name__ == "__main__":
    main()
