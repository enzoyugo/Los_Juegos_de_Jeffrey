"""Track jump trajectory + landing capture V6. Does not retune handling."""

from __future__ import annotations

import json
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CORE = PROJECT_ROOT / "assets/track/modules/generated/core"
GEN = PROJECT_ROOT / "docs/generated/track_jump_v6"


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_handling_still_frozen() -> None:
    cfg = _read("scripts/track/track_wheel_physics_config.gd")
    assert "FRONT_LATERAL_GRIP := 9200.0" in cfg
    assert "YAW_ASSIST_TORQUE := 420.0" in cfg
    assert "ENGINE_FORCE := 6200.0" in cfg
    assert "SPRING_STRENGTH := 32000.0" in cfg
    assert "CENTER_OF_MASS_OFFSET := Vector3(0.0, -0.12, 0.06)" in cfg
    assert 'CONTROLLER_MODE := "FOUR_WHEEL_V1"' in _read("scripts/track/track_config.gd")


def test_v6_lab_and_gates_exist() -> None:
    assert (PROJECT_ROOT / "scenes/debug/TrackJumpTrajectoryLandingLab.tscn").exists()
    lab = _read("scripts/track/track_jump_trajectory_lab.gd")
    for token in (
        "TRACK_TAKEOFF_LATERAL_STATE",
        "TRACK_TAKEOFF_YAW_STATE",
        "TRACK_BALLISTIC_PREDICTION",
        "TRACK_LANDING_CAPTURE_MARGIN",
        "TRACK_APPROACH_FORCE_BALANCE",
        "TRACK_RAMP_NORMAL_SYMMETRY",
        "TRACK_NOMINAL_3X_SETTLE",
        "FAIL_RAIL_CONTACT",
        "PASS_SETTLED",
        "v6_audit_enabled",
        "SSK_V6_STEER",
        "SSK_LANDING_EXTRA_M",
        "V6 HUMAN REVIEW",
        "NOT V6 HUMAN REVIEW CONFIG",
        '_is_human_review_config',
    ):
        assert token in lab
    car = _read("scripts/track/track_wheel_car.gd")
    assert "apply_central_force" in car
    assert "v6_boost_torque_y_integral" in car
    assert "v6_symmetrize_physics_mounts" in car
    wheel = _read("scripts/track/track_arcade_wheel.gd")
    assert "contact_kind" in wheel
    assert "last_world_lat" in wheel


def test_v6_human_review_defaults() -> None:
    lab = _read("scripts/track/track_jump_trajectory_lab.gd")
    assert '_steer_mode: String = "zero"' in lab
    assert "_gap_length: float = 30.0" in lab
    assert "_landing_extra: float = 24.0" in lab
    assert "_sym_mounts: bool = true" in lab
    assert "V6 HUMAN REVIEW" in lab
    assert "NOT V6 HUMAN REVIEW CONFIG" in lab
    assert "_is_human_review_config" in lab
    ready = lab.split("func _ready")[1].split("func ")[0]
    assert '_steer_mode = "v5"' not in ready
    assert "_gap_length = 10.0" not in ready
    assert '_steer_mode = "zero"' in ready
    assert "_gap_length = 30.0" in ready
    assert "_landing_extra = 24.0" in ready


def test_v5_gap_contract_not_reopened() -> None:
    gap = json.loads((CORE / "track_gap_logical_v1.json").read_text(encoding="utf-8"))
    assert gap["collision"] == []
    ramp = json.loads((CORE / "track_ramp_takeoff_v1.json").read_text(encoding="utf-8"))
    lip_end = abs(ramp["exit"]["origin"][2])
    assert abs(lip_end - 13.2) < 0.05
    assert not any(item.get("kind") == "rail" for item in ramp["collision"])


def test_iteration_01_reproduces_if_present() -> None:
    path = GEN / "iteration_01" / "audit.json"
    if not path.exists():
        return
    audit = json.loads(path.read_text(encoding="utf-8"))
    if audit.get("steer") == "v5" and audit.get("mode") == "full":
        assert float(audit.get("takeoff_speed") or 0.0) > 20.0
        assert audit.get("result") in (
            "FAIL_OFFTRACK",
            "FAIL_NO_SETTLE",
            "FAIL_RAIL_CONTACT",
            "PASS_SETTLED",
        )
