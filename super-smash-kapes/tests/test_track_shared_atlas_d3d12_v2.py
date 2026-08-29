"""Shared atlas must stay one imported Texture2D. No runtime 4K rebuild."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_canonical_atlas_authority_files_exist() -> None:
    jpg = PROJECT_ROOT / "assets/vehicles/track/source/track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg"
    atlas = PROJECT_ROOT / "assets/vehicles/track/materials/track_car_atlas.tres"
    player = PROJECT_ROOT / "assets/vehicles/track/materials/track_car_player_v1.tres"
    assert jpg.exists()
    assert jpg.stat().st_size > 1_000_000
    assert atlas.exists()
    assert player.exists()
    atlas_txt = atlas.read_text(encoding="utf-8")
    player_txt = player.read_text(encoding="utf-8")
    assert "track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg" in atlas_txt
    assert "track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg" in player_txt
    assert ".godot/imported" not in atlas_txt
    assert ".godot/imported" not in player_txt


def test_visual_does_not_rebuild_or_hardcode_imported_ctex() -> None:
    visual = _read("scripts/track/track_car_visual.gd")
    config = _read("scripts/track/track_car_visual_config.gd")
    assert "get_image(" not in visual
    assert "decompress(" not in visual
    assert "blit_rect" not in visual
    assert ".resize(" not in visual
    assert "Image.create(" in visual
    assert "_make_fallback_atlas" in visual
    assert "LOAD_FAILED" in visual
    assert "[TRACK_ATLAS]" in visual
    assert "CACHE_MODE_REUSE" in visual
    assert "res://.godot/imported" not in visual
    assert "res://.godot/imported" not in config
    assert "SHARED_ATLAS_AUTHORITY" in config
    assert "PLAYER_MATERIAL" in config
    assert "track_car_atlas.tres" in config
    assert "track_car_player_v1.tres" in config
    assert 'SHARED_ATLAS := "res://assets/vehicles/track/source/track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg"' in config


def test_fallback_image_is_tiny_not_4k() -> None:
    visual = _read("scripts/track/track_car_visual.gd")
    assert "Image.create(4, 4, false, Image.FORMAT_RGBA8)" in visual
    assert "Image.create(4096" not in visual
    assert "ImageTexture.create_from_image" in visual
    assert visual.count("ImageTexture.create_from_image") == 1


def test_diagnostic_labs_exist() -> None:
    assert (PROJECT_ROOT / "scenes/debug/TrackCarMinimalAtlasLab.tscn").exists()
    assert (PROJECT_ROOT / "scenes/debug/TrackCarTextureLoadOnly.tscn").exists()
    load_only = _read("scripts/debug/track_car_texture_load_only.gd")
    minimal = _read("scripts/debug/track_car_minimal_atlas_lab.gd")
    assert "get_image(" not in load_only
    assert "decompress(" not in load_only
    assert "_ensure_shared_atlas" not in load_only
    assert "TrackCarVisual" in minimal or "track_car_visual.gd" in minimal
    assert "use_articulated" in minimal
    assert "look_at_from_position(" in minimal
    look_idx = minimal.find("look_at_from_position(")
    add_idx = minimal.find("add_child(cam)")
    assert add_idx >= 0 and look_idx > add_idx
    assert "cam.look_at(" not in minimal


def test_physics_files_untouched_by_atlas_fix() -> None:
    wheel = _read("scripts/track/track_arcade_wheel.gd")
    car = _read("scripts/track/track_wheel_car.gd")
    scene = _read("scenes/track/TrackCarWheelPhysics.tscn")
    assert "mass = 420.0" in scene
    assert "linear_damp = 0.1" in scene
    assert "angular_damp = 1.55" in scene
    assert "longitudinal_grip" in wheel
    assert "SUSPENSION_TRAVEL" in wheel
    assert "linear_damp = WheelConfig.LINEAR_DAMP" in car
