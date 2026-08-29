'''Tereré Production Semantic Idle V1. Centered on Pose B. Jaguareté frozen.'''

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


def _read(rel):
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _json(rel):
    return json.loads(_read(rel))


def _sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def test_pose_b_is_canonical_authority():
    canon = _json("docs/generated/TERERE_CANONICAL_IDLE_POSE_V1.json")
    assert canon["selected_by_human"] is True
    assert canon["selected_pose"] == "POSE_B"
    assert canon["status"] == "CANONICAL_IDLE_CENTER"
    glb = Path(canon["source_pose_b_glb"])
    assert glb.is_file()
    assert _sha256(glb) == canon["glb_sha256"]
    assert "standing_ops" in canon
    assert canon["standing_ops"]["CC_Base_L_Upperarm"]["primary"] == 50.0
    assert abs(canon["standing_ops"]["CC_Base_L_Upperarm"]["secondary"]) >= 10.0


def test_idle_centered_on_pose_b_with_bounded_deviation():
    run = _json("docs/generated/TERERE_PRODUCTION_SEMANTIC_IDLE_V1_RUN.json")
    metrics = _json("docs/generated/TERERE_PRODUCTION_SEMANTIC_IDLE_V1_METRICS.json")
    assert run["canonical"] == "POSE_B"
    assert run["wired_into_battle"] is False
    assert metrics["animation_name"] == "idle"
    assert metrics["standing_ops_canonical"]["CC_Base_L_Upperarm"]["primary"] == 50.0
    sim = metrics["pose_similarity"]
    assert sim["L_upperarm_from_down_dev"]["max"] <= 8.5
    assert sim["R_upperarm_from_down_dev"]["max"] <= 8.5
    assert sim["L_elbow_flex_dev"]["max"] <= 8.5
    assert sim["R_elbow_flex_dev"]["max"] <= 8.5
    assert sim["L_hand_pos_dev"]["max"] <= 0.12
    assert sim["R_hand_pos_dev"]["max"] <= 0.12
    assert sim["hands_below_shoulders_all_frames"] is True
    assert sim["upperarm_never_near_tpose"] is True
    assert metrics["gains"]["upperarm_gain"] <= 0.30
    assert metrics["gains"]["wrist_gain"] <= 0.15


def test_deformation_and_root_gates():
    metrics = _json("docs/generated/TERERE_PRODUCTION_SEMANTIC_IDLE_V1_METRICS.json")
    rt = _json("docs/generated/TERERE_PRODUCTION_SEMANTIC_IDLE_V1_ROUNDTRIP.json")
    assert metrics["max_extreme_verts"] == 0
    assert metrics["max_limb_length_rel_error"] == 0.0
    assert metrics["pose_classification"] == "STANDING_IDLE"
    assert metrics["technical_pass"] is True
    assert metrics["legacy_axis_hack"] is False
    assert metrics["max_root_xz"] < 0.02
    assert rt["bone_count"] == 101
    assert rt["ok"] is True
    blob = json.dumps(metrics["texture_authority"]).lower()
    assert "terere" in blob
    glb = Path(metrics["output_glb"])
    assert glb.is_file()
    assert _sha256(glb) == metrics["output_glb_sha256"]


def test_jaguarete_authority_unchanged():
    freeze = _json("docs/generated/JAGUARETE_IDLE_APPROVED_AUTHORITY.json")
    old = _json("docs/generated/JAGUARETE_SEMANTIC_IDLE_APPROVED_V1.json")
    glb = Path(freeze["glb"])
    digest = _sha256(glb)
    assert digest == freeze["glb_sha256"]
    assert digest == old["glb_sha256"]
    run = _json("docs/generated/TERERE_PRODUCTION_SEMANTIC_IDLE_V1_RUN.json")
    assert run["jaguarete_rebaked"] is False
    baker = _read("tools/blender/terere_production_semantic_idle_v1.py").lower()
    assert "does not touch jaguareté" in baker or "does not touch jaguarete" in baker


def test_lab_isolated():
    tscn = _read("scenes/debug/TerereProductionSemanticIdleV1Lab.tscn")
    gd = _read("scripts/debug/terere_production_semantic_idle_v1_lab.gd")
    assert "TERERE_PRODUCTION_SEMANTIC_IDLE_V1" in tscn
    assert "TERERÉ IDLE FINAL" in tscn or "TERERE IDLE FINAL" in tscn
    assert "actorcore_animation_lab" not in tscn
    assert "production_animation_lab" not in tscn
    assert "semantic_solver_v2_lab" not in tscn
    assert "fighter_catalog.gd" not in gd
    for token in FORBIDDEN:
        assert token not in tscn
    assert "terere_idle_pose_redesign_v1_b.glb" in tscn
    assert "terere_idle_semantic_clean_v1.glb" in tscn
    assert "terere_production_semantic_idle_v1.glb" in tscn
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert 'pipeline_id = "ACTORCORE_V4"' in catalog
    for fighter, digest in V4.items():
        glb = PROJECT_ROOT / "assets/fighters/processed" / fighter / ("%s_game_ready_v4.glb" % fighter)
        assert hashlib.sha256(glb.read_bytes()).hexdigest().upper() == digest
