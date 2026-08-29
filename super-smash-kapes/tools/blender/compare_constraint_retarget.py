"""Dump Mixamo basis magnitudes and test Copy Rotation constraint retarget.

blender --background --python compare_constraint_retarget.py -- --character terere
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Vector

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


def mesh_aabb(mesh_obj):
    deps = bpy.context.evaluated_depsgraph_get()
    eval_obj = mesh_obj.evaluated_get(deps)
    xs = [v.co.x for v in eval_obj.data.vertices]
    ys = [v.co.y for v in eval_obj.data.vertices]
    zs = [v.co.z for v in eval_obj.data.vertices]
    size = Vector((max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
    return {
        "size": [round(size.x, 3), round(size.y, 3), round(size.z, 3)],
        "volume": round(abs(size.x * size.y * size.z), 2),
        "max_axis": round(max(size.x, size.y, size.z), 3),
    }


def skinned(arm):
    for obj in bpy.data.objects:
        if obj.type == "MESH" and any(m.type == "ARMATURE" and m.object == arm for m in obj.modifiers):
            return obj
    return None


def basis_deg(pb):
    ang = abs(math.degrees(pb.matrix_basis.to_quaternion().angle)) % 360.0
    if ang > 180:
        ang = 360 - ang
    return round(ang, 3)


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--character", default="terere")
    args = p.parse_args(argv)
    cfg = CHARACTERS[args.character]
    with open(BONE_MAP_JSON, "r", encoding="utf-8") as fh:
        pairs = mapped_pairs_from_bone_map(json.load(fh))

    reset_scene()
    import_fbx(cfg["fbx"])
    target = find_armature()
    import_fbx(IDLE_FBX)
    source = [a for a in bpy.data.objects if a.type == "ARMATURE" and a != target][0]
    action = find_source_action(source, "mixamo")
    source.animation_data_create()
    source.animation_data.action = action
    mesh = skinned(target)

    mixamo_frames = []
    for frame in (int(action.frame_range[0]), int((action.frame_range[0] + action.frame_range[1]) * 0.5)):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        entry = {"frame": frame, "bones": []}
        for pair in pairs:
            src = pair["source"]
            if src in source.pose.bones:
                pb = source.pose.bones[src]
                entry["bones"].append({
                    "bone": src,
                    "basis_deg": basis_deg(pb),
                    "location": [round(float(x), 4) for x in pb.location],
                    "scale": [round(float(x), 4) for x in pb.scale],
                })
        mixamo_frames.append(entry)

    clear_pose(target)
    bpy.context.view_layer.update()
    rest = mesh_aabb(mesh)

    # Copy Rotation LOCAL + offset
    for pair in pairs:
        if pair["source"] not in source.pose.bones or pair["target"] not in target.pose.bones:
            continue
        pb = target.pose.bones[pair["target"]]
        c = pb.constraints.new("COPY_ROTATION")
        c.target = source
        c.subtarget = pair["source"]
        if hasattr(c, "use_offset"):
            c.use_offset = True
        c.target_space = "LOCAL"
        c.owner_space = "LOCAL"

    frame = int((action.frame_range[0] + action.frame_range[1]) * 0.5)
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    local_offset = mesh_aabb(mesh)

    # switch to WORLD replace
    for pair in pairs:
        if pair["target"] not in target.pose.bones:
            continue
        pb = target.pose.bones[pair["target"]]
        for c in pb.constraints:
            c.target_space = "WORLD"
            c.owner_space = "WORLD"
            if hasattr(c, "use_offset"):
                c.use_offset = False
    bpy.context.view_layer.update()
    world_replace = mesh_aabb(mesh)

    # POSE space offset
    for pair in pairs:
        if pair["target"] not in target.pose.bones:
            continue
        pb = target.pose.bones[pair["target"]]
        for c in pb.constraints:
            c.target_space = "POSE"
            c.owner_space = "POSE"
            if hasattr(c, "use_offset"):
                c.use_offset = True
    bpy.context.view_layer.update()
    pose_offset = mesh_aabb(mesh)

    def ratio(a):
        return {
            "aabb": a,
            "volume_ratio": round(a["volume"] / max(rest["volume"], 1), 4),
            "max_ratio": round(a["max_axis"] / max(rest["max_axis"], 1e-6), 4),
        }

    report = {
        "mixamo_basis": mixamo_frames,
        "rest": rest,
        "copy_rotation_local_offset": ratio(local_offset),
        "copy_rotation_world_replace": ratio(world_replace),
        "copy_rotation_pose_offset": ratio(pose_offset),
    }
    write_json(os.path.join(GENERATED_DIR, "TERERE_CONSTRAINT_RETARGET_COMPARE.json"), report)
    print("REST", rest)
    print("LOCAL_OFFSET", report["copy_rotation_local_offset"])
    print("WORLD_REPLACE", report["copy_rotation_world_replace"])
    print("POSE_OFFSET", report["copy_rotation_pose_offset"])
    print("MIXAMO_MAX_BASIS", max(b["basis_deg"] for fr in mixamo_frames for b in fr["bones"]))


if __name__ == "__main__":
    main()
