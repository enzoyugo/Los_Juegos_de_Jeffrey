'''Semantic Reaction V1. Isolated hit-reaction bake. Idles frozen. No battle.'''

from pathlib import Path
import hashlib
import json


PROJECT_ROOT = Path(__file__).resolve().parents[1]
V4 = {
    "terere": "D880B8E9FE03F8F0169728259A0C51F0A931AED401B4AA30A32BCED94EA0CEBE",
    "jaguarete": "460BEE0AF4CF0CE3F9550948E3E69D349A9E3C1D1EFADE786178C8E5D639553C",
}
FORBIDDEN = (
    "game_ready_v4",
    "game_ready_v3",
    "semantic_solver_v2",
    "solver_v1",
    "actorcore_benchmark",
    "native_skin_audit",
)
REJECTED = (
    "T_POSE",
    "STANDING_IDLE_ONLY",
    "SIDEWAYS",
    "DEFORMATION_INVALID",
    "ROOT_TRANSLATED",
    "ARM_CHAIN_INVALID",
)


def _read(rel):
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _json(rel):
    return json.loads(_read(rel))


def _sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def test_approved_idle_authorities_unchanged():
    auth = _json("docs/generated/APPROVED_IDLE_AUTHORITIES.json")
    assert auth["immutable"] is True
    terere = auth["fighters"]["terere"]
    jaguarete = auth["fighters"]["jaguarete"]
    assert terere["approval_status"] == "HUMAN_APPROVED"
    assert terere["canonical_pose"] == "POSE_B_GAME_READY"
    assert terere["bone_count"] == 101
    assert terere["animation_name"] == "idle"
    assert terere["do_not_rebake"] is True
    assert _sha256(terere["glb"]) == terere["glb_sha256"]
    assert terere["glb_sha256"] == "9306cfad82cd9a2c0daca67f12be5a4cfc10497061d405982db4647ba47bc7f6"
    assert jaguarete["approval_status"] == "HUMAN_APPROVED_FROZEN"
    assert jaguarete["canonical_pose"] == "APPROVED_SEMANTIC_IDLE_V1"
    assert jaguarete["bone_count"] == 101
    assert jaguarete["animation_name"] == "idle"
    assert jaguarete["do_not_rebake"] is True
    assert _sha256(jaguarete["glb"]) == jaguarete["glb_sha256"]
    assert jaguarete["glb_sha256"] == "e5e4dd145cc454bab39c456a3fbe8f194f56ceab0e9deb8fbb4a87d1686943a4"


def test_clean_rig_v1_target_untouched():
    terere = PROJECT_ROOT / "assets/fighters/processed/clean_rig_v1/terere/terere_clean_rig_v1.glb"
    jaguarete = PROJECT_ROOT / "assets/fighters/processed/clean_rig_v1/jaguarete/jaguarete_clean_rig_v1.glb"
    assert terere.is_file()
    assert jaguarete.is_file()
    assert _sha256(terere) == "2e5fa018e55852052e3f595b8b6cf2756ed136d755cfe22b198c50136ef768ed"
    assert _sha256(jaguarete) == "cafa9f55dafcc2229c6f48ca17635a1febb4b26f1f53baae3dd3591b30549742"


def test_reaction_source_dump_from_scratch():
    dump = _json("docs/generated/REACTION_FBX_SEMANTIC_SOURCE_DUMP.json")
    assert dump["copies_mixamo_quaternion"] is False
    assert dump["frame_end"] >= dump["frame_start"]
    assert dump["fps"] > 0
    assert dump["clip_duration_s"] > 0
    assert dump["classification"]["clip"] == "HIT_REACTION"
    assert "IMPACT" in dump["phases"]
    assert "RECOIL" in dump["phases"]
    assert "RECOVERY" in dump["phases"]
    assert dump["phases"]["peak_frame"] >= dump["frame_start"]
    assert "Reaction.fbx" in dump["source"]
    assert dump["bone_count"] > 0
    assert "intra_abs_max" in dump


def test_reaction_assets_and_animation_name():
    run = _json("docs/generated/SEMANTIC_REACTION_V1_RUN.json")
    assert run["wired_into_battle"] is False
    assert run["traditional_cob_used"] is False
    assert run["idle_assets_modified"] is False
    for fighter in ("terere", "jaguarete"):
        metrics = _json("docs/generated/%s_SEMANTIC_REACTION_V1_METRICS.json" % fighter.upper())
        glb = Path(metrics["output_glb"])
        blend = Path(metrics["output_blend"])
        assert glb.is_file()
        assert blend.is_file()
        assert glb.name == "%s_semantic_reaction_v1.glb" % fighter
        assert metrics["animation_name"] == "reaction"
        assert metrics["pipeline"] == "SEMANTIC_REACTION_V1"
        assert _sha256(glb) == metrics["output_glb_sha256"]
        assert run["fighters"][fighter]["dynamic_classification"] == "HIT_REACTION"


def test_deformation_root_continuity_gates():
    for fighter in ("terere", "jaguarete"):
        metrics = _json("docs/generated/%s_SEMANTIC_REACTION_V1_METRICS.json" % fighter.upper())
        rt = _json("docs/generated/%s_SEMANTIC_REACTION_V1_ROUNDTRIP.json" % fighter.upper())
        assert metrics["max_extreme_verts"] == 0
        assert metrics["max_limb_length_rel_error"] == 0.0
        assert metrics["max_root_xz"] < 0.03
        assert metrics["legacy_axis_hack"] is False
        assert metrics["copies_raw_mixamo_quaternion"] is False
        assert metrics["dynamic_classification"] == "HIT_REACTION"
        assert metrics["dynamic_classification"] not in REJECTED
        assert metrics["peak_torso_dev"] >= 1.6 or metrics["peak_upperarm_dev"] >= 3.0
        assert metrics["max_upperarm_from_down"] < 70.0
        assert metrics["start_continuity"]["L_upperarm_dev"] < 4.0
        assert metrics["end_continuity"]["L_upperarm_dev"] < 4.0
        assert metrics["start_continuity"]["R_upperarm_dev"] < 4.0
        assert metrics["end_continuity"]["R_upperarm_dev"] < 4.0
        assert rt["bone_count"] == 101
        assert rt["ok"] is True
        blob = json.dumps(metrics["texture_authority"]).lower()
        assert fighter in blob or ("terere" in blob or "jaguarete" in blob)


def test_no_legacy_orientation_hacks():
    baker = _read("tools/blender/semantic_reaction_v1.py").lower()
    assert "axis_hack" not in baker or "legacy_axis_hack" in baker
    assert "traditional" not in baker or "does not use traditional cob" in baker
    for fighter in ("terere", "jaguarete"):
        metrics = _json("docs/generated/%s_SEMANTIC_REACTION_V1_METRICS.json" % fighter.upper())
        assert metrics["legacy_axis_hack"] is False
        assert metrics["runtime_retarget"] is False


def test_godot_labs_isolated_and_load_correct_assets():
    terere = _read("scenes/debug/TerereSemanticReactionV1Lab.tscn")
    jaguarete = _read("scenes/debug/JaguareteSemanticReactionV1Lab.tscn")
    gd = _read("scripts/debug/semantic_reaction_v1_lab.gd")
    assert "SEMANTIC_REACTION_V1" in terere
    assert "SEMANTIC_REACTION_V1" in jaguarete
    assert "terere_production_semantic_idle_v1.glb" in terere
    assert "terere_semantic_reaction_v1.glb" in terere
    assert "jaguarete_idle_semantic_polished_v1.glb" in jaguarete
    assert "jaguarete_semantic_reaction_v1.glb" in jaguarete
    assert "actorcore_animation_lab" not in terere
    assert "production_animation_lab" not in terere
    assert "semantic_solver_v2_lab" not in terere
    assert "actorcore_animation_lab" not in jaguarete
    assert "production_animation_lab" not in jaguarete
    assert "semantic_solver_v2_lab" not in jaguarete
    assert "fighter_catalog.gd" not in gd
    assert "KEY_3" in gd
    assert "[REACTION_LAB]" in gd
    assert "SINGLE REACTION TRIGGER" in gd or "SINGLE REACTION" in gd
    for token in FORBIDDEN:
        assert token not in terere
        assert token not in jaguarete


def test_lab_runtime_lifecycle_guards():
    gd = _read("scripts/debug/semantic_reaction_v1_lab.gd")
    assert "is_inside_tree()" in gd
    assert "is_instance_valid(" in gd
    assert "is_queued_for_deletion()" in gd
    assert "var stack: Array[Node] = []" in gd
    assert "var stack: Array[Node] = [node] if node else []" not in gd
    assert "_update_skeleton_debug()" in gd
    assert "_ensure_skeleton_debug()" in gd
    assert "_begin_switch()" in gd
    assert "_finish_switch()" in gd
    assert "queue_free()" in gd
    process = gd.split("func _process(")[1].split("func ")[0]
    assert "_clear_skeleton_debug()" not in process
    assert "MeshInstance3D.new()" not in process
    launcher = _read("tools/launch_semantic_reaction_v1.ps1")
    assert "$PSScriptRoot" in launcher
    assert "Split-Path -Parent $PSScriptRoot" in launcher


def test_no_battle_integration():
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert 'pipeline_id = "ACTORCORE_V4"' in catalog
    for fighter, digest in V4.items():
        glb = PROJECT_ROOT / "assets/fighters/processed" / fighter / ("%s_game_ready_v4.glb" % fighter)
        assert hashlib.sha256(glb.read_bytes()).hexdigest().upper() == digest
    baker = _read("tools/blender/semantic_reaction_v1.py")
    assert "wired_into_battle" in baker
    run = _json("docs/generated/SEMANTIC_REACTION_V1_RUN.json")
    assert run["wired_into_battle"] is False
    battle_hits = []
    for rel in (
        "scenes/battle",
        "scripts/battle",
        "scripts/combat",
    ):
        folder = PROJECT_ROOT / rel
        if not folder.is_dir():
            continue
        for path in folder.rglob("*"):
            if path.suffix.lower() in {".gd", ".tscn"}:
                text = path.read_text(encoding="utf-8", errors="ignore").lower()
                if "semantic_reaction_v1" in text:
                    battle_hits.append(str(path.relative_to(PROJECT_ROOT)))
    assert battle_hits == []
