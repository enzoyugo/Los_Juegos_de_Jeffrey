"""Track 4WHEEL structural dynamics V4: stationary creep + clean landing deck."""

import json
import math
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CORE = PROJECT_ROOT / "assets/track/modules/generated/core"


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_stationary_lab_and_low_speed_params_exist() -> None:
    assert (PROJECT_ROOT / "scenes/debug/Track4WheelStationaryStabilityLab.tscn").exists()
    lab = _read("scripts/debug/track_4wheel_stationary_stability_lab.gd")
    assert "FixedWorldCam" in lab
    assert "lateral_displacement" in lab
    assert "TRACK_STATIONARY" in lab
    cfg = _read("scripts/track/track_wheel_physics_config.gd")
    assert "LOW_SPEED_STABILITY_BEGIN_MPS" in cfg
    assert "LOW_SPEED_STABILITY_FULL_MPS" in cfg
    assert "LOW_SPEED_LATERAL_DAMP" in cfg
    assert "REST_ENTER_SPEED" in cfg
    assert "REST_EXIT_INPUT" in cfg
    assert "lateral_tire_force_slip" in cfg
    assert "FRONT_LATERAL_GRIP := 9200.0" in cfg
    assert "SPRING_STRENGTH := 32000.0" in cfg
    assert "YAW_ASSIST_TORQUE := 420.0" in cfg
    assert "ENGINE_FORCE := 6200.0" in cfg
    car = _read("scripts/track/track_wheel_car.gd")
    assert "PhysicsServer3D.body_set_state" in car
    assert "[TRACK_RESET]" in car
    assert "reset_generation_id" in car
    assert "_apply_rest_stabilization" in car
    assert "NO_VALID_CONTACT" in car
    assert "if want_air and not _was_airborne" in car
    assert "can_sleep = false" in car
    assert "freeze = true" not in car
    baseline = _read("scripts/track/track_car_controller.gd")
    assert "REST_ENTER_SPEED" not in baseline
    assert "LOW_SPEED_LATERAL_DAMP" not in baseline
    assert "_apply_rest_stabilization" not in baseline


def _slip_curve(slip: float) -> float:
    deg = abs(math.degrees(slip))
    if deg <= 2.0:
        return 0.6 * (deg / 2.0)
    if deg <= 5.0:
        return 0.6 + 0.4 * ((deg - 2.0) / 3.0)
    if deg <= 10.0:
        return 1.0 + (0.9 - 1.0) * ((deg - 5.0) / 5.0)
    if deg <= 20.0:
        return 0.9 + (0.65 - 0.9) * ((deg - 10.0) / 10.0)
    if deg <= 30.0:
        return 0.65 + (0.45 - 0.65) * ((deg - 20.0) / 10.0)
    return 0.45


def _slip_force(lat: float, fwd: float, load: float, grip: float) -> float:
    if load <= 1.0:
        return 0.0
    slip = math.atan2(lat, max(abs(fwd), 1.0))
    mag = _slip_curve(slip) * grip * min(1.65, max(0.15, load / 1100.0))
    if lat > 0:
        return -mag
    if lat < 0:
        return mag
    return 0.0


def test_high_speed_tire_blend_matches_slip_only() -> None:
    assert abs(_slip_force(8.0, 10.0, 1100.0, 9200.0) + 4140.0) < 0.5
    assert abs(_slip_force(8.0, 20.0, 1100.0, 9200.0) + 5648.54) < 0.5
    assert abs(_slip_force(8.0, 30.0, 1100.0, 9200.0) + 7145.77) < 1.0
    assert _slip_force(8.0, 20.0, 0.0, 9200.0) == 0.0
    cfg = _read("scripts/track/track_wheel_physics_config.gd")
    assert "if planar >= LOW_SPEED_STABILITY_FULL_MPS:" in cfg
    assert "LOW_SPEED_STABILITY_FULL_MPS := 2.40" in cfg
    assert "LOW_SPEED_STABILITY_BEGIN_MPS := 0.45" in cfg


def test_jump_fail_categories_and_reset_contract() -> None:
    ext = _read("scripts/track/track_4wheel_extended_physics_lab.gd")
    for token in (
        "MISSED_LANDING_LEFT",
        "MISSED_LANDING_RIGHT",
        "UNDERSHOT",
        "OVERSHOT",
        "OFFTRACK_AFTER_CONTACT",
        "RESET_DURING_JUMP",
        "NO_VALID_CONTACT",
        "landing_straight_long",
        "first_contact_wheel_count",
        "LANDING_TARGET_ZONE",
    ):
        assert token in ext
    car = _read("scripts/track/track_wheel_car.gd")
    assert "BODY_STATE_LINEAR_VELOCITY" in car
    assert "drift_state = STATE_GRIP" in car
    assert "_was_airborne = false" in car
    assert "[TRACK_RESET]" in car
    jump = json.loads((CORE / "track_jump_small_v1.json").read_text(encoding="utf-8"))
    assert jump["has_gap"] is True
    assert jump["left_guardrail"] is False
    assert not any(item.get("kind") == "rail" for item in jump["collision"])
    meta = json.loads((CORE / "track_landing_straight_long_v1.json").read_text(encoding="utf-8"))
    assert meta["exit"]["pitch"] == 0.0
    assert any(item.get("kind") == "rail" for item in meta["collision"])
    assert abs(meta["collision"][0]["origin"][1] + 0.06) < 0.001


def test_iteration_01_harness_detected_creep() -> None:
    path = PROJECT_ROOT / "docs/generated/track_4wheel_v4_iterations/iteration_01/stationary_stability.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    assert payload.get("overall_rest_pass") is False
    yaw0 = next(c for c in payload["cases"] if c["id"] == "yaw0_rest")
    assert yaw0["lateral_displacement"] > 0.02
    assert yaw0["PASS"] is False
    jump = json.loads(
        (PROJECT_ROOT / "docs/generated/track_4wheel_v4_iterations/iteration_01/jump_run.json").read_text(
            encoding="utf-8"
        )
    )
    assert jump["has_landing_straight_long"] is False
    assert jump["PASS"] is False


def test_clean_jump_route_has_long_deck_before_curves() -> None:
    ext = _read("scripts/track/track_4wheel_extended_physics_lab.gd")
    assert "landing_straight_long" in ext
    jump = ext.index('"jump_small"')
    land = ext.index('"landing_straight_long"')
    curve = ext.index('"curve_l_45"')
    assert jump < land < curve
    assert "LANDING_TARGET_ZONE" in ext
    assert "FIRST_CONTACT" in ext
    assert "SETTLED" in ext
    glb = CORE / "track_landing_straight_long_v1.glb"
    meta_path = CORE / "track_landing_straight_long_v1.json"
    assert glb.exists()
    assert meta_path.exists()
    payload = json.loads(meta_path.read_text(encoding="utf-8"))
    assert payload["piece_id"] == "landing_straight_long"
    assert abs(payload["centerline_length"] - 36.0) < 0.01
    assert abs(payload["exit"]["origin"][2] + 36.0) < 0.01
    assert payload["exit"]["pitch"] == 0.0
    assert payload["road_width"] == 11.0


def test_v3_asset_not_rebuilt() -> None:
    vis = _read("scripts/track/track_car_visual_config.gd")
    assert "track_car_base_v3_articulated_clean.glb" in vis
    source = PROJECT_ROOT / "assets/vehicles/track/source/track_car_base_v1.glb"
    assert source.stat().st_size == 4_269_248


def test_baseline_untouched() -> None:
    cfg = _read("scripts/track/track_config.gd")
    assert 'CONTROLLER_MODE := "FOUR_WHEEL_V1"' in cfg
    main = _read("scripts/track/track_main.gd")
    assert "TrackCar.tscn" in main
    cam = _read("scripts/track/track_extended_debug_camera.gd")
    assert "landing_anchor" in cam
    assert "auto_side_on_takeoff" in cam
    assert "Does not replace TrackMain" in cam
