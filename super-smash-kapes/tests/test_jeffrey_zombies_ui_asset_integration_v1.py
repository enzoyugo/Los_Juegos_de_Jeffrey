"""Locks for JEFFREY_ZOMBIES_UI_ASSET_INTEGRATION_V1. Presentation-only."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
ZOMBIES_UI = PROJECT_ROOT / "assets" / "ui" / "zombies"

ASSETS = [
    "backgrounds/zombies_menu_bg.png",
    "backgrounds/zombies_loading_bg.png",
    "branding/zombies_title.png",
    "buttons/btn_play.png",
    "buttons/btn_characters.png",
    "buttons/btn_map.png",
    "buttons/btn_options.png",
    "buttons/btn_back.png",
    "loading/loading_bar.png",
]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_zombies_ui_assets_exist() -> None:
    missing = [rel for rel in ASSETS if not (ZOMBIES_UI / rel).exists()]
    assert missing == [], f"ZOMBIES_UI_ASSET_MISSING {missing}"


def test_zombies_menu_uses_supplied_art_not_labels() -> None:
    menu = _read("scripts/ui/jeffrey/zombies_menu_screen.gd")
    button = _read("scripts/ui/jeffrey/zombies_menu_button.gd")
    assets = _read("scripts/ui/jeffrey/zombies_ui_assets.gd")
    assert "STRETCH_KEEP_ASPECT_COVERED" in menu
    assert "zombies_menu_bg.png" in assets
    assert "zombies_title.png" in assets
    assert "btn_play.png" in assets
    assert "btn_characters.png" in assets
    assert "btn_map.png" in assets
    assert "btn_options.png" in assets
    assert "btn_back.png" in assets
    assert "TextureRect" in menu
    assert 'name = "Title"' in menu or 'title.name = "Title"' in menu
    assert "MenuButtons" in menu
    assert "FocusController" in menu
    assert "grab_focus" in menu
    assert "ui_up" in menu and "ui_down" in menu
    assert "pause_match" in menu
    assert "play_pressed" in menu
    assert "characters_pressed" in menu
    assert "map_pressed" in menu
    assert "options_pressed" in menu
    assert "back_pressed" in menu
    assert "Label" not in button
    assert "KEEP_ASPECT" in button
    assert (PROJECT_ROOT / "scenes/ui/zombies/ZombiesMenu.tscn").exists()


def test_zombies_loading_uses_supplied_art_and_copy() -> None:
    loading = _read("scripts/ui/jeffrey/zombies_loading_screen.gd")
    assets = _read("scripts/ui/jeffrey/zombies_ui_assets.gd")
    assert "zombies_loading_bg.png" in assets
    assert "loading_bar.png" in assets
    assert "CARGANDO..." in assets or "CARGANDO..." in loading
    assert "Llegá al estacionamiento del Shopping del Sol y encontrá la última muestra de la cura." in assets
    assert "STRETCH_KEEP_ASPECT_COVERED" in loading
    assert "LoadingContent" in loading
    assert "LoadingText" in loading
    assert "FlavorText" in loading
    assert "LoadingBar" in loading
    assert (PROJECT_ROOT / "scenes/ui/zombies/ZombiesLoading.tscn").exists()


def test_zombies_menu_is_inserted_without_changing_smash_or_track() -> None:
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    player = _read("scripts/zombies/zombies_player.gd")
    enemy = _read("scripts/zombies/zombies_enemy.gd")
    main = _read("scripts/zombies/zombies_main.gd")
    assert "zombies_menu_screen.gd" in app
    assert "zombies_loading_screen.gd" in app
    assert "_show_zombies_menu" in app
    assert "MODE_ZOMBIES" in app
    assert "_show_mode_players" in app
    assert "_host_smash_resolved" in app
    assert "_host_track" in app
    assert "_host_zombies" in app
    assert "zombies_menu_screen" not in player
    assert "zombies_menu_screen" not in enemy
    assert "zombies_menu_screen" not in main
    assert "zombies_loading_screen" not in player
    assert "zombies_loading_screen" not in enemy


def test_zombies_scene_scripts_point_at_jeffrey_ui() -> None:
    menu_scene = _read("scenes/ui/zombies/ZombiesMenu.tscn")
    loading_scene = _read("scenes/ui/zombies/ZombiesLoading.tscn")
    assert "scripts/ui/jeffrey/zombies_menu_screen.gd" in menu_scene
    assert "scripts/ui/jeffrey/zombies_loading_screen.gd" in loading_scene
