"""Overnight Track 1: bind / skin / rest / bbox / bone-axis / Mixamo forensics.

Usage:
  blender --background --python overnight_deformation_forensics.py -- --character terere
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector, Euler

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import (  # noqa: E402
    apply_rest_relative_rotation,
    clear_pose,
    find_armature,
    find_source_action,
    import_fbx,
    import_gltf,
    mapped_pairs_from_bone_map,
    reset_scene,
    write_json,
)
from actorcore_paths import BONE_MAP_JSON, CHARACTERS, GENERATED_DIR, IDLE_FBX  # noqa: E402


DIAG_BONES = [
    ("hip", "CC_Base_Hip"),
    ("spine", "CC_Base_Spine01"),
    ("head", "CC_Base_Head"),
    ("l_upperarm", "CC_Base_L_Upperarm"),
    ("l_forearm", "CC_Base_L_Forearm"),
    ("r_upperarm", "CC_Base_R_Upperarm"),
    ("r_thigh", "CC_Base_R_Thigh"),
    ("r_calf", "CC_Base_R_Calf"),
]


def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []
    parser = argparse.ArgumentParser()
    parser.add_argument("--character", required=True, choices=["terere", "jaguarete"])
    return parser.parse_args(argv)


def vec3(v):
    return [round(float(v.x), 6), round(float(v.y), 6), round(float(v.z), 6)]


def mat16(m):
    return [round(float(v), 6) for row in m for v in row]


def object_xform(obj):
    loc, rot, scale = obj.matrix_world.decompose()
    return {
        "name": obj.name,
        "type": obj.type,
        "parent": obj.parent.name if obj.parent else None,
        "location": vec3(obj.location),
        "rotation_euler": [round(math.degrees(a), 4) for a in obj.rotation_euler],
        "scale": vec3(obj.scale),
        "world_location": vec3(loc),
        "world_scale": vec3(scale),
        "negative_scale": any(s < 0.0 for s in obj.scale),
        "non_unit_scale": any(abs(s - 1.0) > 0.001 for s in obj.scale),
        "unapplied_rotation": any(abs(a) > 1e-4 for a in obj.rotation_euler),
    }


def evaluated_mesh_aabb(mesh_obj):
    deps = bpy.context.evaluated_depsgraph_get()
    eval_obj = mesh_obj.evaluated_get(deps)
    data = eval_obj.data
    if data is None or not getattr(data, "vertices", None):
        return {"empty": True}
    xs = [v.co.x for v in data.vertices]
    ys = [v.co.y for v in data.vertices]
    zs = [v.co.z for v in data.vertices]
    if not xs:
        return {"empty": True}
    min_c = Vector((min(xs), min(ys), min(zs)))
    max_c = Vector((max(xs), max(ys), max(zs)))
    size = max_c - min_c
    return {
        "min": vec3(min_c),
        "max": vec3(max_c),
        "size": vec3(size),
        "height": round(float(max(size.x, size.y, size.z)), 6),
        "width": round(float(min(size.x, size.y) if False else max(size.x, size.y)), 6),
        "axis_size": vec3(size),
        "volume": round(float(abs(size.x * size.y * size.z)), 6),
    }


def bind_audit(arm):
    bones = []
    for bone in arm.data.bones:
        bones.append({
            "name": bone.name,
            "parent": bone.parent.name if bone.parent else None,
            "use_deform": bool(getattr(bone, "use_deform", True)),
            "head": vec3(bone.head_local),
            "tail": vec3(bone.tail_local),
            "roll": round(float(getattr(bone, "roll", 0.0)), 6),
            "matrix_local": mat16(bone.matrix_local),
            "length": round(float(bone.length), 6),
        })
    meshes = []
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        mods = []
        for mod in obj.modifiers:
            if mod.type == "ARMATURE":
                mods.append({
                    "name": mod.name,
                    "object": mod.object.name if mod.object else None,
                    "use_vertex_groups": bool(getattr(mod, "use_vertex_groups", True)),
                    "use_bone_envelopes": bool(getattr(mod, "use_bone_envelopes", False)),
                })
        meshes.append({
            "object": object_xform(obj),
            "vertex_groups": len(obj.vertex_groups),
            "vertex_group_names_count": len(obj.vertex_groups),
            "armature_modifiers": mods,
        })
    pose_deltas = []
    for pb in arm.pose.bones:
        q = pb.matrix_basis.to_quaternion()
        ang = abs(math.degrees(q.angle)) % 360.0
        if ang > 180.0:
            ang = 360.0 - ang
        if ang > 0.05 or pb.location.length > 1e-4 or any(abs(s - 1.0) > 1e-3 for s in pb.scale):
            pose_deltas.append({
                "bone": pb.name,
                "basis_angle_deg": round(ang, 4),
                "location": vec3(pb.location),
                "scale": vec3(pb.scale),
            })
    return {
        "armature": object_xform(arm),
        "pose_position": arm.data.pose_position,
        "bone_count": len(arm.data.bones),
        "bones": bones,
        "meshes": meshes,
        "pose_bones_not_identity": pose_deltas[:80],
        "pose_bones_not_identity_count": len(pose_deltas),
    }


def skin_weight_audit(arm):
    reports = []
    deform_names = {b.name for b in arm.data.bones if getattr(b, "use_deform", True)}
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        if not any(mod.type == "ARMATURE" and mod.object == arm for mod in obj.modifiers):
            continue
        vg_index = {vg.index: vg.name for vg in obj.vertex_groups}
        verts = obj.data.vertices
        n = len(verts)
        unweighted = 0
        infls = []
        over4 = 0
        max_dev = 0.0
        weight_sum_errors = 0
        suspicious = []
        for v in verts:
            groups = [(vg_index.get(g.group, ""), g.weight) for g in v.groups if g.weight > 1e-6]
            groups = [(name, w) for name, w in groups if name]
            if not groups:
                unweighted += 1
                continue
            infls.append(len(groups))
            if len(groups) > 4:
                over4 += 1
            total = sum(w for _, w in groups)
            dev = abs(total - 1.0)
            max_dev = max(max_dev, dev)
            if dev > 0.05:
                weight_sum_errors += 1
            names = [name for name, _ in groups]
            if any("Foot" in n_ or "Toe" in n_ for n_ in names) and any("Hand" in n_ or "Finger" in n_ for n_ in names):
                suspicious.append({"vertex": v.index, "groups": names[:6], "reason": "foot_and_hand"})
            if any("Head" in n_ for n_ in names) and any("Thigh" in n_ or "Calf" in n_ for n_ in names):
                suspicious.append({"vertex": v.index, "groups": names[:6], "reason": "head_and_leg"})
            if len(suspicious) > 40:
                continue
        reports.append({
            "mesh": obj.name,
            "vertices": n,
            "weighted_vertices": n - unweighted,
            "unweighted_vertices": unweighted,
            "unweighted_ratio": round(unweighted / max(n, 1), 6),
            "max_influences": max(infls) if infls else 0,
            "average_influences": round(sum(infls) / max(len(infls), 1), 4),
            "vertices_over_4_influences": over4,
            "over_4_ratio": round(over4 / max(n, 1), 6),
            "max_total_weight_deviation_from_1": round(max_dev, 6),
            "vertices_weight_sum_error": weight_sum_errors,
            "deform_bones_in_armature": len(deform_names),
            "suspicious_influence_samples": suspicious[:25],
            "suspicious_count": len(suspicious),
        })
    return reports


def bbox_at_frame(arm, mesh_obj, frame):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    return evaluated_mesh_aabb(mesh_obj)


def find_skinned_mesh(arm):
    for obj in bpy.data.objects:
        if obj.type == "MESH" and any(mod.type == "ARMATURE" and mod.object == arm for mod in obj.modifiers):
            return obj
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    return meshes[0] if meshes else None


def classify_bbox(rest, animated, label):
    if not rest or not animated or rest.get("empty") or animated.get("empty"):
        return {"stage": label, "status": "UNKNOWN"}
    h_ratio = animated["height"] / max(rest["height"], 1e-6)
    w_ratio = animated["width"] / max(rest["width"], 1e-6)
    rest_vol = float(rest.get("volume") or 0.0)
    anim_vol = float(animated.get("volume") or 0.0)
    vol_ratio = anim_vol / max(rest_vol, 1e-6)
    rest_axes = rest.get("axis_size") or rest.get("size") or [rest["height"]]
    anim_axes = animated.get("axis_size") or animated.get("size") or [animated["height"]]
    max_axis_ratio = max(anim_axes) / max(max(rest_axes), 1e-6)
    # Prior 2.4× height/width gate missed 10× volume explosions (T-pose width used as height).
    broken = (
        vol_ratio > 1.8
        or max_axis_ratio > 1.5
        or h_ratio > 1.5
        or w_ratio > 1.5
        or h_ratio < 0.35
        or w_ratio < 0.35
    )
    reason = ""
    if broken:
        if vol_ratio > 1.8:
            reason = "volume_ratio_%.2f" % vol_ratio
        elif max_axis_ratio > 1.5:
            reason = "max_axis_ratio_%.2f" % max_axis_ratio
        else:
            reason = "bbox_expanded_or_collapsed"
    return {
        "stage": label,
        "status": "BROKEN" if broken else "HEALTHY",
        "rest_height": rest["height"],
        "idle_height": animated["height"],
        "rest_width": rest["width"],
        "idle_width": animated["width"],
        "height_ratio": round(h_ratio, 4),
        "width_ratio": round(w_ratio, 4),
        "volume_ratio": round(vol_ratio, 4),
        "max_axis_ratio": round(max_axis_ratio, 4),
        "broken_reason": reason,
    }


def bone_axis_test(arm):
    results = []
    for label, name in DIAG_BONES:
        if name not in arm.pose.bones:
            results.append({"bone": name, "missing": True})
            continue
        pb = arm.pose.bones[name]
        db = arm.data.bones[name]
        rest_tail = (arm.matrix_world @ db.tail_local.to_4d()).to_3d()
        axes = {}
        for axis in ("x", "y", "z"):
            clear_pose(arm)
            bpy.context.view_layer.update()
            euler = Euler((0, 0, 0), "XYZ")
            setattr(euler, axis, math.radians(10.0))
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = euler
            bpy.context.view_layer.update()
            posed_tail = (arm.matrix_world @ pb.tail).to_3d() if hasattr(pb, "tail") else (arm.matrix_world @ pb.matrix @ Vector((0, db.length, 0, 1))).to_3d()
            delta = posed_tail - rest_tail
            axes[axis] = {
                "tail_delta": vec3(delta),
                "delta_length": round(float(delta.length), 6),
            }
        clear_pose(arm)
        results.append({
            "label": label,
            "bone": name,
            "rest_tail": vec3(rest_tail),
            "plus_10deg_local": axes,
        })
    return results


def retarget_math_sample(source_arm, target_arm, pairs):
    samples = []
    bpy.context.scene.frame_set(int(bpy.context.scene.frame_current))
    bpy.context.view_layer.update()
    for pair in pairs[:12]:
        src = pair["source"]
        dst = pair["target"]
        if src not in source_arm.pose.bones or dst not in target_arm.pose.bones:
            continue
        s_pb = source_arm.pose.bones[src]
        s_db = source_arm.data.bones[src]
        t_db = target_arm.data.bones[dst]
        t_pb = target_arm.pose.bones[dst]
        s_rest = (source_arm.matrix_world @ s_db.matrix_local).to_3x3()
        t_rest = (target_arm.matrix_world @ t_db.matrix_local).to_3x3()
        src_basis = s_pb.matrix_basis.to_3x3()
        world_rot = s_rest @ src_basis @ s_rest.inverted()
        expected = t_rest.inverted() @ world_rot @ t_rest
        apply_rest_relative_rotation(source_arm, target_arm, src, dst)
        actual = t_pb.matrix_basis.to_3x3()
        delta = expected.inverted() @ actual
        ang = abs(math.degrees(delta.to_quaternion().angle)) % 360.0
        if ang > 180:
            ang = 360 - ang
        samples.append({
            "source": src,
            "target": dst,
            "source_basis_angle_deg": round(abs(math.degrees(src_basis.to_quaternion().angle)), 4),
            "expected_vs_applied_angle_deg": round(ang, 4),
        })
    return samples


def mixamo_inspect():
    reset_scene()
    import_fbx(IDLE_FBX)
    arm = find_armature()
    action = find_source_action(arm, "mixamo") if arm else None
    bones = []
    if arm:
        for name in ("mixamorig:Hips", "mixamorig5:Hips", "Hips"):
            if name in arm.data.bones:
                b = arm.data.bones[name]
                bones.append({"name": name, "matrix_local": mat16(b.matrix_local), "head": vec3(b.head_local)})
                break
        prefix = ""
        for b in arm.data.bones:
            if "Hips" in b.name:
                prefix = b.name.split("Hips")[0]
                break
    return {
        "armature": object_xform(arm) if arm else None,
        "bone_count": len(arm.data.bones) if arm else 0,
        "action": action.name if action else None,
        "fps": bpy.context.scene.render.fps,
        "frame_range": [int(action.frame_range[0]), int(action.frame_range[1])] if action else [],
        "namespace_sample": bones,
        "hip_prefix_guess": prefix if arm else "",
        "unit_scale_armature": vec3(arm.scale) if arm else [],
    }


def stage_source_rest(cfg):
    reset_scene()
    import_fbx(cfg["fbx"])
    arm = find_armature()
    mesh = find_skinned_mesh(arm)
    clear_pose(arm)
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    rest_bbox = evaluated_mesh_aabb(mesh) if mesh else {}
    arm.data.pose_position = "POSE"
    bpy.context.view_layer.update()
    pose0 = evaluated_mesh_aabb(mesh) if mesh else {}
    return {
        "bind": bind_audit(arm),
        "skin": skin_weight_audit(arm),
        "rest_bbox": rest_bbox,
        "pose_position_pose_bbox_frame_default": pose0,
        "rest_vs_default_pose": classify_bbox(rest_bbox, pose0, "A_source_fbx_rest_vs_default_pose"),
        "axis_audit": bone_axis_test(arm),
        "armature": arm.name,
        "mesh": mesh.name if mesh else None,
    }


def stage_glb(path, label):
    reset_scene()
    if not os.path.isfile(path):
        return {"missing": True, "path": path}
    import_gltf(path)
    arm = find_armature()
    mesh = find_skinned_mesh(arm)
    objects = [object_xform(o) for o in bpy.data.objects]
    actions = [a.name for a in bpy.data.actions]
    rest = {}
    idle = {}
    if arm and mesh:
        if arm.animation_data:
            arm.animation_data.action = None
        clear_pose(arm)
        bpy.context.view_layer.update()
        rest = evaluated_mesh_aabb(mesh)
        action = None
        for act in bpy.data.actions:
            if "idle" in act.name.lower():
                action = act
                break
        if action is None and bpy.data.actions:
            action = bpy.data.actions[0]
        if action:
            if arm.animation_data is None:
                arm.animation_data_create()
            arm.animation_data.action = action
            mid = int((action.frame_range[0] + action.frame_range[1]) * 0.5)
            idle = bbox_at_frame(arm, mesh, mid)
        cls = classify_bbox(rest, idle if idle else rest, label)
    else:
        cls = {"stage": label, "status": "UNKNOWN", "reason": "missing arm/mesh"}
    return {
        "path": path,
        "armature": arm.name if arm else None,
        "mesh": mesh.name if mesh else None,
        "objects": objects,
        "actions": actions,
        "rest_bbox": rest,
        "idle_mid_bbox": idle,
        "classification": cls,
        "bind_pose_not_identity": bind_audit(arm)["pose_bones_not_identity_count"] if arm else None,
    }


def main():
    args = parse_args()
    cfg = CHARACTERS[args.character]
    char = args.character
    prod = os.path.join(os.path.dirname(cfg["benchmark_dir"]).replace("actorcore_benchmark", char), "%s_game_ready_v3.glb" % char)
    # processed/<char>/<char>_game_ready_v3.glb
    prod = os.path.join(os.path.dirname(os.path.dirname(cfg["benchmark_dir"])), char, "%s_game_ready_v3.glb" % char)

    source = stage_source_rest(cfg)
    write_json(os.path.join(GENERATED_DIR, "%s_ACTORCORE_BIND_AUDIT.json" % char.upper()), source["bind"])
    write_json(os.path.join(GENERATED_DIR, "%s_SKIN_WEIGHT_AUDIT.json" % char.upper()), source["skin"])
    write_json(os.path.join(GENERATED_DIR, "%s_ACTORCORE_BONE_AXIS_AUDIT.json" % char.upper()), source["axis_audit"])

    mixamo = mixamo_inspect()

    # Bake math sample in a combined scene
    reset_scene()
    import_fbx(cfg["fbx"])
    target = find_armature()
    import_fbx(IDLE_FBX)
    source_arm = [a for a in bpy.data.objects if a.type == "ARMATURE" and a != target][0]
    with open(BONE_MAP_JSON, "r", encoding="utf-8") as fh:
        bone_map = json.load(fh)
    pairs = mapped_pairs_from_bone_map(bone_map)
    source_action = find_source_action(source_arm, "mixamo")
    source_arm.animation_data_create()
    source_arm.animation_data.action = source_action
    bpy.context.scene.frame_set(int(source_action.frame_range[0]) + 20)
    math_samples = retarget_math_sample(source_arm, target, pairs)
    mesh = find_skinned_mesh(target)
    clear_pose(target)
    rest_b = evaluated_mesh_aabb(mesh) if mesh else {}
    for pair in pairs:
        if pair["source"] in source_arm.pose.bones and pair["target"] in target.pose.bones:
            apply_rest_relative_rotation(source_arm, target, pair["source"], pair["target"])
    bpy.context.view_layer.update()
    posed_b = evaluated_mesh_aabb(mesh) if mesh else {}
    bake_cls = classify_bbox(rest_b, posed_b, "C_target_rig_after_single_frame_retarget")

    bench = stage_glb(cfg["output_glb"], "F_benchmark_glb_reimport")
    production = stage_glb(prod, "E_production_v3_glb_reimport")

    stages = {
        "A_source_ActorCore_FBX_rest": source["rest_vs_default_pose"],
        "C_after_retarget_one_frame": bake_cls,
        "F_benchmark_glb": bench.get("classification"),
        "E_production_v3_glb": production.get("classification"),
    }
    first_broken = "NONE"
    for key in ("A_source_ActorCore_FBX_rest", "C_after_retarget_one_frame", "F_benchmark_glb", "E_production_v3_glb"):
        item = stages.get(key) or {}
        if item.get("status") == "BROKEN":
            first_broken = key
            break

    report = {
        "character": char,
        "source_mesh": source.get("mesh"),
        "source_armature": source.get("armature"),
        "mixamo": mixamo,
        "retarget_math_samples": math_samples,
        "stages": stages,
        "source_rest_bbox": source["rest_bbox"],
        "benchmark_glb": bench,
        "production_glb": production,
        "FIRST_BROKEN_STAGE": first_broken,
    }
    write_json(os.path.join(GENERATED_DIR, "%s_DEFORMATION_STAGE_CHAIN.json" % char.upper()), report)
    print("FORENSICS %s first_broken=%s" % (char, first_broken))
    for key, item in stages.items():
        print("  %s %s" % (key, item))


if __name__ == "__main__":
    main()
