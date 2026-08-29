"""Bake selected Mixamo clips onto one ActorCore character and export a multi-action GLB.

blender --background --python export_actorcore_animation_library.py -- --character terere
"""
import argparse
import json
import os
import sys
import traceback

import bpy

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
    purge_orphans,
    rebind_actorcore_textures,
    reset_scene,
    write_json,
)
from actorcore_paths import ANIMATIONS_DIR, BONE_MAP_JSON, CHARACTERS, GENERATED_DIR, HIP_Y_SCALE  # noqa: E402
from export_actorcore_game_ready import (  # noqa: E402
    limit_influences,
    mesh_volume,
    skinned_meshes,
    strip_non_production,
)

# Semantic library. No run source exists. Do not invent a run from an attack.
SEMANTIC_CLIPS = [
    {"semantic": "idle", "file": "Idle.fbx", "loop": True, "vol_limit": 1.35, "axis_limit": 1.30},
    {"semantic": "jump", "file": "Unarmed Jump.fbx", "loop": False, "vol_limit": 6.50, "axis_limit": 1.90},
    {"semantic": "air_attack", "file": "Jump Attack.fbx", "loop": False, "vol_limit": 6.50, "axis_limit": 1.90},
    {"semantic": "attack_neutral", "file": "Mutant Punch.fbx", "loop": False, "vol_limit": 6.50, "axis_limit": 1.90},
    {"semantic": "attack_heavy", "file": "Standing Melee Attack Downward.fbx", "loop": False, "vol_limit": 6.50, "axis_limit": 1.90},
    {"semantic": "hit_light", "file": "Reaction.fbx", "loop": False, "vol_limit": 6.50, "axis_limit": 1.90},
    {"semantic": "hit_heavy", "file": "Rib Hit.fbx", "loop": False, "vol_limit": 6.50, "axis_limit": 1.90},
    {"semantic": "ko", "file": "Falling Back Death.fbx", "loop": False, "vol_limit": 6.50, "axis_limit": 1.90},
]

SKIPPED = [
    {"semantic": "run", "reason": "No locomotion FBX in assets/fighters/animations/. Do not map an attack to run."},
    {"semantic": "victory", "reason": "No celebration clip. Do not map KO/death to victory."},
    {"file": "Hit To Body.fbx", "reason": "Duplicate hit; Reaction + Rib Hit cover light/heavy."},
    {"file": "Knocked Out.fbx", "reason": "Duplicate KO; Falling Back Death selected."},
]


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--character", required=True, choices=["terere", "jaguarete"])
    return p.parse_args(argv)


def find_source_arm(target):
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE" and o != target]
    return arms[0] if arms else None


def _push_actions_to_nla(arm):
    """Blender 2.83 glTF exports the active action only unless clips live on NLA."""
    if arm.animation_data is None:
        arm.animation_data_create()
    for track in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(track)
    for action in bpy.data.actions:
        if "mixamo" in action.name.lower():
            continue
        track = arm.animation_data.nla_tracks.new()
        track.name = action.name
        start = int(action.frame_range[0])
        track.strips.new(action.name, start, action)


def delete_armature_tree(arm):
    if arm is None:
        return
    doomed = [arm]
    for obj in list(bpy.data.objects):
        if obj.parent == arm or (obj.type == "MESH" and any(m.type == "ARMATURE" and m.object == arm for m in obj.modifiers)):
            doomed.append(obj)
    for obj in doomed:
        if obj.name in bpy.data.objects:
            bpy.data.objects.remove(obj, do_unlink=True)
    for act in list(bpy.data.actions):
        if "mixamo" in act.name.lower():
            bpy.data.actions.remove(act)


def bake_clip(target, pairs, clip_path, action_name, hip_y_scale):
    import_fbx(clip_path)
    source = find_source_arm(target)
    source_action = find_source_action(source, "mixamo") if source else None
    if source is None or source_action is None:
        raise RuntimeError("Missing Mixamo source for %s" % clip_path)
    source.animation_data_create()
    source.animation_data.action = source_action
    frame_start = int(source_action.frame_range[0])
    frame_end = int(source_action.frame_range[1])
    refs = capture_clip_reference_quats(source, pairs, frame_start)
    bpy.context.scene.frame_set(frame_start)
    bpy.context.view_layer.update()
    hip_src = next((p["source"] for p in pairs if p.get("allow_location_y")), None)
    hip_ref_y = source.pose.bones[hip_src].location.y if hip_src and hip_src in source.pose.bones else 0.0
    if target.animation_data is None:
        target.animation_data_create()
    action = bpy.data.actions.new(action_name)
    target.animation_data.action = action
    clear_pose(target)
    target_bones = [p["target"] for p in pairs]
    for frame in range(frame_start, frame_end + 1):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        for pair in pairs:
            if pair["source"] not in source.pose.bones or pair["target"] not in target.pose.bones:
                continue
            apply_clip_relative_rotation(source, target, pair["source"], pair["target"], refs[pair["source"]])
            if pair.get("allow_location_y"):
                apply_hip_y_clip_relative(target, pair["target"], source, pair["source"], hip_ref_y, hip_y_scale)
        insert_pose_keyframes(target, target_bones, frame)
    action.use_fake_user = True
    delete_armature_tree(source)
    return action, frame_start, frame_end


def main():
    args = parse_args()
    cfg = CHARACTERS[args.character]
    out_dir = os.path.join(os.path.dirname(os.path.dirname(cfg["benchmark_dir"])), "animation_library", args.character)
    os.makedirs(out_dir, exist_ok=True)
    output_glb = os.path.join(
        os.path.dirname(os.path.dirname(cfg["benchmark_dir"])),
        args.character,
        "%s_game_ready_v4.glb" % args.character,
    )
    os.makedirs(os.path.dirname(output_glb), exist_ok=True)
    report_path = os.path.join(GENERATED_DIR, "%s_ANIMATION_LIBRARY_V4.json" % args.character.upper())
    with open(BONE_MAP_JSON, "r", encoding="utf-8") as fh:
        pairs = mapped_pairs_from_bone_map(json.load(fh))

    reset_scene()
    bpy.context.scene.render.fps = 30
    import_fbx(cfg["fbx"])
    rebind_actorcore_textures(args.character)
    target = find_armature()
    meshes = skinned_meshes(target)
    clear_pose(target)
    bpy.context.view_layer.update()
    rest_vol, rest_size = mesh_volume(meshes[0])
    baked = []
    failed = []
    scene_start = 10 ** 9
    scene_end = 0
    for spec in SEMANTIC_CLIPS:
        path = os.path.join(ANIMATIONS_DIR, spec["file"])
        if not os.path.isfile(path):
            failed.append({"semantic": spec["semantic"], "error": "missing file", "file": spec["file"]})
            continue
        action, fs, fe = bake_clip(target, pairs, path, spec["semantic"], HIP_Y_SCALE)
        mid = int((fs + fe) * 0.5)
        target.animation_data.action = action
        bpy.context.scene.frame_set(mid)
        bpy.context.view_layer.update()
        idle_vol, idle_size = mesh_volume(meshes[0])
        vol_ratio = idle_vol / max(rest_vol, 1e-6)
        max_ratio = max(idle_size) / max(max(rest_size), 1e-6)
        ok = vol_ratio <= spec["vol_limit"] and max_ratio <= spec["axis_limit"]
        entry = {
            "semantic": spec["semantic"],
            "file": spec["file"],
            "frames": [fs, fe],
            "loop": spec["loop"],
            "volume_ratio": round(vol_ratio, 4),
            "max_axis_ratio": round(max_ratio, 4),
            "pass": ok,
        }
        if ok:
            baked.append(entry)
            scene_start = min(scene_start, fs)
            scene_end = max(scene_end, fe)
            # Keep a per-clip copy for archive.
            lib_copy = os.path.join(out_dir, "%s.action.txt" % spec["semantic"])
            with open(lib_copy, "w", encoding="utf-8") as fh:
                fh.write("%s frames %s-%s vol=%.3f\n" % (spec["semantic"], fs, fe, vol_ratio))
        else:
            failed.append(entry)
            bpy.data.actions.remove(action)
    report = {
        "character": args.character,
        "retarget": "clip_relative",
        "rest_size": [round(x, 4) for x in rest_size],
        "baked": baked,
        "failed": failed,
        "skipped": SKIPPED,
        "output_glb": output_glb,
    }
    write_json(report_path, report)
    idle_ok = any(b["semantic"] == "idle" and b["pass"] for b in baked)
    if not idle_ok:
        raise RuntimeError("Idle bake failed; refusing to export library. %s" % report_path)

    for mesh in meshes:
        limit_influences(mesh, 4)
    strip_non_production(target, None)
    purge_orphans()
    _push_actions_to_nla(target)
    if target.animation_data:
        target.animation_data.action = None
    bpy.context.scene.frame_start = int(scene_start if scene_start < 10 ** 8 else 1)
    bpy.context.scene.frame_end = int(scene_end if scene_end else 110)
    bpy.context.scene.frame_set(bpy.context.scene.frame_start)
    bpy.ops.export_scene.gltf(
        filepath=output_glb,
        export_format="GLB",
        export_animations=True,
        export_skins=True,
        export_materials=True,
        export_apply=False,
    )
    print("LIBRARY_V4 %s clips=%d failed=%d glb=%s" % (args.character, len(baked), len(failed), output_glb))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
