# -*- coding: utf-8 -*-
"""Semantic Idle Polish V1 for Blender 2.83.

Re-keys Clean Rig V1 Idle from the frozen semantic standing_ops baseline.
Does not overwrite idle_benchmark_v1 outputs. Does not bake Traditional.
Does not modify Clean Rig V1 authority files.
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
OUT_ROOT = os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "semantic_idle_polish_v1")
SCREEN_DIR = os.path.join(GENERATED, "semantic_idle_polish_v1_screenshots")

# Tereré offsets are small and documented. Shared solver + per-fighter polish table.
# Jaguareté keeps baseline standing_ops; only light intra-clip foot stabilize.
POLISH = {
    "terere": {
        "preserve_standing": False,
        "spine_primary_override": 18.0,
        "spine_safe_limit": 24.0,
        "clavicle_primary": 3.0,
        "clavicle_secondary": 1.5,
        "upperarm_primary_add": 6.0,
        "elbow_primary_scale": 0.78,
        "knee_primary_scale": 0.55,
        "hand_primary": 4.0,
        "hand_secondary": 1.0,
        "channel_gain": 0.90,
        "head_intra_gain": 0.60,
        "torso_intra_gain": 0.75,
        "knee_intra_gain": 0.85,
        "shoulder_intra_gain": 0.90,
        "foot_stabilize": True,
        "foot_stabilize_gain": 0.55,
        "notes": [
            "Spine01 solver sat at SAFE +12 with 10.9 deg error vs Mixamo ~1 deg from up; rest is already ~14 deg. Polish raises SAFE to 24 and uses +18 to unhunch without a rigid military pose.",
            "Knee standing 40 * 0.55 reduces T-pose-delta squat that reads as compression on the short vessel body.",
            "Clavicle 8/5 -> 3/1.5 reduces shrug.",
            "Upperarm +6 deg lowering toward sides.",
            "Elbow 80 * 0.78 keeps a visible bend without Mixamo locked-forward hold.",
            "Hands 10/6 -> 4/1 for neutral wrists, less twist.",
            "Head intra 0.60 to avoid extra bob.",
        ],
    },
    "jaguarete": {
        "preserve_standing": True,
        "spine_primary_override": None,
        "clavicle_primary": None,
        "clavicle_secondary": None,
        "upperarm_primary_add": 0.0,
        "elbow_primary_scale": 1.0,
        "knee_primary_scale": 1.0,
        "hand_primary": None,
        "hand_secondary": None,
        "channel_gain": 1.0,
        "head_intra_gain": 1.0,
        "torso_intra_gain": 1.0,
        "knee_intra_gain": 1.0,
        "shoulder_intra_gain": 1.0,
        "foot_stabilize": True,
        "foot_stabilize_gain": 0.40,
        "notes": [
            "Standing_ops copied from frozen semantic baseline (almost production-ready).",
            "0.24 m max_foot_drift is vs T-pose rest because knees are standing-bent, not a walk cycle.",
            "Only intra-clip hip XY compensation to plant feet; amplitude not globally reduced.",
        ],
    },
}

CHANNEL_BONE = {
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
INVERT = set(["L_shoulder_lowering", "R_shoulder_lowering", "L_hand_from_down", "R_hand_from_down"])


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def intra_gain(channel, polish):
    if channel in ("head_lean",):
        return float(polish.get("head_intra_gain", 1.0))
    if channel in ("torso_lean",):
        return float(polish.get("torso_intra_gain", 1.0))
    if channel in ("L_knee_flexion", "R_knee_flexion"):
        return float(polish.get("knee_intra_gain", 1.0))
    if channel in ("L_shoulder_lowering", "R_shoulder_lowering"):
        return float(polish.get("shoulder_intra_gain", 1.0))
    return 1.0


def apply_polish_ops(standing_ops, polish):
    ops = copy.deepcopy(standing_ops)
    if polish.get("preserve_standing"):
        return ops
    if polish.get("spine_primary_override") is not None and "CC_Base_Spine01" in ops:
        ops["CC_Base_Spine01"]["primary"] = float(polish["spine_primary_override"])
        ops["CC_Base_Spine01"]["polish"] = "spine_primary_override"
    add = float(polish.get("upperarm_primary_add") or 0.0)
    scale = float(polish.get("elbow_primary_scale") or 1.0)
    for side in ("L", "R"):
        clav = "CC_Base_%s_Clavicle" % side
        if clav in ops and polish.get("clavicle_primary") is not None:
            ops[clav]["primary"] = float(polish["clavicle_primary"])
            ops[clav]["secondary"] = float(polish.get("clavicle_secondary") or 0.0)
            ops[clav]["polish"] = "clavicle_relax"
        arm = "CC_Base_%s_Upperarm" % side
        if arm in ops and add:
            ops[arm]["primary"] = cr.clamp_deg(arm, float(ops[arm]["primary"]) + add)
            ops[arm]["polish"] = "upperarm_lower"
        elbow = "CC_Base_%s_Forearm" % side
        if elbow in ops and scale != 1.0:
            ops[elbow]["primary"] = cr.clamp_deg(elbow, float(ops[elbow]["primary"]) * scale)
            ops[elbow]["polish"] = "elbow_soften"
        calf = "CC_Base_%s_Calf" % side
        knee_scale = float(polish.get("knee_primary_scale") or 1.0)
        if calf in ops and knee_scale != 1.0:
            ops[calf]["primary"] = cr.clamp_deg(calf, float(ops[calf]["primary"]) * knee_scale)
            ops[calf]["polish"] = "knee_uncompress"
        hand = "CC_Base_%s_Hand" % side
        if hand in ops and polish.get("hand_primary") is not None:
            ops[hand]["primary"] = float(polish["hand_primary"])
            ops[hand]["secondary"] = float(polish.get("hand_secondary") or 0.0)
            ops[hand]["polish"] = "hand_neutral"
    return ops


def mid_foot_xy(arm):
    left = cr.world_head(arm, "CC_Base_L_Foot")
    right = cr.world_head(arm, "CC_Base_R_Foot")
    return Vector(((left.x + right.x) * 0.5, (left.y + right.y) * 0.5, 0.0))


def silhouette_metrics(arm):
    l_hand = cr.world_head(arm, "CC_Base_L_Hand")
    r_hand = cr.world_head(arm, "CC_Base_R_Hand")
    l_sh = cr.world_head(arm, "CC_Base_L_Upperarm")
    r_sh = cr.world_head(arm, "CC_Base_R_Upperarm")
    hip = cr.world_head(arm, "CC_Base_Hip")
    up, _fwd, _right = cr.char_basis(arm)
    spine_lean = math.degrees(cr.bone_y_world(arm, "CC_Base_Spine01").angle(up))
    return {
        "spine_from_up_deg": round(spine_lean, 3),
        "L_upperarm_from_down": round(cr.from_down_deg(arm, "CC_Base_L_Upperarm"), 3),
        "R_upperarm_from_down": round(cr.from_down_deg(arm, "CC_Base_R_Upperarm"), 3),
        "L_elbow_flex": round(cr.flex_deg(arm, "CC_Base_L_Upperarm", "CC_Base_L_Forearm"), 3),
        "R_elbow_flex": round(cr.flex_deg(arm, "CC_Base_R_Upperarm", "CC_Base_R_Forearm"), 3),
        "L_hand_from_down": round(cr.from_down_deg(arm, "CC_Base_L_Hand"), 3),
        "R_hand_from_down": round(cr.from_down_deg(arm, "CC_Base_R_Hand"), 3),
        "hands_below_shoulders": bool(l_hand.z < l_sh.z - 0.02 and r_hand.z < r_sh.z - 0.02),
        "L_hand_x_from_hip": round(abs(l_hand.x - hip.x), 4),
        "R_hand_x_from_hip": round(abs(r_hand.x - hip.x), 4),
        "L_foot": cr.vec3(cr.world_head(arm, "CC_Base_L_Foot")),
        "R_foot": cr.vec3(cr.world_head(arm, "CC_Base_R_Foot")),
    }


def place_camera(arm, view):
    head_z = 1.6
    if "CC_Base_Head" in arm.pose.bones:
        head_z = max(1.2, float(cr.world_head(arm, "CC_Base_Head").z))
    dist = max(4.2, head_z * 2.15)
    look_z = head_z * 0.52
    if view == "front":
        loc = Vector((0.0, -dist, look_z + 0.15))
    elif view == "side":
        loc = Vector((dist, 0.0, look_z + 0.15))
    else:
        loc = Vector((dist * 0.72, -dist * 0.72, look_z + 0.15))
    cam = bpy.context.scene.camera
    if cam is None:
        cr.setup_camera(arm)
        cam = bpy.context.scene.camera
    cam.location = loc
    direction = Vector((0.0, 0.0, look_z)) - loc
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def try_render(path):
    cr.ensure_dir(os.path.dirname(path))
    scene = bpy.context.scene
    scene.render.image_settings.file_format = "PNG"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.filepath = path
    try:
        bpy.ops.render.render(write_still=True)
        return True
    except Exception as exc:
        print("WARN render", path, exc)
        return False


def bake_polished(character):
    polish = POLISH[character]
    cfg = cr.CHARACTERS[character]
    baseline_metrics = load_json(os.path.join(GENERATED, "%s_IDLE_SEMANTIC_CLEAN_V1_METRICS.json" % character.upper()))
    semantic = cr.mixamo_channels_from_file()
    cr.open_blend(cfg["blend"])
    bpy.context.scene.render.fps = 30
    tgt = cr.find_cc_arm()
    mesh = cr.skinned_mesh(tgt)
    if tgt is None or mesh is None:
        raise RuntimeError("clean rig missing for %s" % character)
    cr.disconnect(tgt)
    cr.clear_pose(tgt)
    bpy.context.view_layer.update()
    old_spine_safe = cr.SAFE.get("CC_Base_Spine01")
    if polish.get("spine_safe_limit"):
        cr.SAFE["CC_Base_Spine01"] = float(polish["spine_safe_limit"])
    profile = cr.profile_axes(tgt)
    standing_ops = apply_polish_ops(baseline_metrics["standing_ops"], polish)
    frames = semantic["frames"]
    frame_start = int(frames[0]["frame"])
    frame_end = int(frames[-1]["frame"])
    action = cr.new_action(tgt, "idle")
    keyed = list(standing_ops.keys()) + ["CC_Base_Hip"]
    plant = None
    hip_corr = []
    l_span = []
    r_span = []
    silhouettes = {}
    gain = float(polish.get("channel_gain") or 1.0)
    for item in frames:
        frame = item["frame"]
        ops = {}
        for bone, spec in standing_ops.items():
            ops[bone] = dict(spec)
        for channel, bone in CHANNEL_BONE.items():
            delta = float(item["intra_from_standing"].get(channel, 0.0)) * gain * intra_gain(channel, polish)
            if channel in INVERT:
                delta = -delta
            if abs(delta) > cr.INTRA_CLAMP:
                delta = cr.INTRA_CLAMP if delta > 0 else -cr.INTRA_CLAMP
            if bone not in ops:
                ops[bone] = {"primary": 0.0, "secondary": 0.0}
            ops[bone]["primary"] = cr.clamp_deg(bone, ops[bone]["primary"] + delta)
        cr.clear_pose(tgt)
        for bone, spec in ops.items():
            if bone in profile:
                cr.pose_ops(tgt, bone, profile[bone], spec["primary"], spec.get("secondary", 0.0))
        mixamo_span = float(semantic.get("mixamo_head_hip_span") or 1.0)
        tgt_span = float((cr.world_head(tgt, "CC_Base_Head") - cr.world_head(tgt, "CC_Base_Hip")).length)
        height_scale = tgt_span / max(mixamo_span, 1e-6)
        dz = float(item["intra_from_standing"].get("hip_world_z", 0.0)) * height_scale
        hip_loc = cr.world_up_to_hip_local(tgt, "CC_Base_Hip", dz)
        if "CC_Base_Hip" in tgt.pose.bones:
            tgt.pose.bones["CC_Base_Hip"].location = hip_loc
        bpy.context.view_layer.update()
        corr = 0.0
        if polish.get("foot_stabilize"):
            current = mid_foot_xy(tgt)
            if plant is None:
                plant = current.copy()
            else:
                delta = current - plant
                world_fix = Vector((
                    -delta.x * float(polish["foot_stabilize_gain"]),
                    -delta.y * float(polish["foot_stabilize_gain"]),
                    0.0,
                ))
                extra = cr.world_delta_to_pose_location(tgt, "CC_Base_Hip", world_fix)
                tgt.pose.bones["CC_Base_Hip"].location = hip_loc + extra
                bpy.context.view_layer.update()
                corr = extra.length
        hip_corr.append(corr)
        l_span.append(cr.world_head(tgt, "CC_Base_L_Foot").copy())
        r_span.append(cr.world_head(tgt, "CC_Base_R_Foot").copy())
        for name in keyed:
            if name not in tgt.pose.bones:
                continue
            pose_bone = tgt.pose.bones[name]
            pose_bone.rotation_mode = "QUATERNION"
            pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame)
            if name == "CC_Base_Hip":
                pose_bone.keyframe_insert(data_path="location", frame=frame)
        mid = int(0.5 * (frame_start + frame_end))
        if frame in (frame_start, mid, frame_end):
            silhouettes[str(frame)] = silhouette_metrics(tgt)
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end
    metrics = cr.evaluate_action(tgt, mesh, action, "semantic_polished")
    def foot_travel(points):
        if not points:
            return 0.0
        xs = [p.x for p in points]
        ys = [p.y for p in points]
        return math.sqrt((max(xs) - min(xs)) ** 2 + (max(ys) - min(ys)) ** 2)

    metrics.update({
        "character": character,
        "pipeline": "SEMANTIC_IDLE_POLISH_V1",
        "copies_raw_mixamo_quaternion": False,
        "legacy_axis_hack": False,
        "runtime_retarget": False,
        "proxy_idle": False,
        "standing_ops_baseline": baseline_metrics["standing_ops"],
        "standing_ops_polished": standing_ops,
        "polish": polish,
        "left_foot_intra_travel": round(foot_travel(l_span), 5),
        "right_foot_intra_travel": round(foot_travel(r_span), 5),
        "pelvis_correction_max": round(max(hip_corr) if hip_corr else 0.0, 5),
        "silhouette": silhouettes,
        "texture_authority": cr.texture_authority(),
        "baseline_sha256_glb": sha256_file(os.path.join(
            cfg["out_dir"], "%s_idle_semantic_clean_v1.glb" % character
        )),
    })
    out_dir = os.path.join(OUT_ROOT, character)
    cr.ensure_dir(out_dir)
    stem = "%s_idle_semantic_polished_v1" % character
    glb = os.path.join(out_dir, stem + ".glb")
    blend = os.path.join(out_dir, stem + ".blend")
    if tgt.animation_data is None:
        tgt.animation_data_create()
    tgt.animation_data.action = action
    bpy.context.scene.frame_set(frame_start)
    cr.export_glb(glb)
    cr.setup_camera(tgt)
    screen = {}
    bpy.context.scene.frame_set(int(0.5 * (frame_start + frame_end)))
    bpy.context.view_layer.update()
    for view in ("front", "three_quarter", "side"):
        place_camera(tgt, view)
        png = os.path.join(SCREEN_DIR, "%s_%s.png" % (character, view))
        screen[view] = png.replace("\\", "/") if try_render(png) else None
    metrics["screenshots"] = screen
    try:
        cr.save_blend(blend)
    except Exception as exc:
        print("WARN blend", exc)
        blend = ""
    metrics["output_glb"] = glb.replace("\\", "/")
    metrics["output_blend"] = blend.replace("\\", "/") if blend else ""
    metrics["output_glb_sha256"] = sha256_file(glb)
    cr.write_json(os.path.join(GENERATED, "%s_IDLE_SEMANTIC_POLISHED_V1_METRICS.json" % character.upper()), metrics)
    if old_spine_safe is not None:
        cr.SAFE["CC_Base_Spine01"] = old_spine_safe

    rt = cr.roundtrip_glb(glb, "semantic_polished")
    cr.write_json(os.path.join(GENERATED, "%s_IDLE_SEMANTIC_POLISHED_V1_ROUNDTRIP.json" % character.upper()), rt)
    print("POLISH", character, "pass", metrics.get("technical_pass"), "class", metrics.get("pose_classification"),
          "vol", metrics.get("max_volume_ratio"), "ext", metrics.get("max_extreme_verts"),
          "foot", metrics.get("max_foot_drift"), "intraL", metrics.get("left_foot_intra_travel"))
    return {"metrics": metrics, "roundtrip": rt, "glb": glb}


def parse_chars():
    chars = ("terere", "jaguarete")
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if "--character" in argv:
        idx = argv.index("--character")
        if idx + 1 < len(argv) and argv[idx + 1] in ("terere", "jaguarete"):
            chars = (argv[idx + 1],)
    return chars


def main():
    cr.ensure_dir(GENERATED)
    results = {}
    for character in parse_chars():
        print("==== POLISH", character, "====")
        results[character] = bake_polished(character)
    summary = {
        "pipeline": "SEMANTIC_IDLE_POLISH_V1",
        "overwrote_idle_benchmark_v1": False,
        "overwrote_clean_rig_v1": False,
        "fighters": {},
    }
    prev_path = os.path.join(GENERATED, "SEMANTIC_IDLE_POLISH_V1_RUN.json")
    if os.path.isfile(prev_path):
        try:
            summary["fighters"].update(load_json(prev_path).get("fighters") or {})
        except Exception:
            pass
    for character, row in results.items():
        m = row["metrics"]
        rt = row["roundtrip"]
        summary["fighters"][character] = {
            "technical_pass": m.get("technical_pass"),
            "pose_classification": m.get("pose_classification"),
            "max_volume_ratio": m.get("max_volume_ratio"),
            "max_extreme_verts": m.get("max_extreme_verts"),
            "max_limb_length_rel_error": m.get("max_limb_length_rel_error"),
            "max_root_xz": m.get("max_root_xz"),
            "max_foot_drift": m.get("max_foot_drift"),
            "left_foot_intra_travel": m.get("left_foot_intra_travel"),
            "right_foot_intra_travel": m.get("right_foot_intra_travel"),
            "pelvis_correction_max": m.get("pelvis_correction_max"),
            "roundtrip_ok": bool(rt.get("ok")),
            "roundtrip_bones": rt.get("bone_count"),
            "glb": m.get("output_glb"),
        }
    cr.write_json(os.path.join(GENERATED, "SEMANTIC_IDLE_POLISH_V1_RUN.json"), summary)
    print("POLISH_SUMMARY", json.dumps(summary["fighters"], indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
