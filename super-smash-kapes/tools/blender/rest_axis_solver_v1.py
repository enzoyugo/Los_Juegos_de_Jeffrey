"""Mixamo → ActorCore rest-axis solver V1 (Idle only).

True rest is EditBone / matrix_local with the action disconnected and pose
cleared. Frame 1 is animation, never bind.

Usage:
  blender --background --python rest_axis_solver_v1.py -- --dump-rest-only
  blender --background --python rest_axis_solver_v1.py -- --character terere
  blender --background --python rest_axis_solver_v1.py -- --character jaguarete
"""
from __future__ import print_function

import argparse
import hashlib
import json
import math
import os
import sys
import traceback

import bpy
from mathutils import Matrix, Quaternion, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import (  # noqa: E402
    clear_pose,
    find_armature,
    find_source_action,
    import_fbx,
    insert_pose_keyframes,
    mapped_pairs_from_bone_map,
    purge_orphans,
    rebind_actorcore_textures,
    reset_scene,
    setup_preview_camera,
    write_json,
)
from actorcore_paths import BONE_MAP_JSON, CHARACTERS, GENERATED_DIR, HIP_Y_SCALE, IDLE_FBX  # noqa: E402
from export_actorcore_game_ready import limit_influences, mesh_volume, skinned_meshes, strip_non_production  # noqa: E402


VOLUME_LIMIT = 1.35
AXIS_LIMIT = 1.30
LENGTH_REL_TOL = 0.04
REST_SOURCE = "edit_bone.matrix_local_with_pose_cleared"
METHOD_JSON = os.path.join(GENERATED_DIR, "SOLVER_V1_SELECTED_METHOD.json")
C_BONES_JSON = os.path.join(GENERATED_DIR, "SOLVER_V1_C_BONES.json")


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--character", choices=["terere", "jaguarete"], default="")
    p.add_argument("--dump-rest-only", action="store_true")
    p.add_argument(
        "--method",
        default="auto",
        choices=[
            "auto",
            "parent_relative_cob",
            "world_delta_hierarchy",
            "bone_y_aim",
            "c_gated_hybrid",
            "raw_low_c",
            "arm_y_aim_only",
            "limb_y_aim",
            "constraint_world_arms",
        ],
    )
    return p.parse_args(argv)


def vec3(v):
    return [round(float(v.x), 6), round(float(v.y), 6), round(float(v.z), 6)]


def mat16(m):
    return [round(float(v), 8) for row in m for v in row]


def mat_from_16(vals):
    return Matrix((
        (vals[0], vals[1], vals[2], vals[3]),
        (vals[4], vals[5], vals[6], vals[7]),
        (vals[8], vals[9], vals[10], vals[11]),
        (vals[12], vals[13], vals[14], vals[15]),
    ))


def parent_relative_rest(bone):
    if bone.parent:
        return bone.parent.matrix_local.inverted() @ bone.matrix_local
    return bone.matrix_local.copy()


def world_rest(arm, bone):
    return arm.matrix_world @ bone.matrix_local


def rotation_of(matrix):
    """Pure rotation from a possibly scaled FBX object/bone matrix."""
    _loc, rot, _scale = matrix.decompose()
    return rot


def disconnect_action(arm):
    if arm.animation_data:
        arm.animation_data.action = None


def disable_driven_pose(arm):
    disconnect_action(arm)
    if arm.animation_data:
        for track in getattr(arm.animation_data, "nla_tracks", []):
            track.mute = True


def apply_c_gated_hybrid(source_arm, target_arm, src, dst, c_map):
    """User CoB on bones whose rest axes already match; Y-aim on limbs whose
    rest axes differ ~90°; identity on hip/spine/neck/head with large C.

    Gate uses measured C_angle, never a fighter name.
    """
    t_pb = target_arm.pose.bones[dst]
    c_ang = float(c_map.get(dst, {}).get("C_angle_deg", 90.0))
    limb = any(part in dst for part in (
        "Upperarm", "Forearm", "Hand", "Clavicle", "Thigh", "Calf", "Foot", "Toe",
    ))
    if c_ang < 40.0:
        apply_parent_relative_cob(source_arm, target_arm, src, dst, mat_from_16(c_map[dst]["C"]).to_3x3())
    elif limb:
        apply_bone_y_aim(source_arm, target_arm, src, dst)
    else:
        t_pb.rotation_mode = "QUATERNION"
        t_pb.rotation_quaternion = Quaternion()
        t_pb.location = Vector((0.0, 0.0, 0.0))
        t_pb.scale = Vector((1.0, 1.0, 1.0))


def apply_raw_low_c(source_arm, target_arm, src, dst, c_map):
    """Copy Mixamo matrix_basis onto ActorCore when rest axes already match (C<40°).

    High-mismatch bones stay at ActorCore rest. This is M_delta_src with C≈I.
    """
    t_pb = target_arm.pose.bones[dst]
    s_pb = source_arm.pose.bones[src]
    c_ang = float(c_map.get(dst, {}).get("C_angle_deg", 90.0))
    t_pb.rotation_mode = "QUATERNION"
    t_pb.location = Vector((0.0, 0.0, 0.0))
    t_pb.scale = Vector((1.0, 1.0, 1.0))
    if c_ang < 40.0:
        q = rotation_of(s_pb.matrix_basis)
        if q.w < 0.0:
            q = -q
        t_pb.rotation_quaternion = q
    else:
        t_pb.rotation_quaternion = Quaternion()


def apply_named_y_aim(source_arm, target_arm, src, dst, allow_substrings):
    if any(part in dst for part in allow_substrings):
        apply_bone_y_aim(source_arm, target_arm, src, dst)
        return
    t_pb = target_arm.pose.bones[dst]
    t_pb.rotation_mode = "QUATERNION"
    t_pb.rotation_quaternion = Quaternion()
    t_pb.location = Vector((0.0, 0.0, 0.0))
    t_pb.scale = Vector((1.0, 1.0, 1.0))


def constraint_world_copy(source_arm, target_arm, pairs, allow_substrings):
    """Blender-native world Copy Rotation on selected mapped bones, then bake visual."""
    for pb in target_arm.pose.bones:
        for con in list(pb.constraints):
            pb.constraints.remove(con)
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector((0.0, 0.0, 0.0))
        pb.scale = Vector((1.0, 1.0, 1.0))
    for pair in pairs:
        dst = pair["target"]
        if dst not in target_arm.pose.bones:
            continue
        if allow_substrings and not any(part in dst for part in allow_substrings):
            continue
        pb = target_arm.pose.bones[dst]
        con = pb.constraints.new("COPY_ROTATION")
        con.target = source_arm
        con.subtarget = pair["source"]
        con.target_space = "WORLD"
        con.owner_space = "WORLD"
        if hasattr(con, "mix_mode"):
            con.mix_mode = "REPLACE"
        if hasattr(con, "use_offset"):
            con.use_offset = False
    bpy.context.view_layer.update()
    prev = bpy.context.view_layer.objects.active
    bpy.context.view_layer.objects.active = target_arm
    target_arm.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.pose.visual_transform_apply()
    bpy.ops.pose.constraints_clear()
    bpy.ops.object.mode_set(mode="OBJECT")
    if prev is not None:
        bpy.context.view_layer.objects.active = prev
    for pb in target_arm.pose.bones:
        pb.location = Vector((0.0, 0.0, 0.0))
        pb.scale = Vector((1.0, 1.0, 1.0))


def edit_rolls(arm):
    rolls = {}
    prev = bpy.context.view_layer.objects.active
    try:
        bpy.context.view_layer.objects.active = arm
        arm.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        for eb in arm.data.edit_bones:
            rolls[eb.name] = round(float(eb.roll), 6)
        bpy.ops.object.mode_set(mode="OBJECT")
    except Exception:
        try:
            bpy.ops.object.mode_set(mode="OBJECT")
        except Exception:
            pass
    if prev is not None:
        bpy.context.view_layer.objects.active = prev
    return rolls


def bone_record(arm, bone, rolls):
    pr = parent_relative_rest(bone)
    wr = world_rest(arm, bone)
    axes = wr.to_3x3()
    return {
        "name": bone.name,
        "parent": bone.parent.name if bone.parent else None,
        "roll": rolls.get(bone.name, 0.0),
        "head": vec3(bone.head_local),
        "tail": vec3(bone.tail_local),
        "length": round(float(bone.length), 6),
        "use_deform": bool(getattr(bone, "use_deform", True)),
        "matrix_local": mat16(bone.matrix_local),
        "parent_matrix_local": mat16(bone.parent.matrix_local) if bone.parent else None,
        "parent_relative_rest": mat16(pr),
        "world_rest": mat16(wr),
        "axes_world": {
            "x": vec3(axes @ Vector((1, 0, 0))),
            "y": vec3(axes @ Vector((0, 1, 0))),
            "z": vec3(axes @ Vector((0, 0, 1))),
        },
        "rest_is_edit_bone": True,
        "frame_1_not_used_as_rest": True,
    }


def dump_armature_rest(arm, label):
    disconnect_action(arm)
    clear_pose(arm)
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    rolls = edit_rolls(arm)
    bones = [bone_record(arm, b, rolls) for b in arm.data.bones]
    arm.data.pose_position = "POSE"
    clear_pose(arm)
    bpy.context.view_layer.update()
    return {
        "label": label,
        "armature": arm.name,
        "rest_source": REST_SOURCE,
        "frame_1_is_not_bind_pose": True,
        "object_rotation_euler_deg": [round(math.degrees(a), 4) for a in arm.rotation_euler],
        "object_scale": vec3(arm.scale),
        "bone_count": len(bones),
        "bones": {b["name"]: b for b in bones},
    }


def mapped_pairs():
    with open(BONE_MAP_JSON, "r", encoding="utf-8") as fh:
        return mapped_pairs_from_bone_map(json.load(fh))


def compute_c_bones(source_arm, target_arm, pairs):
    """C maps Mixamo local coords into ActorCore local coords via world rest axes.

    C = T_world_rest^-1 * S_world_rest
    Rotation conversion: R_tgt = C * R_src * C^-1
    """
    out = {}
    for pair in pairs:
        src, dst = pair["source"], pair["target"]
        if src not in source_arm.data.bones or dst not in target_arm.data.bones:
            continue
        s_world = rotation_of(world_rest(source_arm, source_arm.data.bones[src])).to_matrix()
        t_world = rotation_of(world_rest(target_arm, target_arm.data.bones[dst])).to_matrix()
        s_pr = rotation_of(parent_relative_rest(source_arm.data.bones[src])).to_matrix()
        t_pr = rotation_of(parent_relative_rest(target_arm.data.bones[dst])).to_matrix()
        c = t_world.inverted() @ s_world
        ang = abs(math.degrees(c.to_quaternion().angle)) % 360.0
        if ang > 180.0:
            ang = 360.0 - ang
        out[dst] = {
            "source": src,
            "target": dst,
            "C": mat16(c.to_4x4()),
            "C_angle_deg": round(ang, 4),
            "C_is_orthonormal": True,
            "formula": "C = T_world_rest_rot^-1 * S_world_rest_rot (scale stripped)",
            "source_parent_relative_rest": mat16(s_pr.to_4x4()),
            "target_parent_relative_rest": mat16(t_pr.to_4x4()),
        }
    return out


def set_basis_from_armature_matrix(pb, desired_arm):
    bone = pb.bone
    if pb.parent:
        rest_pr = pb.parent.bone.matrix_local.inverted() @ bone.matrix_local
        basis = rest_pr.inverted() @ pb.parent.matrix.inverted() @ desired_arm
    else:
        basis = bone.matrix_local.inverted() @ desired_arm
    _loc, rot, _scale = basis.decompose()
    pb.rotation_mode = "QUATERNION"
    pb.matrix_basis = rot.to_matrix().to_4x4()
    pb.location = Vector((0.0, 0.0, 0.0))
    pb.scale = Vector((1.0, 1.0, 1.0))


def set_world_rotation(target_arm, t_pb, t_db, desired_q):
    """Set matrix_basis so the bone's world rotation is desired_q.

    Local translation stays rest-relative (follows the posed parent). Rest
    translation is NOT baked into the 4x4 — that polluted the rotation and
    exploded the mesh.
    """
    desired_arm_q = rotation_of(target_arm.matrix_world.inverted()) @ desired_q
    if t_pb.parent:
        rest_pr_q = rotation_of(t_pb.parent.bone.matrix_local.inverted() @ t_db.matrix_local)
        parent_q = rotation_of(t_pb.parent.matrix)
        basis_q = rest_pr_q.inverted() @ parent_q.inverted() @ desired_arm_q
    else:
        basis_q = rotation_of(t_db.matrix_local).inverted() @ desired_arm_q
    if basis_q.w < 0.0:
        basis_q = -basis_q
    t_pb.rotation_mode = "QUATERNION"
    t_pb.rotation_quaternion = basis_q
    t_pb.location = Vector((0.0, 0.0, 0.0))
    t_pb.scale = Vector((1.0, 1.0, 1.0))


def apply_world_delta_hierarchy(source_arm, target_arm, src, dst):
    """Same world rotation the Mixamo bone underwent, applied onto ActorCore rest.

    Scale is stripped. Rest is edit/bind, never frame 1.
    world_delta_q = src_anim_q * inverse(src_rest_q)
    desired_q = world_delta_q * tgt_rest_q
    """
    s_pb = source_arm.pose.bones[src]
    s_db = source_arm.data.bones[src]
    t_pb = target_arm.pose.bones[dst]
    t_db = target_arm.data.bones[dst]
    src_rest_q = rotation_of(world_rest(source_arm, s_db))
    src_anim_q = rotation_of(source_arm.matrix_world @ s_pb.matrix)
    tgt_rest_q = rotation_of(world_rest(target_arm, t_db))
    world_delta_q = src_anim_q @ src_rest_q.inverted()
    set_world_rotation(target_arm, t_pb, t_db, world_delta_q @ tgt_rest_q)


def apply_parent_relative_cob(source_arm, target_arm, src, dst, c_3x3):
    """User local equation with true rest, not frame 1.

    M_delta_src = inverse(M_src_rest_local) * M_src_anim_local
    M_delta_target = C * M_delta_src * inverse(C)
    target.matrix_basis = M_delta_target   # Blender: basis is rest-relative local
    """
    s_pb = source_arm.pose.bones[src]
    s_db = source_arm.data.bones[src]
    t_pb = target_arm.pose.bones[dst]
    if s_pb.parent:
        anim_pr = s_pb.parent.matrix.inverted() @ s_pb.matrix
    else:
        anim_pr = s_pb.matrix.copy()
    rest_pr = parent_relative_rest(s_db)
    delta_q = rotation_of(rest_pr.inverted() @ anim_pr)
    d3 = c_3x3 @ delta_q.to_matrix() @ c_3x3.inverted()
    t_pb.rotation_mode = "QUATERNION"
    t_pb.matrix_basis = rotation_of(d3.to_4x4()).to_matrix().to_4x4()
    t_pb.location = Vector((0.0, 0.0, 0.0))
    t_pb.scale = Vector((1.0, 1.0, 1.0))


def apply_bone_y_aim(source_arm, target_arm, src, dst):
    """Aim ActorCore bone Y at Mixamo posed bone Y (world), then copy twist around Y.

    Matches Idle silhouette without conjugating a 90° rest-axis mismatch through hip.
    """
    s_pb = source_arm.pose.bones[src]
    s_db = source_arm.data.bones[src]
    t_pb = target_arm.pose.bones[dst]
    t_db = target_arm.data.bones[dst]
    src_rest_q = rotation_of(world_rest(source_arm, s_db))
    src_anim_q = rotation_of(source_arm.matrix_world @ s_pb.matrix)
    tgt_rest_q = rotation_of(world_rest(target_arm, t_db))
    src_rest_y = (src_rest_q.to_matrix() @ Vector((0, 1, 0))).normalized()
    src_anim_y = (src_anim_q.to_matrix() @ Vector((0, 1, 0))).normalized()
    tgt_rest_y = (tgt_rest_q.to_matrix() @ Vector((0, 1, 0))).normalized()
    swing = tgt_rest_y.rotation_difference(src_anim_y)
    aimed_q = swing @ tgt_rest_q
    swing_src = src_rest_y.rotation_difference(src_anim_y)
    src_swung = swing_src @ src_rest_q
    twist = src_swung.inverted() @ src_anim_q
    axis, angle = twist.to_axis_angle()
    if axis.length < 1e-8 or abs(angle) < 1e-8:
        twist_q = Quaternion()
    else:
        if axis.dot(src_anim_y) < 0.0:
            axis = -axis
            angle = -angle
        twist_q = Quaternion(src_anim_y, angle * max(0.0, axis.dot(src_anim_y)))
    set_world_rotation(target_arm, t_pb, t_db, twist_q @ aimed_q)


def hierarchy_pairs(target_arm, pairs):
    index = {b.name: i for i, b in enumerate(target_arm.data.bones)}
    ranked = [(index.get(p["target"], 10 ** 6), p) for p in pairs]
    ranked.sort(key=lambda item: item[0])
    return [p for _, p in ranked]


def apply_hip_y_rest_relative(source_arm, target_arm, src, dst, rest_y, scale):
    t_pb = target_arm.pose.bones[dst]
    s_pb = source_arm.pose.bones[src]
    t_pb.location = Vector((0.0, (s_pb.location.y - rest_y) * scale, 0.0))


def retarget_frame(source_arm, target_arm, pairs, c_map, method, frame, hip_rest_y):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    if method == "constraint_world_arms":
        constraint_world_copy(
            source_arm, target_arm, pairs,
            ("Upperarm", "Forearm"),
        )
        hip = next((p for p in pairs if p.get("allow_location_y")), None)
        if hip:
            apply_hip_y_rest_relative(source_arm, target_arm, hip["source"], hip["target"], hip_rest_y, HIP_Y_SCALE)
        bpy.context.view_layer.update()
        return
    ordered = hierarchy_pairs(target_arm, pairs)
    for pair in ordered:
        src, dst = pair["source"], pair["target"]
        if src not in source_arm.pose.bones or dst not in target_arm.pose.bones:
            continue
        if method == "parent_relative_cob":
            c_mat = mat_from_16(c_map[dst]["C"]).to_3x3()
            apply_parent_relative_cob(source_arm, target_arm, src, dst, c_mat)
        elif method == "bone_y_aim":
            apply_bone_y_aim(source_arm, target_arm, src, dst)
        elif method == "c_gated_hybrid":
            apply_c_gated_hybrid(source_arm, target_arm, src, dst, c_map)
        elif method == "raw_low_c":
            apply_raw_low_c(source_arm, target_arm, src, dst, c_map)
        elif method == "arm_y_aim_only":
            apply_named_y_aim(source_arm, target_arm, src, dst, ("Upperarm", "Forearm", "Hand", "Clavicle"))
        elif method == "limb_y_aim":
            apply_named_y_aim(
                source_arm, target_arm, src, dst,
                ("Upperarm", "Forearm", "Hand", "Clavicle", "Thigh", "Calf", "Foot", "Toe"),
            )
        else:
            apply_world_delta_hierarchy(source_arm, target_arm, src, dst)
        if pair.get("allow_location_y"):
            apply_hip_y_rest_relative(source_arm, target_arm, src, dst, hip_rest_y, HIP_Y_SCALE)
        if src == "mixamorig5:LeftArm" and frame in (1, 55):
            deg = abs(math.degrees(rotation_of(source_arm.pose.bones[src].matrix_basis).angle))
            print("MIXAMO LeftArm frame=%s basis_deg=%.2f method=%s" % (frame, deg, method))
        bpy.context.view_layer.update()


def limb_lengths(arm):
    names = {
        "L_upperarm": ("CC_Base_L_Upperarm", "CC_Base_L_Forearm"),
        "L_forearm": ("CC_Base_L_Forearm", "CC_Base_L_Hand"),
        "R_upperarm": ("CC_Base_R_Upperarm", "CC_Base_R_Forearm"),
        "R_forearm": ("CC_Base_R_Forearm", "CC_Base_R_Hand"),
        "L_thigh": ("CC_Base_L_Thigh", "CC_Base_L_Calf"),
        "L_calf": ("CC_Base_L_Calf", "CC_Base_L_Foot"),
        "R_thigh": ("CC_Base_R_Thigh", "CC_Base_R_Calf"),
        "R_calf": ("CC_Base_R_Calf", "CC_Base_R_Foot"),
    }
    out = {}
    for key, (a, b) in names.items():
        if a not in arm.pose.bones or b not in arm.pose.bones:
            continue
        pa = arm.matrix_world @ arm.pose.bones[a].head
        pb = arm.matrix_world @ arm.pose.bones[b].head
        out[key] = float((pb - pa).length)
    return out


def pose_angles(arm):
    def world_y(name):
        pb = arm.pose.bones[name]
        return ((arm.matrix_world @ pb.matrix).to_3x3() @ Vector((0, 1, 0))).normalized()

    def world_head(name):
        return arm.matrix_world @ arm.pose.bones[name].head

    hip = world_head("CC_Base_Hip")
    head = world_head("CC_Base_Head")
    torso_up = (head - hip).normalized()
    down = -torso_up

    def from_down(bone_name):
        return round(math.degrees(world_y(bone_name).angle(down)), 3)

    l_arm = from_down("CC_Base_L_Upperarm")
    r_arm = from_down("CC_Base_R_Upperarm")
    return {
        "L_upperarm_from_down_deg": l_arm,
        "R_upperarm_from_down_deg": r_arm,
        "L_forearm_from_down_deg": from_down("CC_Base_L_Forearm"),
        "R_forearm_from_down_deg": from_down("CC_Base_R_Forearm"),
        "L_thigh_from_down_deg": from_down("CC_Base_L_Thigh"),
        "R_thigh_from_down_deg": from_down("CC_Base_R_Thigh"),
        "torso_lean_deg": round(math.degrees(world_y("CC_Base_Spine01").angle(torso_up)), 3),
        "mean_upperarm_from_down_deg": round(0.5 * (l_arm + r_arm), 3),
    }


def classify_pose(angles, volume_ok, length_ok):
    if not volume_ok or not length_ok:
        return "DEFORMATION_INVALID"
    if angles["mean_upperarm_from_down_deg"] >= 70.0:
        return "T_POSE_LIKE"
    return "STANDING_IDLE"


def texture_hashes():
    out = {}
    for img in bpy.data.images:
        payload = None
        if getattr(img, "packed_file", None) and img.packed_file:
            payload = bytes(img.packed_file.data)
        else:
            path = bpy.path.abspath(img.filepath) if img.filepath else ""
            if path and os.path.isfile(path):
                with open(path, "rb") as fh:
                    payload = fh.read()
        if payload:
            key = img.name.lower()
            kind = "other"
            if "diffuse" in key or "albedo" in key:
                kind = "diffuse"
            elif "normal" in key:
                kind = "normal"
            out[kind] = hashlib.sha256(payload).hexdigest()[:16]
    return out


def solver_paths(character):
    root = os.path.join(
        os.path.dirname(os.path.dirname(CHARACTERS[character]["benchmark_dir"])),
        "solver_v1",
        character,
    )
    return {
        "dir": root,
        "glb": os.path.join(root, "%s_idle_solver_v1.glb" % character),
        "blend": os.path.join(root, "%s_idle_solver_v1_preview.blend" % character),
        "metrics": os.path.join(GENERATED_DIR, "%s_IDLE_SOLVER_V1_METRICS.json" % character.upper()),
    }


def dump_rest_authorities():
    reset_scene()
    import_fbx(IDLE_FBX)
    mix_arm = find_armature()
    mix = dump_armature_rest(mix_arm, "Mixamo Idle.fbx edit rest")
    mix["file"] = IDLE_FBX
    mix["mapped_bones"] = [p["source"] for p in mapped_pairs()]
    write_json(os.path.join(GENERATED_DIR, "MIXAMO_REST_BASIS.json"), mix)

    reset_scene()
    import_fbx(CHARACTERS["terere"]["fbx"])
    ac_arm = find_armature()
    ac = dump_armature_rest(ac_arm, "ActorCore CC_Base terere autorig edit rest")
    ac["file"] = CHARACTERS["terere"]["fbx"]
    ac["canonical_for"] = ["terere", "jaguarete"]
    ac["mapped_bones"] = [p["target"] for p in mapped_pairs()]

    reset_scene()
    import_fbx(CHARACTERS["jaguarete"]["fbx"])
    jag_arm = find_armature()
    jag_names = sorted(b.name for b in jag_arm.data.bones)
    ac["jaguarete_bone_names_equal"] = jag_names == sorted(ac["bones"].keys())
    ac["jaguarete_bone_count"] = len(jag_names)
    write_json(os.path.join(GENERATED_DIR, "ACTORCORE_REST_BASIS.json"), ac)
    print("REST dumps Mixamo=%d ActorCore=%d jag_match=%s" % (
        mix["bone_count"], ac["bone_count"], ac["jaguarete_bone_names_equal"]))


def evaluate_current_pose(target, mesh, rest_vol, rest_size, rest_lengths):
    vol, size = mesh_volume(mesh)
    hip = target.pose.bones["CC_Base_Hip"].location.copy()
    vol_ratio = vol / max(rest_vol, 1e-6)
    axis_ratio = max(size) / max(max(rest_size), 1e-6)
    lengths = limb_lengths(target)
    len_err = 0.0
    for key, rest_l in rest_lengths.items():
        if rest_l <= 1e-8:
            continue
        len_err = max(len_err, abs(lengths[key] - rest_l) / rest_l)
    angles = pose_angles(target)
    return vol_ratio, axis_ratio, len_err, hip, angles


def probe_method(source, target, pairs, c_map, method, frames, hip_rest_y, mesh, rest_vol, rest_size, rest_lengths):
    max_vol = 0.0
    max_axis = 0.0
    max_len = 0.0
    mid_angles = None
    for i, frame in enumerate(frames):
        retarget_frame(source, target, pairs, c_map, method, frame, hip_rest_y)
        bpy.context.view_layer.update()
        vol_ratio, axis_ratio, len_err, _hip, angles = evaluate_current_pose(
            target, mesh, rest_vol, rest_size, rest_lengths)
        max_vol = max(max_vol, vol_ratio)
        max_axis = max(max_axis, axis_ratio)
        max_len = max(max_len, len_err)
        if i == len(frames) // 2:
            mid_angles = angles
    volume_ok = max_vol <= VOLUME_LIMIT and max_axis <= AXIS_LIMIT
    length_ok = max_len <= LENGTH_REL_TOL
    classification = classify_pose(mid_angles or {"mean_upperarm_from_down_deg": 90.0}, volume_ok, length_ok)
    clear_pose(target)
    bpy.context.view_layer.update()
    print("PROBE %s vol=%.3f axis=%.3f class=%s arms=%.1f" % (
        method, max_vol, max_axis, classification,
        (mid_angles or {}).get("mean_upperarm_from_down_deg", -1)))
    return {
        "method": method,
        "max_volume_ratio": round(max_vol, 4),
        "max_axis_ratio": round(max_axis, 4),
        "max_limb_length_rel_error": round(max_len, 5),
        "idle_pose_classification": classification,
        "mid_frame_angles": mid_angles,
        "accepted": classification == "STANDING_IDLE",
    }


def select_method(args_method, source, target, pairs, c_map, frames, hip_rest_y, mesh, rest_vol, rest_size, rest_lengths):
    if args_method != "auto":
        return args_method, []
    if os.path.isfile(METHOD_JSON):
        existing = json.loads(open(METHOD_JSON, "r", encoding="utf-8").read())
        if existing.get("method") in (
            "parent_relative_cob",
            "world_delta_hierarchy",
            "bone_y_aim",
            "raw_low_c",
            "arm_y_aim_only",
            "limb_y_aim",
            "constraint_world_arms",
        ):
            return existing["method"], existing.get("probes", [])
    probes = []
    for method in ("constraint_world_arms", "arm_y_aim_only"):
        probes.append(probe_method(
            source, target, pairs, c_map, method, frames, hip_rest_y, mesh, rest_vol, rest_size, rest_lengths))
    chosen = "constraint_world_arms"
    for probe in probes:
        if probe["accepted"]:
            chosen = probe["method"]
            break
    payload = {
        "method": chosen,
        "shared_by": ["terere", "jaguarete"],
        "rest_source": REST_SOURCE,
        "uses_frame_1_as_bind": False,
        "probes": probes,
        "note": "Same method for both fighters. User CoB tried first; world-delta is fallback.",
    }
    write_json(METHOD_JSON, payload)
    return chosen, probes


def bake_character(character, args_method):
    cfg = CHARACTERS[character]
    paths = solver_paths(character)
    os.makedirs(paths["dir"], exist_ok=True)
    pairs = mapped_pairs()
    reset_scene()
    bpy.context.scene.render.fps = 30
    import_fbx(cfg["fbx"])
    rebind_actorcore_textures(character)
    target = find_armature()
    import_fbx(IDLE_FBX)
    source = [a for a in bpy.data.objects if a.type == "ARMATURE" and a != target][0]
    source_action = find_source_action(source, "mixamo")
    source.animation_data_create()
    source.animation_data.action = source_action
    frame_start = int(source_action.frame_range[0])
    frame_end = int(source_action.frame_range[1])

    stored_action = source.animation_data.action
    disconnect_action(source)
    disable_driven_pose(target)
    clear_pose(source)
    clear_pose(target)
    bpy.context.view_layer.update()
    c_map = compute_c_bones(source, target, pairs)
    hip_src = next((p["source"] for p in pairs if p.get("allow_location_y")), None)
    hip_rest_y = source.pose.bones[hip_src].location.y if hip_src and hip_src in source.pose.bones else 0.0
    write_json(C_BONES_JSON, {
        "method_formula": "C = T_world_rest^-1 * S_world_rest",
        "rest_source": REST_SOURCE,
        "uses_frame_1_as_bind": False,
        "shared_by": ["terere", "jaguarete"],
        "bones": c_map,
    })
    source.animation_data.action = stored_action

    meshes = skinned_meshes(target)
    clear_pose(target)
    bpy.context.view_layer.update()
    rest_vol, rest_size = mesh_volume(meshes[0])
    rest_lengths = limb_lengths(target)
    probe_frames = sorted(set([
        frame_start,
        frame_start + 10,
        int((frame_start + frame_end) * 0.5),
        frame_end,
    ]))
    method, probes = select_method(
        args_method, source, target, pairs, c_map, probe_frames, hip_rest_y,
        meshes[0], rest_vol, rest_size, rest_lengths)

    if target.animation_data is None:
        target.animation_data_create()
    action = bpy.data.actions.new("idle")
    target.animation_data.action = action
    target_bones = [p["target"] for p in pairs]
    samples = []
    max_vol_ratio = 0.0
    max_axis_ratio = 0.0
    max_len_err = 0.0
    max_root_xz = 0.0
    mid_sample = None
    mid_frame = int((frame_start + frame_end) * 0.5)
    for frame in range(frame_start, frame_end + 1):
        retarget_frame(source, target, pairs, c_map, method, frame, hip_rest_y)
        insert_pose_keyframes(target, target_bones, frame)
        if (frame - frame_start) % 10 == 0 or frame in (frame_start, frame_end, mid_frame):
            bpy.context.view_layer.update()
            vol_ratio, axis_ratio, len_err, hip, angles = evaluate_current_pose(
                target, meshes[0], rest_vol, rest_size, rest_lengths)
            max_vol_ratio = max(max_vol_ratio, vol_ratio)
            max_axis_ratio = max(max_axis_ratio, axis_ratio)
            max_len_err = max(max_len_err, len_err)
            max_root_xz = max(max_root_xz, abs(hip.x), abs(hip.z))
            sample = {
                "frame": frame,
                "volume_ratio": round(vol_ratio, 4),
                "max_axis_ratio": round(axis_ratio, 4),
                "max_length_rel_error": round(len_err, 5),
                "hip_location": [round(hip.x, 5), round(hip.y, 5), round(hip.z, 5)],
                "angles": angles,
            }
            samples.append(sample)
            if frame == mid_frame:
                mid_sample = sample

    volume_ok = max_vol_ratio <= VOLUME_LIMIT and max_axis_ratio <= AXIS_LIMIT
    length_ok = max_len_err <= LENGTH_REL_TOL
    mid_angles = (mid_sample or samples[len(samples) // 2])["angles"]
    classification = classify_pose(mid_angles, volume_ok, length_ok)
    hashes = texture_hashes()
    metrics = {
        "character": character,
        "solver": "rest_axis_solver_v1",
        "method": method,
        "shared_generic_solver": True,
        "rest_source": REST_SOURCE,
        "uses_frame_1_as_bind": False,
        "idle_file": IDLE_FBX,
        "frame_range": [frame_start, frame_end],
        "rest_size": [round(x, 4) for x in rest_size],
        "rest_volume": round(rest_vol, 6),
        "max_volume_ratio": round(max_vol_ratio, 4),
        "max_axis_ratio": round(max_axis_ratio, 4),
        "max_limb_length_rel_error": round(max_len_err, 5),
        "max_root_xz": round(max_root_xz, 5),
        "volume_limit": VOLUME_LIMIT,
        "axis_limit": AXIS_LIMIT,
        "length_rel_tol": LENGTH_REL_TOL,
        "volume_pass": volume_ok,
        "length_pass": length_ok,
        "root_xz_pass": max_root_xz <= 0.05,
        "idle_pose_classification": classification,
        "mid_frame_angles": mid_angles,
        "probes": probes,
        "texture_hashes": hashes,
        "samples": samples,
        "output_glb": paths["glb"],
        "output_blend": paths["blend"],
        "production_v4_untouched": True,
    }
    write_json(paths["metrics"], metrics)

    for mesh in meshes:
        limit_influences(mesh, 4)
    strip_non_production(target, source)
    purge_orphans()
    mixamo_left = [o.name for o in bpy.data.objects if "mixamo" in o.name.lower()]
    if mixamo_left:
        raise RuntimeError("Mixamo objects remain in preview: %s" % mixamo_left)
    idle = bpy.data.actions.get("idle")
    if idle:
        if target.animation_data is None:
            target.animation_data_create()
        target.animation_data.action = idle
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end
    bpy.context.scene.frame_set(frame_start)
    setup_preview_camera(target)
    bpy.ops.export_scene.gltf(
        filepath=paths["glb"],
        export_format="GLB",
        export_animations=True,
        export_skins=True,
        export_materials=True,
        export_apply=False,
    )
    try:
        bpy.ops.wm.save_as_mainfile(filepath=paths["blend"])
    except Exception as exc:
        print("WARN blend save", exc)
    print("SOLVER_V1 %s method=%s class=%s vol=%.3f axis=%.3f len_err=%.4f glb=%s" % (
        character, method, classification, max_vol_ratio, max_axis_ratio, max_len_err, paths["glb"]))
    return metrics


def main():
    args = parse_args()
    if args.dump_rest_only or not args.character:
        dump_rest_authorities()
        if args.dump_rest_only:
            return
    if args.character:
        bake_character(args.character, args.method)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
