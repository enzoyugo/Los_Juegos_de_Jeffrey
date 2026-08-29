"""Clean Rig V1 Idle retarget benchmark V1. Does not replace production V4."""

from pathlib import Path
import hashlib
import json
import struct


PROJECT_ROOT = Path(__file__).resolve().parents[1]
V4_HASHES = {
    "terere": "D880B8E9FE03F8F0169728259A0C51F0A931AED401B4AA30A32BCED94EA0CEBE",
    "jaguarete": "460BEE0AF4CF0CE3F9550948E3E69D349A9E3C1D1EFADE786178C8E5D639553C",
}
SOURCE_FBM = {
    "terere": "29aedd817e4fbf69",
    "jaguarete": "654179021409871a",
}
MAPPED = [
    ("Hips", "CC_Base_Hip"),
    ("Spine", "CC_Base_Waist"),
    ("Spine1", "CC_Base_Spine01"),
    ("Spine2", "CC_Base_Spine02"),
    ("Neck", "CC_Base_NeckTwist01"),
    ("Head", "CC_Base_Head"),
    ("LeftShoulder", "CC_Base_L_Clavicle"),
    ("LeftArm", "CC_Base_L_Upperarm"),
    ("LeftForeArm", "CC_Base_L_Forearm"),
    ("LeftHand", "CC_Base_L_Hand"),
    ("RightShoulder", "CC_Base_R_Clavicle"),
    ("RightArm", "CC_Base_R_Upperarm"),
    ("RightForeArm", "CC_Base_R_Forearm"),
    ("RightHand", "CC_Base_R_Hand"),
    ("LeftUpLeg", "CC_Base_L_Thigh"),
    ("LeftLeg", "CC_Base_L_Calf"),
    ("LeftFoot", "CC_Base_L_Foot"),
    ("RightUpLeg", "CC_Base_R_Thigh"),
    ("RightLeg", "CC_Base_R_Calf"),
    ("RightFoot", "CC_Base_R_Foot"),
]
FORBIDDEN = (
    "game_ready_v4",
    "game_ready_v3",
    "semantic_solver_v2",
    "solver_v1",
    "actorcore_benchmark",
    "native_skin_audit",
)


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _json(rel: str) -> dict:
    return json.loads(_read(rel))


def _sha16(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:16]


def _glb_json(path: Path) -> dict:
    with path.open("rb") as fh:
        magic = fh.read(4)
        assert magic == b"glTF", path
        _version, _length = struct.unpack("<II", fh.read(8))
        chunk_len, chunk_type = struct.unpack("<I4s", fh.read(8))
        payload = fh.read(chunk_len)
        assert chunk_type in (b"JSON", b"json")
    return json.loads(payload.decode("utf-8"))


def _glb_nodes(data: dict) -> list:
    return [n.get("name", "") for n in data.get("nodes", [])]


def test_clean_rig_v1_is_benchmark_target() -> None:
    baseline = _json("docs/generated/CLEAN_RIG_IDLE_BENCHMARK_BASELINE.json")
    assert baseline["pipeline"] == "CLEAN_RIG_V1"
    for fighter in ("terere", "jaguarete"):
        row = baseline["fighters"][fighter]
        assert row["bone_count"] == 101
        assert row["mesh_count"] == 1
        assert row["has_cc_base_hip"] is True
        assert "clean_rig_v1" in row["glb"]
        assert "clean_rig_v1" in row["blend"]
        assert row["object_transforms"]["armature"]["normalized"] is True
        assert row["object_transforms"]["mesh"]["normalized"] is True
        assert row["rest_tpose_upperarm_from_down_deg"]["L"] > 70.0
        assert row["rest_is_tpose"] is True
        assert row["mesh_armature_aligned"] is True
        assert row["no_hidden_source_rig"] is True
        assert row["cc_base_hierarchy_ok"] is True
        assert row["cc_base_hierarchy"]["CC_Base_Hip"]["parent"] == "root"
        assert row["cc_base_hierarchy"]["CC_Base_L_Thigh"]["parent"] == "CC_Base_Pelvis"
        assert row["cc_base_hierarchy"]["CC_Base_Head"]["parent"] == "CC_Base_NeckTwist02"
        for token in FORBIDDEN:
            assert token not in row["glb"]
            assert token not in row["blend"]


def test_old_v4_is_not_benchmark_target() -> None:
    bake = _read("tools/blender/clean_rig_idle_retarget_benchmark_v1.py")
    assert "clean_rig_v1" in bake
    assert "terere_clean_rig_v1.blend" in bake
    assert "jaguarete_clean_rig_v1.blend" in bake
    assert "game_ready_v4" not in bake.split("CHARACTERS")[1].split("VOLUME_LIMIT")[0]
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert "terere_game_ready_v4.glb" in catalog
    assert "jaguarete_game_ready_v4.glb" in catalog
    assert "idle_benchmark_v1" not in catalog
    lab = _read("scripts/debug/idle_retarget_benchmark_lab.gd")
    for token in FORBIDDEN:
        assert token in lab
    assert "fighter_catalog.gd" not in lab
    assert "FighterDefinition" not in lab


def test_shared_traditional_bone_map() -> None:
    mapping = _json("tools/blender/mixamo_to_cc_base_clean_v1_bone_map.json")
    assert mapping["shared_by"] == ["terere", "jaguarete"]
    assert mapping["target_skeleton"] == "CC_Base"
    assert mapping["rest_source"] == "bind_pose_not_frame_1"
    required = {(e["mixamo_suffix"], e["target"]) for e in mapping["required"]}
    for src, dst in MAPPED:
        assert (src, dst) in required
    mix = _json("docs/generated/MIXAMO_IDLE_FOR_CLEAN_RIG_DUMP.json")
    assert mix["prefix"] == "mixamorig5:"
    assert mix["frame_1_is_not_rest"] is True
    assert mix["rest_is_bind_pose"] is True
    assert mix["frame_start"] == 1
    assert mix["frame_end"] >= 100
    for suffix, _dst in MAPPED:
        assert mix["required_suffixes_present"][suffix] is True


def test_traditional_and_semantic_glbs_exist() -> None:
    for fighter in ("terere", "jaguarete"):
        root = PROJECT_ROOT / "assets/fighters/processed/idle_benchmark_v1" / fighter
        for stem in (
            "%s_idle_traditional_v1" % fighter,
            "%s_idle_semantic_clean_v1" % fighter,
        ):
            glb = root / (stem + ".glb")
            blend = root / (stem + ".blend")
            assert glb.is_file(), glb
            assert blend.is_file(), blend
            assert glb.stat().st_size > 50_000
            data = _glb_json(glb)
            names = [a.get("name", "").lower() for a in data.get("animations", [])]
            assert names, glb
            assert any("idle" in n for n in names), names
            skins = data.get("skins") or []
            assert skins, glb
            joints = skins[0].get("joints") or []
            assert len(joints) == 101, len(joints)
            nodes = _glb_nodes(data)
            assert any("CC_Base_Hip" in n for n in nodes)
            assert not any("mixamo" in n.lower() for n in nodes)


def test_correct_fighter_textures() -> None:
    baseline = _json("docs/generated/CLEAN_RIG_IDLE_BENCHMARK_BASELINE.json")
    for fighter, digest in SOURCE_FBM.items():
        textures = baseline["fighters"][fighter]["textures"]
        names = " ".join(t["name"].lower() for t in textures)
        assert "diffuse" in names
        assert "normal" in names
        fbm = PROJECT_ROOT / "assets/fighters/source_rigged" / fighter / "actorcore/autorig_actor.fbm/model_Pbr_Diffuse.png"
        if fbm.is_file():
            assert _sha16(fbm) == digest


def test_no_legacy_orientation_hacks() -> None:
    lab = _read("scripts/debug/idle_retarget_benchmark_lab.gd")
    assert "legacy_orientation_hack" in lab
    assert "rotation_degrees" not in lab
    bake = _read("tools/blender/clean_rig_idle_retarget_benchmark_v1.py")
    assert "legacy_axis_hack" in bake
    for fighter in ("terere", "jaguarete"):
        for label in ("TRADITIONAL", "SEMANTIC_CLEAN"):
            metrics = _json("docs/generated/%s_IDLE_%s_V1_METRICS.json" % (fighter.upper(), label))
            assert metrics.get("legacy_axis_hack") is False
            assert metrics.get("copies_raw_mixamo_quaternion") is False
            if label == "TRADITIONAL":
                assert metrics.get("uses_frame_1_as_rest") is False


def test_glb_roundtrip_and_volume_gates() -> None:
    ab = _json("docs/generated/CLEAN_RIG_IDLE_AB_COMPARISON.json")
    assert all(row["automatic_winner"] == "HUMAN_REQUIRED" for row in ab["fighters"].values())
    for fighter in ("terere", "jaguarete"):
        rt = _json("docs/generated/%s_IDLE_GLB_ROUNDTRIP_V1.json" % fighter.upper())
        trad = _json("docs/generated/%s_IDLE_TRADITIONAL_V1_METRICS.json" % fighter.upper())
        sem = _json("docs/generated/%s_IDLE_SEMANTIC_CLEAN_V1_METRICS.json" % fighter.upper())
        assert trad["max_volume_ratio"] <= 1.35
        assert sem["max_volume_ratio"] <= 1.35
        assert trad["max_limb_length_rel_error"] <= 0.05
        assert sem["max_limb_length_rel_error"] <= 0.05
        assert trad["pose_classification"] == "DEFORMATION_INVALID"
        assert trad["max_extreme_verts"] > 0
        assert trad["technical_pass"] is False
        assert sem["pose_classification"] == "STANDING_IDLE"
        assert sem["max_extreme_verts"] == 0
        assert sem["technical_pass"] is True
        assert rt["semantic_clean"]["ok"] is True
        assert rt["semantic_clean"]["bone_count"] == 101
        assert rt["semantic_clean"]["pose_classification"] == "STANDING_IDLE"
        assert rt["traditional"]["bone_count"] == 101


def test_one_method_healthy_for_verdict_inputs() -> None:
    run = _json("docs/generated/CLEAN_RIG_IDLE_BENCHMARK_RUN.json")
    ab = _json("docs/generated/CLEAN_RIG_IDLE_AB_COMPARISON.json")
    both_any = True
    for fighter in ("terere", "jaguarete"):
        trad = bool(run[fighter]["traditional_pass"])
        sem = bool(run[fighter]["semantic_pass"])
        if not (trad or sem):
            both_any = False
        assert run[fighter]["traditional_class"]
        assert run[fighter]["semantic_class"]
    assert ab["at_least_one_method_both_fighters"] == both_any


def test_labs_are_benchmark_only() -> None:
    for rel in (
        "scenes/debug/TerereIdleRetargetBenchmarkV1Lab.tscn",
        "scenes/debug/JaguareteIdleRetargetBenchmarkV1Lab.tscn",
        "scripts/debug/idle_retarget_benchmark_lab.gd",
    ):
        blob = _read(rel)
        assert "idle_benchmark_v1" in blob or "CLEAN_RIG_IDLE_BENCHMARK_V1" in blob
        assert "fighter_catalog.gd" not in blob
        assert 'preload("res://scripts/ui/m0_hud.gd")' not in blob
        assert 'preload("res://scripts/ui/kapes_player_hud.gd")' not in blob
        if rel.endswith(".tscn"):
            assert "m0_hud.gd" not in blob
            assert "kapes_player_hud.gd" not in blob
        assert "terere_game_ready_v4.glb" not in blob
        assert "jaguarete_game_ready_v4.glb" not in blob


def test_hand_arm_and_grounding_reports() -> None:
    for fighter in ("terere", "jaguarete"):
        arms = _json("docs/generated/%s_IDLE_HAND_ARM_QUALITY_V1.json" % fighter.upper())
        ground = _json("docs/generated/%s_IDLE_GROUNDING_V1.json" % fighter.upper())
        for method in ("traditional", "semantic_clean"):
            for key in ("rest", "first", "mid", "last"):
                row = arms[method][key]
                assert "CC_Base_L_Upperarm" in row
                assert "CC_Base_L_Hand" in row
                assert "L_elbow_flex_deg" in row
            assert "foot_drift" in ground[method]
            assert "root_xz" in ground[method]
            assert "hip_z_variance" in ground[method]


def test_godot_labs_structurally_valid() -> None:
    data = _json("docs/generated/CLEAN_RIG_IDLE_RETARGET_BENCHMARK_V1_GODOT.json")
    assert data["all_ok"] is True
    assert len(data["labs"]) == 2
    for lab in data["labs"]:
        dump = lab["dump"]
        assert dump["load_ok"] is True
        assert dump["bone_count"] == 101
        assert dump["idle_tracks"] >= 8
        assert dump["runtime_retarget"] is False
        assert dump["proxy_idle"] is False
        assert dump["legacy_orientation_hack"] is False
        assert dump["fallback"] is False
        assert "idle_benchmark_v1" in dump["traditional_glb"]
        assert "idle_benchmark_v1" in dump["semantic_glb"]
        assert "clean_rig_v1" in dump["rest_glb"]
        for token in FORBIDDEN:
            assert token not in dump["traditional_glb"]
            assert token not in dump["semantic_glb"]
            assert token not in dump["rest_glb"]


def test_production_v4_sha_unchanged() -> None:
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert "pipeline_id = \"ACTORCORE_V4\"" in catalog
    terere = PROJECT_ROOT / "assets/fighters/processed/terere/terere_game_ready_v4.glb"
    jaguarete = PROJECT_ROOT / "assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb"
    assert hashlib.sha256(terere.read_bytes()).hexdigest().upper() == V4_HASHES["terere"]
    assert hashlib.sha256(jaguarete.read_bytes()).hexdigest().upper() == V4_HASHES["jaguarete"]
