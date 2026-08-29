"""Track greybox V1 static locks."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_track_stack_exists() -> None:
    for rel in (
        "scripts/track/track_config.gd",
        "scripts/track/track_car_controller.gd",
        "scripts/track/track_camera.gd",
        "scripts/track/track_generator.gd",
        "scripts/track/track_checkpoint.gd",
        "scripts/track/track_turn_manager.gd",
        "scripts/track/track_fuel_system.gd",
        "scripts/track/track_last_dance.gd",
        "scripts/track/track_ghost_recorder.gd",
        "scripts/track/track_ghost_player.gd",
        "scripts/track/track_hud.gd",
        "scripts/track/track_race.gd",
        "scripts/track/track_main.gd",
        "scenes/track/TrackMain.tscn",
    ):
        assert (PROJECT_ROOT / rel).exists(), rel


def test_track_tuning_and_fuel_formula_are_explicit() -> None:
    config = _read("scripts/track/track_config.gd")
    fuel = _read("scripts/track/track_fuel_system.gd")
    gen = _read("scripts/track/track_generator.gd")
    handling = _read("scripts/track/track_handling.gd")
    car = _read("scripts/track/track_car_controller.gd")
    assert "BASELINE_ACCEL := 48.0" in config
    assert "BASELINE_MAX_SPEED := 36.0" in config
    assert "BASELINE_LATERAL_GRIP := 9.8" in config
    assert "TRACK_HANDLING_V1" in config
    assert "V1_LATERAL_GRIP := 16.5" in config
    assert "TRACK_HANDLING_PRESET := \"v2\"" in config
    assert "LATERAL_GRIP := 18.0" in config
    assert "DRIFT_YAW_MULTIPLIER" in config
    assert "DRIFT_ENTRY_SPEED" in config
    assert "FUEL_MULTIPLIER" in config
    assert "STEER_RESPONSE" in config
    assert "HIGH_SPEED_ACCEL_SCALE" in config
    assert "REVERSE_ENTER_SPEED" in config
    assert "CAM_FOV_MIN" in config
    assert "FUEL_ATTEMPT_MULT := 2.75" in config
    assert "LENGTH_CORTA" in config
    assert "DIFF_DEMENTE" in config
    assert "initial_fuel" in config
    assert "expected_time * TrackConfig.FUEL_ATTEMPT_MULT" in fuel or "FUEL_ATTEMPT_MULT" in fuel
    assert "rng.seed = seed_value" in gen
    assert "estimated_time" in gen
    assert "GENERANDO PISTA" not in gen
    assert "damp_lateral" in handling
    assert "steer_authority" in handling
    assert "brake_or_reverse_delta" in handling
    assert "damp_lateral" in car
    assert "VELOCITY_ALIGN" in car
    assert "slip_amount" in car
    assert (PROJECT_ROOT / "scenes/debug/TrackPhysicsLab.tscn").exists()
    assert (PROJECT_ROOT / "scripts/track/track_physics_lab.gd").exists()


def test_track_last_dance_and_turns_are_generic() -> None:
    turns = _read("scripts/track/track_turn_manager.gd")
    last = _read("scripts/track/track_last_dance.gd")
    main = _read("scripts/track/track_main.gd")
    assert "last_dance" in turns
    assert "alive" in turns
    assert "eliminated" in turns
    assert "current_index" in turns
    assert "participants.size()" in turns or "alive" in turns
    assert "STATE_ACTIVE" in last
    assert "track_reset" in main
    assert "surrender" in main
    assert "Ghost" in main or "ghost" in main


def test_track_is_wired_through_the_shell() -> None:
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    registry = _read("scripts/core/jeffrey/game_mode_registry.gd")
    assert "TrackMain.tscn" in app
    assert "_host_track" in app
    assert "MODE_RACING" in app
    assert 'RACING_SCENE := "res://scenes/track/TrackMain.tscn"' in registry
    assert "HotseatComingSoon.tscn" in registry
    assert (PROJECT_ROOT / "scenes/modes/racing/HotseatComingSoon.tscn").exists()
    assert "begin_hosted_match" in app
