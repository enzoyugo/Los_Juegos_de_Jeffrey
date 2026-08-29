"""Native AccuRIG skin deformation audit. No Mixamo. No production V4 writes.

Usage:
  blender --background --python native_skin_deformation_audit.py -- --character terere
  blender --background --python native_skin_deformation_audit.py -- --character jaguarete
"""
from __future__ import print_function

import argparse
import csv
import json
import math
import os
import sys
import traceback

import bpy
from mathutils import Quaternion, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import (  # noqa: E402
    clear_pose,
    find_armature,
    import_fbx,
    import_gltf,
    rebind_actorcore_textures,
    reset_scene,
    setup_preview_camera,
    write_json,
)
from actorcore_paths import CHARACTERS, GENERATED_DIR, PROJECT_ROOT  # noqa: E402
from export_actorcore_game_ready import limit_influences, mesh_volume, skinned_meshes  # noqa: E402


SWEEPS = {
    "CC_Base_L_Upperarm": [0, 10, 20, 30, 45, 60, 75],
    "CC_Base_R_Upperarm": [0, 10, 20, 30, 45, 60, 75],
    "CC_Base_L_Forearm": [0, 30, 60, 90],
    "CC_Base_R_Forearm": [0, 30, 60, 90],
    "CC_Base_L_Thigh": [0, 15, 30, 45, 60],
    "CC_Base_R_Thigh": [0, 15, 30, 45, 60],
    "CC_Base_L_Calf": [0, 30, 60, 90],
    "CC_Base_R_Calf": [0, 30, 60, 90],
    "CC_Base_Spine01": [0, 15, 30],
    "CC_Base_Spine02": [0, 15, 30],
    "CC_Base_Head": [0, 15, 30],
}

AXIS_KIND = {
    "CC_Base_L_Upperarm": "lower_arm",
    "CC_Base_R_Upperarm": "lower_arm",
    "CC_Base_L_Forearm": "bend_elbow",
    "CC_Base_R_Forearm": "bend_elbow",
    "CC_Base_L_Thigh": "flex_hip",
    "CC_Base_R_Thigh": "flex_hip",
    "CC_Base_L_Calf": "bend_knee",
    "CC_Base_R_Calf": "bend_knee",
    "CC_Base_Spine01": "flex_spine",
    "CC_Base_Spine02": "flex_spine",
    "CC_Base_Head": "nod_head",
}

CSV_FIELDS = [
    "character", "variant", "bone", "axis", "sign", "angle_deg",
    "volume", "sx", "sy", "sz", "volume_ratio", "max_axis_ratio",
    "max_vertex_disp", "p50_disp", "p95_disp", "p99_disp",
    "nan_count", "inf_count", "extreme_vertex_count", "verdict",
]

CATASTROPHIC_VOL = 5.0
BROKEN_VOL = 2.5
STRESSED_VOL = 1.5
ARM_CATASTROPHIC = 5.0


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--character", choices=["terere", "jaguarete"], required=True)
    return p.parse_args(argv)


def audit_dir(character):
    root = os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "native_skin_audit", character)
    os.makedirs(root, exist_ok=True)
    return root


def disconnect_action(arm):
    if arm.animation_data:
        arm.animation_data.action = None
        for track in getattr(arm.animation_data, "nla_tracks", []):
            track.mute = True


def world_head(arm, name):
    return arm.matrix_world @ arm.pose.bones[name].head


def world_tail(arm, name):
    return arm.matrix_world @ arm.pose.bones[name].tail


def character_basis(arm):
    hip = world_head(arm, "CC_Base_Hip")
    head = world_head(arm, "CC_Base_Head")
    up = (head - hip).normalized()
    left = world_head(arm, "CC_Base_L_Upperarm")
    right = world_head(arm, "CC_Base_R_Upperarm")
    right_dir = (right - left).normalized()
    forward = up.cross(right_dir).normalized()
    if forward.length < 0.1:
        forward = Vector((0.0, -1.0, 0.0))
    return up, forward, right_dir


def rotate_bone(arm, name, axis, angle_deg):
    pb = arm.pose.bones[name]
    pb.rotation_mode = "QUATERNION"
    axis_v = Vector(axis).normalized()
    pb.rotation_quaternion = Quaternion(axis_v, math.radians(angle_deg))
    pb.location = Vector((0.0, 0.0, 0.0))
    pb.scale = Vector((1.0, 1.0, 1.0))


def pick_axis(arm, bone_name, kind):
    up, forward, _right = character_basis(arm)
    rest_tail = world_tail(arm, bone_name).copy()
    child = None
    if "Upperarm" in bone_name:
        child = bone_name.replace("Upperarm", "Forearm")
    elif "Forearm" in bone_name:
        child = bone_name.replace("Forearm", "Hand")
    elif "Thigh" in bone_name:
        child = bone_name.replace("Thigh", "Calf")
    elif "Calf" in bone_name:
        child = bone_name.replace("Calf", "Foot")
    rest_child = world_tail(arm, child).copy() if child and child in arm.pose.bones else rest_tail
    best = (-1e18, (1.0, 0.0, 0.0), 1.0)
    for axis in ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)):
        for sign in (1.0, -1.0):
            clear_pose(arm)
            rotate_bone(arm, bone_name, axis, sign * 25.0)
            bpy.context.view_layer.update()
            posed_tail = world_tail(arm, bone_name)
            posed_child = world_tail(arm, child) if child and child in arm.pose.bones else posed_tail
            if kind == "lower_arm":
                score = (rest_tail - posed_tail).dot(up)
            elif kind == "bend_elbow":
                shoulder = bone_name.replace("Forearm", "Upperarm")
                if shoulder in arm.pose.bones:
                    rest_d = (rest_child - world_head(arm, shoulder)).length
                    posed_d = (posed_child - world_head(arm, shoulder)).length
                    score = rest_d - posed_d
                else:
                    score = (rest_child - posed_child).length
            elif kind == "flex_hip":
                score = (posed_tail - rest_tail).dot(forward)
            elif kind == "bend_knee":
                thigh = bone_name.replace("Calf", "Thigh")
                if thigh in arm.pose.bones:
                    rest_d = (rest_child - world_head(arm, thigh)).length
                    posed_d = (posed_child - world_head(arm, thigh)).length
                    score = rest_d - posed_d
                else:
                    score = (rest_child - posed_child).length
            elif kind == "flex_spine":
                score = abs((posed_tail - rest_tail).dot(forward))
            else:
                score = abs((posed_tail - rest_tail).dot(forward))
            if score > best[0]:
                best = (score, axis, sign)
    clear_pose(arm)
    bpy.context.view_layer.update()
    return {"axis": list(best[1]), "sign": best[2], "probe_score": round(best[0], 6), "kind": kind}


def evaluated_points(mesh_obj):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = mesh_obj.evaluated_get(deps)
    mw = ev.matrix_world
    pts = []
    nan_count = 0
    inf_count = 0
    for v in ev.data.vertices:
        w = mw @ v.co
        if math.isnan(w.x) or math.isnan(w.y) or math.isnan(w.z):
            nan_count += 1
            pts.append(Vector((0.0, 0.0, 0.0)))
            continue
        if math.isinf(w.x) or math.isinf(w.y) or math.isinf(w.z):
            inf_count += 1
            pts.append(Vector((0.0, 0.0, 0.0)))
            continue
        pts.append(w)
    return pts, nan_count, inf_count


def percentile(sorted_vals, p):
    if not sorted_vals:
        return 0.0
    if len(sorted_vals) == 1:
        return sorted_vals[0]
    idx = int(round((p / 100.0) * (len(sorted_vals) - 1)))
    idx = max(0, min(len(sorted_vals) - 1, idx))
    return sorted_vals[idx]


def classify_pose(volume_ratio, max_axis_ratio, nan_count, inf_count, extreme_count, bone):
    if nan_count or inf_count:
        return "CATASTROPHIC"
    if volume_ratio >= CATASTROPHIC_VOL:
        return "CATASTROPHIC"
    if "Upperarm" in bone or "Forearm" in bone:
        if volume_ratio >= ARM_CATASTROPHIC:
            return "CATASTROPHIC"
    if volume_ratio >= BROKEN_VOL or max_axis_ratio >= 2.0 or extreme_count > 200:
        return "BROKEN"
    if volume_ratio >= STRESSED_VOL or max_axis_ratio >= 1.45:
        return "STRESSED"
    return "HEALTHY"


def measure_mesh(mesh_obj, rest_pts, rest_vol, rest_size, rest_diag):
    vol, size = mesh_volume(mesh_obj)
    pts, nan_count, inf_count = evaluated_points(mesh_obj)
    disps = []
    extreme = []
    n = min(len(pts), len(rest_pts))
    for i in range(n):
        d = (pts[i] - rest_pts[i]).length
        disps.append(d)
        if d > 0.35 * rest_diag:
            extreme.append(i)
    disps_sorted = sorted(disps)
    volume_ratio = vol / max(rest_vol, 1e-8)
    max_axis_ratio = max(size) / max(max(rest_size), 1e-8)
    return {
        "volume": vol,
        "size": size,
        "volume_ratio": volume_ratio,
        "max_axis_ratio": max_axis_ratio,
        "max_vertex_disp": disps_sorted[-1] if disps_sorted else 0.0,
        "p50_disp": percentile(disps_sorted, 50),
        "p95_disp": percentile(disps_sorted, 95),
        "p99_disp": percentile(disps_sorted, 99),
        "nan_count": nan_count,
        "inf_count": inf_count,
        "extreme_vertex_count": len(extreme),
        "extreme_indices": extreme[:40],
        "disps": disps,
        "pts": pts,
    }


def modifier_audit(arm, mesh):
    mod = None
    for m in mesh.modifiers:
        if m.type == "ARMATURE":
            mod = m
            break
    return {
        "armature_name": arm.name,
        "mesh_name": mesh.name,
        "armature_modifier_target": mod.object.name if mod and mod.object else None,
        "use_deform_preserve_volume": bool(getattr(mod, "use_deform_preserve_volume", False)) if mod else None,
        "armature_location": list(arm.location),
        "armature_rotation_euler_deg": [round(math.degrees(a), 4) for a in arm.rotation_euler],
        "armature_scale": list(arm.scale),
        "mesh_location": list(mesh.location),
        "mesh_rotation_euler_deg": [round(math.degrees(a), 4) for a in mesh.rotation_euler],
        "mesh_scale": list(mesh.scale),
        "mesh_parent": mesh.parent.name if mesh.parent else None,
        "bind_note": "Blender 2.83 vertex groups + armature modifier; inverse bind not exposed as a numeric ID property on Mesh.",
    }


def duplicate_skinned_mesh(mesh, arm, name):
    copy = mesh.copy()
    copy.data = mesh.data.copy()
    copy.name = name
    bpy.context.collection.objects.link(copy)
    copy.parent = mesh.parent
    copy.matrix_parent_inverse = mesh.matrix_parent_inverse.copy()
    for mod in copy.modifiers:
        if mod.type == "ARMATURE":
            mod.object = arm
    return copy


def collapse_twist_weights(mesh_obj):
    groups = {vg.name: vg for vg in mesh_obj.vertex_groups}
    mapping = []
    for name, vg in list(groups.items()):
        if "Twist" not in name:
            continue
        parent = name.split("Twist")[0]
        if parent not in groups:
            continue
        mapping.append((name, parent))
    vg_by_index = {vg.index: vg for vg in mesh_obj.vertex_groups}
    name_by_index = {vg.index: vg.name for vg in mesh_obj.vertex_groups}
    parent_index = {p: groups[p].index for _, p in mapping}
    twist_index = {t: groups[t].index for t, _ in mapping}
    moved = 0
    for v in mesh_obj.data.vertices:
        extra = {}
        for g in v.groups:
            gname = name_by_index.get(g.group)
            if gname in twist_index:
                parent = gname.split("Twist")[0]
                extra[parent] = extra.get(parent, 0.0) + g.weight
                vg_by_index[g.group].remove([v.index])
                moved += 1
        for parent, w in extra.items():
            groups[parent].add([v.index], w, "ADD")
    # renormalize
    for v in mesh_obj.data.vertices:
        gs = [(g.group, g.weight) for g in v.groups if g.weight > 1e-8]
        total = sum(w for _, w in gs) or 1.0
        for gi, w in gs:
            vg_by_index[gi].add([v.index], w / total, "REPLACE")
    return {"pairs": mapping, "twist_assignments_moved": moved}


def influence_stats(mesh_obj):
    over4 = 0
    max_inf = 0
    helper = 0
    for v in mesh_obj.data.vertices:
        groups = [g for g in v.groups if g.weight > 1e-8]
        max_inf = max(max_inf, len(groups))
        if len(groups) > 4:
            over4 += 1
        names = [mesh_obj.vertex_groups[g.group].name for g in groups]
        if any(("Twist" in n or "Share" in n or "Facial" in n or "Breast" in n) for n in names):
            helper += 1
    return {
        "vertex_count": len(mesh_obj.data.vertices),
        "vertices_over_4_influences": over4,
        "max_influences": max_inf,
        "vertices_with_helper_or_twist": helper,
    }


def vertex_groups_of(mesh_obj, index):
    v = mesh_obj.data.vertices[index]
    out = []
    for g in v.groups:
        if g.weight <= 1e-8:
            continue
        name = mesh_obj.vertex_groups[g.group].name
        out.append({"bone": name, "weight": round(float(g.weight), 5)})
    out.sort(key=lambda item: -item["weight"])
    return out


def forensic_vertices(mesh_obj, rest_pts, posed_pts, indices, rest_diag):
    rows = []
    for i in indices[:25]:
        if i >= len(rest_pts) or i >= len(posed_pts):
            continue
        rest = rest_pts[i]
        posed = posed_pts[i]
        disp = (posed - rest).length
        groups = vertex_groups_of(mesh_obj, i)
        rows.append({
            "vertex_index": i,
            "rest": [round(rest.x, 5), round(rest.y, 5), round(rest.z, 5)],
            "posed": [round(posed.x, 5), round(posed.y, 5), round(posed.z, 5)],
            "displacement": round(disp, 5),
            "vertex_groups": groups,
            "has_twist": any("Twist" in g["bone"] for g in groups),
            "has_share": any("Share" in g["bone"] for g in groups),
            "has_helper": any(
                any(tag in g["bone"] for tag in ("Twist", "Share", "Facial", "Breast", "Root"))
                for g in groups
            ),
            "cross_limb": _cross_limb(groups),
        })
    return rows


def _cross_limb(groups):
    sides = set()
    for g in groups:
        if "_L_" in g["bone"]:
            sides.add("L")
        if "_R_" in g["bone"]:
            sides.add("R")
    return sides == {"L", "R"}


def apply_pose(arm, axes, specs):
    clear_pose(arm)
    for bone, angle in specs:
        if bone not in arm.pose.bones or bone not in axes:
            continue
        info = axes[bone]
        rotate_bone(arm, bone, info["axis"], info["sign"] * angle)
    bpy.context.view_layer.update()


def row_from_measure(character, variant, bone, axis_info, angle, meas):
    verdict = classify_pose(
        meas["volume_ratio"], meas["max_axis_ratio"], meas["nan_count"],
        meas["inf_count"], meas["extreme_vertex_count"], bone)
    return {
        "character": character,
        "variant": variant,
        "bone": bone,
        "axis": "%s,%s,%s" % tuple(axis_info["axis"]),
        "sign": axis_info["sign"],
        "angle_deg": angle,
        "volume": round(meas["volume"], 6),
        "sx": round(meas["size"][0], 4),
        "sy": round(meas["size"][1], 4),
        "sz": round(meas["size"][2], 4),
        "volume_ratio": round(meas["volume_ratio"], 4),
        "max_axis_ratio": round(meas["max_axis_ratio"], 4),
        "max_vertex_disp": round(meas["max_vertex_disp"], 5),
        "p50_disp": round(meas["p50_disp"], 5),
        "p95_disp": round(meas["p95_disp"], 5),
        "p99_disp": round(meas["p99_disp"], 5),
        "nan_count": meas["nan_count"],
        "inf_count": meas["inf_count"],
        "extreme_vertex_count": meas["extreme_vertex_count"],
        "verdict": verdict,
    }


def write_csv(path, rows):
    with open(path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=CSV_FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row.get(k, "") for k in CSV_FIELDS})


def add_label(collection, text, location):
    obj = bpy.data.objects.new("LABEL_%s" % text, None)
    collection.objects.link(obj)
    obj.location = location
    if hasattr(obj, "empty_draw_size"):
        obj.empty_draw_size = 0.2
    return obj


def build_preview_grid(arm, mesh, axes, character, out_blend):
    poses = [
        ("REST", []),
        ("upperarm_30", [("CC_Base_L_Upperarm", 30), ("CC_Base_R_Upperarm", 30)]),
        ("upperarm_60", [("CC_Base_L_Upperarm", 60), ("CC_Base_R_Upperarm", 60)]),
        ("elbow_90", [("CC_Base_L_Forearm", 90), ("CC_Base_R_Forearm", 90)]),
        ("thigh_45", [("CC_Base_L_Thigh", 45), ("CC_Base_R_Thigh", 45)]),
        ("knee_90", [("CC_Base_L_Calf", 90), ("CC_Base_R_Calf", 90)]),
        ("standing", [
            ("CC_Base_L_Upperarm", 62), ("CC_Base_R_Upperarm", 62),
            ("CC_Base_L_Forearm", 28), ("CC_Base_R_Forearm", 28),
            ("CC_Base_L_Calf", 18), ("CC_Base_R_Calf", 18),
        ]),
    ]
    spacing = 1.6
    for i, (label, specs) in enumerate(poses):
        arm2 = arm.copy()
        arm2.data = arm.data.copy()
        arm2.name = "preview_%s" % label
        mesh2 = mesh.copy()
        mesh2.data = mesh.data.copy()
        mesh2.name = "preview_mesh_%s" % label
        bpy.context.collection.objects.link(arm2)
        bpy.context.collection.objects.link(mesh2)
        mesh2.parent = arm2
        for mod in mesh2.modifiers:
            if mod.type == "ARMATURE":
                mod.object = arm2
        arm2.location.x = (i - 3) * spacing
        apply_pose(arm2, axes, specs)
        add_label(bpy.context.collection, label, (arm2.location.x, -0.9, 0.05))
    # hide originals used for measurement variants
    mesh.hide_viewport = True
    setup_preview_camera(arm)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)


def export_standing_glb(arm, mesh, axes, path):
    clear_pose(arm)
    specs = [
        ("CC_Base_L_Upperarm", 62), ("CC_Base_R_Upperarm", 62),
        ("CC_Base_L_Forearm", 28), ("CC_Base_R_Forearm", 28),
        ("CC_Base_L_Calf", 18), ("CC_Base_R_Calf", 18),
    ]
    if arm.animation_data is None:
        arm.animation_data_create()
    action = bpy.data.actions.new("standing_native")
    arm.animation_data.action = action
    apply_pose(arm, axes, [])
    bpy.context.scene.frame_set(1)
    for bone, _ang in specs:
        if bone in arm.pose.bones:
            arm.pose.bones[bone].keyframe_insert(data_path="rotation_quaternion", frame=1)
    apply_pose(arm, axes, specs)
    bpy.context.scene.frame_set(10)
    for bone, _ang in specs:
        if bone in arm.pose.bones:
            arm.pose.bones[bone].keyframe_insert(data_path="rotation_quaternion", frame=10)
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 10
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_animations=True,
        export_skins=True,
        export_materials=True,
        export_apply=False,
    )


def glb_roundtrip(glb_path, rest_vol_src):
    if not os.path.isfile(glb_path):
        return {"error": "missing glb"}
    imported = list(bpy.data.objects)
    import_gltf(glb_path)
    new_arms = [o for o in bpy.data.objects if o.type == "ARMATURE" and o not in imported]
    if not new_arms:
        return {"error": "no armature in glb"}
    arm = new_arms[0]
    meshes = skinned_meshes(arm)
    if not meshes:
        return {"error": "no mesh in glb"}
    mesh = meshes[0]
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    rest_vol, rest_size = mesh_volume(mesh)
    bpy.context.scene.frame_set(10)
    bpy.context.view_layer.update()
    pose_vol, pose_size = mesh_volume(mesh)
    result = {
        "glb": glb_path,
        "rest_size": [round(x, 4) for x in rest_size],
        "pose_size": [round(x, 4) for x in pose_size],
        "volume_ratio_vs_glb_rest": round(pose_vol / max(rest_vol, 1e-8), 4),
        "volume_ratio_vs_source_rest": round(pose_vol / max(rest_vol_src, 1e-8), 4),
        "bone_count": len(arm.data.bones),
    }
    for obj in list(bpy.data.objects):
        if obj not in imported:
            bpy.data.objects.remove(obj, do_unlink=True)
    return result


def worst_status(rows, variant):
    order = {"HEALTHY": 0, "STRESSED": 1, "BROKEN": 2, "CATASTROPHIC": 3}
    worst = "HEALTHY"
    max_vol = 0.0
    for row in rows:
        if row["variant"] != variant:
            continue
        max_vol = max(max_vol, float(row["volume_ratio"]))
        if order.get(row["verdict"], 0) > order.get(worst, 0):
            worst = row["verdict"]
    return worst, max_vol


def audit_character(character):
    cfg = CHARACTERS[character]
    out_dir = audit_dir(character)
    csv_path = os.path.join(GENERATED_DIR, "%s_NATIVE_SKIN_DEFORMATION.csv" % character.upper())
    json_path = os.path.join(GENERATED_DIR, "%s_NATIVE_SKIN_AUDIT.json" % character.upper())
    blend_path = os.path.join(out_dir, "%s_native_skin_audit.blend" % character)
    glb_path = os.path.join(out_dir, "%s_native_standing_test.glb" % character)

    reset_scene()
    bpy.context.scene.render.fps = 30
    import_fbx(cfg["fbx"])
    rebind_actorcore_textures(character)
    arm = find_armature()
    disconnect_action(arm)
    clear_pose(arm)
    bpy.context.view_layer.update()
    meshes = skinned_meshes(arm)
    if not meshes:
        raise RuntimeError("No skinned mesh for %s" % character)
    original = meshes[0]
    original.name = "skin_original"

    rest_vol, rest_size = mesh_volume(original)
    rest_pts, rest_nan, rest_inf = evaluated_points(original)
    rest_diag = math.sqrt(sum(s * s for s in rest_size))
    if rest_nan or rest_inf:
        print("WARN rest nan/inf", rest_nan, rest_inf)

    axes = {}
    for bone, kind in AXIS_KIND.items():
        if bone in arm.pose.bones:
            axes[bone] = pick_axis(arm, bone, kind)
            print("AXIS %s %s" % (bone, axes[bone]))

    audit = modifier_audit(arm, original)
    stats_original = influence_stats(original)

    copy_4 = duplicate_skinned_mesh(original, arm, "skin_4inf")
    limit_influences(copy_4, 4)
    stats_4 = influence_stats(copy_4)
    rest_vol_4, rest_size_4 = mesh_volume(copy_4)
    rest_pts_4, _, _ = evaluated_points(copy_4)

    copy_twist = duplicate_skinned_mesh(original, arm, "skin_twist_collapsed")
    twist_info = collapse_twist_weights(copy_twist)
    rest_vol_t, rest_size_t = mesh_volume(copy_twist)
    rest_pts_t, _, _ = evaluated_points(copy_twist)

    variants = [
        ("original", original, rest_pts, rest_vol, rest_size, rest_diag),
        ("4inf", copy_4, rest_pts_4, rest_vol_4, rest_size_4, math.sqrt(sum(s * s for s in rest_size_4))),
        ("twist_collapsed", copy_twist, rest_pts_t, rest_vol_t, rest_size_t, math.sqrt(sum(s * s for s in rest_size_t))),
    ]

    rows = []
    forensics = {}
    for bone, angles in SWEEPS.items():
        if bone not in axes:
            continue
        for angle in angles:
            apply_pose(arm, axes, [(bone, angle)])
            for variant, mesh, rpts, rvol, rsize, rdiag in variants:
                meas = measure_mesh(mesh, rpts, rvol, rsize, rdiag)
                row = row_from_measure(character, variant, bone, axes[bone], angle, meas)
                rows.append(row)
                key = "%s|%s|%s" % (variant, bone, angle)
                if row["verdict"] in ("BROKEN", "CATASTROPHIC") and key not in forensics:
                    forensics[key] = forensic_vertices(
                        mesh, rpts, meas["pts"], meas["extreme_indices"], rdiag)

    standing_specs = [
        ("CC_Base_L_Upperarm", 62), ("CC_Base_R_Upperarm", 62),
        ("CC_Base_L_Forearm", 28), ("CC_Base_R_Forearm", 28),
        ("CC_Base_L_Calf", 18), ("CC_Base_R_Calf", 18),
    ]
    apply_pose(arm, axes, standing_specs)
    standing = {}
    for variant, mesh, rpts, rvol, rsize, rdiag in variants:
        meas = measure_mesh(mesh, rpts, rvol, rsize, rdiag)
        row = row_from_measure(character, variant, "STANDING_COMBO", {"axis": [0, 0, 0], "sign": 1}, 0, meas)
        rows.append(row)
        standing[variant] = {
            "volume_ratio": row["volume_ratio"],
            "max_axis_ratio": row["max_axis_ratio"],
            "verdict": row["verdict"],
            "max_vertex_disp": row["max_vertex_disp"],
            "extreme_vertex_count": row["extreme_vertex_count"],
        }
        if row["verdict"] in ("BROKEN", "CATASTROPHIC"):
            forensics["%s|STANDING" % variant] = forensic_vertices(
                mesh, rpts, meas["pts"], meas["extreme_indices"], rdiag)

    # Apply-scale copy experiment (temporary; not saved to source).
    scale_experiment = {}
    try:
        arm_s = arm.copy()
        arm_s.data = arm.data.copy()
        mesh_s = original.copy()
        mesh_s.data = original.data.copy()
        bpy.context.collection.objects.link(arm_s)
        bpy.context.collection.objects.link(mesh_s)
        mesh_s.parent = arm_s
        for mod in mesh_s.modifiers:
            if mod.type == "ARMATURE":
                mod.object = arm_s
        bpy.context.view_layer.objects.active = arm_s
        arm_s.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        clear_pose(arm_s)
        bpy.context.view_layer.update()
        svol, ssize = mesh_volume(mesh_s)
        spts, _, _ = evaluated_points(mesh_s)
        sdiag = math.sqrt(sum(s * s for s in ssize))
        if "CC_Base_L_Upperarm" in axes:
            rotate_bone(arm_s, "CC_Base_L_Upperarm", axes["CC_Base_L_Upperarm"]["axis"],
                        axes["CC_Base_L_Upperarm"]["sign"] * 60.0)
            bpy.context.view_layer.update()
            sm = measure_mesh(mesh_s, spts, svol, ssize, sdiag)
            scale_experiment = {
                "applied_rotation_and_scale": True,
                "volume_ratio_upperarm_60": round(sm["volume_ratio"], 4),
                "verdict": classify_pose(
                    sm["volume_ratio"], sm["max_axis_ratio"], sm["nan_count"],
                    sm["inf_count"], sm["extreme_vertex_count"], "CC_Base_L_Upperarm"),
            }
        bpy.data.objects.remove(mesh_s, do_unlink=True)
        bpy.data.objects.remove(arm_s, do_unlink=True)
    except Exception as exc:
        scale_experiment = {"error": str(exc)}

    write_csv(csv_path, rows)
    orig_worst, orig_max = worst_status(rows, "original")
    inf_worst, inf_max = worst_status(rows, "4inf")
    twist_worst, twist_max = worst_status(rows, "twist_collapsed")

    copy_4.hide_viewport = True
    copy_twist.hide_viewport = True
    export_standing_glb(arm, original, axes, glb_path)
    roundtrip = glb_roundtrip(glb_path, rest_vol)

    payload = {
        "character": character,
        "mixamo_used": False,
        "rest_volume": rest_vol,
        "rest_size": [round(x, 4) for x in rest_size],
        "axes": axes,
        "armature_modifier": audit,
        "influence_stats": {"original": stats_original, "4inf": stats_4},
        "twist_collapse": twist_info,
        "original_worst": orig_worst,
        "original_max_volume_ratio": round(orig_max, 4),
        "four_inf_worst": inf_worst,
        "four_inf_max_volume_ratio": round(inf_max, 4),
        "twist_worst": twist_worst,
        "twist_max_volume_ratio": round(twist_max, 4),
        "standing": standing,
        "scale_apply_experiment": scale_experiment,
        "glb_roundtrip": roundtrip,
        "forensics_keys": list(forensics.keys()),
        "forensics": forensics,
        "csv": csv_path,
        "blend": blend_path,
        "standing_glb": glb_path,
        "production_v4_untouched": True,
    }
    write_json(json_path, payload)

    # Preview grid last so the saved blend is inspectable.
    copy_4.hide_viewport = True
    copy_twist.hide_viewport = True
    build_preview_grid(arm, original, axes, character, blend_path)
    print("NATIVE_SKIN_AUDIT %s original=%s volmax=%.3f 4inf=%s twist=%s standing=%s" % (
        character, orig_worst, orig_max, inf_worst, twist_worst, standing["original"]["verdict"]))
    return payload


def main():
    args = parse_args()
    audit_character(args.character)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
