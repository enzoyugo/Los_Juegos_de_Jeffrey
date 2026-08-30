"""Regression locks for the party gameplay-polish telemetry and flow guards."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_track_runtime_snapshot_covers_progression_and_four_wheel_authority() -> None:
    main = _read("scripts/track/track_main.gd")
    car = _read("scripts/track/track_wheel_car.gd")
    for key in (
        '"checkpoint_index"',
        '"checkpoint_total"',
        '"elapsed"',
        '"reset_count"',
        '"length_id"',
        '"difficulty_id"',
        '"car_telemetry"',
    ):
        assert key in main
    for key in ("debug_speed", "debug_grounded_n", "debug_steer", "debug_slip_angle", "drift_state"):
        assert key in car
    assert "if index != _next_check" in main
    assert "func _reset_checkpoint" in main


def test_track_lengths_and_difficulties_are_behaviorally_distinct() -> None:
    config = _read("scripts/track/track_config.gd")
    generator = _read("scripts/track/track_generator.gd")
    generator_v2 = _read("scripts/track/track_generator_v2.gd")
    assert "LENGTH_CORTA: 10" in config
    assert "LENGTH_MEDIA: 16" in config
    assert "LENGTH_LARGA: 24" in config
    assert "if difficulty == Config.DIFF_TRANQUI" in generator
    assert "if difficulty == Config.DIFF_DEMENTE" in generator
    assert "normalize_difficulty" in generator_v2
    assert "DIFF_TIME_MULT" in config
    assert "difficulty_id" in generator


def test_smash_ko_respawn_snapshot_and_idempotent_ko_path() -> None:
    fighter = _read("scripts/fighters/fighter.gd")
    playground = _read("scripts/core/m0_playground.gd")
    assert "if state == FighterState.DEAD:" in fighter
    assert "fighter_ko.emit(self)" in fighter
    for key in ("ko_events", "respawn_events", "last_ko_player", "last_hit_knockback"):
        assert key in playground
    assert "if fighter.stocks <= 0" in playground
    assert "respawn_timers[fighter.player_id] = RESPAWN_DELAY" in playground


def test_zombies_pause_guard_and_wave_telemetry_preserve_pacing_observability() -> None:
    main = _read("scripts/zombies/zombies_main.gd")
    waves = _read("scripts/zombies/zombies_waves.gd")
    assert "if _paused or get_tree().paused:" in main
    assert "_start_wave()" in main and "_tick_spawns(delta)" in main
    for key in ("wave_elapsed", "time_to_first_contact", "average_active_zombies"):
        assert f'"{key}"' in main
    assert "SPAWN_INTERVAL" in main
    assert "func next_count" in waves and "func zombie_health" in waves


def test_shared_party_input_and_return_paths_are_explicit() -> None:
    track = _read("scripts/track/track_config.gd")
    zombies = _read("scripts/zombies/zombies_config.gd")
    main = _read("scripts/core/main.gd")
    assert "KEY_W" in track and "KEY_UP" in track
    assert "KEY_BACKSPACE" in track and "KEY_SHIFT" in track
    assert "pause_match" in track or "ensure_actions" in track
    assert "KEY_E" in zombies and "KEY_G" in zombies
    assert "restart_requested.connect(_restart_match)" in main
    assert "rematch_pressed.connect(_start_match)" in main
