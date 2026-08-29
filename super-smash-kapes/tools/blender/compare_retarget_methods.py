"""Compare retarget change-of-basis methods by skinned bbox/volume.

blender --background --python compare_retarget_methods.py -- --character terere
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector, Quaternion

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import (  # noqa: E402
    clear_pose,
    find_armature,
    find_source_action,
    import_fbx,
    mapped_pairs_from_bone_map,
    reset_scene,
    write_json,
)
from actorcore_paths import BONE_MAP_JSON, CHARACTERS, GENERATED_DIR, IDLE_FBX  # noqa: E402


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--character", required=True, choices=["terere", "jaguarete"])
    return p.parse_args(argv)


def vec3(v):
    return [round(float(v.x), 6), round(float(v.y), 6), round(float(v.z), 6)]


def mesh_aabb(mesh_obj):
    deps = bpy.context.evaluated_depsgraph_get()
    eval_obj = mesh_obj.evaluated_get(deps)
    data = eval_obj.data
    xs = [v.co.x for v in data.vertices]
    ys = [v.co.y for v in data.vertices]
    zs = [v.co.z for v in data.vertices]
    size = Vector((max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
    return {
        "size": vec3(size),
        "max_axis": round(max(size.x, size.y, size.z), 4),
        "volume": round(abs(size.x * size.y * size.z), 2),
    }


def skinned_mesh(arm):
    for obj in bpy.data.objects:
        if obj.type == "MESH" and any(m.type == "ARMATURE" and m.object == arm for m in obj.modifiers):
            return obj
    return None


def parent_rel_rest(arm, name):
    db = arm.data.bones[name]
    if db.parent:
        rel = db.parent.matrix_local.inverted() @ db.matrix_local
    else:
        rel = db.matrix_local.copy()
    return rel.to_quaternion().to_matrix()


def armature_rest_world_ortho(arm, name):
    db = arm.data.bones[name]
    m = (arm.matrix_world @ db.matrix_local).to_3x3()
    return m.to_quaternion().to_matrix()


def apply_method(method, source_arm, target_arm, src, dst):
    s_pb = source_arm.pose.bones[src]
    t_pb = target_arm.pose.bones[dst]
    s_basis = s_pb.matrix_basis.to_3x3()
    t_pb.rotation_mode = "QUATERNION"
    t_pb.location = Vector((0.0, 0.0, 0.0))
    t_pb.scale = Vector((1.0, 1.0, 1.0))
    if method == "direct_basis":
        t_pb.matrix_basis = s_pb.matrix_basis.copy()
        t_pb.location = Vector((0.0, 0.0, 0.0))
        t_pb.scale = Vector((1.0, 1.0, 1.0))
        return
    if method == "direct_quat":
        t_pb.rotation_quaternion = s_pb.matrix_basis.to_quaternion()
        return
    if method == "parent_rel":
        s_ps = parent_rel_rest(source_arm, src)
        t_ps = parent_rel_rest(target_arm, dst)
        world = s_ps @ s_basis @ s_ps.inverted()
        t_rot = t_ps.inverted() @ world @ t_ps
        t_pb.rotation_quaternion = t_rot.to_quaternion()
        return
    if method == "current_world":
        s_rest = armature_rest_world_ortho(source_arm, src)
        t_rest = armature_rest_world_ortho(target_arm, dst)
        world = s_rest @ s_basis @ s_rest.inverted()
        t_rot = t_rest.inverted() @ world @ t_rest
        t_pb.rotation_quaternion = t_rot.to_quaternion()
        return
    if method == "current_raw_3x3":
        s_db = source_arm.data.bones[src]
        t_db = target_arm.data.bones[dst]
        s_rest = (source_arm.matrix_world @ s_db.matrix_local).to_3x3()
        t_rest = (target_arm.matrix_world @ t_db.matrix_local).to_3x3()
        world = s_rest @ s_basis @ s_rest.inverted()
        t_rot = t_rest.inverted() @ world @ t_rest
        t_pb.matrix_basis = t_rot.to_4x4()
        t_pb.location = Vector((0.0, 0.0, 0.0))
        t_pb.scale = Vector((1.0, 1.0, 1.0))
        return
    raise ValueError(method)


def pose_scale_stats(arm):
    bad = []
    for pb in arm.pose.bones:
        if any(abs(s - 1.0) > 0.01 for s in pb.scale):
            bad.append({"bone": pb.name, "scale": vec3(pb.scale)})
    return bad[:20]


def main():
    args = parse_args()
    cfg = CHARACTERS[args.character]
    with open(BONE_MAP_JSON, "r", encoding="utf-8") as fh:
        pairs = mapped_pairs_from_bone_map(json.load(fh))
    methods = ["direct_quat", "direct_basis", "parent_rel", "current_world", "current_raw_3x3"]
    results = []
    for method in methods:
        reset_scene()
        import_fbx(cfg["fbx"])
        target = find_armature()
        import_fbx(IDLE_FBX)
        source = [a for a in bpy.data.objects if a.type == "ARMATURE" and a != target][0]
        action = find_source_action(source, "mixamo")
        source.animation_data_create()
        source.animation_data.action = action
        mesh = skinned_mesh(target)
        clear_pose(target)
        bpy.context.view_layer.update()
        rest = mesh_aabb(mesh)
        frame = int((action.frame_range[0] + action.frame_range[1]) * 0.5)
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        for pair in pairs:
            if pair["source"] in source.pose.bones and pair["target"] in target.pose.bones:
                apply_method(method, source, target, pair["source"], pair["target"])
        bpy.context.view_layer.update()
        posed = mesh_aabb(mesh)
        vol_ratio = posed["volume"] / max(rest["volume"], 1.0)
        max_ratio = posed["max_axis"] / max(rest["max_axis"], 1e-6)
        scales = pose_scale_stats(target)
        results.append({
            "method": method,
            "rest": rest,
            "idle_mid": posed,
            "volume_ratio": round(vol_ratio, 4),
            "max_axis_ratio": round(max_ratio, 4),
            "non_unit_pose_scales": scales,
            "verdict": "PASS" if vol_ratio < 1.45 and max_ratio < 1.35 else "FAIL",
        })
        print("METHOD %s vol=%.3f max=%.3f %s" % (method, vol_ratio, max_ratio, results[-1]["verdict"]))
    write_json(os.path.join(GENERATED_DIR, "%s_RETARGET_METHOD_COMPARE.json" % args.character.upper()), {
        "character": args.character,
        "results": results,
    })


if __name__ == "__main__":
    main()
