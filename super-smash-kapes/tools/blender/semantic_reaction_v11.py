# -*- coding: utf-8 -*-
"""Semantic Reaction V1.1 — torso/hip/head impact readability overlay.

Freezes Reaction V1 arm/hand/foot logic. Adds pitch-only recoil candidates.
Does not overwrite V1, idles, Clean Rig, battle, or other clips.
"""
from __future__ import print_function

import math
import os
import sys
import traceback

import bpy
from mathutils import Matrix, Quaternion, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
import clean_rig_idle_retarget_benchmark_v1 as cr
import semantic_reaction_v1 as v1

PROJECT_ROOT = cr.PROJECT_ROOT
GENERATED = cr.GENERATED
OUT_ROOT = os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "semantic_reaction_v11")
DUMP_PATH = os.path.join(GENERATED, "REACTION_FBX_SEMANTIC_SOURCE_DUMP.json")
FREEZE_PATH = os.path.join(GENERATED, "FROZEN_SEMANTIC_REACTION_V1.json")

CANDIDATES = {
    "a": {
        "label": "LIGHT",
        "torso_peak_deg": 6.0,
        "hip_share": 0.38,
        "spine_share": 0.62,
        "head_share": 0.42,
        "head_lag_frames": 3,
        "knee_extra_deg": 0.8,
        "compress_extra": 0.012,
        "band": [4.5, 7.5],
    },
    "b": {
        "label": "MEDIUM",
        "torso_peak_deg": 9.5,
        "hip_share": 0.40,
        "spine_share": 0.60,
        "head_share": 0.40,
        "head_lag_frames": 3,
        "knee_extra_deg": 1.5,
        "compress_extra": 0.018,
        "band": [7.5, 11.5],
    },
    "c": {
        "label": "STRONG",
        "torso_peak_deg": 13.5,
        "hip_share": 0.42,
        "spine_share": 0.58,
        "head_share": 0.38,
        "head_lag_frames": 3,
        "knee_extra_deg": 2.2,
        "compress_extra": 0.024,
        "band": [11.5, 16.0],
    },
}


def log(msg):
    print(msg)
    sys.stdout.flush()


HIP_EXTRA_MAX = 14.0
SPINE_EXTRA_MAX = 32.0
HEAD_EXTRA_MAX = 10.0


def _clip_extra(value, limit):
    if value > limit:
        return limit
    if value < -limit:
        return -limit
    return value


def apply_hip_pitch(arm, hip_info, degrees):
    if hip_info is None or "CC_Base_Hip" not in arm.pose.bones:
        return
    pose_bone = arm.pose.bones["CC_Base_Hip"]
    pose_bone.rotation_mode = "QUATERNION"
    axis = Vector(hip_info["primary_axis_vec"])
    if axis.length < 1e-6:
        return
    pose_bone.rotation_quaternion = Quaternion(
        axis.normalized(),
        math.radians(float(hip_info["sign"]) * float(degrees)),
    )


def apply_overlay(arm, profile, ops, hip_info, hip_deg, spine_extra, head_extra):
    apply_hip_pitch(arm, hip_info, _clip_extra(hip_deg, HIP_EXTRA_MAX))
    if abs(spine_extra) > 1e-4 and "CC_Base_Spine01" in profile and "CC_Base_Spine01" in ops:
        spec = ops["CC_Base_Spine01"]
        cr.pose_ops(
            arm,
            "CC_Base_Spine01",
            profile["CC_Base_Spine01"],
            float(spec.get("primary") or 0.0) + _clip_extra(spine_extra, SPINE_EXTRA_MAX),
            float(spec.get("secondary") or 0.0),
        )
    if abs(head_extra) > 1e-4 and "CC_Base_Head" in profile and "CC_Base_Head" in ops:
        spec = ops["CC_Base_Head"]
        cr.pose_ops(
            arm,
            "CC_Base_Head",
            profile["CC_Base_Head"],
            float(spec.get("primary") or 0.0) + _clip_extra(head_extra, HEAD_EXTRA_MAX),
            float(spec.get("secondary") or 0.0),
        )
    bpy.context.view_layer.update()


def _bone_snap(arm, names):
    out = {}
    for name in names:
        if name not in arm.pose.bones:
            continue
        pose_bone = arm.pose.bones[name]
        pose_bone.rotation_mode = "QUATERNION"
        out[name] = (pose_bone.rotation_quaternion.copy(), pose_bone.location.copy())
    return out


def _restore_snap(arm, snap):
    for name, pair in snap.items():
        pose_bone = arm.pose.bones[name]
        pose_bone.rotation_mode = "QUATERNION"
        pose_bone.rotation_quaternion = pair[0]
        pose_bone.location = pair[1]
    bpy.context.view_layer.update()


def choose_hip_pitch(arm):
    """Pick Hip local axis by actual spine-lean change. rotate_local is the known-working setter."""
    names = ("CC_Base_Hip", "CC_Base_Spine01", "CC_Base_Head")
    snap = _bone_snap(arm, names)
    hip_loc = arm.pose.bones["CC_Base_Hip"].location.copy() if "CC_Base_Hip" in arm.pose.bones else Vector((0, 0, 0))
    up, fwd, _right = cr.char_basis(arm)
    rest_fwd = fwd.copy()
    rest_lean = math.degrees(cr.bone_y_world(arm, "CC_Base_Spine01").angle(up))
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
    world_z = Vector((0.0, 0.0, 1.0))
    rest_world = math.degrees(up.angle(world_z))
    rest_fwd_xy = Vector((rest_fwd.x, rest_fwd.y, 0.0))
    for name, axis, sign in options:
        _restore_snap(arm, snap)
        if "CC_Base_Hip" in arm.pose.bones:
            arm.pose.bones["CC_Base_Hip"].location = hip_loc.copy()
        cr.rotate_local(arm, "CC_Base_Hip", axis, sign * 10.0)
        arm.pose.bones["CC_Base_Hip"].location = hip_loc.copy()
        bpy.context.view_layer.update()
        up2, fwd2, _r2 = cr.char_basis(arm)
        lean = math.degrees(cr.bone_y_world(arm, "CC_Base_Spine01").angle(up2))
        world_tilt = math.degrees(up2.angle(world_z))
        yaw = 0.0
        fwd_xy = Vector((fwd2.x, fwd2.y, 0.0))
        if rest_fwd_xy.length > 1e-6 and fwd_xy.length > 1e-6:
            yaw = math.degrees(rest_fwd_xy.angle(fwd_xy))
        elif rest_fwd.length > 1e-6 and fwd2.length > 1e-6:
            yaw = math.degrees(fwd2.angle(rest_fwd))
        dlean = lean - rest_lean
        dworld = world_tilt - rest_world
        score = dworld - (2.2 * yaw)
        row = {
            "name": name,
            "primary_axis_vec": list(axis),
            "sign": sign,
            "secondary_axis_vec": [0.0, 0.0, 1.0] if axis[2] == 0.0 else [1.0, 0.0, 0.0],
            "secondary_sign": 1.0,
            "kind": "flex_hip",
            "dlean": round(dlean, 4),
            "dworld": round(dworld, 4),
            "yaw": round(yaw, 4),
            "score": round(score, 4),
        }
        log("HIP_AXIS_CAND %s dlean %s dworld %s yaw %s" % (name, row["dlean"], row["dworld"], row["yaw"]))
        if score > best_score:
            best_score = score
            best = row
    _restore_snap(arm, snap)
    if "CC_Base_Hip" in arm.pose.bones:
        arm.pose.bones["CC_Base_Hip"].location = hip_loc.copy()
    bpy.context.view_layer.update()
    if best is None:
        best = {
            "name": "local_x+",
            "primary_axis_vec": [1.0, 0.0, 0.0],
            "sign": 1.0,
            "secondary_axis_vec": [0.0, 0.0, 1.0],
            "secondary_sign": 1.0,
            "kind": "flex_hip",
            "dlean": 0.0,
            "dworld": 0.0,
            "yaw": 0.0,
            "score": 0.0,
        }
    log("PITCH_AXIS %s dlean %s dworld %s yaw %s" % (
        best["name"], best.get("dlean"), best.get("dworld"), best["yaw"],
    ))
    return best


def world_torso_deg(arm):
    up, _fwd, _right = cr.char_basis(arm)
    return math.degrees(up.angle(Vector((0.0, 0.0, 1.0))))


def recoil_shape_map(dump):
    frames = dump["frames"]
    raw = []
    for item in frames:
        intra = item.get("intra_from_standing") or {}
        score = (
            abs(float(intra.get("torso_lean") or 0.0))
            + abs(float(intra.get("torso_pitch") or 0.0)) * 0.35
            + float(intra.get("hip_horiz") or 0.0) * 20.0
        )
        raw.append(score)
    peak = max(raw) if raw else 1.0
    if peak < 1e-6:
        peak = 1.0
    by_frame = {}
    for item, score in zip(frames, raw):
        by_frame[int(item["frame"])] = score / peak
    return by_frame


def shape_at(shapes, frame, start, end):
    if frame < start:
        return 0.0
    if frame > end:
        return 0.0
    return float(shapes.get(int(frame), 0.0))


def pose_v1_frame(arm, profile, standing_ops, cfg, intra, weight, height_scale, extra_knee, extra_dz):
    animated = v1.build_animated_ops(standing_ops, intra, cfg)
    ops = v1.lerp_ops(standing_ops, animated, weight)
    if extra_knee:
        for side in ("L", "R"):
            calf = "CC_Base_%s_Calf" % side
            if calf in ops:
                ops[calf]["primary"] = cr.clamp_deg(calf, float(ops[calf]["primary"]) + extra_knee)
    v1.apply_ops(arm, profile, ops)
    v1.enforce_arm_safety(arm, profile, ops, cfg["arm_safety"])
    dz = float(intra.get("hip_world_z", 0.0)) * height_scale * float(cfg["gains"]["vertical_compression_gain"]) * weight
    dz = v1.clip(dz, cfg["hip_z_limit"])
    dz += extra_dz
    dz = v1.clip(dz, cfg["hip_z_limit"])
    if "CC_Base_Hip" in arm.pose.bones:
        arm.pose.bones["CC_Base_Hip"].location = cr.world_delta_to_pose_location(
            arm, "CC_Base_Hip", Vector((0.0, 0.0, dz))
        )
    bpy.context.view_layer.update()
    return ops


def spine_world_ratio(arm, profile, standing_ops):
    v1.apply_ops(arm, profile, standing_ops)
    bpy.context.view_layer.update()
    ref_w = world_torso_deg(arm)
    spec = standing_ops["CC_Base_Spine01"]
    primary = float(spec.get("primary") or 0.0)
    secondary = float(spec.get("secondary") or 0.0)
    best = (0.2, 1.0)
    best_delta = -1e9
    for sign in (1.0, -1.0):
        v1.apply_ops(arm, profile, standing_ops)
        cr.pose_ops(
            arm,
            "CC_Base_Spine01",
            profile["CC_Base_Spine01"],
            primary + sign * 10.0,
            secondary,
        )
        bpy.context.view_layer.update()
        delta = world_torso_deg(arm) - ref_w
        if delta > best_delta:
            best_delta = delta
            best = (delta / (sign * 10.0), sign)
    v1.apply_ops(arm, profile, standing_ops)
    bpy.context.view_layer.update()
    log("SPINE_RATIO %s sign %s" % (round(best[0], 4), best[1]))
    return best


def calibrate(arm, profile, standing_ops, cfg, dump, cand, hip_info, height_scale, shapes):
    frames = dump["frames"]
    peak_frame = int(dump["phases"]["peak_frame"])
    frame_start = int(dump["frame_start"])
    frame_end = int(dump["frame_end"])
    peak_item = None
    for item in frames:
        if int(item["frame"]) == peak_frame:
            peak_item = item
            break
    if peak_item is None:
        peak_item = frames[len(frames) // 4]
    intra = peak_item.get("intra_from_standing") or {}
    weight = v1.motion_weight(peak_frame, frame_start, frame_end, cfg["intro_frames"], cfg["outro_frames"])
    v1.apply_ops(arm, profile, standing_ops)
    bpy.context.view_layer.update()
    ref = v1.silhouette(arm)
    ref_world = world_torso_deg(arm)
    pose_v1_frame(arm, profile, standing_ops, cfg, intra, weight, height_scale, 0.0, 0.0)
    base_world = world_torso_deg(arm)
    base_dev = abs(base_world - ref_world)
    hip_ratio = abs(float(hip_info.get("dworld") or 0.0)) / 10.0
    if hip_ratio < 0.15:
        hip_ratio = 1.0
    spine_ratio, spine_sign = spine_world_ratio(arm, profile, standing_ops)
    if abs(spine_ratio) < 0.05:
        spine_ratio = 0.2
        spine_sign = 1.0
    needed = max(0.2, float(cand["torso_peak_deg"]) - base_dev)
    hip_peak = needed * float(cand["hip_share"]) / hip_ratio
    spine_peak = needed * float(cand["spine_share"]) / abs(spine_ratio) * spine_sign
    head_peak = needed * float(cand["head_share"]) / max(abs(spine_ratio) * 1.15, 0.12) * spine_sign
    hip_peak = _clip_extra(hip_peak, HIP_EXTRA_MAX)
    spine_peak = _clip_extra(spine_peak, SPINE_EXTRA_MAX)
    head_peak = _clip_extra(head_peak, HEAD_EXTRA_MAX)
    log("CALIB baseW %s needed %s hip %s spine %s head %s" % (
        round(base_dev, 3), round(needed, 3), round(hip_peak, 3), round(spine_peak, 3), round(head_peak, 3),
    ))
    return {
        "base_peak_torso": round(base_dev, 3),
        "overlay_gain": 1.0,
        "sign": 1.0,
        "hip_peak": round(hip_peak, 4),
        "spine_peak": round(spine_peak, 4),
        "head_peak": round(head_peak, 4),
        "hip_ratio": round(hip_ratio, 4),
        "spine_ratio": round(spine_ratio, 4),
        "ref_spine": ref["spine_from_up_deg"],
        "ref_world_torso": round(ref_world, 3),
        "method": "world_tilt_ratio_hip_plus_spine",
    }


def bake_candidate(fighter, dump, cand_id, cand, freeze_row):
    cfg = v1.FIGHTERS[fighter]
    standing_ops = v1.standing_ops_for(fighter)
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
    v1.apply_ops(arm, profile, standing_ops)
    bpy.context.view_layer.update()
    ref = v1.silhouette(arm)
    _up0, rest_forward, _r0 = cr.char_basis(arm)
    rest_forward = rest_forward.copy()
    ref_head = math.degrees(cr.bone_y_world(arm, "CC_Base_Head").angle(_up0))
    ref_world = world_torso_deg(arm)
    axis_info = choose_hip_pitch(arm)
    hip_info = {
        "primary_axis_vec": axis_info["primary_axis_vec"],
        "sign": axis_info["sign"],
        "secondary_axis_vec": axis_info["secondary_axis_vec"],
        "secondary_sign": axis_info["secondary_sign"],
        "kind": "flex_hip",
        "dworld": axis_info.get("dworld", 10.0),
        "name": axis_info.get("name"),
    }
    frames = dump["frames"]
    frame_start = int(dump["frame_start"])
    frame_end = int(dump["frame_end"])
    shapes = recoil_shape_map(dump)
    mixamo_span = float(dump.get("mixamo_head_hip_span") or 1.0)
    tgt_span = float((cr.world_head(arm, "CC_Base_Head") - cr.world_head(arm, "CC_Base_Hip")).length)
    height_scale = tgt_span / max(mixamo_span, 1e-6)
    calib = calibrate(arm, profile, standing_ops, cfg, dump, cand, hip_info, height_scale, shapes)
    hip_peak = float(calib["hip_peak"])
    spine_peak = float(calib["spine_peak"])
    head_peak = float(calib["head_peak"])
    action = cr.new_action(arm, "reaction")
    keyed = list(standing_ops.keys()) + ["CC_Base_Hip"]
    start_sil = None
    end_sil = None
    peak_torso = 0.0
    peak_torso_char = 0.0
    peak_head = 0.0
    peak_arm = 0.0
    max_from_down = 0.0
    min_elbow = 180.0
    max_yaw = 0.0
    foot_l = []
    foot_r = []
    lag = int(cand["head_lag_frames"])
    for item in frames:
        frame = int(item["frame"])
        intra = item.get("intra_from_standing") or {}
        weight = v1.motion_weight(frame, frame_start, frame_end, cfg["intro_frames"], cfg["outro_frames"])
        body_shape = shape_at(shapes, frame, frame_start, frame_end) * weight
        head_shape = shape_at(shapes, frame - lag, frame_start, frame_end) * weight
        extra_knee = float(cand["knee_extra_deg"]) * body_shape
        extra_dz = -abs(float(cand["compress_extra"])) * body_shape
        ops = pose_v1_frame(arm, profile, standing_ops, cfg, intra, weight, height_scale, extra_knee, extra_dz)
        hip_deg = hip_peak * body_shape
        spine_deg = spine_peak * body_shape
        head_unit = head_peak * head_shape
        apply_overlay(arm, profile, ops, hip_info, hip_deg, spine_deg, head_unit)
        v1.enforce_arm_safety(arm, profile, ops, cfg["arm_safety"])
        bpy.context.view_layer.update()
        sil = v1.silhouette(arm)
        if frame == frame_start:
            start_sil = sil
        if frame == frame_end:
            end_sil = sil
        peak_torso = max(peak_torso, abs(world_torso_deg(arm) - ref_world))
        peak_torso_char = max(peak_torso_char, abs(sil["spine_from_up_deg"] - ref["spine_from_up_deg"]))
        head_lean = math.degrees(cr.bone_y_world(arm, "CC_Base_Head").angle(cr.char_basis(arm)[0]))
        peak_head = max(peak_head, abs(head_lean - ref_head))
        peak_arm = max(
            peak_arm,
            abs(sil["L_upperarm_from_down"] - ref["L_upperarm_from_down"]),
            abs(sil["R_upperarm_from_down"] - ref["R_upperarm_from_down"]),
        )
        max_from_down = max(max_from_down, sil["L_upperarm_from_down"], sil["R_upperarm_from_down"])
        min_elbow = min(min_elbow, sil["L_elbow_flex"], sil["R_elbow_flex"])
        _up, fwd, _rr = cr.char_basis(arm)
        rest_xy = Vector((rest_forward.x, rest_forward.y, 0.0))
        fwd_xy = Vector((fwd.x, fwd.y, 0.0))
        if rest_xy.length > 1e-6 and fwd_xy.length > 1e-6:
            max_yaw = max(max_yaw, math.degrees(fwd_xy.angle(rest_xy)))
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
    v1.setup_preview_cameras(arm)
    metrics = cr.evaluate_action(arm, mesh, action, "semantic_reaction_v11_%s" % cand_id)
    dyn = v1.classify_dynamic(metrics, peak_torso, peak_arm, max_from_down, min_elbow)
    out_dir = os.path.join(OUT_ROOT, fighter)
    cr.ensure_dir(out_dir)
    glb = os.path.join(out_dir, "%s_semantic_reaction_v11_%s.glb" % (fighter, cand_id))
    blend = os.path.join(out_dir, "%s_semantic_reaction_v11_%s.blend" % (fighter, cand_id))
    cr.export_glb(glb)
    try:
        cr.save_blend(blend)
    except Exception as exc:
        log("WARN blend %s" % exc)
        blend = ""
    start_c = v1.continuity_row(start_sil, ref) if start_sil else {}
    end_c = v1.continuity_row(end_sil, ref) if end_sil else {}

    def span(pts):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        return round(max(xs) - min(xs) + max(ys) - min(ys), 5) if pts else 0.0

    v1_from_down = float(freeze_row.get("max_upperarm_from_down") or 90.0)
    arm_preserved = max_from_down <= max(v1_from_down + 8.0, cfg["arm_safety"]["max_from_down"])
    in_band = cand["band"][0] <= peak_torso <= cand["band"][1]
    metrics.update({
        "character": fighter,
        "pipeline": "SEMANTIC_REACTION_V11",
        "candidate": cand_id,
        "candidate_label": cand["label"],
        "animation_name": "reaction",
        "copies_raw_mixamo_quaternion": False,
        "legacy_axis_hack": False,
        "runtime_retarget": False,
        "wired_into_battle": False,
        "v1_frozen": True,
        "arm_ops_from": "SEMANTIC_REACTION_V1",
        "dynamic_classification": dyn,
        "gains_v1": cfg["gains"],
        "overlay": {
            "torso_peak_target_deg": cand["torso_peak_deg"],
            "hip_share": cand["hip_share"],
            "spine_share": cand["spine_share"],
            "head_share": cand["head_share"],
            "head_lag_frames": cand["head_lag_frames"],
            "knee_extra_deg": cand["knee_extra_deg"],
            "compress_extra": cand["compress_extra"],
            "calibration": calib,
            "pitch_axis": axis_info,
            "method": "hip_local_pose_ops_plus_unclamped_spine",
        },
        "standing_ops_canonical": standing_ops,
        "canonical_silhouette": ref,
        "start_continuity": start_c,
        "end_continuity": end_c,
        "peak_torso_dev": round(peak_torso, 3),
        "peak_torso_char_rel": round(peak_torso_char, 3),
        "peak_head_follow": round(peak_head, 3),
        "peak_upperarm_dev": round(peak_arm, 3),
        "max_upperarm_from_down": round(max_from_down, 3),
        "min_elbow_flex": round(min_elbow, 3),
        "max_yaw_from_canonical": round(max_yaw, 3),
        "l_foot_drift": span(foot_l),
        "r_foot_drift": span(foot_r),
        "arm_preserved_vs_v1": bool(arm_preserved),
        "torso_in_target_band": bool(in_band),
        "texture_authority": cr.texture_authority(),
        "output_glb": glb.replace("\\", "/"),
        "output_blend": blend.replace("\\", "/") if blend else "",
        "output_glb_sha256": v1.sha256_file(glb),
        "phases": dump.get("phases"),
    })
    cr.write_json(os.path.join(GENERATED, "%s_SEMANTIC_REACTION_V11_%s_METRICS.json" % (fighter.upper(), cand_id.upper())), metrics)
    rt = cr.roundtrip_glb(glb, "semantic_reaction_v11_%s" % cand_id)
    cr.write_json(os.path.join(GENERATED, "%s_SEMANTIC_REACTION_V11_%s_ROUNDTRIP.json" % (fighter.upper(), cand_id.upper())), rt)
    healthy = (
        int(metrics.get("max_extreme_verts", 99)) == 0
        and float(metrics.get("max_limb_length_rel_error", 99)) == 0.0
        and int(rt.get("bone_count") or 0) == 101
        and float(metrics.get("max_root_xz", 99)) < 0.03
        and dyn == "HIT_REACTION"
        and start_c.get("L_upperarm_dev", 99) < 4.0
        and end_c.get("L_upperarm_dev", 99) < 4.0
        and max_yaw < 18.0
        and arm_preserved
        and metrics.get("legacy_axis_hack") is False
    )
    log("BAKE %s %s class %s healthy %s peakTorso %s band %s peakArm %s fromDown %s yaw %s" % (
        fighter, cand_id, dyn, healthy, round(peak_torso, 3), in_band, round(peak_arm, 3),
        round(max_from_down, 3), round(max_yaw, 3),
    ))
    return {"metrics": metrics, "roundtrip": rt, "healthy": healthy, "dyn": dyn, "glb": glb}


def verify_frozen():
    freeze = v1.load_json(FREEZE_PATH)
    for fighter, row in freeze["fighters"].items():
        digest = v1.sha256_file(row["glb"])
        if digest != row["glb_sha256"]:
            raise RuntimeError("Reaction V1 mutated: %s" % fighter)
    idle = v1.load_json(os.path.join(GENERATED, "APPROVED_IDLE_AUTHORITIES.json"))
    for fighter, row in idle["fighters"].items():
        digest = v1.sha256_file(row["glb"])
        if digest != row["glb_sha256"]:
            raise RuntimeError("idle authority mutated: %s" % fighter)
    return freeze


def probe():
    freeze = verify_frozen()
    dump = v1.load_json(DUMP_PATH)
    fighter = "terere"
    cfg = v1.FIGHTERS[fighter]
    standing_ops = v1.standing_ops_for(fighter)
    cr.open_blend(cr.CHARACTERS[fighter]["blend"])
    arm = cr.find_cc_arm()
    cr.disconnect(arm)
    cr.clear_pose(arm)
    bpy.context.view_layer.update()
    profile = cr.profile_axes(arm)
    v1.apply_ops(arm, profile, standing_ops)
    bpy.context.view_layer.update()
    ref = v1.silhouette(arm)
    hip_info = choose_hip_pitch(arm)
    ref_world = world_torso_deg(arm)
    apply_hip_pitch(arm, hip_info, 10.0)
    bpy.context.view_layer.update()
    hip10 = v1.silhouette(arm)
    hip10w = world_torso_deg(arm)
    log("PROBE hip10 char %s world %s dchar %s dworld %s" % (
        hip10["spine_from_up_deg"],
        round(hip10w, 3),
        round(abs(hip10["spine_from_up_deg"] - ref["spine_from_up_deg"]), 3),
        round(abs(hip10w - ref_world), 3),
    ))
    v1.apply_ops(arm, profile, standing_ops)
    bpy.context.view_layer.update()
    spec = standing_ops["CC_Base_Spine01"]
    cr.pose_ops(
        arm,
        "CC_Base_Spine01",
        profile["CC_Base_Spine01"],
        float(spec.get("primary") or 0.0) + 15.0,
        float(spec.get("secondary") or 0.0),
    )
    bpy.context.view_layer.update()
    spine15 = v1.silhouette(arm)
    spine15w = world_torso_deg(arm)
    log("PROBE spine15 char %s world %s dchar %s dworld %s" % (
        spine15["spine_from_up_deg"],
        round(spine15w, 3),
        round(abs(spine15["spine_from_up_deg"] - ref["spine_from_up_deg"]), 3),
        round(abs(spine15w - ref_world), 3),
    ))
    log("PROBE freeze %s" % freeze["authority"])


def main():
    if "--probe" in sys.argv:
        probe()
        return
    cr.ensure_dir(GENERATED)
    cr.ensure_dir(OUT_ROOT)
    freeze = verify_frozen()
    dump = v1.load_json(DUMP_PATH)
    results = {}
    for fighter in ("terere", "jaguarete"):
        results[fighter] = {}
        for cand_id, cand in (("a", CANDIDATES["a"]), ("b", CANDIDATES["b"]), ("c", CANDIDATES["c"])):
            log("==== BAKE %s %s %s ====" % (fighter, cand_id, cand["label"]))
            results[fighter][cand_id] = bake_candidate(fighter, dump, cand_id, cand, freeze["fighters"][fighter])
    verify_frozen()
    all_healthy = all(results[f][c]["healthy"] for f in results for c in results[f])
    token = "SSK_SEMANTIC_REACTION_V11_READY_FOR_HUMAN_SELECTION" if all_healthy else "SSK_SEMANTIC_REACTION_V11_PARTIAL"
    run = {
        "pipeline": "SEMANTIC_REACTION_V11",
        "verdict_token": token,
        "wired_into_battle": False,
        "auto_selected": False,
        "v1_frozen": True,
        "traditional_cob_used": False,
        "idle_assets_modified": False,
        "reaction_v1_modified": False,
        "candidates": CANDIDATES,
        "fighters": {
            name: {
                cid: {
                    "healthy": row["healthy"],
                    "dynamic_classification": row["dyn"],
                    "glb": row["metrics"].get("output_glb"),
                    "peak_torso_dev": row["metrics"].get("peak_torso_dev"),
                    "torso_in_target_band": row["metrics"].get("torso_in_target_band"),
                    "arm_preserved_vs_v1": row["metrics"].get("arm_preserved_vs_v1"),
                    "max_root_xz": row["metrics"].get("max_root_xz"),
                    "start_continuity": row["metrics"].get("start_continuity"),
                    "end_continuity": row["metrics"].get("end_continuity"),
                    "roundtrip_bones": row["roundtrip"].get("bone_count"),
                }
                for cid, row in by_cand.items()
            }
            for name, by_cand in results.items()
        },
    }
    cr.write_json(os.path.join(GENERATED, "SEMANTIC_REACTION_V11_RUN.json"), run)
    log("VERDICT %s" % token)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
