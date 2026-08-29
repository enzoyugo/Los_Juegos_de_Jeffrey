"""Track modular kit pilot V1: 5 original pieces, exact connectors, shared materials."""

from __future__ import annotations

import json
import math
import struct
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CORE = PROJECT_ROOT / "assets/track/modules/generated/core"
PILOT_IDS = ("start", "straight_medium", "curve_l_45", "curve_r_45", "finish")
PILOT_GLBS = {
    "start": "track_start_v1.glb",
    "straight_medium": "track_straight_medium_v1.glb",
    "curve_l_45": "track_curve_l_45_v1.glb",
    "curve_r_45": "track_curve_r_45_v1.glb",
    "finish": "track_finish_v1.glb",
}


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _kit() -> dict:
    return json.loads((PROJECT_ROOT / "data/track/modules/track_kit_v1.json").read_text(encoding="utf-8"))


def _parse_glb(path: Path) -> dict:
    data = path.read_bytes()
    assert data[:4] == b"glTF"
    json_len = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20 : 20 + json_len])


def _piece(kit: dict, piece_id: str) -> dict:
    for item in kit["pieces"]:
        if item["id"] == piece_id:
            return item
    raise KeyError(piece_id)


def test_pilot_spec_contract() -> None:
    kit = _kit()
    contract = kit["contract"]
    assert contract["road_width_m"] == 11.0
    assert contract["shoulder_m"] == 0.7
    assert contract["guardrail_height_m"] == 0.9
    assert contract["guardrail_thickness_m"] == 0.22
    assert contract["seam_tolerance_m"] == 0.0005
    assert kit["pilot_ids"] == list(PILOT_IDS)
    start = _piece(kit, "start")
    finish = _piece(kit, "finish")
    straight = _piece(kit, "straight_medium")
    left = _piece(kit, "curve_l_45")
    right = _piece(kit, "curve_r_45")
    assert start["type"] == "start"
    assert finish["type"] == "finish"
    assert straight["length_m"] == 24.0
    assert 20.0 <= straight["length_m"] <= 35.0
    assert left["angle_deg"] == 45
    assert right["angle_deg"] == 45
    assert left["direction"] == "left"
    assert right["direction"] == "right"
    assert left["radius_m"] == right["radius_m"]
    names = set(kit["output_filenames"].values())
    assert set(PILOT_GLBS.values()).issubset(names)
    original_11 = {
        "track_start_v1.glb",
        "track_straight_medium_v1.glb",
        "track_curve_l_45_v1.glb",
        "track_curve_r_45_v1.glb",
        "track_finish_v1.glb",
        "track_ramp_small_v1.glb",
        "track_jump_small_v1.glb",
        "track_boost_straight_v1.glb",
        "track_landing_straight_long_v1.glb",
        "track_ramp_takeoff_v1.glb",
        "track_gap_logical_v1.glb",
    }
    assert original_11.issubset(names)
    for extra in (
        "track_straight_short_v1.glb",
        "track_straight_long_v1.glb",
        "track_curve_l_90_v1.glb",
        "track_curve_r_90_v1.glb",
        "track_chicane_lr_v1.glb",
        "track_chicane_rl_v1.glb",
    ):
        assert extra in names
    assert _piece(kit, "straight_short")["length_m"] == 12.0
    assert _piece(kit, "straight_long")["length_m"] == 44.0
    assert kit["extended_physics_ids"] == ["ramp_small", "jump_small", "boost_straight", "landing_straight_long"]
    assert kit["clean_gap_ids"] == ["ramp_takeoff", "gap_logical"]


def test_pilot_glbs_still_exist() -> None:
    for piece_id, name in PILOT_GLBS.items():
        glb = CORE / name
        meta = CORE / name.replace(".glb", ".json")
        assert glb.exists()
        assert meta.exists()
        payload = json.loads(meta.read_text(encoding="utf-8"))
        assert payload["piece_id"] == piece_id
        assert payload["road_width"] == 11.0
        assert payload["shoulder_width"] == 0.7
        assert payload["guardrail_height"] == 0.9
        assert payload["collision"]
        assert any(item["kind"] == "road" for item in payload["collision"])


def test_glbs_have_connectors_no_embedded_images() -> None:
    for piece_id, name in PILOT_GLBS.items():
        doc = _parse_glb(CORE / name)
        names = [node.get("name") for node in doc.get("nodes", [])]
        assert "ENTRY" in names, piece_id
        assert "EXIT" in names, piece_id
        assert "images" not in doc or not doc["images"]
        assert "textures" not in doc or not doc["textures"]
        materials = [m.get("name") for m in doc.get("materials", [])]
        assert "ROAD" in materials
        assert "SHOULDER" in materials
        assert "GUARDRAIL" in materials
        entry = next(n for n in doc["nodes"] if n.get("name") == "ENTRY")
        assert entry.get("translation", [0, 0, 0]) == [0.0, 0.0, 0.0]
        if piece_id == "start":
            assert "PLAYER_SPAWN" in names
            assert "START_MARKER" in names
        if piece_id == "finish":
            assert "FINISH_TRIGGER_ANCHOR" in names


def test_curve_is_true_arc_and_mirrored() -> None:
    sys.path.insert(0, str(PROJECT_ROOT / "scripts" / "blender"))
    import generate_track_kit_v1 as gen

    cfg = gen.TrackKitConfig(_kit())
    left = cfg.spec("curve_l_45")
    right = cfg.spec("curve_r_45")
    exit_l = gen.frame_at(cfg, left, 1.0)
    exit_r = gen.frame_at(cfg, right, 1.0)
    assert abs(math.degrees(exit_l["yaw"]) - 45.0) < 1e-9
    assert abs(math.degrees(exit_r["yaw"]) + 45.0) < 1e-9
    assert abs(exit_l["pos"][0] + exit_r["pos"][0]) < 1e-9
    assert abs(exit_l["pos"][2] - exit_r["pos"][2]) < 1e-9
    expected_len = 30.0 * math.radians(45.0)
    assert abs(gen.centerline_length(cfg, left) - expected_len) < 1e-9
    mid = gen.frame_at(cfg, left, 0.5)
    # width via perpendicular offset must stay 11 m
    inner = gen._offset(mid, -5.5, 0.0)
    outer = gen._offset(mid, 5.5, 0.0)
    width = math.dist(inner, outer)
    assert abs(width - 11.0) < 1e-9
    # not a rotated slab: midpoint is off the ENTRY->EXIT chord
    entry = gen.frame_at(cfg, left, 0.0)["pos"]
    chord_mid = (
        (entry[0] + exit_l["pos"][0]) * 0.5,
        0.0,
        (entry[2] + exit_l["pos"][2]) * 0.5,
    )
    assert math.dist(mid["pos"], chord_mid) > 1.0


def test_generator_refuses_all_and_defaults_to_pilot() -> None:
    src = _read("scripts/blender/generate_track_kit_v1.py")
    assert "--all is refused" in src or "Refusing --all" in src
    assert "PILOT_DEFAULT" in src
    result = subprocess.run(
        [sys.executable, str(PROJECT_ROOT / "scripts/blender/generate_track_kit_v1.py"), "--all"],
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    assert result.returncode == 2


def test_shared_lightweight_materials_and_no_new_atlas() -> None:
    mats = [
        "assets/track/materials/track_asphalt_v1.tres",
        "assets/track/materials/track_shoulder_v1.tres",
        "assets/track/materials/track_guardrail_v1.tres",
        "assets/track/materials/track_marker_v1.tres",
    ]
    for rel in mats:
        path = PROJECT_ROOT / rel
        assert path.exists()
        text = path.read_text(encoding="utf-8")
        assert "StandardMaterial3D" in text
        assert ".png" not in text
        assert path.stat().st_size < 4000
    asphalt = _read("assets/track/materials/track_asphalt_v1.tres")
    shoulder = _read("assets/track/materials/track_shoulder_v1.tres")
    rail = _read("assets/track/materials/track_guardrail_v1.tres")
    for text in (asphalt, shoulder, rail):
        assert "NoiseTexture2D" in text
        assert "FastNoiseLite" in text
    wrapper = _read("scripts/track/track_piece.gd")
    assert "track_asphalt_v1.tres" in _read("scripts/track/track_piece_registry.gd")
    assert "set_surface_override_material" in wrapper
    assert "Trimesh" not in wrapper
    lab = _read("scripts/track/track_modular_kit_pilot_lab.gd")
    assert "align_entry_to" in lab
    assert 'CONTROLLER_MODE' not in lab or "BASELINE" in lab
    assert "F5" in lab
    assert 'CONTROLLER_MODE := "FOUR_WHEEL_V1"' in _read("scripts/track/track_config.gd")
    assert (PROJECT_ROOT / "scenes/debug/TrackModularKitPilotLab.tscn").exists()
    assert (PROJECT_ROOT / "scenes/track/modules/TrackPiece.tscn").exists()


def test_sidecar_collision_is_not_visual_trimesh() -> None:
    curve = json.loads((CORE / "track_curve_l_45_v1.json").read_text(encoding="utf-8"))
    road_boxes = [item for item in curve["collision"] if item["kind"] == "road"]
    assert len(road_boxes) >= 8
    for box in road_boxes:
        assert box["size"][0] == 12.4
        assert abs(box["size"][1] - 0.12) < 1e-9
    straight = json.loads((CORE / "track_straight_medium_v1.json").read_text(encoding="utf-8"))
    roads = [item for item in straight["collision"] if item["kind"] == "road"]
    assert len(roads) == 1
    assert abs(roads[0]["size"][2] - 24.04) < 0.001


def test_glb_import_discards_embedded_images() -> None:
    for name in PILOT_GLBS.values():
        text = (CORE / (name + ".import")).read_text(encoding="utf-8")
        assert "gltf/embedded_image_handling=0" in text
        assert "gltf/embedded_image_handling=1" not in text
        assert "gltf/embedded_image_handling=3" not in text
        assert "animation/import=false" in text
    report = json.loads(
        (PROJECT_ROOT / "docs/generated/TRACK_PILOT_SEAM_MATH.json").read_text(encoding="utf-8")
    )
    assert len(report) == 4
    for row in report:
        assert row["max_position_m"] <= 0.0005
        assert abs(row["yaw_delta_deg"]) <= 0.05
        assert abs(row["up_delta_deg"]) <= 0.05
