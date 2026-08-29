"""Dump Mixamo clip rest vs frame-1 vs intra-clip rotation magnitudes.

Used to decide which clips are safe for clip-relative ActorCore bake.
Clips whose frame 1 is still T-pose (tiny rest-relative rotation) will explode
if later frames contain T-pose→stand deltas.

Usage:
  blender --background --python inspect_mixamo_clips.py
"""
import json
import math
import os
import sys

import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import find_armature, find_source_action, import_fbx, reset_scene, write_json  # noqa: E402
from actorcore_paths import ANIMATIONS_DIR, GENERATED_DIR  # noqa: E402


SAMPLE_BONES = (
    "mixamorig:Hips",
    "mixamorig5:Hips",
    "mixamorig:Spine",
    "mixamorig5:Spine",
    "mixamorig:LeftArm",
    "mixamorig5:LeftArm",
    "mixamorig:RightArm",
    "mixamorig5:RightArm",
    "mixamorig:LeftUpLeg",
    "mixamorig5:LeftUpLeg",
    "mixamorig:RightUpLeg",
    "mixamorig5:RightUpLeg",
    "mixamorig:Head",
    "mixamorig5:Head",
)


def quat_angle_deg(q):
    ang = abs(math.degrees(q.angle))
    if ang > 180.0:
        ang = 360.0 - ang
    return ang


def inspect_clip(path):
    reset_scene()
    import_fbx(path)
    arm = find_armature()
    action = find_source_action(arm, "mixamo") if arm else None
    if arm is None or action is None:
        return {"path": path, "error": "missing armature/action"}
    arm.animation_data_create()
    arm.animation_data.action = action
    frame_start = int(action.frame_range[0])
    frame_end = int(action.frame_range[1])
    bpy.context.scene.frame_set(frame_start)
    bpy.context.view_layer.update()
    frame1 = {}
    max_frame1 = 0.0
    bones = []
    for pb in arm.pose.bones:
        if not any(token in pb.name for token in ("Hips", "Spine", "Arm", "UpLeg", "Head", "ForeArm", "Leg")):
            continue
        ang = quat_angle_deg(pb.matrix_basis.to_quaternion())
        rec = {"name": pb.name, "frame1_basis_deg": round(ang, 4), "location": [round(pb.location.x, 4), round(pb.location.y, 4), round(pb.location.z, 4)]}
        bones.append(rec)
        if ang > max_frame1:
            max_frame1 = ang
        if pb.name in SAMPLE_BONES or "Hips" in pb.name or pb.name.endswith("LeftArm") or pb.name.endswith("RightArm"):
            frame1[pb.name] = rec
    refs = {pb.name: pb.matrix_basis.to_quaternion().copy() for pb in arm.pose.bones}
    max_intra = 0.0
    intra_bone = ""
    step = max(1, int((frame_end - frame_start) / 12))
    for frame in range(frame_start, frame_end + 1, step):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        for pb in arm.pose.bones:
            delta = refs[pb.name].inverted() @ pb.matrix_basis.to_quaternion()
            ang = quat_angle_deg(delta)
            if ang > max_intra:
                max_intra = ang
                intra_bone = pb.name
    standing_like = max_frame1 >= 25.0
    return {
        "file": os.path.basename(path),
        "path": path,
        "action": action.name,
        "fps": bpy.context.scene.render.fps,
        "frame_range": [frame_start, frame_end],
        "armature_scale": [round(s, 6) for s in arm.scale],
        "armature_rotation_deg": [round(math.degrees(a), 4) for a in arm.rotation_euler],
        "bone_count": len(arm.data.bones),
        "max_frame1_basis_deg": round(max_frame1, 4),
        "max_intra_clip_deg": round(max_intra, 4),
        "max_intra_clip_bone": intra_bone,
        "frame1_looks_like_standing": standing_like,
        "clip_relative_safe": standing_like or max_intra < 35.0,
        "note": (
            "Frame 1 already holds T-pose→stand. Clip-relative bake stays on AccuRIG bind."
            if standing_like
            else "Frame 1 is near T-pose rest. Later frames may still contain T→stand and explode if rest-relative."
        ),
        "sample_frame1": frame1,
    }


def main():
    clips = []
    for name in sorted(os.listdir(ANIMATIONS_DIR)):
        if not name.lower().endswith(".fbx"):
            continue
        clips.append(inspect_clip(os.path.join(ANIMATIONS_DIR, name)))
    out = {
        "policy": "Bake with clip_relative only. Reject rest_relative. If frame1 is T-pose AND intra-clip > 35deg, treat as explosion risk.",
        "clips": clips,
    }
    write_json(os.path.join(GENERATED_DIR, "MIXAMO_CLIP_POSE_AUDIT.json"), out)
    print("MIXAMO_CLIP_POSE_AUDIT clips=%d" % len(clips))
    for clip in clips:
        print("  %s frame1=%.1f intra=%.1f standing=%s safe=%s" % (
            clip.get("file"),
            clip.get("max_frame1_basis_deg", -1),
            clip.get("max_intra_clip_deg", -1),
            clip.get("frame1_looks_like_standing"),
            clip.get("clip_relative_safe"),
        ))


if __name__ == "__main__":
    main()
