"""Minimal armature + short clip set for stylized humanoid V2."""

from __future__ import annotations

import math

import bpy
from mathutils import Vector


BONE_LIST = [
    ("root", (0, 0, 0), (0, 0, 0.05)),
    ("hips", (0, 0, 0.85), (0, 0, 0.95)),
    ("spine", (0, 0, 0.95), (0, 0, 1.15)),
    ("chest", (0, 0, 1.15), (0, 0, 1.35)),
    ("head", (0, 0, 1.45), (0, 0, 1.75)),
    ("upper_arm.L", (-0.45, 0, 1.38), (-0.55, 0, 1.05)),
    ("lower_arm.L", (-0.55, 0, 1.05), (-0.60, 0.05, 0.75)),
    ("hand.L", (-0.60, 0.05, 0.75), (-0.62, 0.12, 0.62)),
    ("upper_arm.R", (0.45, 0, 1.38), (0.55, 0, 1.05)),
    ("lower_arm.R", (0.55, 0, 1.05), (0.60, 0.05, 0.75)),
    ("hand.R", (0.60, 0.05, 0.75), (0.62, 0.12, 0.62)),
    ("upper_leg.L", (-0.18, 0, 0.85), (-0.20, 0, 0.48)),
    ("lower_leg.L", (-0.20, 0, 0.48), (-0.20, 0.02, 0.16)),
    ("foot.L", (-0.20, 0.02, 0.16), (-0.20, 0.18, 0.05)),
    ("upper_leg.R", (0.18, 0, 0.85), (0.20, 0, 0.48)),
    ("lower_leg.R", (0.20, 0, 0.48), (0.20, 0.02, 0.16)),
    ("foot.R", (0.20, 0.02, 0.16), (0.20, 0.18, 0.05)),
]

PARENTS = {
    "hips": "root",
    "spine": "hips",
    "chest": "spine",
    "head": "chest",
    "upper_arm.L": "chest",
    "lower_arm.L": "upper_arm.L",
    "hand.L": "lower_arm.L",
    "upper_arm.R": "chest",
    "lower_arm.R": "upper_arm.R",
    "hand.R": "lower_arm.R",
    "upper_leg.L": "hips",
    "lower_leg.L": "upper_leg.L",
    "foot.L": "lower_leg.L",
    "upper_leg.R": "hips",
    "lower_leg.R": "upper_leg.R",
    "foot.R": "lower_leg.R",
}


def create_armature(name: str = "FortArmature") -> bpy.types.Object:
    arm_data = bpy.data.armatures.new(name)
    arm_obj = bpy.data.objects.new(name, arm_data)
    bpy.context.scene.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    edit_bones = arm_data.edit_bones
    created = {}
    for bname, head, tail in BONE_LIST:
        bone = edit_bones.new(bname)
        bone.head = Vector(head)
        bone.tail = Vector(tail)
        created[bname] = bone
    for child, parent in PARENTS.items():
        if child in created and parent in created:
            created[child].parent = created[parent]
            created[child].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm_obj


def bind_meshes(arm_obj, mesh_objs: list) -> None:
    for mesh in mesh_objs:
        if mesh.type != "MESH":
            continue
        mesh.parent = arm_obj
        mod = mesh.modifiers.new(name="Armature", type="ARMATURE")
        mod.object = arm_obj
    bpy.context.view_layer.objects.active = arm_obj
    # Attempt automatic weights on joined selection
    bpy.ops.object.select_all(action="DESELECT")
    for mesh in mesh_objs:
        if mesh.type == "MESH":
            mesh.select_set(True)
    arm_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    except Exception:
        pass


def _ensure_action(arm_obj, name: str, frames: int = 24):
    if arm_obj.animation_data is None:
        arm_obj.animation_data_create()
    action = bpy.data.actions.new(name=name)
    arm_obj.animation_data.action = action
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = frames
    return action


def _key_pose(arm_obj, frame: int, bone_rots: dict):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="POSE")
    for bname, euler in bone_rots.items():
        pb = arm_obj.pose.bones.get(bname)
        if pb is None:
            continue
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = euler
        pb.keyframe_insert(data_path="rotation_euler", frame=frame)
    bpy.ops.object.mode_set(mode="OBJECT")


def add_minimum_animations(arm_obj) -> list[str]:
    """IDLE / ATTACK / HIT / JUMP / KO — short exaggerated clips."""
    names = []

    _ensure_action(arm_obj, "IDLE", 32)
    _key_pose(arm_obj, 1, {"spine": (0, 0, 0), "upper_arm.R": (0.1, 0, -0.2), "upper_arm.L": (0.1, 0, 0.2)})
    _key_pose(arm_obj, 16, {"spine": (0.05, 0, 0), "upper_arm.R": (0.15, 0, -0.25), "upper_arm.L": (0.08, 0, 0.18)})
    _key_pose(arm_obj, 32, {"spine": (0, 0, 0), "upper_arm.R": (0.1, 0, -0.2), "upper_arm.L": (0.1, 0, 0.2)})
    names.append("IDLE")

    _ensure_action(arm_obj, "ATTACK", 16)
    _key_pose(arm_obj, 1, {"upper_arm.R": (0.2, 0, -0.3), "chest": (0, 0, 0)})
    _key_pose(arm_obj, 6, {"upper_arm.R": (-0.2, -0.4, -1.2), "chest": (0, 0.15, -0.2)})
    _key_pose(arm_obj, 12, {"upper_arm.R": (0.1, -0.1, -0.8), "chest": (0, 0.05, -0.05)})
    _key_pose(arm_obj, 16, {"upper_arm.R": (0.2, 0, -0.3), "chest": (0, 0, 0)})
    names.append("ATTACK")

    _ensure_action(arm_obj, "HIT", 10)
    _key_pose(arm_obj, 1, {"spine": (0, 0, 0), "head": (0, 0, 0)})
    _key_pose(arm_obj, 4, {"spine": (-0.25, 0, 0.2), "head": (-0.2, 0, 0.3), "upper_arm.L": (0.6, 0, 0.5)})
    _key_pose(arm_obj, 10, {"spine": (0, 0, 0), "head": (0, 0, 0)})
    names.append("HIT")

    _ensure_action(arm_obj, "JUMP", 14)
    _key_pose(arm_obj, 1, {"hips": (0, 0, 0), "upper_leg.L": (0.3, 0, 0), "upper_leg.R": (-0.2, 0, 0)})
    _key_pose(arm_obj, 7, {"hips": (0, 0, 0.08), "upper_leg.L": (0.5, 0, 0), "upper_leg.R": (0.4, 0, 0)})
    _key_pose(arm_obj, 14, {"hips": (0, 0, 0), "upper_leg.L": (0.1, 0, 0), "upper_leg.R": (0.1, 0, 0)})
    names.append("JUMP")

    _ensure_action(arm_obj, "KO", 18)
    _key_pose(arm_obj, 1, {"spine": (0, 0, 0), "head": (0, 0, 0)})
    _key_pose(arm_obj, 8, {"spine": (-0.9, 0, 0.2), "head": (-0.6, 0, 0.4), "upper_arm.L": (1.0, 0, 0.8), "upper_arm.R": (1.0, 0, -0.8)})
    _key_pose(arm_obj, 18, {"spine": (-1.1, 0, 0.1), "head": (-0.8, 0, 0.2)})
    names.append("KO")

    # Leave IDLE as active default
    if arm_obj.animation_data and "IDLE" in bpy.data.actions:
        arm_obj.animation_data.action = bpy.data.actions["IDLE"]
    return names
