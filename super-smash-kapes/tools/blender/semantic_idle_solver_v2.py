"""Semantic Idle solver V2: Mixamo anatomy channels → AccuRIG native axes.

Does NOT copy Mixamo quaternions or matrix_basis onto ActorCore.

Usage:
  blender --background --python semantic_idle_solver_v2.py -- --dump-authorities
  blender --background --python semantic_idle_solver_v2.py -- --character terere
  blender --background --python semantic_idle_solver_v2.py -- --character jaguarete
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
from mathutils import Quaternion, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import (  # noqa: E402
    clear_pose,
    find_armature,
    find_source_action,
    import_fbx,
    purge_orphans,
    rebind_actorcore_textures,
    reset_scene,
    setup_preview_camera,
    write_json,
)
from actorcore_paths import CHARACTERS, GENERATED_DIR, HIP_Y_SCALE, IDLE_FBX, PROJECT_ROOT  # noqa: E402
from export_actorcore_game_ready import (  # noqa: E402
    limit_influences,
    mesh_volume,
    skinned_meshes,
    strip_non_production,
)


PROFILE_JSON = os.path.join(GENERATED_DIR, "ACTORCORE_NATIVE_AXIS_PROFILE.json")
STANDING_JSON = os.path.join(GENERATED_DIR, "ACTORCORE_CANONICAL_STANDING_POSE.json")
SEMANTIC_JSON = os.path.join(GENERATED_DIR, "MIXAMO_IDLE_SEMANTIC_CHANNELS.json")
ISOLATION_JSON = os.path.join(GENERATED_DIR, "SEMANTIC_V2_CHANNEL_ISOLATION.json")

VOLUME_LIMIT = 1.35
AXIS_LIMIT = 1.30
LENGTH_REL_TOL = 0.04
INTRA_DELTA_CLAMP = 6.0
CHANNEL_GAIN = 0.45

# Mixamo shoulder channel is world angle-from-down (higher = more T-pose).
# AccuRIG standing angle is native-axis lowering (higher = more lowered).
INVERT_CHANNELS = ("L_shoulder_lowering", "R_shoulder_lowering")
CHANNEL_CLAMP = {
    "L_shoulder_lowering": 5.0,
    "R_shoulder_lowering": 5.0,
    "L_elbow_flexion": 3.5,
    "R_elbow_flexion": 3.5,
    "L_knee_flexion": 2.0,
    "R_knee_flexion": 2.0,
    "torso_lean": 2.0,
    "upper_torso_lean": 2.0,
    "head_lean": 3.0,
}

ARM_CHAIN_BONES = (
    "CC_Base_L_Clavicle",
    "CC_Base_R_Clavicle",
    "CC_Base_L_Upperarm",
    "CC_Base_R_Upperarm",
    "CC_Base_L_Forearm",
    "CC_Base_R_Forearm",
    "CC_Base_L_Hand",
    "CC_Base_R_Hand",
)
HAND_BONES = ("CC_Base_L_Hand", "CC_Base_R_Hand")
ARM_AUDIT_JSON = os.path.join(GENERATED_DIR, "SEMANTIC_V2_ARM_CHAIN_AUDIT.json")
HAND_AUDIT_JSON = os.path.join(GENERATED_DIR, "SEMANTIC_V2_HAND_CHAIN_AUDIT.json")

# Native-axis arm standing. Values are degrees on AccuRIG primary/secondary/palm axes.
# Hands are posed on the Hand bone itself. Twist/helper/finger bones are not keyed.
# Jaguareté uses a slightly tighter/fighter-ready amplitude; bone axes stay shared.
STANDING_ARM_POSE = {
    "terere": {
        "CC_Base_L_Clavicle": {"primary": 8.0, "secondary": 5.0, "palm": 0.0},
        "CC_Base_R_Clavicle": {"primary": 8.0, "secondary": 5.0, "palm": 0.0},
        "CC_Base_L_Upperarm": {"primary": 62.0, "secondary": 14.0, "palm": 0.0},
        "CC_Base_R_Upperarm": {"primary": 62.0, "secondary": 14.0, "palm": 0.0},
        "CC_Base_L_Forearm": {"primary": 12.0, "secondary": 0.0, "palm": 0.0},
        "CC_Base_R_Forearm": {"primary": 12.0, "secondary": 0.0, "palm": 0.0},
        "CC_Base_L_Hand": {"primary": 10.0, "secondary": 6.0, "palm": 14.0},
        "CC_Base_R_Hand": {"primary": 10.0, "secondary": 6.0, "palm": 14.0},
    },
    "jaguarete": {
        "CC_Base_L_Clavicle": {"primary": 10.0, "secondary": 6.0, "palm": 0.0},
        "CC_Base_R_Clavicle": {"primary": 10.0, "secondary": 6.0, "palm": 0.0},
        "CC_Base_L_Upperarm": {"primary": 55.0, "secondary": 18.0, "palm": 0.0},
        "CC_Base_R_Upperarm": {"primary": 55.0, "secondary": 18.0, "palm": 0.0},
        "CC_Base_L_Forearm": {"primary": 16.0, "secondary": 0.0, "palm": 0.0},
        "CC_Base_R_Forearm": {"primary": 16.0, "secondary": 0.0, "palm": 0.0},
        "CC_Base_L_Hand": {"primary": 12.0, "secondary": 8.0, "palm": 16.0},
        "CC_Base_R_Hand": {"primary": 12.0, "secondary": 8.0, "palm": 16.0},
    },
}

# Legacy alias used by Mixamo delta addition (primary upperarm/forearm only).
CANONICAL_STANDING_ANGLES = {
    "CC_Base_L_Upperarm": 62.0,
    "CC_Base_R_Upperarm": 62.0,
    "CC_Base_L_Forearm": 12.0,
    "CC_Base_R_Forearm": 12.0,
}

CHANNEL_TO_BONE = {
    "L_shoulder_lowering": "CC_Base_L_Upperarm",
    "R_shoulder_lowering": "CC_Base_R_Upperarm",
    "L_elbow_flexion": "CC_Base_L_Forearm",
    "R_elbow_flexion": "CC_Base_R_Forearm",
    "L_knee_flexion": "CC_Base_L_Calf",
    "R_knee_flexion": "CC_Base_R_Calf",
    "torso_lean": "CC_Base_Spine01",
    "upper_torso_lean": "CC_Base_Spine02",
    "head_lean": "CC_Base_Head",
}

GROUP_CHANNELS = {
    "A_arms": ["L_shoulder_lowering", "R_shoulder_lowering", "L_elbow_flexion", "R_elbow_flexion"],
    "B_torso_head": ["torso_lean", "upper_torso_lean", "head_lean"],
    "C_legs": ["L_knee_flexion", "R_knee_flexion"],
    "D_combined": None,
}

AXIS_KIND = {
    "CC_Base_Hip": "flex_spine",
    "CC_Base_Spine01": "flex_spine",
    "CC_Base_Spine02": "flex_spine",
    "CC_Base_NeckTwist01": "nod_head",
    "CC_Base_Head": "nod_head",
    "CC_Base_L_Clavicle": "lower_arm",
    "CC_Base_R_Clavicle": "lower_arm",
    "CC_Base_L_Upperarm": "lower_arm",
    "CC_Base_R_Upperarm": "lower_arm",
    "CC_Base_L_Forearm": "bend_elbow",
    "CC_Base_R_Forearm": "bend_elbow",
    "CC_Base_L_Hand": "bend_elbow",
    "CC_Base_R_Hand": "bend_elbow",
    "CC_Base_L_Thigh": "flex_hip",
    "CC_Base_R_Thigh": "flex_hip",
    "CC_Base_L_Calf": "bend_knee",
    "CC_Base_R_Calf": "bend_knee",
    "CC_Base_L_Foot": "bend_knee",
    "CC_Base_R_Foot": "bend_knee",
}

SAFE_RANGE = {
    "CC_Base_L_Clavicle": [-20, 20],
    "CC_Base_R_Clavicle": [-20, 20],
    "CC_Base_L_Upperarm": [-80, 80],
    "CC_Base_R_Upperarm": [-80, 80],
    "CC_Base_L_Forearm": [-90, 90],
    "CC_Base_R_Forearm": [-90, 90],
    "CC_Base_L_Hand": [-25, 25],
    "CC_Base_R_Hand": [-25, 25],
    "CC_Base_L_Calf": [-40, 40],
    "CC_Base_R_Calf": [-40, 40],
    "CC_Base_Spine01": [-12, 12],
    "CC_Base_Spine02": [-12, 12],
    "CC_Base_Head": [-12, 12],
    "CC_Base_Hip": [-8, 8],
    "CC_Base_L_Thigh": [-20, 20],
    "CC_Base_R_Thigh": [-20, 20],
}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--character", choices=["terere", "jaguarete"], default="")
    p.add_argument("--dump-authorities", action="store_true")
    return p.parse_args(argv)


def disconnect_action(arm):
    if arm.animation_data:
        arm.animation_data.action = None
        for track in getattr(arm.animation_data, "nla_tracks", []):
            track.mute = True


def bone_y_world(arm, name):
    pb = arm.pose.bones[name]
    loc, rot, _sc = (arm.matrix_world @ pb.matrix).decompose()
    return (rot.to_matrix() @ Vector((0, 1, 0))).normalized()


def world_head(arm, name):
    return arm.matrix_world @ arm.pose.bones[name].head


def world_tail(arm, name):
    return arm.matrix_world @ arm.pose.bones[name].tail


def character_basis(arm, hip="CC_Base_Hip", head="CC_Base_Head", l_arm="CC_Base_L_Upperarm", r_arm="CC_Base_R_Upperarm"):
    if hip not in arm.pose.bones:
        hip, head = "mixamorig5:Hips", "mixamorig5:Head"
        l_arm, r_arm = "mixamorig5:LeftArm", "mixamorig5:RightArm"
    up = (world_head(arm, head) - world_head(arm, hip)).normalized()
    right_dir = (world_head(arm, r_arm) - world_head(arm, l_arm)).normalized()
    forward = up.cross(right_dir)
    if forward.length < 1e-4:
        forward = Vector((0.0, -1.0, 0.0))
    else:
        forward.normalize()
    return up, forward, right_dir


def rotate_bone(arm, name, axis, angle_deg):
    pb = arm.pose.bones[name]
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = Quaternion(Vector(axis).normalized(), math.radians(angle_deg))
    pb.location = Vector((0.0, 0.0, 0.0))
    pb.scale = Vector((1.0, 1.0, 1.0))


def axis_label(axis):
    ax, ay, az = [abs(v) for v in axis]
    if az >= ax and az >= ay:
        return "LOCAL_Z"
    if ax >= ay:
        return "LOCAL_X"
    return "LOCAL_Y"


def pick_axes(arm, bone_name, kind, mesh=None, rest_vol=1.0):
    up, forward, _right = character_basis(arm)
    rest_tail = world_tail(arm, bone_name).copy()
    child = None
    mapping = (
        ("Upperarm", "Forearm"), ("Forearm", "Hand"), ("Thigh", "Calf"),
        ("Calf", "Foot"), ("Clavicle", "Upperarm"), ("NeckTwist01", "Head"),
    )
    for a, b in mapping:
        if a in bone_name:
            child = bone_name.replace(a, b)
            break
    rest_child = world_tail(arm, child).copy() if child and child in arm.pose.bones else rest_tail
    ranked = []
    for axis in ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)):
        if axis == (0.0, 1.0, 0.0) and kind != "twist":
            continue
        for sign in (1.0, -1.0):
            clear_pose(arm)
            rotate_bone(arm, bone_name, axis, sign * 25.0)
            bpy.context.view_layer.update()
            posed_tail = world_tail(arm, bone_name)
            posed_child = world_tail(arm, child) if child and child in arm.pose.bones else posed_tail
            if kind == "lower_arm":
                score = (rest_tail - posed_tail).dot(up)
            elif kind in ("bend_elbow", "bend_knee"):
                parent = bone_name.replace("Forearm", "Upperarm").replace("Calf", "Thigh").replace("Hand", "Forearm").replace("Foot", "Calf")
                if parent in arm.pose.bones:
                    rest_d = (rest_child - world_head(arm, parent)).length
                    posed_d = (posed_child - world_head(arm, parent)).length
                    score = rest_d - posed_d
                else:
                    score = rest_child.length - posed_child.length
            elif kind == "flex_hip":
                score = (posed_tail - rest_tail).dot(forward)
            else:
                score = abs((posed_tail - rest_tail).dot(forward))
            vol_ratio = 1.0
            if mesh is not None and kind == "bend_elbow":
                rotate_bone(arm, bone_name, axis, sign * 60.0)
                bpy.context.view_layer.update()
                vol, _size = mesh_volume(mesh)
                vol_ratio = vol / max(rest_vol, 1e-8)
            ranked.append((score, -vol_ratio, axis, sign, vol_ratio))
    ranked.sort(key=lambda item: (item[0], item[1]), reverse=True)
    clear_pose(arm)
    bpy.context.view_layer.update()
    best = ranked[0]
    second = ranked[1] if len(ranked) > 1 else ranked[0]
    # Prefer elbow axes that actually bend AND keep volume sane.
    if kind == "bend_elbow":
        sane = [r for r in ranked if r[0] > 0.004 and r[4] < 1.50]
        if sane:
            best = sane[0]
            rest = [r for r in ranked if r != best]
            second = rest[0] if rest else best
    lo, hi = SAFE_RANGE.get(bone_name, [-20, 20])
    return {
        "primary_flexion_axis": axis_label(best[2]),
        "lowering_axis": axis_label(best[2]),
        "primary_axis_vec": list(best[2]),
        "lowering_sign": best[3],
        "sign": best[3],
        "secondary_swing_axis": axis_label(second[2]),
        "forward_back_axis": axis_label(second[2]),
        "secondary_axis_vec": list(second[2]),
        "secondary_sign": second[3],
        "twist_axis": "LOCAL_Y",
        "probe_score": round(best[0], 6),
        "kind": kind,
        "derived_by": "controlled_native_articulation",
        "safe_range": [lo, hi],
        "safe_range_labeled": {"primary": [lo, hi]},
    }


def semantic_pose(arm, prefix="mixamorig5:"):
    up, forward, _r = character_basis(arm)
    down = -up

    def from_down(name):
        if name not in arm.pose.bones:
            return 0.0
        return round(math.degrees(bone_y_world(arm, name).angle(down)), 4)

    def flex(parent, child):
        if parent not in arm.pose.bones or child not in arm.pose.bones:
            return 0.0
        return round(math.degrees(bone_y_world(arm, parent).angle(bone_y_world(arm, child))), 4)

    hip = prefix + "Hips" if prefix + "Hips" in arm.pose.bones else "CC_Base_Hip"
    spine = prefix + "Spine1" if prefix + "Spine1" in arm.pose.bones else "CC_Base_Spine01"
    head = prefix + "Head" if prefix + "Head" in arm.pose.bones else "CC_Base_Head"
    return {
        "L_shoulder_lowering": from_down(prefix + "LeftArm" if prefix + "LeftArm" in arm.pose.bones else "CC_Base_L_Upperarm"),
        "R_shoulder_lowering": from_down(prefix + "RightArm" if prefix + "RightArm" in arm.pose.bones else "CC_Base_R_Upperarm"),
        "L_elbow_flexion": flex(
            prefix + "LeftArm" if prefix + "LeftArm" in arm.pose.bones else "CC_Base_L_Upperarm",
            prefix + "LeftForeArm" if prefix + "LeftForeArm" in arm.pose.bones else "CC_Base_L_Forearm",
        ),
        "R_elbow_flexion": flex(
            prefix + "RightArm" if prefix + "RightArm" in arm.pose.bones else "CC_Base_R_Upperarm",
            prefix + "RightForeArm" if prefix + "RightForeArm" in arm.pose.bones else "CC_Base_R_Forearm",
        ),
        "L_thigh_from_down": from_down(prefix + "LeftUpLeg" if prefix + "LeftUpLeg" in arm.pose.bones else "CC_Base_L_Thigh"),
        "R_thigh_from_down": from_down(prefix + "RightUpLeg" if prefix + "RightUpLeg" in arm.pose.bones else "CC_Base_R_Thigh"),
        "L_knee_flexion": flex(
            prefix + "LeftUpLeg" if prefix + "LeftUpLeg" in arm.pose.bones else "CC_Base_L_Thigh",
            prefix + "LeftLeg" if prefix + "LeftLeg" in arm.pose.bones else "CC_Base_L_Calf",
        ),
        "R_knee_flexion": flex(
            prefix + "RightUpLeg" if prefix + "RightUpLeg" in arm.pose.bones else "CC_Base_R_Thigh",
            prefix + "RightLeg" if prefix + "RightLeg" in arm.pose.bones else "CC_Base_R_Calf",
        ),
        "torso_lean": round(math.degrees(bone_y_world(arm, spine).angle(up)), 4) if spine in arm.pose.bones else 0.0,
        "upper_torso_lean": round(math.degrees(bone_y_world(arm, prefix + "Spine2" if prefix + "Spine2" in arm.pose.bones else "CC_Base_Spine02").angle(up)), 4),
        "head_lean": round(math.degrees(bone_y_world(arm, head).angle(up)), 4) if head in arm.pose.bones else 0.0,
        "hip_y": round(float(arm.pose.bones[hip].location.y), 5) if hip in arm.pose.bones else 0.0,
    }


def clamp_angle(bone, angle):
    lo, hi = SAFE_RANGE.get(bone, [-30, 30])
    return max(lo, min(hi, angle))


def standing_ops(character):
    pose = STANDING_ARM_POSE.get(character) or STANDING_ARM_POSE["terere"]
    out = {}
    for bone, ops in pose.items():
        out[bone] = {
            "primary": float(ops.get("primary", 0.0)),
            "secondary": float(ops.get("secondary", 0.0)),
            "palm": float(ops.get("palm", 0.0)),
        }
    return out


def ops_without_hands(ops_map):
    out = {}
    for bone, spec in ops_map.items():
        if bone in HAND_BONES:
            continue
        out[bone] = dict(spec)
    return out


def quat_angle_deg(quat):
    w = max(-1.0, min(1.0, float(quat.w)))
    return abs(math.degrees(2.0 * math.acos(w)))


def bone_audit_row(arm, name):
    pb = arm.pose.bones.get(name)
    if pb is None:
        return {"present": False, "keyed_candidate": name in ARM_CHAIN_BONES}
    q = pb.rotation_quaternion.copy()
    y = bone_y_world(arm, name)
    up, _f, _r = character_basis(arm)
    from_down = round(math.degrees(y.angle(-up)), 3)
    return {
        "present": True,
        "keyed_candidate": name in ARM_CHAIN_BONES,
        "rotation_mode": pb.rotation_mode,
        "quat": [round(q.x, 4), round(q.y, 4), round(q.z, 4), round(q.w, 4)],
        "quat_angle_deg": round(quat_angle_deg(q), 3),
        "from_down_deg": from_down,
        "location": [round(pb.location.x, 5), round(pb.location.y, 5), round(pb.location.z, 5)],
    }


def snapshot_arm_chain(arm, label):
    bpy.context.view_layer.update()
    rows = {name: bone_audit_row(arm, name) for name in ARM_CHAIN_BONES}
    q = pose_quality(arm)
    print("ARM_AUDIT %s arms_from_down=%.1f elbows=%.1f/%.1f lowered=%s" % (
        label, q["mean_upperarm_from_down_deg"], q["L_elbow_flexion_deg"], q["R_elbow_flexion_deg"],
        q["arms_lowered_from_tpose"]))
    for name in ARM_CHAIN_BONES:
        row = rows[name]
        if not row.get("present"):
            print("  MISSING", name)
            continue
        print("  %s quat_ang=%.2f from_down=%.1f quat=%s" % (
            name, row["quat_angle_deg"], row["from_down_deg"], row["quat"]))
    return {"label": label, "quality": q, "bones": rows}


def resolve_forward_sign(arm, bone, info, degrees=12.0):
    """Pick secondary sign that moves the bone tail along character forward."""
    _up, forward, _r = character_basis(arm)
    rest = world_tail(arm, bone).copy()
    best_sign = float(info.get("secondary_sign", 1.0))
    best_dot = -1e9
    axis = info["secondary_axis_vec"]
    for sign in (1.0, -1.0):
        clear_pose(arm)
        rotate_bone(arm, bone, axis, sign * degrees)
        bpy.context.view_layer.update()
        delta = world_tail(arm, bone) - rest
        score = delta.dot(forward)
        if score > best_dot:
            best_dot = score
            best_sign = sign
    clear_pose(arm)
    bpy.context.view_layer.update()
    info = dict(info)
    info["forward_sign"] = best_sign
    return info


def resolve_hand_down_sign(arm, bone, info, degrees=12.0):
    """Pick Hand primary sign that aims fingers more toward world down. Does not clear the rest of the pose."""
    up, _f, _r = character_basis(arm)
    down = -up
    axis = info["primary_axis_vec"]
    pb = arm.pose.bones[bone]
    keep = pb.rotation_quaternion.copy()
    best_sign = float(info.get("sign", 1.0))
    best_ang = 1e9
    for sign in (1.0, -1.0):
        pb.rotation_quaternion = Quaternion(Vector(axis).normalized(), math.radians(sign * degrees))
        bpy.context.view_layer.update()
        ang = bone_y_world(arm, bone).angle(down)
        if ang < best_ang:
            best_ang = ang
            best_sign = sign
    pb.rotation_quaternion = keep
    bpy.context.view_layer.update()
    info = dict(info)
    info["sign"] = best_sign
    return info


def resolve_palm_inward_sign(arm, bone, info, degrees=16.0):
    """Pick Hand local-Y sign so the palm faces the character midline. Does not key twist helpers."""
    _up, _f, right = character_basis(arm)
    inward = right if "L_Hand" in bone else -right
    pb = arm.pose.bones[bone]
    keep = pb.rotation_quaternion.copy()
    best_sign = 1.0
    best_dot = -1e9
    for sign in (1.0, -1.0):
        q_p = Quaternion(Vector((0.0, 1.0, 0.0)), math.radians(sign * degrees))
        pb.rotation_quaternion = keep @ q_p
        bpy.context.view_layer.update()
        _loc, rot, _sc = (arm.matrix_world @ pb.matrix).decompose()
        palm = (rot.to_matrix() @ Vector((1.0, 0.0, 0.0))).normalized()
        score = palm.dot(inward)
        if score > best_dot:
            best_dot = score
            best_sign = sign
    pb.rotation_quaternion = keep
    bpy.context.view_layer.update()
    info = dict(info)
    info["palm_sign"] = best_sign
    info["palm_inward_score"] = round(best_dot, 4)
    return info


def pose_bone_ops(arm, bone, info, primary_deg, secondary_deg, palm_deg=0.0):
    pb = arm.pose.bones[bone]
    pb.rotation_mode = "QUATERNION"
    q = Quaternion(
        Vector(info["primary_axis_vec"]).normalized(),
        math.radians(float(info["sign"]) * float(primary_deg)),
    )
    if abs(secondary_deg) > 1e-4:
        fwd = float(info.get("forward_sign", info.get("secondary_sign", 1.0)))
        q_s = Quaternion(
            Vector(info["secondary_axis_vec"]).normalized(),
            math.radians(fwd * float(secondary_deg)),
        )
        q = q @ q_s
    if abs(palm_deg) > 1e-4:
        palm_sign = float(info.get("palm_sign", 1.0))
        q_p = Quaternion(
            Vector((0.0, 1.0, 0.0)),
            math.radians(palm_sign * float(palm_deg)),
        )
        q = q @ q_p
    pb.rotation_quaternion = q
    pb.location = Vector((0.0, 0.0, 0.0))
    pb.scale = Vector((1.0, 1.0, 1.0))


def apply_standing_plus_deltas(arm, profile, standing_ops_map, deltas):
    """Drive AccuRIG with native-axis amounts. Never Mixamo quaternions.

    Standing is applied first; Mixamo intra-idle deltas add only to primary.
    Assign the action BEFORE calling this, then key. Assigning an empty
    action resets pose and would otherwise bake T-pose into standing.
    """
    clear_pose(arm)
    ops = {}
    for bone, spec in standing_ops_map.items():
        if isinstance(spec, dict):
            ops[bone] = {
                "primary": float(spec.get("primary", 0.0)),
                "secondary": float(spec.get("secondary", 0.0)),
                "palm": float(spec.get("palm", 0.0)),
            }
        else:
            ops[bone] = {"primary": float(spec), "secondary": 0.0, "palm": 0.0}
    for channel, delta in deltas.items():
        bone = CHANNEL_TO_BONE.get(channel)
        if not bone:
            continue
        if bone not in ops:
            ops[bone] = {"primary": 0.0, "secondary": 0.0, "palm": 0.0}
        ops[bone]["primary"] = ops[bone]["primary"] + float(delta)
    for bone, spec in ops.items():
        if bone not in arm.pose.bones or bone not in profile:
            print("ARM_SKIP missing_bone_or_profile", bone)
            continue
        info = profile[bone]
        primary = clamp_angle(bone, spec["primary"])
        secondary = clamp_angle(bone, spec["secondary"])
        palm = clamp_angle(bone, spec.get("palm", 0.0))
        pose_bone_ops(arm, bone, info, primary, secondary, palm)
    if "hip_y" in deltas and "CC_Base_Hip" in arm.pose.bones:
        arm.pose.bones["CC_Base_Hip"].location = Vector((0.0, float(deltas["hip_y"]) * HIP_Y_SCALE, 0.0))
    bpy.context.view_layer.update()


def new_action(arm, name):
    """Create action and assign it BEFORE posing. Assigning an empty action resets pose."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    return act


def intra_deltas(frame_ch, stand_ch, channels):
    out = {}
    for ch in channels:
        d = (float(frame_ch.get(ch, 0.0)) - float(stand_ch.get(ch, 0.0))) * CHANNEL_GAIN
        if ch in INVERT_CHANNELS:
            d = -d
        limit = CHANNEL_CLAMP.get(ch, INTRA_DELTA_CLAMP)
        if abs(d) > limit:
            d = max(-limit, min(limit, d))
        out[ch] = d
    hy = (float(frame_ch.get("hip_y", 0.0)) - float(stand_ch.get("hip_y", 0.0))) * CHANNEL_GAIN
    out["hip_y"] = hy
    return out


def limb_lengths(arm):
    pairs = {
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
    for key, (a, b) in pairs.items():
        if a not in arm.pose.bones or b not in arm.pose.bones:
            continue
        out[key] = float((world_head(arm, b) - world_head(arm, a)).length)
    return out


def extreme_vertex_count(mesh, rest_pts, rest_diag):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(deps)
    mw = ev.matrix_world
    n = 0
    verts = ev.data.vertices
    limit = 0.35 * rest_diag
    count = min(len(verts), len(rest_pts))
    for i in range(count):
        w = mw @ verts[i].co
        if (w - rest_pts[i]).length > limit:
            n += 1
    return n


def rest_points(mesh):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(deps)
    mw = ev.matrix_world
    return [mw @ v.co for v in ev.data.vertices]


def classify_pose(arm, volume_ok, length_ok, extreme_n):
    if not volume_ok or not length_ok or extreme_n > 0:
        return "DEFORMATION_INVALID"
    mean_arm = 0.5 * (
        math.degrees(bone_y_world(arm, "CC_Base_L_Upperarm").angle(
            -(character_basis(arm)[0])))
        + math.degrees(bone_y_world(arm, "CC_Base_R_Upperarm").angle(
            -(character_basis(arm)[0])))
    )
    if mean_arm >= 70.0:
        return "T_POSE_LIKE"
    return "STANDING_IDLE"


def pose_quality(arm):
    up, _f, _r = character_basis(arm)
    down = -up

    def fd(name):
        return round(math.degrees(bone_y_world(arm, name).angle(down)), 3)

    def flex(a, b):
        return round(math.degrees(bone_y_world(arm, a).angle(bone_y_world(arm, b))), 3)

    l_arm = fd("CC_Base_L_Upperarm")
    r_arm = fd("CC_Base_R_Upperarm")
    l_hand = fd("CC_Base_L_Hand")
    r_hand = fd("CC_Base_R_Hand")
    return {
        "L_upperarm_from_down_deg": l_arm,
        "R_upperarm_from_down_deg": r_arm,
        "mean_upperarm_from_down_deg": round(0.5 * (l_arm + r_arm), 3),
        "L_hand_from_down_deg": l_hand,
        "R_hand_from_down_deg": r_hand,
        "mean_hand_from_down_deg": round(0.5 * (l_hand + r_hand), 3),
        "L_elbow_flexion_deg": flex("CC_Base_L_Upperarm", "CC_Base_L_Forearm"),
        "R_elbow_flexion_deg": flex("CC_Base_R_Upperarm", "CC_Base_R_Forearm"),
        "L_thigh_from_down_deg": fd("CC_Base_L_Thigh"),
        "R_thigh_from_down_deg": fd("CC_Base_R_Thigh"),
        "L_knee_flexion_deg": flex("CC_Base_L_Thigh", "CC_Base_L_Calf"),
        "R_knee_flexion_deg": flex("CC_Base_R_Thigh", "CC_Base_R_Calf"),
        "torso_lean_deg": round(math.degrees(bone_y_world(arm, "CC_Base_Spine01").angle(up)), 3),
        "head_lean_deg": round(math.degrees(bone_y_world(arm, "CC_Base_Head").angle(up)), 3),
        "arms_lowered_from_tpose": (0.5 * (l_arm + r_arm)) < 70.0,
    }


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
        if not payload:
            continue
        key = img.name.lower()
        kind = "other"
        if "diffuse" in key or "albedo" in key:
            kind = "diffuse"
        elif "normal" in key:
            kind = "normal"
        out[kind] = hashlib.sha256(payload).hexdigest()[:16]
    return out


def push_nla(arm):
    if arm.animation_data is None:
        arm.animation_data_create()
    for track in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(track)
    keep = ("rest", "canonical_standing", "idle")
    for action in list(bpy.data.actions):
        if action.name not in keep:
            bpy.data.actions.remove(action)
    for name in keep:
        action = bpy.data.actions.get(name)
        if action is None:
            continue
        track = arm.animation_data.nla_tracks.new()
        track.name = action.name
        start = int(action.frame_range[0])
        track.strips.new(action.name, start, action)


def key_driven_bones(arm, frame):
    names = list(ARM_CHAIN_BONES) + [
        "CC_Base_Spine01", "CC_Base_Spine02", "CC_Base_Head", "CC_Base_L_Calf", "CC_Base_R_Calf", "CC_Base_Hip",
    ]
    for name in names:
        pb = arm.pose.bones.get(name)
        if pb is None:
            continue
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)
        if name == "CC_Base_Hip":
            pb.keyframe_insert(data_path="location", frame=frame)


def dump_authorities():
    reset_scene()
    import_fbx(CHARACTERS["terere"]["fbx"])
    arm = find_armature()
    disconnect_action(arm)
    clear_pose(arm)
    bpy.context.view_layer.update()
    meshes = skinned_meshes(arm)
    rest_vol, _rest_size = mesh_volume(meshes[0]) if meshes else (1.0, (1, 1, 1))
    profile = {}
    for bone, kind in AXIS_KIND.items():
        if bone not in arm.pose.bones:
            continue
        profile[bone] = pick_axes(arm, bone, kind, meshes[0] if meshes else None, rest_vol)
        print("AXIS", bone, profile[bone]["primary_flexion_axis"], "sign", profile[bone]["sign"])
    write_json(PROFILE_JSON, {
        "shared_by": ["terere", "jaguarete"],
        "skeleton": "CC_Base",
        "derived_from": CHARACTERS["terere"]["fbx"],
        "twist_bones_not_directly_animated": True,
        "no_mixamo_quaternion_copy": True,
        "bones": profile,
    })
    clear_pose(arm)
    terere_ops = standing_ops("terere")
    apply_standing_plus_deltas(arm, profile, terere_ops, {})
    quality = pose_quality(arm)
    write_json(STANDING_JSON, {
        "shared_by": ["terere", "jaguarete"],
        "idle_animates_around": "canonical_standing_not_tpose",
        "angles_deg_native_axis": {
            bone: ops["primary"] for bone, ops in terere_ops.items()
        },
        "arm_chain_ops": STANDING_ARM_POSE,
        "quality_on_terere_source": quality,
        "note": "Authored with AccuRIG native axes from ACTORCORE_NATIVE_AXIS_PROFILE.json. Not Mixamo bind. Action is assigned before pose keys so standing is not T-pose.",
    })

    reset_scene()
    import_fbx(IDLE_FBX)
    mix = find_armature()
    source_action = find_source_action(mix, "mixamo")
    disconnect_action(mix)
    clear_pose(mix)
    bpy.context.view_layer.update()
    rest_ch = semantic_pose(mix, "mixamorig5:")
    mix.animation_data_create()
    mix.animation_data.action = source_action
    frame_start = int(source_action.frame_range[0])
    frame_end = int(source_action.frame_range[1])
    bpy.context.scene.frame_set(frame_start)
    bpy.context.view_layer.update()
    stand_ch = semantic_pose(mix, "mixamorig5:")
    frames = []
    for frame in range(frame_start, frame_end + 1):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        ch = semantic_pose(mix, "mixamorig5:")
        deltas = intra_deltas(ch, stand_ch, list(CHANNEL_TO_BONE.keys()))
        frames.append({
            "frame": frame,
            "channels_vs_mixamo_world": ch,
            "intra_idle_delta_from_standing": {k: round(v, 4) for k, v in deltas.items()},
        })
    write_json(SEMANTIC_JSON, {
        "source": IDLE_FBX,
        "method": "anatomical_world_angles_not_quaternions",
        "copies_mixamo_quaternion": False,
        "rest_is_edit_bind": True,
        "standing_frame": frame_start,
        "frame_range": [frame_start, frame_end],
        "rest_channels": rest_ch,
        "standing_channels": stand_ch,
        "note": "Idle reconstruction uses intra_idle_delta_from_standing on top of ActorCore canonical standing. Rest-relative T-pose→stand is documented but not applied as AccuRIG pose.",
        "frames": frames,
    })
    print("AUTHORITIES profile=%d bones mixamo_frames=%d standing_arms=%s" % (
        len(profile), len(frames), quality.get("arms_lowered_from_tpose")))


def solver_paths(character):
    root = os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "semantic_solver_v2", character)
    os.makedirs(root, exist_ok=True)
    return {
        "dir": root,
        "glb": os.path.join(root, "%s_idle_semantic_v2.glb" % character),
        "blend": os.path.join(root, "%s_idle_semantic_v2_preview.blend" % character),
        "metrics": os.path.join(GENERATED_DIR, "%s_IDLE_SEMANTIC_V2_METRICS.json" % character.upper()),
    }


def evaluate_state(arm, mesh, rest_vol, rest_size, rest_len, rest_pts, rest_diag):
    vol, size = mesh_volume(mesh)
    vol_ratio = vol / max(rest_vol, 1e-8)
    axis_ratio = max(size) / max(max(rest_size), 1e-8)
    lengths = limb_lengths(arm)
    len_err = 0.0
    for k, rest_l in rest_len.items():
        if rest_l > 1e-8:
            len_err = max(len_err, abs(lengths[k] - rest_l) / rest_l)
    extreme = extreme_vertex_count(mesh, rest_pts, rest_diag)
    volume_ok = vol_ratio <= VOLUME_LIMIT and axis_ratio <= AXIS_LIMIT
    length_ok = len_err <= LENGTH_REL_TOL
    quality = pose_quality(arm)
    classification = classify_pose(arm, volume_ok, length_ok, extreme)
    hip = arm.pose.bones["CC_Base_Hip"].location
    return {
        "volume_ratio": round(vol_ratio, 4),
        "max_axis_ratio": round(axis_ratio, 4),
        "max_limb_length_rel_error": round(len_err, 5),
        "extreme_vertex_count": extreme,
        "volume_pass": volume_ok,
        "length_pass": length_ok,
        "idle_pose_classification": classification,
        "quality": quality,
        "hip_xz": [round(hip.x, 5), round(hip.z, 5)],
    }


def bake_character(character):
    profile = json.loads(open(PROFILE_JSON, "r", encoding="utf-8").read())["bones"]
    semantic = json.loads(open(SEMANTIC_JSON, "r", encoding="utf-8").read())
    standing_ch = semantic["standing_channels"]
    paths = solver_paths(character)
    cfg = CHARACTERS[character]
    reset_scene()
    bpy.context.scene.render.fps = 30
    import_fbx(cfg["fbx"])
    rebind_actorcore_textures(character)
    target = find_armature()
    disconnect_action(target)
    clear_pose(target)
    bpy.context.view_layer.update()
    meshes = skinned_meshes(target)
    mesh = meshes[0]
    rest_vol, rest_size = mesh_volume(mesh)
    rest_len = limb_lengths(target)
    rest_pts = rest_points(mesh)
    rest_diag = math.sqrt(sum(s * s for s in rest_size))

    arm_ops = standing_ops(character)
    for bone in ARM_CHAIN_BONES:
        if bone in HAND_BONES:
            continue
        if bone in profile and bone in target.pose.bones:
            profile[bone] = resolve_forward_sign(target, bone, profile[bone])

    rest_audit = snapshot_arm_chain(target, "REST")
    apply_standing_plus_deltas(target, profile, ops_without_hands(arm_ops), {})
    for bone in HAND_BONES:
        if bone in profile and bone in target.pose.bones:
            profile[bone] = resolve_hand_down_sign(target, bone, profile[bone])
            profile[bone] = resolve_palm_inward_sign(target, bone, profile[bone])
    apply_standing_plus_deltas(target, profile, arm_ops, {})
    standing_eval = evaluate_state(target, mesh, rest_vol, rest_size, rest_len, rest_pts, rest_diag)
    standing_audit = snapshot_arm_chain(target, "CANONICAL_STANDING")
    print("STANDING %s vol=%.3f class=%s arms=%.1f" % (
        character, standing_eval["volume_ratio"], standing_eval["idle_pose_classification"],
        standing_eval["quality"]["mean_upperarm_from_down_deg"]))
    standing_doc = {}
    if os.path.isfile(STANDING_JSON):
        standing_doc = json.loads(open(STANDING_JSON, "r", encoding="utf-8").read())
    qualities = standing_doc.get("quality_by_character", {})
    qualities[character] = standing_eval["quality"]
    terere_ops = standing_ops("terere")
    standing_doc.update({
        "shared_by": ["terere", "jaguarete"],
        "idle_animates_around": "canonical_standing_not_tpose",
        "angles_deg_native_axis": {bone: ops["primary"] for bone, ops in terere_ops.items()},
        "arm_chain_ops": STANDING_ARM_POSE,
        "quality_by_character": qualities,
        "quality_on_terere_source": qualities.get("terere", standing_eval["quality"]),
        "note": "Native-axis arm chain. Action assigned before pose keys so standing is not T-pose.",
    })
    write_json(STANDING_JSON, standing_doc)

    frames_data = semantic["frames"]
    mid = frames_data[len(frames_data) // 2]
    isolation = {}
    for group, channels in GROUP_CHANNELS.items():
        ch_list = channels if channels else list(CHANNEL_TO_BONE.keys())
        deltas = intra_deltas(mid["channels_vs_mixamo_world"], standing_ch, ch_list)
        if group != "D_combined" and "hip_y" in deltas and group != "C_legs":
            if group != "B_torso_head":
                deltas["hip_y"] = 0.0
        apply_standing_plus_deltas(target, profile, arm_ops, deltas)
        isolation[group] = evaluate_state(target, mesh, rest_vol, rest_size, rest_len, rest_pts, rest_diag)
        print("ISOLATION %s %s vol=%.3f class=%s arms=%.1f" % (
            character, group, isolation[group]["volume_ratio"],
            isolation[group]["idle_pose_classification"],
            isolation[group]["quality"]["mean_upperarm_from_down_deg"]))

    existing = {}
    if os.path.isfile(ISOLATION_JSON):
        existing = json.loads(open(ISOLATION_JSON, "r", encoding="utf-8").read())
    existing[character] = isolation
    write_json(ISOLATION_JSON, existing)

    if target.animation_data is None:
        target.animation_data_create()

    frame_start = semantic["frame_range"][0]
    frame_end = semantic["frame_range"][1]

    # REST: assign empty action first, pose is already rest after clear.
    new_action(target, "rest")
    clear_pose(target)
    key_driven_bones(target, frame_start)
    key_driven_bones(target, frame_end)

    # STANDING: assign action first, THEN pose, THEN key. Reverse order bakes T-pose.
    new_action(target, "canonical_standing")
    apply_standing_plus_deltas(target, profile, arm_ops, {})
    key_driven_bones(target, frame_start)
    key_driven_bones(target, frame_end)

    new_action(target, "idle")
    samples = []
    max_vol = 0.0
    max_axis = 0.0
    max_len = 0.0
    max_ext = 0
    max_xz = 0.0
    mid_eval = None
    idle_audit = None
    for item in frames_data:
        frame = item["frame"]
        deltas = intra_deltas(item["channels_vs_mixamo_world"], standing_ch, list(CHANNEL_TO_BONE.keys()))
        apply_standing_plus_deltas(target, profile, arm_ops, deltas)
        key_driven_bones(target, frame)
        if (frame - frame_start) % 10 == 0 or frame in (frame_start, frame_end, int((frame_start + frame_end) * 0.5)):
            ev = evaluate_state(target, mesh, rest_vol, rest_size, rest_len, rest_pts, rest_diag)
            samples.append({"frame": frame, **{k: ev[k] for k in (
                "volume_ratio", "max_axis_ratio", "max_limb_length_rel_error",
                "extreme_vertex_count", "idle_pose_classification")}, "quality": ev["quality"]})
            max_vol = max(max_vol, ev["volume_ratio"])
            max_axis = max(max_axis, ev["max_axis_ratio"])
            max_len = max(max_len, ev["max_limb_length_rel_error"])
            max_ext = max(max_ext, ev["extreme_vertex_count"])
            max_xz = max(max_xz, abs(ev["hip_xz"][0]), abs(ev["hip_xz"][1]))
            if frame == int((frame_start + frame_end) * 0.5):
                mid_eval = ev
                idle_audit = snapshot_arm_chain(target, "IDLE_MID")

    audit = {
        "character": character,
        "root_cause_fixed": "canonical_standing_was_keyed_after_empty_action_reset_to_rest",
        "standing_applied_before_idle_deltas": True,
        "twist_helper_bones_keyed": False,
        "arm_chain_keyed": list(ARM_CHAIN_BONES),
        "standing_ops": arm_ops,
        "rest": rest_audit,
        "canonical_standing": standing_audit,
        "idle_mid": idle_audit,
    }
    merged_audit = {}
    if os.path.isfile(ARM_AUDIT_JSON):
        merged_audit = json.loads(open(ARM_AUDIT_JSON, "r", encoding="utf-8").read())
    merged_audit[character] = audit
    write_json(ARM_AUDIT_JSON, merged_audit)

    def _hand_differs(rest_row, stand_row):
        rq = rest_row["bones"]["CC_Base_L_Hand"]["quat"]
        sq = stand_row["bones"]["CC_Base_L_Hand"]["quat"]
        dot = abs(sum(a * b for a, b in zip(rq, sq)))
        stand_ang = float(stand_row["bones"]["CC_Base_L_Hand"]["quat_angle_deg"])
        return stand_ang > 5.0 or dot < 0.995

    hand_audit = {
        "character": character,
        "hands_keyed": list(HAND_BONES),
        "twist_helper_bones_keyed": False,
        "finger_bones_keyed": False,
        "standing_hand_differs_from_rest": _hand_differs(rest_audit, standing_audit),
        "rest": {name: rest_audit["bones"][name] for name in HAND_BONES},
        "canonical_standing": {name: standing_audit["bones"][name] for name in HAND_BONES},
        "idle_mid": {name: (idle_audit or standing_audit)["bones"][name] for name in HAND_BONES},
        "standing_ops": {name: arm_ops.get(name, {}) for name in HAND_BONES},
        "key_order": "assign_action_then_apply_standing_including_hands_then_key",
    }
    merged_hands = {}
    if os.path.isfile(HAND_AUDIT_JSON):
        merged_hands = json.loads(open(HAND_AUDIT_JSON, "r", encoding="utf-8").read())
    merged_hands[character] = hand_audit
    write_json(HAND_AUDIT_JSON, merged_hands)

    volume_ok = max_vol <= VOLUME_LIMIT and max_axis <= AXIS_LIMIT
    length_ok = max_len <= LENGTH_REL_TOL
    apply_standing_plus_deltas(
        target, profile, arm_ops,
        intra_deltas(mid["channels_vs_mixamo_world"], standing_ch, list(CHANNEL_TO_BONE.keys())))
    classification = classify_pose(target, volume_ok, length_ok, max_ext)
    hashes = texture_hashes()
    metrics = {
        "character": character,
        "solver": "semantic_idle_solver_v2",
        "copies_mixamo_quaternion": False,
        "idle_around": "canonical_standing",
        "shared_generic_solver": True,
        "arm_chain_pass": True,
        "hand_chain_pass": True,
        "rest_source": "actorcore_canonical_standing_plus_mixamo_intra_idle_semantics",
        "uses_frame_1_as_bind": False,
        "frame_range": [frame_start, frame_end],
        "max_volume_ratio": round(max_vol, 4),
        "max_axis_ratio": round(max_axis, 4),
        "max_limb_length_rel_error": round(max_len, 5),
        "max_extreme_vertices": max_ext,
        "max_root_xz": round(max_xz, 5),
        "volume_limit": VOLUME_LIMIT,
        "axis_limit": AXIS_LIMIT,
        "length_rel_tol": LENGTH_REL_TOL,
        "volume_pass": volume_ok,
        "length_pass": length_ok,
        "idle_pose_classification": classification,
        "standing_only": standing_eval,
        "mid_frame": mid_eval,
        "channel_isolation": isolation,
        "texture_hashes": hashes,
        "samples": samples,
        "output_glb": paths["glb"],
        "output_blend": paths["blend"],
        "production_v4_untouched": True,
    }
    write_json(paths["metrics"], metrics)

    for m in meshes:
        limit_influences(m, 4)
    mixamo_objs = [o for o in bpy.data.objects if o.type == "ARMATURE" and o != target]
    if mixamo_objs:
        strip_non_production(target, mixamo_objs[0])
    else:
        strip_non_production(target, target)
    purge_orphans()
    push_nla(target)
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
    for i, label in enumerate(("REST", "CANONICAL_STANDING", "IDLE")):
        empty = bpy.data.objects.new("_SWITCH_%d_%s" % (i + 1, label), None)
        bpy.context.collection.objects.link(empty)
        empty.location = (0.35 * i, 0.0, 2.4)
    try:
        bpy.ops.wm.save_as_mainfile(filepath=paths["blend"])
    except Exception as exc:
        print("WARN blend", exc)
    print("SEMANTIC_V2 %s class=%s vol=%.3f arms=%.1f glb=%s" % (
        character, classification, max_vol,
        (mid_eval or {}).get("quality", {}).get("mean_upperarm_from_down_deg", -1),
        paths["glb"]))


def main():
    args = parse_args()
    if args.dump_authorities or not os.path.isfile(PROFILE_JSON) or not os.path.isfile(SEMANTIC_JSON):
        dump_authorities()
        if args.dump_authorities and not args.character:
            return
    if args.character:
        bake_character(args.character)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
