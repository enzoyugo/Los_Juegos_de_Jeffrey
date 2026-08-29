"""Semantic Idle solver V2 — native-axis reconstruction, not Mixamo matrix copy."""

from pathlib import Path
import hashlib
import json
import struct


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_FBM = {
    "terere": "29aedd817e4fbf69",
    "jaguarete": "654179021409871a",
}
V4_HASHES = {
    "terere": "D880B8E9FE03F8F0169728259A0C51F0A931AED401B4AA30A32BCED94EA0CEBE",
    "jaguarete": "460BEE0AF4CF0CE3F9550948E3E69D349A9E3C1D1EFADE786178C8E5D639553C",
}
CRITICAL_BONES = [
    "CC_Base_Hip",
    "CC_Base_Spine01",
    "CC_Base_Spine02",
    "CC_Base_NeckTwist01",
    "CC_Base_Head",
    "CC_Base_L_Clavicle",
    "CC_Base_R_Clavicle",
    "CC_Base_L_Upperarm",
    "CC_Base_R_Upperarm",
    "CC_Base_L_Forearm",
    "CC_Base_R_Forearm",
    "CC_Base_L_Hand",
    "CC_Base_R_Hand",
    "CC_Base_L_Thigh",
    "CC_Base_R_Thigh",
    "CC_Base_L_Calf",
    "CC_Base_R_Calf",
    "CC_Base_L_Foot",
    "CC_Base_R_Foot",
]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _json(rel: str) -> dict:
    return json.loads(_read(rel))


def _glb_json(path: Path) -> dict:
    with path.open("rb") as fh:
        magic = fh.read(4)
        assert magic == b"glTF", path
        _version, _length = struct.unpack("<II", fh.read(8))
        chunk_len, chunk_type = struct.unpack("<I4s", fh.read(8))
        payload = fh.read(chunk_len)
        assert chunk_type in (b"JSON", b"json")
    return json.loads(payload.decode("utf-8"))


def test_native_axis_profile_exists() -> None:
    profile = _json("docs/generated/ACTORCORE_NATIVE_AXIS_PROFILE.json")
    assert profile["skeleton"] == "CC_Base"
    assert profile["shared_by"] == ["terere", "jaguarete"]
    assert profile["no_mixamo_quaternion_copy"] is True
    assert profile["twist_bones_not_directly_animated"] is True
    bones = profile["bones"]
    for name in CRITICAL_BONES:
        assert name in bones, name
        info = bones[name]
        assert info["derived_by"] == "controlled_native_articulation"
        assert info["primary_flexion_axis"] in {"LOCAL_X", "LOCAL_Y", "LOCAL_Z"}
        assert info["lowering_sign"] in (-1.0, 1.0, -1, 1)
        assert info["twist_axis"] == "LOCAL_Y"
        assert len(info["safe_range"]) == 2
    assert bones["CC_Base_L_Upperarm"]["primary_flexion_axis"] == "LOCAL_Z"
    assert bones["CC_Base_R_Upperarm"]["primary_flexion_axis"] == "LOCAL_Z"
    assert bones["CC_Base_L_Forearm"]["primary_flexion_axis"] == "LOCAL_X"
    assert bones["CC_Base_R_Forearm"]["primary_flexion_axis"] == "LOCAL_X"


def test_canonical_standing_pose_exists() -> None:
    standing = _json("docs/generated/ACTORCORE_CANONICAL_STANDING_POSE.json")
    assert standing["idle_animates_around"] == "canonical_standing_not_tpose"
    angles = standing["angles_deg_native_axis"]
    assert angles["CC_Base_L_Upperarm"] >= 55.0
    assert angles["CC_Base_R_Upperarm"] >= 55.0
    assert angles["CC_Base_L_Forearm"] >= 8.0
    assert "CC_Base_L_Clavicle" in angles
    assert "CC_Base_L_Hand" in angles
    assert standing["quality_on_terere_source"]["arms_lowered_from_tpose"] is True
    assert standing["quality_on_terere_source"]["mean_upperarm_from_down_deg"] < 70.0
    assert "terere" in standing["shared_by"] and "jaguarete" in standing["shared_by"]
    chain = standing["arm_chain_ops"]
    assert chain["terere"]["CC_Base_L_Upperarm"]["primary"] >= 55.0
    assert chain["jaguarete"]["CC_Base_L_Upperarm"]["primary"] >= 45.0


def test_mixamo_semantic_channels_exist() -> None:
    data = _json("docs/generated/MIXAMO_IDLE_SEMANTIC_CHANNELS.json")
    assert data["copies_mixamo_quaternion"] is False
    assert data["method"] == "anatomical_world_angles_not_quaternions"
    assert data["rest_is_edit_bind"] is True
    assert "Idle.fbx" in data["source"]
    for key in (
        "L_shoulder_lowering",
        "R_shoulder_lowering",
        "L_elbow_flexion",
        "R_elbow_flexion",
        "torso_lean",
        "head_lean",
        "L_knee_flexion",
        "R_knee_flexion",
    ):
        assert key in data["rest_channels"]
        assert key in data["standing_channels"]
    assert data["rest_channels"]["L_shoulder_lowering"] > 80.0
    assert data["standing_channels"]["L_shoulder_lowering"] < 70.0
    assert len(data["frames"]) >= 100
    frame = data["frames"][0]
    assert "intra_idle_delta_from_standing" in frame
    assert "channels_vs_mixamo_world" in frame
    assert "quaternion" not in frame
    assert "matrix" not in frame


def test_no_direct_mixamo_quaternion_copy() -> None:
    solver = _read("tools/blender/semantic_idle_solver_v2.py")
    assert "Does NOT copy Mixamo quaternions or matrix_basis" in solver
    assert "Never Mixamo quaternions" in solver
    assert "apply_clip_relative_rotation" not in solver
    assert "capture_clip_reference_quats" not in solver
    bake = solver.split("def bake_character")[1].split("def main")[0]
    assert "IDLE_FBX" not in bake
    assert "mixamorig" not in bake
    assert "matrix_basis" not in bake
    assert "apply_standing_plus_deltas" in bake
    ter = _json("docs/generated/TERERE_IDLE_SEMANTIC_V2_METRICS.json")
    jag = _json("docs/generated/JAGUARETE_IDLE_SEMANTIC_V2_METRICS.json")
    assert ter["copies_mixamo_quaternion"] is False
    assert jag["copies_mixamo_quaternion"] is False
    assert ter["idle_around"] == jag["idle_around"] == "canonical_standing"
    assert ter["shared_generic_solver"] is True
    assert jag["shared_generic_solver"] is True


def test_production_v4_unchanged() -> None:
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    terere = _read("fighters/terere/terere_actorcore_visual.gd")
    jaguarete = _read("fighters/jaguarete/jaguarete_actorcore_visual.gd")
    for blob in (catalog, terere, jaguarete):
        assert "game_ready_v4.glb" in blob
        assert "semantic_solver_v2" not in blob
        assert "solver_v1" not in blob
    terere_v4 = PROJECT_ROOT / "assets/fighters/processed/terere/terere_game_ready_v4.glb"
    jaguarete_v4 = PROJECT_ROOT / "assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb"
    assert hashlib.sha256(terere_v4.read_bytes()).hexdigest().upper() == V4_HASHES["terere"]
    assert hashlib.sha256(jaguarete_v4.read_bytes()).hexdigest().upper() == V4_HASHES["jaguarete"]


def test_solver_outputs_exist() -> None:
    for rel in (
        "assets/fighters/processed/semantic_solver_v2/terere/terere_idle_semantic_v2.glb",
        "assets/fighters/processed/semantic_solver_v2/jaguarete/jaguarete_idle_semantic_v2.glb",
        "assets/fighters/processed/semantic_solver_v2/terere/terere_idle_semantic_v2_preview.blend",
        "assets/fighters/processed/semantic_solver_v2/jaguarete/jaguarete_idle_semantic_v2_preview.blend",
    ):
        path = PROJECT_ROOT / rel
        assert path.is_file(), path
        assert path.stat().st_size > 10_000
    for rel in (
        "assets/fighters/processed/semantic_solver_v2/terere/terere_idle_semantic_v2.glb",
        "assets/fighters/processed/semantic_solver_v2/jaguarete/jaguarete_idle_semantic_v2.glb",
    ):
        data = _glb_json(PROJECT_ROOT / rel)
        names = [a.get("name", "").lower() for a in data.get("animations", [])]
        joined = " ".join(names)
        assert "idle" in joined, names
        assert "rest" in joined, names
        assert "standing" in joined, names
        assert data.get("skins")
        mixamo = [n.get("name", "") for n in data.get("nodes", []) if "mixamo" in n.get("name", "").lower()]
        assert mixamo == [], mixamo


def test_textures_remain_character_specific() -> None:
    ter = _json("docs/generated/TERERE_IDLE_SEMANTIC_V2_METRICS.json")["texture_hashes"]
    jag = _json("docs/generated/JAGUARETE_IDLE_SEMANTIC_V2_METRICS.json")["texture_hashes"]
    assert ter["diffuse"] == SOURCE_FBM["terere"]
    assert jag["diffuse"] == SOURCE_FBM["jaguarete"]
    assert ter["diffuse"] != jag["diffuse"]


def test_volume_gate_and_pose_classification() -> None:
    for name in ("TERERE_IDLE_SEMANTIC_V2_METRICS.json", "JAGUARETE_IDLE_SEMANTIC_V2_METRICS.json"):
        data = _json("docs/generated/" + name)
        assert data["volume_limit"] == 1.35
        assert data["axis_limit"] == 1.30
        expected = data["max_volume_ratio"] <= 1.35 and data["max_axis_ratio"] <= 1.30
        assert data["volume_pass"] is expected
        assert data["idle_pose_classification"] in {
            "STANDING_IDLE",
            "T_POSE_LIKE",
            "DEFORMATION_INVALID",
        }
        assert data["mid_frame"]["quality"]["arms_lowered_from_tpose"] is True
        assert data["mid_frame"]["quality"]["mean_upperarm_from_down_deg"] < 70.0


def test_limb_length_invariance_and_no_extreme_vertices() -> None:
    for name in ("TERERE_IDLE_SEMANTIC_V2_METRICS.json", "JAGUARETE_IDLE_SEMANTIC_V2_METRICS.json"):
        data = _json("docs/generated/" + name)
        assert data["length_pass"] is True
        assert data["max_limb_length_rel_error"] <= data["length_rel_tol"]
        assert data["max_extreme_vertices"] == 0


def test_channel_isolation_recorded() -> None:
    iso = _json("docs/generated/SEMANTIC_V2_CHANNEL_ISOLATION.json")
    for fighter in ("terere", "jaguarete"):
        assert fighter in iso
        for group in ("A_arms", "B_torso_head", "C_legs", "D_combined"):
            assert group in iso[fighter]
            assert "volume_ratio" in iso[fighter][group]
            assert "idle_pose_classification" in iso[fighter][group]


def test_generic_cc_base_solver() -> None:
    solver = _read("tools/blender/semantic_idle_solver_v2.py")
    assert 'if character == "terere"' not in solver
    assert "if character == 'jaguarete'" not in solver
    ter = _json("docs/generated/TERERE_IDLE_SEMANTIC_V2_METRICS.json")
    jag = _json("docs/generated/JAGUARETE_IDLE_SEMANTIC_V2_METRICS.json")
    assert ter["solver"] == jag["solver"] == "semantic_idle_solver_v2"
    standing = _json("docs/generated/ACTORCORE_CANONICAL_STANDING_POSE.json")
    assert standing["shared_by"] == ["terere", "jaguarete"]


def test_godot_labs_exist_and_not_wired_to_battle() -> None:
    assert (PROJECT_ROOT / "scenes/debug/TerereSemanticSolverV2Lab.tscn").is_file()
    assert (PROJECT_ROOT / "scenes/debug/JaguareteSemanticSolverV2Lab.tscn").is_file()
    lab = _read("scripts/debug/semantic_solver_v2_lab.gd")
    assert "VOLUME_RATIO" in lab
    assert "POSE" in lab
    assert "IDLE_SOURCE" in lab
    assert "ROOT_XZ" in lab
    assert "KEY_3" in lab
    assert "BATTLE OFF" in lab
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert "semantic_solver_v2" not in catalog
    playground = _read("scenes/core/M0Playground.tscn") if (PROJECT_ROOT / "scenes/core/M0Playground.tscn").is_file() else ""
    assert "SemanticSolverV2" not in playground


def _glb_anim_quat(glb: dict, blob: bytes, clip: str, bone: str):
    import struct as _st
    nodes = glb.get("nodes", [])
    anim = next(a for a in glb["animations"] if a.get("name") == clip)
    node_idx = next(i for i, n in enumerate(nodes) if n.get("name") == bone)
    ch = next(c for c in anim["channels"] if c["target"]["node"] == node_idx and c["target"]["path"] == "rotation")
    acc = glb["accessors"][anim["samplers"][ch["sampler"]]["output"]]
    view = glb["bufferViews"][acc["bufferView"]]
    off = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    return _st.unpack_from("<ffff", blob, off)


def _glb_blob(path: Path) -> bytes:
    data = path.read_bytes()
    import struct as _st
    _magic, _ver, _length = _st.unpack_from("<4sII", data, 0)
    off = 12
    json_len, json_type = _st.unpack_from("<I4s", data, off)
    off += 8 + json_len
    bin_len, bin_type = _st.unpack_from("<I4s", data, off)
    off += 8
    return data[off:off + bin_len]


def test_standing_arm_clip_is_not_rest() -> None:
    """Canonical standing must not export the T-pose rest quaternion on upperarms."""
    for rel in (
        "assets/fighters/processed/semantic_solver_v2/terere/terere_idle_semantic_v2.glb",
        "assets/fighters/processed/semantic_solver_v2/jaguarete/jaguarete_idle_semantic_v2.glb",
    ):
        path = PROJECT_ROOT / rel
        glb = _glb_json(path)
        blob = _glb_blob(path)
        rest_q = _glb_anim_quat(glb, blob, "rest", "CC_Base_L_Upperarm")
        stand_q = _glb_anim_quat(glb, blob, "canonical_standing", "CC_Base_L_Upperarm")
        idle_q = _glb_anim_quat(glb, blob, "idle", "CC_Base_L_Upperarm")
        rest_dot_stand = abs(sum(a * b for a, b in zip(rest_q, stand_q)))
        rest_dot_idle = abs(sum(a * b for a, b in zip(rest_q, idle_q)))
        assert rest_dot_stand < 0.97, (rel, rest_q, stand_q, rest_dot_stand)
        assert rest_dot_idle < 0.97, (rel, rest_q, idle_q, rest_dot_idle)


def test_arm_chain_keyed_and_action_order_fixed() -> None:
    solver = _read("tools/blender/semantic_idle_solver_v2.py")
    assert "ARM_CHAIN_BONES" in solver
    assert "CC_Base_L_Clavicle" in solver
    assert "Assigning an empty action resets pose" in solver
    assert "new_action(target, \"canonical_standing\")" in solver
    audit = _json("docs/generated/SEMANTIC_V2_ARM_CHAIN_AUDIT.json")
    for fighter in ("terere", "jaguarete"):
        row = audit[fighter]
        assert row["twist_helper_bones_keyed"] is False
        rest_ang = row["rest"]["bones"]["CC_Base_L_Upperarm"]["from_down_deg"]
        stand_ang = row["canonical_standing"]["bones"]["CC_Base_L_Upperarm"]["from_down_deg"]
        assert rest_ang > 70.0
        assert stand_ang < 55.0
        assert stand_ang < rest_ang - 20.0


def test_hand_chain_standing_differs_from_rest() -> None:
    solver = _read("tools/blender/semantic_idle_solver_v2.py")
    assert "HAND_BONES" in solver
    assert "resolve_hand_down_sign" in solver
    assert "resolve_palm_inward_sign" in solver
    assert "CC_Base_L_HandTwist" not in solver.split("def key_driven_bones")[1].split("def dump_authorities")[0]
    standing = _json("docs/generated/ACTORCORE_CANONICAL_STANDING_POSE.json")
    for fighter in ("terere", "jaguarete"):
        hands = standing["arm_chain_ops"][fighter]
        assert hands["CC_Base_L_Hand"]["primary"] > 0.0
        assert hands["CC_Base_R_Hand"]["primary"] > 0.0
        assert hands["CC_Base_L_Hand"]["palm"] > 0.0
    for rel in (
        "assets/fighters/processed/semantic_solver_v2/terere/terere_idle_semantic_v2.glb",
        "assets/fighters/processed/semantic_solver_v2/jaguarete/jaguarete_idle_semantic_v2.glb",
    ):
        path = PROJECT_ROOT / rel
        glb = _glb_json(path)
        blob = _glb_blob(path)
        rest_q = _glb_anim_quat(glb, blob, "rest", "CC_Base_L_Hand")
        stand_q = _glb_anim_quat(glb, blob, "canonical_standing", "CC_Base_L_Hand")
        idle_q = _glb_anim_quat(glb, blob, "idle", "CC_Base_L_Hand")
        rest_dot_stand = abs(sum(a * b for a, b in zip(rest_q, stand_q)))
        idle_dot_stand = abs(sum(a * b for a, b in zip(idle_q, stand_q)))
        assert rest_dot_stand < 0.995, (rel, rest_q, stand_q, rest_dot_stand)
        assert idle_dot_stand > 0.90, (rel, idle_q, stand_q, idle_dot_stand)
    audit = _json("docs/generated/SEMANTIC_V2_HAND_CHAIN_AUDIT.json")
    for fighter in ("terere", "jaguarete"):
        row = audit[fighter]
        assert row["twist_helper_bones_keyed"] is False
        assert row["finger_bones_keyed"] is False
        assert row["standing_hand_differs_from_rest"] is True
        rest_ang = row["rest"]["CC_Base_L_Hand"]["quat_angle_deg"]
        stand_ang = row["canonical_standing"]["CC_Base_L_Hand"]["quat_angle_deg"]
        assert stand_ang > rest_ang + 2.0
