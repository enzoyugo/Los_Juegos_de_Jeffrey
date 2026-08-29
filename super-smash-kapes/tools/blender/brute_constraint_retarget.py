"""Brute-force Copy Rotation spaces/inverts; pick lowest volume ratio.

blender --background --python brute_constraint_retarget.py -- --character terere
"""
import argparse
import itertools
import json
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


def aabb(mesh_obj):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = mesh_obj.evaluated_get(deps)
    xs = [v.co.x for v in ev.data.vertices]
    ys = [v.co.y for v in ev.data.vertices]
    zs = [v.co.z for v in ev.data.vertices]
    size = Vector((max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
    return abs(size.x * size.y * size.z), [round(size.x, 2), round(size.y, 2), round(size.z, 2)]


def skinned(arm):
    for obj in bpy.data.objects:
        if obj.type == "MESH" and any(m.type == "ARMATURE" and m.object == arm for m in obj.modifiers):
            return obj
    return None


def setup(cfg, pairs):
    reset_scene()
    import_fbx(cfg["fbx"])
    target = find_armature()
    import_fbx(IDLE_FBX)
    source = [a for a in bpy.data.objects if a.type == "ARMATURE" and a != target][0]
    action = find_source_action(source, "mixamo")
    source.animation_data_create()
    source.animation_data.action = action
    mesh = skinned(target)
    return source, target, action, mesh, pairs


def apply_constraints(source, target, pairs, space, offset, invert):
    for pair in pairs:
        if pair["source"] not in source.pose.bones or pair["target"] not in target.pose.bones:
            continue
        pb = target.pose.bones[pair["target"]]
        for c in list(pb.constraints):
            pb.constraints.remove(c)
        c = pb.constraints.new("COPY_ROTATION")
        c.target = source
        c.subtarget = pair["source"]
        c.target_space = space
        c.owner_space = space
        if hasattr(c, "use_offset"):
            c.use_offset = offset
        c.invert_x, c.invert_y, c.invert_z = invert
        c.use_x = True
        c.use_y = True
        c.use_z = True


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--character", default="terere")
    args = p.parse_args(argv)
    cfg = CHARACTERS[args.character]
    with open(BONE_MAP_JSON, "r", encoding="utf-8") as fh:
        pairs = mapped_pairs_from_bone_map(json.load(fh))
    source, target, action, mesh, pairs = setup(cfg, pairs)
    clear_pose(target)
    bpy.context.view_layer.update()
    rest_vol, rest_size = aabb(mesh)
    frame = int((action.frame_range[0] + action.frame_range[1]) * 0.5)
    bpy.context.scene.frame_set(frame)

    spaces = ["WORLD", "LOCAL", "POSE"]
    if "LOCAL_WITH_PARENT" in dir(bpy.types.CopyRotationConstraint.bl_rna.properties["target_space"].enum_items[0]):
        pass
    try:
        spaces.append("LOCAL_WITH_PARENT")
    except Exception:
        pass
    # validate spaces
    valid_spaces = []
    for sp in ["WORLD", "POSE", "LOCAL", "LOCAL_WITH_PARENT"]:
        valid_spaces.append(sp)

    results = []
    best = None
    for space, offset, invert in itertools.product(valid_spaces, [False, True], itertools.product([False, True], repeat=3)):
        try:
            apply_constraints(source, target, pairs, space, offset, invert)
        except TypeError:
            continue
        bpy.context.view_layer.update()
        vol, size = aabb(mesh)
        ratio = vol / max(rest_vol, 1.0)
        row = {
            "space": space,
            "offset": offset,
            "invert": list(invert),
            "volume_ratio": round(ratio, 4),
            "size": size,
        }
        results.append(row)
        if best is None or ratio < best["volume_ratio"]:
            best = row
            print("BEST so far", row)

    results.sort(key=lambda r: r["volume_ratio"])
    write_json(os.path.join(GENERATED_DIR, "%s_CONSTRAINT_BRUTE.json" % args.character.upper()), {
        "rest_volume": rest_vol,
        "rest_size": rest_size,
        "best": best,
        "top10": results[:10],
    })
    print("WINNER", best)


if __name__ == "__main__":
    main()
