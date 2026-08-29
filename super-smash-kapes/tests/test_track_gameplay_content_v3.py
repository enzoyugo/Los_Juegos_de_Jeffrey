"""Track gameplay content V3: boost overspeed, new kit pieces, generator rhythm."""

from __future__ import annotations

import json
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CORE = PROJECT_ROOT / "assets/track/modules/generated/core"

ORIGINAL_11 = (
    "track_start_v1.glb",
    "track_straight_medium_v1.glb",
    "track_curve_l_45_v1.glb",
    "track_curve_r_45_v1.glb",
    "track_finish_v1.glb",
    "track_ramp_small_v1.glb",
    "track_jump_small_v1.glb",
    "track_boost_straight_v1.glb",
    "track_landing_straight_long_v1.glb",
    "track_ramp_takeoff_v1.glb",
    "track_gap_logical_v1.glb",
)
NEW_GLBS = (
    "track_straight_short_v1.glb",
    "track_straight_long_v1.glb",
    "track_curve_l_90_v1.glb",
    "track_curve_r_90_v1.glb",
    "track_chicane_lr_v1.glb",
    "track_chicane_rl_v1.glb",
)
HANDLING_TOKENS = (
    "FRONT_LATERAL_GRIP := 9200.0",
    "SPRING_STRENGTH := 32000.0",
    "YAW_ASSIST_TORQUE := 420.0",
    "ENGINE_FORCE := 6200.0",
    "CENTER_OF_MASS_OFFSET := Vector3(0.0, -0.12, 0.06)",
)


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_v3_files_exist() -> None:
    for rel in (
        "scripts/debug/track_boost_delta_lab.gd",
        "scenes/debug/TrackBoostDeltaLab.tscn",
        "scripts/track/track_boost_feedback.gd",
        "assets/track/materials/track_boost_v1.tres",
        "docs/TRACK_GAMEPLAY_CONTENT_V3_REPORT.md",
        "tests/test_track_gameplay_content_v3.py",
    ):
        assert (PROJECT_ROOT / rel).exists(), rel


def test_boost_overspeed_tokens() -> None:
    config = _read("scripts/track/track_config.gd")
    car = _read("scripts/track/track_car_controller.gd")
    wheel = _read("scripts/track/track_wheel_car.gd")
    assert "BOOST_OVERSPEED := 1.22" in config
    assert "BOOST_DURATION := 0.85" in config
    assert "BOOST_ACCEL_SCALE := 0.85" in config
    assert "MAX_SPEED * Config.BOOST_OVERSPEED" in car
    assert 'print("[TRACK_BOOST] APPLY controller=BASELINE' in car
    assert 'print("[TRACK_BOOST] END")' in car
    assert "BOOST_RETRIGGER_LOCK" in car
    assert "Config.BOOST_DURATION" in wheel
    assert "apply_central_force" in wheel
    assert "ENGINE_FORCE" in wheel


def test_new_kit_glbs_exist() -> None:
    for name in ORIGINAL_11:
        assert (CORE / name).exists(), name
    for name in NEW_GLBS:
        glb = CORE / name
        meta = CORE / name.replace(".glb", ".json")
        assert glb.exists(), name
        assert meta.exists(), meta.name
        payload = json.loads(meta.read_text(encoding="utf-8"))
        assert payload["road_width"] == 11.0
        assert payload["collision"]
        assert payload["entry"]["origin"] == [0.0, 0.0, 0.0]
        assert abs(payload["exit"]["origin"][0]) < 0.05 or payload["piece_id"].startswith("curve")
        if payload["piece_id"].startswith("chicane") or payload["piece_id"].startswith("straight"):
            assert abs(payload["exit"]["yaw"]) < 0.05
            assert abs(payload["exit"]["origin"][0]) < 0.05


def test_showcases_include_v3_vocabulary() -> None:
    data = json.loads(_read("data/track/generator_v2_showcases.json"))
    ids = set()
    for key in ("SHORT_SHOWCASE", "MEDIUM_SHOWCASE", "LONG_SHOWCASE"):
        row = data[key]
        assert bool(row.get("accepted", True)) or int(row.get("piece_count", 0)) > 0
        for pid in row["piece_sequence"]:
            ids.add(pid)
    assert "curve_l_90" in ids or "curve_r_90" in ids
    assert "chicane_lr" in ids or "chicane_rl" in ids
    assert "boost_straight" in ids
    assert "straight_short" in ids
    assert "straight_long" in ids
    assert "start" in ids and "finish" in ids


def test_controller_mode_baseline_and_handling_frozen() -> None:
    config = _read("scripts/track/track_config.gd")
    assert 'CONTROLLER_MODE := "FOUR_WHEEL_V1"' in config
    handling = _read("scripts/track/track_wheel_physics_config.gd")
    for token in HANDLING_TOKENS:
        assert token in handling, token
    assert "SUSPENSION_TRAVEL := 0.14" in handling
    assert "MAX_SUSPENSION_FORCE := 18000.0" in handling


def test_landing_close_camera_cycle() -> None:
    cam = _read("scripts/track/track_extended_debug_camera.gd")
    jump = _read("scripts/track/track_jump_trajectory_lab.gd")
    assert "MODE_LANDING_CLOSE" in cam
    assert "LANDING_CLOSE" in cam
    assert "MODE_LANDING_SIDE" in cam
    assert "MODE_TOPDOWN" in cam
    assert "KEY_K" in jump
    assert "cycle_mode" in jump
    chase = _read("scripts/track/track_camera.gd")
    assert "func boost_punch(" in chase
