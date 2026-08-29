"""Rest-axis solver V1 (Idle only) — does not replace production V4."""

from pathlib import Path
import hashlib
import json
import struct


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_FBM = {
    "terere": "29aedd817e4fbf69",
    "jaguarete": "654179021409871a",
}


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _json(rel: str) -> dict:
    return json.loads(_read(rel))


def _sha16(path: Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()[:16]


def _glb_json(path: Path) -> dict:
    with path.open("rb") as fh:
        magic = fh.read(4)
        assert magic == b"glTF", path
        _version, _length = struct.unpack("<II", fh.read(8))
        chunk_len, chunk_type = struct.unpack("<I4s", fh.read(8))
        payload = fh.read(chunk_len)
        assert chunk_type in (b"JSON", b"json")
    return json.loads(payload.decode("utf-8"))


def test_true_rest_pose_used_not_frame_1() -> None:
    solver = _read("tools/blender/rest_axis_solver_v1.py")
    math_doc = _read("docs/generated/REST_AXIS_SOLVER_MATH.md")
    mix = _json("docs/generated/MIXAMO_REST_BASIS.json")
    ac = _json("docs/generated/ACTORCORE_REST_BASIS.json")
    assert "edit_bone.matrix_local_with_pose_cleared" in solver
    assert mix["rest_source"] == "edit_bone.matrix_local_with_pose_cleared"
    assert ac["rest_source"] == "edit_bone.matrix_local_with_pose_cleared"
    assert mix["frame_1_is_not_bind_pose"] is True
    assert ac["frame_1_is_not_bind_pose"] is True
    assert "Frame 1" in math_doc
    hips = mix["bones"]["mixamorig5:Hips"]
    hip = ac["bones"]["CC_Base_Hip"]
    assert hips["rest_is_edit_bone"] is True
    assert hip["parent_relative_rest"]
    assert "axes_world" in hips and "roll" in hips
    assert "axes_world" in hip and "roll" in hip


def test_per_bone_basis_conversion_exists() -> None:
    c_bones = _json("docs/generated/SOLVER_V1_C_BONES.json")
    assert c_bones["uses_frame_1_as_bind"] is False
    assert "CC_Base_L_Upperarm" in c_bones["bones"]
    arm = c_bones["bones"]["CC_Base_L_Upperarm"]
    assert len(arm["C"]) == 16
    assert arm["source"] == "mixamorig5:LeftArm"
    math_doc = _read("docs/generated/REST_AXIS_SOLVER_MATH.md")
    assert "C_bone = T^-1 * S" in math_doc
    assert "R_tgt = C_bone * R_src * C_bone^-1" in math_doc


def test_source_frame_1_is_not_treated_as_bind_pose() -> None:
    solver = _read("tools/blender/rest_axis_solver_v1.py")
    export_v4 = _read("tools/blender/export_actorcore_game_ready.py")
    assert "capture_clip_reference_quats" not in solver
    assert "apply_clip_relative_rotation" not in solver
    assert "uses_frame_1_as_bind" in solver
    # Production V4 still uses clip-relative; solver must not.
    assert "apply_clip_relative_rotation" in export_v4
    for name in ("TERERE_IDLE_SOLVER_V1_METRICS.json", "JAGUARETE_IDLE_SOLVER_V1_METRICS.json"):
        data = _json("docs/generated/" + name)
        assert data["uses_frame_1_as_bind"] is False
        assert data["rest_source"] == "edit_bone.matrix_local_with_pose_cleared"


def test_volume_gate() -> None:
    for name in ("TERERE_IDLE_SOLVER_V1_METRICS.json", "JAGUARETE_IDLE_SOLVER_V1_METRICS.json"):
        data = _json("docs/generated/" + name)
        assert data["volume_limit"] == 1.35
        assert data["axis_limit"] == 1.30
        assert "max_volume_ratio" in data
        expected = data["max_volume_ratio"] <= 1.35 and data["max_axis_ratio"] <= 1.30
        assert data["volume_pass"] is expected


def test_bone_length_invariance() -> None:
    for name in ("TERERE_IDLE_SOLVER_V1_METRICS.json", "JAGUARETE_IDLE_SOLVER_V1_METRICS.json"):
        data = _json("docs/generated/" + name)
        assert data["length_pass"] is True
        assert data["max_limb_length_rel_error"] <= data["length_rel_tol"]


def test_tpose_detection() -> None:
    solver = _read("tools/blender/rest_axis_solver_v1.py")
    assert 'return "T_POSE_LIKE"' in solver
    assert 'return "STANDING_IDLE"' in solver
    assert 'return "DEFORMATION_INVALID"' in solver
    for name in ("TERERE_IDLE_SOLVER_V1_METRICS.json", "JAGUARETE_IDLE_SOLVER_V1_METRICS.json"):
        data = _json("docs/generated/" + name)
        assert data["idle_pose_classification"] in {
            "STANDING_IDLE",
            "T_POSE_LIKE",
            "DEFORMATION_INVALID",
        }
        assert "mean_upperarm_from_down_deg" in data["mid_frame_angles"]


def test_terere_and_jaguarete_solver_outputs_exist() -> None:
    for rel in (
        "assets/fighters/processed/solver_v1/terere/terere_idle_solver_v1.glb",
        "assets/fighters/processed/solver_v1/jaguarete/jaguarete_idle_solver_v1.glb",
        "assets/fighters/processed/solver_v1/terere/terere_idle_solver_v1_preview.blend",
        "assets/fighters/processed/solver_v1/jaguarete/jaguarete_idle_solver_v1_preview.blend",
    ):
        path = PROJECT_ROOT / rel
        assert path.is_file(), path
        assert path.stat().st_size > 10_000
    for rel in (
        "assets/fighters/processed/solver_v1/terere/terere_idle_solver_v1.glb",
        "assets/fighters/processed/solver_v1/jaguarete/jaguarete_idle_solver_v1.glb",
    ):
        data = _glb_json(PROJECT_ROOT / rel)
        names = [a.get("name", "") for a in data.get("animations", [])]
        assert any("idle" in n.lower() for n in names), names
        assert data.get("skins")
        mixamo = [n.get("name", "") for n in data.get("nodes", []) if "mixamo" in n.get("name", "").lower()]
        assert mixamo == [], mixamo


def test_textures_remain_character_specific() -> None:
    ter = _json("docs/generated/TERERE_IDLE_SOLVER_V1_METRICS.json")["texture_hashes"]
    jag = _json("docs/generated/JAGUARETE_IDLE_SOLVER_V1_METRICS.json")["texture_hashes"]
    assert ter["diffuse"] == SOURCE_FBM["terere"]
    assert jag["diffuse"] == SOURCE_FBM["jaguarete"]
    assert ter["diffuse"] != jag["diffuse"]


def test_production_v4_remains_untouched() -> None:
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    terere = _read("fighters/terere/terere_actorcore_visual.gd")
    jaguarete = _read("fighters/jaguarete/jaguarete_actorcore_visual.gd")
    for blob in (catalog, terere, jaguarete):
        assert "game_ready_v4.glb" in blob
        assert "solver_v1" not in blob
    for rel in (
        "assets/fighters/processed/terere/terere_game_ready_v4.glb",
        "assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb",
    ):
        path = PROJECT_ROOT / rel
        assert path.is_file()
        data = _glb_json(path)
        names = [a.get("name", "") for a in data.get("animations", [])]
        assert any("idle" in n.lower() for n in names)
    method = _json("docs/generated/SOLVER_V1_SELECTED_METHOD.json")
    assert method["shared_by"] == ["terere", "jaguarete"]
    ter_m = _json("docs/generated/TERERE_IDLE_SOLVER_V1_METRICS.json")
    jag_m = _json("docs/generated/JAGUARETE_IDLE_SOLVER_V1_METRICS.json")
    assert ter_m["method"] == jag_m["method"] == method["method"]
    assert "if character ==" not in _read("tools/blender/rest_axis_solver_v1.py")
    guard = _json("docs/generated/SOLVER_V1_V4_UNTOUCHED.json")
    terere_v4 = PROJECT_ROOT / "assets/fighters/processed/terere/terere_game_ready_v4.glb"
    jaguarete_v4 = PROJECT_ROOT / "assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb"
    assert hashlib.sha256(terere_v4.read_bytes()).hexdigest().upper() == guard["terere_game_ready_v4_sha256"]
    assert hashlib.sha256(jaguarete_v4.read_bytes()).hexdigest().upper() == guard["jaguarete_game_ready_v4_sha256"]


def test_godot_solver_labs_exist() -> None:
    assert (PROJECT_ROOT / "scenes/debug/TerereSolverV1Lab.tscn").is_file()
    assert (PROJECT_ROOT / "scenes/debug/JaguareteSolverV1Lab.tscn").is_file()
    lab = _read("scripts/debug/solver_v1_animation_lab.gd")
    assert "VOLUME_RATIO" in lab
    assert "POSE" in lab
    assert "BATTLE OFF" in lab
    assert "KEY_4" in lab
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert "solver_v1" not in catalog
