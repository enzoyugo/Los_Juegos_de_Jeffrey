"""Track 4-wheel physics R&D V1: parallel controller, not canonical."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_source_glb_untouched_and_articulated_exists() -> None:
    source = PROJECT_ROOT / "assets/vehicles/track/source/track_car_base_v1.glb"
    processed = PROJECT_ROOT / "assets/vehicles/track/processed/track_car_base_v2_articulated.glb"
    assert source.exists()
    assert processed.exists()
    assert source.stat().st_size == 4_269_248
    assert processed.stat().st_size > 1_000_000
    assert processed.resolve() != source.resolve()


def test_baseline_controller_remains_canonical() -> None:
    config = _read("scripts/track/track_config.gd")
    main = _read("scripts/track/track_main.gd")
    car = _read("scripts/track/track_car_controller.gd")
    scene = _read("scenes/track/TrackCar.tscn")
    assert 'CONTROLLER_MODE := "BASELINE"' in config
    assert "CONTROLLER_FOUR_WHEEL_V1" in config
    assert "BASELINE_TRACK_CONTROLLER" in car
    assert "class_name TrackCarController" in car
    assert "CharacterBody3D" in scene
    assert "res://scripts/track/track_car_controller.gd" in scene
    assert "res://scenes/track/TrackCar.tscn" in main
    assert "CarScene.instantiate()" in main
    assert "SSK_TRACK_CONTROLLER" in main


def test_four_wheel_parallel_architecture() -> None:
    car = _read("scripts/track/track_wheel_car.gd")
    wheel = _read("scripts/track/track_arcade_wheel.gd")
    cfg = _read("scripts/track/track_wheel_physics_config.gd")
    scene = _read("scenes/track/TrackCarWheelPhysics.tscn")
    ghost = _read("scripts/track/track_ghost_player.gd")
    assert "FOUR_WHEEL_TRACK_CONTROLLER_V1" in cfg
    assert "extends RigidBody3D" in car
    assert "VehicleBody3D" not in car
    assert "extends Node3D" in wheel
    assert "RigidBody3D" not in wheel.split("extends", 1)[1][:40]
    assert "WheelPhysicsFL" in scene
    assert "WheelPhysicsFR" in scene
    assert "WheelPhysicsRL" in scene
    assert "WheelPhysicsRR" in scene
    assert scene.count("type=\"RigidBody3D\"") == 1
    assert "apply_force" in wheel
    assert "steer_angle" in wheel
    assert "DRIVE_AWD" in cfg
    assert "DRIFT_REAR_GRIP" in cfg
    assert "YAW_ASSIST_TORQUE" in cfg
    assert "FRONT_ANTIROLL" in cfg
    assert "TrackArcadeWheel" not in ghost
    assert "TrackWheelCar" not in ghost
    assert "track_accel" in car
    assert "track_drift" in car
    assert "track_left" in car


def test_tire_and_drift_logic_is_selective() -> None:
    cfg = _read("scripts/track/track_wheel_physics_config.gd")
    wheel = _read("scripts/track/track_arcade_wheel.gd")
    car = _read("scripts/track/track_wheel_car.gd")
    assert "lateral_tire_force" in cfg
    assert "if lateral_speed > 0.0:" in cfg
    assert "return -mag" in cfg
    assert "brake_or_reverse_force" in cfg
    assert "if forward_speed > reverse_enter:" in cfg
    assert "is_driven" in cfg and "DRIVE_FWD" in cfg
    assert "if not _ray.is_colliding():" in wheel
    assert "MIN_GROUND_NORMAL_Y" in wheel
    assert "drift_grip_multiplier" in car
    assert "FRONT_LATERAL_GRIP" in car
    assert "DRIFT_REAR_GRIP" in car
    assert "is_countersteer" in car
    assert "STATE_DRIFT_RECOVERY" in car
    assert "STATE_AIRBORNE" in car
    assert "rotate_y(" not in car


def test_lab_ab_and_inputs_match() -> None:
    lab = _read("scripts/track/track_wheel_physics_lab.gd")
    config = _read("scripts/track/track_config.gd")
    ingest = _read("scripts/track/track_car_ingest_lab.gd")
    visual = _read("scripts/track/track_car_visual.gd")
    vis_cfg = _read("scripts/track/track_car_visual_config.gd")
    assert (PROJECT_ROOT / "scenes/debug/TrackWheelPhysicsLab.tscn").exists()
    assert "F5" in lab or "KEY_F5" in lab
    assert "MODE_BASELINE" in lab
    assert "MODE_FOUR_WHEEL" in lab
    assert "A STRAIGHT" in lab
    assert "B SLALOM" in lab
    assert "C SWEEPER" in lab or "C FAST" in lab
    assert "D HAIRPIN" in lab
    assert "E DRIFT" in lab
    assert "F BUMPS" in lab
    assert "G JUMP" in lab
    assert "H RAILS" in lab or "H GUARDRAIL" in lab
    assert "ROAD_WIDTH" in lab
    assert 'KEY_SHIFT' in config
    assert "track_drift" in config
    assert "KEY_3" in ingest
    assert "use_articulated" in visual
    assert "apply_wheel_states" in visual
    assert "_shared_atlas" in visual
    assert "src.duplicate()" not in visual
    assert 'WHEEL_STRUCTURE := "FUSED_BODY_MESH"' in vis_cfg
    assert "PROCESSED_ARTICULATED_GLB" in vis_cfg
    assert (PROJECT_ROOT / "docs/TRACK_4WHEEL_PHYSICS_RND_V1_REPORT.md").exists()
    assert (PROJECT_ROOT / "docs/TRACK_CAR_ARTICULATED_V2_REPORT.md").exists()
