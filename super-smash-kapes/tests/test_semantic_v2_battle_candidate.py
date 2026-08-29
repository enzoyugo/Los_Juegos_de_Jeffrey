"""Semantic V2 battle candidate switch — production V4 stays default."""

from pathlib import Path
import hashlib


PROJECT_ROOT = Path(__file__).resolve().parents[1]
V4_HASHES = {
    "terere": "D880B8E9FE03F8F0169728259A0C51F0A931AED401B4AA30A32BCED94EA0CEBE",
    "jaguarete": "460BEE0AF4CF0CE3F9550948E3E69D349A9E3C1D1EFADE786178C8E5D639553C",
}


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_production_default_still_v4() -> None:
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    terere = _read("fighters/terere/terere_actorcore_visual.gd")
    jaguarete = _read("fighters/jaguarete/jaguarete_actorcore_visual.gd")
    for blob in (catalog, terere, jaguarete):
        assert "game_ready_v4.glb" in blob
        assert "semantic_solver_v2" not in blob
    for fighter, digest in V4_HASHES.items():
        path = PROJECT_ROOT / f"assets/fighters/processed/{fighter}/{fighter}_game_ready_v4.glb"
        assert hashlib.sha256(path.read_bytes()).hexdigest().upper() == digest


def test_candidate_env_switch_does_not_rewrite_catalog() -> None:
    definition = _read("scripts/fighters/fighter_definition.gd")
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert "SSK_USE_SEMANTIC_V2_CANDIDATE" in definition
    assert "terere_semantic_v2_battle_candidate.gd" in definition
    assert "jaguarete_semantic_v2_battle_candidate.gd" in definition
    assert "SSK_USE_SEMANTIC_V2_CANDIDATE" not in catalog
    assert "semantic_solver_v2" not in catalog


def test_candidate_assets_and_sizes() -> None:
    terere = _read("fighters/terere/terere_semantic_v2_battle_candidate.gd")
    jaguarete = _read("fighters/jaguarete/jaguarete_semantic_v2_battle_candidate.gd")
    assert "terere_idle_semantic_v2.glb" in terere
    assert "jaguarete_idle_semantic_v2.glb" in jaguarete
    assert "target_visual_height = 2.40" in terere
    assert "target_visual_height = 3.15" in jaguarete
    assert (PROJECT_ROOT / "assets/fighters/processed/semantic_solver_v2/terere/terere_idle_semantic_v2.glb").is_file()
    assert (PROJECT_ROOT / "assets/fighters/processed/semantic_solver_v2/jaguarete/jaguarete_idle_semantic_v2.glb").is_file()
    assert (PROJECT_ROOT / "scenes/debug/TerereSemanticV2BattleCandidate.tscn").is_file()
    assert (PROJECT_ROOT / "scenes/debug/JaguareteSemanticV2BattleCandidate.tscn").is_file()


def test_one_facing_authority_and_no_idle_proxy_rotation() -> None:
    glb = _read("scripts/fighters/glb_fighter_visual.gd")
    actor = _read("scripts/fighters/actorcore_fighter_visual.gd")
    assert "FacingRoot" in glb
    assert "facing_root.rotation" in glb
    assert "model_root.rotation = Vector3(_base_pitch, _base_yaw, 0.0)" in glb
    assert "model_root.rotation.y = _base_yaw + (0.0 if facing > 0.0 else PI)" not in glb
    assert "snap_motion_roots_neutral" in glb
    assert "snap_motion_roots_neutral()" in actor
    assert "SSK_FIGHTER_VISUAL_AUDIT" in actor
    assert "_idle_uses_skeletal()" in glb
    assert "model_pitch_offset" in glb
    terere = _read("fighters/terere/terere_semantic_v2_battle_candidate.gd")
    jaguarete = _read("fighters/jaguarete/jaguarete_semantic_v2_battle_candidate.gd")
    production = _read("fighters/terere/terere_actorcore_visual.gd")
    assert "model_pitch_offset = -PI * 0.5" in terere
    assert "model_pitch_offset = -PI * 0.5" in jaguarete
    assert "model_pitch_offset" not in production


def test_canonical_catalog_sizes_unchanged() -> None:
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert "target_visual_height = 2.40" in catalog
    assert "target_visual_height = 3.15" in catalog
    assert 'pipeline_id = "ACTORCORE_V4"' in catalog


def test_battle_authority_json_default_is_v4() -> None:
    import json

    data = json.loads(_read("docs/generated/BATTLE_FIGHTER_VISUAL_AUTHORITY.json"))
    assert data["catalog_default_pipeline"] == "ACTORCORE_V4"
    assert data["catalog_swapped"] is False
    assert data["env_SSK_USE_SEMANTIC_V2_CANDIDATE"] is False
    for fighter in ("terere", "jaguarete"):
        row = data[fighter]
        assert row["pipeline"] == "ACTORCORE_V4"
        assert "game_ready_v4.glb" in row["glb"]
        assert row["experimental_semantic_v2"] is False
        assert row["production"]["pipeline"] == "ACTORCORE_V4"
        assert row["candidate"]["pipeline"] == "ACTORCORE_SEMANTIC_V2_CANDIDATE"
        assert "semantic_solver_v2" in row["candidate"]["glb"]
        assert row["candidate"]["glb_matches_expected"] is True
        assert row["production"]["skeleton_upright"]["classification"] == "UPRIGHT"
        assert row["candidate"]["skeleton_upright"]["classification"] == "UPRIGHT"
        assert row["candidate"]["skeleton_upright"]["dominant_axis"] == "Y"


def test_pose_parity_and_transform_stack_structure() -> None:
    import json

    for fighter in ("terere", "jaguarete"):
        parity = json.loads(_read(f"docs/generated/{fighter.upper()}_POSE_PARITY.json"))
        assert "blender" in parity
        assert "godot_lab_direct_glb" in parity
        assert "candidate_standing" in parity
        assert "production_idle" in parity
        assert "bone_local_delta_standing_vs_blender" in parity
        stack = json.loads(_read(f"docs/generated/{fighter.upper()}_BATTLE_TRANSFORM_STACK.json"))
        blob = json.dumps(stack)
        assert "FacingRoot" in blob
        assert "ModelRoot" in blob
        assert "VisualMotionRoot" in blob
