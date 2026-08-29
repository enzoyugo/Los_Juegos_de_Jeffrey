"""Jeffrey full-game canonicalization + Track menu V1 gates."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MENU = ROOT / "assets/ui/track/menu_v1"


def test_track_menu_assets_present() -> None:
    expected = [
        MENU / "backgrounds/track_menu_costanera_bg.png",
        MENU / "header/track_menu_header.png",
        MENU / "players/track_active_players_panel.png",
        MENU / "selectors/track_length_selector.png",
        MENU / "selectors/track_difficulty_selector.png",
        MENU / "buttons/track_start_button.png",
        MENU / "buttons/track_back_button.png",
        MENU / "hints/track_controls_hint.png",
    ]
    for path in expected:
        assert path.is_file(), path


def test_track_menu_script_and_wiring() -> None:
    menu = (ROOT / "scripts/ui/jeffrey/track_menu_screen.gd").read_text(encoding="utf-8")
    assert "start_pressed" in menu
    assert "length_id" in menu
    assert "difficulty_id" in menu
    assert "JUGADORES" in menu or "Players" in menu
    app = (ROOT / "scripts/core/jeffrey/jeffrey_app.gd").read_text(encoding="utf-8")
    assert "TRACK_MENU" in app
    assert "_show_track_menu" in app
    assert "pending_track_length_id" in app
    main = (ROOT / "scripts/track/track_main.gd").read_text(encoding="utf-8")
    assert "_menu_configured" in main
    assert "difficulty_id" in main


def test_no_track_picker() -> None:
    menu = (ROOT / "scripts/ui/jeffrey/track_menu_screen.gd").read_text(encoding="utf-8")
    assert "PISTA" not in menu or "EMPEZAR" in menu
    assert "track_selector" not in menu.lower()


def test_fort_v2_not_production_default() -> None:
    catalog = (ROOT / "scripts/fighters/fighter_catalog.gd").read_text(encoding="utf-8")
    assert "fort_stylized_v2_candidate" not in catalog
    assert "JEFFREY_STYLIZED_BLENDER_V1_INTERIM" in catalog
    visual = (ROOT / "scripts/fighters/jeffrey_stylized_glb_visual.gd").read_text(encoding="utf-8")
    assert "SSK_FORT_V2_CANDIDATE" in visual


def test_canonical_docs() -> None:
    assert (ROOT / "docs/CANONICAL_RUNTIME_AUTHORITY.md").is_file()
    assert (ROOT / "docs/SMASH_ART_MATURITY_INVENTORY.md").is_file()
    assert (ROOT / "docs/JEFFREY_FULL_GAME_CANONICAL_V1_REPORT.md").is_file()
    assert (ROOT / "scenes/debug/JeffreyFullGameCanonicalV1Lab.tscn").is_file()


def test_content_expansion_pipeline_label_compat() -> None:
    ## Keep content expansion test soft-compat if it still mentions old pipeline id.
    text = (ROOT / "scripts/fighters/fighter_catalog.gd").read_text(encoding="utf-8")
    assert "JEFFREY_STYLIZED" in text
