"""V9 asset-first + seam/runoff firewalls. Generator V4 and TrackMain frozen."""

from __future__ import annotations

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_v9_files_exist() -> None:
    for rel in (
        "tools/blender/run_v9_content.py",
        "tools/blender/track/process_raw_library_v9.py",
        "tools/blender/track/build_urban_kit_v2.py",
        "tools/blender/zombies/build_sds_environment_v2.py",
        "tools/blender/zombies/build_zombie_pistol_foundation_v1.py",
        "scripts/track/track_seam_contact_inspector.gd",
        "scripts/debug/smoke_track_seam_contact_v1.gd",
        "scenes/debug/SmokeTrackSeamContactV1.tscn",
        "scenes/debug/ShoppingBlenderEnvironmentV2Lab.tscn",
        "docs/BLENDER_ASSET_USAGE_AND_PROVENANCE_V2_REPORT.md",
        "docs/SHOPPING_DEL_SOL_BLENDER_ENVIRONMENT_V2_REPORT.md",
        "docs/SHOPPING_FACADE_AND_ENTRANCE_V2_REPORT.md",
        "docs/SHOPPING_INTERIOR_THRESHOLD_V1_REPORT.md",
        "docs/TRACK_AIRBORNE_AND_SEAM_CLOSURE_V3_REPORT.md",
        "docs/TRACK_DRIFT_CAMERA_HUMAN_FEEL_V2_REPORT.md",
        "docs/TRACK_ASUNCION_URBAN_ASSET_FIRST_V3_REPORT.md",
        "docs/JEFFREY_BLENDER_ASSET_FIRST_V9_MASTER_REPORT.md",
        "scenes/debug/CaptureV9VisualReview.tscn",
        "scripts/debug/capture_v9_visual_review.gd",
    ):
        assert (PROJECT_ROOT / rel).exists(), rel


def test_finish_runoff_kit() -> None:
    js = PROJECT_ROOT / "assets/track/processed/kit_v8_15m/track_finish_runoff_v1.json"
    glb = PROJECT_ROOT / "assets/track/processed/kit_v8_15m/track_finish_runoff_v1.glb"
    assert js.exists(), js
    assert glb.exists(), glb
    text = js.read_text(encoding="utf-8")
    assert '"piece_id": "finish_runoff"' in text
    assert "CORE_DIR_V8_15M" in _read("scripts/track/track_piece_registry.gd")
    assert "finish_runoff" in _read("scripts/track/track_piece_registry.gd")
    asm = _read("scripts/track/track_kit_assembler.gd")
    assert "append_runoff" in asm
    assert "finish_runoff" in asm


def test_seam_and_drift_tokens() -> None:
    piece = _read("scripts/track/track_piece.gd")
    assert "RoadCollider_" in piece
    assert "RoadCollider_Seam" in piece
    assert "RoadCollider_SeamExit" in piece
    wheel = _read("scripts/track/track_arcade_wheel.gd")
    assert "last_contact_kind" in wheel
    car = _read("scripts/track/track_wheel_car.gd")
    assert "POST_FINISH_RUNOFF" in car
    assert "DRIFT_ARM" in car
    assert "DRIFT_ACTIVE" in car
    assert "post_finish" in car
    cfg = _read("scripts/track/track_wheel_physics_config.gd")
    assert "DRIFT_ACTIVE_SLIP" in cfg
    assert "SPRING_STRENGTH := 32000.0" in cfg
    assert "SUSPENSION_TRAVEL := 0.14" in cfg


def test_firewalls_intact() -> None:
    gen = _read("scripts/track/track_generator_v2.gd")
    assert "Incremental constraint-aware assembler" in gen
    main = _read("scripts/track/track_main.gd")
    assert "CORE_DIR_V8_15M" not in main
    assert "finish_runoff" not in main
    cfg = _read("scripts/track/track_config.gd")
    assert 'CONTROLLER_MODE := "BASELINE"' in cfg
    zcfg = _read("scripts/zombies/zombies_config.gd")
    assert "MAIN_ENTRANCE_COST := 1500" in zcfg
    assert "raw_models" not in _read("scripts/zombies/zombies_map.gd")


def test_v8_uses_runoff() -> None:
    v8 = _read("scripts/debug/track_turbo_v8_showcase.gd")
    assert "assemble(self, seq, KIT_DIR, true)" in v8
    assert "ST_RUNOFF" in v8
    assert "record_split" in v8
