"""Zombies UI asset integration V1. Presentation-only locks. No gameplay retune."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
ASSETS = PROJECT_ROOT / "assets" / "ui" / "zombies"

REQUIRED_ASSETS = [
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
    missing = [rel for rel in REQUIRED_ASSETS if not (ASSETS / rel).exists()]
    assert missing == [], missing


def test_zombies_menu_and_loading_scenes_exist() -> None:
    for rel in (
        "scripts/ui/jeffrey/zombies_ui_assets.gd",
        "scripts/ui/jeffrey/zombies_menu_button.gd",
        "scripts/ui/jeffrey/zombies_menu_screen.gd",
        "scripts/ui/jeffrey/zombies_loading_screen.gd",
        "scenes/ui/zombies/ZombiesMenu.tscn",
        "scenes/ui/zombies/ZombiesLoading.tscn",
    ):
        assert (PROJECT_ROOT / rel).exists(), rel
    tscn_menu = _read("scenes/ui/zombies/ZombiesMenu.tscn")
    tscn_loading = _read("scenes/ui/zombies/ZombiesLoading.tscn")
    assert "zombies_menu_screen.gd" in tscn_menu
    assert "zombies_loading_screen.gd" in tscn_loading
    menu = _read("scripts/ui/jeffrey/zombies_menu_screen.gd")
    loading = _read("scripts/ui/jeffrey/zombies_loading_screen.gd")
    assets = _read("scripts/ui/jeffrey/zombies_ui_assets.gd")
    assert "STRETCH_KEEP_ASPECT_COVERED" in menu
    assert "STRETCH_KEEP_ASPECT_COVERED" in loading
    assert "btn_play.png" in assets
    assert "CARGANDO" in assets
    assert "Llegá al estacionamiento del Shopping del Sol" in assets
    assert "ZAssets.LOADING_COPY" in loading
    assert "ZAssets.FLAVOR" in loading
    assert "grab_focus" in menu
    assert "pause_match" in menu
    assert "ui_up" in menu
    assert "ui_down" in menu
    assert "Label.new()" not in menu or "MapNote" in menu
    assert "zombies_title.png" in assets
    assert "fighter.ko()" not in menu
    assert "invulnerability" not in menu


def test_zombies_menu_is_wired_without_breaking_other_modes() -> None:
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    assert "_show_zombies_menu" in app
    assert "ZOMBIES_MENU" in app
    assert "ZOMBIES_LOADING" in app
    assert "MODE_ZOMBIES" in app
    assert "_show_mode_players()" in app
    assert "_host_smash" in app
    assert "_host_track" in app
    assert "MODE_SMASH" in app
    hub = _read("scripts/ui/jeffrey/hub_screen.gd")
    assert "mode_chosen.emit" in hub


def test_gameplay_scripts_were_not_retuned() -> None:
    player = _read("scripts/zombies/zombies_player.gd")
    enemy = _read("scripts/zombies/zombies_enemy.gd")
    waves = _read("scripts/zombies/zombies_waves.gd")
    smash = _read("scripts/fighters/fighter.gd")
    track = _read("scripts/track/track_wheel_car.gd")
    playground = _read("scripts/core/m0_playground.gd")
    assert "health = maxf(health - amount, 0.0)" in player
    assert "func configure_health" in enemy
    assert "zombies_to_spawn = mini(4 + wave * 2, 16)" in waves
    assert "RESPAWN_DELAY := 1.15" in playground
    assert "position.x < -19.0 or position.x > 19.0" in playground
    assert "REAR_LATERAL_GRIP" in track
    assert "damage_percent" in smash
    menu = _read("scripts/ui/jeffrey/zombies_menu_screen.gd")
    assert "zombies_player.gd" not in menu
    assert "zombies_enemy.gd" not in menu
    assert "track_wheel_car.gd" not in menu
