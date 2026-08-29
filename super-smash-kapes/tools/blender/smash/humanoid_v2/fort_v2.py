"""Ricardo Fort V2 — caricature head, costume, identity cues on humanoid base."""

from __future__ import annotations

import math

import bpy
from mathutils import Euler

from .materials_v2 import JeffreyMaterialsV2, assign
from .stylized_humanoid_base import (
    HumanoidProportions,
    StylizedHumanoidBase,
    make_cube,
    make_cylinder,
    make_ico,
    make_uv_sphere,
    parent,
    shade_smooth,
)


def fort_proportions() -> HumanoidProportions:
    return HumanoidProportions(
        height=2.05,
        head_ratio=0.30,
        shoulder_width=1.05,
        chest_depth=0.46,
        waist_width=0.68,
        hip_width=0.74,
        upper_arm_len=0.40,
        lower_arm_len=0.36,
        hand_size=0.22,
        upper_leg_len=0.40,
        lower_leg_len=0.36,
        shoe_len=0.36,
        shoe_w=0.22,
        shoe_h=0.13,
    )


def build_fort_head(root, mats: JeffreyMaterialsV2, head_center_z: float, head_h: float) -> dict:
    """Caricature head: jaw, cheeks, brow, hair volume, integrated sunglasses."""
    r = head_h * 0.42
    head = make_uv_sphere(
        "Head",
        (0, 0.04, head_center_z),
        r,
        mats.skin,
        segments=28,
        rings=18,
        scale=(1.0, 1.05, 1.08),
    )
    # Jaw / chin mass
    jaw = make_uv_sphere(
        "Jaw",
        (0, 0.10, head_center_z - r * 0.45),
        r * 0.55,
        mats.skin,
        segments=20,
        rings=12,
        scale=(1.15, 1.2, 0.7),
    )
    cheek_l = make_uv_sphere(
        "CheekL",
        (-r * 0.55, 0.18, head_center_z - r * 0.1),
        r * 0.32,
        mats.skin,
        segments=14,
        rings=10,
    )
    cheek_r = make_uv_sphere(
        "CheekR",
        (r * 0.55, 0.18, head_center_z - r * 0.1),
        r * 0.32,
        mats.skin,
        segments=14,
        rings=10,
    )
    # Brow ridge
    brow = make_cube(
        "Brow",
        (0, 0.28, head_center_z + r * 0.12),
        (r * 1.35, 0.08, 0.08),
        mats.brow,
        bevel_w=0.02,
    )
    # Nose
    nose = make_uv_sphere(
        "Nose",
        (0, 0.38, head_center_z - r * 0.05),
        r * 0.16,
        mats.skin,
        segments=12,
        rings=8,
        scale=(0.7, 1.3, 0.9),
    )
    # Mouth line
    mouth = make_cube(
        "Mouth",
        (0, 0.32, head_center_z - r * 0.42),
        (r * 0.55, 0.06, 0.05),
        mats.lip,
        bevel_w=0.015,
    )
    # Hair volume (dark styled mass) — back + top + sides
    hair_top = make_uv_sphere(
        "HairTop",
        (0, -0.05, head_center_z + r * 0.35),
        r * 0.95,
        mats.hair,
        segments=24,
        rings=14,
        scale=(1.15, 1.2, 0.7),
    )
    hair_back = make_uv_sphere(
        "HairBack",
        (0, -0.22, head_center_z + r * 0.05),
        r * 0.85,
        mats.hair,
        segments=20,
        rings=12,
        scale=(1.1, 0.85, 1.0),
    )
    hair_side_l = make_uv_sphere(
        "HairSideL",
        (-r * 0.75, 0.0, head_center_z + r * 0.05),
        r * 0.4,
        mats.hair,
        segments=14,
        rings=10,
        scale=(0.7, 1.0, 1.1),
    )
    hair_side_r = make_uv_sphere(
        "HairSideR",
        (r * 0.75, 0.0, head_center_z + r * 0.05),
        r * 0.4,
        mats.hair,
        segments=14,
        rings=10,
        scale=(0.7, 1.0, 1.1),
    )
    # Integrated sunglasses (frame + lenses seated on face)
    frame = make_cylinder(
        "GlassesFrame",
        (0, 0.36, head_center_z + r * 0.02),
        r * 0.55,
        0.06,
        mats.glasses_frame,
        verts=20,
        rot=(math.pi / 2, 0, 0),
        scale=(1.0, 0.35, 1.0),
    )
    lens_l = make_uv_sphere(
        "LensL",
        (-r * 0.28, 0.40, head_center_z + r * 0.02),
        r * 0.22,
        mats.glasses,
        segments=14,
        rings=10,
        scale=(1.1, 0.35, 0.85),
    )
    lens_r = make_uv_sphere(
        "LensR",
        (r * 0.28, 0.40, head_center_z + r * 0.02),
        r * 0.22,
        mats.glasses,
        segments=14,
        rings=10,
        scale=(1.1, 0.35, 0.85),
    )
    # Small gold star motif above head (identity, not floating far)
    star = make_ico(
        "Star",
        (0, 0.0, head_center_z + r * 1.15),
        0.07,
        mats.gold,
        subdivisions=1,
    )

    parts = {
        "head": head,
        "jaw": jaw,
        "cheek_l": cheek_l,
        "cheek_r": cheek_r,
        "brow": brow,
        "nose": nose,
        "mouth": mouth,
        "hair_top": hair_top,
        "hair_back": hair_back,
        "hair_side_l": hair_side_l,
        "hair_side_r": hair_side_r,
        "glasses_frame": frame,
        "lens_l": lens_l,
        "lens_r": lens_r,
        "Star": star,
    }
    for o in parts.values():
        parent(o, root)
    return parts


def build_fort_costume(root, mats: JeffreyMaterialsV2, shoulder_z: float, hip_z: float, shoulder_width: float) -> dict:
    """White jacket + gold lapels/cuffs following body, not pasted rectangles."""
    mid_z = (shoulder_z + hip_z) * 0.55
    # Jacket flare / peplum
    jacket_skirt = make_cube(
        "JacketSkirt",
        (0, 0.02, hip_z + 0.18),
        (shoulder_width * 0.95, 0.48, 0.28),
        mats.white_fabric,
        bevel_w=0.04,
    )
    # Gold lapels — angled thin forms along chest
    lapel_l = make_cube(
        "LapelL",
        (-0.18, 0.24, mid_z + 0.12),
        (0.16, 0.06, 0.55),
        mats.gold,
        bevel_w=0.02,
    )
    lapel_l.rotation_euler = Euler((0.15, 0.0, 0.35), "XYZ")
    bpy.context.view_layer.objects.active = lapel_l
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

    lapel_r = make_cube(
        "LapelR",
        (0.18, 0.24, mid_z + 0.12),
        (0.16, 0.06, 0.55),
        mats.gold,
        bevel_w=0.02,
    )
    lapel_r.rotation_euler = Euler((0.15, 0.0, -0.35), "XYZ")
    bpy.context.view_layer.objects.active = lapel_r
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

    # Chest gold accent panel (narrow, follows torso)
    chest_gold = make_cube(
        "ChestGold",
        (0, 0.26, mid_z + 0.05),
        (0.22, 0.05, 0.35),
        mats.gold,
        bevel_w=0.02,
    )
    # Cuffs
    cuff_l = make_cylinder(
        "CuffL",
        (-shoulder_width * 0.58, 0.08, shoulder_z - 0.72),
        0.09,
        0.08,
        mats.gold,
        verts=14,
    )
    cuff_r = make_cylinder(
        "CuffR",
        (shoulder_width * 0.58, 0.08, shoulder_z - 0.72),
        0.09,
        0.08,
        mats.gold,
        verts=14,
    )
    # Collar
    collar = make_cube(
        "Collar",
        (0, 0.12, shoulder_z + 0.02),
        (0.42, 0.28, 0.08),
        mats.white_fabric,
        bevel_w=0.02,
    )

    parts = {
        "jacket_skirt": jacket_skirt,
        "lapel_l": lapel_l,
        "lapel_r": lapel_r,
        "chest_gold": chest_gold,
        "cuff_l": cuff_l,
        "cuff_r": cuff_r,
        "collar": collar,
    }
    for o in parts.values():
        parent(o, root)
    return parts


def pose_theatrical_slap(parts: dict) -> None:
    """Rotate upper arm only — children follow via parenting (no floating hands)."""
    arm_r = parts.get("upper_arm_r")
    if arm_r is None:
        return
    arm_r.rotation_euler = Euler((0.35, -0.2, -0.75), "XYZ")
    # Do not apply transforms — keep hierarchy for export parenting.


def build_fort_v2(silhouette_only: bool = False) -> tuple:
    mats = JeffreyMaterialsV2(prefix="FortV2")
    if silhouette_only:
        # Force all mats to silhouette for form review
        for attr in (
            "skin",
            "hair",
            "white_fabric",
            "gold",
            "dark_fabric",
            "glasses",
            "glasses_frame",
            "lip",
            "brow",
        ):
            setattr(mats, attr, mats.silhouette)

    base = StylizedHumanoidBase(fort_proportions(), mats)
    root = base.build_body(personality="theatrical")
    head_parts = build_fort_head(root, mats, base.parts["head_center_z"], base.parts["head_h"])
    costume = {}
    if not silhouette_only:
        costume = build_fort_costume(
            root,
            mats,
            base.parts["shoulder_z"],
            base.parts["hip_z"],
            base.props.shoulder_width,
        )
        pose_theatrical_slap(base.parts)

    parts = {**base.parts, **head_parts, **costume}
    return root, parts, mats
