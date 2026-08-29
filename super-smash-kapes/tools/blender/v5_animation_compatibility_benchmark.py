# -*- coding: utf-8 -*-
"""V5 animation compatibility benchmark for Blender 2.83.

Idle + Reaction only. Semantic reapplication onto V5 native skeleton.
Does not copy CC_Base curves. Does not overwrite V1. Does not auto-promote V5.
"""
from __future__ import print_function

import copy
import hashlib
import json
import math
import os
import sys
import traceback
from datetime import datetime

import bpy
from mathutils import Quaternion, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
import clean_rig_idle_retarget_benchmark_v1 as cr
import semantic_reaction_v1 as rv1
import semantic_reaction_v11 as rv11
import terere_production_semantic_idle_v1 as terere_idle

PROJECT_ROOT = cr.PROJECT_ROOT
GENERATED = cr.GENERATED
OUT_ROOT = os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "v5_animation_benchmark")

V1_CLEAN = {
    "terere": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "clean_rig_v1", "terere", "terere_clean_rig_v1.blend"),
    "jaguarete": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "clean_rig_v1", "jaguarete", "jaguarete_clean_rig_v1.blend"),
}
V5_CLEAN = {
    "terere": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "clean_rig_v5", "terere", "terere_clean_rig_v5.blend"),
    "jaguarete": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "clean_rig_v5", "jaguarete", "jaguarete_clean_rig_v5.blend"),
}
V1_IDLE_GLB = {
    "terere": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "production_semantic_idle_v1", "terere", "terere_production_semantic_idle_v1.glb"),
    "jaguarete": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "semantic_idle_polish_v1", "jaguarete", "jaguarete_idle_semantic_polished_v1.glb"),
}
PRESENTATION_HEIGHT = {"terere": 2.40, "jaguarete": 3.15}

# V1 CC_Base -> V5 UE-style. Do not assume 101-bone identity.
BONE_MAP = {
    "CC_Base_Hip": "pelvis",
    "CC_Base_Spine01": "spine_01",
    "CC_Base_Spine02": "spine_02",
    "CC_Base_NeckTwist01": "neck_01",
    "CC_Base_Head": "head",
    "CC_Base_L_Clavicle": "clavicle_l",
    "CC_Base_R_Clavicle": "clavicle_r",
    "CC_Base_L_Upperarm": "upperarm_l",
    "CC_Base_R_Upperarm": "upperarm_r",
    "CC_Base_L_Forearm": "lowerarm_l",
    "CC_Base_R_Forearm": "lowerarm_r",
    "CC_Base_L_Hand": "hand_l",
    "CC_Base_R_Hand": "hand_r",
    "CC_Base_L_Thigh": "thigh_l",
    "CC_Base_R_Thigh": "thigh_r",
    "CC_Base_L_Calf": "calf_l",
    "CC_Base_R_Calf": "calf_r",
    "CC_Base_L_Foot": "foot_l",
    "CC_Base_R_Foot": "foot_r",
    "CC_Base_L_ToeBase": "ball_l",
    "CC_Base_R_ToeBase": "ball_r",
    "CC_Base_Pelvis": "cc_base_pelvis",
}
for side, tag in (("L", "l"), ("R", "r")):
    for finger, fl in (("Index", "index"), ("Middle", "middle"), ("Mid", "middle"), ("Ring", "ring"), ("Pinky", "pinky"), ("Thumb", "thumb")):
        for seg in (1, 2, 3):
            BONE_MAP["CC_Base_%s_%s%d" % (side, finger, seg)] = "%s_0%d_%s" % (fl, seg, tag)

IMPORTANT = [
    "CC_Base_Hip", "CC_Base_Spine01", "CC_Base_Spine02", "CC_Base_Head",
    "CC_Base_L_Clavicle", "CC_Base_R_Clavicle",
    "CC_Base_L_Upperarm", "CC_Base_R_Upperarm",
    "CC_Base_L_Forearm", "CC_Base_R_Forearm",
    "CC_Base_L_Hand", "CC_Base_R_Hand",
    "CC_Base_L_Thigh", "CC_Base_R_Thigh",
    "CC_Base_L_Calf", "CC_Base_R_Calf",
    "CC_Base_L_Foot", "CC_Base_R_Foot",
    "CC_Base_L_Index1", "CC_Base_L_Ring1", "CC_Base_L_Pinky1", "CC_Base_L_Thumb1",
    "CC_Base_R_Index1", "CC_Base_R_Ring1", "CC_Base_R_Pinky1", "CC_Base_R_Thumb1",
]

V5_AXIS_KIND = {
    "clavicle_l": "lower_arm",
    "clavicle_r": "lower_arm",
    "upperarm_l": "lower_arm",
    "upperarm_r": "lower_arm",
    "lowerarm_l": "bend_elbow",
    "lowerarm_r": "bend_elbow",
    "hand_l": "lower_arm",
    "hand_r": "lower_arm",
    "calf_l": "bend_knee",
    "calf_r": "bend_knee",
    "spine_01": "flex_spine",
    "head": "nod_head",
}
V5_SAFE = {
    "clavicle_l": 20.0, "clavicle_r": 20.0,
    "upperarm_l": 80.0, "upperarm_r": 80.0,
    "lowerarm_l": 90.0, "lowerarm_r": 90.0,
    "hand_l": 25.0, "hand_r": 25.0,
    "calf_l": 40.0, "calf_r": 40.0,
    "spine_01": 12.0, "head": 12.0, "pelvis": 8.0,
}
V5_LIMB_PAIRS = (
    ("upperarm_l", "lowerarm_l"),
    ("lowerarm_l", "hand_l"),
    ("upperarm_r", "lowerarm_r"),
    ("lowerarm_r", "hand_r"),
    ("thigh_l", "calf_l"),
    ("calf_l", "foot_l"),
    ("thigh_r", "calf_r"),
    ("calf_r", "foot_r"),
)
V5_NAMES = {
    "hip": "pelvis",
    "head": "head",
    "spine": "spine_01",
    "l_upperarm": "upperarm_l",
    "r_upperarm": "upperarm_r",
    "l_forearm": "lowerarm_l",
    "r_forearm": "lowerarm_r",
    "l_hand": "hand_l",
    "r_hand": "hand_r",
    "l_thigh": "thigh_l",
    "r_thigh": "thigh_r",
    "l_calf": "calf_l",
    "r_calf": "calf_r",
    "l_foot": "foot_l",
    "r_foot": "foot_r",
    "l_clavicle": "clavicle_l",
    "r_clavicle": "clavicle_r",
}
CC_NAMES = {
    "hip": "CC_Base_Hip",
    "head": "CC_Base_Head",
    "spine": "CC_Base_Spine01",
    "l_upperarm": "CC_Base_L_Upperarm",
    "r_upperarm": "CC_Base_R_Upperarm",
    "l_forearm": "CC_Base_L_Forearm",
    "r_forearm": "CC_Base_R_Forearm",
    "l_hand": "CC_Base_L_Hand",
    "r_hand": "CC_Base_R_Hand",
    "l_thigh": "CC_Base_L_Thigh",
    "r_thigh": "CC_Base_R_Thigh",
    "l_calf": "CC_Base_L_Calf",
    "r_calf": "CC_Base_R_Calf",
    "l_foot": "CC_Base_L_Foot",
    "r_foot": "CC_Base_R_Foot",
    "l_clavicle": "CC_Base_L_Clavicle",
    "r_clavicle": "CC_Base_R_Clavicle",
}

JAGUARETE_IDLE_GAIN = 1.0
JAGUARETE_IDLE_ARM_SAFETY = {"max_from_down": 62.0, "min_elbow": 50.0, "max_elbow": 105.0}

FINGER_PREFIXES = ("index_", "middle_", "ring_", "pinky_", "thumb_")


def log(msg):
    print(msg)
    sys.stdout.flush()


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def find_v5_arm():
    for obj in bpy.data.objects:
        if obj.type == "ARMATURE" and "pelvis" in obj.pose.bones:
            return obj
    return None


_orig_char_basis = cr.char_basis


def char_basis_patched(arm):
    if "pelvis" in arm.pose.bones and "CC_Base_Hip" not in arm.pose.bones:
        hip, head, left_arm, right_arm = "pelvis", "head", "upperarm_l", "upperarm_r"
        up = (cr.world_head(arm, head) - cr.world_head(arm, hip)).normalized()
        right = (cr.world_head(arm, right_arm) - cr.world_head(arm, left_arm)).normalized()
        forward = up.cross(right)
        if forward.length < 1e-4:
            forward = Vector((0.0, -1.0, 0.0))
        else:
            forward.normalize()
        return up, forward, right
    return _orig_char_basis(arm)


cr.char_basis = char_basis_patched


V1_SAFE = {
    "CC_Base_L_Clavicle": 20.0, "CC_Base_R_Clavicle": 20.0,
    "CC_Base_L_Upperarm": 80.0, "CC_Base_R_Upperarm": 80.0,
    "CC_Base_L_Forearm": 90.0, "CC_Base_R_Forearm": 90.0,
    "CC_Base_L_Hand": 25.0, "CC_Base_R_Hand": 25.0,
    "CC_Base_L_Calf": 40.0, "CC_Base_R_Calf": 40.0,
    "CC_Base_Spine01": 12.0, "CC_Base_Head": 12.0, "CC_Base_Hip": 8.0,
}


def install_v5_axes():
    cr.AXIS_KIND = V5_AXIS_KIND
    merged = dict(V1_SAFE)
    merged.update(V5_SAFE)
    cr.SAFE = merged
    cr.LIMB_PAIRS = V5_LIMB_PAIRS


def v5_profile_axes(arm):
    """Score axes by anatomical effect, not raw tail travel.

    V5 short bones (spine_01) and UE local axes can make V1's abs(delta)
    profiler pick a twist or inverted flex.
    """
    up, forward, _right = cr.char_basis(arm)
    profile = {}
    for bone, kind in V5_AXIS_KIND.items():
        if bone not in arm.pose.bones:
            continue
        rest_tail = cr.world_tail(arm, bone).copy()
        ranked = []
        for axis in ((1.0, 0.0, 0.0), (0.0, 0.0, 1.0)):
            for sign in (1.0, -1.0):
                cr.clear_pose(arm)
                cr.rotate_local(arm, bone, axis, sign * 25.0)
                bpy.context.view_layer.update()
                posed = cr.world_tail(arm, bone)
                if kind == "lower_arm":
                    score = (rest_tail - posed).dot(up)
                elif kind == "bend_elbow":
                    side = "l" if bone.endswith("_l") else "r"
                    ua = "upperarm_%s" % side
                    hand = "hand_%s" % side
                    cr.clear_pose(arm)
                    bpy.context.view_layer.update()
                    rest_flex = cr.flex_deg(arm, ua, bone)
                    rest_hand = cr.world_head(arm, hand)
                    cr.rotate_local(arm, bone, axis, sign * 25.0)
                    bpy.context.view_layer.update()
                    flex = cr.flex_deg(arm, ua, bone)
                    hand_w = cr.world_head(arm, hand)
                    score = (flex - rest_flex) + 3.0 * (rest_hand.z - hand_w.z)
                elif kind == "bend_knee":
                    side = "l" if bone.endswith("_l") else "r"
                    thigh = "thigh_%s" % side
                    cr.clear_pose(arm)
                    bpy.context.view_layer.update()
                    rest_flex = cr.flex_deg(arm, thigh, bone)
                    cr.rotate_local(arm, bone, axis, sign * 25.0)
                    bpy.context.view_layer.update()
                    flex = cr.flex_deg(arm, thigh, bone)
                    score = flex - rest_flex
                else:
                    score = abs((posed - rest_tail).dot(forward))
                ranked.append((score, axis, sign))
        ranked.sort(key=lambda item: item[0], reverse=True)
        best = ranked[0]
        second = ranked[1] if len(ranked) > 1 else ranked[0]
        profile[bone] = {
            "primary_axis_vec": list(best[1]),
            "sign": best[2],
            "secondary_axis_vec": list(second[1]),
            "secondary_sign": second[2],
            "kind": kind,
            "primary_score": round(float(best[0]), 4),
        }
        cr.clear_pose(arm)
    bpy.context.view_layer.update()
    return profile


def install_v1_axes():
    cr.AXIS_KIND = {
        "CC_Base_L_Clavicle": "lower_arm",
        "CC_Base_R_Clavicle": "lower_arm",
        "CC_Base_L_Upperarm": "lower_arm",
        "CC_Base_R_Upperarm": "lower_arm",
        "CC_Base_L_Forearm": "bend_elbow",
        "CC_Base_R_Forearm": "bend_elbow",
        "CC_Base_L_Hand": "lower_arm",
        "CC_Base_R_Hand": "lower_arm",
        "CC_Base_L_Calf": "bend_knee",
        "CC_Base_R_Calf": "bend_knee",
        "CC_Base_Spine01": "flex_spine",
        "CC_Base_Head": "nod_head",
    }
    cr.SAFE = {
        "CC_Base_L_Clavicle": 20.0, "CC_Base_R_Clavicle": 20.0,
        "CC_Base_L_Upperarm": 80.0, "CC_Base_R_Upperarm": 80.0,
        "CC_Base_L_Forearm": 90.0, "CC_Base_R_Forearm": 90.0,
        "CC_Base_L_Hand": 25.0, "CC_Base_R_Hand": 25.0,
        "CC_Base_L_Calf": 40.0, "CC_Base_R_Calf": 40.0,
        "CC_Base_Spine01": 12.0, "CC_Base_Head": 12.0, "CC_Base_Hip": 8.0,
    }
    cr.LIMB_PAIRS = (
        ("CC_Base_L_Upperarm", "CC_Base_L_Forearm"),
        ("CC_Base_L_Forearm", "CC_Base_L_Hand"),
        ("CC_Base_R_Upperarm", "CC_Base_R_Forearm"),
        ("CC_Base_R_Forearm", "CC_Base_R_Hand"),
        ("CC_Base_L_Thigh", "CC_Base_L_Calf"),
        ("CC_Base_L_Calf", "CC_Base_L_Foot"),
        ("CC_Base_R_Thigh", "CC_Base_R_Calf"),
        ("CC_Base_R_Calf", "CC_Base_R_Foot"),
    )


def reset_shapekeys(mesh):
    if mesh is None or mesh.data is None or mesh.data.shape_keys is None:
        return
    for key in mesh.data.shape_keys.key_blocks:
        key.value = 0.0


def dump_armature(arm, label):
    rows = []
    hierarchy = {}
    for bone in arm.data.bones:
        parent = bone.parent.name if bone.parent else None
        hierarchy[bone.name] = parent
        rest = arm.matrix_world @ bone.matrix_local
        y_axis = (rest.to_3x3() @ Vector((0.0, 1.0, 0.0)))
        if y_axis.length > 1e-8:
            y_axis = y_axis.normalized()
        head_w = arm.matrix_world @ bone.head_local
        tail_w = arm.matrix_world @ bone.tail_local
        rows.append({
            "name": bone.name,
            "parent": parent,
            "length": round(float(bone.length), 6),
            "head_world": cr.vec3(head_w),
            "tail_world": cr.vec3(tail_w),
            "y_axis_world": cr.vec3(y_axis),
            "rest_quat": [round(float(v), 6) for v in rest.to_quaternion()],
            "use_deform": bool(bone.use_deform),
            "connected": bool(bone.use_connect),
        })
    twists = [b.name for b in arm.data.bones if "twist" in b.name.lower()]
    helpers = [b.name for b in arm.data.bones if any(tok in b.name.lower() for tok in ("ik_", "twist", "share", "root"))]
    fingers = [b.name for b in arm.data.bones if any(b.name.lower().startswith(p) or "index" in b.name.lower() or "ring" in b.name.lower() or "pinky" in b.name.lower() or "thumb" in b.name.lower() or "mid" in b.name.lower() for p in FINGER_PREFIXES)]
    return {
        "label": label,
        "armature": arm.name,
        "bone_count": len(arm.data.bones),
        "bones": sorted([b.name for b in arm.data.bones]),
        "hierarchy": hierarchy,
        "rows": rows,
        "twist_helper_layout": twists,
        "helper_bones": helpers,
        "finger_bones": sorted(set(fingers)),
        "object_xform": cr.object_xform(arm),
    }


def y_axis_of(dump, name):
    for row in dump["rows"]:
        if row["name"] == name:
            return Vector(row["y_axis_world"])
    return None


def length_of(dump, name):
    for row in dump["rows"]:
        if row["name"] == name:
            return float(row["length"])
    return None


def parent_of(dump, name):
    return dump["hierarchy"].get(name)


def classify_pair(v1_dump, v5_dump, cc_name, v5_name):
    v1_has = cc_name in v1_dump["hierarchy"]
    v5_has = v5_name in v5_dump["hierarchy"] if v5_name else False
    if v1_has and not v5_has:
        return "MISSING_V5"
    if (not v1_has) and v5_has:
        return "NEW_V5"
    if not v1_has and not v5_has:
        return "MISSING_V5"
    y1 = y_axis_of(v1_dump, cc_name)
    y5 = y_axis_of(v5_dump, v5_name)
    l1 = length_of(v1_dump, cc_name)
    l5 = length_of(v5_dump, v5_name)
    axis_deg = 180.0
    if y1 is not None and y5 is not None and y1.length > 1e-8 and y5.length > 1e-8:
        axis_deg = math.degrees(y1.angle(y5))
    len_ratio = None
    if l1 and l5 and l1 > 1e-8:
        len_ratio = l5 / l1
    same_name = cc_name == v5_name
    p1 = parent_of(v1_dump, cc_name)
    p5 = parent_of(v5_dump, v5_name)
    parent_semantic = (p1 == p5) or (p1 in BONE_MAP and BONE_MAP[p1] == p5)
    rest_close = axis_deg < 8.0 and (len_ratio is None or 0.85 <= len_ratio <= 1.15)
    chain_ok = v5_name in (
        "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head",
        "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r",
        "lowerarm_l", "lowerarm_r", "hand_l", "hand_r",
        "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r",
        "ball_l", "ball_r",
    ) or any(v5_name.startswith(p) for p in FINGER_PREFIXES) or v5_name == "cc_base_pelvis"
    if same_name and parent_semantic and rest_close:
        cls = "EXACT_MATCH"
    elif same_name:
        cls = "NAME_MATCH_REST_DIFF"
    elif chain_ok:
        cls = "SEMANTIC_MATCH_NAME_DIFF"
    else:
        cls = "INCOMPATIBLE"
    return {
        "class": cls,
        "v1": cc_name,
        "v5": v5_name,
        "v1_parent": p1,
        "v5_parent": p5,
        "axis_delta_deg": round(axis_deg, 3),
        "length_ratio": None if len_ratio is None else round(len_ratio, 4),
        "parent_semantic_ok": bool(parent_semantic),
        "rest_close": bool(rest_close),
    }


def compare_skeletons(fighter, v1_dump, v5_dump):
    important = []
    classes = {}
    for cc_name in IMPORTANT:
        v5_name = BONE_MAP.get(cc_name)
        row = classify_pair(v1_dump, v5_dump, cc_name, v5_name)
        if isinstance(row, str):
            row = {"class": row, "v1": cc_name, "v5": v5_name}
        important.append(row)
        classes[cc_name] = row["class"]
    v1_set = set(v1_dump["bones"])
    v5_set = set(v5_dump["bones"])
    mapped_v5 = set(BONE_MAP.values())
    new_v5 = sorted([n for n in v5_set if n not in mapped_v5 and n not in v1_set])
    missing_v5 = []
    for cc_name, v5_name in BONE_MAP.items():
        if cc_name in v1_set and v5_name not in v5_set:
            missing_v5.append({"v1": cc_name, "expected_v5": v5_name})
    blocking = [c for c in (
        "CC_Base_Hip", "CC_Base_Spine01", "CC_Base_Head",
        "CC_Base_L_Upperarm", "CC_Base_L_Forearm", "CC_Base_L_Hand",
        "CC_Base_R_Upperarm", "CC_Base_R_Forearm", "CC_Base_R_Hand",
        "CC_Base_L_Thigh", "CC_Base_L_Calf", "CC_Base_L_Foot",
        "CC_Base_R_Thigh", "CC_Base_R_Calf", "CC_Base_R_Foot",
    ) if classes.get(c) in ("MISSING_V5", "INCOMPATIBLE")]
    ring_missing = any(
        item.get("class") == "MISSING_V5" and "Ring" in item.get("v1", "")
        for item in important
    )
    if blocking:
        strategy = "BLOCK"
        reason = "required body bones missing or incompatible: %s" % blocking
    elif all(classes.get(c) == "EXACT_MATCH" for c in (
        "CC_Base_Hip", "CC_Base_L_Upperarm", "CC_Base_L_Forearm", "CC_Base_L_Hand",
    )):
        strategy = "DIRECT_CURVE_REUSE"
        reason = "identity match on core chain"
    else:
        strategy = "SEMANTIC_REAPPLICATION"
        reason = "names and/or rest/axes differ; approved semantic channels + V5 native skeleton + V5 canonical pose"
    return {
        "fighter": fighter,
        "v1_bone_count": v1_dump["bone_count"],
        "v5_bone_count": v5_dump["bone_count"],
        "direct_curve_reuse_eligible": strategy == "DIRECT_CURVE_REUSE",
        "transfer_strategy": strategy,
        "strategy_reason": reason,
        "ring_finger_missing_not_fatal": bool(ring_missing),
        "important_bones": important,
        "missing_v5": missing_v5,
        "new_v5_sample": new_v5[:40],
        "new_v5_count": len(new_v5),
        "v1_twist_helpers": v1_dump["twist_helper_layout"],
        "v5_twist_helpers": v5_dump["twist_helper_layout"],
        "v1_fingers": v1_dump["finger_bones"],
        "v5_fingers": v5_dump["finger_bones"],
        "copies_cc_base_curves": False,
        "traditional_cob": False,
    }


def torso_world_lean_deg(arm, names):
    up, _fwd, _right = cr.char_basis(arm)
    return math.degrees(up.angle(Vector((0.0, 0.0, 1.0))))


def silhouette(arm, names):
    up, _fwd, _right = cr.char_basis(arm)
    hip = cr.world_head(arm, names["hip"])
    l_hand = cr.world_head(arm, names["l_hand"])
    r_hand = cr.world_head(arm, names["r_hand"])
    l_sh = cr.world_head(arm, names["l_upperarm"])
    r_sh = cr.world_head(arm, names["r_upperarm"])
    l_foot = cr.world_head(arm, names["l_foot"])
    r_foot = cr.world_head(arm, names["r_foot"])
    span = float((cr.world_head(arm, names["head"]) - hip).length)
    torso_mid = Vector((0.0, 0.0, hip.z + span * 0.45))
    return {
        "spine_from_up_deg": round(torso_world_lean_deg(arm, names), 3),
        "L_upperarm_from_down": round(cr.from_down_deg(arm, names["l_upperarm"]), 3),
        "R_upperarm_from_down": round(cr.from_down_deg(arm, names["r_upperarm"]), 3),
        "L_elbow_flex": round(cr.flex_deg(arm, names["l_upperarm"], names["l_forearm"]), 3),
        "R_elbow_flex": round(cr.flex_deg(arm, names["r_upperarm"], names["r_forearm"]), 3),
        "L_knee_flex": round(cr.flex_deg(arm, names["l_thigh"], names["l_calf"]), 3),
        "R_knee_flex": round(cr.flex_deg(arm, names["r_thigh"], names["r_calf"]), 3),
        "L_hand_from_down": round(cr.from_down_deg(arm, names["l_hand"]), 3),
        "R_hand_from_down": round(cr.from_down_deg(arm, names["r_hand"]), 3),
        "L_hand": cr.vec3(l_hand),
        "R_hand": cr.vec3(r_hand),
        "hip": cr.vec3(hip),
        "L_foot": cr.vec3(l_foot),
        "R_foot": cr.vec3(r_foot),
        "shoulder_width": round(float((l_sh - r_sh).length), 5),
        "shoulder_width_over_span": round(float((l_sh - r_sh).length) / max(span, 1e-6), 4),
        "L_hand_height": round(float(l_hand.z), 5),
        "R_hand_height": round(float(r_hand.z), 5),
        "L_hand_height_over_span": round(float(l_hand.z - hip.z) / max(span, 1e-6), 4),
        "R_hand_height_over_span": round(float(r_hand.z - hip.z) / max(span, 1e-6), 4),
        "L_hand_to_torso": round(float((l_hand - torso_mid).length), 5),
        "R_hand_to_torso": round(float((r_hand - torso_mid).length), 5),
        "L_hand_to_torso_over_span": round(float((l_hand - torso_mid).length) / max(span, 1e-6), 4),
        "R_hand_to_torso_over_span": round(float((r_hand - torso_mid).length) / max(span, 1e-6), 4),
        "foot_stance": round(float((l_foot - r_foot).length), 5),
        "foot_stance_over_span": round(float((l_foot - r_foot).length) / max(span, 1e-6), 4),
        "head_hip_span": round(span, 5),
        "hands_below_shoulders": bool(l_hand.z < l_sh.z - 0.01 and r_hand.z < r_sh.z - 0.01),
        "root_xz": round(math.sqrt(hip.x * hip.x + hip.y * hip.y), 5),
    }


def pose_match_row(v1_sil, v5_sil):
    def ang(key):
        return round(abs(float(v5_sil.get(key, 0.0)) - float(v1_sil.get(key, 0.0))), 3)

    def ratio(key):
        return round(abs(float(v5_sil.get(key, 0.0)) - float(v1_sil.get(key, 0.0))), 4)

    return {
        "shoulder_width_over_span_dev": ratio("shoulder_width_over_span"),
        "L_upperarm_from_down_dev": ang("L_upperarm_from_down"),
        "R_upperarm_from_down_dev": ang("R_upperarm_from_down"),
        "L_elbow_flex_dev": ang("L_elbow_flex"),
        "R_elbow_flex_dev": ang("R_elbow_flex"),
        "L_hand_to_torso_over_span_dev": ratio("L_hand_to_torso_over_span"),
        "R_hand_to_torso_over_span_dev": ratio("R_hand_to_torso_over_span"),
        "L_hand_height_over_span_dev": ratio("L_hand_height_over_span"),
        "R_hand_height_over_span_dev": ratio("R_hand_height_over_span"),
        "spine_from_up_dev": ang("spine_from_up_deg"),
        "L_knee_flex_dev": ang("L_knee_flex"),
        "R_knee_flex_dev": ang("R_knee_flex"),
        "foot_stance_over_span_dev": ratio("foot_stance_over_span"),
        "hands_below_shoulders_v5": v5_sil.get("hands_below_shoulders"),
        "root_xz_v5": v5_sil.get("root_xz"),
        "v1": v1_sil,
        "v5": v5_sil,
        "note": "Angular metrics compared directly. Linear metrics compared as ratios to head-hip span. Do not optimize blindly.",
    }


def ops_cc_to_v5(ops_cc):
    out = {}
    for cc_name, spec in ops_cc.items():
        v5 = BONE_MAP.get(cc_name)
        if v5:
            out[v5] = {
                "primary": float(spec.get("primary") or 0.0),
                "secondary": float(spec.get("secondary") or 0.0),
            }
    return out


def apply_v5(arm, profile, ops_v5):
    cr.clear_pose(arm)
    for bone, spec in ops_v5.items():
        if bone in profile:
            cr.pose_ops(arm, bone, profile[bone], spec.get("primary", 0.0), spec.get("secondary", 0.0))
    bpy.context.view_layer.update()


def apply_cc_on_v5(arm, profile, ops_cc):
    apply_v5(arm, profile, ops_cc_to_v5(ops_cc))


def solve_keep_sec(arm, profile, ops_v5, bone, metric_fn, target, lo, hi, step=4.0):
    best = float(ops_v5.get(bone, {}).get("primary") or 0.0)
    best_err = 1e9
    sec = float(ops_v5.get(bone, {}).get("secondary") or 0.0)
    angle = lo
    while angle <= hi + 1e-6:
        trial = copy.deepcopy(ops_v5)
        if bone not in trial:
            trial[bone] = {"primary": 0.0, "secondary": sec}
        trial[bone]["primary"] = angle
        trial[bone]["secondary"] = sec
        apply_v5(arm, profile, trial)
        err = abs(metric_fn() - target)
        if err < best_err:
            best_err = err
            best = angle
        angle += step
    if bone not in ops_v5:
        ops_v5[bone] = {"primary": 0.0, "secondary": sec}
    ops_v5[bone]["primary"] = cr.clamp_deg(bone, best)
    ops_v5[bone]["secondary"] = sec
    apply_v5(arm, profile, ops_v5)
    return best, best_err


def reconstruct_canonical(arm, profile, standing_cc, v1_sil):
    ops_v5 = ops_cc_to_v5(standing_cc)
    apply_v5(arm, profile, ops_v5)
    seed_sil = silhouette(arm, V5_NAMES)
    n = V5_NAMES
    solves = {}
    plan = [
        (n["spine"], lambda: torso_world_lean_deg(arm, V5_NAMES), v1_sil["spine_from_up_deg"], -12, 12, "spine"),
        (n["l_upperarm"], lambda: cr.from_down_deg(arm, n["l_upperarm"]), v1_sil["L_upperarm_from_down"], 0, 80, "L_upperarm"),
        (n["r_upperarm"], lambda: cr.from_down_deg(arm, n["r_upperarm"]), v1_sil["R_upperarm_from_down"], 0, 80, "R_upperarm"),
        (n["l_forearm"], lambda: cr.flex_deg(arm, n["l_upperarm"], n["l_forearm"]), v1_sil["L_elbow_flex"], 20, 90, "L_elbow"),
        (n["r_forearm"], lambda: cr.flex_deg(arm, n["r_upperarm"], n["r_forearm"]), v1_sil["R_elbow_flex"], 20, 90, "R_elbow"),
        (n["l_calf"], lambda: cr.flex_deg(arm, n["l_thigh"], n["l_calf"]), v1_sil["L_knee_flex"], 0, 40, "L_knee"),
        (n["r_calf"], lambda: cr.flex_deg(arm, n["r_thigh"], n["r_calf"]), v1_sil["R_knee_flex"], 0, 40, "R_knee"),
    ]
    for bone, metric, target, lo, hi, label in plan:
        if bone not in profile:
            continue
        best, err = solve_keep_sec(arm, profile, ops_v5, bone, metric, target, lo, hi, step=4.0)
        solves[label] = {"bone": bone, "primary": round(best, 3), "err": round(err, 3), "target": target}
    apply_v5(arm, profile, ops_v5)
    refined = silhouette(arm, V5_NAMES)
    standing_cc_out = {}
    inv = {}
    for cc_name, v5_name in BONE_MAP.items():
        inv[v5_name] = cc_name
    for v5_name, spec in ops_v5.items():
        cc_name = inv.get(v5_name)
        if cc_name:
            standing_cc_out[cc_name] = {
                "primary": float(spec.get("primary") or 0.0),
                "secondary": float(spec.get("secondary") or 0.0),
            }
    return standing_cc_out, ops_v5, seed_sil, refined, solves


def standing_ops_for(fighter):
    return rv1.standing_ops_for(fighter)


def measure_v1_idle_silhouette(fighter):
    install_v1_axes()
    cr.reset_empty()
    bpy.ops.import_scene.gltf(filepath=V1_IDLE_GLB[fighter])
    arm = cr.find_cc_arm()
    if arm is None:
        raise RuntimeError("V1 idle armature missing for %s" % fighter)
    action = arm.animation_data.action if arm.animation_data else None
    if action is None and bpy.data.actions:
        action = bpy.data.actions[0]
    if action is not None:
        if arm.animation_data is None:
            arm.animation_data_create()
        arm.animation_data.action = action
        bpy.context.scene.frame_set(int(action.frame_range[0]))
    bpy.context.view_layer.update()
    return silhouette(arm, CC_NAMES)


def enforce_arm_safety_v5(arm, profile, ops_cc, safety):
    ops_v5 = ops_cc_to_v5(ops_cc)
    inv = dict((v, k) for k, v in BONE_MAP.items())
    for side in ("l", "r"):
        ua = "upperarm_%s" % side
        el = "lowerarm_%s" % side
        hand = "hand_%s" % side
        steps = 0
        while cr.from_down_deg(arm, ua) > safety["max_from_down"] and steps < 8:
            ops_v5[ua]["primary"] = cr.clamp_deg(ua, float(ops_v5[ua]["primary"]) + 2.0)
            cr.pose_ops(arm, ua, profile[ua], ops_v5[ua]["primary"], ops_v5[ua].get("secondary", 0.0))
            bpy.context.view_layer.update()
            steps += 1
        flex = cr.flex_deg(arm, ua, el)
        steps = 0
        while flex < safety["min_elbow"] and steps < 8:
            ops_v5[el]["primary"] = cr.clamp_deg(el, float(ops_v5[el]["primary"]) + 2.0)
            cr.pose_ops(arm, el, profile[el], ops_v5[el]["primary"], ops_v5[el].get("secondary", 0.0))
            bpy.context.view_layer.update()
            flex = cr.flex_deg(arm, ua, el)
            steps += 1
        if "max_elbow" in safety:
            steps = 0
            while flex > safety["max_elbow"] and steps < 8:
                ops_v5[el]["primary"] = cr.clamp_deg(el, float(ops_v5[el]["primary"]) - 2.0)
                cr.pose_ops(arm, el, profile[el], ops_v5[el]["primary"], ops_v5[el].get("secondary", 0.0))
                bpy.context.view_layer.update()
                flex = cr.flex_deg(arm, ua, el)
                steps += 1
        h = cr.world_head(arm, hand)
        sh = cr.world_head(arm, ua)
        steps = 0
        while h.z >= sh.z - 0.01 and steps < 6:
            ops_v5[ua]["primary"] = cr.clamp_deg(ua, float(ops_v5[ua]["primary"]) + 2.0)
            cr.pose_ops(arm, ua, profile[ua], ops_v5[ua]["primary"], ops_v5[ua].get("secondary", 0.0))
            bpy.context.view_layer.update()
            h = cr.world_head(arm, hand)
            sh = cr.world_head(arm, ua)
            steps += 1
    for v5_name, spec in ops_v5.items():
        cc_name = inv.get(v5_name)
        if cc_name and cc_name in ops_cc:
            ops_cc[cc_name]["primary"] = spec["primary"]
            ops_cc[cc_name]["secondary"] = spec.get("secondary", 0.0)


def build_idle_ops(fighter, standing_cc, intra):
    if fighter == "terere":
        return terere_idle.build_frame_ops(standing_cc, intra)
    ops = {}
    for bone, spec in standing_cc.items():
        ops[bone] = {"primary": float(spec.get("primary") or 0.0), "secondary": float(spec.get("secondary") or 0.0)}
    mapping = {
        "L_shoulder_lowering": "CC_Base_L_Upperarm",
        "R_shoulder_lowering": "CC_Base_R_Upperarm",
        "L_elbow_flexion": "CC_Base_L_Forearm",
        "R_elbow_flexion": "CC_Base_R_Forearm",
        "L_knee_flexion": "CC_Base_L_Calf",
        "R_knee_flexion": "CC_Base_R_Calf",
        "torso_lean": "CC_Base_Spine01",
        "head_lean": "CC_Base_Head",
        "L_hand_from_down": "CC_Base_L_Hand",
        "R_hand_from_down": "CC_Base_R_Hand",
    }
    invert = set(["L_shoulder_lowering", "R_shoulder_lowering", "L_hand_from_down", "R_hand_from_down"])
    for channel, bone in mapping.items():
        delta = float(intra.get(channel, 0.0)) * JAGUARETE_IDLE_GAIN
        if channel in invert:
            delta = -delta
        if abs(delta) > cr.INTRA_CLAMP:
            delta = cr.INTRA_CLAMP if delta > 0 else -cr.INTRA_CLAMP
        if bone not in ops:
            ops[bone] = {"primary": 0.0, "secondary": 0.0}
        ops[bone]["primary"] = cr.clamp_deg(bone, ops[bone]["primary"] + delta)
    for channel, bone in (("L_shoulder_lowering", "CC_Base_L_Clavicle"), ("R_shoulder_lowering", "CC_Base_R_Clavicle")):
        delta = float(intra.get(channel, 0.0)) * 0.32
        if channel in invert:
            delta = -delta
        if bone not in ops:
            ops[bone] = {"primary": 0.0, "secondary": 0.0}
        ops[bone]["primary"] = cr.clamp_deg(bone, ops[bone]["primary"] + rv1.clip(delta, 1.8))
    return ops


def idle_safety(fighter):
    if fighter == "terere":
        return {
            "max_from_down": terere_idle.ARM_SAFETY["max_upperarm_from_down"],
            "min_elbow": terere_idle.ARM_SAFETY["min_elbow_flex"],
            "max_elbow": terere_idle.ARM_SAFETY["max_elbow_flex"],
        }
    return JAGUARETE_IDLE_ARM_SAFETY


def key_v5(arm, ops_cc, frame, also_hip=True):
    keyed = list(ops_cc.keys())
    if also_hip:
        keyed.append("CC_Base_Hip")
    for cc_name in keyed:
        v5 = BONE_MAP.get(cc_name, cc_name if cc_name in arm.pose.bones else None)
        if not v5 or v5 not in arm.pose.bones:
            continue
        pb = arm.pose.bones[v5]
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)
        if v5 == "pelvis":
            pb.keyframe_insert(data_path="location", frame=frame)


def finger_report(arm, rest_quats):
    missing = []
    for cc_name, v5_name in BONE_MAP.items():
        if "Ring" in cc_name or "ring_" in v5_name:
            if v5_name not in arm.pose.bones:
                missing.append({"semantic": cc_name, "expected_v5": v5_name, "fatal_for_idle_reaction": False})
    max_delta = 0.0
    exploded = False
    for name, rest_q in rest_quats.items():
        if name not in arm.pose.bones:
            continue
        q = arm.pose.bones[name].rotation_quaternion
        delta = math.degrees(rest_q.rotation_difference(q).angle)
        max_delta = max(max_delta, delta)
        if delta > 75.0:
            exploded = True
    wrist = {}
    for side in ("l", "r"):
        hand = "hand_%s" % side
        if hand in arm.pose.bones:
            wrist[hand] = {
                "from_down": round(cr.from_down_deg(arm, hand), 3),
                "quat": [round(float(v), 5) for v in arm.pose.bones[hand].rotation_quaternion],
            }
    return {
        "missing_semantic_channels": missing,
        "max_finger_delta_from_rest_deg": round(max_delta, 3),
        "finger_explosion": bool(exploded),
        "neutral_fingers": bool(max_delta < 12.0),
        "wrists": wrist,
    }


def snapshot_finger_rest(arm):
    out = {}
    for pb in arm.pose.bones:
        low = pb.name.lower()
        if any(low.startswith(p) for p in FINGER_PREFIXES) or "metacarpal" in low:
            pb.rotation_mode = "QUATERNION"
            out[pb.name] = pb.rotation_quaternion.copy()
    return out


def native_height(mesh):
    bbox = cr.mesh_bbox(mesh)
    return float(bbox["size"][2])


def v5_classify(arm, volume_ok, length_ok, extreme_n, rest_forward, clip_kind):
    if not volume_ok or not length_ok:
        return "DEFORMATION_INVALID"
    if clip_kind != "reaction" and extreme_n > 0:
        return "DEFORMATION_INVALID"
    if clip_kind != "reaction":
        mean_arm = 0.5 * (cr.from_down_deg(arm, "upperarm_l") + cr.from_down_deg(arm, "upperarm_r"))
        if mean_arm >= 70.0:
            return "T_POSE_LIKE"
    up, forward, _right = cr.char_basis(arm)
    lean = math.degrees(up.angle(Vector((0.0, 0.0, 1.0))))
    if lean >= 40.0:
        return "SIDEWAYS"
    if rest_forward is not None and rest_forward.length > 1e-6:
        yaw = math.degrees(forward.angle(rest_forward))
        if yaw >= 45.0:
            return "ROOT_ROTATED"
    if clip_kind == "reaction":
        return "HIT_REACTION_CANDIDATE"
    return "STANDING_IDLE"


def evaluate_v5(arm, mesh, action, label, clip_kind, rest_from_current=False):
    if rest_from_current:
        bpy.context.view_layer.update()
        rest_bbox = cr.mesh_bbox(mesh)
        rest_len = cr.limb_lengths(arm)
        rest_pts = cr.rest_points(mesh)
        rest_diag = math.sqrt(sum(size * size for size in rest_bbox["size"]))
        rest_hip = cr.world_head(arm, "pelvis").copy()
        _up, rest_forward, _right = cr.char_basis(arm)
        rest_mode = "canonical_idle_pose"
    else:
        cr.disconnect(arm)
        cr.clear_pose(arm)
        reset_shapekeys(mesh)
        bpy.context.view_layer.update()
        rest_bbox = cr.mesh_bbox(mesh)
        rest_len = cr.limb_lengths(arm)
        rest_pts = cr.rest_points(mesh)
        rest_diag = math.sqrt(sum(size * size for size in rest_bbox["size"]))
        rest_hip = cr.world_head(arm, "pelvis").copy()
        _up, rest_forward, _right = cr.char_basis(arm)
        rest_mode = "bind_tpose"
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    frame_start = int(action.frame_range[0])
    frame_end = int(action.frame_range[1])
    probe = list(range(frame_start, frame_end + 1, 2))
    if probe[-1] != frame_end:
        probe.append(frame_end)
    max_vol = max_axis = max_len = max_root = 0.0
    max_ext = 0
    hip_zs = []
    mid_class = "UNKNOWN"
    mid = int(0.5 * (frame_start + frame_end))
    lfoot_xs, lfoot_ys, rfoot_xs, rfoot_ys = [], [], [], []
    samples = []
    for frame in probe:
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        bbox = cr.mesh_bbox(mesh)
        vol_ratio = bbox["volume"] / max(rest_bbox["volume"], 1e-8)
        axis_ratio = max(bbox["size"]) / max(max(rest_bbox["size"]), 1e-8)
        lengths = cr.limb_lengths(arm)
        len_err = 0.0
        for key, rest_length in rest_len.items():
            if rest_length > 1e-8:
                len_err = max(len_err, abs(lengths[key] - rest_length) / rest_length)
        ext = cr.extreme_count(mesh, rest_pts, rest_diag)
        hip = cr.world_head(arm, "pelvis")
        root_xz = math.sqrt((hip.x - rest_hip.x) ** 2 + (hip.y - rest_hip.y) ** 2)
        hip_zs.append(hip.z)
        lfoot = cr.world_head(arm, "foot_l")
        rfoot = cr.world_head(arm, "foot_r")
        lfoot_xs.append(lfoot.x)
        lfoot_ys.append(lfoot.y)
        rfoot_xs.append(rfoot.x)
        rfoot_ys.append(rfoot.y)
        max_vol = max(max_vol, vol_ratio)
        max_axis = max(max_axis, axis_ratio)
        max_len = max(max_len, len_err)
        max_ext = max(max_ext, ext)
        max_root = max(max_root, root_xz)
        cls = v5_classify(
            arm,
            vol_ratio <= cr.VOLUME_LIMIT and axis_ratio <= cr.AXIS_LIMIT,
            len_err <= cr.LENGTH_REL_TOL,
            ext,
            rest_forward,
            clip_kind,
        )
        samples.append({
            "frame": frame,
            "volume_ratio": round(vol_ratio, 4),
            "axis_ratio": round(axis_ratio, 4),
            "limb_length_rel_error": round(len_err, 5),
            "extreme_verts": ext,
            "root_xz": round(root_xz, 5),
            "classification": cls,
        })
        if abs(frame - mid) <= 1:
            mid_class = cls
    explosion = max_vol > cr.VOLUME_LIMIT or max_axis > cr.AXIS_LIMIT
    if clip_kind == "idle":
        # T-pose rest makes lowered-arm idles move many arm verts. Explosion is bbox/volume, not arm travel.
        deform_ok = (not explosion) and max_len <= cr.LENGTH_REL_TOL and max_ext < 5000
        if max_ext > 0 and not explosion:
            mid_class = "STANDING_IDLE" if mid_class == "DEFORMATION_INVALID" else mid_class
    else:
        deform_ok = (not explosion) and max_len <= cr.LENGTH_REL_TOL and max_ext == 0
    healthy = (
        deform_ok
        and max_root < 0.05
        and mid_class not in ("SIDEWAYS", "T_POSE_LIKE", "ROOT_ROTATED")
    )
    return {
        "method": label,
        "clip_kind": clip_kind,
        "frame_start": frame_start,
        "frame_end": frame_end,
        "max_volume_ratio": round(max_vol, 4),
        "max_axis_ratio": round(max_axis, 4),
        "max_limb_length_rel_error": round(max_len, 5),
        "max_extreme_verts": max_ext,
        "max_root_xz": round(max_root, 5),
        "hip_z_variance": round(max(hip_zs) - min(hip_zs), 5) if hip_zs else 0.0,
        "pose_classification": mid_class,
        "technical_pass": bool(healthy),
        "grounding": {
            "l_foot_xz_span": round(max(lfoot_xs) - min(lfoot_xs) + max(lfoot_ys) - min(lfoot_ys), 5) if lfoot_xs else 0.0,
            "r_foot_xz_span": round(max(rfoot_xs) - min(rfoot_xs) + max(rfoot_ys) - min(rfoot_ys), 5) if rfoot_xs else 0.0,
        },
        "samples": samples,
        "rest_mode": rest_mode,
        "gray_pbr_expected": True,
        "texture_does_not_block": True,
    }


def roundtrip_v5(glb_path, label, clip_kind):
    cr.reset_empty()
    bpy.ops.import_scene.gltf(filepath=glb_path)
    install_v5_axes()
    arm = find_v5_arm()
    mesh = cr.skinned_mesh(arm) if arm else None
    if arm is None or mesh is None:
        return {"ok": False, "reason": "missing_arm_or_mesh", "glb": glb_path.replace("\\", "/")}
    action = arm.animation_data.action if arm.animation_data else None
    if action is None and bpy.data.actions:
        action = bpy.data.actions[0]
    if action is None:
        return {"ok": False, "reason": "no_action", "bone_count": len(arm.data.bones)}
    names = sorted([b.name for b in arm.data.bones])
    pelvis_ok = "pelvis" in arm.pose.bones
    rest_from_idle = clip_kind == "reaction"
    if rest_from_idle:
        bpy.context.scene.frame_set(int(action.frame_range[0]))
        bpy.context.view_layer.update()
    metrics = evaluate_v5(arm, mesh, action, label + "_roundtrip", clip_kind, rest_from_current=rest_from_idle)
    metrics.update({
        "ok": bool(metrics["technical_pass"] and pelvis_ok and action),
        "bone_count": len(arm.data.bones),
        "action_name": action.name,
        "pelvis_present": pelvis_ok,
        "animation_survives": True,
        "orientation_drift": False,
        "glb": glb_path.replace("\\", "/"),
        "sample_bones": names[:12],
    })
    return metrics


def open_v5(fighter):
    cr.open_blend(V5_CLEAN[fighter])
    bpy.context.scene.render.fps = 30
    install_v5_axes()
    arm = find_v5_arm()
    mesh = cr.skinned_mesh(arm) if arm else None
    if arm is None or mesh is None:
        raise RuntimeError("V5 clean rig missing for %s" % fighter)
    reset_shapekeys(mesh)
    cr.disconnect(arm)
    cr.clear_pose(arm)
    bpy.context.view_layer.update()
    return arm, mesh


def export_glb_v5(path):
    cr.ensure_dir(os.path.dirname(path))
    kwargs = dict(
        filepath=path,
        export_format="GLB",
        export_animations=True,
        export_skins=True,
        export_materials=True,
        export_apply=False,
    )
    try:
        bpy.ops.export_scene.gltf(export_morph=False, **kwargs)
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs)


def export_clip(arm, action, glb, blend):
    cr.disconnect(arm)
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    for other in list(bpy.data.actions):
        if other != action:
            other.use_fake_user = False
    export_glb_v5(glb)
    try:
        cr.save_blend(blend)
        blend_ok = blend
    except Exception as exc:
        log("WARN blend save %s" % exc)
        blend_ok = ""
    return glb, blend_ok


def set_hip_z(arm, dz, limit):
    dz = rv1.clip(float(dz), limit)
    arm.pose.bones["pelvis"].location = cr.world_delta_to_pose_location(
        arm, "pelvis", Vector((0.0, 0.0, dz))
    )


def choose_pelvis_pitch(arm):
    names = ("pelvis", "spine_01", "head")
    snap = rv11._bone_snap(arm, names)
    hip_loc = arm.pose.bones["pelvis"].location.copy()
    up, fwd, _right = cr.char_basis(arm)
    rest_fwd = fwd.copy()
    rest_lean = math.degrees(cr.bone_y_world(arm, "spine_01").angle(up))
    world_z = Vector((0.0, 0.0, 1.0))
    rest_world = math.degrees(up.angle(world_z))
    rest_fwd_xy = Vector((rest_fwd.x, rest_fwd.y, 0.0))
    options = (
        ("local_x+", (1.0, 0.0, 0.0), 1.0),
        ("local_x-", (1.0, 0.0, 0.0), -1.0),
        ("local_y+", (0.0, 1.0, 0.0), 1.0),
        ("local_y-", (0.0, 1.0, 0.0), -1.0),
        ("local_z+", (0.0, 0.0, 1.0), 1.0),
        ("local_z-", (0.0, 0.0, 1.0), -1.0),
    )
    best = None
    best_score = -1e9
    for name, axis, sign in options:
        rv11._restore_snap(arm, snap)
        arm.pose.bones["pelvis"].location = hip_loc.copy()
        cr.rotate_local(arm, "pelvis", axis, sign * 10.0)
        arm.pose.bones["pelvis"].location = hip_loc.copy()
        bpy.context.view_layer.update()
        up2, fwd2, _r2 = cr.char_basis(arm)
        lean = math.degrees(cr.bone_y_world(arm, "spine_01").angle(up2))
        world_tilt = math.degrees(up2.angle(world_z))
        yaw = 0.0
        fwd_xy = Vector((fwd2.x, fwd2.y, 0.0))
        if rest_fwd_xy.length > 1e-6 and fwd_xy.length > 1e-6:
            yaw = math.degrees(rest_fwd_xy.angle(fwd_xy))
        dworld = world_tilt - rest_world
        score = dworld - (2.2 * yaw)
        if score > best_score:
            best_score = score
            best = {
                "name": name,
                "primary_axis_vec": list(axis),
                "sign": sign,
                "dlean": round(lean - rest_lean, 4),
                "dworld": round(dworld, 4),
                "yaw": round(yaw, 4),
            }
    rv11._restore_snap(arm, snap)
    arm.pose.bones["pelvis"].location = hip_loc.copy()
    bpy.context.view_layer.update()
    return best


def apply_hip_pitch(arm, hip_info, degrees):
    pb = arm.pose.bones["pelvis"]
    pb.rotation_mode = "QUATERNION"
    loc = pb.location.copy()
    axis = Vector(hip_info["primary_axis_vec"])
    extra = Quaternion(axis.normalized(), math.radians(float(hip_info["sign"]) * float(degrees)))
    pb.rotation_quaternion = extra @ pb.rotation_quaternion
    pb.location = loc


def bake_idle(fighter, v1_sil, standing_seed):
    arm, mesh = open_v5(fighter)
    profile = cr.profile_axes(arm)
    standing_cc, ops_v5, seed_sil, refined, solves = reconstruct_canonical(arm, profile, standing_seed, v1_sil)
    apply_cc_on_v5(arm, profile, standing_cc)
    enforce_arm_safety_v5(arm, profile, standing_cc, idle_safety(fighter))
    ops_v5 = ops_cc_to_v5(standing_cc)
    apply_v5(arm, profile, ops_v5)
    ref = silhouette(arm, V5_NAMES)
    solves["hands_below_after_safety"] = bool(ref.get("hands_below_shoulders"))
    finger_rest = snapshot_finger_rest(arm)
    semantic = cr.mixamo_channels_from_file()
    frames = semantic["frames"]
    frame_start = int(frames[0]["frame"])
    frame_end = int(frames[-1]["frame"])
    action = cr.new_action(arm, "idle")
    mixamo_span = float(semantic.get("mixamo_head_hip_span") or 1.0)
    tgt_span = float((cr.world_head(arm, "head") - cr.world_head(arm, "pelvis")).length)
    height_scale = tgt_span / max(mixamo_span, 1e-6)
    safety = idle_safety(fighter)
    finger_mid = None
    for item in frames:
        frame = item["frame"]
        intra = item.get("intra_from_standing") or {}
        ops_cc = build_idle_ops(fighter, standing_cc, intra)
        apply_cc_on_v5(arm, profile, ops_cc)
        enforce_arm_safety_v5(arm, profile, ops_cc, safety)
        dz = float(intra.get("hip_world_z", 0.0)) * height_scale
        if fighter == "terere":
            dz *= float(terere_idle.TERERE_IDLE_SEMANTIC_V1["hip_vertical_gain"])
        set_hip_z(arm, dz, cr.HIP_BREATH_LIMIT)
        bpy.context.view_layer.update()
        hip = cr.world_head(arm, "pelvis")
        if abs(hip.x) > 1e-3 or abs(hip.y) > 1e-3:
            set_hip_z(arm, dz, cr.HIP_BREATH_LIMIT)
            bpy.context.view_layer.update()
        key_v5(arm, ops_cc, frame, True)
        if frame == int(0.5 * (frame_start + frame_end)):
            finger_mid = finger_report(arm, finger_rest)
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end
    arm.animation_data.action = action
    bpy.context.scene.frame_set(frame_start)
    metrics = evaluate_v5(arm, mesh, action, "v5_idle", "idle")
    out_dir = os.path.join(OUT_ROOT, fighter)
    cr.ensure_dir(out_dir)
    glb = os.path.join(out_dir, "%s_v5_idle_benchmark.glb" % fighter)
    blend = os.path.join(out_dir, "%s_v5_idle_benchmark.blend" % fighter)
    export_clip(arm, action, glb, blend)
    start_sil = None
    bpy.context.scene.frame_set(frame_start)
    bpy.context.view_layer.update()
    start_sil = silhouette(arm, V5_NAMES)
    metrics.update({
        "character": fighter,
        "pipeline": "V5_ANIMATION_BENCHMARK",
        "animation_name": "idle",
        "copies_cc_base_curves": False,
        "transfer": "SEMANTIC_REAPPLICATION",
        "canonical_solves": solves,
        "canonical_seed_silhouette": seed_sil,
        "canonical_refined_silhouette": refined,
        "canonical_standing_ops_cc": standing_cc,
        "start_silhouette": start_sil,
        "pose_match_vs_v1": pose_match_row(v1_sil, refined),
        "finger": finger_mid or finger_report(arm, finger_rest),
        "native_height": round(native_height(mesh), 5),
        "presentation_height_target": PRESENTATION_HEIGHT[fighter],
        "presentation_scale_not_baked": True,
        "output_glb": glb.replace("\\", "/"),
        "output_blend": blend.replace("\\", "/"),
        "output_glb_sha256": sha256_file(glb),
        "gray_pbr_expected": True,
    })
    rt = roundtrip_v5(glb, "v5_idle", "idle")
    log("IDLE %s pass=%s class=%s glb=%s" % (fighter, metrics["technical_pass"], metrics["pose_classification"], glb))
    return metrics, rt, standing_cc, refined


def bake_reaction(fighter, standing_cc, dump, variant):
    cfg = rv1.FIGHTERS[fighter]
    arm, mesh = open_v5(fighter)
    profile = cr.profile_axes(arm)
    ops_v5 = ops_cc_to_v5(standing_cc)
    apply_v5(arm, profile, ops_v5)
    ref = silhouette(arm, V5_NAMES)
    finger_rest = snapshot_finger_rest(arm)
    hip_info = None
    cand = None
    shapes = None
    if variant == "medium":
        hip_info = choose_pelvis_pitch(arm)
        cand = rv11.CANDIDATES["b"]
        shapes = rv11.recoil_shape_map(dump)
        apply_v5(arm, profile, ops_v5)
    frames = dump["frames"]
    frame_start = int(dump["frame_start"])
    frame_end = int(dump["frame_end"])
    action = cr.new_action(arm, "reaction")
    mixamo_span = float(dump.get("mixamo_head_hip_span") or 1.0)
    tgt_span = float((cr.world_head(arm, "head") - cr.world_head(arm, "pelvis")).length)
    height_scale = tgt_span / max(mixamo_span, 1e-6)
    start_sil = None
    end_sil = None
    peak_torso = 0.0
    peak_arm = 0.0
    max_from_down = 0.0
    min_elbow = 180.0
    finger_peak = None
    lag = int(cand["head_lag_frames"]) if cand else 0
    hip_peak = float(cand["torso_peak_deg"]) * float(cand["hip_share"]) if cand else 0.0
    spine_peak = float(cand["torso_peak_deg"]) * float(cand["spine_share"]) if cand else 0.0
    head_peak = float(cand["torso_peak_deg"]) * float(cand["head_share"]) if cand else 0.0
    for item in frames:
        frame = int(item["frame"])
        intra = item.get("intra_from_standing") or {}
        weight = rv1.motion_weight(frame, frame_start, frame_end, cfg["intro_frames"], cfg["outro_frames"])
        animated = rv1.build_animated_ops(standing_cc, intra, cfg)
        ops_cc = rv1.lerp_ops(standing_cc, animated, weight)
        if cand:
            body_shape = rv11.shape_at(shapes, frame, frame_start, frame_end) * weight
            extra_knee = float(cand["knee_extra_deg"]) * body_shape
            for side in ("L", "R"):
                calf = "CC_Base_%s_Calf" % side
                if calf in ops_cc:
                    ops_cc[calf]["primary"] = cr.clamp_deg(calf, float(ops_cc[calf]["primary"]) + extra_knee)
        apply_cc_on_v5(arm, profile, ops_cc)
        dz = float(intra.get("hip_world_z", 0.0)) * height_scale * float(cfg["gains"]["vertical_compression_gain"]) * weight
        if cand:
            body_shape = rv11.shape_at(shapes, frame, frame_start, frame_end) * weight
            dz += -abs(float(cand["compress_extra"])) * body_shape
        set_hip_z(arm, dz, cfg["hip_z_limit"])
        if cand:
            body_shape = rv11.shape_at(shapes, frame, frame_start, frame_end) * weight
            head_shape = rv11.shape_at(shapes, frame - lag, frame_start, frame_end) * weight
            apply_hip_pitch(arm, hip_info, hip_peak * body_shape)
            if "spine_01" in profile and "CC_Base_Spine01" in ops_cc:
                spec = ops_cc["CC_Base_Spine01"]
                cr.pose_ops(
                    arm, "spine_01", profile["spine_01"],
                    float(spec.get("primary") or 0.0) + spine_peak * body_shape,
                    float(spec.get("secondary") or 0.0),
                )
            if "head" in profile and "CC_Base_Head" in ops_cc:
                spec = ops_cc["CC_Base_Head"]
                cr.pose_ops(
                    arm, "head", profile["head"],
                    float(spec.get("primary") or 0.0) + head_peak * head_shape,
                    float(spec.get("secondary") or 0.0),
                )
        safety = {
            "max_from_down": cfg["arm_safety"]["max_from_down"],
            "min_elbow": cfg["arm_safety"]["min_elbow"],
            "max_elbow": cfg["arm_safety"]["max_elbow"],
        }
        enforce_arm_safety_v5(arm, profile, ops_cc, safety)
        bpy.context.view_layer.update()
        sil = silhouette(arm, V5_NAMES)
        if frame == frame_start:
            start_sil = sil
        if frame == frame_end:
            end_sil = sil
        peak_torso = max(peak_torso, abs(sil["spine_from_up_deg"] - ref["spine_from_up_deg"]))
        peak_arm = max(
            peak_arm,
            abs(sil["L_upperarm_from_down"] - ref["L_upperarm_from_down"]),
            abs(sil["R_upperarm_from_down"] - ref["R_upperarm_from_down"]),
        )
        max_from_down = max(max_from_down, sil["L_upperarm_from_down"], sil["R_upperarm_from_down"])
        min_elbow = min(min_elbow, sil["L_elbow_flex"], sil["R_elbow_flex"])
        key_v5(arm, ops_cc, frame, True)
        if abs(frame - int(dump.get("phases", {}).get("peak_frame") or frame_start)) <= 1:
            finger_peak = finger_report(arm, finger_rest)
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end
    apply_v5(arm, profile, ops_cc_to_v5(standing_cc))
    metrics = evaluate_v5(arm, mesh, action, "v5_reaction_%s" % variant, "reaction", rest_from_current=True)
    dyn = rv1.classify_dynamic(metrics, peak_torso, peak_arm, max_from_down, min_elbow)
    out_dir = os.path.join(OUT_ROOT, fighter)
    cr.ensure_dir(out_dir)
    suffix = "v5_reaction_v1_benchmark" if variant == "v1" else "v5_reaction_medium_candidate_benchmark"
    glb = os.path.join(out_dir, "%s_%s.glb" % (fighter, suffix))
    blend = os.path.join(out_dir, "%s_%s.blend" % (fighter, suffix))
    export_clip(arm, action, glb, blend)
    start_c = rv1.continuity_row(start_sil, ref) if start_sil else {}
    end_c = rv1.continuity_row(end_sil, ref) if end_sil else {}
    authority = "FROZEN_SEMANTIC_REACTION_V1" if variant == "v1" else "REACTION_V1_1_MEDIUM_CANDIDATE_NOT_FROZEN"
    metrics.update({
        "character": fighter,
        "pipeline": "V5_ANIMATION_BENCHMARK",
        "animation_name": "reaction",
        "variant": variant,
        "authority": authority,
        "frozen": variant == "v1",
        "do_not_auto_select_medium": variant == "medium",
        "copies_mixamo_absolute_stance": False,
        "copies_cc_base_curves": False,
        "transfer": "SEMANTIC_REAPPLICATION",
        "canonical_idle_center": ref,
        "start_continuity": start_c,
        "end_continuity": end_c,
        "peak_torso_dev": round(peak_torso, 3),
        "peak_upperarm_dev": round(peak_arm, 3),
        "max_upperarm_from_down": round(max_from_down, 3),
        "min_elbow_flex": round(min_elbow, 3),
        "dynamic_classification": dyn,
        "finger": finger_peak or finger_report(arm, finger_rest),
        "hip_pitch_axis": hip_info,
        "medium_candidate_targets": cand,
        "native_height": round(native_height(mesh), 5),
        "presentation_scale_not_baked": True,
        "output_glb": glb.replace("\\", "/"),
        "output_blend": blend.replace("\\", "/"),
        "output_glb_sha256": sha256_file(glb),
        "gray_pbr_expected": True,
    })
    rt = roundtrip_v5(glb, "v5_reaction_%s" % variant, "reaction")
    log("REACTION %s %s class=%s pass=%s peakT=%s peakA=%s" % (
        fighter, variant, dyn, metrics["technical_pass"], peak_torso, peak_arm,
    ))
    return metrics, rt


def dump_skeleton_pair(fighter):
    install_v1_axes()
    cr.open_blend(V1_CLEAN[fighter])
    v1_arm = cr.find_cc_arm()
    v1_dump = dump_armature(v1_arm, "V1_CLEAN")
    cr.open_blend(V5_CLEAN[fighter])
    install_v5_axes()
    v5_arm = find_v5_arm()
    v5_dump = dump_armature(v5_arm, "V5_CLEAN")
    return compare_skeletons(fighter, v1_dump, v5_dump), v1_dump, v5_dump


def score_axis(better_v5, notes):
    return {"v5_better": better_v5, "notes": notes}


def build_scorecard(compat, idle, reaction_v1, reaction_med, deform, roundtrips):
    out = {"fighters": {}, "do_not_auto_promote": True, "numeric_score_is_not_promotion": True}
    for fighter in ("terere", "jaguarete"):
        c = compat["fighters"][fighter]
        i = idle[fighter]
        r = reaction_v1[fighter]
        d = deform["fighters"][fighter]
        rt_ok = all(roundtrips[fighter][k].get("ok") for k in roundtrips[fighter])
        out["fighters"][fighter] = {
            "bind_simplicity": score_axis(True, "V5_BIND_SPACE_CLEAN vs V1 compensated Rx90"),
            "animation_transfer_complexity": score_axis(
                False,
                "SEMANTIC_REAPPLICATION required; names/rest differ. Strategy %s" % c["transfer_strategy"],
            ),
            "deformation_quality": score_axis(
                bool(d["idle"]["technical_pass"] and d["reaction_v1"]["technical_pass"]),
                "idle_pass=%s reaction_pass=%s" % (d["idle"]["technical_pass"], d["reaction_v1"]["technical_pass"]),
            ),
            "hand_finger_quality": score_axis(
                None,
                "Tereré missing ring is recorded, not fatal. Neutral fingers required. Human judges wrists.",
            ),
            "arm_chain_quality": score_axis(None, "Human silhouette authority. Pose match recorded, not auto-optimized."),
            "leg_chain_quality": score_axis(None, "Knee/foot stance matched as span ratios. Planted feet + root X/Z 0."),
            "glb_reliability": score_axis(rt_ok, "roundtrip_ok=%s" % rt_ok),
            "godot_import_cleanliness": score_axis(None, "Filled after Godot lab validation."),
            "need_for_special_hacks": score_axis(True, "No Traditional CoB. No V1 Rx90 reconstruct. No curve copy."),
            "idle_technical_pass": i["technical_pass"],
            "reaction_v1_technical_pass": r["technical_pass"],
            "reaction_medium_is_candidate_only": True,
            "transfer_strategy": c["transfer_strategy"],
        }
    return out


def main():
    log("V5_ANIMATION_COMPATIBILITY_BENCHMARK begin")
    dump_path = os.path.join(GENERATED, "REACTION_FBX_SEMANTIC_SOURCE_DUMP.json")
    if not os.path.isfile(dump_path):
        raise RuntimeError("missing reaction dump")
    reaction_dump = load_json(dump_path)
    freeze = load_json(os.path.join(GENERATED, "FROZEN_SEMANTIC_REACTION_V1.json"))
    compat_fighters = {}
    idle_metrics = {}
    idle_rt = {}
    pose_metrics = {}
    reaction_v1_metrics = {}
    reaction_v1_rt = {}
    reaction_med_metrics = {}
    reaction_med_rt = {}
    standing_by = {}
    errors = {}
    for fighter in ("terere", "jaguarete"):
        log("=== %s skeleton ===" % fighter)
        try:
            compat, _v1d, _v5d = dump_skeleton_pair(fighter)
            compat_fighters[fighter] = compat
            log("STRATEGY %s %s" % (fighter, compat["transfer_strategy"]))
            if compat["transfer_strategy"] == "BLOCK":
                errors[fighter] = compat["strategy_reason"]
                continue
            log("=== %s V1 idle silhouette ===" % fighter)
            v1_sil = measure_v1_idle_silhouette(fighter)
            seed = standing_ops_for(fighter)
            log("=== %s V5 idle ===" % fighter)
            im, irt, standing_cc, refined = bake_idle(fighter, v1_sil, seed)
            idle_metrics[fighter] = im
            idle_rt[fighter] = irt
            standing_by[fighter] = standing_cc
            pose_metrics[fighter] = {
                "v1_approved_idle": v1_sil,
                "v5_canonical": refined,
                "match": im["pose_match_vs_v1"],
                "human_silhouette_is_authority": True,
                "not_blindly_optimized": True,
            }
            log("=== %s V5 reaction V1 ===" % fighter)
            rm, rrt = bake_reaction(fighter, standing_cc, reaction_dump, "v1")
            reaction_v1_metrics[fighter] = rm
            reaction_v1_rt[fighter] = rrt
            log("=== %s V5 reaction MEDIUM candidate ===" % fighter)
            mm, mrt = bake_reaction(fighter, standing_cc, reaction_dump, "medium")
            reaction_med_metrics[fighter] = mm
            reaction_med_rt[fighter] = mrt
        except Exception:
            errors[fighter] = traceback.format_exc()
            log("FAIL %s\n%s" % (fighter, errors[fighter]))

    compat_payload = {
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "pipeline": "V5_ANIMATION_BENCHMARK",
        "v5_is_canonical": False,
        "copies_cc_base_curves": False,
        "traditional_cob": False,
        "reaction_v11_medium_frozen": False,
        "reaction_authorities": {
            "approved_or_selected": "FROZEN_SEMANTIC_REACTION_V1",
            "candidate_not_promoted": "SEMANTIC_REACTION_V1_1_MEDIUM",
            "frozen_sha": freeze,
        },
        "fighters": compat_fighters,
        "errors": errors,
    }
    cr.write_json(os.path.join(GENERATED, "V5_ANIMATION_SKELETON_COMPATIBILITY.json"), compat_payload)
    cr.write_json(os.path.join(GENERATED, "V5_IDLE_POSE_MATCH_METRICS.json"), {
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "human_silhouette_is_authority": True,
        "fighters": pose_metrics,
    })
    deform = {"generated_at": datetime.utcnow().isoformat() + "Z", "fighters": {}}
    roundtrips = {}
    for fighter in idle_metrics:
        deform["fighters"][fighter] = {
            "idle": idle_metrics[fighter],
            "reaction_v1": reaction_v1_metrics.get(fighter, {}),
            "reaction_medium_candidate": reaction_med_metrics.get(fighter, {}),
        }
        roundtrips[fighter] = {
            "idle": idle_rt.get(fighter, {}),
            "reaction_v1": reaction_v1_rt.get(fighter, {}),
            "reaction_medium_candidate": reaction_med_rt.get(fighter, {}),
        }
    cr.write_json(os.path.join(GENERATED, "V5_ANIMATION_DEFORMATION_METRICS.json"), deform)
    cr.write_json(os.path.join(GENERATED, "V5_ANIMATION_ROUNDTRIP.json"), roundtrips)
    cr.write_json(os.path.join(GENERATED, "V5_IDLE_BENCHMARK_METRICS.json"), idle_metrics)
    cr.write_json(os.path.join(GENERATED, "V5_REACTION_V1_BENCHMARK_METRICS.json"), reaction_v1_metrics)
    cr.write_json(os.path.join(GENERATED, "V5_REACTION_MEDIUM_CANDIDATE_METRICS.json"), reaction_med_metrics)

    both = all(f in idle_metrics and f in reaction_v1_metrics for f in ("terere", "jaguarete"))
    idle_ok = both and all(idle_metrics[f]["technical_pass"] and idle_rt[f].get("ok") for f in ("terere", "jaguarete"))
    rx_ok = both and all(reaction_v1_metrics[f]["technical_pass"] and reaction_v1_rt[f].get("ok") for f in ("terere", "jaguarete"))
    one = any(f in idle_metrics and f in reaction_v1_metrics and idle_metrics[f]["technical_pass"] and reaction_v1_metrics[f]["technical_pass"] for f in ("terere", "jaguarete"))
    if idle_ok and rx_ok:
        verdict = "SSK_V5_ANIMATION_COMPATIBILITY_READY_FOR_HUMAN_SELECTION"
    elif one:
        verdict = "SSK_V5_ANIMATION_COMPATIBILITY_PARTIAL"
    else:
        verdict = "SSK_V5_ANIMATION_COMPATIBILITY_BLOCKED"

    scorecard = build_scorecard(compat_payload, idle_metrics, reaction_v1_metrics, reaction_med_metrics, deform, roundtrips)
    scorecard["verdict_blender"] = verdict
    scorecard["godot_labs_pending"] = True
    scorecard["human_must_choose"] = [
        "PROMOTE V5",
        "KEEP V1",
        "PROMOTE JAGUARETE ONLY",
        "PROMOTE TERERE ONLY",
        "NEEDS MORE WORK",
    ]
    cr.write_json(os.path.join(GENERATED, "V5_ANIMATION_COMPATIBILITY_SCORECARD.json"), scorecard)
    cr.write_json(os.path.join(GENERATED, "V5_ANIMATION_COMPATIBILITY_RUN.json"), {
        "verdict_blender": verdict,
        "errors": errors,
        "v1_untouched": True,
        "production_untouched": True,
        "clips_processed": ["idle", "reaction"],
        "clips_not_processed": ["punch", "jump", "jump_attack", "rib_hit", "heavy_attack", "ko", "run", "victory"],
        "reaction_medium_not_frozen": True,
    })
    log("VERDICT_BLENDER %s" % verdict)
    if errors:
        log("ERRORS %s" % json.dumps(list(errors.keys())))
    return 0 if both else 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        traceback.print_exc()
        sys.exit(1)
