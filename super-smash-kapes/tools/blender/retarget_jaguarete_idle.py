"""
Offline Mixamo Idle → Jaguareté v2 retarget + bake + GLB export.
Blender 2.83 — rest-relative rotation transfer, hip Y-only translation.
"""
import bpy
import json
import math
import os
import sys
from mathutils import Matrix, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from ssk_blender_paths import (  # noqa: E402
    BAKE_METRICS_JSON,
    BONE_MAP_JSON,
    EXPORT_ANIM_NAME,
    GAME_READY_GLB,
    IDLE_FBX,
    JAGUARETE_V2_GLB,
    PREVIEW_BLEND,
    PROCESSED_DIR,
    TARGET_ACTION_NAME,
)

ROOT_XZ_TOLERANCE = 0.05
HIP_Y_SCALE = 0.01  # Mixamo cm → Jaguareté unit scale for breathing only


def _reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _import_gltf(path: str) -> None:
    bpy.ops.import_scene.gltf(filepath=path)


def _import_fbx(path: str) -> None:
    bpy.ops.import_scene.fbx(filepath=path)


def _load_bone_map() -> dict:
    with open(BONE_MAP_JSON, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _find_armature(hint: str):
    for obj in bpy.data.objects:
        if obj.type == "ARMATURE" and obj.name == hint:
            return obj
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    return arms[0] if arms else None


def _find_source_action(source_arm, hint: str):
    if source_arm.animation_data and source_arm.animation_data.action:
        return source_arm.animation_data.action
    for act in bpy.data.actions:
        if hint in act.name:
            return act
    return bpy.data.actions[0] if bpy.data.actions else None


def _mapped_pairs(bone_map: dict) -> list:
    pairs = []
    for entry in bone_map["bones"]:
        if entry.get("class") != "REQUIRED":
            continue
        src = entry.get("source")
        dst = entry.get("target")
        if src and dst:
            pairs.append(
                {
                    "source": src,
                    "target": dst,
                    "allow_location_y": bool(entry.get("allow_location_y", False)),
                }
            )
    return pairs


def _rest_relative_matrix(source_arm, target_arm, source_name: str, target_name: str) -> Matrix:
    s_pb = source_arm.pose.bones[source_name]
    t_pb = target_arm.pose.bones[target_name]
    s_db = source_arm.data.bones[source_name]
    t_db = target_arm.data.bones[target_name]

    s_pose_world = source_arm.matrix_world @ s_pb.matrix
    s_rest_world = source_arm.matrix_world @ s_db.matrix_local
    t_rest_world = target_arm.matrix_world @ t_db.matrix_local

    delta_rot = s_rest_world.to_3x3().inverted() @ s_pose_world.to_3x3()
    t_pose_rot = t_rest_world.to_3x3() @ delta_rot
    t_pose_world = Matrix.Translation(t_rest_world.translation) @ t_pose_rot.to_4x4()
    return target_arm.matrix_world.inverted() @ t_pose_world


def _apply_hip_y_only(target_arm, target_name: str, source_arm, source_name: str) -> None:
    t_pb = target_arm.pose.bones[target_name]
    s_pb = source_arm.pose.bones[source_name]
    y_delta = s_pb.location.y * HIP_Y_SCALE
    t_pb.location = Vector((0.0, y_delta, 0.0))


def _retarget_frame(source_arm, target_arm, pairs: list, frame: int) -> None:
    scene = bpy.context.scene
    scene.frame_set(frame)
    bpy.context.view_layer.update()

    for pair in pairs:
        src = pair["source"]
        dst = pair["target"]
        if src not in source_arm.pose.bones or dst not in target_arm.pose.bones:
            continue
        t_pb = target_arm.pose.bones[dst]
        t_pb.matrix = _rest_relative_matrix(source_arm, target_arm, src, dst)
        if pair.get("allow_location_y"):
            _apply_hip_y_only(target_arm, dst, source_arm, src)


def _insert_pose_keyframes(target_arm, bone_names: list, frame: int) -> None:
    for name in bone_names:
        pb = target_arm.pose.bones.get(name)
        if pb is None:
            continue
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)
        if name == "Hip":
            pb.keyframe_insert(data_path="location", frame=frame)


def _purge_orphans() -> None:
    try:
        bpy.ops.outliner.orphans_purge(do_recursive=True)
    except Exception:
        pass


def _validate(target_arm, action, metrics: dict) -> list:
    errors = []
    if target_arm is None:
        errors.append("target armature missing")
    if action is None:
        errors.append("target action missing")
    elif len(action.fcurves) == 0:
        errors.append("target action has zero fcurves")
    if metrics.get("keyed_target_bones", 0) == 0:
        errors.append("zero keyed target bones")

    mesh_found = False
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for mod in obj.modifiers:
            if mod.type == "ARMATURE" and mod.object == target_arm:
                mesh_found = True
    if not mesh_found:
        errors.append("no mesh skinned to target armature")

    if metrics.get("root_translation_max_x", 0.0) > ROOT_XZ_TOLERANCE:
        errors.append("root X translation exceeds tolerance")
    if metrics.get("root_translation_max_z", 0.0) > ROOT_XZ_TOLERANCE:
        errors.append("root Z translation exceeds tolerance")

    for fc in action.fcurves if action else []:
        for kp in fc.keyframe_points:
            if math.isnan(kp.co[1]) or math.isinf(kp.co[1]):
                errors.append("invalid keyframe value on %s" % fc.data_path)
                break

    return errors


def _collect_metrics(action, pairs: list, hip_name: str = "Hip") -> dict:
    metrics = {
        "source_action": "",
        "target_action": action.name if action else "",
        "frame_start": int(action.frame_range[0]) if action else 0,
        "frame_end": int(action.frame_range[1]) if action else 0,
        "fps": bpy.context.scene.render.fps,
        "mapped_bones": len(pairs),
        "unmapped_bones": 0,
        "keyed_target_bones": 0,
        "root_translation_max_x": 0.0,
        "root_translation_max_y": 0.0,
        "root_translation_max_z": 0.0,
    }
    if action is None:
        return metrics

    keyed = set()
    for fc in action.fcurves:
        bone = fc.data_path.split('"')
        if len(bone) >= 2:
            keyed.add(bone[1])
    metrics["keyed_target_bones"] = len(keyed)

    for axis, key in enumerate(("x", "y", "z")):
        path = 'pose.bones["%s"].location' % hip_name
        fc = action.fcurves.find(path, index=axis)
        if fc is None:
            continue
        vals = [abs(kp.co[1]) for kp in fc.keyframe_points]
        if vals:
            metrics["root_translation_max_%s" % key] = max(vals)
    return metrics


def _delete_source_objects(source_arm) -> None:
    to_delete = []
    if source_arm:
        to_delete.append(source_arm)
        for child in source_arm.children:
            to_delete.append(child)
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and obj not in to_delete:
            if obj.parent == source_arm:
                to_delete.append(obj)
    for obj in to_delete:
        bpy.data.objects.remove(obj, do_unlink=True)
    for act in list(bpy.data.actions):
        if "mixamo" in act.name.lower():
            bpy.data.actions.remove(act)


def main() -> None:
    os.makedirs(PROCESSED_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(BAKE_METRICS_JSON), exist_ok=True)

    bone_map = _load_bone_map()
    pairs = _mapped_pairs(bone_map)

    _reset_scene()
    scene = bpy.context.scene
    scene.render.fps = 30

    _import_gltf(JAGUARETE_V2_GLB)
    target_arm = _find_armature(bone_map.get("target_armature_hint", "Armature"))

    _import_fbx(IDLE_FBX)
    source_arm = _find_armature(bone_map.get("source_armature_hint", "Armature.001"))
    source_action = _find_source_action(source_arm, bone_map.get("source_action_hint", "mixamo"))

    if target_arm is None or source_arm is None or source_action is None:
        raise RuntimeError("Failed to locate target/source armature or source action")

    source_arm.animation_data_create()
    source_arm.animation_data.action = source_action

    frame_start = int(source_action.frame_range[0])
    frame_end = int(source_action.frame_range[1])

    target_action = bpy.data.actions.new(TARGET_ACTION_NAME)
    if target_arm.animation_data is None:
        target_arm.animation_data_create()
    target_arm.animation_data.action = target_action

    target_bone_names = [p["target"] for p in pairs]

    for frame in range(frame_start, frame_end + 1):
        _retarget_frame(source_arm, target_arm, pairs, frame)
        _insert_pose_keyframes(target_arm, target_bone_names, frame)

    export_name = bone_map.get("export_animation_name", EXPORT_ANIM_NAME)
    target_action.name = export_name

    metrics = _collect_metrics(target_action, pairs)
    metrics["source_action"] = source_action.name

    _delete_source_objects(source_arm)
    _purge_orphans()

    errors = _validate(target_arm, target_action, metrics)
    if errors:
        metrics["validation_errors"] = errors
        with open(BAKE_METRICS_JSON, "w", encoding="utf-8") as fh:
            json.dump(metrics, fh, indent=2)
        raise RuntimeError("Validation failed: %s" % "; ".join(errors))

    bpy.ops.export_scene.gltf(
        filepath=GAME_READY_GLB,
        export_format="GLB",
        export_animations=True,
        export_skins=True,
        export_materials=True,
        export_apply=False,
    )

    try:
        bpy.ops.wm.save_as_mainfile(filepath=PREVIEW_BLEND)
    except Exception as exc:
        print("WARN: preview blend save failed: %s" % exc)

    metrics["validation_errors"] = []
    metrics["export_glb"] = GAME_READY_GLB
    metrics["preview_blend"] = PREVIEW_BLEND
    with open(BAKE_METRICS_JSON, "w", encoding="utf-8") as fh:
        json.dump(metrics, fh, indent=2)

    print("Bake complete:")
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
