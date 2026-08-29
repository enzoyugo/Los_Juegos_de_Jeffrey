"""Track Turbo V8: 15 m kit, splits, blender pipeline. Generator V4 frozen."""

from __future__ import annotations

import json
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CORE_11 = PROJECT_ROOT / "assets/track/modules/generated/core"
KIT_15 = PROJECT_ROOT / "assets/track/processed/kit_v8_15m"
URBAN = PROJECT_ROOT / "assets/environments/shared/urban"


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_v8_files_exist() -> None:
    for rel in (
        "tools/blender/common/bpy_util.py",
        "tools/blender/track/widen_kit_metadata.py",
        "tools/blender/track/build_kit_v8_15m.py",
        "tools/blender/track/build_urban_kit_v1.py",
        "tools/blender/zombies/build_sds_environment_v1.py",
        "tools/blender/run_v8_content.py",
        "scripts/debug/track_turbo_v8_showcase.gd",
        "scenes/debug/TrackTurboV8Showcase.tscn",
        "scenes/debug/Track15mKitShowcase.tscn",
        "scenes/debug/TrackAsuncionUrbanV1Showcase.tscn",
        "scenes/debug/ShoppingBlenderEnvironmentV1Lab.tscn",
        "scenes/debug/SmokeTrackCheckpointSplitsV1.tscn",
        "scenes/debug/SmokeTrackVisualLifetimeV1.tscn",
        "scenes/debug/GodotStaleProcessDiagnostic.tscn",
        "docs/BLENDER_TOOLCHAIN_AND_SHARED_ASSET_PIPELINE_V1_REPORT.md",
        "docs/TRACK_15M_MODULAR_KIT_V1_REPORT.md",
        "docs/TRACK_AIRBORNE_SEAM_ROOT_CAUSE_V2_REPORT.md",
        "docs/TRACK_CHECKPOINT_SPLIT_TIMING_V1_REPORT.md",
        "docs/TRACK_VISUAL_LIFETIME_AUDIT_V1_REPORT.md",
        "docs/TRACK_TURBO_V8_HUMAN_CLOSURE_REPORT.md",
        "docs/SHOPPING_DEL_SOL_BLENDER_ENVIRONMENT_V1_REPORT.md",
        "docs/SHOPPING_BLENDER_GODOT_INTEGRATION_V1_REPORT.md",
        "docs/JEFFREY_BLENDER_TRACK_ZOMBIES_V8_MASTER_REPORT.md",
    ):
        assert (PROJECT_ROOT / rel).exists(), rel


def test_11m_kit_preserved() -> None:
    start = json.loads((CORE_11 / "track_start_v1.json").read_text(encoding="utf-8"))
    assert float(start["road_width"]) == 11.0
    assert (CORE_11 / "track_start_v1.glb").exists()
    assert (CORE_11 / "track_curve_l_90_v1.glb").exists()


def test_15m_metadata_width_and_overlap() -> None:
    start11 = json.loads((CORE_11 / "track_start_v1.json").read_text(encoding="utf-8"))
    start15 = json.loads((KIT_15 / "track_start_v1.json").read_text(encoding="utf-8"))
    assert float(start15["road_width"]) == 15.0
    assert float(start15["shoulder_width"]) == 0.9
    roads15 = [b for b in start15["collision"] if b.get("kind") == "road"]
    roads11 = [b for b in start11["collision"] if b.get("kind") == "road"]
    assert roads15, "15m start missing road collider"
    assert abs(float(roads15[0]["size"][0]) - 16.8) < 0.001
    assert float(roads15[0]["size"][1]) >= 0.20
    assert float(roads15[0]["size"][2]) >= float(roads11[0]["size"][2]) + 0.099
    for name in ("track_curve_l_45_v1.json", "track_curve_r_90_v1.json", "track_chicane_lr_v1.json"):
        doc = json.loads((KIT_15 / name).read_text(encoding="utf-8"))
        for box in doc.get("collision") or []:
            if box.get("kind") == "road":
                assert abs(float(box["size"][0]) - 16.8) < 0.05, name


def test_15m_glbs_exist() -> None:
    needed = [
        "start",
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
        "ramp_takeoff",
        "ramp_small",
        "jump_small",
        "landing_straight_long",
        "slope_up_gentle",
        "crest_gentle",
        "slope_down_gentle",
        "finish",
        "checkpoint_gantry",
    ]
    for pid in needed:
        glb = KIT_15 / ("track_%s_v1.glb" % pid)
        js = KIT_15 / ("track_%s_v1.json" % pid)
        assert glb.exists(), str(glb)
        if pid != "checkpoint_gantry":
            assert js.exists(), str(js)


def test_urban_and_sds_glbs() -> None:
    for rel in (
        "vegetation/palm_01.glb",
        "vegetation/palm_02.glb",
        "vegetation/tree_01.glb",
        "vegetation/tree_02.glb",
        "lighting/lamp_parking.glb",
        "vehicles/car_sedan.glb",
        "street_props/building_small_01.glb",
        "street_props/jeffrey_arch_01.glb",
        "industrial/container_01.glb",
    ):
        assert (URBAN / rel).exists(), rel
    sds = PROJECT_ROOT / "assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v1.glb"
    assert sds.exists()
    blend = PROJECT_ROOT / "assets/environments/shopping_del_sol/blender/shopping_del_sol_zombies_environment_v1.blend"
    assert blend.exists()


def test_splits_and_visual_lifetime_tokens() -> None:
    hs = _read("scripts/track/track_hotseat_v2.gd")
    assert "record_split" in hs
    assert "target_split_sec" in hs
    assert "best_splits" in hs
    v8 = _read("scripts/debug/track_turbo_v8_showcase.gd")
    assert "_hs.record_split(_timer)" in v8
    assert "target_split_sec" in v8
    assert "_car.free()" in v8
    vis = _read("scripts/track/track_car_visual.gd")
    assert "static func live_visuals" in vis
    assert "CORE_DIR_V8_15M" in _read("scripts/track/track_piece_registry.gd")
    assert 'kit_dir: String = ""' in _read("scripts/track/track_kit_assembler.gd")


def test_firewalls_intact() -> None:
    gen = _read("scripts/track/track_generator_v2.gd")
    assert "Incremental constraint-aware assembler" in gen
    assert "MAX_ATTEMPTS" in gen
    cfg = _read("scripts/track/track_config.gd")
    assert 'CONTROLLER_MODE := "BASELINE"' in cfg
    assert "ROAD_WIDTH := 11.0" in cfg
    wheel = _read("scripts/track/track_wheel_physics_config.gd")
    assert "SPRING_STRENGTH := 32000.0" in wheel
    assert "SUSPENSION_TRAVEL := 0.14" in wheel
    assert "MAX_SUSPENSION_FORCE := 18000.0" in wheel
    assert "CENTER_OF_MASS_OFFSET := Vector3(0.0, -0.12, 0.06)" in wheel
    main = _read("scripts/track/track_main.gd")
    assert "track_generator_v2" not in main
    assert "CORE_DIR_V8_15M" not in main
    f6 = _read("scripts/debug/f6_repeat_stability_lab.gd")
    assert "TrackTurboV8Showcase.tscn" in f6
    guard = _read("scripts/debug/godot_stale_process_diagnostic.gd")
    assert "never auto-kill" in guard
    assert "queue_free()" not in guard or "kill" not in guard.lower() or "Never kills" in guard
