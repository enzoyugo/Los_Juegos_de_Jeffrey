"""Render resource stability gate: authorities, preloads, Defensores path."""

from pathlib import Path
import subprocess
import sys

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_defensores_platform_kit_authority_exists() -> None:
    png = PROJECT_ROOT / "assets/stages/defensores_del_chaco/platforms/defensores_platform_kit.png"
    stage = _read("scripts/stages/defensores_stage.gd")
    assert png.exists()
    assert png.stat().st_size > 100_000
    assert "defensores_platform_kit.png" in stage
    assert "const PLATFORM_TEXTURE := preload(" in stage


def test_track_runtime_authorities_are_split() -> None:
    visual = _read("scripts/track/track_car_visual.gd")
    config = _read("scripts/track/track_car_visual_config.gd")
    lab = _read("scripts/track/track_wheel_physics_lab.gd")
    main = _read("scripts/track/track_main.gd")
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    articulated_import = _read(
        "assets/vehicles/track/processed/track_car_base_v2_articulated.glb.import"
    )
    atlas_import = _read(
        "assets/vehicles/track/source/track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg.import"
    )
    assert 'CONTROLLER_MODE := "BASELINE"' in _read("scripts/track/track_config.gd")
    assert "SHARED_ATLAS" in config
    assert "_packed_for_mode" in visual
    assert "preload(\"res://assets/vehicles/track/source/track_car_base_v1.glb\")" not in visual
    assert "const BaselineScene := preload(" not in lab
    assert "const FourWheelScene := preload(" not in lab
    assert "const CarScene := preload(" not in main
    assert "const TRACK_SCENE := preload(" not in app
    assert "gltf/embedded_image_handling=0" in articulated_import
    assert "gltf/embedded_image_handling=3" not in articulated_import
    assert "compress/mode=2" in atlas_import
    assert (PROJECT_ROOT / "scenes/debug/RenderStabilityHarness.tscn").exists()
    assert (PROJECT_ROOT / "scenes/debug/ValidateJeffreyShell.tscn").exists()
    assert (PROJECT_ROOT / "tools/scan_resource_paths.py").exists()


def test_required_resource_path_scan_is_clean() -> None:
    result = subprocess.run(
        [sys.executable, str(PROJECT_ROOT / "tools/scan_resource_paths.py")],
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "required_missing=0" in result.stdout
    assert "defensores_platform_kit_exists=True" in result.stdout


def test_road_width_and_baseline_canonical_unchanged() -> None:
    config = _read("scripts/track/track_config.gd")
    assert "ROAD_WIDTH := 11.0" in config
    assert "ROAD_SHOULDER := 0.7" in config
    assert "GUARDRAIL_HEIGHT := 0.9" in config
    assert 'CONTROLLER_MODE := "BASELINE"' in config


def test_modular_kit_spec_and_inventory_exist() -> None:
    import json

    kit = json.loads((PROJECT_ROOT / "data/track/modules/track_kit_v1.json").read_text(encoding="utf-8"))
    inventory = PROJECT_ROOT / "docs/references/track/block_preview_inventory.csv"
    assert 15 <= len(kit["pieces"]) <= 25
    assert kit["contract"]["road_width_m"] == 11.0
    assert kit["pilot_ids"] == ["start", "straight_medium", "curve_l_45", "curve_r_45", "finish"]
    assert inventory.exists()
    assert (PROJECT_ROOT / "docs/TRACK_MODULAR_KIT_ORIGINALITY_GUIDELINES.md").exists()
    assert (PROJECT_ROOT / "scripts/blender/generate_track_kit_v1.py").exists()
    assert (PROJECT_ROOT / "scripts/track/track_piece_geometry_contract_v1.gd").exists()
    core = PROJECT_ROOT / "assets/track/modules/generated/core"
    names = [
        "track_start_v1.glb",
        "track_straight_medium_v1.glb",
        "track_curve_l_45_v1.glb",
        "track_curve_r_45_v1.glb",
        "track_finish_v1.glb",
        "track_landing_straight_long_v1.glb",
    ]
    glbs = sorted(p.name for p in core.glob("*.glb"))
    for name in names:
        assert name in glbs
    assert "track_ramp_takeoff_v1.glb" in glbs
    assert "track_gap_logical_v1.glb" in glbs
    assert len(glbs) == 17

