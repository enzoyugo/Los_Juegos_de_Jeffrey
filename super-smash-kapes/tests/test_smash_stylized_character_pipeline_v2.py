"""Smash Stylized Character Pipeline V2 gates (candidate-only)."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HUMANOID = ROOT / "tools/blender/smash/humanoid_v2"
FORT_DIR = ROOT / "assets/fighters/processed/fort"


def test_v1_frozen() -> None:
    v1 = FORT_DIR / "fort_stylized_v1.glb"
    assert v1.is_file()
    assert v1.stat().st_size > 1024


def test_v2_candidate_assets_exist() -> None:
    glb = FORT_DIR / "fort_stylized_v2_candidate.glb"
    assert glb.is_file()
    assert glb.stat().st_size > 1024
    # Must not overwrite V1
    assert glb.name != "fort_stylized_v1.glb"
    blend = ROOT / "assets/fighters/sources/fort/fort_stylized_v2_candidate.blend"
    assert blend.is_file()


def test_humanoid_v2_modules() -> None:
    for name in [
        "bpy_scene.py",
        "materials_v2.py",
        "stylized_humanoid_base.py",
        "fort_v2.py",
        "portrait_scene_v2.py",
        "rig_v2.py",
        "validation_v2.py",
        "build_fort_v2_candidate.py",
    ]:
        assert (HUMANOID / name).is_file(), name


def test_production_catalog_still_points_at_v1() -> None:
    text = (ROOT / "scripts/fighters/fighter_catalog.gd").read_text(encoding="utf-8")
    assert "fort_stylized_v1.glb" in text or "%s_stylized_v1.glb" in text
    assert "fort_stylized_v2_candidate.glb" not in text


def test_candidate_debug_path_exists() -> None:
    visual = (ROOT / "scripts/fighters/jeffrey_stylized_glb_visual.gd").read_text(encoding="utf-8")
    assert "SSK_FORT_V2_CANDIDATE" in visual
    assert "fort_stylized_v2_candidate.glb" in visual
    assert (ROOT / "scenes/debug/SmashFortV2CandidateLab.tscn").is_file()


def test_report_exists() -> None:
    assert (ROOT / "docs/SMASH_STYLIZED_CHARACTER_PIPELINE_V2_REPORT.md").is_file()


def test_pajaro_and_cartes_v1_untouched_as_candidates() -> None:
    ## V2 must not mass-produce Cartes/Pájaro candidates in this sprint.
    assert not (ROOT / "assets/fighters/processed/cartes/cartes_stylized_v2_candidate.glb").exists()
    assert not (ROOT / "assets/fighters/processed/pajaro_campana/pajaro_campana_stylized_v2_candidate.glb").exists()
