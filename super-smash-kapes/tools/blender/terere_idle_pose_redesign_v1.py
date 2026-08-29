# -*- coding: utf-8 -*-
"""Tereré Idle Pose Redesign V1 for Blender 2.83.

Authors three distinct STATIC canonical idle silhouettes.
Does not animate Mixamo around them. Does not touch Jaguareté.
Does not modify Clean Rig authority files.
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
OUT_ROOT = os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "idle_pose_redesign_v1", "terere")
SCREEN_DIR = os.path.join(GENERATED, "terere_idle_pose_redesign_v1_screenshots")
VIEWS = ("front", "three_quarter", "side")

# Genuinely different silhouette philosophies. Not a ±2° sweep.
# Upperarm secondary is filled at bake time after a forward-compact probe.
POSES = {
    "POSE_A": {
        "id": "A",
        "label": "RELAXED COMPACT",
        "philosophy": "Arms low, hands near hips/ribs, relaxed elbows, minimal fight stance.",
        "spine": 8.0,
        "head": -6.0,
        "clavicle": (4.0, 2.0),
        "upperarm_L": {"primary": 62.0, "secondary": 16.0},
        "upperarm_R": {"primary": 66.0, "secondary": 14.0},
        "forearm_L": {"primary": 86.0, "secondary": 0.0},
        "forearm_R": {"primary": 84.0, "secondary": 0.0},
        "hand_L": {"primary": 6.0, "secondary": 2.0},
        "hand_R": {"primary": 6.0, "secondary": 2.0},
        "calf_L": 40.0,
        "calf_R": 40.0,
    },
    "POSE_B": {
        "id": "B",
        "label": "GAME READY",
        "philosophy": "Hands more forward/up, elbows bent, compact fighting-game stance, small lead/rear asymmetry.",
        "spine": 7.0,
        "head": -4.0,
        "clavicle": (3.0, 1.0),
        "upperarm_L": {"primary": 50.0, "secondary": 26.0},
        "upperarm_R": {"primary": 58.0, "secondary": 20.0},
        "forearm_L": {"primary": 90.0, "secondary": 0.0},
        "forearm_R": {"primary": 86.0, "secondary": 0.0},
        "hand_L": {"primary": 8.0, "secondary": 3.0},
        "hand_R": {"primary": 7.0, "secondary": 2.0},
        "calf_L": 40.0,
        "calf_R": 40.0,
    },
    "POSE_C": {
        "id": "C",
        "label": "CARTOON FIGHTER",
        "philosophy": "Stronger readable readiness silhouette, still natural, not a boxing caricature.",
        "spine": 10.0,
        "head": -8.0,
        "clavicle": (2.0, 1.0),
        "upperarm_L": {"primary": 54.0, "secondary": 30.0},
        "upperarm_R": {"primary": 62.0, "secondary": 22.0},
        "forearm_L": {"primary": 90.0, "secondary": 0.0},
        "forearm_R": {"primary": 82.0, "secondary": 0.0},
        "hand_L": {"primary": 4.0, "secondary": 2.0},
        "hand_R": {"primary": 5.0, "secondary": 2.0},
        "calf_L": 40.0,
        "calf_R": 40.0,
    },
}


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def apply_ops(arm, profile, ops):
    cr.clear_pose(arm)
    for bone, spec in ops.items():
        if bone in profile:
            cr.pose_ops(arm, bone, profile[bone], spec.get("primary", 0.0), spec.get("secondary", 0.0))
    bpy.context.view_layer.update()


def hand_layout(arm):
    up, forward, right = cr.char_basis(arm)
    hip = cr.world_head(arm, "CC_Base_Hip")
    spine = cr.world_head(arm, "CC_Base_Spine02") if "CC_Base_Spine02" in arm.pose.bones else hip
    out = {}
    for side in ("L", "R"):
        hand = cr.world_head(arm, "CC_Base_%s_Hand" % side)
        delta = hand - hip
        out[side] = {
            "forward": float(delta.dot(forward)),
            "lateral": abs(float(delta.dot(right))),
            "height": float(hand.z),
            "from_hip": float(delta.length),
            "from_spine": float((hand - spine).length),
        }
    l_sh = cr.world_head(arm, "CC_Base_L_Upperarm")
    r_sh = cr.world_head(arm, "CC_Base_R_Upperarm")
    out["shoulder_width"] = float((l_sh - r_sh).length)
    out["com_xz"] = [round(float(hip.x), 4), round(float(hip.y), 4)]
    return out


def silhouette(arm):
    layout = hand_layout(arm)
    l_hand = cr.world_head(arm, "CC_Base_L_Hand")
    r_hand = cr.world_head(arm, "CC_Base_R_Hand")
    l_sh = cr.world_head(arm, "CC_Base_L_Upperarm")
    r_sh = cr.world_head(arm, "CC_Base_R_Upperarm")
    hip = cr.world_head(arm, "CC_Base_Hip")
    up, _fwd, _right = cr.char_basis(arm)
    l_down = cr.from_down_deg(arm, "CC_Base_L_Upperarm")
    r_down = cr.from_down_deg(arm, "CC_Base_R_Upperarm")
    return {
        "spine_from_up_deg": round(math.degrees(cr.bone_y_world(arm, "CC_Base_Spine01").angle(up)), 3),
        "L_upperarm_from_down": round(l_down, 3),
        "R_upperarm_from_down": round(r_down, 3),
        "L_upperarm_down_from_horizontal": round(90.0 - l_down, 3),
        "R_upperarm_down_from_horizontal": round(90.0 - r_down, 3),
        "L_elbow_flex": round(cr.flex_deg(arm, "CC_Base_L_Upperarm", "CC_Base_L_Forearm"), 3),
        "R_elbow_flex": round(cr.flex_deg(arm, "CC_Base_R_Upperarm", "CC_Base_R_Forearm"), 3),
        "L_knee_flex": round(cr.flex_deg(arm, "CC_Base_L_Thigh", "CC_Base_L_Calf"), 3),
        "R_knee_flex": round(cr.flex_deg(arm, "CC_Base_R_Thigh", "CC_Base_R_Calf"), 3),
        "hands_below_shoulders": bool(l_hand.z < l_sh.z - 0.02 and r_hand.z < r_sh.z - 0.02),
        "shoulder_width": round(layout["shoulder_width"], 4),
        "L_hand_to_torso": round(layout["L"]["from_spine"], 4),
        "R_hand_to_torso": round(layout["R"]["from_spine"], 4),
        "L_hand_lateral": round(layout["L"]["lateral"], 4),
        "R_hand_lateral": round(layout["R"]["lateral"], 4),
        "L_hand_forward": round(layout["L"]["forward"], 4),
        "R_hand_forward": round(layout["R"]["forward"], 4),
        "L_hand_height": round(layout["L"]["height"], 4),
        "R_hand_height": round(layout["R"]["height"], 4),
        "center_of_mass_xz": layout["com_xz"],
        "L_foot": cr.vec3(cr.world_head(arm, "CC_Base_L_Foot")),
        "R_foot": cr.vec3(cr.world_head(arm, "CC_Base_R_Foot")),
        "hip": cr.vec3(hip),
        "possible_hand_body_intersection": bool(
            layout["L"]["from_spine"] < 0.04 or layout["R"]["from_spine"] < 0.04
        ),
    }


def build_ops(spec, forward_sign):
    ops = {
        "CC_Base_Spine01": {"primary": cr.clamp_deg("CC_Base_Spine01", spec["spine"]), "secondary": 0.0},
        "CC_Base_Head": {"primary": cr.clamp_deg("CC_Base_Head", spec["head"]), "secondary": 0.0},
        "CC_Base_L_Clavicle": {"primary": spec["clavicle"][0], "secondary": spec["clavicle"][1]},
        "CC_Base_R_Clavicle": {"primary": spec["clavicle"][0], "secondary": spec["clavicle"][1]},
        "CC_Base_L_Upperarm": {
            "primary": cr.clamp_deg("CC_Base_L_Upperarm", spec["upperarm_L"]["primary"]),
            "secondary": spec["upperarm_L"]["secondary"] * forward_sign,
        },
        "CC_Base_R_Upperarm": {
            "primary": cr.clamp_deg("CC_Base_R_Upperarm", spec["upperarm_R"]["primary"]),
            "secondary": spec["upperarm_R"]["secondary"] * forward_sign,
        },
        "CC_Base_L_Forearm": {
            "primary": cr.clamp_deg("CC_Base_L_Forearm", spec["forearm_L"]["primary"]),
            "secondary": spec["forearm_L"]["secondary"],
        },
        "CC_Base_R_Forearm": {
            "primary": cr.clamp_deg("CC_Base_R_Forearm", spec["forearm_R"]["primary"]),
            "secondary": spec["forearm_R"]["secondary"],
        },
        "CC_Base_L_Hand": {
            "primary": cr.clamp_deg("CC_Base_L_Hand", spec["hand_L"]["primary"]),
            "secondary": spec["hand_L"]["secondary"],
        },
        "CC_Base_R_Hand": {
            "primary": cr.clamp_deg("CC_Base_R_Hand", spec["hand_R"]["primary"]),
            "secondary": spec["hand_R"]["secondary"],
        },
        "CC_Base_L_Calf": {"primary": spec["calf_L"], "secondary": 0.0},
        "CC_Base_R_Calf": {"primary": spec["calf_R"], "secondary": 0.0},
    }
    return ops


def probe_forward_sign(arm, profile, baseline_ops):
    scores = []
    for sign in (1.0, -1.0):
        ops = copy.deepcopy(baseline_ops)
        for side in ("L", "R"):
            bone = "CC_Base_%s_Upperarm" % side
            ops[bone] = dict(ops.get(bone) or {"primary": 50.0, "secondary": 0.0})
            ops[bone]["secondary"] = 20.0 * sign
            ops[bone]["primary"] = cr.clamp_deg(bone, float(ops[bone].get("primary") or 50.0) + 8.0)
        apply_ops(arm, profile, ops)
        layout = hand_layout(arm)
        score = (layout["L"]["forward"] + layout["R"]["forward"]) - 0.65 * (
            layout["L"]["lateral"] + layout["R"]["lateral"]
        )
        scores.append((score, sign, layout))
        print("FORWARD_PROBE sign", sign, "score", round(score, 4),
              "fwd", round(layout["L"]["forward"], 3), round(layout["R"]["forward"], 3),
              "lat", round(layout["L"]["lateral"], 3), round(layout["R"]["lateral"], 3))
    scores.sort(key=lambda item: item[0], reverse=True)
    return float(scores[0][1]), scores


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
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except Exception:
        pass
    scene.render.image_settings.file_format = "PNG"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 360
    scene.render.filepath = path
    try:
        bpy.ops.render.render(write_still=True)
        return True
    except Exception as exc:
        print("WARN render", path, exc)
        return False


def key_pose(arm, ops, frame=1):
    action = cr.new_action(arm, "canonical_pose")
    keyed = list(ops.keys())
    for name in keyed:
        if name not in arm.pose.bones:
            continue
        pose_bone = arm.pose.bones[name]
        pose_bone.rotation_mode = "QUATERNION"
        pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame)
        pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame + 1)
    bpy.context.scene.frame_start = frame
    bpy.context.scene.frame_end = frame + 1
    bpy.context.scene.frame_set(frame)
    return action


def bake_pose(pose_key, spec, arm, mesh, profile, forward_sign):
    ops = build_ops(spec, forward_sign)
    apply_ops(arm, profile, ops)
    sil = silhouette(arm)
    action = key_pose(arm, ops, 1)
    metrics = cr.evaluate_action(arm, mesh, action, "canonical_static")
    apply_ops(arm, profile, ops)
    action = key_pose(arm, ops, 1)
    out_dir = OUT_ROOT
    cr.ensure_dir(out_dir)
    stem = "terere_idle_pose_redesign_v1_%s" % spec["id"].lower()
    glb = os.path.join(out_dir, stem + ".glb")
    blend = os.path.join(out_dir, stem + ".blend")
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    bpy.context.scene.frame_set(1)
    cr.export_glb(glb)
    try:
        cr.save_blend(blend)
    except Exception as exc:
        print("WARN blend", exc)
        blend = ""
    screens = {}
    metrics.update({
        "character": "terere",
        "pipeline": "TERERE_IDLE_POSE_REDESIGN_V1",
        "pose_id": pose_key,
        "label": spec["label"],
        "philosophy": spec["philosophy"],
        "animation": False,
        "copies_raw_mixamo_quaternion": False,
        "legacy_axis_hack": False,
        "runtime_retarget": False,
        "standing_ops": ops,
        "forward_secondary_sign": forward_sign,
        "silhouette": sil,
        "screenshots": screens,
        "output_glb": glb.replace("\\", "/"),
        "output_blend": blend.replace("\\", "/") if blend else "",
        "output_glb_sha256": sha256_file(glb),
        "texture_authority": cr.texture_authority(),
    })
    cr.write_json(os.path.join(GENERATED, "TERERE_IDLE_POSE_REDESIGN_V1_%s_METRICS.json" % spec["id"]), metrics)
    rt = cr.roundtrip_glb(glb, "canonical_static")
    cr.write_json(os.path.join(GENERATED, "TERERE_IDLE_POSE_REDESIGN_V1_%s_ROUNDTRIP.json" % spec["id"]), rt)
    print(
        "POSE", pose_key, "class", metrics.get("pose_classification"),
        "pass", metrics.get("technical_pass"),
        "vol", metrics.get("max_volume_ratio"),
        "ext", metrics.get("max_extreme_verts"),
        "elbow", sil.get("L_elbow_flex"), sil.get("R_elbow_flex"),
        "lat", sil.get("L_hand_lateral"), sil.get("R_hand_lateral"),
        "fwd", sil.get("L_hand_forward"), sil.get("R_hand_forward"),
        "intersect", sil.get("possible_hand_body_intersection"),
    )
    return {"metrics": metrics, "roundtrip": rt, "glb": glb, "ops": ops, "silhouette": sil}


def render_baseline(arm, mesh, baseline_ops, profile):
    apply_ops(arm, profile, baseline_ops)
    action = key_pose(arm, baseline_ops, 1)
    metrics = cr.evaluate_action(arm, mesh, action, "baseline_static")
    apply_ops(arm, profile, baseline_ops)
    sil = silhouette(arm)
    return {"metrics": metrics, "silhouette": sil, "screenshots": {}}


def bind_action(arm):
    if arm.animation_data and arm.animation_data.action:
        return arm.animation_data.action
    if bpy.data.actions:
        if arm.animation_data is None:
            arm.animation_data_create()
        arm.animation_data.action = bpy.data.actions[0]
        return bpy.data.actions[0]
    return None


def ensure_ground():
    if "RedesignGround" in bpy.data.objects:
        return
    bpy.ops.mesh.primitive_plane_add(size=18.0, location=(0.0, 0.0, 0.0))
    plane = bpy.context.active_object
    plane.name = "RedesignGround"
    mat = bpy.data.materials.new("RedesignGroundMat")
    mat.diffuse_color = (0.11, 0.13, 0.16, 1.0)
    plane.data.materials.append(mat)


def screenshot_glb(label, glb_path):
    cr.reset_empty()
    bpy.ops.import_scene.gltf(filepath=glb_path)
    arm = cr.find_cc_arm()
    if arm is None:
        raise RuntimeError("no CC armature in %s" % glb_path)
    action = bind_action(arm)
    if action is None:
        raise RuntimeError("no action in %s" % glb_path)
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_set(int(action.frame_range[0]))
    bpy.context.view_layer.update()
    cr.setup_camera(arm)
    ensure_ground()
    screens = {}
    for view in VIEWS:
        png = os.path.join(SCREEN_DIR, "%s_%s.png" % (label, view))
        place_camera(arm, view)
        screens[view] = png.replace("\\", "/") if try_render(png) else ""
    sil = silhouette(arm)
    return screens, sil


def freeze_jaguarete():
    glb = os.path.join(
        PROJECT_ROOT, "assets", "fighters", "processed", "semantic_idle_polish_v1",
        "jaguarete", "jaguarete_idle_semantic_polished_v1.glb",
    )
    blend = os.path.splitext(glb)[0] + ".blend"
    rt = None
    record = {
        "authority": "JAGUARETE_IDLE_APPROVED_AUTHORITY",
        "status": "HUMAN_APPROVED_PENDING_PRODUCTION_INTEGRATION",
        "do_not_rebake": True,
        "do_not_modify": True,
        "glb": glb.replace("\\", "/"),
        "blend": blend.replace("\\", "/") if os.path.isfile(blend) else "",
        "glb_sha256": sha256_file(glb),
        "glb_bytes": os.path.getsize(glb),
        "blend_sha256": sha256_file(blend) if os.path.isfile(blend) else "",
        "animation_name": "idle",
        "bone_count": 101,
        "source_pipeline": "SEMANTIC_IDLE_POLISH_V1",
        "note": "Human approved for now. Pose redesign V1 does not regenerate Jaguarete.",
    }
    cr.write_json(os.path.join(GENERATED, "JAGUARETE_IDLE_APPROVED_AUTHORITY.json"), record)
    return record


def main():
    cr.ensure_dir(GENERATED)
    cr.ensure_dir(SCREEN_DIR)
    cr.ensure_dir(OUT_ROOT)
    jag = freeze_jaguarete()
    baseline_metrics = load_json(os.path.join(GENERATED, "TERERE_IDLE_SEMANTIC_CLEAN_V1_METRICS.json"))
    baseline_ops = baseline_metrics["standing_ops"]
    cfg = cr.CHARACTERS["terere"]
    cr.open_blend(cfg["blend"])
    bpy.context.scene.render.fps = 30
    arm = cr.find_cc_arm()
    mesh = cr.skinned_mesh(arm)
    if arm is None or mesh is None:
        raise RuntimeError("clean rig missing for terere")
    cr.disconnect(arm)
    cr.clear_pose(arm)
    bpy.context.view_layer.update()
    profile = cr.profile_axes(arm)
    forward_sign, probe = probe_forward_sign(arm, profile, baseline_ops)
    print("FORWARD_SIGN", forward_sign)

    baseline_row = render_baseline(arm, mesh, baseline_ops, profile)
    results = {}
    for pose_key in ("POSE_A", "POSE_B", "POSE_C"):
        print("====", pose_key, "====")
        cr.open_blend(cfg["blend"])
        bpy.context.scene.render.fps = 30
        arm = cr.find_cc_arm()
        mesh = cr.skinned_mesh(arm)
        cr.disconnect(arm)
        cr.clear_pose(arm)
        bpy.context.view_layer.update()
        profile = cr.profile_axes(arm)
        results[pose_key] = bake_pose(pose_key, POSES[pose_key], arm, mesh, profile, forward_sign)

    poses_out = {}
    all_healthy = True
    distinct = True
    laterals = []
    for pose_key, row in results.items():
        m = row["metrics"]
        rt = row["roundtrip"]
        sil = row["silhouette"]
        healthy = (
            bool(m.get("technical_pass"))
            and m.get("pose_classification") == "STANDING_IDLE"
            and int(rt.get("bone_count") or 0) == 101
            and int(m.get("max_extreme_verts", 99)) == 0
            and float(m.get("max_limb_length_rel_error", 99)) == 0.0
        )
        if not healthy:
            all_healthy = False
        laterals.append((
            round(float(POSES[pose_key]["upperarm_L"]["primary"]), 1),
            round(float(POSES[pose_key]["upperarm_L"]["secondary"]), 1),
            round(float(POSES[pose_key]["forearm_L"]["primary"]), 1),
            pose_key,
        ))
        poses_out[pose_key] = {
            "label": POSES[pose_key]["label"],
            "philosophy": POSES[pose_key]["philosophy"],
            "healthy": healthy,
            "technical_pass": m.get("technical_pass"),
            "pose_classification": m.get("pose_classification"),
            "max_volume_ratio": m.get("max_volume_ratio"),
            "max_extreme_verts": m.get("max_extreme_verts"),
            "max_limb_length_rel_error": m.get("max_limb_length_rel_error"),
            "roundtrip_ok": bool(rt.get("ok")),
            "roundtrip_bones": rt.get("bone_count"),
            "glb": m.get("output_glb"),
            "standing_ops": row["ops"],
            "silhouette": sil,
            "screenshots": m.get("screenshots"),
        }
    if len(set((x[0], x[1], x[2]) for x in laterals)) < 3:
        distinct = False
    baseline_glb = os.path.join(
        PROJECT_ROOT, "assets", "fighters", "processed", "idle_benchmark_v1",
        "terere", "terere_idle_semantic_clean_v1.glb",
    )
    print("==== SCREENSHOTS ====")
    base_screens, base_sil_shot = screenshot_glb("BASELINE", baseline_glb)
    baseline_row["screenshots"] = base_screens
    baseline_row["silhouette_from_glb"] = base_sil_shot
    for pose_key, row in results.items():
        screens, sil_shot = screenshot_glb(pose_key, row["glb"])
        row["metrics"]["screenshots"] = screens
        poses_out[pose_key]["screenshots"] = screens
        poses_out[pose_key]["silhouette_from_glb"] = sil_shot
        cr.write_json(
            os.path.join(GENERATED, "TERERE_IDLE_POSE_REDESIGN_V1_%s_METRICS.json" % POSES[pose_key]["id"]),
            row["metrics"],
        )
    token = "SSK_TERERE_IDLE_POSE_REDESIGN_V1_READY_FOR_HUMAN_SELECTION"
    if not all_healthy or not distinct:
        token = "SSK_TERERE_IDLE_POSE_REDESIGN_V1_PARTIAL"
    summary = {
        "pipeline": "TERERE_IDLE_POSE_REDESIGN_V1",
        "verdict_token": token,
        "animation_baked": False,
        "auto_selected_candidate": None,
        "wired_into_battle": False,
        "jaguarete_rebaked": False,
        "forward_secondary_sign": forward_sign,
        "visibly_distinct": distinct,
        "baseline": {
            "glb": os.path.join(
                PROJECT_ROOT, "assets", "fighters", "processed", "idle_benchmark_v1",
                "terere", "terere_idle_semantic_clean_v1.glb",
            ).replace("\\", "/"),
            "silhouette": baseline_row["silhouette"],
            "screenshots": baseline_row["screenshots"],
        },
        "jaguarete_freeze": jag,
        "poses": poses_out,
        "future_motion_architecture": {
            "executed": False,
            "rule": "Selected canonical pose is the idle center. Mixamo intra-idle deltas animate around it and must not redefine stance.",
        },
    }
    cr.write_json(os.path.join(GENERATED, "TERERE_IDLE_POSE_REDESIGN_V1_METRICS.json"), summary)
    cr.write_json(os.path.join(GENERATED, "TERERE_IDLE_POSE_REDESIGN_V1_RUN.json"), {
        "pipeline": summary["pipeline"],
        "verdict_token": token,
        "auto_selected_candidate": None,
        "jaguarete_rebaked": False,
        "wired_into_battle": False,
        "visibly_distinct": distinct,
        "poses": {
            key: {
                "healthy": val["healthy"],
                "pose_classification": val["pose_classification"],
                "glb": val["glb"],
                "roundtrip_bones": val["roundtrip_bones"],
            }
            for key, val in poses_out.items()
        },
    })
    print("VERDICT", token, "distinct", distinct)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
