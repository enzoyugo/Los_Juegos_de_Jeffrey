"""Static locks for the Los Juegos de Jeffrey multimode shell.

Gameplay numbers and Smash authorities must remain identical to the
pre-migration baseline. This file does not simulate physics.
"""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_boot_and_autoload_are_jeffrey_shell() -> None:
    project = _read("project.godot")
    assert 'config/name="Los Juegos de Jeffrey"' in project
    assert 'run/main_scene="res://scenes/core/JeffreyBoot.tscn"' in project
    assert 'JeffreyCore="*res://scripts/core/jeffrey/jeffrey_core.gd"' in project
    assert (PROJECT_ROOT / "scenes/core/JeffreyBoot.tscn").exists()
    assert (PROJECT_ROOT / "scenes/core/Main.tscn").exists()
    assert (PROJECT_ROOT / "scenes/core/M0Playground.tscn").exists()


def test_smash_gameplay_authorities_were_not_rewritten() -> None:
    fighter = _read("scripts/fighters/fighter.gd")
    stats = _read("scripts/fighters/fighter_stats.gd")
    playground = _read("scripts/core/m0_playground.gd")
    attack = _read("data/attacks/basic_attack.tres")
    assert "walk_speed: float = 10.0" in stats
    assert "jump_velocity: float = 16.0" in stats
    assert "starting_stocks: int = 3" in stats
    assert "gravity: float = 42.0" in stats
    assert "startup_seconds = 0.1" in attack
    assert "damage = 8.0" in attack
    assert "base_knockback = 7.0" in attack
    assert "RESPAWN_DELAY := 1.15" in playground
    assert "Vector3(-4.0, 1.7, 0.0)" in playground
    assert "Vector3(4.0, 1.7, 0.0)" in playground
    assert "position.x < -19.0 or position.x > 19.0" in playground
    assert "invulnerability_time = 1.5" in fighter
    assert 'return "p%d_%s" % [player_id, name]' in fighter
    assert "JeffreyCore" not in fighter
    assert "JeffreyCore" not in playground


def test_character_and_mode_registries_cover_v1_roster() -> None:
    characters = _read("scripts/core/jeffrey/character_registry.gd")
    modes = _read("scripts/core/jeffrey/game_mode_registry.gd")
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert "_definitions[\"terere\"]" in catalog
    assert "_definitions[\"jaguarete\"]" in catalog
    assert "register_builtin" in characters
    assert 'MODE_SMASH := "smash"' in modes
    assert 'MODE_RACING := "racing"' in modes
    assert 'MODE_ZOMBIES := "zombies"' in modes
    assert 'display_name: "Smash Kapes"' in modes or '"Smash Kapes"' in modes
    assert "max_players" in modes
    assert (PROJECT_ROOT / "scenes/modes/racing/HotseatComingSoon.tscn").exists()
    assert (PROJECT_ROOT / "scenes/modes/zombies/ZombiesComingSoon.tscn").exists()


def test_profiles_are_not_characters() -> None:
    profile = _read("scripts/core/jeffrey/player_profile.gd")
    match_setup = _read("scripts/core/match_setup.gd")
    assert "display_name" in profile
    assert "smash_stats" in profile
    assert "racing_stats" in profile
    assert "zombies_stats" in profile
    assert "player_1_profile_id" in match_setup
    assert "Never used as fighter identity" in match_setup
    session = _read("scripts/core/jeffrey/active_session.gd")
    assert "active_player_ids" in session
    assert "remove_player" in session


def test_persistence_is_versioned_and_atomic() -> None:
    persist = _read("scripts/core/jeffrey/jeffrey_persistence.gd")
    assert "SAVE_VERSION := 1" in persist
    assert "save.json.tmp" in persist
    assert "save.corrupt" in persist


def test_smash_adapter_keeps_main_host() -> None:
    main = _read("scripts/core/main.gd")
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    assert "hosted_by_shell" in main
    assert "begin_character_select" in main
    assert "begin_hosted_match" in main
    assert "smash_session_exited" in main
    assert "MAIN_SCENE" in app
    assert "begin_character_select" in app
    assert "begin_hosted_match" in app


def test_keyboard_contract_unchanged() -> None:
    project = _read("project.godot")
    for action in (
        "p1_left",
        "p1_right",
        "p1_jump",
        "p1_down",
        "p1_attack",
        "p2_left",
        "p2_right",
        "p2_jump",
        "p2_down",
        "p2_attack",
        "restart_match",
        "pause_match",
    ):
        assert f"{action}=" in project
    assert '"physical_keycode":65' in project
    assert '"physical_keycode":70' in project
    assert '"physical_keycode":78' in project
