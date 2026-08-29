"""Zombies greybox V1 static locks (updated for vertical slice)."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_zombies_stack_exists() -> None:
    for rel in (
        "scripts/zombies/zombies_config.gd",
        "scripts/zombies/zombies_player.gd",
        "scripts/zombies/zombies_weapon.gd",
        "scripts/zombies/zombies_enemy.gd",
        "scripts/zombies/zombies_waves.gd",
        "scripts/zombies/zombies_hud.gd",
        "scripts/zombies/zombies_main.gd",
        "scenes/zombies/ZombiesMain.tscn",
    ):
        assert (PROJECT_ROOT / rel).exists(), rel


def test_zombies_greybox_is_honest() -> None:
    player = _read("scripts/zombies/zombies_player.gd")
    waves = _read("scripts/zombies/zombies_waves.gd")
    main = _read("scripts/zombies/zombies_main.gd")
    hud = _read("scripts/zombies/zombies_hud.gd")
    assert "MOUSE_MODE_CAPTURED" in player
    assert "intersect_ray" in player
    assert "next_count" in waves
    assert "NIVEL 27" not in main
    assert "session_exited" in main
    assert "MUNICIÓN INFINITA" not in hud
    assert "setup" in main


def test_zombies_is_wired_as_development_greybox() -> None:
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    registry = _read("scripts/core/jeffrey/game_mode_registry.gd")
    assert "ZombiesMain.tscn" in app
    assert "_host_zombies" in app
    assert "MODE_ZOMBIES" in app
    assert 'ZOMBIES_SCENE := "res://scenes/zombies/ZombiesMain.tscn"' in registry
    assert "ZombiesComingSoon.tscn" in registry
    assert "AVAIL_DEVELOPMENT" in registry
    assert (PROJECT_ROOT / "scenes/modes/zombies/ZombiesComingSoon.tscn").exists()
