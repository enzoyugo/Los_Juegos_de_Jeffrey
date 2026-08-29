"""Smash Content Expansion V1 gates."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

NEW_FIGHTERS = ["cartes", "fort", "pajaro_campana"]
NEW_STAGES = ["palacio", "costanera"]


def test_new_fighter_portraits_and_victory() -> None:
    for fid in NEW_FIGHTERS:
        assert (ROOT / f"assets/ui/portraits/{fid}_portrait.png").is_file()
        assert (ROOT / f"assets/ui/victory/{fid}/{fid}_victory.png").is_file()


def test_fighter_catalog_registers_new_ids() -> None:
    text = (ROOT / "scripts/fighters/fighter_catalog.gd").read_text(encoding="utf-8")
    for fid in NEW_FIGHTERS:
        assert fid in text
    assert "gameplay_profile" in text
    assert "JEFFREY_STYLIZED_BLENDER_V1" in text or "JEFFREY_STYLIZED_V1" in text
    assert "jeffrey_stylized" in text


def test_stylized_visual_script_exists() -> None:
    path = ROOT / "scripts/fighters/jeffrey_stylized_fighter_visual.gd"
    assert path.is_file()
    text = path.read_text(encoding="utf-8")
    assert "_build_cartes" in text
    assert "_build_fort" in text
    assert "_build_pajaro" in text


def test_stage_catalog_and_scenes() -> None:
    catalog = (ROOT / "scripts/stages/stage_catalog.gd").read_text(encoding="utf-8")
    assert "PALACIO" in catalog
    assert "COSTANERA" in catalog
    assert (ROOT / "scenes/stages/PalacioDeLopezStage.tscn").is_file()
    assert (ROOT / "scenes/stages/CostaneraDeAsuncionStage.tscn").is_file()
    assert (ROOT / "scripts/stages/palacio_stage.gd").is_file()
    assert (ROOT / "scripts/stages/costanera_stage.gd").is_file()


def test_match_setup_has_stage_id() -> None:
    text = (ROOT / "scripts/core/match_setup.gd").read_text(encoding="utf-8")
    assert "stage_id" in text
    playground = (ROOT / "scripts/core/m0_playground.gd").read_text(encoding="utf-8")
    assert "StageCatalog" in playground
    assert "_make_attack" in playground
    assert "blast_min" in playground


def test_character_select_stage_hooks() -> None:
    jeffrey = (ROOT / "scripts/ui/jeffrey/character_select_screen.gd").read_text(encoding="utf-8")
    assert "selected_stage_id" in jeffrey
    assert "_build_stage_row" in jeffrey
    kapes = (ROOT / "scripts/ui/kapes_character_select.gd").read_text(encoding="utf-8")
    assert "_selected_stage_id" in kapes
    assert "stage_id" in kapes


def test_pipeline_docs() -> None:
    assert (ROOT / "docs/SMASH_FIGHTER_PIPELINE_V1.md").is_file()
    assert (ROOT / "docs/SMASH_STAGE_PIPELINE_V1.md").is_file()
