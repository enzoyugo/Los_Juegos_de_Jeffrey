"""
Inspect Jaguareté v2 GLB + Mixamo Idle.fbx in Blender 2.83.
Read-only — does not modify source assets.
"""
import bpy
import json
import math
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from ssk_blender_paths import (  # noqa: E402
    IDLE_FBX,
    JAGUARETE_V2_GLB,
    RIG_DUMP_TXT,
)


def _reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _import_gltf(path: str) -> None:
    bpy.ops.import_scene.gltf(filepath=path)


def _import_fbx(path: str) -> None:
    bpy.ops.import_scene.fbx(filepath=path)


def _find_armatures() -> list:
    return [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]


def _bone_hierarchy(arm_obj) -> list:
    lines = []
    for bone in arm_obj.data.bones:
        parent = bone.parent.name if bone.parent else "-"
        lines.append(f"  {bone.name} (parent={parent})")
    return lines


def _bone_rest_dump(arm_obj) -> list:
    lines = []
    for bone in arm_obj.data.bones:
        head = bone.head_local
        tail = bone.tail_local
        mat = bone.matrix_local
        lines.append(
            f"  {bone.name}: head=({head.x:.5f},{head.y:.5f},{head.z:.5f}) "
            f"tail=({tail.x:.5f},{tail.y:.5f},{tail.z:.5f}) "
            f"mat_local={[round(v, 5) for row in mat for v in row]}"
        )
    return lines


def _mesh_skin_report(arm_obj) -> list:
    lines = []
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for mod in obj.modifiers:
            if mod.type == "ARMATURE" and mod.object == arm_obj:
                lines.append(f"  mesh={obj.name} armature_modifier=yes vertex_groups={len(obj.vertex_groups)}")
    return lines


def _action_report(arm_obj) -> list:
    lines = []
    if arm_obj.animation_data and arm_obj.animation_data.action:
        action = arm_obj.animation_data.action
        lines.append(f"  active_action={action.name}")
        lines.append(f"  frame_range={action.frame_range[0]}..{action.frame_range[1]}")
        lines.append(f"  fcurves={len(action.fcurves)}")
    for action in bpy.data.actions:
        lines.append(f"  action_in_file={action.name} frames={action.frame_range[0]}..{action.frame_range[1]}")
    return lines


def _root_translation_report(arm_obj, action_name: str) -> list:
    lines = []
    action = bpy.data.actions.get(action_name)
    if action is None and arm_obj.animation_data and arm_obj.animation_data.action:
        action = arm_obj.animation_data.action
    if action is None:
        lines.append("  no action for root translation audit")
        return lines
    hips_names = [b.name for b in arm_obj.data.bones if "Hip" in b.name or "hip" in b.name]
    if not hips_names:
        hips_names = [arm_obj.data.bones[0].name]
    for bone_name in hips_names:
        for axis, label in enumerate(("x", "y", "z")):
            path = f'pose.bones["{bone_name}"].location'
            fc = action.fcurves.find(path, index=axis)
            if fc is None:
                continue
            vals = [kp.co[1] for kp in fc.keyframe_points]
            if vals:
                lines.append(
                    f"  {bone_name}.location.{label}: min={min(vals):.5f} max={max(vals):.5f} keys={len(vals)}"
                )
    return lines


def main() -> None:
    os.makedirs(os.path.dirname(RIG_DUMP_TXT), exist_ok=True)
    out = []
    out.append("=== SSK Jaguareté Blender Rig Dump ===")
    out.append(f"Blender: {bpy.app.version_string}")
    out.append(f"Jaguareté GLB: {JAGUARETE_V2_GLB}")
    out.append(f"Idle FBX: {IDLE_FBX}")
    out.append("")

    if not os.path.isfile(JAGUARETE_V2_GLB):
        out.append(f"ERROR: missing {JAGUARETE_V2_GLB}")
    if not os.path.isfile(IDLE_FBX):
        out.append(f"ERROR: missing {IDLE_FBX}")

    _reset_scene()
    out.append("--- JAGUARETÉ V2 GLB ---")
    _import_gltf(JAGUARETE_V2_GLB)
    jag_arms = _find_armatures()
    out.append(f"armature_count={len(jag_arms)}")
    jag_arm = jag_arms[0] if jag_arms else None
    if jag_arm:
        out.append(f"armature_name={jag_arm.name}")
        out.append(f"bone_count={len(jag_arm.data.bones)}")
        out.append("bone_hierarchy:")
        out.extend(_bone_hierarchy(jag_arm))
        out.append("bone_rest:")
        out.extend(_bone_rest_dump(jag_arm))
        out.append("mesh_skin:")
        out.extend(_mesh_skin_report(jag_arm))
    else:
        out.append("ERROR: no Jaguareté armature found")

    out.append("")
    out.append("--- MIXAMO IDLE FBX ---")
    _import_fbx(IDLE_FBX)
    mix_arms = [a for a in _find_armatures() if jag_arm is None or a != jag_arm]
    if jag_arm and len(mix_arms) == 0:
        mix_arms = [a for a in _find_armatures() if a.name != jag_arm.name]
    out.append(f"armature_count={len(mix_arms)}")
    mix_arm = mix_arms[0] if mix_arms else None
    if mix_arm:
        out.append(f"armature_name={mix_arm.name}")
        out.append(f"bone_count={len(mix_arm.data.bones)}")
        out.append("bone_hierarchy:")
        out.extend(_bone_hierarchy(mix_arm))
        out.append("bone_rest:")
        out.extend(_bone_rest_dump(mix_arm))
        out.append("actions:")
        out.extend(_action_report(mix_arm))
        out.append("root_translation_channels:")
        for act in bpy.data.actions:
            out.extend(_root_translation_report(mix_arm, act.name))
    else:
        out.append("ERROR: no Mixamo armature found")

    out.append("")
    out.append("--- SCENE FPS ---")
    out.append(f"scene_fps={bpy.context.scene.render.fps}")

    text = "\n".join(out)
    with open(RIG_DUMP_TXT, "w", encoding="utf-8") as fh:
        fh.write(text)
    print(text)
    print(f"\nWrote {RIG_DUMP_TXT}")


if __name__ == "__main__":
    main()
