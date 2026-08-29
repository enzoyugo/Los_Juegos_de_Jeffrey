"""Zombies parking + Shopping shell V3 static locks."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_parking_files_exist() -> None:
    for rel in (
        "scripts/zombies/zombies_parking.gd",
        "scripts/zombies/zombies_shopping_shell.gd",
        "scripts/zombies/zombies_audio.gd",
        "scenes/debug/ShoppingZombiesIntegrationLab.tscn",
        "data/zombies/audio/pistol.wav",
        "data/zombies/audio/shopping_open.wav",
        "assets/environments/shopping_del_sol/processed/psx_industrial_pack.glb",
        "docs/SHOPPING_RAW_ASSET_INVENTORY_V1.md",
    ):
        assert (PROJECT_ROOT / rel).exists(), rel


def test_level_starts_outside() -> None:
    map_src = _read("scripts/zombies/zombies_map.gd")
    config = _read("scripts/zombies/zombies_config.gd")
    main = _read("scripts/zombies/zombies_main.gd")
    assert "player_spawn: Vector3 = Vector3(0, 0.05, 28.5)" in map_src
    assert "parking_spawns" in map_src
    assert "shopping_open" in map_src
    assert "MAIN_ENTRANCE_COST := 1500" in config
    assert "ABRIR" in _read("scripts/zombies/zombies_buyable_door.gd")
    assert "spawn_points_for" in main
    assert "TERERÉ MARKET" in map_src
    assert "shopping_del_sol_exterior_v01.glb" in _read("scripts/zombies/zombies_shopping_shell.gd")


def test_audio_and_combat_polish() -> None:
    audio = _read("scripts/zombies/zombies_audio.gd")
    enemy = _read("scripts/zombies/zombies_enemy.gd")
    hud = _read("scripts/zombies/zombies_hud.gd")
    view = _read("scripts/zombies/zombies_viewmodel.gd")
    assert "play(" in audio
    assert "pistol" in audio
    assert "WINDUP" in enemy
    assert "attack_started" in enemy
    assert "_slot_jitter" in enemy
    assert "_vignette_pulse = 0.16" in hud
    assert "magazine" in view.lower() or "0.022" in view or "Mag" in view
