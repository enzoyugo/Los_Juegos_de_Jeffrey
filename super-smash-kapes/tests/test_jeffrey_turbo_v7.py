"""Track Turbo V7 + production pipeline static locks."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_hud_telemetry_is_safe() -> None:
    lab = _read("scripts/track/track_generator_v2_lab.gd")
    tel = _read("scripts/track/track_debug_telemetry.gd")
    assert "TrackDebugTelemetry" in tel
    assert "int(_car.get(\"debug_grounded_n\"))" not in lab
    assert "Telemetry.debug_int" in lab
    assert "OPTIONAL" in tel or "debug_int" in tel
    assert 'CONTROLLER_MODE := "FOUR_WHEEL_V1"' in _read("scripts/track/track_config.gd")


def test_pipeline_and_labs_exist() -> None:
    for rel in (
        "docs/JEFFREY_GAME_PRODUCTION_PIPELINE_V1.md",
        "scripts/track/track_dynamic_chase_camera.gd",
        "scripts/track/track_hotseat_v2.gd",
        "scripts/track/track_checkpoint_layout.gd",
        "scripts/track/track_rhythm_analyzer.gd",
        "scripts/track/track_scenery_generator.gd",
        "scripts/track/track_generation_reveal.gd",
        "scripts/track/track_turbo_hud.gd",
        "scenes/debug/TrackWidthCameraDriftLab.tscn",
        "scenes/debug/TrackCameraLab.tscn",
        "scenes/debug/TrackDriftLab.tscn",
        "scenes/debug/TrackHotseatLab.tscn",
        "scenes/debug/TrackGenerationRevealLab.tscn",
        "scenes/debug/TrackSceneryLab.tscn",
        "scenes/debug/TrackTurboV7Showcase.tscn",
        "scenes/debug/SmokeTrackTurboV7Systems.tscn",
        "scenes/debug/F6RepeatStabilityLab.tscn",
        "tools/find_blender.py",
        "assets/environments/shopping_del_sol/blender/README.md",
        "docs/TRACK_TURBO_DRIVING_FEEL_V7_REPORT.md",
        "docs/TRACK_TURBO_HOTSEAT_V2_REPORT.md",
        "docs/TRACK_PROCEDURAL_SHOW_AND_RHYTHM_V2_REPORT.md",
        "docs/TRACK_ASUNCION_URBAN_SCENERY_V2_REPORT.md",
        "docs/SHOPPING_BLENDER_ENVIRONMENT_PIPELINE_V1_REPORT.md",
        "docs/JEFFREY_F6_RUNTIME_STABILITY_V3_REPORT.md",
        "docs/JEFFREY_TRACK_TURBO_AND_ENVIRONMENT_PIPELINE_V7_MASTER_REPORT.md",
    ):
        assert (PROJECT_ROOT / rel).exists(), rel


def test_generator_v4_not_rewritten() -> None:
    gen = _read("scripts/track/track_generator_v2.gd")
    assert "Incremental constraint-aware assembler" in gen
    assert "MAX_ATTEMPTS" in gen
    main = _read("scripts/track/track_main.gd")
    assert "track_generator_v2" not in main
    assert "TrackCar.tscn" in main


def test_hotseat_is_last_place_not_round_robin() -> None:
    hs = _read("scripts/track/track_hotseat_v2.gd")
    assert "PHASE_LAST_PLACE" in hs
    assert "last_place_id" in hs
    assert "ÚLTIMA" in hs or "used_ultima" in hs
    turns = _read("scripts/track/track_turn_manager.gd")
    assert "current_index += 1" in turns


def test_width_candidate_not_canonical() -> None:
    cfg = _read("scripts/track/track_config.gd")
    assert "ROAD_WIDTH := 11.0" in cfg
    assert "ROAD_WIDTH_CANDIDATE := 15.0" in cfg
    contract = _read("scripts/track/track_piece_geometry_contract_v1.gd")
    assert "ROAD_WIDTH := 11.0" in contract


def test_camera_bounds_and_drift_no_suspension_retune() -> None:
    cam = _read("scripts/track/track_dynamic_chase_camera.gd")
    assert "clampf(fov, 60.0, 92.0)" in cam
    assert "is_finite" in cam
    wheel = _read("scripts/track/track_wheel_car.gd")
    assert "[TRACK_DRIFT] ENTER" in wheel
    cfg = _read("scripts/track/track_wheel_physics_config.gd")
    assert "SPRING_STRENGTH" in cfg
    assert "TrackDynamicChaseCamera" in cam


def test_zombies_gameplay_and_blender_firewall() -> None:
    mmap = _read("scripts/zombies/zombies_map.gd")
    cfg = _read("scripts/zombies/zombies_config.gd")
    assert "MAIN_ENTRANCE_COST := 1500" in cfg
    assert "player_spawn: Vector3 = Vector3(0, 0.05, 28.5)" in mmap
    assert "*" in _read("assets/reference/.gdignore")
    assert (PROJECT_ROOT / "assets/environments/shopping_del_sol/blender/exports/shopping_del_sol_zombies_environment_v1.glb").exists()
    assert "BLENDER_REQUIRED" in _read("tools/find_blender.py")
    assert "assets/raw_models" not in mmap
    parking = _read("scripts/zombies/zombies_parking.gd")
    assert "visuals: bool = true" in parking
