"""Shared helpers for ActorCore benchmark Blender scripts."""
import json
import math
import os
import struct
from datetime import datetime, timezone

try:
    import bpy
    from mathutils import Matrix, Vector, Quaternion
    HAS_BPY = True
except ImportError:
    HAS_BPY = False


def ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def iso_mtime(path: str) -> str:
    if not os.path.isfile(path):
        return ""
    return datetime.fromtimestamp(os.path.getmtime(path), tz=timezone.utc).isoformat()


def file_size(path: str) -> int:
    return os.path.getsize(path) if os.path.isfile(path) else 0


def png_dimensions(path: str) -> list:
    if not os.path.isfile(path):
        return [0, 0]
    with open(path, "rb") as fh:
        header = fh.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        return [0, 0]
    width, height = struct.unpack(">II", header[16:24])
    return [int(width), int(height)]


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_fbx(path: str) -> None:
    bpy.ops.import_scene.fbx(filepath=path)


def rebind_actorcore_textures(character: str) -> None:
    """Force images onto this character's .fbm files.

    AccuRIG names every map model_Pbr_Diffuse.png. Blender 2.83 FBX import
    resolves that filename from a search path and can pack Jaguareté maps
    into a Tereré export (byte-identical GLB hashes).
    """
    from actorcore_paths import CHARACTERS
    fbm = CHARACTERS[character]["fbm_dir"]
    mapping = {
        "diffuse": os.path.join(fbm, "model_Pbr_Diffuse.png"),
        "normal": os.path.join(fbm, "model_Pbr_Normal.png"),
    }
    for img in bpy.data.images:
        name = img.name.lower()
        target = ""
        if "diffuse" in name or "albedo" in name:
            target = mapping["diffuse"]
        elif "normal" in name:
            target = mapping["normal"]
        if target and os.path.isfile(target):
            img.filepath = target
            img.filepath_raw = target
            try:
                img.reload()
            except Exception:
                pass
    print("REBIND_TEXTURES %s diffuse=%s" % (character, mapping["diffuse"]))


def import_gltf(path: str) -> None:
    bpy.ops.import_scene.gltf(filepath=path)


def find_armatures():
    return [o for o in bpy.data.objects if o.type == "ARMATURE"]


def find_armature(preferred_name: str = ""):
    if preferred_name:
        for obj in bpy.data.objects:
            if obj.type == "ARMATURE" and obj.name == preferred_name:
                return obj
    arms = find_armatures()
    return arms[0] if arms else None


def bone_record(arm_obj, bone) -> dict:
    parent = bone.parent.name if bone.parent else None
    head = bone.head_local
    tail = bone.tail_local
    mat = bone.matrix_local
    return {
        "name": bone.name,
        "parent": parent,
        "head": [round(head.x, 6), round(head.y, 6), round(head.z, 6)],
        "tail": [round(tail.x, 6), round(tail.y, 6), round(tail.z, 6)],
        "matrix_local": [round(v, 6) for row in mat for v in row],
    }


def _material_texture_slots(mat) -> list:
    images = []
    if mat is None:
        return images
    if getattr(mat, "use_nodes", False) and mat.node_tree:
        for node in mat.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                images.append({
                    "node": node.name,
                    "image": node.image.name,
                    "filepath": getattr(node.image, "filepath", ""),
                })
    return images


def collect_rig_data(arm_obj) -> dict:
    bones = []
    for bone in arm_obj.data.bones:
        bones.append(bone_record(arm_obj, bone))
    meshes = []
    shape_keys = []
    materials = []
    texture_slots = []
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            entry = {
                "name": obj.name,
                "vertices": len(obj.data.vertices) if obj.data else 0,
                "polygons": len(obj.data.polygons) if obj.data else 0,
                "vertex_groups": len(obj.vertex_groups),
                "vertex_group_names": [vg.name for vg in obj.vertex_groups],
                "armature_modifier": False,
                "armature_modifier_object": "",
                "shape_key_count": len(obj.data.shape_keys.key_blocks) if obj.data and obj.data.shape_keys else 0,
            }
            for mod in obj.modifiers:
                if mod.type == "ARMATURE":
                    entry["armature_modifier"] = True
                    if mod.object:
                        entry["armature_modifier_object"] = mod.object.name
            meshes.append(entry)
            if obj.data and obj.data.shape_keys:
                for sk in obj.data.shape_keys.key_blocks:
                    shape_keys.append({"mesh": obj.name, "name": sk.name})
            if obj.data and obj.data.materials:
                for mat in obj.data.materials:
                    if mat and mat.name not in materials:
                        materials.append(mat.name)
                        texture_slots.append({
                            "material": mat.name,
                            "images": _material_texture_slots(mat),
                        })
    actions = []
    for act in bpy.data.actions:
        actions.append({
            "name": act.name,
            "frame_start": int(act.frame_range[0]),
            "frame_end": int(act.frame_range[1]),
            "fcurves": len(act.fcurves),
        })
    return {
        "armature_name": arm_obj.name,
        "bone_count": len(arm_obj.data.bones),
        "bones": bones,
        "meshes": meshes,
        "shape_keys": shape_keys,
        "materials": materials,
        "texture_slots": texture_slots,
        "actions": actions,
        "scene_fps": bpy.context.scene.render.fps,
    }


def dump_rig_text(title: str, rig: dict) -> str:
    lines = [f"=== {title} ===", f"armature={rig['armature_name']}", f"bones={rig['bone_count']}", ""]
    lines.append("bone_hierarchy:")
    for b in rig["bones"]:
        lines.append(f"  {b['name']} (parent={b['parent']})")
    lines.append("bone_rest:")
    for b in rig["bones"]:
        lines.append(
            f"  {b['name']}: head={b['head']} tail={b['tail']} mat_local={b['matrix_local']}"
        )
    lines.append("meshes:")
    for m in rig["meshes"]:
        lines.append(f"  {m}")
    lines.append("shape_keys:")
    for sk in rig["shape_keys"][:50]:
        lines.append(f"  {sk}")
    if len(rig["shape_keys"]) > 50:
        lines.append(f"  ... {len(rig['shape_keys']) - 50} more")
    lines.append("texture_slots:")
    for slot in rig.get("texture_slots", []):
        lines.append("  %s" % slot)
    lines.append("actions:")
    for a in rig["actions"]:
        lines.append(f"  {a}")
    lines.append(f"scene_fps={rig['scene_fps']}")
    return "\n".join(lines)


def find_source_action(source_arm, hint: str = "mixamo"):
    if source_arm.animation_data and source_arm.animation_data.action:
        return source_arm.animation_data.action
    for act in bpy.data.actions:
        if hint.lower() in act.name.lower():
            return act
    return bpy.data.actions[0] if bpy.data.actions else None


def quat_delta_degrees(a, b) -> float:
    """Shortest-arc angle in degrees (handles q vs -q and angles > 180)."""
    delta = a.rotation_difference(b)
    angle = abs(math.degrees(delta.angle)) % 360.0
    if angle > 180.0:
        angle = 360.0 - angle
    return angle


def rest_relative_matrix(source_arm, target_arm, source_name: str, target_name: str):
    """Deprecated world-space helper kept for audit scripts."""
    s_pb = source_arm.pose.bones[source_name]
    s_db = source_arm.data.bones[source_name]
    t_db = target_arm.data.bones[target_name]
    s_pose_world = source_arm.matrix_world @ s_pb.matrix
    s_rest_world = source_arm.matrix_world @ s_db.matrix_local
    t_rest_world = target_arm.matrix_world @ t_db.matrix_local
    delta_rot = s_rest_world.to_3x3().inverted() @ s_pose_world.to_3x3()
    t_pose_rot = t_rest_world.to_3x3() @ delta_rot
    t_pose_world = Matrix.Translation(t_rest_world.translation) @ t_pose_rot.to_4x4()
    return target_arm.matrix_world.inverted() @ t_pose_world


def apply_rest_relative_rotation(source_arm, target_arm, source_name: str, target_name: str) -> None:
    """Copy Mixamo LOCAL rest-relative rotation into ActorCore local axes.

    World-space per-bone copy double-counts parent motion. Change-of-basis on
    matrix_basis keeps idle-scale articulation (degrees, not hundreds of degrees).
    """
    s_pb = source_arm.pose.bones[source_name]
    s_db = source_arm.data.bones[source_name]
    t_pb = target_arm.pose.bones[target_name]
    t_db = target_arm.data.bones[target_name]
    s_rest = (source_arm.matrix_world @ s_db.matrix_local).to_3x3()
    t_rest = (target_arm.matrix_world @ t_db.matrix_local).to_3x3()
    src_basis_rot = s_pb.matrix_basis.to_3x3()
    world_rot = s_rest @ src_basis_rot @ s_rest.inverted()
    t_basis_rot = t_rest.inverted() @ world_rot @ t_rest
    t_pb.rotation_mode = "QUATERNION"
    t_pb.matrix_basis = t_basis_rot.to_4x4()
    t_pb.location = Vector((0.0, 0.0, 0.0))
    t_pb.scale = Vector((1.0, 1.0, 1.0))


def apply_clip_relative_rotation(source_arm, target_arm, source_name: str, target_name: str, source_ref_quat) -> None:
    """Transfer Mixamo motion relative to the CLIP'S first frame, not Mixamo T-pose rest.

    Absolute Mixamo rest-relative rotations are 50–100° (T-pose → stand). Copying those
    onto AccuRIG local axes (≈90° rest mismatch) explodes the skinned mesh. Intra-clip
    deltas are idle-scale and stay on the ActorCore bind pose.
    """
    s_pb = source_arm.pose.bones[source_name]
    t_pb = target_arm.pose.bones[target_name]
    q = s_pb.matrix_basis.to_quaternion()
    delta = source_ref_quat.inverted() @ q
    if delta.w < 0.0:
        delta = -delta
    t_pb.rotation_mode = "QUATERNION"
    t_pb.rotation_quaternion = delta
    t_pb.location = Vector((0.0, 0.0, 0.0))
    t_pb.scale = Vector((1.0, 1.0, 1.0))


def capture_clip_reference_quats(source_arm, pairs, frame: int) -> dict:
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    refs = {}
    for pair in pairs:
        src = pair["source"]
        if src in source_arm.pose.bones:
            refs[src] = source_arm.pose.bones[src].matrix_basis.to_quaternion().copy()
    return refs


def apply_hip_y_only(target_arm, target_name: str, source_arm, source_name: str, scale: float) -> None:
    t_pb = target_arm.pose.bones[target_name]
    s_pb = source_arm.pose.bones[source_name]
    t_pb.location = Vector((0.0, s_pb.location.y * scale, 0.0))


def apply_hip_y_clip_relative(target_arm, target_name: str, source_arm, source_name: str, ref_y: float, scale: float) -> None:
    t_pb = target_arm.pose.bones[target_name]
    s_pb = source_arm.pose.bones[source_name]
    t_pb.location = Vector((0.0, (s_pb.location.y - ref_y) * scale, 0.0))


def clear_pose(arm_obj) -> None:
    identity = Quaternion()
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = identity.copy()
        pb.location = Vector((0.0, 0.0, 0.0))
        pb.scale = Vector((1.0, 1.0, 1.0))


def mapped_pairs_from_bone_map(bone_map: dict) -> list:
    pairs = []
    for entry in bone_map.get("bones", []):
        if entry.get("class") != "REQUIRED":
            continue
        src = entry.get("source")
        dst = entry.get("target")
        if src and dst:
            pairs.append({
                "source": src,
                "target": dst,
                "allow_location_y": bool(entry.get("allow_location_y", False)),
            })
    return pairs


def insert_pose_keyframes(target_arm, bone_names: list, frame: int) -> None:
    for name in bone_names:
        pb = target_arm.pose.bones.get(name)
        if pb is None:
            continue
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)
        if name == "CC_Base_Hip":
            pb.keyframe_insert(data_path="location", frame=frame)


def purge_orphans() -> None:
    try:
        bpy.ops.outliner.orphans_purge(do_recursive=True)
    except Exception:
        pass


def setup_preview_camera(target_arm) -> None:
    cam_data = bpy.data.cameras.new("BenchmarkCamera")
    cam_obj = bpy.data.objects.new("BenchmarkCamera", cam_data)
    bpy.context.collection.objects.link(cam_obj)
    height = 1.6
    if target_arm:
        heads = [b.head_local.z for b in target_arm.data.bones]
        if heads:
            height = max(1.2, min(max(heads) * 0.55, 3.0))
    cam_obj.location = (0.0, -4.2, height)
    cam_obj.rotation_euler = (math.radians(78), 0.0, 0.0)
    cam_data.lens = 50
    bpy.context.scene.camera = cam_obj


def quat_to_euler_deg(q) -> list:
    e = q.to_euler()
    return [round(math.degrees(e.x), 4), round(math.degrees(e.y), 4), round(math.degrees(e.z), 4)]


def motion_audit_for_action(arm_obj, action, bone_names: list, rotation_threshold: float = 0.35) -> dict:
    """Intra-clip local articulation audit. Keys are not enough; bones must actually move."""
    scene = bpy.context.scene
    if arm_obj.animation_data is None:
        arm_obj.animation_data_create()
    arm_obj.animation_data.action = action
    frame_start = int(action.frame_range[0])
    frame_end = int(action.frame_range[1])
    report = {
        "action": action.name,
        "frame_start": frame_start,
        "frame_end": frame_end,
        "fps": scene.render.fps,
        "metric": "intra_clip_local_rotation_from_first_frame",
        "bones": {},
    }
    for label, bone_name in bone_names:
        if bone_name not in arm_obj.pose.bones:
            report["bones"][label] = {"missing": True}
            continue
        pb = arm_obj.pose.bones[bone_name]
        key_count = 0
        loc_key_range = 0.0
        for fc in action.fcurves:
            if '"%s"' % bone_name not in fc.data_path:
                continue
            key_count += len(fc.keyframe_points)
            if "location" in fc.data_path and fc.keyframe_points:
                vals = [kp.co[1] for kp in fc.keyframe_points]
                loc_key_range = max(loc_key_range, max(vals) - min(vals))
        first_q = None
        first_loc = None
        max_rot_delta = 0.0
        max_loc_delta = 0.0
        for frame in range(frame_start, frame_end + 1):
            scene.frame_set(frame)
            bpy.context.view_layer.update()
            pose_q = pb.matrix_basis.to_quaternion().copy()
            loc = pb.location.copy()
            if first_q is None:
                first_q = pose_q
                first_loc = loc
                continue
            max_rot_delta = max(max_rot_delta, quat_delta_degrees(first_q, pose_q))
            max_loc_delta = max(max_loc_delta, (loc - first_loc).length)
        report["bones"][label] = {
            "bone": bone_name,
            "rotation_delta_degrees": round(max_rot_delta, 4),
            "location_delta": round(max(max_loc_delta, loc_key_range), 6),
            "key_count": key_count,
        }
    branches_with_motion = sum(
        1 for b in report["bones"].values()
        if not b.get("missing") and b.get("rotation_delta_degrees", 0.0) > rotation_threshold
    )
    report["branches_with_motion"] = branches_with_motion
    report["rotation_threshold_degrees"] = rotation_threshold
    report["accepted"] = branches_with_motion >= 6
    return report


def write_json(path: str, data) -> None:
    ensure_dir(os.path.dirname(path))
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)
