"""Focused ActorCore idle benchmark checks. Production catalog and combat tests stay in test_m0_combat.py."""

from pathlib import Path
import json
import struct


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _glb_json(path: Path) -> dict:
    with path.open("rb") as fh:
        magic = fh.read(4)
        assert magic == b"glTF", path
        _version, _length = struct.unpack("<II", fh.read(8))
        chunk_len, chunk_type = struct.unpack("<I4s", fh.read(8))
        payload = fh.read(chunk_len)
        assert chunk_type in (b"JSON", b"json")
    return json.loads(payload.decode("utf-8"))


def _glb_animation_names(path: Path) -> list:
    data = _glb_json(path)
    return [a.get("name", "") for a in data.get("animations", [])]


def test_actorcore_packages_exist_with_fbx() -> None:
    for char in ("terere", "jaguarete"):
        root = PROJECT_ROOT / "assets/fighters/source_rigged" / char / "actorcore"
        assert (root / "autorig_actor.fbx").is_file()
        assert (root / "autorig_actor.json").is_file()
        assert (root / "autorig_actor.fbm").is_dir()


def test_shared_critical_bone_hierarchy() -> None:
    eq = json.loads((PROJECT_ROOT / "docs/generated/ACTORCORE_RIG_EQUIVALENCE.json").read_text(encoding="utf-8"))
    assert eq["TOTAL_TERERE_BONES"] == eq["TOTAL_JAGUARETE_BONES"]
    assert eq["COMMON_BONES"] == eq["TOTAL_TERERE_BONES"]
    assert eq["ONLY_TERERE"] == []
    assert eq["ONLY_JAGUARETE"] == []
    assert eq["PARENT_MISMATCHES"] == []
    assert eq["CAN_ONE_SHARED_ACTORCORE_RETARGET_PIPELINE_SUPPORT_BOTH"] is True
    for bone in (
        "CC_Base_Hip",
        "CC_Base_Spine01",
        "CC_Base_Head",
        "CC_Base_L_Upperarm",
        "CC_Base_R_Upperarm",
        "CC_Base_L_Thigh",
        "CC_Base_R_Thigh",
    ):
        crit = eq["CRITICAL_BONES"][bone]
        assert crit["terere"] and crit["jaguarete"] and crit["same_parent"]


def test_generic_retarget_script_and_shared_map_exist() -> None:
    assert (PROJECT_ROOT / "tools/blender/retarget_mixamo_to_actorcore.py").is_file()
    bone_map = json.loads((PROJECT_ROOT / "tools/blender/mixamo_to_actorcore_bone_map.json").read_text(encoding="utf-8"))
    assert bone_map.get("shared_by") == ["terere", "jaguarete"]
    assert bone_map.get("required_count", 0) >= 20
    script = (PROJECT_ROOT / "tools/blender/retarget_mixamo_to_actorcore.py").read_text(encoding="utf-8")
    assert "--character" in script
    assert "terere" in script and "jaguarete" in script
    assert "apply_rest_relative_rotation" in script


def test_benchmark_preview_blends_and_glbs_produced() -> None:
    for char in ("terere", "jaguarete"):
        base = PROJECT_ROOT / "assets/fighters/processed/actorcore_benchmark" / char
        blend = base / f"{char}_actorcore_idle_preview.blend"
        glb = base / f"{char}_actorcore_idle.glb"
        assert blend.is_file(), blend
        assert glb.is_file(), glb
        names = _glb_animation_names(glb)
        assert names, glb
        assert any("idle" in n.lower() for n in names), names


def test_godot_track_dumps_have_multiple_bone_tracks() -> None:
    for name in (
        "docs/generated/TERERE_ACTORCORE_GODOT_TRACKS.txt",
        "docs/generated/JAGUARETE_ACTORCORE_GODOT_TRACKS.txt",
    ):
        text = (PROJECT_ROOT / name).read_text(encoding="utf-8")
        assert "idle" in text.lower()
        assert "BONE_TRACK_COUNT=" in text
        count = int(text.strip().split("BONE_TRACK_COUNT=")[-1].split()[0])
        assert count >= 6, text
        assert "Skeleton3D" in text or "CC_Base_" in text


def test_no_runtime_retarget_in_actorcore_labs() -> None:
    shared = (PROJECT_ROOT / "scripts/debug/actorcore_animation_lab.gd").read_text(encoding="utf-8")
    terere = (PROJECT_ROOT / "scripts/debug/terere_actorcore_animation_lab.gd").read_text(encoding="utf-8")
    jaguarete = (PROJECT_ROOT / "scripts/debug/jaguarete_actorcore_animation_lab.gd").read_text(encoding="utf-8")
    assert "RUNTIME RETARGET: OFF" in shared
    assert "actorcore_benchmark" in terere
    assert "actorcore_benchmark" in jaguarete
    assert "KEY_1" in shared and "KEY_2" in shared
    assert (PROJECT_ROOT / "scenes/debug/TerereActorCoreAnimationLab.tscn").is_file()
    assert (PROJECT_ROOT / "scenes/debug/JaguareteActorCoreAnimationLab.tscn").is_file()


def test_production_fighter_catalog_points_at_actorcore_v3_not_benchmark() -> None:
    catalog = (PROJECT_ROOT / "scripts/fighters/fighter_catalog.gd").read_text(encoding="utf-8")
    assert "actorcore_benchmark" not in catalog
    assert "actorcore_idle" not in catalog
    assert "terere_game_ready_v4.glb" in catalog
    assert "jaguarete_game_ready_v4.glb" in catalog
    terere = (PROJECT_ROOT / "fighters/terere/terere_glb_visual.gd").read_text(encoding="utf-8")
    jaguarete = (PROJECT_ROOT / "fighters/jaguarete/jaguarete_rigged_visual.gd").read_text(encoding="utf-8")
    assert "actorcore_benchmark" not in terere
    assert "actorcore_benchmark" not in jaguarete
    assert "jaguarete_game_ready_idle.glb" in jaguarete
    assert "terere_glb_1.glb" in terere or "terere_v2" in terere


def test_canonical_terere_and_jaguarete_sizes_frozen() -> None:
    terere = (PROJECT_ROOT / "fighters/terere/terere_glb_visual.gd").read_text(encoding="utf-8")
    jaguarete = (PROJECT_ROOT / "fighters/jaguarete/jaguarete_rigged_visual.gd").read_text(encoding="utf-8")
    catalog = (PROJECT_ROOT / "scripts/fighters/fighter_catalog.gd").read_text(encoding="utf-8")
    assert "target_visual_height = 2.40" in terere or "2.40" in terere
    assert "target_visual_height = 3.15" in jaguarete or "3.15" in jaguarete
    assert "target_visual_height = 2.40" in catalog
    assert "target_visual_height = 3.15" in catalog


def test_idle_motion_audits_require_real_articulation() -> None:
    for name in (
        "docs/generated/TERERE_ACTORCORE_IDLE_MOTION_AUDIT.json",
        "docs/generated/JAGUARETE_ACTORCORE_IDLE_MOTION_AUDIT.json",
    ):
        data = json.loads((PROJECT_ROOT / name).read_text(encoding="utf-8"))
        audit = data["motion_audit"]
        assert audit["accepted"] is True
        assert audit["branches_with_motion"] >= 6
        hip = audit["bones"]["Hip"]["rotation_delta_degrees"]
        # Intra-clip idle should articulate, but not explode.
        assert 0.2 < hip < 40.0
        assert audit["bones"]["Spine"]["rotation_delta_degrees"] < 40.0
        assert audit["bones"]["Head"]["rotation_delta_degrees"] < 40.0
        loc = data["bake_metrics"]["root_translation_max_x"]
        assert loc <= 0.05
        assert data["bake_metrics"]["root_translation_max_z"] <= 0.05
