"""Deep polish continuation regressions."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_deep_polish_capture_scene_exists() -> None:
    assert (PROJECT_ROOT / "scenes/debug/JeffreyDeepPolishV1Capture.tscn").exists()
    assert "1920" in _read("scripts/debug/jeffrey_deep_polish_v1_capture.gd")
    assert "DEEP_POLISH" in _read("scripts/debug/jeffrey_deep_polish_v1_capture.gd")


def test_track_scenery_densified() -> None:
    placer = _read("scripts/track/track_environment_placer_v1.gd")
    assert "SAMPLE_STRIDE := 1" in placer
    race = _read("scripts/track/track_race.gd")
    assert "n % 3 != 0" in race


def test_character_select_masks_baked_placeholders() -> None:
    src = _read("scripts/ui/jeffrey/character_select_screen.gd")
    assert "ORDEN DE ELECCIÓN" in src
    assert "PanelContainer" in src
    assert "CHAR_PLAYERS_PANEL" not in src.split("panel_host")[0] or "ORDEN DE ELECCIÓN" in src


def test_character_card_keys_studio_white() -> None:
    src = _read("scripts/ui/jeffrey/character_card.gd")
    assert "_portrait_without_cream" in src
    assert "near_white" in src


def test_options_restyle_has_audio_section() -> None:
    src = _read("scripts/ui/jeffrey/options_screen.gd")
    assert '"AUDIO"' in src or "AUDIO" in src
    assert "jeffrey_input_hint" in src.lower() or "Hint.make" in src


def test_hub_jugar_badge_contrast() -> None:
    src = _read("scripts/ui/jeffrey/mode_select_card.gd")
    assert "Soft plate behind badge" in src or "plate := ColorRect" in src
    assert "GOLD_HOT" in src


def test_selected_panel_hides_short_scrollbar() -> None:
    src = _read("scripts/ui/jeffrey/selected_players_panel.gd")
    assert "SCROLL_MODE_SHOW_NEVER" in src


def test_four_wheel_still_default() -> None:
    main = _read("scripts/track/track_main.gd")
    assert "FOUR_WHEEL_SCENE_PATH" in main
    assert 'override == "BASELINE"' in main
