# -*- coding: utf-8 -*-
"""Semantic Reaction V1. Mixamo Reaction.fbx around approved idle centers.

Does not overwrite Idle assets. Does not use Traditional CoB.
Does not touch Jaguareté approved idle or Tereré Production Idle.
"""
from __future__ import print_function

import copy
import hashlib
import json
import math
import os
import sys
import traceback

import bpy
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
import clean_rig_idle_retarget_benchmark_v1 as cr

PROJECT_ROOT = cr.PROJECT_ROOT
GENERATED = cr.GENERATED
REACTION_FBX = os.path.join(PROJECT_ROOT, "assets", "fighters", "animations", "Reaction.fbx")
OUT_ROOT = os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "semantic_reaction_v1")

INVERT = set(["L_shoulder_lowering", "R_shoulder_lowering", "L_hand_from_down", "R_hand_from_down"])
MAJOR = (
    "Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
    "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
    "RightShoulder", "RightArm", "RightForeArm", "RightHand",
    "LeftUpLeg", "LeftLeg", "LeftFoot",
    "RightUpLeg", "RightLeg", "RightFoot",
)

FIGHTERS = {
    "terere": {
        "idle_glb": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "production_semantic_idle_v1", "terere", "terere_production_semantic_idle_v1.glb"),
        "ops_from": "canonical",
        "gains": {
            "torso_pitch_gain": 0.88,
            "torso_yaw_gain": 0.50,
            "torso_roll_gain": 0.35,
            "head_gain": 0.72,
            "clavicle_gain": 0.42,
            "upperarm_gain": 0.38,
            "elbow_gain": 0.52,
            "wrist_gain": 0.16,
            "hip_gain": 0.70,
            "knee_gain": 0.42,
            "vertical_compression_gain": 0.55,
        },
        "envelope": {
            "spine": 12.0, "head": 9.0, "clavicle": 5.0, "upperarm": 12.0,
            "elbow": 10.0, "wrist": 4.0, "knee": 8.0,
        },
        "arm_safety": {"max_from_down": 56.0, "min_elbow": 70.0, "max_elbow": 104.0},
        "hip_z_limit": 0.07,
        "intro_frames": 3,
        "outro_frames": 10,
    },
    "jaguarete": {
        "idle_glb": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "semantic_idle_polish_v1", "jaguarete", "jaguarete_idle_semantic_polished_v1.glb"),
        "ops_from": "jaguarete_polished",
        "gains": {
            "torso_pitch_gain": 0.95,
            "torso_yaw_gain": 0.55,
            "torso_roll_gain": 0.40,
            "head_gain": 0.80,
            "clavicle_gain": 0.48,
            "upperarm_gain": 0.48,
            "elbow_gain": 0.58,
            "wrist_gain": 0.18,
            "hip_gain": 0.78,
            "knee_gain": 0.48,
            "vertical_compression_gain": 0.60,
        },
        "envelope": {
            "spine": 14.0, "head": 10.0, "clavicle": 6.0, "upperarm": 14.0,
            "elbow": 12.0, "wrist": 4.5, "knee": 9.0,
        },
        "arm_safety": {"max_from_down": 64.0, "min_elbow": 52.0, "max_elbow": 105.0},
        "hip_z_limit": 0.08,
        "intro_frames": 3,
        "outro_frames": 10,
    },
}


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


def clip(value, limit):
    if value > limit:
        return limit
    if value < -limit:
        return -limit
    return value


def smooth01(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def motion_weight(frame, start, end, intro, outro):
    if end <= start:
        return 1.0
    if frame <= start:
        return 0.0
    if frame >= end:
        return 0.0
    if intro > 0 and frame < start + intro:
        return smooth01(float(frame - start) / float(intro))
    if outro > 0 and frame > end - outro:
        return smooth01(float(end - frame) / float(outro))
    return 1.0


def mixamo_rich(arm, prefix, standing_hip=None):
    row = cr.mixamo_semantic(arm, prefix)
    hips = cr.mixamo_name(prefix, "Hips")
    spine = cr.mixamo_name(prefix, "Spine1")
    hip_w = cr.world_head(arm, hips)
    up, forward, right = cr.char_basis(arm)
    y = cr.bone_y_world(arm, spine)
    row["hip_world_x"] = round(float(hip_w.x), 5)
    row["hip_world_y"] = round(float(hip_w.y), 5)
    row["torso_pitch"] = round(math.degrees(math.atan2(float(y.dot(forward)), max(float(y.dot(up)), 1e-6))), 4)
    flat = Vector((forward.x, forward.y, 0.0))
    hy = Vector((y.x, y.y, 0.0))
    yaw = 0.0
    if flat.length > 1e-5 and hy.length > 1e-5:
        yaw = math.degrees(flat.angle(hy))
        if flat.cross(hy).z < 0:
            yaw = -yaw
    row["torso_yaw"] = round(yaw, 4)
    row["torso_roll"] = round(math.degrees(math.atan2(float(y.dot(right)), max(float(y.dot(up)), 1e-6))), 4)
    if standing_hip is not None:
        row["hip_horiz"] = round(math.sqrt((hip_w.x - standing_hip.x) ** 2 + (hip_w.y - standing_hip.y) ** 2), 5)
    return row


def dump_reaction():
    cr.reset_empty()
    bpy.context.scene.render.fps = 30
    cr.import_fbx(REACTION_FBX)
    arm = cr.find_mixamo_arm()
    if arm is None:
        raise RuntimeError("Mixamo armature missing in Reaction.fbx")
    prefix = cr.discover_prefix(arm)
    action = arm.animation_data.action if arm.animation_data else None
    if action is None:
        for candidate in bpy.data.actions:
            if "reaction" in candidate.name.lower() or "mixamo" in candidate.name.lower():
                action = candidate
                break
    if action is None and bpy.data.actions:
        action = bpy.data.actions[0]
    cr.disconnect(arm)
    cr.clear_pose(arm)
    bpy.context.view_layer.update()
    rest = mixamo_rich(arm, prefix)
    hierarchy = {}
    for bone in arm.data.bones:
        hierarchy[bone.name] = bone.parent.name if bone.parent else None
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    frame_start = int(action.frame_range[0])
    frame_end = int(action.frame_range[1])
    fps = int(bpy.context.scene.render.fps)
    bpy.context.scene.frame_set(frame_start)
    bpy.context.view_layer.update()
    standing = mixamo_rich(arm, prefix)
    standing_hip = cr.world_head(arm, cr.mixamo_name(prefix, "Hips")).copy()
    standing = mixamo_rich(arm, prefix, standing_hip)
    mixamo_span = float((cr.world_head(arm, cr.mixamo_name(prefix, "Head")) - standing_hip).length)
    frames = []
    root_x, root_y, root_z = [], [], []
    hip_loc = {"x": [], "y": [], "z": []}
    for frame in range(frame_start, frame_end + 1):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        world = mixamo_rich(arm, prefix, standing_hip)
        intra = {}
        for key, value in world.items():
            intra[key] = round(float(value) - float(standing.get(key, 0.0)), 5 if "hip" in key else 4)
        loc = arm.pose.bones[cr.mixamo_name(prefix, "Hips")].location
        hip_loc["x"].append(float(loc.x))
        hip_loc["y"].append(float(loc.y))
        hip_loc["z"].append(float(loc.z))
        root_x.append(world["hip_world_x"])
        root_y.append(world["hip_world_y"])
        root_z.append(world["hip_world_z"])
        frames.append({"frame": frame, "world": world, "intra_from_standing": intra})
    peak = max(frames, key=lambda item: abs(item["intra_from_standing"].get("torso_lean", 0.0)) + abs(item["intra_from_standing"].get("torso_pitch", 0.0)) * 0.5 + item["intra_from_standing"].get("hip_horiz", 0.0) * 20.0)
    peak_score = abs(peak["intra_from_standing"].get("torso_lean", 0.0)) + abs(peak["intra_from_standing"].get("torso_pitch", 0.0))
    impact = frame_start
    for item in frames:
        score = abs(item["intra_from_standing"].get("torso_lean", 0.0)) + abs(item["intra_from_standing"].get("torso_pitch", 0.0))
        if score >= 0.30 * max(peak_score, 1e-6):
            impact = item["frame"]
            break
    duration = (frame_end - frame_start + 1) / float(max(fps, 1))
    phases = {
        "ANTICIPATION": {"start": frame_start, "end": max(frame_start, impact - 1)} if impact > frame_start + 2 else None,
        "IMPACT": {"start": impact, "end": min(peak["frame"], impact + 3)},
        "RECOIL": {"start": min(peak["frame"], impact + 3), "end": min(frame_end, peak["frame"] + max(4, int(0.15 * fps)))},
        "RECOVERY": {"start": min(frame_end, peak["frame"] + max(4, int(0.15 * fps))), "end": frame_end},
        "peak_frame": peak["frame"],
        "time_to_peak_s": round((peak["frame"] - frame_start) / float(max(fps, 1)), 3),
        "recovery_duration_s": round((frame_end - peak["frame"]) / float(max(fps, 1)), 3),
        "clip_duration_s": round(duration, 3),
    }
    strongest = "torso"
    mag = {
        "torso": max(abs(item["intra_from_standing"].get("torso_lean", 0.0)) for item in frames),
        "head": max(abs(item["intra_from_standing"].get("head_lean", 0.0)) for item in frames),
        "shoulder": max(abs(item["intra_from_standing"].get("L_shoulder_lowering", 0.0)) for item in frames),
        "hip_horiz": max(item["intra_from_standing"].get("hip_horiz", 0.0) for item in frames),
        "knee": max(abs(item["intra_from_standing"].get("L_knee_flexion", 0.0)) for item in frames),
    }
    strongest = max(mag.items(), key=lambda kv: kv[1])[0]
    dump = {
        "source": REACTION_FBX.replace("\\", "/"),
        "armature": arm.name,
        "namespace_prefix": prefix,
        "bone_count": len(arm.data.bones),
        "bones": sorted(list(arm.pose.bones.keys())),
        "hierarchy_major": {
            cr.mixamo_name(prefix, suffix): hierarchy.get(cr.mixamo_name(prefix, suffix))
            for suffix in MAJOR if cr.mixamo_name(prefix, suffix) in hierarchy
        },
        "action": action.name if action else "",
        "frame_start": frame_start,
        "frame_end": frame_end,
        "fps": fps,
        "clip_duration_s": round(duration, 3),
        "object": cr.object_xform(arm),
        "rest": rest,
        "standing": standing,
        "standing_is_first_animated_frame_not_rest": True,
        "copies_mixamo_quaternion": False,
        "root_world": {
            "x": {"min": round(min(root_x), 5), "max": round(max(root_x), 5)},
            "y": {"min": round(min(root_y), 5), "max": round(max(root_y), 5)},
            "z": {"min": round(min(root_z), 5), "max": round(max(root_z), 5)},
        },
        "hip_local": {
            axis: {"min": round(min(hip_loc[axis]), 5), "max": round(max(hip_loc[axis]), 5)}
            for axis in ("x", "y", "z")
        },
        "intra_abs_max": mag,
        "strongest_recoil_channel": strongest,
        "phases": phases,
        "classification": {
            "clip": "HIT_REACTION",
            "direction": "backward_recoil" if standing["torso_pitch"] <= peak["world"]["torso_pitch"] else "forward_or_mixed",
            "notes": "Phases from source torso/hip evidence. Root X/Z stripped on bake.",
        },
        "mixamo_head_hip_span": round(mixamo_span, 6),
        "frames": frames,
    }
    cr.write_json(os.path.join(GENERATED, "REACTION_FBX_SEMANTIC_SOURCE_DUMP.json"), dump)
    log("DUMP reaction frames %s-%s peak %s strongest %s" % (frame_start, frame_end, peak["frame"], strongest))
    return dump


def standing_ops_for(fighter):
    if fighter == "terere":
        return copy.deepcopy(load_json(os.path.join(GENERATED, "TERERE_CANONICAL_IDLE_POSE_V1.json"))["standing_ops"])
    polished = load_json(os.path.join(GENERATED, "JAGUARETE_IDLE_SEMANTIC_POLISHED_V1_METRICS.json"))["standing_ops_polished"]
    ops = {}
    for bone, spec in polished.items():
        ops[bone] = {"primary": float(spec.get("primary") or 0.0), "secondary": float(spec.get("secondary") or 0.0)}
    return ops


def apply_ops(arm, profile, ops):
    cr.clear_pose(arm)
    for bone, spec in ops.items():
        if bone in profile:
            cr.pose_ops(arm, bone, profile[bone], spec.get("primary", 0.0), spec.get("secondary", 0.0))
    bpy.context.view_layer.update()


def silhouette(arm):
    up, _fwd, right = cr.char_basis(arm)
    hip = cr.world_head(arm, "CC_Base_Hip")
    l_hand = cr.world_head(arm, "CC_Base_L_Hand")
    r_hand = cr.world_head(arm, "CC_Base_R_Hand")
    l_sh = cr.world_head(arm, "CC_Base_L_Upperarm")
    r_sh = cr.world_head(arm, "CC_Base_R_Upperarm")
    return {
        "spine_from_up_deg": round(math.degrees(cr.bone_y_world(arm, "CC_Base_Spine01").angle(up)), 3),
        "L_upperarm_from_down": round(cr.from_down_deg(arm, "CC_Base_L_Upperarm"), 3),
        "R_upperarm_from_down": round(cr.from_down_deg(arm, "CC_Base_R_Upperarm"), 3),
        "L_elbow_flex": round(cr.flex_deg(arm, "CC_Base_L_Upperarm", "CC_Base_L_Forearm"), 3),
        "R_elbow_flex": round(cr.flex_deg(arm, "CC_Base_R_Upperarm", "CC_Base_R_Forearm"), 3),
        "L_hand": cr.vec3(l_hand),
        "R_hand": cr.vec3(r_hand),
        "hip": cr.vec3(hip),
        "L_foot": cr.vec3(cr.world_head(arm, "CC_Base_L_Foot")),
        "R_foot": cr.vec3(cr.world_head(arm, "CC_Base_R_Foot")),
        "hands_below_shoulders": bool(l_hand.z < l_sh.z - 0.01 and r_hand.z < r_sh.z - 0.01),
        "shoulder_width": round(float((l_sh - r_sh).length), 4),
    }


def filtered(raw, gain, invert, envelope):
    delta = float(raw) * float(gain)
    if invert:
        delta = -delta
    return clip(delta, envelope)


def build_animated_ops(standing_ops, intra, cfg):
    gains = cfg["gains"]
    env = cfg["envelope"]
    ops = {}
    for bone, spec in standing_ops.items():
        ops[bone] = {"primary": float(spec.get("primary") or 0.0), "secondary": float(spec.get("secondary") or 0.0)}
    spine_delta = filtered(intra.get("torso_lean", 0.0), gains["torso_pitch_gain"], False, env["spine"])
    spine_delta += filtered(intra.get("torso_pitch", 0.0), gains["torso_pitch_gain"] * 0.35, False, env["spine"])
    spine_delta += clip(float(intra.get("hip_horiz", 0.0)) * 35.0 * gains["hip_gain"], env["spine"] * 0.65)
    yaw_delta = filtered(intra.get("torso_yaw", 0.0), gains["torso_yaw_gain"], False, env["spine"] * 0.45)
    ops["CC_Base_Spine01"]["primary"] = cr.clamp_deg("CC_Base_Spine01", ops["CC_Base_Spine01"]["primary"] + spine_delta)
    ops["CC_Base_Spine01"]["secondary"] = clip(ops["CC_Base_Spine01"].get("secondary", 0.0) + yaw_delta, env["spine"] * 0.4)
    ops["CC_Base_Head"]["primary"] = cr.clamp_deg(
        "CC_Base_Head",
        ops["CC_Base_Head"]["primary"] + filtered(intra.get("head_lean", 0.0), gains["head_gain"], False, env["head"]),
    )
    for side, sh_ch, el_ch, hand_ch in (
        ("L", "L_shoulder_lowering", "L_elbow_flexion", "L_hand_from_down"),
        ("R", "R_shoulder_lowering", "R_elbow_flexion", "R_hand_from_down"),
    ):
        clav = "CC_Base_%s_Clavicle" % side
        ua = "CC_Base_%s_Upperarm" % side
        el = "CC_Base_%s_Forearm" % side
        hand = "CC_Base_%s_Hand" % side
        ops[clav]["primary"] = cr.clamp_deg(
            clav, ops[clav]["primary"] + filtered(intra.get(sh_ch, 0.0), gains["clavicle_gain"], sh_ch in INVERT, env["clavicle"])
        )
        ops[ua]["primary"] = cr.clamp_deg(
            ua, ops[ua]["primary"] + filtered(intra.get(sh_ch, 0.0), gains["upperarm_gain"], sh_ch in INVERT, env["upperarm"])
        )
        ops[el]["primary"] = cr.clamp_deg(
            el, ops[el]["primary"] + filtered(intra.get(el_ch, 0.0), gains["elbow_gain"], False, env["elbow"])
        )
        ops[hand]["primary"] = cr.clamp_deg(
            hand, ops[hand]["primary"] + filtered(intra.get(hand_ch, 0.0), gains["wrist_gain"], hand_ch in INVERT, env["wrist"])
        )
        calf = "CC_Base_%s_Calf" % side
        kn = "L_knee_flexion" if side == "L" else "R_knee_flexion"
        ops[calf]["primary"] = cr.clamp_deg(
            calf, ops[calf]["primary"] + filtered(intra.get(kn, 0.0), gains["knee_gain"], False, env["knee"])
        )
    return ops


def lerp_ops(a, b, weight):
    out = {}
    for bone in a:
        out[bone] = {
            "primary": float(a[bone]["primary"]) * (1.0 - weight) + float(b[bone]["primary"]) * weight,
            "secondary": float(a[bone].get("secondary") or 0.0) * (1.0 - weight) + float(b[bone].get("secondary") or 0.0) * weight,
        }
    return out


def enforce_arm_safety(arm, profile, ops, safety):
    for side in ("L", "R"):
        ua = "CC_Base_%s_Upperarm" % side
        el = "CC_Base_%s_Forearm" % side
        steps = 0
        while cr.from_down_deg(arm, ua) > safety["max_from_down"] and steps < 8:
            ops[ua]["primary"] = cr.clamp_deg(ua, float(ops[ua]["primary"]) + 2.0)
            cr.pose_ops(arm, ua, profile[ua], ops[ua]["primary"], ops[ua].get("secondary", 0.0))
            bpy.context.view_layer.update()
            steps += 1
        flex = cr.flex_deg(arm, ua, el)
        steps = 0
        while flex < safety["min_elbow"] and steps < 8:
            ops[el]["primary"] = cr.clamp_deg(el, float(ops[el]["primary"]) + 2.0)
            cr.pose_ops(arm, el, profile[el], ops[el]["primary"], ops[el].get("secondary", 0.0))
            bpy.context.view_layer.update()
            flex = cr.flex_deg(arm, ua, el)
            steps += 1


def vdist(a, b):
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def continuity_row(sil, ref):
    return {
        "spine_dev": abs(sil["spine_from_up_deg"] - ref["spine_from_up_deg"]),
        "L_upperarm_dev": abs(sil["L_upperarm_from_down"] - ref["L_upperarm_from_down"]),
        "R_upperarm_dev": abs(sil["R_upperarm_from_down"] - ref["R_upperarm_from_down"]),
        "L_elbow_dev": abs(sil["L_elbow_flex"] - ref["L_elbow_flex"]),
        "R_elbow_dev": abs(sil["R_elbow_flex"] - ref["R_elbow_flex"]),
        "L_hand_dev": vdist(sil["L_hand"], ref["L_hand"]),
        "R_hand_dev": vdist(sil["R_hand"], ref["R_hand"]),
        "hip_dev": vdist(sil["hip"], ref["hip"]),
    }


def classify_dynamic(metrics, peak_torso, peak_arm, max_from_down, min_elbow):
    if int(metrics.get("max_extreme_verts", 99)) > 0 or float(metrics.get("max_limb_length_rel_error", 99)) > 0.02:
        return "DEFORMATION_INVALID"
    if max_from_down >= 70.0:
        return "T_POSE"
    if peak_torso >= 40.0:
        return "SIDEWAYS"
    if float(metrics.get("max_root_xz", 0.0)) >= 0.05:
        return "ROOT_TRANSLATED"
    if min_elbow is not None and min_elbow < 35.0:
        return "ARM_CHAIN_INVALID"
    if peak_torso < 1.6 and peak_arm < 3.0:
        return "STANDING_IDLE_ONLY"
    return "HIT_REACTION"


def setup_preview_cameras(arm):
    cr.setup_camera(arm)
    head_z = 1.6
    if "CC_Base_Head" in arm.pose.bones:
        head_z = max(1.3, float(cr.world_head(arm, "CC_Base_Head").z))
    dist = max(4.4, head_z * 2.1)
    look = Vector((0.0, 0.0, head_z * 0.52))
    for name, loc in (
        ("PreviewThreeQuarter", Vector((dist * 0.7, -dist * 0.7, look.z + 0.2))),
        ("PreviewSide", Vector((dist, 0.0, look.z + 0.2))),
    ):
        if name in bpy.data.objects:
            continue
        cam_data = bpy.data.cameras.new(name)
        cam = bpy.data.objects.new(name, cam_data)
        bpy.context.collection.objects.link(cam)
        cam.location = loc
        cam.rotation_euler = (look - loc).to_track_quat("-Z", "Y").to_euler()


def bake_fighter(fighter, dump):
    cfg = FIGHTERS[fighter]
    standing_ops = standing_ops_for(fighter)
    char = cr.CHARACTERS[fighter]
    cr.open_blend(char["blend"])
    bpy.context.scene.render.fps = int(dump.get("fps") or 30)
    arm = cr.find_cc_arm()
    mesh = cr.skinned_mesh(arm)
    if arm is None or mesh is None:
        raise RuntimeError("clean rig missing for %s" % fighter)
    cr.disconnect(arm)
    cr.clear_pose(arm)
    bpy.context.view_layer.update()
    profile = cr.profile_axes(arm)
    apply_ops(arm, profile, standing_ops)
    ref = silhouette(arm)
    frames = dump["frames"]
    frame_start = int(dump["frame_start"])
    frame_end = int(dump["frame_end"])
    action = cr.new_action(arm, "reaction")
    keyed = list(standing_ops.keys()) + ["CC_Base_Hip"]
    mixamo_span = float(dump.get("mixamo_head_hip_span") or 1.0)
    tgt_span = float((cr.world_head(arm, "CC_Base_Head") - cr.world_head(arm, "CC_Base_Hip")).length)
    height_scale = tgt_span / max(mixamo_span, 1e-6)
    start_sil = None
    end_sil = None
    peak_torso = 0.0
    peak_arm = 0.0
    max_from_down = 0.0
    min_elbow = 180.0
    foot_l = []
    foot_r = []
    for item in frames:
        frame = item["frame"]
        intra = item.get("intra_from_standing") or {}
        animated = build_animated_ops(standing_ops, intra, cfg)
        weight = motion_weight(frame, frame_start, frame_end, cfg["intro_frames"], cfg["outro_frames"])
        ops = lerp_ops(standing_ops, animated, weight)
        apply_ops(arm, profile, ops)
        enforce_arm_safety(arm, profile, ops, cfg["arm_safety"])
        dz = float(intra.get("hip_world_z", 0.0)) * height_scale * float(cfg["gains"]["vertical_compression_gain"]) * weight
        dz = clip(dz, cfg["hip_z_limit"])
        if "CC_Base_Hip" in arm.pose.bones:
            arm.pose.bones["CC_Base_Hip"].location = cr.world_delta_to_pose_location(arm, "CC_Base_Hip", Vector((0.0, 0.0, dz)))
        bpy.context.view_layer.update()
        sil = silhouette(arm)
        if frame == frame_start:
            start_sil = sil
        if frame == frame_end:
            end_sil = sil
        peak_torso = max(peak_torso, abs(sil["spine_from_up_deg"] - ref["spine_from_up_deg"]))
        peak_arm = max(peak_arm, abs(sil["L_upperarm_from_down"] - ref["L_upperarm_from_down"]), abs(sil["R_upperarm_from_down"] - ref["R_upperarm_from_down"]))
        max_from_down = max(max_from_down, sil["L_upperarm_from_down"], sil["R_upperarm_from_down"])
        min_elbow = min(min_elbow, sil["L_elbow_flex"], sil["R_elbow_flex"])
        foot_l.append(sil["L_foot"])
        foot_r.append(sil["R_foot"])
        for name in keyed:
            if name not in arm.pose.bones:
                continue
            pb = arm.pose.bones[name]
            pb.rotation_mode = "QUATERNION"
            pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)
            if name == "CC_Base_Hip":
                pb.keyframe_insert(data_path="location", frame=frame)
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    bpy.context.scene.frame_set(frame_start)
    setup_preview_cameras(arm)
    metrics = cr.evaluate_action(arm, mesh, action, "semantic_reaction_v1")
    dyn = classify_dynamic(metrics, peak_torso, peak_arm, max_from_down, min_elbow)
    out_dir = os.path.join(OUT_ROOT, fighter)
    cr.ensure_dir(out_dir)
    glb = os.path.join(out_dir, "%s_semantic_reaction_v1.glb" % fighter)
    blend = os.path.join(out_dir, "%s_semantic_reaction_v1.blend" % fighter)
    cr.export_glb(glb)
    try:
        cr.save_blend(blend)
    except Exception as exc:
        log("WARN blend %s" % exc)
        blend = ""
    start_c = continuity_row(start_sil, ref) if start_sil else {}
    end_c = continuity_row(end_sil, ref) if end_sil else {}

    def span(pts):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        return round(max(xs) - min(xs) + max(ys) - min(ys), 5) if pts else 0.0

    metrics.update({
        "character": fighter,
        "pipeline": "SEMANTIC_REACTION_V1",
        "animation_name": "reaction",
        "copies_raw_mixamo_quaternion": False,
        "legacy_axis_hack": False,
        "runtime_retarget": False,
        "wired_into_battle": False,
        "dynamic_classification": dyn,
        "gains": cfg["gains"],
        "envelopes_deg": cfg["envelope"],
        "arm_safety": cfg["arm_safety"],
        "standing_ops_canonical": standing_ops,
        "canonical_silhouette": ref,
        "start_continuity": start_c,
        "end_continuity": end_c,
        "peak_torso_dev": round(peak_torso, 3),
        "peak_upperarm_dev": round(peak_arm, 3),
        "max_upperarm_from_down": round(max_from_down, 3),
        "min_elbow_flex": round(min_elbow, 3),
        "l_foot_drift": span(foot_l),
        "r_foot_drift": span(foot_r),
        "texture_authority": cr.texture_authority(),
        "output_glb": glb.replace("\\", "/"),
        "output_blend": blend.replace("\\", "/") if blend else "",
        "output_glb_sha256": sha256_file(glb),
        "phases": dump.get("phases"),
    })
    cr.write_json(os.path.join(GENERATED, "%s_SEMANTIC_REACTION_V1_METRICS.json" % fighter.upper()), metrics)
    rt = cr.roundtrip_glb(glb, "semantic_reaction_v1")
    cr.write_json(os.path.join(GENERATED, "%s_SEMANTIC_REACTION_V1_ROUNDTRIP.json" % fighter.upper()), rt)
    healthy = (
        int(metrics.get("max_extreme_verts", 99)) == 0
        and float(metrics.get("max_limb_length_rel_error", 99)) == 0.0
        and int(rt.get("bone_count") or 0) == 101
        and float(metrics.get("max_root_xz", 99)) < 0.03
        and dyn == "HIT_REACTION"
        and start_c.get("L_upperarm_dev", 99) < 4.0
        and end_c.get("L_upperarm_dev", 99) < 4.0
        and metrics.get("legacy_axis_hack") is False
    )
    log("BAKE %s class %s healthy %s peakTorso %s peakArm %s startUA %s endUA %s bones %s" % (
        fighter, dyn, healthy, peak_torso, peak_arm,
        start_c.get("L_upperarm_dev"), end_c.get("L_upperarm_dev"), rt.get("bone_count"),
    ))
    return {"metrics": metrics, "roundtrip": rt, "healthy": healthy, "glb": glb, "dyn": dyn}


def verify_idles_untouched():
    auth = load_json(os.path.join(GENERATED, "APPROVED_IDLE_AUTHORITIES.json"))
    for fighter, row in auth["fighters"].items():
        digest = sha256_file(row["glb"])
        if digest != row["glb_sha256"]:
            raise RuntimeError("idle authority mutated: %s" % fighter)
    return True


def main():
    cr.ensure_dir(GENERATED)
    cr.ensure_dir(OUT_ROOT)
    verify_idles_untouched()
    dump = dump_reaction()
    results = {}
    for fighter in ("terere", "jaguarete"):
        log("==== BAKE %s ====" % fighter)
        results[fighter] = bake_fighter(fighter, dump)
    verify_idles_untouched()
    both = all(results[f]["healthy"] for f in results)
    one = any(results[f]["healthy"] for f in results)
    token = "SSK_SEMANTIC_REACTION_V1_READY_FOR_HUMAN_PLAYTEST"
    if not both:
        token = "SSK_SEMANTIC_REACTION_V1_PARTIAL" if one else "SSK_SEMANTIC_REACTION_V1_BLOCKED"
    run = {
        "pipeline": "SEMANTIC_REACTION_V1",
        "verdict_token": token,
        "wired_into_battle": False,
        "traditional_cob_used": False,
        "idle_assets_modified": False,
        "fighters": {
            name: {
                "healthy": row["healthy"],
                "dynamic_classification": row["dyn"],
                "glb": row["metrics"].get("output_glb"),
                "roundtrip_bones": row["roundtrip"].get("bone_count"),
                "technical_pass": row["metrics"].get("technical_pass"),
                "max_extreme_verts": row["metrics"].get("max_extreme_verts"),
                "max_root_xz": row["metrics"].get("max_root_xz"),
                "peak_torso_dev": row["metrics"].get("peak_torso_dev"),
                "start_continuity": row["metrics"].get("start_continuity"),
                "end_continuity": row["metrics"].get("end_continuity"),
            }
            for name, row in results.items()
        },
    }
    cr.write_json(os.path.join(GENERATED, "SEMANTIC_REACTION_V1_RUN.json"), run)
    log("VERDICT %s" % token)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
