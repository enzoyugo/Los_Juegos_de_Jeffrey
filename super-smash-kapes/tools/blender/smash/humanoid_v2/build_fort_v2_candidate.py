"""Build Fort stylized V2 candidate + V1/V2 review package.

Does NOT overwrite fort_stylized_v1.glb or production catalog paths.

Usage:
  blender --background --python tools/blender/smash/humanoid_v2/build_fort_v2_candidate.py
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
SMASH = HERE.parent  # tools/blender/smash
ROOT = HERE.parents[3]  # super-smash-kapes (humanoid_v2→smash→blender→tools→project)
sys.path.insert(0, str(SMASH))
assert (ROOT / "project.godot").is_file(), f"ROOT misresolved: {ROOT}"

from humanoid_v2.bpy_scene import (  # noqa: E402
    count_tris,
    export_glb,
    mesh_objects,
    reset_scene,
    save_blend,
    setup_three_point,
)
from humanoid_v2.fort_v2 import build_fort_v2  # noqa: E402
from humanoid_v2.portrait_scene_v2 import (  # noqa: E402
    apply_silhouette_world,
    ensure_camera,
    render_angle_set,
    render_select_victory,
    render_still,
)
from humanoid_v2.rig_v2 import add_minimum_animations, bind_meshes, create_armature  # noqa: E402
from humanoid_v2.validation_v2 import validate_candidate, write_report  # noqa: E402

OUT_ASSET = ROOT / "assets/fighters/processed/fort"
OUT_BLEND = ROOT / "assets/fighters/sources/fort"
OUT_REVIEW = Path(r"E:\JeffreyAIResearch\outputs\runtime-review\smash_stylized_character_pipeline_v2")
COMPARE = OUT_REVIEW / "fort_comparison"
V1_GLB = OUT_ASSET / "fort_stylized_v1.glb"
V2_GLB = OUT_ASSET / "fort_stylized_v2_candidate.glb"
V2_BLEND = OUT_BLEND / "fort_stylized_v2_candidate.blend"


def _copy_v1_review_if_present() -> None:
    """Reuse prior V1 review stills when available."""
    src = Path(r"E:\JeffreyAIResearch\outputs\runtime-review\smash_art_asset_production_v1\fighters\fort")
    mapping = {
        "front.png": "V1_FRONT.png",
        "three_quarter.png": "V1_3Q.png",
        "side.png": "V1_SIDE.png",
        "gameplay_distance.png": "V1_GAMEPLAY.png",
        "select_portrait.png": "V1_SELECT.png",
        "victory_portrait.png": "V1_VICTORY.png",
    }
    COMPARE.mkdir(parents=True, exist_ok=True)
    for a, b in mapping.items():
        sp = src / a
        if sp.is_file():
            shutil.copy2(sp, COMPARE / b)


def render_v1_from_glb() -> dict:
    """Import V1 GLB and render comparison angles with same camera language."""
    if not V1_GLB.is_file():
        return {"error": "v1_glb_missing"}
    reset_scene(0.25)
    setup_three_point()
    bpy.ops.import_scene.gltf(filepath=str(V1_GLB))
    # Re-center roughly on origin
    ensure_camera()
    paths = render_angle_set(COMPARE, look_z=1.2, prefix="V1_")
    por = render_select_victory(COMPARE, look_z=1.35, prefix="V1_")
    paths.update(por)
    return paths


def build_silhouette_pass() -> dict:
    reset_scene(0.1)
    setup_three_point(40, 20, 25)
    apply_silhouette_world()
    root, parts, _mats = build_fort_v2(silhouette_only=True)
    ensure_camera()
    sil_dir = OUT_REVIEW / "fort_silhouette"
    paths = render_angle_set(sil_dir, look_z=1.35, prefix="SIL_")
    # Also neutral-material gameplay
    return {"root_name": root.name, "paths": paths, "tris": count_tris([root])}


def join_selected_meshes(name: str, objs: list):
    valid = [o for o in objs if o is not None and o.type == "MESH"]
    if not valid:
        return None
    if len(valid) == 1:
        valid[0].name = name
        return valid[0]
    bpy.ops.object.select_all(action="DESELECT")
    for o in valid:
        o.select_set(True)
    bpy.context.view_layer.objects.active = valid[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    return joined


def build_full_candidate() -> dict:
    reset_scene(0.2)
    setup_three_point()
    root, parts, mats = build_fort_v2(silhouette_only=False)

    # Rename motion hooks before any join
    for legacy, key in (("ArmL", "upper_arm_l"), ("ArmR", "upper_arm_r"), ("LegL", "upper_leg_l"), ("LegR", "upper_leg_r")):
        obj = parts.get(key)
        if obj is not None:
            obj.name = legacy
    if parts.get("Star") is not None:
        parts["Star"].name = "Star"

    # Join into coherent regions for stable export (keeps materials as slots).
    from humanoid_v2.stylized_humanoid_base import join_objects

    body_keys = [
        "chest", "waist", "hips", "belly", "underbust", "shoulder_l", "shoulder_r", "neck",
        "jacket_skirt", "lapel_l", "lapel_r", "chest_gold", "cuff_l", "cuff_r", "collar",
    ]
    head_keys = [
        "head", "jaw", "cheek_l", "cheek_r", "brow", "nose", "mouth",
        "hair_top", "hair_back", "hair_side_l", "hair_side_r",
        "glasses_frame", "lens_l", "lens_r", "Star",
    ]
    limb_keys = [
        "ArmL", "lower_arm_l", "hand_l", "thumb_l",
        "ArmR", "lower_arm_r", "hand_r", "thumb_r",
        "LegL", "lower_leg_l", "foot_l",
        "LegR", "lower_leg_r", "foot_r",
    ]
    body_mesh = join_objects("FortBody", [parts[k] for k in body_keys if parts.get(k)])
    head_mesh = join_objects("FortHead", [parts[k] for k in head_keys if parts.get(k)])
    # Keep limbs separate for procedural Godot motion hooks when unskinned
    limb_meshes = [parts[k] for k in limb_keys if parts.get(k)]

    export_meshes = [m for m in [body_mesh, head_mesh] + limb_meshes if m is not None]
    for m in export_meshes:
        m.parent = root

    # Armature: parent only (no AUTO weights — avoids invalid mesh export).
    # Animations live on armature in .blend; static GLB is the visual candidate.
    arm = create_armature("FortV2Armature")
    anims = []
    try:
        for m in export_meshes:
            m.parent = arm
        root.parent = arm
        anims = add_minimum_animations(arm)
        export_roots = [arm]
    except Exception as exc:
        print("RIG_WARN", exc)
        export_roots = [root] + export_meshes

    export_glb(V2_GLB, export_roots)
    try:
        save_blend(V2_BLEND)
    except Exception as exc:
        print("BLEND_SAVE_WARN", exc)

    report = validate_candidate(arm if arm else root, V2_GLB)
    report["animations"] = anims
    report["skinning"] = "parent_only_no_auto_weights"
    write_report(OUT_REVIEW / "fort_v2_validation.json", report)

    ensure_camera()
    bpy.context.scene.render.film_transparent = True
    angle_paths = render_angle_set(COMPARE, look_z=1.35, prefix="V2_")
    por_paths = render_select_victory(COMPARE, look_z=1.45, prefix="V2_")
    cand_por = OUT_ASSET / "fort_v2_candidate_portrait.png"
    cand_vic = OUT_ASSET / "fort_v2_candidate_victory.png"
    from humanoid_v2.portrait_scene_v2 import frame_character

    cam = bpy.context.scene.camera
    frame_character(cam, look_z=1.45, dist=3.2, side=1.2, height=1.6)
    render_still(cand_por, 768, 768)
    frame_character(cam, look_z=1.3, dist=4.0, side=1.8, height=1.45)
    render_still(cand_vic, 768, 960)

    summary = {
        "v2_glb": str(V2_GLB),
        "v2_blend": str(V2_BLEND),
        "validation": report,
        "angles": angle_paths,
        "portraits": por_paths,
        "candidate_portrait": str(cand_por),
        "candidate_victory": str(cand_vic),
        "tris": report.get("triangle_count"),
        "glb_bytes": V2_GLB.stat().st_size if V2_GLB.is_file() else 0,
    }
    return summary


def write_side_by_side_note(summary: dict) -> None:
    note = COMPARE / "COMPARISON_README.txt"
    lines = [
        "Fort V1 vs V2 comparison package",
        "V1 = production interim fort_stylized_v1.glb (frozen)",
        "V2 = fort_stylized_v2_candidate (NOT production until human approval)",
        "",
        f"V2 tris: {summary.get('tris')}",
        f"V2 glb bytes: {summary.get('glb_bytes')}",
        f"V2 validation ok: {summary.get('validation', {}).get('ok')}",
        f"V2 issues: {summary.get('validation', {}).get('issues')}",
        "",
        "Review pairs: V1_FRONT/V2_FRONT, V1_3Q/V2_3Q, V1_SIDE/V2_SIDE,",
        "V1_GAMEPLAY/V2_GAMEPLAY, V1_SELECT/V2_SELECT, V1_VICTORY/V2_VICTORY",
    ]
    note.write_text("\n".join(lines), encoding="utf-8")


def main():
    OUT_REVIEW.mkdir(parents=True, exist_ok=True)
    COMPARE.mkdir(parents=True, exist_ok=True)
    OUT_BLEND.mkdir(parents=True, exist_ok=True)

    print("PHASE_SILHOUETTE")
    sil = build_silhouette_pass()
    (OUT_REVIEW / "fort_silhouette_stats.json").write_text(json.dumps(sil, indent=2), encoding="utf-8")

    print("PHASE_V1_RENDER")
    try:
        v1_paths = render_v1_from_glb()
    except Exception as exc:
        print("V1_RENDER_WARN", exc)
        _copy_v1_review_if_present()
        v1_paths = {"fallback": "copied_prior_review"}

    print("PHASE_V2_FULL")
    summary = build_full_candidate()
    summary["v1_paths"] = v1_paths
    summary["silhouette"] = sil
    write_side_by_side_note(summary)
    (OUT_REVIEW / "fort_v2_build_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print("FORT_V2_CANDIDATE_PASS", json.dumps({"tris": summary.get("tris"), "glb": summary.get("v2_glb")}))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("FORT_V2_CANDIDATE_FAIL", exc)
        raise
