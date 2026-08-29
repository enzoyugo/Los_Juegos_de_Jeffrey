"""Track generator V2: modular kit assembler, validation, materials, boost rearm."""

from __future__ import annotations

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CORE = PROJECT_ROOT / "assets/track/modules/generated/core"

ALLOWED = (
    "start",
    "finish",
    "straight_short",
    "straight_medium",
    "straight_long",
    "curve_l_45",
    "curve_r_45",
    "curve_l_90",
    "curve_r_90",
    "chicane_lr",
    "chicane_rl",
    "boost_straight",
    "landing_straight_long",
)
FORBIDDEN = (
    "ramp_small",
    "ramp_takeoff",
    "jump_small",
    "gap_logical",
    "hairpin_l",
    "hairpin_r",
)


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _allowed_block(src: str) -> str:
    start = src.find("ALLOWED_IDS")
    assert start != -1
    end = src.find("]", start)
    assert end != -1
    return src[start : end + 1]


def test_v2_files_exist() -> None:
    for rel in (
        "scripts/track/track_generator_v2.gd",
        "scripts/track/track_generator_v2_validator.gd",
        "scripts/track/track_generator_v2_lab.gd",
        "scenes/debug/TrackGeneratorV2Lab.tscn",
        "data/track/generator_v2_showcases.json",
        "tests/test_track_generator_v2.py",
        "scripts/debug/smoke_track_generator_v2.gd",
        "scripts/debug/track_boost_reset_lab.gd",
        "scenes/debug/TrackBoostResetLab.tscn",
        "docs/TRACK_GENERATOR_AND_VISUAL_FOUNDATION_V2_REPORT.md",
    ):
        assert (PROJECT_ROOT / rel).exists(), rel


def test_kit_glb_count_original_plus_new() -> None:
    glbs = sorted(CORE.glob("*.glb"))
    assert len(glbs) == 17
    original_11 = (
        "start",
        "straight_medium",
        "curve_l_45",
        "curve_r_45",
        "finish",
        "ramp_small",
        "jump_small",
        "boost_straight",
        "landing_straight_long",
        "ramp_takeoff",
        "gap_logical",
    )
    for piece_id in original_11:
        matches = list(CORE.glob(f"track_{piece_id}_v1.glb"))
        assert matches, piece_id
    for piece_id in ALLOWED:
        matches = list(CORE.glob(f"track_{piece_id}_v1.glb"))
        assert matches, piece_id


def test_showcases_json_has_three_seeds() -> None:
    import json

    data = json.loads(_read("data/track/generator_v2_showcases.json"))
    for key in ("SHORT_SHOWCASE", "MEDIUM_SHOWCASE", "LONG_SHOWCASE"):
        assert key in data
        row = data[key]
        assert int(row["seed"]) >= 1
        assert row["length"] in ("SHORT", "MEDIUM", "LONG")
        assert row["difficulty"] in ("TRANQUI", "PICANTE", "DEMENTE")


def test_generator_source_has_reject_reasons_and_accepted() -> None:
    gen = _read("scripts/track/track_generator_v2.gd")
    val = _read("scripts/track/track_generator_v2_validator.gd")
    lab = _read("scripts/track/track_generator_v2_lab.gd")
    smoke = _read("scripts/debug/smoke_track_generator_v2.gd")
    assert 'print("[TRACK_GENERATOR_V2] ACCEPTED")' in gen
    assert "[TRACK_GENERATOR_V2] ACCEPTED" in smoke
    assert "SEAM_POS" in val
    assert "SEAM_ROT" in val
    assert "OVERLAP" in val
    assert "SELF_CROSS" in val
    assert "HEADING" in val
    assert "ELEVATION" in val
    assert "DRIVEABILITY" in val
    assert "VARIETY" in val
    assert "START/FINISH" in val
    assert "NO_STUNT" in val
    assert "MAX_ATTEMPTS := 40" in gen
    assert "10007" in gen
    assert "* 17" in gen
    assert "KEY_1" in lab and "KEY_2" in lab and "KEY_3" in lab
    assert "KEY_T" in lab and "KEY_R" in lab and "KEY_G" in lab
    assert "KEY_F4" in lab
    assert "KEY_F2" in lab
    assert "TrackCar.tscn" in lab
    assert "TrackCarWheelPhysics.tscn" in lab
    assert "SSK_TRACK_CONTROLLER" not in lab


def test_controller_mode_still_baseline() -> None:
    config = _read("scripts/track/track_config.gd")
    main = _read("scripts/track/track_main.gd")
    assert 'CONTROLLER_MODE := "FOUR_WHEEL_V1"' in config
    assert "TrackGeneratorV2" not in main
    assert "track_generator_v2" not in main


def test_handling_constants_still_frozen() -> None:
    cfg = _read("scripts/track/track_wheel_physics_config.gd")
    assert "FRONT_LATERAL_GRIP := 9200.0" in cfg
    assert "YAW_ASSIST_TORQUE := 420.0" in cfg
    assert "SPRING_STRENGTH := 32000.0" in cfg
    assert "CENTER_OF_MASS_OFFSET := Vector3(0.0, -0.12, 0.06)" in cfg


def test_v2_allowed_pool_has_no_jump_or_ramp() -> None:
    val = _read("scripts/track/track_generator_v2_validator.gd")
    gen = _read("scripts/track/track_generator_v2.gd")
    block = _allowed_block(val)
    for bad in FORBIDDEN:
        assert f'"{bad}"' not in block, bad
        assert f'"{bad}"' not in gen, bad
    for good in ALLOWED:
        assert f'"{good}"' in block, good
    assert '"slope_up_gentle"' in val
    assert "ramp_" not in block
    assert "jump_" not in block
    assert "jump_small" not in gen
    assert "ramp_small" not in gen
    assert "gap_logical" not in gen


def test_v1_greybox_generator_untouched_in_behavior() -> None:
    gen = _read("scripts/track/track_generator.gd")
    assert "class_name TrackGenerator" in gen
    assert "func generate(seed_value: int, length_id: String, difficulty_id: String)" in gen
    assert 'types: Array[String] = ["start"]' in gen
    assert '"hairpin_left"' in gen
    assert '"chicane"' in gen
    assert "TrackPieceRegistry" not in gen
    assert "straight_medium" not in gen
    assert "curve_l_45" not in gen


def test_shared_materials_use_noise_not_atlas() -> None:
    asphalt = _read("assets/track/materials/track_asphalt_v1.tres")
    shoulder = _read("assets/track/materials/track_shoulder_v1.tres")
    rail = _read("assets/track/materials/track_guardrail_v1.tres")
    for text in (asphalt, shoulder, rail):
        assert "StandardMaterial3D" in text
        assert "NoiseTexture2D" in text
        assert "FastNoiseLite" in text
        assert ".png" not in text
        assert "uid://track" in text
    assert "roughness = 0.85" in asphalt
    registry = _read("scripts/track/track_piece_registry.gd")
    assert "track_asphalt_v1.tres" in registry
    assert "track_shoulder_v1.tres" in registry
    assert "track_guardrail_v1.tres" in registry


def test_boost_rearm_and_reset_lab() -> None:
    piece = _read("scripts/track/track_piece.gd")
    jump = _read("scripts/track/track_jump_trajectory_lab.gd")
    car = _read("scripts/track/track_wheel_car.gd")
    lab = _read("scripts/debug/track_boost_reset_lab.gd")
    assert "func rearm_boost_trigger()" in piece
    assert 'set_deferred("monitoring", true)' in piece
    assert "rearm_boost_trigger" in jump
    assert "boost_generation" in car
    assert "BOOST_ENTRY" in lab
    assert "SSK_BOOST_RESET_SMOKE" in lab
    assert "TrackCarWheelPhysics.tscn" in lab
    assert "boost_straight" in lab
    assert "apply_track_boost" in car
    assert "_boost_timer = Config.BOOST_DURATION" in car or "Config.BOOST_DURATION" in car
