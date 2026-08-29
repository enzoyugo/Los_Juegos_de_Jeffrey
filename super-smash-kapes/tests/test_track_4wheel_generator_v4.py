"""Track 4WHEEL generator lab + incremental composer V4 static locks."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_v4_files_exist() -> None:
    for rel in (
        "scripts/track/track_generator_v2.gd",
        "scripts/track/track_generator_v2_lab.gd",
        "scripts/track/track_surface.gd",
        "scripts/debug/smoke_track_generator_v4_batch.gd",
        "scripts/debug/smoke_track_4wheel_module_compat.gd",
        "scenes/debug/Track4WheelModuleCompat.tscn",
        "assets/track/modules/generated/core/track_slope_up_gentle_v1.json",
        "assets/track/modules/generated/core/track_slope_down_gentle_v1.json",
        "assets/track/modules/generated/core/track_crest_gentle_v1.json",
    ):
        assert (PROJECT_ROOT / rel).exists(), rel


def test_lab_defaults_4wheel_trackmain_stays_baseline() -> None:
    lab = _read("scripts/track/track_generator_v2_lab.gd")
    config = _read("scripts/track/track_config.gd")
    main = _read("scripts/track/track_main.gd")
    assert 'MODE_FOUR_WHEEL := "4WHEEL"' in lab
    assert "_mode: String = MODE_FOUR_WHEEL" in lab
    assert "KEY_F2" in lab
    assert "TrackCarWheelPhysics.tscn" in lab
    assert "TrackCar.tscn" in lab
    assert 'CONTROLLER_MODE := "BASELINE"' in config
    assert "track_generator_v2" not in main


def test_incremental_composer_tokens() -> None:
    gen = _read("scripts/track/track_generator_v2.gd")
    val = _read("scripts/track/track_generator_v2_validator.gd")
    assert "COMPOSE_EMPTY" in gen
    assert "_backtrack_seq" in gen
    assert "OccupancyIndex" in gen
    assert "_heading_openness" in gen
    assert "CONTROLLER_COMPAT" in val
    assert "xz_overlap" in val
    assert "slope_up_gentle" in gen
    assert "MAX_ATTEMPTS := 40" in gen
    assert "10007" in gen
    assert "* 17" in gen


def test_offtrack_and_4wheel_boost_cap() -> None:
    lab = _read("scripts/track/track_generator_v2_lab.gd")
    wheel = _read("scripts/track/track_arcade_wheel.gd")
    surf = _read("scripts/track/track_surface.gd")
    assert "OFFTRACK" in lab
    assert "KIND_OFFTRACK" in surf
    assert "drive_cap" in wheel
    assert "rest_m" in wheel
