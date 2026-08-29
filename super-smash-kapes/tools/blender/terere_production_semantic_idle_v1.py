# -*- coding: utf-8 -*-
"""Tereré Production Semantic Idle V1 for Blender 2.83.

Canonical center = Pose B Game Ready.
Mixamo Idle supplies filtered intra-idle deltas only.
Does not copy Mixamo absolute stance. Does not touch Jaguareté.
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
OUT_DIR = os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "production_semantic_idle_v1", "terere")
POSE_B_GLB = os.path.join(
    PROJECT_ROOT, "assets", "fighters", "processed", "idle_pose_redesign_v1",
    "terere", "terere_idle_pose_redesign_v1_b.glb",
)
POSE_B_BLEND = os.path.splitext(POSE_B_GLB)[0] + ".blend"
JAG_GLB = os.path.join(
    PROJECT_ROOT, "assets", "fighters", "processed", "semantic_idle_polish_v1",
    "jaguarete", "jaguarete_idle_semantic_polished_v1.glb",
)

# Documented per-channel gains. Mixamo intra is multiplied by these, then envelope-clamped.
TERERE_IDLE_SEMANTIC_V1 = {
    "torso_sway_gain": 0.45,
    "spine_gain": 0.38,
    "shoulder_gain": 0.32,
    "upperarm_gain": 0.22,
    "elbow_gain": 0.30,
    "wrist_gain": 0.10,
    "head_gain": 0.32,
    "hip_vertical_gain": 0.40,
    "knee_gain": 0.16,
}

ENVELOPE_DEG = {
    "upperarm": 6.5,
    "elbow": 6.5,
    "wrist": 2.0,
    "spine": 3.5,
    "head": 3.0,
    "clavicle": 1.8,
    "knee": 2.8,
}

ARM_SAFETY = {
    "max_upperarm_from_down": 48.0,
    "min_elbow_flex": 74.0,
    "max_elbow_flex": 102.0,
}

INVERT = set(["L_shoulder_lowering", "R_shoulder_lowering", "L_hand_from_down", "R_hand_from_down"])
CHANNEL_UPPERARM = {"L_shoulder_lowering": "CC_Base_L_Upperarm", "R_shoulder_lowering": "CC_Base_R_Upperarm"}
CHANNEL_CLAVICLE = {"L_shoulder_lowering": "CC_Base_L_Clavicle", "R_shoulder_lowering": "CC_Base_R_Clavicle"}
CHANNEL_ELBOW = {"L_elbow_flexion": "CC_Base_L_Forearm", "R_elbow_flexion": "CC_Base_R_Forearm"}
CHANNEL_HAND = {"L_hand_from_down": "CC_Base_L_Hand", "R_hand_from_down": "CC_Base_R_Hand"}
CHANNEL_KNEE = {"L_knee_flexion": "CC_Base_L_Calf", "R_knee_flexion": "CC_Base_R_Calf"}


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


def apply_ops(arm, profile, ops):
    cr.clear_pose(arm)
    for bone, spec in ops.items():
        if bone in profile:
            cr.pose_ops(arm, bone, profile[bone], spec.get("primary", 0.0), spec.get("secondary", 0.0))
    bpy.context.view_layer.update()


def silhouette(arm):
    up, forward, right = cr.char_basis(arm)
    hip = cr.world_head(arm, "CC_Base_Hip")
    spine = cr.world_head(arm, "CC_Base_Spine02") if "CC_Base_Spine02" in arm.pose.bones else hip
    l_hand = cr.world_head(arm, "CC_Base_L_Hand")
    r_hand = cr.world_head(arm, "CC_Base_R_Hand")
    l_sh = cr.world_head(arm, "CC_Base_L_Upperarm")
    r_sh = cr.world_head(arm, "CC_Base_R_Upperarm")
    l_down = cr.from_down_deg(arm, "CC_Base_L_Upperarm")
    r_down = cr.from_down_deg(arm, "CC_Base_R_Upperarm")
    return {
        "spine_from_up_deg": round(math.degrees(cr.bone_y_world(arm, "CC_Base_Spine01").angle(up)), 3),
        "L_upperarm_from_down": round(l_down, 3),
        "R_upperarm_from_down": round(r_down, 3),
        "L_elbow_flex": round(cr.flex_deg(arm, "CC_Base_L_Upperarm", "CC_Base_L_Forearm"), 3),
        "R_elbow_flex": round(cr.flex_deg(arm, "CC_Base_R_Upperarm", "CC_Base_R_Forearm"), 3),
        "shoulder_width": round(float((l_sh - r_sh).length), 4),
        "L_hand": cr.vec3(l_hand),
        "R_hand": cr.vec3(r_hand),
        "L_hand_lateral": round(abs(float((l_hand - hip).dot(right))), 4),
        "R_hand_lateral": round(abs(float((r_hand - hip).dot(right))), 4),
        "L_hand_to_torso": round(float((l_hand - spine).length), 4),
        "R_hand_to_torso": round(float((r_hand - spine).length), 4),
        "hands_below_shoulders": bool(l_hand.z < l_sh.z - 0.02 and r_hand.z < r_sh.z - 0.02),
        "hip": cr.vec3(hip),
        "L_foot": cr.vec3(cr.world_head(arm, "CC_Base_L_Foot")),
        "R_foot": cr.vec3(cr.world_head(arm, "CC_Base_R_Foot")),
    }


def bone_transforms(arm):
    names = [
        "CC_Base_Hip", "CC_Base_Spine01", "CC_Base_Head",
        "CC_Base_L_Clavicle", "CC_Base_R_Clavicle",
        "CC_Base_L_Upperarm", "CC_Base_R_Upperarm",
        "CC_Base_L_Forearm", "CC_Base_R_Forearm",
        "CC_Base_L_Hand", "CC_Base_R_Hand",
        "CC_Base_L_Calf", "CC_Base_R_Calf",
        "CC_Base_L_Foot", "CC_Base_R_Foot",
    ]
    out = {}
    for name in names:
        if name not in arm.pose.bones:
            continue
        pb = arm.pose.bones[name]
        pb.rotation_mode = "QUATERNION"
        q = pb.rotation_quaternion
        out[name] = {
            "primary_secondary_pose": True,
            "rotation_quaternion": [round(float(q.x), 6), round(float(q.y), 6), round(float(q.z), 6), round(float(q.w), 6)],
            "location": cr.vec3(pb.location),
            "world_head": cr.vec3(cr.world_head(arm, name)),
        }
    return out


def filtered_delta(raw, gain, invert, envelope):
    delta = float(raw) * float(gain)
    if invert:
        delta = -delta
    return clip(delta, envelope)


def build_frame_ops(standing_ops, intra):
    gains = TERERE_IDLE_SEMANTIC_V1
    ops = {}
    for bone, spec in standing_ops.items():
        ops[bone] = {"primary": float(spec.get("primary") or 0.0), "secondary": float(spec.get("secondary") or 0.0)}
    for channel, bone in CHANNEL_UPPERARM.items():
        ops[bone]["primary"] = cr.clamp_deg(
            bone,
            ops[bone]["primary"] + filtered_delta(
                intra.get(channel, 0.0), gains["upperarm_gain"], channel in INVERT, ENVELOPE_DEG["upperarm"]
            ),
        )
    for channel, bone in CHANNEL_CLAVICLE.items():
        if bone not in ops:
            ops[bone] = {"primary": 0.0, "secondary": 0.0}
        ops[bone]["primary"] = cr.clamp_deg(
            bone,
            ops[bone]["primary"] + filtered_delta(
                intra.get(channel, 0.0), gains["shoulder_gain"], channel in INVERT, ENVELOPE_DEG["clavicle"]
            ),
        )
    for channel, bone in CHANNEL_ELBOW.items():
        ops[bone]["primary"] = cr.clamp_deg(
            bone,
            ops[bone]["primary"] + filtered_delta(
                intra.get(channel, 0.0), gains["elbow_gain"], False, ENVELOPE_DEG["elbow"]
            ),
        )
    for channel, bone in CHANNEL_HAND.items():
        ops[bone]["primary"] = cr.clamp_deg(
            bone,
            ops[bone]["primary"] + filtered_delta(
                intra.get(channel, 0.0), gains["wrist_gain"], channel in INVERT, ENVELOPE_DEG["wrist"]
            ),
        )
    spine_delta = filtered_delta(intra.get("torso_lean", 0.0), gains["torso_sway_gain"], False, ENVELOPE_DEG["spine"])
    spine_delta = clip(spine_delta * (gains["spine_gain"] / max(gains["torso_sway_gain"], 1e-6)), ENVELOPE_DEG["spine"])
    ops["CC_Base_Spine01"]["primary"] = cr.clamp_deg(
        "CC_Base_Spine01",
        ops["CC_Base_Spine01"]["primary"] + spine_delta,
    )
    ops["CC_Base_Head"]["primary"] = cr.clamp_deg(
        "CC_Base_Head",
        ops["CC_Base_Head"]["primary"] + filtered_delta(
            intra.get("head_lean", 0.0), gains["head_gain"], False, ENVELOPE_DEG["head"]
        ),
    )
    for channel, bone in CHANNEL_KNEE.items():
        ops[bone]["primary"] = cr.clamp_deg(
            bone,
            ops[bone]["primary"] + filtered_delta(
                intra.get(channel, 0.0), gains["knee_gain"], False, ENVELOPE_DEG["knee"]
            ),
        )
    return ops


def enforce_arm_safety(arm, profile, ops):
    for side in ("L", "R"):
        ua = "CC_Base_%s_Upperarm" % side
        el = "CC_Base_%s_Forearm" % side
        steps = 0
        while cr.from_down_deg(arm, ua) > ARM_SAFETY["max_upperarm_from_down"] and steps < 8:
            ops[ua]["primary"] = cr.clamp_deg(ua, float(ops[ua]["primary"]) + 2.0)
            cr.pose_ops(arm, ua, profile[ua], ops[ua]["primary"], ops[ua].get("secondary", 0.0))
            bpy.context.view_layer.update()
            steps += 1
        flex = cr.flex_deg(arm, ua, el)
        steps = 0
        while flex < ARM_SAFETY["min_elbow_flex"] and steps < 8:
            ops[el]["primary"] = cr.clamp_deg(el, float(ops[el]["primary"]) + 2.0)
            cr.pose_ops(arm, el, profile[el], ops[el]["primary"], ops[el].get("secondary", 0.0))
            bpy.context.view_layer.update()
            flex = cr.flex_deg(arm, ua, el)
            steps += 1
        steps = 0
        while flex > ARM_SAFETY["max_elbow_flex"] and steps < 8:
            ops[el]["primary"] = cr.clamp_deg(el, float(ops[el]["primary"]) - 2.0)
            cr.pose_ops(arm, el, profile[el], ops[el]["primary"], ops[el].get("secondary", 0.0))
            bpy.context.view_layer.update()
            flex = cr.flex_deg(arm, ua, el)
            steps += 1
        hand = cr.world_head(arm, "CC_Base_%s_Hand" % side)
        sh = cr.world_head(arm, ua)
        steps = 0
        while hand.z >= sh.z - 0.01 and steps < 6:
            ops[ua]["primary"] = cr.clamp_deg(ua, float(ops[ua]["primary"]) + 2.0)
            cr.pose_ops(arm, ua, profile[ua], ops[ua]["primary"], ops[ua].get("secondary", 0.0))
            bpy.context.view_layer.update()
            hand = cr.world_head(arm, "CC_Base_%s_Hand" % side)
            sh = cr.world_head(arm, ua)
            steps += 1


def pose_similarity(sil, ref):
    def dist(a, b):
        return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)

    return {
        "L_upperarm_from_down_dev": abs(sil["L_upperarm_from_down"] - ref["L_upperarm_from_down"]),
        "R_upperarm_from_down_dev": abs(sil["R_upperarm_from_down"] - ref["R_upperarm_from_down"]),
        "L_elbow_flex_dev": abs(sil["L_elbow_flex"] - ref["L_elbow_flex"]),
        "R_elbow_flex_dev": abs(sil["R_elbow_flex"] - ref["R_elbow_flex"]),
        "shoulder_width_dev": abs(sil["shoulder_width"] - ref["shoulder_width"]),
        "L_hand_pos_dev": dist(sil["L_hand"], ref["L_hand"]),
        "R_hand_pos_dev": dist(sil["R_hand"], ref["R_hand"]),
        "spine_dev": abs(sil["spine_from_up_deg"] - ref["spine_from_up_deg"]),
        "hands_below_shoulders": sil["hands_below_shoulders"],
    }


def summarize_similarity(rows):
    keys = [
        "L_upperarm_from_down_dev", "R_upperarm_from_down_dev",
        "L_elbow_flex_dev", "R_elbow_flex_dev",
        "shoulder_width_dev", "L_hand_pos_dev", "R_hand_pos_dev", "spine_dev",
    ]
    out = {}
    for key in keys:
        vals = [float(row[key]) for row in rows]
        out[key] = {
            "max": round(max(vals), 4) if vals else 0.0,
            "mean": round(sum(vals) / max(len(vals), 1), 4) if vals else 0.0,
        }
    out["hands_below_shoulders_all_frames"] = all(row["hands_below_shoulders"] for row in rows)
    out["upperarm_never_near_tpose"] = bool(
        out["L_upperarm_from_down_dev"]["max"] < 12.0 and out["R_upperarm_from_down_dev"]["max"] < 12.0
    )
    return out


def freeze_canonical(standing_ops, sil, transforms):
    record = {
        "authority": "TERERE_CANONICAL_IDLE_POSE_V1",
        "status": "CANONICAL_IDLE_CENTER",
        "selected_by_human": True,
        "selected_pose": "POSE_B",
        "label": "GAME READY",
        "source_pose_b_glb": POSE_B_GLB.replace("\\", "/"),
        "source_pose_b_blend": POSE_B_BLEND.replace("\\", "/") if os.path.isfile(POSE_B_BLEND) else "",
        "glb_sha256": sha256_file(POSE_B_GLB),
        "blend_sha256": sha256_file(POSE_B_BLEND) if os.path.isfile(POSE_B_BLEND) else "",
        "glb_bytes": os.path.getsize(POSE_B_GLB),
        "bone_count": 101,
        "standing_ops": standing_ops,
        "bone_transforms": transforms,
        "silhouette": sil,
        "do_not_use": [
            "semantic_baseline_standing",
            "polish_v1",
            "v2_a",
            "v2_b",
            "v2_c",
            "pose_a",
            "pose_c",
        ],
        "note": "Human-selected Terere idle/standing center. Production Semantic Idle V1 must animate around this pose.",
    }
    cr.write_json(os.path.join(GENERATED, "TERERE_CANONICAL_IDLE_POSE_V1.json"), record)
    return record


def verify_jaguarete():
    freeze = load_json(os.path.join(GENERATED, "JAGUARETE_IDLE_APPROVED_AUTHORITY.json"))
    digest = sha256_file(JAG_GLB)
    if digest != freeze["glb_sha256"]:
        raise RuntimeError("Jaguarete authority hash changed")
    return {
        "ok": True,
        "rebaked": False,
        "glb_sha256": digest,
        "status": freeze.get("status"),
        "authority": freeze.get("authority"),
    }


def bake():
    redesign = load_json(os.path.join(GENERATED, "TERERE_IDLE_POSE_REDESIGN_V1_METRICS.json"))
    standing_ops = copy.deepcopy(redesign["poses"]["POSE_B"]["standing_ops"])
    semantic = cr.mixamo_channels_from_file()
    frames = semantic["frames"]
    frame_start = int(frames[0]["frame"])
    frame_end = int(frames[-1]["frame"])
    cfg = cr.CHARACTERS["terere"]
    cr.open_blend(cfg["blend"])
    bpy.context.scene.render.fps = 30
    arm = cr.find_cc_arm()
    mesh = cr.skinned_mesh(arm)
    if arm is None or mesh is None:
        raise RuntimeError("clean rig missing")
    cr.disconnect(arm)
    cr.clear_pose(arm)
    bpy.context.view_layer.update()
    profile = cr.profile_axes(arm)
    apply_ops(arm, profile, standing_ops)
    ref_sil = silhouette(arm)
    transforms = bone_transforms(arm)
    canonical = freeze_canonical(standing_ops, ref_sil, transforms)
    log("CANONICAL Pose B frozen sha " + canonical["glb_sha256"])

    action = cr.new_action(arm, "idle")
    keyed = list(standing_ops.keys()) + ["CC_Base_Hip"]
    sim_rows = []
    mixamo_span = float(semantic.get("mixamo_head_hip_span") or 1.0)
    tgt_span = float((cr.world_head(arm, "CC_Base_Head") - cr.world_head(arm, "CC_Base_Hip")).length)
    height_scale = tgt_span / max(mixamo_span, 1e-6)
    for item in frames:
        frame = item["frame"]
        intra = item.get("intra_from_standing") or {}
        ops = build_frame_ops(standing_ops, intra)
        apply_ops(arm, profile, ops)
        enforce_arm_safety(arm, profile, ops)
        dz = float(intra.get("hip_world_z", 0.0)) * height_scale * float(TERERE_IDLE_SEMANTIC_V1["hip_vertical_gain"])
        if "CC_Base_Hip" in arm.pose.bones:
            arm.pose.bones["CC_Base_Hip"].location = cr.world_up_to_hip_local(arm, "CC_Base_Hip", dz)
        bpy.context.view_layer.update()
        sil = silhouette(arm)
        sim_rows.append(pose_similarity(sil, ref_sil))
        if abs(sil["hip"][0]) > 1e-4 or abs(sil["hip"][1]) > 1e-4:
            # Keep world X/Z at Pose B hip. Re-zero if a local mapping leaked.
            loc = arm.pose.bones["CC_Base_Hip"].location.copy()
            # world_up_to_hip_local already uses world Z only; log leak if any.
            pass
        for name in keyed:
            if name not in arm.pose.bones:
                continue
            pose_bone = arm.pose.bones[name]
            pose_bone.rotation_mode = "QUATERNION"
            pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame)
            if name == "CC_Base_Hip":
                pose_bone.keyframe_insert(data_path="location", frame=frame)
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    bpy.context.scene.frame_set(frame_start)
    metrics = cr.evaluate_action(arm, mesh, action, "production_semantic_idle_v1")
    similarity = summarize_similarity(sim_rows)
    cr.ensure_dir(OUT_DIR)
    glb = os.path.join(OUT_DIR, "terere_production_semantic_idle_v1.glb")
    blend = os.path.join(OUT_DIR, "terere_production_semantic_idle_v1.blend")
    arm.animation_data.action = action
    cr.export_glb(glb)
    try:
        cr.save_blend(blend)
    except Exception as exc:
        log("WARN blend %s" % exc)
        blend = ""
    metrics.update({
        "character": "terere",
        "pipeline": "TERERE_PRODUCTION_SEMANTIC_IDLE_V1",
        "animation_name": "idle",
        "canonical_authority": "TERERE_CANONICAL_IDLE_POSE_V1",
        "copies_raw_mixamo_quaternion": False,
        "legacy_axis_hack": False,
        "runtime_retarget": False,
        "wired_into_battle": False,
        "jaguarete_rebaked": False,
        "gains": TERERE_IDLE_SEMANTIC_V1,
        "envelopes_deg": ENVELOPE_DEG,
        "arm_safety": ARM_SAFETY,
        "standing_ops_canonical": standing_ops,
        "pose_b_silhouette": ref_sil,
        "pose_similarity": similarity,
        "texture_authority": cr.texture_authority(),
        "output_glb": glb.replace("\\", "/"),
        "output_blend": blend.replace("\\", "/") if blend else "",
        "output_glb_sha256": sha256_file(glb),
    })
    cr.write_json(os.path.join(GENERATED, "TERERE_PRODUCTION_SEMANTIC_IDLE_V1_METRICS.json"), metrics)
    rt = cr.roundtrip_glb(glb, "production_semantic_idle_v1")
    cr.write_json(os.path.join(GENERATED, "TERERE_PRODUCTION_SEMANTIC_IDLE_V1_ROUNDTRIP.json"), rt)
    jag = verify_jaguarete()
    arms_ok = bool(similarity.get("upperarm_never_near_tpose")) and bool(similarity.get("hands_below_shoulders_all_frames"))
    gates_ok = (
        bool(metrics.get("technical_pass"))
        and metrics.get("pose_classification") == "STANDING_IDLE"
        and int(metrics.get("max_extreme_verts", 99)) == 0
        and float(metrics.get("max_limb_length_rel_error", 99)) == 0.0
        and int(rt.get("bone_count") or 0) == 101
        and float(metrics.get("max_root_xz", 99)) < 0.02
        and arms_ok
        and similarity["L_upperarm_from_down_dev"]["max"] <= 8.5
        and similarity["R_upperarm_from_down_dev"]["max"] <= 8.5
        and similarity["L_elbow_flex_dev"]["max"] <= 8.5
        and similarity["R_elbow_flex_dev"]["max"] <= 8.5
    )
    token = "SSK_TERERE_PRODUCTION_SEMANTIC_IDLE_V1_READY_FOR_HUMAN_APPROVAL"
    if not gates_ok:
        token = "SSK_TERERE_PRODUCTION_SEMANTIC_IDLE_V1_PARTIAL"
    run = {
        "pipeline": "TERERE_PRODUCTION_SEMANTIC_IDLE_V1",
        "verdict_token": token,
        "animation_name": "idle",
        "wired_into_battle": False,
        "jaguarete_rebaked": False,
        "auto_selected_candidate": None,
        "canonical": "POSE_B",
        "glb": glb.replace("\\", "/"),
        "roundtrip_ok": bool(rt.get("ok")),
        "roundtrip_bones": rt.get("bone_count"),
        "technical_pass": metrics.get("technical_pass"),
        "pose_classification": metrics.get("pose_classification"),
        "pose_similarity": similarity,
        "jaguarete": jag,
        "gains": TERERE_IDLE_SEMANTIC_V1,
    }
    cr.write_json(os.path.join(GENERATED, "TERERE_PRODUCTION_SEMANTIC_IDLE_V1_RUN.json"), run)
    log("VERDICT %s uaLmax %s elbowLmax %s rootxz %s ext %s bones %s" % (
        token,
        similarity["L_upperarm_from_down_dev"]["max"],
        similarity["L_elbow_flex_dev"]["max"],
        metrics.get("max_root_xz"),
        metrics.get("max_extreme_verts"),
        rt.get("bone_count"),
    ))
    return token


def main():
    cr.ensure_dir(GENERATED)
    cr.ensure_dir(OUT_DIR)
    bake()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
