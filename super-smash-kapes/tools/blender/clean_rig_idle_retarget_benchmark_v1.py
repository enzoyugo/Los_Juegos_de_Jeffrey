# -*- coding: utf-8 -*-
"""Clean Rig V1 Idle retarget benchmark for Blender 2.83.

Traditional: rest-space change-of-basis Mixamo -> CC_Base.
Semantic: native-axis standing + Mixamo intra-idle channels.
Target is Clean Rig V1 only. Production V4 and AccuRIG FBX are not opened as targets.
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
from mathutils import Matrix, Quaternion, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.normpath(os.path.join(SCRIPT_DIR, "..", ".."))
GENERATED = os.path.join(PROJECT_ROOT, "docs", "generated")
IDLE_FBX = os.path.join(PROJECT_ROOT, "assets", "fighters", "animations", "Idle.fbx")
BONE_MAP_JSON = os.path.join(SCRIPT_DIR, "mixamo_to_cc_base_clean_v1_bone_map.json")

CHARACTERS = {
    "terere": {
        "blend": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "clean_rig_v1", "terere", "terere_clean_rig_v1.blend"),
        "glb": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "clean_rig_v1", "terere", "terere_clean_rig_v1.glb"),
        "out_dir": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "idle_benchmark_v1", "terere"),
        "height": 2.40,
    },
    "jaguarete": {
        "blend": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "clean_rig_v1", "jaguarete", "jaguarete_clean_rig_v1.blend"),
        "glb": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "clean_rig_v1", "jaguarete", "jaguarete_clean_rig_v1.glb"),
        "out_dir": os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "idle_benchmark_v1", "jaguarete"),
        "height": 3.15,
    },
}

VOLUME_LIMIT = 1.35
AXIS_LIMIT = 1.35
LENGTH_REL_TOL = 0.05
EXTREME_FRAC = 0.35
CHANNEL_GAIN = 1.0
INTRA_CLAMP = 8.0
HIP_BREATH_LIMIT = 0.04
YAW_ROOT_LIMIT = 35.0
FOOT_SLIDE_LIMIT = 0.035

EXPECTED_CC_PARENTS = {
    "CC_Base_Hip": "root",
    "CC_Base_Waist": "CC_Base_Hip",
    "CC_Base_Spine01": "CC_Base_Waist",
    "CC_Base_Spine02": "CC_Base_Spine01",
    "CC_Base_NeckTwist01": "CC_Base_Spine02",
    "CC_Base_Head": "CC_Base_NeckTwist02",
    "CC_Base_L_Clavicle": "CC_Base_Spine02",
    "CC_Base_L_Upperarm": "CC_Base_L_Clavicle",
    "CC_Base_L_Forearm": "CC_Base_L_Upperarm",
    "CC_Base_L_Hand": "CC_Base_L_Forearm",
    "CC_Base_R_Clavicle": "CC_Base_Spine02",
    "CC_Base_R_Upperarm": "CC_Base_R_Clavicle",
    "CC_Base_R_Forearm": "CC_Base_R_Upperarm",
    "CC_Base_R_Hand": "CC_Base_R_Forearm",
    "CC_Base_L_Thigh": "CC_Base_Pelvis",
    "CC_Base_L_Calf": "CC_Base_L_Thigh",
    "CC_Base_L_Foot": "CC_Base_L_Calf",
    "CC_Base_R_Thigh": "CC_Base_Pelvis",
    "CC_Base_R_Calf": "CC_Base_R_Thigh",
    "CC_Base_R_Foot": "CC_Base_R_Calf",
}

HAND_CHAIN = (
    "CC_Base_L_Clavicle", "CC_Base_L_Upperarm", "CC_Base_L_Forearm", "CC_Base_L_Hand",
    "CC_Base_R_Clavicle", "CC_Base_R_Upperarm", "CC_Base_R_Forearm", "CC_Base_R_Hand",
)

LIMB_PAIRS = (
    ("CC_Base_L_Upperarm", "CC_Base_L_Forearm"),
    ("CC_Base_L_Forearm", "CC_Base_L_Hand"),
    ("CC_Base_R_Upperarm", "CC_Base_R_Forearm"),
    ("CC_Base_R_Forearm", "CC_Base_R_Hand"),
    ("CC_Base_L_Thigh", "CC_Base_L_Calf"),
    ("CC_Base_L_Calf", "CC_Base_L_Foot"),
    ("CC_Base_R_Thigh", "CC_Base_R_Calf"),
    ("CC_Base_R_Calf", "CC_Base_R_Foot"),
)

AXIS_KIND = {
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

SAFE = {
    "CC_Base_L_Clavicle": 20.0,
    "CC_Base_R_Clavicle": 20.0,
    "CC_Base_L_Upperarm": 80.0,
    "CC_Base_R_Upperarm": 80.0,
    "CC_Base_L_Forearm": 90.0,
    "CC_Base_R_Forearm": 90.0,
    "CC_Base_L_Hand": 25.0,
    "CC_Base_R_Hand": 25.0,
    "CC_Base_L_Calf": 40.0,
    "CC_Base_R_Calf": 40.0,
    "CC_Base_Spine01": 12.0,
    "CC_Base_Head": 12.0,
    "CC_Base_Hip": 8.0,
}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["dump-mixamo", "dump-baseline", "bake", "all"], default="all")
    parser.add_argument("--character", choices=["terere", "jaguarete", "both"], default="both")
    return parser.parse_args(argv)


def ensure_dir(path):
    if path and not os.path.isdir(path):
        os.makedirs(path)


def write_json(path, data):
    ensure_dir(os.path.dirname(path))
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)


def vec3(value):
    return [round(float(value.x), 6), round(float(value.y), 6), round(float(value.z), 6)]


def reset_empty():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for addon in ("io_scene_fbx", "io_scene_gltf2"):
        try:
            bpy.ops.preferences.addon_enable(module=addon)
        except Exception:
            pass


def open_blend(path):
    bpy.ops.wm.open_mainfile(filepath=path)


def import_fbx(path):
    bpy.ops.import_scene.fbx(filepath=path)


def export_glb(path):
    ensure_dir(os.path.dirname(path))
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_animations=True,
        export_skins=True,
        export_materials=True,
        export_apply=False,
    )


def save_blend(path):
    ensure_dir(os.path.dirname(path))
    bpy.ops.wm.save_as_mainfile(filepath=path)


def load_bone_map():
    with open(BONE_MAP_JSON, "r", encoding="utf-8") as handle:
        return json.load(handle)


def find_cc_arm():
    for obj in bpy.data.objects:
        if obj.type == "ARMATURE" and "CC_Base_Hip" in obj.pose.bones:
            return obj
    return None


def find_mixamo_arm():
    for obj in bpy.data.objects:
        if obj.type != "ARMATURE":
            continue
        for pose_bone in obj.pose.bones:
            if pose_bone.name.endswith("Hips") and "CC_Base" not in pose_bone.name:
                return obj
    return None


def discover_prefix(arm):
    for pose_bone in arm.pose.bones:
        if pose_bone.name.endswith("Hips"):
            return pose_bone.name[:-4]
    return ""


def mixamo_name(prefix, suffix):
    return prefix + suffix


def clear_pose(arm):
    identity = Quaternion()
    for pose_bone in arm.pose.bones:
        pose_bone.rotation_mode = "QUATERNION"
        pose_bone.rotation_quaternion = identity.copy()
        pose_bone.location = Vector((0.0, 0.0, 0.0))
        pose_bone.scale = Vector((1.0, 1.0, 1.0))
    bpy.context.view_layer.update()


def disconnect(arm):
    if arm.animation_data:
        arm.animation_data.action = None
        for track in getattr(arm.animation_data, "nla_tracks", []):
            track.mute = True


def skinned_mesh(arm):
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for modifier in obj.modifiers:
            if modifier.type == "ARMATURE" and modifier.object == arm:
                return obj
    return None


def world_head(arm, name):
    return arm.matrix_world @ arm.pose.bones[name].head


def world_tail(arm, name):
    return arm.matrix_world @ arm.pose.bones[name].tail


def bone_y_world(arm, name):
    pose_bone = arm.pose.bones[name]
    _loc, rot, _scale = (arm.matrix_world @ pose_bone.matrix).decompose()
    return (rot.to_matrix() @ Vector((0.0, 1.0, 0.0))).normalized()


def char_basis(arm):
    if "CC_Base_Hip" in arm.pose.bones:
        hip, head, left_arm, right_arm = "CC_Base_Hip", "CC_Base_Head", "CC_Base_L_Upperarm", "CC_Base_R_Upperarm"
    else:
        prefix = discover_prefix(arm)
        hip = mixamo_name(prefix, "Hips")
        head = mixamo_name(prefix, "Head")
        left_arm = mixamo_name(prefix, "LeftArm")
        right_arm = mixamo_name(prefix, "RightArm")
    up = (world_head(arm, head) - world_head(arm, hip)).normalized()
    right = (world_head(arm, right_arm) - world_head(arm, left_arm)).normalized()
    forward = up.cross(right)
    if forward.length < 1e-4:
        forward = Vector((0.0, -1.0, 0.0))
    else:
        forward.normalize()
    return up, forward, right


def from_down_deg(arm, name):
    up, _forward, _right = char_basis(arm)
    return math.degrees(bone_y_world(arm, name).angle(-up))


def flex_deg(arm, parent_name, child_name):
    return math.degrees(bone_y_world(arm, parent_name).angle(bone_y_world(arm, child_name)))


def object_xform(obj):
    euler = obj.rotation_euler
    return {
        "name": obj.name,
        "location": vec3(obj.location),
        "rotation_euler_deg": [round(math.degrees(euler.x), 4), round(math.degrees(euler.y), 4), round(math.degrees(euler.z), 4)],
        "scale": vec3(obj.scale),
        "normalized": (
            obj.location.length < 1e-5
            and abs(euler.x) < 1e-4 and abs(euler.y) < 1e-4 and abs(euler.z) < 1e-4
            and abs(obj.scale.x - 1.0) < 1e-4
            and abs(obj.scale.y - 1.0) < 1e-4
            and abs(obj.scale.z - 1.0) < 1e-4
        ),
    }


def mesh_bbox(mesh_obj):
    deps = bpy.context.evaluated_depsgraph_get()
    evaluated = mesh_obj.evaluated_get(deps)
    matrix_world = evaluated.matrix_world
    xs, ys, zs = [], [], []
    for vertex in evaluated.data.vertices:
        world = matrix_world @ vertex.co
        xs.append(world.x)
        ys.append(world.y)
        zs.append(world.z)
    size_x, size_y, size_z = max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)
    return {
        "min": [round(min(xs), 5), round(min(ys), 5), round(min(zs), 5)],
        "max": [round(max(xs), 5), round(max(ys), 5), round(max(zs), 5)],
        "size": [round(size_x, 5), round(size_y, 5), round(size_z, 5)],
        "volume": abs(size_x * size_y * size_z),
    }


def rest_points(mesh_obj):
    deps = bpy.context.evaluated_depsgraph_get()
    evaluated = mesh_obj.evaluated_get(deps)
    matrix_world = evaluated.matrix_world
    return [matrix_world @ vertex.co for vertex in evaluated.data.vertices]


def extreme_count(mesh_obj, rest_pts, rest_diag):
    deps = bpy.context.evaluated_depsgraph_get()
    evaluated = mesh_obj.evaluated_get(deps)
    matrix_world = evaluated.matrix_world
    limit = EXTREME_FRAC * max(rest_diag, 1e-6)
    count = 0
    vertices = evaluated.data.vertices
    total = min(len(vertices), len(rest_pts))
    for index in range(total):
        if (matrix_world @ vertices[index].co - rest_pts[index]).length > limit:
            count += 1
    return count


def limb_lengths(arm):
    lengths = {}
    for parent_name, child_name in LIMB_PAIRS:
        if parent_name in arm.pose.bones and child_name in arm.pose.bones:
            lengths[parent_name + "->" + child_name] = float((world_head(arm, child_name) - world_head(arm, parent_name)).length)
    return lengths


def texture_names():
    names = []
    for image in bpy.data.images:
        if image.size[0] > 0:
            names.append({"name": image.name, "filepath": image.filepath, "size": [int(image.size[0]), int(image.size[1])]})
    return names


def setup_camera(arm):
    camera_data = bpy.data.cameras.new("BenchmarkCamera")
    camera_obj = bpy.data.objects.new("BenchmarkCamera", camera_data)
    bpy.context.collection.objects.link(camera_obj)
    height = 1.6
    if "CC_Base_Head" in arm.pose.bones:
        height = max(1.2, float(world_head(arm, "CC_Base_Head").z) * 0.55)
    camera_obj.location = (0.0, -4.4, height)
    camera_obj.rotation_euler = (math.radians(78.0), 0.0, 0.0)
    camera_data.lens = 50
    bpy.context.scene.camera = camera_obj
    sun = bpy.data.lights.new("Sun", "SUN")
    sun_obj = bpy.data.objects.new("Sun", sun)
    bpy.context.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(50), 0.0, math.radians(30))


def delete_object(obj):
    if obj is None:
        return
    for child in list(obj.children):
        delete_object(child)
    bpy.data.objects.remove(obj, do_unlink=True)


def quat4(quat):
    return [round(float(quat.x), 6), round(float(quat.y), 6), round(float(quat.z), 6), round(float(quat.w), 6)]


def quat_angle_deg(quat):
    w = max(-1.0, min(1.0, float(quat.w)))
    return abs(math.degrees(2.0 * math.acos(w)))


def image_hash(image):
    payload = None
    if getattr(image, "packed_file", None) and image.packed_file:
        payload = bytes(image.packed_file.data)
    else:
        path = bpy.path.abspath(image.filepath) if image.filepath else ""
        if path and os.path.isfile(path):
            with open(path, "rb") as handle:
                payload = handle.read()
    if not payload:
        return ""
    return hashlib.md5(payload).hexdigest()[:16]


def texture_authority():
    rows = []
    for image in bpy.data.images:
        if image.size[0] <= 0:
            continue
        rows.append({
            "name": image.name,
            "filepath": image.filepath,
            "packed": bool(getattr(image, "packed_file", None) and image.packed_file),
            "size": [int(image.size[0]), int(image.size[1])],
            "md5_16": image_hash(image),
        })
    return rows


def parent_name(arm, bone_name):
    bone = arm.data.bones.get(bone_name)
    if bone is None:
        return None
    return bone.parent.name if bone.parent else None


def yaw_from_minus_y_deg(arm):
    _up, forward, _right = char_basis(arm)
    flat = Vector((forward.x, forward.y, 0.0))
    if flat.length < 1e-5:
        return 0.0
    flat.normalize()
    return math.degrees(flat.angle(Vector((0.0, -1.0, 0.0))))


def world_delta_to_pose_location(arm, bone_name, delta_world):
    rest_world = arm.matrix_world @ arm.data.bones[bone_name].matrix_local
    return rest_world.to_3x3().inverted() @ delta_world


def fcurve_channels(action, bone_name):
    rows = []
    if action is None:
        return rows
    needle = 'pose.bones["%s"]' % bone_name
    for curve in action.fcurves:
        path = curve.data_path or ""
        if needle not in path:
            continue
        keys = [round(float(kp.co[1]), 6) for kp in curve.keyframe_points[:8]]
        rows.append({
            "data_path": path,
            "array_index": int(curve.array_index),
            "key_count": len(curve.keyframe_points),
            "sample_values": keys,
        })
    return rows


def basis_sample(arm, name):
    pose_bone = arm.pose.bones[name]
    quat = pose_bone.matrix_basis.to_quaternion()
    return {
        "location": vec3(pose_bone.location),
        "quat": quat4(quat),
        "angle_deg": round(quat_angle_deg(quat), 4),
        "rotation_mode": pose_bone.rotation_mode,
    }


def mixamo_semantic(arm, prefix):
    def named(suffix):
        return mixamo_name(prefix, suffix)

    hips = named("Hips")
    return {
        "L_shoulder_lowering": round(from_down_deg(arm, named("LeftArm")), 4),
        "R_shoulder_lowering": round(from_down_deg(arm, named("RightArm")), 4),
        "L_elbow_flexion": round(flex_deg(arm, named("LeftArm"), named("LeftForeArm")), 4),
        "R_elbow_flexion": round(flex_deg(arm, named("RightArm"), named("RightForeArm")), 4),
        "L_hand_from_down": round(from_down_deg(arm, named("LeftHand")), 4),
        "R_hand_from_down": round(from_down_deg(arm, named("RightHand")), 4),
        "L_knee_flexion": round(flex_deg(arm, named("LeftUpLeg"), named("LeftLeg")), 4),
        "R_knee_flexion": round(flex_deg(arm, named("RightUpLeg"), named("RightLeg")), 4),
        "torso_lean": round(math.degrees(bone_y_world(arm, named("Spine1")).angle(char_basis(arm)[0])), 4),
        "head_lean": round(math.degrees(bone_y_world(arm, named("Head")).angle(char_basis(arm)[0])), 4),
        "hip_y": round(float(arm.pose.bones[hips].location.y), 5),
        "hip_world_z": round(float(world_head(arm, hips).z), 5),
    }


def dump_mixamo():
    reset_empty()
    bpy.context.scene.render.fps = 30
    import_fbx(IDLE_FBX)
    arm = find_mixamo_arm()
    if arm is None:
        raise RuntimeError("Mixamo armature not found in Idle.fbx")
    prefix = discover_prefix(arm)
    action = None
    if arm.animation_data and arm.animation_data.action:
        action = arm.animation_data.action
    if action is None:
        for candidate in bpy.data.actions:
            lowered = candidate.name.lower()
            if "mixamo" in lowered or "idle" in lowered:
                action = candidate
                break
    if action is None and bpy.data.actions:
        action = bpy.data.actions[0]
    disconnect(arm)
    clear_pose(arm)
    bpy.context.view_layer.update()
    rest_channels = mixamo_semantic(arm, prefix)
    rest_bones = {}
    hierarchy = {}
    for bone in arm.data.bones:
        hierarchy[bone.name] = bone.parent.name if bone.parent else None
        rest_bones[bone.name] = {
            "parent": bone.parent.name if bone.parent else None,
            "head": vec3(bone.head_local),
            "tail": vec3(bone.tail_local),
        }
    hip = mixamo_name(prefix, "Hips")
    head_name = mixamo_name(prefix, "Head")
    mixamo_span = 0.0
    if hip in arm.pose.bones and head_name in arm.pose.bones:
        mixamo_span = float((world_head(arm, head_name) - world_head(arm, hip)).length)
    rest_basis = {}
    frame1_basis = {}
    major_suffixes = (
        "Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
        "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
        "RightShoulder", "RightArm", "RightForeArm", "RightHand",
        "LeftUpLeg", "LeftLeg", "LeftFoot",
        "RightUpLeg", "RightLeg", "RightFoot",
    )
    for suffix in major_suffixes:
        name = mixamo_name(prefix, suffix)
        if name in arm.pose.bones:
            rest_basis[name] = basis_sample(arm, name)
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    frame_start = int(action.frame_range[0]) if action else 1
    frame_end = int(action.frame_range[1]) if action else 1
    loc_keys = {"x": [], "y": [], "z": []}
    if hip in arm.pose.bones:
        for frame in range(frame_start, frame_end + 1):
            bpy.context.scene.frame_set(frame)
            bpy.context.view_layer.update()
            loc = arm.pose.bones[hip].location
            loc_keys["x"].append(float(loc.x))
            loc_keys["y"].append(float(loc.y))
            loc_keys["z"].append(float(loc.z))
    channels = []
    if action:
        bpy.context.scene.frame_set(frame_start)
        bpy.context.view_layer.update()
        standing = mixamo_semantic(arm, prefix)
        for suffix in major_suffixes:
            name = mixamo_name(prefix, suffix)
            if name in arm.pose.bones:
                frame1_basis[name] = basis_sample(arm, name)
        for frame in range(frame_start, frame_end + 1):
            bpy.context.scene.frame_set(frame)
            bpy.context.view_layer.update()
            world = mixamo_semantic(arm, prefix)
            intra = {}
            for key in world:
                intra[key] = round(world[key] - standing[key], 5 if key == "hip_y" else 4)
            channels.append({"frame": frame, "world": world, "intra_from_standing": intra})
    else:
        standing = {}
    bone_map = load_bone_map()
    names = set(arm.pose.bones.keys())
    local_rot = {}
    for suffix in ("Hips", "Spine1", "LeftArm", "RightArm", "LeftUpLeg", "Head"):
        name = mixamo_name(prefix, suffix)
        local_rot[name] = fcurve_channels(action, name)
    report = {
        "source": IDLE_FBX.replace("\\", "/"),
        "armature": arm.name,
        "namespace_prefix": prefix,
        "prefix": prefix,
        "bone_count": len(arm.data.bones),
        "bones": sorted(list(arm.pose.bones.keys())),
        "hierarchy_major": {
            mixamo_name(prefix, suffix): hierarchy.get(mixamo_name(prefix, suffix))
            for suffix in major_suffixes
            if mixamo_name(prefix, suffix) in hierarchy
        },
        "rest_pose": "bind_pose_edit_bones",
        "rest_is_bind_pose": True,
        "frame_1_is_not_rest": True,
        "action": action.name if action else "",
        "frame_start": frame_start,
        "frame_end": frame_end,
        "fps": int(bpy.context.scene.render.fps),
        "object": object_xform(arm),
        "rest_channels": rest_channels,
        "standing_channels": standing,
        "rest_local_basis": rest_basis,
        "frame1_local_basis": frame1_basis,
        "local_rotation_fcurves": local_rot,
        "root_location_keys": {
            "x": {"min": round(min(loc_keys["x"] or [0]), 5), "max": round(max(loc_keys["x"] or [0]), 5)},
            "y": {"min": round(min(loc_keys["y"] or [0]), 5), "max": round(max(loc_keys["y"] or [0]), 5)},
            "z": {"min": round(min(loc_keys["z"] or [0]), 5), "max": round(max(loc_keys["z"] or [0]), 5)},
        },
        "root_motion_policy": "zero world X/Y; clamp world Z breathing",
        "frame_count": len(channels),
        "mixamo_head_hip_span": round(mixamo_span, 6),
        "required_suffixes_present": {},
        "copies_raw_euler": False,
        "copies_raw_quaternion": False,
        "prior_dumps_not_used": True,
        "rest_bones_major": {
            key: rest_bones[key] for key in rest_bones
            if key.split(":")[-1] in major_suffixes
        },
    }
    for entry in bone_map["required"]:
        expected = prefix + entry["mixamo_suffix"]
        report["required_suffixes_present"][entry["mixamo_suffix"]] = expected in names
    write_json(os.path.join(GENERATED, "MIXAMO_IDLE_FOR_CLEAN_RIG_DUMP.json"), report)
    hip_name = mixamo_name(prefix, "Hips")
    head_name = mixamo_name(prefix, "Head")
    disconnect(arm)
    clear_pose(arm)
    mixamo_span = 0.0
    if hip_name in arm.pose.bones and head_name in arm.pose.bones:
        mixamo_span = float((world_head(arm, head_name) - world_head(arm, hip_name)).length)
    write_json(os.path.join(GENERATED, "MIXAMO_IDLE_SEMANTIC_CHANNELS_CLEAN_V1.json"), {
        "source": IDLE_FBX.replace("\\", "/"),
        "prefix": prefix,
        "copies_mixamo_quaternion": False,
        "method": "anatomical_world_angles_not_quaternions",
        "rest_is_edit_bind": True,
        "standing_is_first_animated_frame_not_rest": True,
        "mixamo_head_hip_span": round(mixamo_span, 6),
        "rest": rest_channels,
        "standing": standing,
        "frames": channels,
    })
    print("DUMP_MIXAMO prefix=%s bones=%d frames=%s-%s" % (prefix, len(arm.data.bones), frame_start, frame_end))
    return report


def dump_baseline(character):
    cfg = CHARACTERS[character]
    open_blend(cfg["blend"])
    arm = find_cc_arm()
    if arm is None:
        raise RuntimeError("CC armature missing in %s" % cfg["blend"])
    mesh = skinned_mesh(arm)
    disconnect(arm)
    clear_pose(arm)
    bpy.context.view_layer.update()
    rest = {}
    for name in (
        "CC_Base_Hip", "CC_Base_Head", "CC_Base_L_Hand", "CC_Base_R_Hand",
        "CC_Base_L_Foot", "CC_Base_R_Foot", "CC_Base_L_Upperarm", "CC_Base_R_Upperarm",
    ):
        if name not in arm.pose.bones:
            continue
        data_bone = arm.data.bones[name]
        rest[name] = {
            "head_local": vec3(data_bone.head_local),
            "tail_local": vec3(data_bone.tail_local),
            "world_head": vec3(world_head(arm, name)),
        }
    materials = []
    if mesh and mesh.data.materials:
        materials = [material.name for material in mesh.data.materials if material]
    bbox = mesh_bbox(mesh) if mesh else {}
    hierarchy = {}
    hierarchy_ok = True
    for name, expected in EXPECTED_CC_PARENTS.items():
        actual = parent_name(arm, name)
        hierarchy[name] = {"parent": actual, "expected": expected, "ok": actual == expected}
        if actual != expected:
            hierarchy_ok = False
    aligned = {}
    aligned_ok = True
    if bbox:
        pad = 0.2
        bmin, bmax = bbox["min"], bbox["max"]
        for name in ("CC_Base_Hip", "CC_Base_Head", "CC_Base_L_Hand", "CC_Base_R_Hand", "CC_Base_L_Foot", "CC_Base_R_Foot"):
            if name not in arm.pose.bones:
                aligned[name] = {"inside": False}
                aligned_ok = False
                continue
            pos = world_head(arm, name)
            inside = (
                bmin[0] - pad <= pos.x <= bmax[0] + pad
                and bmin[1] - pad <= pos.y <= bmax[1] + pad
                and bmin[2] - pad <= pos.z <= bmax[2] + pad
            )
            aligned[name] = {"world_head": vec3(pos), "inside_mesh_bbox": inside}
            if not inside:
                aligned_ok = False
    l_arm = from_down_deg(arm, "CC_Base_L_Upperarm") if "CC_Base_L_Upperarm" in arm.pose.bones else 0.0
    r_arm = from_down_deg(arm, "CC_Base_R_Upperarm") if "CC_Base_R_Upperarm" in arm.pose.bones else 0.0
    hidden = [obj.name for obj in bpy.data.objects if ("mixamo" in obj.name.lower() or "source_rigged" in obj.name.lower())]
    action_names = [action.name for action in bpy.data.actions]
    return {
        "character": character,
        "blend": cfg["blend"].replace("\\", "/"),
        "glb": cfg["glb"].replace("\\", "/"),
        "bone_count": len(arm.data.bones),
        "mesh_count": 1 if mesh else 0,
        "material_count": len(materials),
        "materials": materials,
        "textures": texture_names(),
        "texture_authority": texture_authority(),
        "object_transforms": {
            "armature": object_xform(arm),
            "mesh": object_xform(mesh) if mesh else {},
        },
        "rest_major_bones": rest,
        "rest_bbox": bbox,
        "rest_transforms": rest,
        "actions": action_names,
        "has_cc_base_hip": "CC_Base_Hip" in arm.pose.bones,
        "cc_base_hierarchy": hierarchy,
        "cc_base_hierarchy_ok": hierarchy_ok,
        "mesh_armature_aligned": aligned_ok,
        "alignment": aligned,
        "rest_is_tpose": (0.5 * (l_arm + r_arm)) >= 75.0,
        "hidden_source_rig": hidden,
        "no_hidden_source_rig": len(hidden) == 0,
        "pipeline": "CLEAN_RIG_V1",
        "target_height": cfg["height"],
        "rest_tpose_upperarm_from_down_deg": {
            "L": round(l_arm, 3),
            "R": round(r_arm, 3),
        },
    }


def dump_all_baselines():
    rows = {}
    for character in ("terere", "jaguarete"):
        rows[character] = dump_baseline(character)
    payload = {
        "pipeline": "CLEAN_RIG_V1",
        "animation_source": IDLE_FBX.replace("\\", "/"),
        "not_used": ["game_ready_v4", "semantic_solver_v2", "solver_v1", "actorcore_benchmark", "source_rigged"],
        "fighters": rows,
    }
    write_json(os.path.join(GENERATED, "CLEAN_RIG_IDLE_BENCHMARK_BASELINE.json"), payload)
    print("DUMP_BASELINE terere_bones=%s jaguarete_bones=%s" % (
        rows["terere"]["bone_count"], rows["jaguarete"]["bone_count"]))
    return payload


def mapped_pairs(src_arm, tgt_arm):
    prefix = discover_prefix(src_arm)
    pairs = []
    for entry in load_bone_map()["required"]:
        src = prefix + entry["mixamo_suffix"]
        dst = entry["target"]
        if src in src_arm.pose.bones and dst in tgt_arm.pose.bones:
            pairs.append({
                "source": src,
                "target": dst,
                "allow_location_y": bool(entry.get("allow_location_y")),
            })
    return pairs, prefix


def compute_C(src_arm, tgt_arm, src_name, tgt_name):
    src_rest = (src_arm.matrix_world @ src_arm.data.bones[src_name].matrix_local).to_3x3()
    tgt_rest = (tgt_arm.matrix_world @ tgt_arm.data.bones[tgt_name].matrix_local).to_3x3()
    return tgt_rest.inverted() @ src_rest


def world_up_to_hip_local(arm, hip_name, delta_z):
    dz = max(-HIP_BREATH_LIMIT, min(HIP_BREATH_LIMIT, float(delta_z)))
    return world_delta_to_pose_location(arm, hip_name, Vector((0.0, 0.0, dz)))


def apply_traditional_frame(src_arm, tgt_arm, pairs, c_map, src_hip, tgt_hip, src_hip_rest_w, height_scale):
    for pair in pairs:
        src, dst = pair["source"], pair["target"]
        change = c_map[dst]
        src_pose = src_arm.pose.bones[src]
        tgt_pose = tgt_arm.pose.bones[dst]
        src_rot = src_pose.matrix_basis.to_3x3()
        tgt_rot = change @ src_rot @ change.inverted()
        tgt_pose.rotation_mode = "QUATERNION"
        tgt_pose.matrix_basis = tgt_rot.to_4x4()
        tgt_pose.location = Vector((0.0, 0.0, 0.0))
        tgt_pose.scale = Vector((1.0, 1.0, 1.0))
    src_world = (src_arm.matrix_world @ src_arm.pose.bones[src_hip].matrix).to_translation()
    delta_z = (src_world.z - src_hip_rest_w.z) * height_scale
    tgt_arm.pose.bones[tgt_hip].location = world_up_to_hip_local(tgt_arm, tgt_hip, delta_z)


def new_action(arm, name):
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    return action


def key_mapped(arm, pairs, frame, hip_name):
    for pair in pairs:
        pose_bone = arm.pose.bones[pair["target"]]
        pose_bone.rotation_mode = "QUATERNION"
        pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame)
        if pair["target"] == hip_name:
            pose_bone.keyframe_insert(data_path="location", frame=frame)


def classify_pose(arm, volume_ok, length_ok, extreme_n, rest_forward=None):
    if not volume_ok or not length_ok or extreme_n > 0:
        return "DEFORMATION_INVALID"
    mean_arm = 0.5 * (from_down_deg(arm, "CC_Base_L_Upperarm") + from_down_deg(arm, "CC_Base_R_Upperarm"))
    if mean_arm >= 70.0:
        return "T_POSE_LIKE"
    up, forward, _right = char_basis(arm)
    lean = math.degrees(bone_y_world(arm, "CC_Base_Spine01").angle(up))
    if lean >= 40.0:
        return "SIDEWAYS"
    if rest_forward is not None and rest_forward.length > 1e-6:
        yaw = math.degrees(forward.angle(rest_forward))
        if yaw >= 45.0:
            return "ROOT_ROTATED"
    return "STANDING_IDLE"


def arm_quality(arm):
    names = [
        "CC_Base_L_Clavicle", "CC_Base_L_Upperarm", "CC_Base_L_Forearm", "CC_Base_L_Hand",
        "CC_Base_R_Clavicle", "CC_Base_R_Upperarm", "CC_Base_R_Forearm", "CC_Base_R_Hand",
    ]
    out = {}
    for name in names:
        if name not in arm.pose.bones:
            continue
        out[name] = {
            "from_down_deg": round(from_down_deg(arm, name), 3),
            "world_head": vec3(world_head(arm, name)),
        }
    out["L_elbow_flex_deg"] = round(flex_deg(arm, "CC_Base_L_Upperarm", "CC_Base_L_Forearm"), 3)
    out["R_elbow_flex_deg"] = round(flex_deg(arm, "CC_Base_R_Upperarm", "CC_Base_R_Forearm"), 3)
    return out


def evaluate_action(arm, mesh, action, label):
    disconnect(arm)
    clear_pose(arm)
    bpy.context.view_layer.update()
    rest_bbox = mesh_bbox(mesh)
    rest_len = limb_lengths(arm)
    rest_pts = rest_points(mesh)
    rest_diag = math.sqrt(sum(size * size for size in rest_bbox["size"]))
    rest_hip = world_head(arm, "CC_Base_Hip").copy()
    rest_lfoot = world_head(arm, "CC_Base_L_Foot").copy()
    rest_rfoot = world_head(arm, "CC_Base_R_Foot").copy()
    rest_arm = arm_quality(arm)
    _up, rest_forward, _right = char_basis(arm)
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    frame_start = int(action.frame_range[0])
    frame_end = int(action.frame_range[1])
    mid = int(0.5 * (frame_start + frame_end))
    probe = list(range(frame_start, frame_end + 1))
    samples = []
    max_vol = max_axis = max_len = max_root_xz = 0.0
    max_ext = 0
    foot_d = hand_d = 0.0
    hip_zs = []
    mid_class = "UNKNOWN"
    mid_arm = None
    first_arm = None
    last_arm = None
    rest_lhand = world_head(arm, "CC_Base_L_Hand").copy()
    rest_rhand = world_head(arm, "CC_Base_R_Hand").copy()
    lfoot_xs, lfoot_ys, rfoot_xs, rfoot_ys = [], [], [], []
    max_axis_comp = [0.0, 0.0, 0.0]
    for frame in probe:
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        bbox = mesh_bbox(mesh)
        vol_ratio = bbox["volume"] / max(rest_bbox["volume"], 1e-8)
        axis_ratio = max(bbox["size"]) / max(max(rest_bbox["size"]), 1e-8)
        for axis_i in range(3):
            max_axis_comp[axis_i] = max(
                max_axis_comp[axis_i],
                bbox["size"][axis_i] / max(rest_bbox["size"][axis_i], 1e-8),
            )
        lfoot = world_head(arm, "CC_Base_L_Foot")
        rfoot = world_head(arm, "CC_Base_R_Foot")
        lfoot_xs.append(lfoot.x)
        lfoot_ys.append(lfoot.y)
        rfoot_xs.append(rfoot.x)
        rfoot_ys.append(rfoot.y)
        lengths = limb_lengths(arm)
        len_err = 0.0
        for key, rest_length in rest_len.items():
            if rest_length > 1e-8:
                len_err = max(len_err, abs(lengths[key] - rest_length) / rest_length)
        ext = extreme_count(mesh, rest_pts, rest_diag)
        hip = world_head(arm, "CC_Base_Hip")
        root_xz = math.sqrt((hip.x - rest_hip.x) ** 2 + (hip.y - rest_hip.y) ** 2)
        hip_zs.append(hip.z)
        foot_d = max(
            foot_d,
            (world_head(arm, "CC_Base_L_Foot") - rest_lfoot).length,
            (world_head(arm, "CC_Base_R_Foot") - rest_rfoot).length,
        )
        hand_d = max(
            hand_d,
            (world_head(arm, "CC_Base_L_Hand") - rest_lhand).length,
            (world_head(arm, "CC_Base_R_Hand") - rest_rhand).length,
        )
        max_vol = max(max_vol, vol_ratio)
        max_axis = max(max_axis, axis_ratio)
        max_len = max(max_len, len_err)
        max_ext = max(max_ext, ext)
        max_root_xz = max(max_root_xz, root_xz)
        cls = classify_pose(
            arm,
            vol_ratio <= VOLUME_LIMIT and axis_ratio <= AXIS_LIMIT,
            len_err <= LENGTH_REL_TOL,
            ext,
            rest_forward,
        )
        row = {
            "frame": frame,
            "volume_ratio": round(vol_ratio, 4),
            "axis_ratio": round(axis_ratio, 4),
            "limb_length_rel_error": round(len_err, 5),
            "extreme_verts": ext,
            "root_xz": round(root_xz, 5),
            "classification": cls,
        }
        if frame in (frame_start, mid, frame_end):
            row["arm"] = arm_quality(arm)
        samples.append(row)
        if frame == frame_start:
            first_arm = row.get("arm")
        if frame == mid:
            mid_class = cls
            mid_arm = row.get("arm")
        if frame == frame_end:
            last_arm = row.get("arm")
    tech_pass = (
        max_vol <= VOLUME_LIMIT
        and max_axis <= AXIS_LIMIT
        and max_len <= LENGTH_REL_TOL
        and max_ext == 0
        and mid_class == "STANDING_IDLE"
    )
    return {
        "method": label,
        "frame_start": frame_start,
        "frame_end": frame_end,
        "max_volume_ratio": round(max_vol, 4),
        "max_axis_ratio": round(max_axis, 4),
        "max_limb_length_rel_error": round(max_len, 5),
        "max_extreme_verts": max_ext,
        "max_root_xz": round(max_root_xz, 5),
        "max_foot_drift": round(foot_d, 5),
        "max_hand_drift": round(hand_d, 5),
        "hip_z_variance": round(max(hip_zs) - min(hip_zs), 5) if hip_zs else 0.0,
        "pose_classification": mid_class,
        "technical_pass": tech_pass,
        "rest_arm": rest_arm,
        "first_arm": first_arm,
        "mid_arm": mid_arm,
        "last_arm": last_arm,
        "principal_axis_ratios": {
            "x": round(max_axis_comp[0], 4),
            "y": round(max_axis_comp[1], 4),
            "z": round(max_axis_comp[2], 4),
        },
        "grounding": {
            "l_foot_xz_span": round(max(lfoot_xs) - min(lfoot_xs) + max(lfoot_ys) - min(lfoot_ys), 5) if lfoot_xs else 0.0,
            "r_foot_xz_span": round(max(rfoot_xs) - min(rfoot_xs) + max(rfoot_ys) - min(rfoot_ys), 5) if rfoot_xs else 0.0,
            "visible_foot_slide": bool(
                (max(lfoot_xs) - min(lfoot_xs) > FOOT_SLIDE_LIMIT if lfoot_xs else False)
                or (max(lfoot_ys) - min(lfoot_ys) > FOOT_SLIDE_LIMIT if lfoot_ys else False)
                or (max(rfoot_xs) - min(rfoot_xs) > FOOT_SLIDE_LIMIT if rfoot_xs else False)
                or (max(rfoot_ys) - min(rfoot_ys) > FOOT_SLIDE_LIMIT if rfoot_ys else False)
            ),
        },
        "samples": samples,
    }


def rotate_local(arm, name, axis, degrees):
    pose_bone = arm.pose.bones[name]
    pose_bone.rotation_mode = "QUATERNION"
    pose_bone.rotation_quaternion = Quaternion(Vector(axis).normalized(), math.radians(degrees))
    pose_bone.location = Vector((0.0, 0.0, 0.0))
    pose_bone.scale = Vector((1.0, 1.0, 1.0))


def profile_axes(arm):
    up, forward, _right = char_basis(arm)
    profile = {}
    for bone, kind in AXIS_KIND.items():
        if bone not in arm.pose.bones:
            continue
        rest_tail = world_tail(arm, bone).copy()
        ranked = []
        for axis in ((1.0, 0.0, 0.0), (0.0, 0.0, 1.0)):
            for sign in (1.0, -1.0):
                clear_pose(arm)
                rotate_local(arm, bone, axis, sign * 25.0)
                bpy.context.view_layer.update()
                posed = world_tail(arm, bone)
                if kind == "lower_arm":
                    score = (rest_tail - posed).dot(up)
                elif kind in ("bend_elbow", "bend_knee"):
                    score = abs((posed - rest_tail).length)
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
        }
        clear_pose(arm)
    bpy.context.view_layer.update()
    return profile


def pose_ops(arm, bone, info, primary, secondary=0.0):
    pose_bone = arm.pose.bones[bone]
    pose_bone.rotation_mode = "QUATERNION"
    quat = Quaternion(Vector(info["primary_axis_vec"]).normalized(), math.radians(info["sign"] * primary))
    if abs(secondary) > 1e-4:
        quat2 = Quaternion(
            Vector(info["secondary_axis_vec"]).normalized(),
            math.radians(info["secondary_sign"] * secondary),
        )
        quat = quat @ quat2
    pose_bone.rotation_quaternion = quat
    pose_bone.location = Vector((0.0, 0.0, 0.0))
    pose_bone.scale = Vector((1.0, 1.0, 1.0))


def clamp_deg(bone, value):
    limit = SAFE.get(bone, 30.0)
    if value > limit:
        return limit
    if value < -limit:
        return -limit
    return value


def apply_ops_map(arm, profile, ops):
    for bone, spec in ops.items():
        if bone in profile:
            pose_ops(arm, bone, profile[bone], spec.get("primary", 0.0), spec.get("secondary", 0.0))


def solve_primary(arm, profile, standing_ops, bone, info, metric_fn, target, lo, hi, step=4.0):
    best = 0.0
    best_err = 1e9
    angle = lo
    while angle <= hi + 1e-6:
        clear_pose(arm)
        apply_ops_map(arm, profile, standing_ops)
        pose_ops(arm, bone, info, angle, 0.0)
        bpy.context.view_layer.update()
        err = abs(metric_fn() - target)
        if err < best_err:
            best_err = err
            best = angle
        angle += step
    return clamp_deg(bone, best), best_err


def mixamo_channels_from_file():
    path = os.path.join(GENERATED, "MIXAMO_IDLE_SEMANTIC_CHANNELS_CLEAN_V1.json")
    if not os.path.isfile(path):
        dump_mixamo()
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def bake_semantic(tgt_arm, profile, semantic, frame_start, frame_end):
    standing = semantic["standing"]
    frames = semantic["frames"]
    standing_ops = {}
    plan = [
        ("CC_Base_L_Upperarm", lambda: from_down_deg(tgt_arm, "CC_Base_L_Upperarm"), standing["L_shoulder_lowering"], -80, 80),
        ("CC_Base_R_Upperarm", lambda: from_down_deg(tgt_arm, "CC_Base_R_Upperarm"), standing["R_shoulder_lowering"], -80, 80),
        ("CC_Base_L_Forearm", lambda: flex_deg(tgt_arm, "CC_Base_L_Upperarm", "CC_Base_L_Forearm"), standing["L_elbow_flexion"], -20, 80),
        ("CC_Base_R_Forearm", lambda: flex_deg(tgt_arm, "CC_Base_R_Upperarm", "CC_Base_R_Forearm"), standing["R_elbow_flexion"], -20, 80),
        ("CC_Base_L_Calf", lambda: flex_deg(tgt_arm, "CC_Base_L_Thigh", "CC_Base_L_Calf"), standing["L_knee_flexion"], -10, 50),
        ("CC_Base_R_Calf", lambda: flex_deg(tgt_arm, "CC_Base_R_Thigh", "CC_Base_R_Calf"), standing["R_knee_flexion"], -10, 50),
        ("CC_Base_Spine01", lambda: math.degrees(bone_y_world(tgt_arm, "CC_Base_Spine01").angle(char_basis(tgt_arm)[0])), standing["torso_lean"], -12, 12),
        ("CC_Base_Head", lambda: math.degrees(bone_y_world(tgt_arm, "CC_Base_Head").angle(char_basis(tgt_arm)[0])), standing["head_lean"], -12, 12),
        ("CC_Base_L_Hand", lambda: from_down_deg(tgt_arm, "CC_Base_L_Hand"), standing.get("L_hand_from_down", 20.0), -25, 25),
        ("CC_Base_R_Hand", lambda: from_down_deg(tgt_arm, "CC_Base_R_Hand"), standing.get("R_hand_from_down", 20.0), -25, 25),
    ]
    for bone, metric, target, lo, hi in plan:
        if bone not in profile:
            continue
        ang, err = solve_primary(tgt_arm, profile, standing_ops, bone, profile[bone], metric, target, lo, hi)
        standing_ops[bone] = {"primary": ang, "secondary": 0.0, "match_err": round(err, 3)}
        print("SEM_STAND", bone, "deg", round(ang, 2), "err", round(err, 2), "target", round(target, 2))
    for bone, primary, secondary in (
        ("CC_Base_L_Clavicle", 8.0, 4.0),
        ("CC_Base_R_Clavicle", 8.0, 4.0),
    ):
        if bone in profile and bone not in standing_ops:
            standing_ops[bone] = {"primary": primary, "secondary": secondary, "match_err": None}

    channel_bone = {
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
    action = new_action(tgt_arm, "idle")
    keyed = list(standing_ops.keys()) + ["CC_Base_Hip"]
    for item in frames:
        frame = item["frame"]
        ops = {}
        for bone, spec in standing_ops.items():
            ops[bone] = dict(spec)
        for channel, bone in channel_bone.items():
            delta = float(item["intra_from_standing"].get(channel, 0.0)) * CHANNEL_GAIN
            if channel in invert:
                delta = -delta
            if abs(delta) > INTRA_CLAMP:
                delta = INTRA_CLAMP if delta > 0 else -INTRA_CLAMP
            if bone not in ops:
                ops[bone] = {"primary": 0.0, "secondary": 0.0}
            ops[bone]["primary"] = clamp_deg(bone, ops[bone]["primary"] + delta)
        clear_pose(tgt_arm)
        for bone, spec in ops.items():
            if bone in profile:
                pose_ops(tgt_arm, bone, profile[bone], spec["primary"], spec.get("secondary", 0.0))
        mixamo_span = float(semantic.get("mixamo_head_hip_span") or 1.0)
        tgt_span = float((world_head(tgt_arm, "CC_Base_Head") - world_head(tgt_arm, "CC_Base_Hip")).length)
        height_scale = tgt_span / max(mixamo_span, 1e-6)
        dz = float(item["intra_from_standing"].get("hip_world_z", 0.0)) * height_scale
        if "CC_Base_Hip" in tgt_arm.pose.bones:
            tgt_arm.pose.bones["CC_Base_Hip"].location = world_up_to_hip_local(tgt_arm, "CC_Base_Hip", dz)
        bpy.context.view_layer.update()
        for name in keyed:
            if name not in tgt_arm.pose.bones:
                continue
            pose_bone = tgt_arm.pose.bones[name]
            pose_bone.rotation_mode = "QUATERNION"
            pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame)
            if name == "CC_Base_Hip":
                pose_bone.keyframe_insert(data_path="location", frame=frame)
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end
    return action, standing_ops


def find_mixamo_action():
    for action in bpy.data.actions:
        lowered = action.name.lower()
        if "mixamo" in lowered or "layer0" in lowered:
            return action
    if bpy.data.actions:
        return bpy.data.actions[0]
    return None


def bake_traditional(src_arm, tgt_arm, pairs, frame_start, frame_end):
    disconnect(src_arm)
    disconnect(tgt_arm)
    clear_pose(src_arm)
    clear_pose(tgt_arm)
    bpy.context.view_layer.update()
    c_map = {}
    for pair in pairs:
        c_map[pair["target"]] = compute_C(src_arm, tgt_arm, pair["source"], pair["target"])
    src_hip = next(pair["source"] for pair in pairs if pair["allow_location_y"])
    tgt_hip = next(pair["target"] for pair in pairs if pair["allow_location_y"])
    src_hip_rest_w = (src_arm.matrix_world @ src_arm.pose.bones[src_hip].matrix).to_translation().copy()
    src_prefix = discover_prefix(src_arm)
    src_head = mixamo_name(src_prefix, "Head")
    src_span = float((world_head(src_arm, src_head) - world_head(src_arm, src_hip)).length)
    tgt_span = float((world_head(tgt_arm, "CC_Base_Head") - world_head(tgt_arm, "CC_Base_Hip")).length)
    height_scale = tgt_span / max(src_span, 1e-6)
    src_action = find_mixamo_action()
    if src_action is None:
        raise RuntimeError("Mixamo action missing")
    if src_arm.animation_data is None:
        src_arm.animation_data_create()
    src_arm.animation_data.action = src_action
    action = new_action(tgt_arm, "idle")
    for frame in range(frame_start, frame_end + 1):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        apply_traditional_frame(src_arm, tgt_arm, pairs, c_map, src_hip, tgt_hip, src_hip_rest_w, height_scale)
        key_mapped(tgt_arm, pairs, frame, tgt_hip)
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end
    cob = {}
    for dst, change in c_map.items():
        quat = change.to_quaternion()
        cob[dst] = {"C_angle_deg": round(abs(math.degrees(quat.angle)), 3)}
    cob["_height_scale"] = round(height_scale, 6)
    return action, cob


def strip_mixamo(src_arm):
    if src_arm is None:
        return
    delete_object(src_arm)
    for action in list(bpy.data.actions):
        lowered = action.name.lower()
        if "mixamo" in lowered or "layer0" in lowered:
            try:
                bpy.data.actions.remove(action)
            except Exception:
                pass


def export_method(character, method, arm, action, metrics):
    cfg = CHARACTERS[character]
    ensure_dir(cfg["out_dir"])
    if method == "semantic_clean":
        stem = "%s_idle_semantic_clean_v1" % character
        label = "SEMANTIC_CLEAN"
    else:
        stem = "%s_idle_traditional_v1" % character
        label = "TRADITIONAL"
    blend = os.path.join(cfg["out_dir"], stem + ".blend")
    glb = os.path.join(cfg["out_dir"], stem + ".glb")
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    bpy.context.scene.frame_start = int(action.frame_range[0])
    bpy.context.scene.frame_end = int(action.frame_range[1])
    bpy.context.scene.frame_set(int(action.frame_range[0]))
    export_glb(glb)
    setup_camera(arm)
    try:
        save_blend(blend)
    except Exception as exc:
        print("WARN blend", exc)
    metrics["output_glb"] = glb.replace("\\", "/")
    metrics["output_blend"] = blend.replace("\\", "/")
    write_json(os.path.join(GENERATED, "%s_IDLE_%s_V1_METRICS.json" % (character.upper(), label)), metrics)
    print("EXPORT", character, method, "pass", metrics.get("technical_pass"), "class", metrics.get("pose_classification"))
    return glb


def roundtrip_glb(glb_path, method):
    reset_empty()
    bpy.ops.import_scene.gltf(filepath=glb_path)
    arm = find_cc_arm()
    mesh = skinned_mesh(arm) if arm else None
    if arm is None or mesh is None:
        return {"ok": False, "reason": "missing_arm_or_mesh", "glb": glb_path}
    action = arm.animation_data.action if arm.animation_data else None
    if action is None and bpy.data.actions:
        action = bpy.data.actions[0]
    if action is None:
        return {"ok": False, "reason": "no_action", "bone_count": len(arm.data.bones)}
    metrics = evaluate_action(arm, mesh, action, method + "_roundtrip")
    metrics["bone_count"] = len(arm.data.bones)
    metrics["ok"] = metrics["bone_count"] >= 90 and bool(action)
    return metrics


def bake_character(character):
    cfg = CHARACTERS[character]
    semantic = mixamo_channels_from_file()
    open_blend(cfg["blend"])
    bpy.context.scene.render.fps = 30
    tgt = find_cc_arm()
    if tgt is None:
        raise RuntimeError("clean CC armature missing")
    mesh = skinned_mesh(tgt)
    import_fbx(IDLE_FBX)
    src = find_mixamo_arm()
    if src is None:
        raise RuntimeError("Idle Mixamo armature missing")
    pairs, prefix = mapped_pairs(src, tgt)
    if len(pairs) < 16:
        raise RuntimeError("mapped pairs too few: %s" % len(pairs))
    src_action = src.animation_data.action if src.animation_data else find_mixamo_action()
    frame_start = int(src_action.frame_range[0])
    frame_end = int(src_action.frame_range[1])

    trad_act, cob = bake_traditional(src, tgt, pairs, frame_start, frame_end)
    trad_metrics = evaluate_action(tgt, mesh, trad_act, "traditional")
    trad_metrics.update({
        "character": character,
        "pipeline": "CLEAN_RIG_V1",
        "mapped_bones": len(pairs),
        "mixamo_prefix": prefix,
        "uses_frame_1_as_rest": False,
        "legacy_axis_hack": False,
        "C_angles": cob,
        "copies_raw_mixamo_quaternion": False,
        "texture_authority": texture_authority(),
    })
    strip_mixamo(src)
    trad_glb = export_method(character, "traditional", tgt, trad_act, trad_metrics)
    trad_act.name = "idle_traditional"
    trad_act.use_fake_user = True

    disconnect(tgt)
    clear_pose(tgt)
    profile = profile_axes(tgt)
    sem_act, standing_ops = bake_semantic(tgt, profile, semantic, frame_start, frame_end)
    sem_metrics = evaluate_action(tgt, mesh, sem_act, "semantic_clean")
    sem_metrics.update({
        "character": character,
        "pipeline": "CLEAN_RIG_V1",
        "copies_raw_mixamo_quaternion": False,
        "standing_ops": standing_ops,
        "legacy_axis_hack": False,
        "texture_authority": texture_authority(),
    })
    sem_glb = export_method(character, "semantic_clean", tgt, sem_act, sem_metrics)
    sem_act.name = "idle_semantic"
    sem_act.use_fake_user = True

    write_json(os.path.join(GENERATED, "%s_IDLE_HAND_ARM_QUALITY_V1.json" % character.upper()), {
        "traditional": {
            "rest": trad_metrics.get("rest_arm"),
            "first": trad_metrics.get("first_arm"),
            "mid": trad_metrics.get("mid_arm"),
            "last": trad_metrics.get("last_arm"),
        },
        "semantic_clean": {
            "rest": sem_metrics.get("rest_arm"),
            "first": sem_metrics.get("first_arm"),
            "mid": sem_metrics.get("mid_arm"),
            "last": sem_metrics.get("last_arm"),
        },
    })
    write_json(os.path.join(GENERATED, "%s_IDLE_GROUNDING_V1.json" % character.upper()), {
        "traditional": {
            "foot_drift": trad_metrics.get("max_foot_drift"),
            "root_xz": trad_metrics.get("max_root_xz"),
            "hip_z_variance": trad_metrics.get("hip_z_variance"),
            "grounding": trad_metrics.get("grounding"),
        },
        "semantic_clean": {
            "foot_drift": sem_metrics.get("max_foot_drift"),
            "root_xz": sem_metrics.get("max_root_xz"),
            "hip_z_variance": sem_metrics.get("hip_z_variance"),
            "grounding": sem_metrics.get("grounding"),
        },
    })

    rest_act = new_action(tgt, "rest")
    clear_pose(tgt)
    bpy.context.view_layer.update()
    for name in ("CC_Base_Hip", "CC_Base_L_Upperarm", "CC_Base_R_Upperarm", "CC_Base_Head"):
        if name not in tgt.pose.bones:
            continue
        pose_bone = tgt.pose.bones[name]
        pose_bone.rotation_mode = "QUATERNION"
        pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame_start)
        pose_bone.keyframe_insert(data_path="rotation_quaternion", frame=frame_end)
        if name == "CC_Base_Hip":
            pose_bone.keyframe_insert(data_path="location", frame=frame_start)
            pose_bone.keyframe_insert(data_path="location", frame=frame_end)
    rest_act.use_fake_user = True
    if tgt.animation_data:
        tgt.animation_data.action = trad_act
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end
    cmp_blend = os.path.join(cfg["out_dir"], "%s_idle_ab_preview_v1.blend" % character)
    try:
        save_blend(cmp_blend)
    except Exception as exc:
        print("WARN cmp blend", exc)
        cmp_blend = ""

    rt_trad = roundtrip_glb(trad_glb, "traditional")
    rt_sem = roundtrip_glb(sem_glb, "semantic_clean")
    write_json(os.path.join(GENERATED, "%s_IDLE_GLB_ROUNDTRIP_V1.json" % character.upper()), {
        "traditional": rt_trad,
        "semantic_clean": rt_sem,
    })
    return {
        "traditional": trad_metrics,
        "semantic_clean": sem_metrics,
        "comparison_blend": cmp_blend.replace("\\", "/"),
        "roundtrip": {"traditional": rt_trad, "semantic_clean": rt_sem},
    }


def build_ab(results):
    payload = {"pipeline": "CLEAN_RIG_V1", "animation": "Idle.fbx", "fighters": {}}
    for character, row in results.items():
        trad = row["traditional"]
        sem = row["semantic_clean"]
        payload["fighters"][character] = {
            "traditional": {
                "classification": trad.get("pose_classification"),
                "max_volume_ratio": trad.get("max_volume_ratio"),
                "extreme_verts": trad.get("max_extreme_verts"),
                "limb_length_error": trad.get("max_limb_length_rel_error"),
                "principal_axis_ratios": trad.get("principal_axis_ratios"),
                "upperarm_pose": (trad.get("mid_arm") or {}).get("CC_Base_L_Upperarm"),
                "elbow_pose": {
                    "L": (trad.get("mid_arm") or {}).get("L_elbow_flex_deg"),
                    "R": (trad.get("mid_arm") or {}).get("R_elbow_flex_deg"),
                },
                "hand_pose": (trad.get("mid_arm") or {}).get("CC_Base_L_Hand"),
                "foot_drift": trad.get("max_foot_drift"),
                "root_xz": trad.get("max_root_xz"),
                "hip_z_variance": trad.get("hip_z_variance"),
                "hand_drift": trad.get("max_hand_drift"),
                "grounding": trad.get("grounding"),
                "technical_pass": trad.get("technical_pass"),
                "per_character_hacks": 0,
                "implementation_complexity": "shared rest-space change-of-basis; hip vertical only",
                "generalizability_to_future_clips": "likely if both fighters pass — same Mixamo suffix map and bind-pose rest",
            },
            "semantic_clean": {
                "classification": sem.get("pose_classification"),
                "max_volume_ratio": sem.get("max_volume_ratio"),
                "extreme_verts": sem.get("max_extreme_verts"),
                "limb_length_error": sem.get("max_limb_length_rel_error"),
                "principal_axis_ratios": sem.get("principal_axis_ratios"),
                "upperarm_pose": (sem.get("mid_arm") or {}).get("CC_Base_L_Upperarm"),
                "elbow_pose": {
                    "L": (sem.get("mid_arm") or {}).get("L_elbow_flex_deg"),
                    "R": (sem.get("mid_arm") or {}).get("R_elbow_flex_deg"),
                },
                "hand_pose": (sem.get("mid_arm") or {}).get("CC_Base_L_Hand"),
                "foot_drift": sem.get("max_foot_drift"),
                "root_xz": sem.get("max_root_xz"),
                "hip_z_variance": sem.get("hip_z_variance"),
                "hand_drift": sem.get("max_hand_drift"),
                "grounding": sem.get("grounding"),
                "technical_pass": sem.get("technical_pass"),
                "per_character_hacks": 0,
                "implementation_complexity": "native-axis standing solved from Mixamo world channels + intra-idle deltas",
                "generalizability_to_future_clips": "idle channels transfer; other clips need clip-specific semantic extractors",
            },
            "automatic_winner": "HUMAN_REQUIRED",
        }
    both_trad = all(results[character]["traditional"].get("technical_pass") for character in results)
    both_sem = all(results[character]["semantic_clean"].get("technical_pass") for character in results)
    payload["traditional_generic_mapping_likely"] = bool(both_trad)
    payload["semantic_clip_specific"] = True
    payload["at_least_one_method_both_fighters"] = bool(both_trad or both_sem)
    write_json(os.path.join(GENERATED, "CLEAN_RIG_IDLE_AB_COMPARISON.json"), payload)
    return payload


def main():
    args = parse_args()
    ensure_dir(GENERATED)
    if args.mode in ("dump-mixamo", "all"):
        dump_mixamo()
    if args.mode in ("dump-baseline", "all"):
        dump_all_baselines()
    if args.mode in ("bake", "all"):
        chars = ("terere", "jaguarete") if args.character == "both" else (args.character,)
        results = {}
        for character in chars:
            print("==== BAKE", character, "====")
            results[character] = bake_character(character)
        if len(results) == 2:
            build_ab(results)
        write_json(os.path.join(GENERATED, "CLEAN_RIG_IDLE_BENCHMARK_RUN.json"), {
            character: {
                "traditional_pass": results[character]["traditional"].get("technical_pass"),
                "semantic_pass": results[character]["semantic_clean"].get("technical_pass"),
                "traditional_class": results[character]["traditional"].get("pose_classification"),
                "semantic_class": results[character]["semantic_clean"].get("pose_classification"),
            }
            for character in results
        })


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
