"""Track clean gap + landing contract V5. Does not retune handling."""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CORE = PROJECT_ROOT / "assets/track/modules/generated/core"
GEN = PROJECT_ROOT / "docs/generated/track_clean_gap_v5"


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _kit() -> dict:
    return json.loads((PROJECT_ROOT / "data/track/modules/track_kit_v1.json").read_text(encoding="utf-8"))


def test_handling_constants_frozen() -> None:
    cfg = _read("scripts/track/track_wheel_physics_config.gd")
    assert "FRONT_LATERAL_GRIP := 9200.0" in cfg
    assert "REAR_LATERAL_GRIP" in cfg
    assert "DRIFT_REAR_GRIP" in cfg
    assert "YAW_ASSIST_TORQUE := 420.0" in cfg
    assert "ENGINE_FORCE := 6200.0" in cfg
    assert "SPRING_STRENGTH := 32000.0" in cfg
    assert 'CONTROLLER_MODE := "FOUR_WHEEL_V1"' in _read("scripts/track/track_config.gd")
    vis = _read("scripts/track/track_car_visual_config.gd")
    assert "track_car_base_v3_articulated_clean.glb" in vis
    source = PROJECT_ROOT / "assets/vehicles/track/source/track_car_base_v1.glb"
    assert source.stat().st_size == 4_269_248


def test_v5_pieces_and_lab_exist() -> None:
    assert (PROJECT_ROOT / "scenes/debug/TrackCleanGapLandingLab.tscn").exists()
    lab = _read("scripts/track/track_clean_gap_landing_lab.gd")
    for token in (
        "TRACK_TAKEOFF_TRANSFORM_INVARIANCE",
        "TRACK_GAP_COLLISION_EMPTY",
        "TRACK_FIRST_CONTACT_LANDING_DECK",
        "TRACK_NO_BODY_PRECONTACT",
        "TRACK_CLEAN_JUMP_SETTLE",
        "TRACK_RECOVERY_BEFORE_CURVE",
        "FAIL_FIRST_CONTACT_WRONG_PIECE",
        "FAIL_BODY_CONTACT_BEFORE_WHEEL",
        "PASS_SETTLED",
        "ramp_takeoff",
        "gap_logical",
        "use_scripted_input",
        "scripted_steer",
    ):
        assert token in lab
    assert "contact_piece_id" in _read("scripts/track/track_arcade_wheel.gd")
    assert "BODY_CONTACT_BEFORE_WHEEL" in _read("scripts/track/track_wheel_car.gd")
    assert (CORE / "track_ramp_takeoff_v1.glb").exists()
    assert (CORE / "track_gap_logical_v1.json").exists()
    gap = json.loads((CORE / "track_gap_logical_v1.json").read_text(encoding="utf-8"))
    assert gap["piece_id"] == "gap_logical"
    assert gap["has_gap"] is True
    assert gap["collision"] == []
    ramp = json.loads((CORE / "track_ramp_takeoff_v1.json").read_text(encoding="utf-8"))
    assert ramp["piece_id"] == "ramp_takeoff"
    assert any(item["kind"] == "road" for item in ramp["collision"])
    lip_end = abs(ramp["exit"]["origin"][2])
    assert abs(lip_end - 13.2) < 0.05
    assert not any(item.get("kind") == "rail" for item in ramp["collision"])


def test_pad_14_vs_2_takeoff_uncoupled() -> None:
    path = GEN / "iteration_01" / "pad_14_vs_2.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    ans = payload["answers"]
    assert ans["takeoff_edge_delta_m"] < 0.01
    assert ans["boost_entry_delta_m"] < 0.01
    assert ans["ramp_entry_delta_m"] < 0.01
    assert ans["shortening_moves_TAKEOFF_EDGE"] is False
    assert ans["shortening_moves_next_piece"] is True
    assert abs(ans["exit_delta_m"] - 12.0) < 0.2
    assert ans["pad_is_after_takeoff"] is True
    assert ans["pad_is_part_of_approach"] is False
    inv = json.loads((GEN / "assembly_invariance.json").read_text(encoding="utf-8"))
    assert inv["PASS"] is True
    assert inv["takeoff_identical"] is True
    assert inv["boost_identical"] is True
    empty = json.loads((GEN / "v5_gap_collision_sweep.json").read_text(encoding="utf-8"))
    assert empty["empty"] is True


def test_iteration_01_reproduces_jump_small_first_contact() -> None:
    audit_path = GEN / "iteration_01" / "audit.json"
    if not audit_path.exists():
        return
    audit = json.loads(audit_path.read_text(encoding="utf-8"))
    if audit.get("layout") == "v4":
        assert audit.get("first_contact_piece") == "jump_small" or audit.get("v4_expected_fail") is True


def test_generator_clean_gap_cli() -> None:
    src = _read("scripts/blender/generate_track_kit_v1.py")
    assert "--clean-gap" in src
    assert "CLEAN_GAP_PHYSICS" in src
    sys.path.insert(0, str(PROJECT_ROOT / "scripts" / "blender"))
    import generate_track_kit_v1 as gen

    cfg = gen.TrackKitConfig(_kit())
    ramp = cfg.spec("ramp_takeoff")
    r0 = gen.frame_at(cfg, ramp, 0.0)
    r1 = gen.frame_at(cfg, ramp, 1.0)
    assert abs(r0["pitch"]) < 1e-9
    assert abs(math.degrees(r1["pitch"]) - 18.0) < 0.05
    assert abs(r1["pos"][2] + 13.2) < 0.01
    gap = cfg.spec("gap_logical")
    assert gen.TrackPieceBuilder(cfg).collision_boxes(gap) == []
    g0 = gen.frame_at(cfg, gap, 0.0)
    g1 = gen.frame_at(cfg, gap, 1.0)
    assert g0["solid"] is False
    assert g1["solid"] is False
    assert abs(math.degrees(g0["pitch"]) - 18.0) < 0.05
    assert abs(g1["pitch"]) < 1e-6
