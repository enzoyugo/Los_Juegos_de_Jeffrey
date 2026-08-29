"""Reusable stylized humanoid mesh primitives and body builder (party-game proportions)."""

from __future__ import annotations

import math
from dataclasses import dataclass

import bpy
from mathutils import Euler, Vector

from .materials_v2 import JeffreyMaterialsV2, assign


@dataclass
class HumanoidProportions:
    """Party-game caricature proportions (height ~2.0 Blender units)."""

    height: float = 2.0
    head_ratio: float = 0.28  # 25–32%
    shoulder_width: float = 0.95
    chest_depth: float = 0.42
    waist_width: float = 0.62
    hip_width: float = 0.70
    upper_arm_len: float = 0.38
    lower_arm_len: float = 0.34
    hand_size: float = 0.20
    upper_leg_len: float = 0.42
    lower_leg_len: float = 0.38
    shoe_len: float = 0.34
    shoe_w: float = 0.20
    shoe_h: float = 0.12


def _active():
    return bpy.context.object


def _apply_trs(obj, loc, scale=None, rot=None):
    if scale is not None:
        obj.scale = scale
    if rot is not None:
        obj.rotation_euler = Euler(rot, "XYZ")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.location = loc


def bevel(obj, width: float = 0.03, segments: int = 2) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    mod = obj.modifiers.new(name="Bevel", type="BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(30)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def shade_smooth(obj, auto_smooth_deg: float = 45.0) -> None:
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()
    mesh = obj.data
    try:
        mesh.use_auto_smooth = True
        mesh.auto_smooth_angle = math.radians(auto_smooth_deg)
    except Exception:
        # Blender 5 may use different smooth storage; ignore if unavailable.
        pass


def make_cube(name, loc, size, material=None, bevel_w=0.03):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    obj = _active()
    obj.name = name
    _apply_trs(obj, loc, scale=size)
    if bevel_w > 0:
        bevel(obj, bevel_w, 2)
    shade_smooth(obj)
    if material:
        assign(obj, material)
    return obj


def make_uv_sphere(name, loc, radius, material=None, segments=24, rings=16, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=(0, 0, 0), segments=segments, ring_count=rings)
    obj = _active()
    obj.name = name
    _apply_trs(obj, loc, scale=scale)
    shade_smooth(obj, 55)
    if material:
        assign(obj, material)
    return obj


def make_ico(name, loc, radius, material=None, subdivisions=2, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=radius, location=(0, 0, 0), subdivisions=subdivisions)
    obj = _active()
    obj.name = name
    _apply_trs(obj, loc, scale=scale)
    shade_smooth(obj, 55)
    if material:
        assign(obj, material)
    return obj


def make_taper_limb(name, loc, length, r_top, r_bot, material=None, verts=16):
    """Vertical limb along +Z, origin at top."""
    bpy.ops.mesh.primitive_cone_add(
        radius1=r_bot, radius2=r_top, depth=length, location=(0, 0, 0), vertices=verts
    )
    obj = _active()
    obj.name = name
    # Cone default: tip along +Z from center; shift so top at loc.
    _apply_trs(obj, (loc[0], loc[1], loc[2] - length * 0.5))
    shade_smooth(obj, 40)
    if material:
        assign(obj, material)
    return obj


def make_cylinder(name, loc, radius, depth, material=None, verts=16, scale=(1, 1, 1), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=(0, 0, 0), vertices=verts)
    obj = _active()
    obj.name = name
    _apply_trs(obj, loc, scale=scale, rot=rot)
    shade_smooth(obj, 40)
    if material:
        assign(obj, material)
    return obj


def parent(child, parent_obj, keep_transform: bool = True):
    if keep_transform:
        child.parent = parent_obj
        child.matrix_parent_inverse = parent_obj.matrix_world.inverted()
    else:
        child.parent = parent_obj


def join_objects(name: str, objs: list):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    joined = _active()
    joined.name = name
    return joined


class StylizedHumanoidBase:
    """Builds a cohesive stylized body under a root empty."""

    def __init__(self, props: HumanoidProportions | None = None, mats: JeffreyMaterialsV2 | None = None):
        self.props = props or HumanoidProportions()
        self.mats = mats or JeffreyMaterialsV2()
        self.root = None
        self.parts: dict = {}

    def build_body(self, personality: str = "theatrical") -> bpy.types.Object:
        p = self.props
        m = self.mats
        root = bpy.data.objects.new("HumanoidRoot", None)
        bpy.context.scene.collection.objects.link(root)
        self.root = root

        head_h = p.height * p.head_ratio
        head_center_z = p.height - head_h * 0.45
        neck_z = head_center_z - head_h * 0.42
        shoulder_z = neck_z - 0.06
        hip_z = p.shoe_h + p.lower_leg_len + p.upper_leg_len * 0.15
        torso_top = shoulder_z
        torso_bot = hip_z + 0.08
        torso_h = max(0.35, torso_top - torso_bot)
        torso_mid = (torso_top + torso_bot) * 0.5

        # ---- TORSO (beveled, waist taper via two overlapping forms) ----
        chest = make_cube(
            "Chest",
            (0, 0, torso_mid + torso_h * 0.12),
            (p.shoulder_width * 0.92, p.chest_depth, torso_h * 0.72),
            m.white_fabric,
            bevel_w=0.045,
        )
        waist = make_cube(
            "Waist",
            (0, 0, torso_bot + torso_h * 0.18),
            (p.waist_width, p.chest_depth * 0.9, torso_h * 0.45),
            m.white_fabric,
            bevel_w=0.04,
        )
        hips = make_cube(
            "Hips",
            (0, 0, hip_z + 0.05),
            (p.hip_width, p.chest_depth * 0.85, 0.22),
            m.dark_fabric,
            bevel_w=0.035,
        )
        # Soft belly/chest volume so torso isn't a slab
        belly = make_uv_sphere(
            "ChestVolume",
            (0, p.chest_depth * 0.18, torso_mid + 0.08),
            0.28,
            m.white_fabric,
            segments=24,
            rings=14,
            scale=(p.shoulder_width * 0.78, 0.62, 0.78),
        )
        # Extra waist tuck sphere (negative space illusion via darker narrow band already on hips)
        underbust = make_uv_sphere(
            "Underbust",
            (0, 0.05, torso_mid - 0.08),
            0.2,
            m.white_fabric,
            segments=18,
            rings=10,
            scale=(p.waist_width * 1.05, 0.7, 0.45),
        )

        # ---- SHOULDERS ----
        sh_l = make_uv_sphere(
            "ShoulderL",
            (-p.shoulder_width * 0.48, 0, shoulder_z - 0.02),
            0.14,
            m.white_fabric,
            scale=(1.15, 0.95, 0.85),
        )
        sh_r = make_uv_sphere(
            "ShoulderR",
            (p.shoulder_width * 0.48, 0, shoulder_z - 0.02),
            0.14,
            m.white_fabric,
            scale=(1.15, 0.95, 0.85),
        )

        # ---- NECK ----
        neck = make_cylinder(
            "Neck",
            (0, 0.02, neck_z),
            0.09,
            head_h * 0.22,
            m.skin,
            verts=14,
        )

        # ---- ARMS (tapered upper/lower + mitten hands) ----
        arm_attach_z = shoulder_z - 0.05
        arm_x = p.shoulder_width * 0.55
        for side, sx in (("L", -1), ("R", 1)):
            ux = sx * arm_x
            upper = make_taper_limb(
                f"UpperArm{side}",
                (ux, 0.02, arm_attach_z),
                p.upper_arm_len,
                0.10,
                0.075,
                m.skin,
            )
            flare = 0.18 if personality == "theatrical" else 0.08
            upper.rotation_euler = Euler((0.12, 0.0, sx * flare), "XYZ")
            bpy.context.view_layer.objects.active = upper
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

            elbow_z = arm_attach_z - p.upper_arm_len * 0.92
            lower = make_taper_limb(
                f"LowerArm{side}",
                (ux * 1.02, 0.06, elbow_z),
                p.lower_arm_len,
                0.07,
                0.055,
                m.skin,
            )
            # Overlap elbow so chain reads connected
            lower.location.z = elbow_z + 0.04
            hand_z = elbow_z - p.lower_arm_len * 0.88
            hand = make_uv_sphere(
                f"Hand{side}",
                (ux * 1.04, 0.14, hand_z),
                p.hand_size * 0.55,
                m.skin,
                segments=16,
                rings=10,
                scale=(1.1, 1.35, 0.75),
            )
            thumb = make_uv_sphere(
                f"Thumb{side}",
                (ux * 1.04 + sx * 0.08, 0.24, hand_z + 0.02),
                p.hand_size * 0.22,
                m.skin,
                segments=10,
                rings=8,
            )
            parent(lower, upper)
            parent(hand, lower)
            parent(thumb, hand)
            self.parts[f"upper_arm_{side.lower()}"] = upper
            self.parts[f"lower_arm_{side.lower()}"] = lower
            self.parts[f"hand_{side.lower()}"] = hand
            self.parts[f"thumb_{side.lower()}"] = thumb

        # ---- LEGS ----
        for side, sx in (("L", -1), ("R", 1)):
            lx = sx * p.hip_width * 0.28
            ul = make_taper_limb(
                f"UpperLeg{side}",
                (lx, 0.0, hip_z + 0.02),
                p.upper_leg_len,
                0.12,
                0.09,
                m.dark_fabric,
            )
            knee_z = hip_z + 0.02 - p.upper_leg_len * 0.92
            ll = make_taper_limb(
                f"LowerLeg{side}",
                (lx, 0.02, knee_z + 0.03),
                p.lower_leg_len,
                0.085,
                0.065,
                m.dark_fabric,
            )
            foot_z = p.shoe_h * 0.55
            shoe = make_cube(
                f"Shoe{side}",
                (lx, 0.10, foot_z),
                (p.shoe_w, p.shoe_len, p.shoe_h),
                m.gold,
                bevel_w=0.025,
            )
            parent(ll, ul)
            parent(shoe, ll)
            self.parts[f"upper_leg_{side.lower()}"] = ul
            self.parts[f"lower_leg_{side.lower()}"] = ll
            self.parts[f"foot_{side.lower()}"] = shoe

        body_parts = [
            chest,
            waist,
            hips,
            belly,
            underbust,
            sh_l,
            sh_r,
            neck,
            self.parts["upper_arm_l"],
            self.parts["upper_arm_r"],
            self.parts["upper_leg_l"],
            self.parts["upper_leg_r"],
        ]
        # lower arms/hands/legs/shoes already parented in limb chains
        for o in body_parts:
            parent(o, root)

        self.parts.update(
            {
                "chest": chest,
                "waist": waist,
                "hips": hips,
                "belly": belly,
                "underbust": underbust,
                "shoulder_l": sh_l,
                "shoulder_r": sh_r,
                "neck": neck,
                "head_center_z": head_center_z,
                "head_h": head_h,
                "shoulder_z": shoulder_z,
                "hip_z": hip_z,
            }
        )
        # Godot motion hooks (legacy names)
        self.parts["ArmL"] = self.parts["upper_arm_l"]
        self.parts["ArmR"] = self.parts["upper_arm_r"]
        self.parts["LegL"] = self.parts["upper_leg_l"]
        self.parts["LegR"] = self.parts["upper_leg_r"]
        return root
