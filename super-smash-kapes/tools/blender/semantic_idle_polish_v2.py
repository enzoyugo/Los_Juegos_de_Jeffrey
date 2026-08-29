# -*- coding: utf-8 -*-
"""Tereré Semantic Idle Polish V2 for Blender 2.83.

Restores frozen Idle Benchmark V1 semantic standing_ops, then applies tiny
standing offsets only. Does not iterate from rejected Polish V1.
Does not touch Jaguareté, Clean Rig, Traditional, V4, or battle.
"""
from __future__ import print_function

import copy
import hashlib
import json
import math
import os
import shutil
import sys
import traceback

import bpy
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
import clean_rig_idle_retarget_benchmark_v1 as cr

PROJECT_ROOT = cr.PROJECT_ROOT
GENERATED = cr.GENERATED
OUT_ROOT = os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "semantic_idle_polish_v2")
SCREEN_DIR = os.path.join(GENERATED, "semantic_idle_polish_v2_screenshots")
CONTACT_PATH = os.path.join(GENERATED, "TERERE_IDLE_POLISH_V2_CONTACT_SHEET.png")
TIMES = (0.0, 0.9, 1.8, 2.7)
VIEWS = ("front", "three_quarter")

# Conservative standing deltas only. Intra-idle motion stays identical to baseline.
# Elbows ADD bend. V1 scaled elbows down and opened the silhouette.
CANDIDATES = {
    "V2_A": {
        "label": "MINIMAL",
        "spine_primary_delta": 0.0,
        "clavicle_primary": 7.5,
        "clavicle_secondary": 4.5,
        "upperarm_primary_add": 1.0,
        "elbow_primary_add": 2.0,
        "hand_primary": 9.0,
        "hand_secondary": 5.5,
        "notes": "95% baseline. Tiny shoulder drop, tiny extra elbow bend, wrists slightly quieter.",
    },
    "V2_B": {
        "label": "MODERATE",
        "spine_primary_delta": -1.0,
        "clavicle_primary": 7.0,
        "clavicle_secondary": 4.0,
        "upperarm_primary_add": 2.0,
        "elbow_primary_add": 4.0,
        "hand_primary": 8.5,
        "hand_secondary": 5.0,
        "notes": "90% baseline. 1 deg less spine, modest compact arms. Knees unchanged.",
    },
    "V2_C": {
        "label": "COMPACT",
        "spine_primary_delta": 0.0,
        "clavicle_primary": 6.5,
        "clavicle_secondary": 3.5,
        "upperarm_primary_add": 1.5,
        "elbow_primary_add": 6.0,
        "hand_primary": 8.0,
        "hand_secondary": 4.5,
        "notes": "Baseline torso kept. Slightly more compact arms/hands. Knees unchanged.",
    },
}

ROW_COLORS = {
    "BASELINE": (0.20, 0.45, 0.85, 1.0),
    "V1": (0.85, 0.22, 0.18, 1.0),
    "V2_A": (0.20, 0.72, 0.38, 1.0),
    "V2_B": (0.92, 0.78, 0.18, 1.0),
    "V2_C": (0.18, 0.78, 0.82, 1.0),
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


def apply_v2_ops(standing_ops, cand):
    ops = copy.deepcopy(standing_ops)
    spine = "CC_Base_Spine01"
    if spine in ops:
        ops[spine]["primary"] = cr.clamp_deg(
            spine,
            float(ops[spine]["primary"]) + float(cand.get("spine_primary_delta") or 0.0),
        )
        ops[spine]["polish"] = "v2_spine"
    add = float(cand.get("upperarm_primary_add") or 0.0)
    elbow_add = float(cand.get("elbow_primary_add") or 0.0)
    for side in ("L", "R"):
        clav = "CC_Base_%s_Clavicle" % side
        if clav in ops and cand.get("clavicle_primary") is not None:
            ops[clav]["primary"] = float(cand["clavicle_primary"])
            ops[clav]["secondary"] = float(cand.get("clavicle_secondary") or 0.0)
            ops[clav]["polish"] = "v2_shoulder_drop"
        arm = "CC_Base_%s_Upperarm" % side
        if arm in ops and add:
            ops[arm]["primary"] = cr.clamp_deg(arm, float(ops[arm]["primary"]) + add)
            ops[arm]["polish"] = "v2_upperarm_down"
        elbow = "CC_Base_%s_Forearm" % side
        if elbow in ops and elbow_add:
            ops[elbow]["primary"] = cr.clamp_deg(elbow, float(ops[elbow]["primary"]) + elbow_add)
            ops[elbow]["polish"] = "v2_elbow_keep_bend"
        hand = "CC_Base_%s_Hand" % side
        if hand in ops and cand.get("hand_primary") is not None:
            ops[hand]["primary"] = float(cand["hand_primary"])
            ops[hand]["secondary"] = float(cand.get("hand_secondary") or 0.0)
            ops[hand]["polish"] = "v2_hand_inward"
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
    l_from_down = cr.from_down_deg(arm, "CC_Base_L_Upperarm")
    r_from_down = cr.from_down_deg(arm, "CC_Base_R_Upperarm")
    return {
        "spine_from_up_deg": round(spine_lean, 3),
        "L_upperarm_from_down": round(l_from_down, 3),
        "R_upperarm_from_down": round(r_from_down, 3),
        "L_upperarm_down_from_horizontal": round(90.0 - l_from_down, 3),
        "R_upperarm_down_from_horizontal": round(90.0 - r_from_down, 3),
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


def time_to_frame(seconds, frame_start, fps=30.0):
    return int(round(float(frame_start) + float(seconds) * float(fps)))


def verify_frozen_baseline():
    baseline = load_json(os.path.join(GENERATED, "SEMANTIC_IDLE_POLISH_V1_BASELINE.json"))
    files = baseline.get("files") or {}
    report = {"ok": True, "files": {}}
    for key, meta in files.items():
        path = meta["path"]
        row = {"path": path, "expected": meta["sha256"]}
        if not os.path.isfile(path):
            row["ok"] = False
            row["reason"] = "missing"
            report["ok"] = False
        else:
            digest = sha256_file(path)
            row["actual"] = digest
            row["ok"] = digest == meta["sha256"]
            if not row["ok"]:
                report["ok"] = False
        report["files"][key] = row
    if not report["ok"]:
        raise RuntimeError("frozen semantic baseline hash mismatch")
    return report


def freeze_jaguarete():
    glb = os.path.join(
        PROJECT_ROOT, "assets", "fighters", "processed", "semantic_idle_polish_v1",
        "jaguarete", "jaguarete_idle_semantic_polished_v1.glb",
    )
    blend = os.path.splitext(glb)[0] + ".blend"
    record = {
        "authority": "JAGUARETE_SEMANTIC_IDLE_APPROVED_V1",
        "status": "FROZEN",
        "do_not_rebake": True,
        "do_not_modify": True,
        "glb": glb.replace("\\", "/"),
        "glb_sha256": sha256_file(glb),
        "glb_bytes": os.path.getsize(glb),
        "blend": blend.replace("\\", "/") if os.path.isfile(blend) else "",
        "blend_sha256": sha256_file(blend) if os.path.isfile(blend) else "",
        "note": "Human approved near-production. V2 does not regenerate Jaguarete.",
    }
    cr.write_json(os.path.join(GENERATED, "JAGUARETE_SEMANTIC_IDLE_APPROVED_V1.json"), record)
    return record


def restore_terere_v2_base():
    src = os.path.join(
        PROJECT_ROOT, "assets", "fighters", "processed", "idle_benchmark_v1",
        "terere", "terere_idle_semantic_clean_v1.glb",
    )
    dst_dir = os.path.join(OUT_ROOT, "terere")
    cr.ensure_dir(dst_dir)
    dst = os.path.join(dst_dir, "terere_idle_semantic_v2_base.glb")
    shutil.copy2(src, dst)
    metrics = load_json(os.path.join(GENERATED, "TERERE_IDLE_SEMANTIC_CLEAN_V1_METRICS.json"))
    record = {
        "id": "TERERE_V2_BASE",
        "restored_from": src.replace("\\", "/"),
        "copy": dst.replace("\\", "/"),
        "sha256_source": sha256_file(src),
        "sha256_copy": sha256_file(dst),
        "byte_identical": sha256_file(src) == sha256_file(dst),
        "standing_ops": metrics["standing_ops"],
    }
    cr.write_json(os.path.join(GENERATED, "TERERE_V2_BASE.json"), record)
    if not record["byte_identical"]:
        raise RuntimeError("TERERE_V2_BASE copy is not byte-identical")
    return record, metrics["standing_ops"]

def bake_candidate(cand_id, standing_ops):
    cand = CANDIDATES[cand_id]
    cfg = cr.CHARACTERS["terere"]
    semantic = cr.mixamo_channels_from_file()
    cr.open_blend(cfg["blend"])
    bpy.context.scene.render.fps = 30
    tgt = cr.find_cc_arm()
    mesh = cr.skinned_mesh(tgt)
    if tgt is None or mesh is None:
        raise RuntimeError("clean rig missing for terere")
    cr.disconnect(tgt)
    cr.clear_pose(tgt)
    bpy.context.view_layer.update()
    profile = cr.profile_axes(tgt)
    standing_ops_v2 = apply_v2_ops(standing_ops, cand)
    frames = semantic["frames"]
    frame_start = int(frames[0]["frame"])
    frame_end = int(frames[-1]["frame"])
    action = cr.new_action(tgt, "idle")
    keyed = list(standing_ops_v2.keys()) + ["CC_Base_Hip"]
    silhouettes = {}
    for item in frames:
        frame = item["frame"]
        ops = {}
        for bone, spec in standing_ops_v2.items():
            ops[bone] = dict(spec)
        intra = item.get("intra_from_standing") or item.get("intra_from_standing") or {}
        for channel, bone in CHANNEL_BONE.items():
            delta = float(intra.get(channel, 0.0))
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
        mixamo_span = float(semantic.get("mixamo_head_hip_span") or semantic.get("mixamo_head_hip_span") or 1.0)
        tgt_span = float((cr.world_head(tgt, "CC_Base_Head") - cr.world_head(tgt, "CC_Base_Hip")).length)
        height_scale = tgt_span / max(mixamo_span, 1e-6)
        dz = float(intra.get("hip_world_z", intra.get("hip_world_z", 0.0))) * height_scale
        hip_loc = cr.world_up_to_hip_local(tgt, "CC_Base_Hip", dz)
        if "CC_Base_Hip" in tgt.pose.bones:
            tgt.pose.bones["CC_Base_Hip"].location = hip_loc
        bpy.context.view_layer.update()
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
    metrics = cr.evaluate_action(tgt, mesh, action, "semantic_polish_v2")
    metrics.update({
        "character": "terere",
        "pipeline": "SEMANTIC_IDLE_POLISH_V2",
        "candidate": cand_id,
        "label": cand["label"],
        "copies_raw_mixamo_quaternion": False,
        "legacy_axis_hack": False,
        "runtime_retarget": False,
        "proxy_idle": False,
        "standing_ops_baseline": standing_ops,
        "standing_ops_polished": standing_ops_v2,
        "polish": cand,
        "knees_unchanged": True,
        "channel_gain": 1.0,
        "foot_stabilize": False,
        "silhouette": silhouettes,
        "texture_authority": cr.texture_authority(),
        "notes": cand["notes"],
    })
    out_dir = os.path.join(OUT_ROOT, "terere")
    cr.ensure_dir(out_dir)
    stem = "terere_idle_semantic_polished_v2_%s" % cand_id[-1].lower()
    glb = os.path.join(out_dir, stem + ".glb")
    blend = os.path.join(out_dir, stem + ".blend")
    if tgt.animation_data is None:
        tgt.animation_data_create()
    tgt.animation_data.action = action
    bpy.context.scene.frame_set(frame_start)
    cr.export_glb(glb)
    try:
        cr.save_blend(blend)
    except Exception as exc:
        print("WARN blend", exc)
        blend = ""
    metrics["output_glb"] = glb.replace("\\", "/")
    metrics["output_blend"] = blend.replace("\\", "/") if blend else ""
    metrics["output_glb_sha256"] = sha256_file(glb)
    cr.write_json(os.path.join(GENERATED, "TERERE_IDLE_SEMANTIC_POLISH_%s_METRICS.json" % cand_id), metrics)
    rt = cr.roundtrip_glb(glb, "semantic_polish_v2")
    cr.write_json(os.path.join(GENERATED, "TERERE_IDLE_SEMANTIC_POLISH_%s_ROUNDTRIP.json" % cand_id), rt)
    sil1 = silhouettes.get(str(frame_start)) or {}
    print("V2", cand_id, "pass", metrics.get("technical_pass"), "class", metrics.get("pose_classification"),
          "vol", metrics.get("max_volume_ratio"), "ext", metrics.get("max_extreme_verts"),
          "elbowL", sil1.get("L_elbow_flex"))
    return {"metrics": metrics, "roundtrip": rt, "glb": glb}

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
    if "V2Ground" in bpy.data.objects:
        return
    bpy.ops.mesh.primitive_plane_add(size=18.0, location=(0.0, 0.0, 0.0))
    plane = bpy.context.active_object
    plane.name = "V2Ground"
    mat = bpy.data.materials.new("V2GroundMat")
    mat.diffuse_color = (0.11, 0.13, 0.16, 1.0)
    plane.data.materials.append(mat)


def render_glb_grid(label, glb_path, shots):
    cr.reset_empty()
    bpy.ops.import_scene.gltf(filepath=glb_path)
    arm = cr.find_cc_arm()
    if arm is None:
        raise RuntimeError("no CC armature in %s" % glb_path)
    action = bind_action(arm)
    if action is None:
        raise RuntimeError("no action in %s" % glb_path)
    bpy.context.scene.render.fps = 30
    frame_start = int(action.frame_range[0])
    cr.setup_camera(arm)
    ensure_ground()
    scene = bpy.context.scene
    scene.render.resolution_x = 640
    scene.render.resolution_y = 360
    for seconds in TIMES:
        frame = time_to_frame(seconds, frame_start, 30.0)
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        for view in VIEWS:
            png = os.path.join(SCREEN_DIR, "%s_t%s_%s.png" % (label, str(seconds).replace(".", "p"), view))
            place_camera(arm, view)
            ok = try_render(png)
            shots.append({
                "candidate": label,
                "t": seconds,
                "view": view,
                "frame": frame,
                "path": png.replace("\\", "/") if ok else "",
                "ok": ok,
            })


def _px(img, x, y):
    width, height = int(img.size[0]), int(img.size[1])
    if x < 0 or y < 0 or x >= width or y >= height:
        return (0.08, 0.09, 0.11, 1.0)
    index = (y * width + x) * 4
    pixels = img.pixels
    return (pixels[index], pixels[index + 1], pixels[index + 2], pixels[index + 3])


def compose_contact(shots):
    cell_w, cell_h = 640, 360
    pad = 8
    stripe = 14
    rows_order = ["BASELINE", "V1", "V2_A", "V2_B", "V2_C"]
    cols = []
    for seconds in TIMES:
        for view in VIEWS:
            cols.append((seconds, view))
    lookup = {}
    for shot in shots:
        if shot.get("ok") and shot.get("path") and os.path.isfile(shot["path"]):
            lookup[(shot["candidate"], shot["t"], shot["view"])] = shot["path"]
    n_rows = len(rows_order)
    n_cols = len(cols)
    width = n_cols * (cell_w + pad) + pad + stripe
    height = n_rows * (cell_h + pad) + pad + stripe
    dest = bpy.data.images.new("V2Contact", width=width, height=height, alpha=True)
    pix = [0.07, 0.08, 0.10, 1.0] * (width * height)

    def set_px(x, y, rgba):
        if x < 0 or y < 0 or x >= width or y >= height:
            return
        index = (y * width + x) * 4
        pix[index] = rgba[0]
        pix[index + 1] = rgba[1]
        pix[index + 2] = rgba[2]
        pix[index + 3] = rgba[3]

    loaded = {}
    for path in lookup.values():
        if path not in loaded:
            loaded[path] = bpy.data.images.load(path)
    for r, cand in enumerate(rows_order):
        color = ROW_COLORS[cand]
        y0 = height - (pad + stripe + (r + 1) * (cell_h + pad))
        for y in range(y0, y0 + cell_h):
            for x in range(0, stripe):
                set_px(x, y, color)
        for c, (seconds, view) in enumerate(cols):
            x0 = stripe + pad + c * (cell_w + pad)
            path = lookup.get((cand, seconds, view))
            src = loaded.get(path) if path else None
            for yy in range(cell_h):
                for xx in range(cell_w):
                    if src is not None:
                        sx = min(int(src.size[0]) - 1, int(xx * src.size[0] / float(cell_w)))
                        sy = min(int(src.size[1]) - 1, int(yy * src.size[1] / float(cell_h)))
                        rgba = _px(src, sx, sy)
                    else:
                        rgba = (0.12, 0.12, 0.14, 1.0)
                    set_px(x0 + xx, y0 + yy, rgba)
    dest.pixels = pix
    dest.filepath_raw = CONTACT_PATH
    dest.file_format = "PNG"
    dest.save()
    print("CONTACT", CONTACT_PATH)
    return CONTACT_PATH


def metric_get(metrics, *keys, **kwargs):
    default = kwargs.get("default")
    for key in keys:
        if key in metrics:
            return metrics[key]
    return default


def main():
    cr.ensure_dir(GENERATED)
    cr.ensure_dir(SCREEN_DIR)
    cr.ensure_dir(os.path.join(OUT_ROOT, "terere"))
    baseline_check = verify_frozen_baseline()
    jag = freeze_jaguarete()
    base_record, standing_ops = restore_terere_v2_base()
    results = {}
    for cand_id in ("V2_A", "V2_B", "V2_C"):
        print("==== TERERE", cand_id, "====")
        results[cand_id] = bake_candidate(cand_id, standing_ops)
    glbs = {
        "BASELINE": os.path.join(
            PROJECT_ROOT, "assets", "fighters", "processed", "idle_benchmark_v1",
            "terere", "terere_idle_semantic_clean_v1.glb",
        ),
        "V1": os.path.join(
            PROJECT_ROOT, "assets", "fighters", "processed", "semantic_idle_polish_v1",
            "terere", "terere_idle_semantic_polished_v1.glb",
        ),
        "V2_A": results["V2_A"]["glb"],
        "V2_B": results["V2_B"]["glb"],
        "V2_C": results["V2_C"]["glb"],
    }
    shots = []
    for label, glb in glbs.items():
        print("==== RENDER", label, "====")
        render_glb_grid(label, glb, shots)
    compose_contact(shots)
    summary = {
        "pipeline": "SEMANTIC_IDLE_POLISH_V2",
        "verdict_token": "SSK_TERERE_SEMANTIC_IDLE_POLISH_V2_READY_FOR_HUMAN_SELECTION",
        "overwrote_idle_benchmark_v1": False,
        "overwrote_clean_rig_v1": False,
        "overwrote_semantic_idle_polish_v1": False,
        "jaguarete_rebaked": False,
        "wired_into_battle": False,
        "auto_selected_candidate": None,
        "frozen_baseline_ok": baseline_check["ok"],
        "terere_v2_base": base_record,
        "jaguarete_freeze": jag,
        "contact_sheet": CONTACT_PATH.replace("\\", "/"),
        "screenshots": shots,
        "candidates": {},
    }
    all_healthy = True
    for cand_id in ("V2_A", "V2_B", "V2_C"):
        m = results[cand_id]["metrics"]
        rt = results[cand_id]["roundtrip"]
        tech = bool(metric_get(m, "technical_pass", "technical_pass"))
        cls = metric_get(m, "pose_classification", "pose_classification")
        bones = int(rt.get("bone_count") or 0)
        healthy = (
            tech
            and cls == "STANDING_IDLE"
            and bones == 101
            and int(metric_get(m, "max_extreme_verts", "max_extreme_verts", default=1) or 1) == 0
            and float(metric_get(m, "max_limb_length_rel_error", "max_limb_length_rel_error", default=1) or 1) == 0.0
        )
        if not healthy:
            all_healthy = False
        sil = (m.get("silhouette") or {}).get("1") or {}
        summary["candidates"][cand_id] = {
            "label": CANDIDATES[cand_id]["label"],
            "technical_pass": tech,
            "pose_classification": cls,
            "healthy": healthy,
            "max_volume_ratio": metric_get(m, "max_volume_ratio", "max_volume_ratio"),
            "max_extreme_verts": metric_get(m, "max_extreme_verts", "max_extreme_verts"),
            "max_limb_length_rel_error": metric_get(m, "max_limb_length_rel_error", "max_limb_length_rel_error"),
            "max_root_xz": metric_get(m, "max_root_xz", "max_root_xz"),
            "roundtrip_ok": bool(rt.get("ok")),
            "roundtrip_bones": bones,
            "glb": m.get("output_glb"),
            "standing_ops": m.get("standing_ops_polished"),
            "silhouette_frame1": sil,
            "notes": CANDIDATES[cand_id]["notes"],
        }
    if not all_healthy:
        summary["verdict_token"] = "SSK_TERERE_SEMANTIC_IDLE_POLISH_V2_NOT_READY"
    cr.write_json(os.path.join(GENERATED, "SEMANTIC_IDLE_POLISH_V2_RUN.json"), summary)
    print("V2_SUMMARY", json.dumps(summary["candidates"], indent=2))
    print("VERDICT", summary["verdict_token"])


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
