"""
Phase 7-9: Generic Mixamo -> ActorCore offline retarget + bake + export.
Usage (after --):
  --character terere|jaguarete
  --source-animation <path>
  --output-blend <path>
  --output-glb <path>
  --action-name idle
"""
import argparse
import json
import math
import os
import sys

import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import (  # noqa: E402
    apply_clip_relative_rotation,
    apply_hip_y_clip_relative,
    apply_hip_y_only,
    apply_rest_relative_rotation,
    capture_clip_reference_quats,
    clear_pose,
    ensure_dir,
    find_armature,
    find_source_action,
    import_fbx,
    insert_pose_keyframes,
    mapped_pairs_from_bone_map,
    motion_audit_for_action,
    purge_orphans,
    reset_scene,
    setup_preview_camera,
    write_json,
)
from actorcore_paths import (  # noqa: E402
    BONE_MAP_JSON,
    CHARACTERS,
    EXPORT_ACTION_NAME,
    HIP_Y_SCALE,
    IDLE_FBX,
    MOTION_AUDIT_BONES,
    ROOT_XZ_TOLERANCE,
)


def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []
    parser = argparse.ArgumentParser()
    parser.add_argument("--character", required=True, choices=["terere", "jaguarete"])
    parser.add_argument("--source-animation", default=IDLE_FBX)
    parser.add_argument("--output-blend", default="")
    parser.add_argument("--output-glb", default="")
    parser.add_argument("--action-name", default=EXPORT_ACTION_NAME)
    parser.add_argument(
        "--retarget-mode",
        default="clip_relative",
        choices=["clip_relative", "rest_relative"],
        help="clip_relative = Mixamo deltas vs clip frame 1 (does not explode AccuRIG). "
             "rest_relative = Mixamo T-pose→pose (known catastrophic for idle).",
    )
    return parser.parse_args(argv)


def retarget_frame(source_arm, target_arm, pairs, frame, refs=None, hip_ref_y=0.0, mode="clip_relative"):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    for pair in pairs:
        src = pair["source"]
        dst = pair["target"]
        if src not in source_arm.pose.bones or dst not in target_arm.pose.bones:
            continue
        if mode == "clip_relative" and refs is not None and src in refs:
            apply_clip_relative_rotation(source_arm, target_arm, src, dst, refs[src])
            if pair.get("allow_location_y"):
                apply_hip_y_clip_relative(target_arm, dst, source_arm, src, hip_ref_y, HIP_Y_SCALE)
        else:
            apply_rest_relative_rotation(source_arm, target_arm, src, dst)
            if pair.get("allow_location_y"):
                apply_hip_y_only(target_arm, dst, source_arm, src, HIP_Y_SCALE)


def validate_action(target_arm, action, metrics):
    errors = []
    if target_arm is None:
        errors.append("target armature missing")
    if action is None or len(action.fcurves) == 0:
        errors.append("target action missing or empty")
    if metrics.get("keyed_target_bones", 0) == 0:
        errors.append("zero keyed bones")
    mesh_found = any(
        obj.type == "MESH" and any(mod.type == "ARMATURE" and mod.object == target_arm for mod in obj.modifiers)
        for obj in bpy.data.objects
    )
    if not mesh_found:
        errors.append("no skinned mesh")
    if metrics.get("root_translation_max_x", 0.0) > ROOT_XZ_TOLERANCE:
        errors.append("root X exceeds tolerance")
    if metrics.get("root_translation_max_z", 0.0) > ROOT_XZ_TOLERANCE:
        errors.append("root Z exceeds tolerance")
    return errors


def collect_metrics(action, pairs, hip_name="CC_Base_Hip"):
    keyed = set()
    for fc in action.fcurves:
        parts = fc.data_path.split('"')
        if len(parts) >= 2:
            keyed.add(parts[1])
    metrics = {
        "target_action": action.name if action else "",
        "frame_start": int(action.frame_range[0]) if action else 0,
        "frame_end": int(action.frame_range[1]) if action else 0,
        "fps": bpy.context.scene.render.fps,
        "mapped_bones": len(pairs),
        "keyed_target_bones": len(keyed),
        "root_translation_max_x": 0.0,
        "root_translation_max_y": 0.0,
        "root_translation_max_z": 0.0,
    }
    for axis, key in enumerate(("x", "y", "z")):
        path = 'pose.bones["%s"].location' % hip_name
        fc = action.fcurves.find(path, index=axis)
        if fc:
            vals = [abs(kp.co[1]) for kp in fc.keyframe_points]
            if vals:
                metrics["root_translation_max_%s" % key] = max(vals)
    return metrics


def delete_source_objects(source_arm):
    to_delete = [source_arm] if source_arm else []
    for child in list(source_arm.children) if source_arm else []:
        to_delete.append(child)
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and obj.parent == source_arm:
            to_delete.append(obj)
    for obj in to_delete:
        if obj and obj.name in bpy.data.objects:
            bpy.data.objects.remove(obj, do_unlink=True)
    for act in list(bpy.data.actions):
        if "mixamo" in act.name.lower():
            bpy.data.actions.remove(act)


def main():
    args = parse_args()
    cfg = CHARACTERS[args.character]
    output_blend = args.output_blend or cfg["preview_blend"]
    output_glb = args.output_glb or cfg["output_glb"]
    ensure_dir(cfg["benchmark_dir"])
    with open(BONE_MAP_JSON, "r", encoding="utf-8") as fh:
        bone_map = json.load(fh)
    pairs = mapped_pairs_from_bone_map(bone_map)
    reset_scene()
    bpy.context.scene.render.fps = 30
    import_fbx(cfg["fbx"])
    target_arm = find_armature()
    import_fbx(args.source_animation)
    arms = find_armatures_except(target_arm)
    source_arm = arms[0] if arms else None
    source_action = find_source_action(source_arm, "mixamo")
    if target_arm is None or source_arm is None or source_action is None:
        raise RuntimeError("Missing target/source/action for %s" % args.character)
    source_arm.animation_data_create()
    source_arm.animation_data.action = source_action
    frame_start = int(source_action.frame_range[0])
    frame_end = int(source_action.frame_range[1])
    refs = capture_clip_reference_quats(source_arm, pairs, frame_start) if args.retarget_mode == "clip_relative" else None
    bpy.context.scene.frame_set(frame_start)
    bpy.context.view_layer.update()
    hip_src = next((p["source"] for p in pairs if p.get("allow_location_y")), None)
    hip_ref_y = 0.0
    if hip_src and hip_src in source_arm.pose.bones:
        hip_ref_y = source_arm.pose.bones[hip_src].location.y
    clear_pose(target_arm)
    target_action = bpy.data.actions.new(args.action_name)
    target_arm.animation_data_create()
    target_arm.animation_data.action = target_action
    target_bones = [p["target"] for p in pairs]
    for frame in range(frame_start, frame_end + 1):
        retarget_frame(source_arm, target_arm, pairs, frame, refs, hip_ref_y, args.retarget_mode)
        insert_pose_keyframes(target_arm, target_bones, frame)
    target_action.name = args.action_name
    metrics = collect_metrics(target_action, pairs)
    motion = motion_audit_for_action(target_arm, target_action, MOTION_AUDIT_BONES)
    metrics["retarget_mode"] = args.retarget_mode
    bbox = _bbox_volume_audit(target_arm, target_action)
    metrics["bbox_audit"] = bbox
    write_json(cfg["motion_audit"], {"bake_metrics": metrics, "motion_audit": motion, "bbox_audit": bbox})
    errors = validate_action(target_arm, target_action, metrics)
    if not motion.get("accepted"):
        errors.append("motion audit rejected (branches_with_motion=%s)" % motion.get("branches_with_motion"))
    if bbox and not bbox.get("pass", True):
        errors.append("deformation bbox failed volume_ratio=%s" % bbox.get("volume_ratio"))
    delete_source_objects(source_arm)
    purge_orphans()
    setup_preview_camera(target_arm)
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end
    bpy.context.scene.frame_set(frame_start)
    bpy.context.view_layer.update()
    if errors:
        raise RuntimeError("Validation failed: %s" % "; ".join(errors))
    bpy.ops.export_scene.gltf(
        filepath=output_glb,
        export_format="GLB",
        export_animations=True,
        export_skins=True,
        export_materials=True,
        export_apply=False,
    )
    try:
        bpy.ops.wm.save_as_mainfile(filepath=output_blend)
    except Exception as exc:
        print("WARN blend save: %s" % exc)
    print("Bake complete %s glb=%s motion_accepted=%s" % (args.character, output_glb, motion.get("accepted")))


def find_armatures_except(exclude):
    return [o for o in bpy.data.objects if o.type == "ARMATURE" and o != exclude]


def _bbox_volume_audit(target_arm, action):
    mesh = None
    for obj in bpy.data.objects:
        if obj.type == "MESH" and any(mod.type == "ARMATURE" and mod.object == target_arm for mod in obj.modifiers):
            mesh = obj
            break
    if mesh is None:
        return {"pass": False, "reason": "no skinned mesh"}
    if target_arm.animation_data is None:
        target_arm.animation_data_create()
    target_arm.animation_data.action = None
    clear_pose(target_arm)
    bpy.context.view_layer.update()
    rest_vol, rest_size = _mesh_volume(mesh)
    target_arm.animation_data.action = action
    mid = int((action.frame_range[0] + action.frame_range[1]) * 0.5)
    bpy.context.scene.frame_set(mid)
    bpy.context.view_layer.update()
    idle_vol, idle_size = _mesh_volume(mesh)
    vol_ratio = idle_vol / max(rest_vol, 1e-6)
    max_ratio = max(idle_size) / max(max(rest_size), 1e-6)
    return {
        "rest_size": [round(x, 4) for x in rest_size],
        "idle_mid_size": [round(x, 4) for x in idle_size],
        "volume_ratio": round(vol_ratio, 4),
        "max_axis_ratio": round(max_ratio, 4),
        "pass": vol_ratio <= 1.35 and max_ratio <= 1.30,
    }


def _mesh_volume(mesh_obj):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = mesh_obj.evaluated_get(deps)
    xs = [v.co.x for v in ev.data.vertices]
    ys = [v.co.y for v in ev.data.vertices]
    zs = [v.co.z for v in ev.data.vertices]
    sx, sy, sz = max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)
    return abs(sx * sy * sz), (sx, sy, sz)


if __name__ == "__main__":
    main()
