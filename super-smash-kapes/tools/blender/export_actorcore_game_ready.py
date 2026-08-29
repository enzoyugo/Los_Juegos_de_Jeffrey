"""Deterministic ActorCore game-ready export (clip-relative Mixamo bake).

blender --background --python export_actorcore_game_ready.py -- --character terere --action-name idle
"""
import argparse
import json
import os
import sys

import bpy
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import (  # noqa: E402
    apply_clip_relative_rotation,
    apply_hip_y_clip_relative,
    capture_clip_reference_quats,
    clear_pose,
    find_armature,
    find_source_action,
    import_fbx,
    insert_pose_keyframes,
    mapped_pairs_from_bone_map,
    motion_audit_for_action,
    purge_orphans,
    rebind_actorcore_textures,
    reset_scene,
    write_json,
)
from actorcore_paths import (  # noqa: E402
    BONE_MAP_JSON,
    CHARACTERS,
    GENERATED_DIR,
    HIP_Y_SCALE,
    IDLE_FBX,
    MOTION_AUDIT_BONES,
)


MAX_INFLUENCES = 4
VOLUME_RATIO_LIMIT = 1.35
MAX_AXIS_RATIO_LIMIT = 1.30


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--character", required=True, choices=["terere", "jaguarete"])
    p.add_argument("--source-animation", default=IDLE_FBX)
    p.add_argument("--action-name", default="idle")
    p.add_argument("--output-glb", default="")
    p.add_argument("--output-blend", default="")
    return p.parse_args(argv)


def production_paths(character: str):
    cfg = CHARACTERS[character]
    processed = os.path.join(os.path.dirname(os.path.dirname(cfg["benchmark_dir"])), character)
    return {
        "glb": os.path.join(processed, "%s_game_ready_v4.glb" % character),
        "blend": os.path.join(processed, "%s_game_ready_v4_preview.blend" % character),
        "bbox": os.path.join(GENERATED_DIR, "%s_V4_BBOX_VALIDATION.json" % character.upper()),
        "export_settings": os.path.join(GENERATED_DIR, "ACTORCORE_V4_EXPORT_SETTINGS.json"),
    }


def skinned_meshes(arm):
    out = []
    for obj in bpy.data.objects:
        if obj.type == "MESH" and any(m.type == "ARMATURE" and m.object == arm for m in obj.modifiers):
            out.append(obj)
    return out


def mesh_volume(mesh_obj):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = mesh_obj.evaluated_get(deps)
    xs = [v.co.x for v in ev.data.vertices]
    ys = [v.co.y for v in ev.data.vertices]
    zs = [v.co.z for v in ev.data.vertices]
    sx, sy, sz = max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)
    return abs(sx * sy * sz), (sx, sy, sz)


def limit_influences(mesh_obj, max_inf=MAX_INFLUENCES):
    mesh = mesh_obj.data
    vg_by_index = {vg.index: vg for vg in mesh_obj.vertex_groups}
    for v in mesh.vertices:
        groups = [(g.group, g.weight) for g in v.groups if g.weight > 1e-8]
        if len(groups) <= max_inf:
            continue
        groups.sort(key=lambda item: -item[1])
        keep = groups[:max_inf]
        drop = groups[max_inf:]
        total = sum(w for _, w in keep) or 1.0
        for gi, _w in drop:
            vg = vg_by_index.get(gi)
            if vg:
                vg.remove([v.index])
        for gi, w in keep:
            vg = vg_by_index.get(gi)
            if vg:
                vg.add([v.index], w / total, "REPLACE")


def strip_non_production(target_arm, source_arm):
    keep_meshes = set(skinned_meshes(target_arm))
    keep = set(keep_meshes)
    keep.add(target_arm)
    for obj in list(bpy.data.objects):
        if obj in keep:
            continue
        bpy.data.objects.remove(obj, do_unlink=True)
    for act in list(bpy.data.actions):
        if "mixamo" in act.name.lower():
            bpy.data.actions.remove(act)


EXPORT_SETTINGS = {
    "export_format": "GLB",
    "export_texcoords": True,
    "export_normals": True,
    "export_materials": True,
    "export_colors": True,
    "export_cameras": False,
    "export_extras": False,
    "export_yup": True,
    "export_apply": False,
    "export_animations": True,
    "export_frame_range": True,
    "export_skins": True,
    "export_all_influences": False,
    "export_current_frame": False,
    "retarget_mode": "clip_relative_to_first_frame",
    "max_influences": MAX_INFLUENCES,
    "root_motion": "X=0 Z=0, Hip Y clip-relative scaled",
}


def main():
    args = parse_args()
    cfg = CHARACTERS[args.character]
    paths = production_paths(args.character)
    output_glb = args.output_glb or paths["glb"]
    output_blend = args.output_blend or paths["blend"]
    os.makedirs(os.path.dirname(output_glb), exist_ok=True)
    with open(BONE_MAP_JSON, "r", encoding="utf-8") as fh:
        pairs = mapped_pairs_from_bone_map(json.load(fh))

    reset_scene()
    bpy.context.scene.render.fps = 30
    import_fbx(cfg["fbx"])
    rebind_actorcore_textures(args.character)
    target = find_armature()
    import_fbx(args.source_animation)
    source = [a for a in bpy.data.objects if a.type == "ARMATURE" and a != target][0]
    source_action = find_source_action(source, "mixamo")
    source.animation_data_create()
    source.animation_data.action = source_action
    frame_start = int(source_action.frame_range[0])
    frame_end = int(source_action.frame_range[1])

    refs = capture_clip_reference_quats(source, pairs, frame_start)
    bpy.context.scene.frame_set(frame_start)
    bpy.context.view_layer.update()
    hip_src = next((p["source"] for p in pairs if p.get("allow_location_y")), None)
    hip_ref_y = source.pose.bones[hip_src].location.y if hip_src and hip_src in source.pose.bones else 0.0

    clear_pose(target)
    target_action = bpy.data.actions.new(args.action_name)
    target.animation_data_create()
    target.animation_data.action = target_action
    target_bones = [p["target"] for p in pairs]

    for frame in range(frame_start, frame_end + 1):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        for pair in pairs:
            if pair["source"] not in source.pose.bones or pair["target"] not in target.pose.bones:
                continue
            apply_clip_relative_rotation(source, target, pair["source"], pair["target"], refs[pair["source"]])
            if pair.get("allow_location_y"):
                apply_hip_y_clip_relative(target, pair["target"], source, pair["source"], hip_ref_y, HIP_Y_SCALE)
        insert_pose_keyframes(target, target_bones, frame)

    meshes = skinned_meshes(target)
    clear_pose(target)
    bpy.context.scene.frame_set(frame_start)
    bpy.context.view_layer.update()
    rest_vol, rest_size = mesh_volume(meshes[0]) if meshes else (1.0, (0, 0, 0))
    mid = int((frame_start + frame_end) * 0.5)
    bpy.context.scene.frame_set(mid)
    bpy.context.view_layer.update()
    idle_vol, idle_size = mesh_volume(meshes[0]) if meshes else (1.0, (0, 0, 0))
    vol_ratio = idle_vol / max(rest_vol, 1e-6)
    max_ratio = max(idle_size) / max(max(rest_size), 1e-6)
    bbox = {
        "character": args.character,
        "rest_size": [round(x, 4) for x in rest_size],
        "idle_mid_size": [round(x, 4) for x in idle_size],
        "volume_ratio": round(vol_ratio, 4),
        "max_axis_ratio": round(max_ratio, 4),
        "pass": vol_ratio <= VOLUME_RATIO_LIMIT and max_ratio <= MAX_AXIS_RATIO_LIMIT,
    }
    write_json(paths["bbox"], bbox)
    if not bbox["pass"]:
        raise RuntimeError("Deformation bbox failed: %s" % bbox)

    motion = motion_audit_for_action(target, target_action, MOTION_AUDIT_BONES)
    if not motion.get("accepted"):
        raise RuntimeError("Motion audit rejected: %s" % motion.get("branches_with_motion"))

    before_over4 = 0
    after_over4 = 0
    for mesh in meshes:
        before_over4 += sum(1 for v in mesh.data.vertices if len([g for g in v.groups if g.weight > 1e-8]) > MAX_INFLUENCES)
        limit_influences(mesh, MAX_INFLUENCES)
        after_over4 += sum(1 for v in mesh.data.vertices if len([g for g in v.groups if g.weight > 1e-8]) > MAX_INFLUENCES)
    bbox["vertices_over_4_before"] = before_over4
    bbox["vertices_over_4_after"] = after_over4
    write_json(paths["bbox"], bbox)

    strip_non_production(target, source)
    purge_orphans()
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end
    bpy.context.scene.frame_set(frame_start)

    write_json(paths["export_settings"], EXPORT_SETTINGS)
    # Blender 2.83 glTF exporter: keep the proven production kwargs. Extra flags
    # (export_cameras/export_yup/export_all_influences) are not reliable on 2.83.
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
        print("WARN blend save:", exc)
    print("EXPORT_V4 %s glb=%s bbox_pass=%s vol_ratio=%.3f" % (args.character, output_glb, bbox["pass"], vol_ratio))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
