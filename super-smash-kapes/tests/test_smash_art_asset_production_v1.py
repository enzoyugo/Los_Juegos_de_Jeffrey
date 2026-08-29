"""Smash Art Asset Production V1 — Blender hybrid gates."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

FIGHTERS = ["cartes", "fort", "pajaro_campana"]
STAGES = {
    "palacio": ROOT / "assets/stages/palacio_de_lopez/visual/palacio_visual_v1.glb",
    "costanera": ROOT / "assets/stages/costanera_de_asuncion/visual/costanera_visual_v1.glb",
}


def test_stylized_fighter_glbs_exist() -> None:
    for fid in FIGHTERS:
        path = ROOT / f"assets/fighters/processed/{fid}/{fid}_stylized_v1.glb"
        assert path.is_file(), path
        assert path.stat().st_size > 1024


def test_stage_visual_glbs_exist() -> None:
    for path in STAGES.values():
        assert path.is_file(), path
        assert path.stat().st_size > 1024


def test_catalog_uses_blender_pipeline() -> None:
    text = (ROOT / "scripts/fighters/fighter_catalog.gd").read_text(encoding="utf-8")
    assert "JEFFREY_STYLIZED_BLENDER_V1" in text or "JEFFREY_STYLIZED_BLENDER_V1_INTERIM" in text
    assert "jeffrey_stylized_glb_visual.gd" in text
    for fid in FIGHTERS:
        assert f"{fid}_stylized_v1.glb" in text or "%s_stylized_v1.glb" in text


def test_glb_visual_and_fallback_scripts() -> None:
    glb = ROOT / "scripts/fighters/jeffrey_stylized_glb_visual.gd"
    procedural = ROOT / "scripts/fighters/jeffrey_stylized_fighter_visual.gd"
    assert glb.is_file()
    assert procedural.is_file()
    glb_text = glb.read_text(encoding="utf-8")
    assert "production_glb_path" in glb_text
    assert "_try_load_glb" in glb_text


def test_stage_base_loads_visual_glb() -> None:
    text = (ROOT / "scripts/stages/jeffrey_smash_stage_base.gd").read_text(encoding="utf-8")
    assert "_try_attach_visual_glb" in text
    assert "palacio_visual_v1.glb" in text
    assert "costanera_visual_v1.glb" in text
    assert "_pulse_ko_burst" in text


def test_blender_build_script_exists() -> None:
    path = ROOT / "tools/blender/smash/build_stylized_smash_art_v1.py"
    assert path.is_file()
    text = path.read_text(encoding="utf-8")
    assert "build_fort" in text
    assert "build_cartes" in text
    assert "build_pajaro" in text
    assert "build_palacio_visual" in text
    assert "build_costanera_visual" in text


def test_pipeline_docs() -> None:
    assert (ROOT / "docs/SMASH_ART_ASSET_PRODUCTION_V1_REPORT.md").is_file()
    assert (ROOT / "docs/SMASH_BLENDER_FIGHTER_PIPELINE_V1.md").is_file()
    assert (ROOT / "docs/SMASH_BLENDER_STAGE_PIPELINE_V1.md").is_file()


def test_portraits_regenerated() -> None:
    for fid in FIGHTERS:
        assert (ROOT / f"assets/ui/portraits/{fid}_portrait.png").is_file()
        assert (ROOT / f"assets/ui/victory/{fid}/{fid}_victory.png").is_file()
