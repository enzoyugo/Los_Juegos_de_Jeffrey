"""Track articulated V3 asset integrity + airborne/landing sanity."""

from __future__ import annotations

import hashlib
import json
import struct
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT_ROOT / "assets/vehicles/track/source/track_car_base_v1.glb"
V2 = PROJECT_ROOT / "assets/vehicles/track/processed/track_car_base_v2_articulated.glb"
V3 = PROJECT_ROOT / "assets/vehicles/track/processed/track_car_base_v3_articulated_clean.glb"
OWNERSHIP = PROJECT_ROOT / "docs/generated/TRACK_CAR_V3_MESH_OWNERSHIP.json"
SOURCE_SHA = "b1dd649b39b0c701ccb5b11062b7087579702caa930d8a0b436dd4d581e725af"

sys.path.insert(0, str(PROJECT_ROOT / "scripts" / "blender"))
import track_car_v3_lib as lib  # noqa: E402


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _parse_glb(path: Path) -> dict:
    data = path.read_bytes()
    json_len = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20 : 20 + json_len])


def test_source_hash_untouched() -> None:
    digest = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    assert digest == SOURCE_SHA
    cfg = _read("scripts/track/track_car_visual_config.gd")
    assert SOURCE_SHA in cfg


def test_v3_exists_geometry_only() -> None:
    assert V3.exists()
    assert V2.exists()
    doc = _parse_glb(V3)
    names = [n.get("name") for n in doc.get("nodes", [])]
    for wanted in ("Body", "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR", "NOSE_MARKER", "REAR_MARKER"):
        assert wanted in names, wanted
    assert not doc.get("images")
    assert not doc.get("textures")
    for node in doc["nodes"]:
        if node.get("name") in ("Body", "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"):
            sc = node.get("scale", [1, 1, 1])
            assert all(abs(float(s) - 1.0) < 0.001 for s in sc)


def test_v3_import_discards_embedded_images() -> None:
    text = (V3.parent / (V3.name + ".import")).read_text(encoding="utf-8")
    assert "gltf/embedded_image_handling=0" in text
    assert "animation/import=false" in text


def test_face_ownership_sum() -> None:
    data = json.loads(OWNERSHIP.read_text(encoding="utf-8"))
    src = int(data["source_faces"])
    total = sum(int(data["parts"][k]["faces"]) for k in data["parts"])
    assert total == src
    assert int(data.get("discarded", 0)) == 0


def test_v3_wheels_compact_and_sweep() -> None:
    parts = lib.extract_meshes(V3)
    for wid in lib.WHEEL_IDS:
        m = lib.wheel_metrics(parts["Wheel_%s" % wid])
        assert m["gates"]["pass"], (wid, m["gates"], m["max_radius"], m["aabb"]["size"])
        assert m["spin_sweep"]["pass"]
        assert m["max_radius"] <= lib.MAX_WHEEL_RADIUS_SOURCE + 1e-4
        assert max(m["aabb"]["size"]) <= lib.MAX_WHEEL_AABB_AXIS_SOURCE
        runtime_r = m["max_radius"] * lib.VISUAL_SCALE
        assert runtime_r <= 0.45


def test_v3_semantic_markers_minus_z() -> None:
    doc = _parse_glb(V3)
    nodes = {n.get("name"): n for n in doc["nodes"]}
    nose = nodes["NOSE_MARKER"]["translation"]
    rear = nodes["REAR_MARKER"]["translation"]
    fwd = (nose[0] - rear[0], nose[1] - rear[1], nose[2] - rear[2])
    assert fwd[2] < -0.5
    body = lib.extract_meshes(V3)["Body"]
    morph = lib.semantic_orientation_metrics(body)
    assert morph["pass"]
    fl_z = nodes["Wheel_FL"]["translation"][2]
    rl_z = nodes["Wheel_RL"]["translation"][2]
    assert fl_z < 0.0
    assert rl_z > 0.0


def test_v2_harness_still_fails() -> None:
    parts = lib.extract_meshes(V2)
    fails = 0
    for wid in lib.WHEEL_IDS:
        m = lib.wheel_metrics(parts["Wheel_%s" % wid])
        if not m["gates"]["pass"]:
            fails += 1
    assert fails >= 1
    v2_body = lib.semantic_orientation_metrics(parts["Body"])
    assert v2_body["pass"] is False


def test_runtime_uses_v3_not_v2() -> None:
    cfg = _read("scripts/track/track_car_visual_config.gd")
    assert "track_car_base_v3_articulated_clean.glb" in cfg
    assert "PROCESSED_ARTICULATED_V2_GLB" in cfg
    assert "physics_meters_to_visual_local" in cfg
    vis = _read("scripts/track/track_car_visual.gd")
    assert "semantic_forward" in vis
    assert "physics_meters_to_visual_local" in vis
    assert "Transform3D.IDENTITY" in vis
    assert "NOSE_MARKER" in vis
    car = _read("scripts/track/track_wheel_car.gd")
    assert "SPAWN_SETTLE" in car
    assert "TRACK_4WHEEL_LANDING" in car
    assert "AIR_DEBOUNCE_FRAMES" in car
    assert "dot_chassis" in car
    wheel = _read("scripts/track/track_arcade_wheel.gd")
    assert "compression_m" in wheel
    lab = _read("scripts/track/track_4wheel_extended_physics_lab.gd")
    assert "KEY_K" in lab
    assert "TAKEOFF_ZONE" in lab
    assert "VALID_TAKEOFF" in lab
    assert "track_extended_debug_camera.gd" in lab
    assert (PROJECT_ROOT / "scenes/debug/TrackCarSemanticOrientationLab.tscn").exists()
    assert (PROJECT_ROOT / "scenes/debug/TrackCarArticulatedIntegrityLab.tscn").exists()
    assert 'CONTROLLER_MODE := "BASELINE"' in _read("scripts/track/track_config.gd")


def test_compression_authority_units() -> None:
    def compression_m(rest, current, travel):
        return max(0.0, min(rest - current, travel))

    assert compression_m(0.12, 0.12, 0.14) == 0.0
    assert abs(compression_m(0.12, 0.10, 0.14) - 0.02) < 1e-9
    assert abs(compression_m(0.12, 0.04, 0.14) - 0.08) < 1e-9
    vis_scale = 4.4 / 0.998046875
    local = 0.08 / vis_scale
    assert abs(local * vis_scale - 0.08) < 1e-9


def test_baseline_not_promoted() -> None:
    main = _read("scripts/track/track_main.gd")
    assert "res://scenes/track/TrackCar.tscn" in main
    ghost = _read("scripts/track/track_ghost_player.gd")
    assert "TrackWheelCar" not in ghost
