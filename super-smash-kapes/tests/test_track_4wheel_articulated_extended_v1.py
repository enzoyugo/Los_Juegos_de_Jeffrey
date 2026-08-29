"""4WHEEL articulated transform fix + extended physics lab (ramp/jump/boost)."""

from __future__ import annotations

import json
import math
import struct
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CORE = PROJECT_ROOT / "assets/track/modules/generated/core"

PILOT_GLBS = (
    "track_start_v1.glb",
    "track_straight_medium_v1.glb",
    "track_curve_l_45_v1.glb",
    "track_curve_r_45_v1.glb",
    "track_finish_v1.glb",
)
EXTENDED_GLBS = {
    "ramp_small": "track_ramp_small_v1.glb",
    "jump_small": "track_jump_small_v1.glb",
    "boost_straight": "track_boost_straight_v1.glb",
    "landing_straight_long": "track_landing_straight_long_v1.glb",
    "ramp_takeoff": "track_ramp_takeoff_v1.glb",
    "gap_logical": "track_gap_logical_v1.glb",
}
ALL_GLBS = tuple(PILOT_GLBS) + tuple(EXTENDED_GLBS.values())
V3_GLBS = (
    "track_straight_short_v1.glb",
    "track_straight_long_v1.glb",
    "track_curve_l_90_v1.glb",
    "track_curve_r_90_v1.glb",
    "track_chicane_lr_v1.glb",
    "track_chicane_rl_v1.glb",
)


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _kit() -> dict:
    return json.loads((PROJECT_ROOT / "data/track/modules/track_kit_v1.json").read_text(encoding="utf-8"))


def _parse_glb(path: Path) -> dict:
    data = path.read_bytes()
    assert data[:4] == b"glTF"
    json_len = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20 : 20 + json_len])


def test_visual_yaw_paths_are_split() -> None:
    cfg = _read("scripts/track/track_car_visual_config.gd")
    visual = _read("scripts/track/track_car_visual.gd")
    assert "SOURCE_VISUAL_YAW_DEGREES" in cfg
    assert "ARTICULATED_VISUAL_YAW_DEGREES" in cfg
    assert "ARTICULATED_BODY_YAW_DEGREES" in cfg
    assert "ARTICULATED_VISUAL_YAW_DEGREES := 0.0" in cfg
    assert "ARTICULATED_BODY_YAW_DEGREES := 0.0" in cfg
    assert "SOURCE_VISUAL_YAW_DEGREES := 180.0" in cfg
    assert "use_articulated" in visual
    assert "ARTICULATED_VISUAL_ROTATION_DEGREES" in visual
    assert "geometric_forward" in visual
    assert "body_model_nose" in visual
    assert "rest_transform" in visual
    assert "centroid_local" in visual
    assert "reparent(spin, false)" in visual
    assert "MODE_REST" in visual
    assert "SteerPivot" in visual
    assert "SuspensionPivot" in visual
    assert "SpinPivot" in visual
    assert "susp_m" in visual
    assert "physics_meters_to_visual_local" in visual or "VISUAL_SCALE" in visual
    assert "live_visuals" in visual or "_exit_tree" in visual


def test_wheel_bind_does_not_double_translate() -> None:
    visual = _read("scripts/track/track_car_visual.gd")
    assert "axle_parent" in visual
    assert "mesh3.reparent(spin, false)" in visual
    assert "Transform3D.IDENTITY" in visual
    assert "wheel_center_global" in visual
    assert "debug_apply_wheel_pose" in visual
    assert "physics_meters_to_visual_local" in visual


def test_physics_chassis_is_not_yawed_to_match_art() -> None:
    car = _read("scripts/track/track_wheel_car.gd")
    vis = _read("scripts/track/track_car_visual.gd")
    assert "rotate_y(" not in car
    assert "ARTICULATED_BODY_YAW" in vis
    assert "apply_track_boost" in car
    assert "AIRBORNE_ENTER" in car
    assert "AIRBORNE_EXIT" in car
    assert "add_to_group(\"track_runtime_car\")" in car
    assert "fmod(spin_angle, TAU)" in _read("scripts/track/track_arcade_wheel.gd")


def test_airborne_skips_tire_forces() -> None:
    wheel = _read("scripts/track/track_arcade_wheel.gd")
    cfg = _read("scripts/track/track_wheel_physics_config.gd")
    assert "if not _ray.is_colliding():" in wheel
    assert "is_grounded = false" in wheel
    src = wheel.split("if not _ray.is_colliding():", 1)[1].split("var normal", 1)[0]
    assert "apply_force" not in src
    assert "lateral_tire_force(8.0, 20.0, 0.0" in _read("scripts/debug/validate_jeffrey_shell.gd")
    assert "no tire force without load / airborne" in _read("scripts/debug/validate_jeffrey_shell.gd")
    assert "lateral_tire_force" in cfg


def test_boost_is_shared_and_bounded() -> None:
    piece = _read("scripts/track/track_piece.gd")
    baseline = _read("scripts/track/track_car_controller.gd")
    four = _read("scripts/track/track_wheel_car.gd")
    assert "BoostTrigger" in piece
    assert "collision_layer = 0" in piece
    assert "apply_track_boost" in piece
    assert "boost_gameplay_enabled" in piece
    assert "if _boost_timer > Config.BOOST_RETRIGGER_LOCK" in baseline
    assert "if _boost_timer > Config.BOOST_RETRIGGER_LOCK" in four
    assert "apply_central_force" in four
    assert "Config.BOOST_ACCEL_SCALE" in baseline
    assert "BOOST_OVERSPEED" in baseline


def test_f5_frees_old_car() -> None:
    for rel in (
        "scripts/track/track_modular_kit_pilot_lab.gd",
        "scripts/track/track_wheel_physics_lab.gd",
        "scripts/track/track_4wheel_extended_physics_lab.gd",
    ):
        src = _read(rel)
        assert "old.free()" in src
        assert "live_track_car_count" in src
        assert "KEY_V" in src
        assert "KEY_B" in src
    ext = _read("scripts/track/track_4wheel_extended_physics_lab.gd")
    assert "KEY_K" in ext
    assert "TAKEOFF_ZONE" in ext


def test_original_eleven_plus_v3_modules() -> None:
    glbs = sorted(p.name for p in CORE.glob("*.glb"))
    for name in ALL_GLBS:
        assert name in glbs
        assert (CORE / name).exists()
        assert (CORE / name.replace(".glb", ".json")).exists()
    for name in V3_GLBS:
        assert name in glbs
        assert (CORE / name).exists()
        assert (CORE / name.replace(".glb", ".json")).exists()
    assert len(glbs) == 17


def test_extended_glbs_have_connectors_no_images() -> None:
    for piece_id, name in EXTENDED_GLBS.items():
        doc = _parse_glb(CORE / name)
        names = [node.get("name") for node in doc.get("nodes", [])]
        assert "ENTRY" in names, piece_id
        assert "EXIT" in names, piece_id
        assert "images" not in doc or not doc["images"]
        assert "textures" not in doc or not doc["textures"]
        materials = [m.get("name") for m in doc.get("materials", [])]
        meta = json.loads((CORE / name.replace(".glb", ".json")).read_text(encoding="utf-8"))
        assert meta["piece_id"] == piece_id
        assert meta["road_width"] == 11.0
        if piece_id == "gap_logical":
            assert meta.get("has_gap") is True
            assert meta["collision"] == []
            assert "ROAD" not in materials
            continue
        assert "ROAD" in materials
        assert any(item["kind"] == "road" for item in meta["collision"])
        if piece_id == "jump_small":
            assert meta.get("left_guardrail") is False
            assert meta.get("has_gap") is True
            zs = [item["origin"][2] for item in meta["collision"] if item["kind"] == "road"]
            # gap around z = -(1.2 + 3.5) = -4.7 should have no road box center
            gap_centers = [z for z in zs if -8.0 < z < -1.4]
            assert gap_centers == []
        if piece_id == "boost_straight":
            assert meta["boost_strength"] > 0.0
            assert "START_FINISH" in materials or "MARKER" in materials
        if piece_id == "ramp_small":
            pitches = [abs(item.get("pitch", 0.0)) for item in meta["collision"] if item["kind"] == "road"]
            assert max(pitches) > 0.05
            assert min(pitches) < 0.08
        if piece_id == "ramp_takeoff":
            assert "TAKEOFF_EDGE" in names
            assert abs(meta["exit"]["origin"][2] + 13.2) < 0.05


def test_ramp_jump_boost_parametric_math() -> None:
    sys.path.insert(0, str(PROJECT_ROOT / "scripts" / "blender"))
    import generate_track_kit_v1 as gen

    cfg = gen.TrackKitConfig(_kit())
    ramp = cfg.spec("ramp_small")
    jump = cfg.spec("jump_small")
    boost = cfg.spec("boost_straight")
    r0 = gen.frame_at(cfg, ramp, 0.0)
    r1 = gen.frame_at(cfg, ramp, 1.0)
    assert r0["pos"] == (0.0, 0.0, 0.0)
    assert abs(r0["pitch"]) < 1e-9
    assert abs(r1["pos"][1] - 1.8) < 1e-9
    assert r1["pos"][2] == -12.0
    assert abs(math.degrees(r1["pitch"]) - 18.0) < 0.01
    assert abs(math.degrees(r1["pitch"]) - jump["entry_pitch_deg"]) < 0.01
    j0 = gen.frame_at(cfg, jump, 0.0)
    assert abs(j0["pitch"] - r1["pitch"]) < 1e-9
    lip = float(jump["ramp_length_m"])
    gap = float(jump["gap_m"])
    land = float(jump["land_length_m"])
    mid_gap = gen.frame_at(cfg, jump, (lip + gap * 0.5) / (lip + gap + land))
    assert mid_gap["solid"] is False
    land_fr = gen.frame_at(cfg, jump, 1.0)
    assert land_fr["solid"] is True
    assert land_fr["pos"][1] == -0.85
    boxes = gen.TrackPieceBuilder(cfg).collision_boxes(jump)
    road = [b for b in boxes if b["kind"] == "road"]
    assert road
    gap_z = -(lip + gap * 0.5)
    for box in road:
        z = box["origin"][2]
        half = box["size"][2] * 0.5
        assert not (z - half <= gap_z <= z + half)
    b0 = gen.frame_at(cfg, boost, 0.0)
    b1 = gen.frame_at(cfg, boost, 1.0)
    assert b0["pitch"] == 0.0
    assert b1["pos"][2] == -12.0
    assert boost["boost_strength"] == 1.35


def test_processed_body_mesh_is_already_minus_z_nose() -> None:
    """Measured authority: processed Body centroid is on the FL/FR (-Z) side."""
    path = PROJECT_ROOT / "assets/vehicles/track/processed/track_car_base_v2_articulated.glb"
    data = path.read_bytes()
    json_len = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20 : 20 + json_len])
    off = 20 + json_len
    if off % 4:
        off += 4 - (off % 4)
    blob = data[off + 8 : off + 8 + struct.unpack_from("<I", data, off)[0]]
    nodes = {n.get("name"): n for n in doc["nodes"]}
    fl_z = nodes["Wheel_FL"].get("translation", [0, 0, 0])[2]
    rl_z = nodes["Wheel_RL"].get("translation", [0, 0, 0])[2]
    assert fl_z < 0.0
    assert rl_z > 0.0
    acc = doc["accessors"][doc["meshes"][nodes["Body"]["mesh"]]["primitives"][0]["attributes"]["POSITION"]]
    bv = doc["bufferViews"][acc["bufferView"]]
    start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    zs = [
        struct.unpack_from("<f", blob, start + i * 12 + 8)[0]
        for i in range(acc["count"])
    ]
    centroid_z = sum(zs) / len(zs)
    assert centroid_z < 0.0
    assert sum(1 for z in zs if z < -0.15) > sum(1 for z in zs if z > 0.15)


def test_generator_extended_cli_and_refuses_all() -> None:
    src = _read("scripts/blender/generate_track_kit_v1.py")
    assert "--extended" in src
    assert "--clean-gap" in src
    assert "EXTENDED_PHYSICS" in src
    assert "class ElevationBuilder" in src
    assert "class SpecialBuilder" in src
    assert "math.tan(launch)" in src
    result = subprocess.run(
        [sys.executable, str(PROJECT_ROOT / "scripts/blender/generate_track_kit_v1.py"), "--all"],
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    assert result.returncode == 2


def test_extended_lab_and_import_flags() -> None:
    assert (PROJECT_ROOT / "scenes/debug/Track4WheelExtendedPhysicsLab.tscn").exists()
    lab = _read("scripts/track/track_4wheel_extended_physics_lab.gd")
    assert "ramp_small" in lab
    assert "jump_small" in lab
    assert "boost_straight" in lab
    assert 'CONTROLLER_MODE := "FOUR_WHEEL_V1"' in _read("scripts/track/track_config.gd")
    for name in ALL_GLBS:
        text = (CORE / (name + ".import")).read_text(encoding="utf-8")
        assert "gltf/embedded_image_handling=0" in text
        assert "animation/import=false" in text
    assert (PROJECT_ROOT / "docs/TRACK_4WHEEL_ARTICULATED_EXTENDED_VALIDATION_V1_REPORT.md").exists()
    assert (PROJECT_ROOT / "docs/TRACK_4WHEEL_VISUAL_TRANSFORM_REPAIR_AND_EXTENDED_DYNAMICS_V2_REPORT.md").exists()
