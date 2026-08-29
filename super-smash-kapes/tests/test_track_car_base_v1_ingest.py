"""Track car base V1 ingest: wrapper, collider, source immutability."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_source_glb_is_present_and_not_replaced() -> None:
    source = PROJECT_ROOT / "assets/vehicles/track/source/track_car_base_v1.glb"
    processed_clean = PROJECT_ROOT / "assets/vehicles/track/processed/track_car_base_v1_clean.glb"
    assert source.exists()
    assert source.stat().st_size > 1_000_000
    assert not processed_clean.exists()


def test_runtime_wrapper_and_ingest_lab_exist() -> None:
    for rel in (
        "scenes/track/TrackCar.tscn",
        "scenes/debug/TrackCarIngestLab.tscn",
        "scripts/track/track_car_visual.gd",
        "scripts/track/track_car_visual_config.gd",
        "scripts/track/track_car_ingest_lab.gd",
        "assets/vehicles/track/materials/track_car_body_v1.tres",
        "assets/vehicles/track/materials/track_car_ghost_v1.tres",
        "docs/TRACK_CAR_BASE_V1_INGEST_REPORT.md",
    ):
        assert (PROJECT_ROOT / rel).exists(), rel


def test_track_car_uses_box_collider_not_trimesh() -> None:
    scene = _read("scenes/track/TrackCar.tscn")
    config = _read("scripts/track/track_car_visual_config.gd")
    visual = _read("scripts/track/track_car_visual.gd")
    assert "BoxShape3D" in scene
    assert "ConcavePolygonShape3D" not in scene
    assert "create_trimesh_collision" not in visual
    assert "ConvexPolygonShape3D" not in scene
    assert "CollisionShape3D" in scene
    assert "VisualRoot" in scene
    assert "CameraAnchor" in scene
    assert "DriverHeadAnchor" in scene
    assert "CharacterMount" in scene
    assert 'SOURCE_GLB := "res://assets/vehicles/track/source/track_car_base_v1.glb"' in config
    assert 'WHEEL_STRUCTURE := "FUSED_BODY_MESH"' in config
    assert "WHEEL_ARTICULATION_BLOCKED_BY_SOURCE_MESH" in config
    assert "VISUAL_WHEEL_STEERING_DEFERRED" in config
    assert "VISUAL_SCALE" in config
    assert "COLLIDER_SIZE" in config


def test_controller_mounts_wrapper_without_replacing_handling() -> None:
    main = _read("scripts/track/track_main.gd")
    lab = _read("scripts/track/track_physics_lab.gd")
    car = _read("scripts/track/track_car_controller.gd")
    ghost = _read("scripts/track/track_ghost_player.gd")
    assert "res://scenes/track/TrackCar.tscn" in main
    assert "res://scenes/track/TrackCar.tscn" in lab
    assert "damp_lateral" in car
    assert "wants_drift" in car
    assert "camera_target" in car
    assert "set_character_visual" in car
    assert "set_player_accent" in car
    assert "CharacterBody3D" not in ghost.split("extends", 1)[1][:80]
    assert "ghost_mode" in ghost
    assert "create_trimesh_collision" not in ghost


def test_ingest_lab_is_isolated_from_controller() -> None:
    lab = _read("scripts/track/track_car_ingest_lab.gd")
    assert "TrackCarController" not in lab
    assert "ImportedCar" in lab
    assert "ReferenceGrid" in lab
    assert "ReferenceAxes" in lab
    assert "DebugCamera" in lab
    assert "ColliderPreview" in lab
