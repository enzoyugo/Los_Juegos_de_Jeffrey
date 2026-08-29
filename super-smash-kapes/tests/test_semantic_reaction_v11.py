'''Semantic Reaction V1.1 torso/hip/head polish. V1 frozen. No battle.'''

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


def test_reaction_v1_frozen():
    freeze = _json("docs/generated/FROZEN_SEMANTIC_REACTION_V1.json")
    assert freeze["immutable"] is True
    assert freeze["do_not_rebake"] is True
    for fighter, row in freeze["fighters"].items():
        assert _sha256(row["glb"]) == row["glb_sha256"]
        assert Path(row["glb"]).is_file()
    idle = _json("docs/generated/APPROVED_IDLE_AUTHORITIES.json")
    for fighter, row in idle["fighters"].items():
        assert _sha256(row["glb"]) == row["glb_sha256"]


def test_candidates_exist_and_named_reaction():
    run = _json("docs/generated/SEMANTIC_REACTION_V11_RUN.json")
    assert run["wired_into_battle"] is False
    assert run["auto_selected"] is False
    assert run["reaction_v1_modified"] is False
    for fighter in ("terere", "jaguarete"):
        for cand in ("a", "b", "c"):
            metrics = _json("docs/generated/%s_SEMANTIC_REACTION_V11_%s_METRICS.json" % (fighter.upper(), cand.upper()))
            glb = Path(metrics["output_glb"])
            assert glb.is_file()
            assert metrics["animation_name"] == "reaction"
            assert metrics["arm_ops_from"] == "SEMANTIC_REACTION_V1"
            assert _sha256(glb) == metrics["output_glb_sha256"]
            assert run["fighters"][fighter][cand]["healthy"] is True


def test_gates_continuity_root_arms():
    freeze = _json("docs/generated/FROZEN_SEMANTIC_REACTION_V1.json")
    for fighter in ("terere", "jaguarete"):
        v1_from = freeze["fighters"][fighter]["max_upperarm_from_down"]
        for cand in ("a", "b", "c"):
            metrics = _json("docs/generated/%s_SEMANTIC_REACTION_V11_%s_METRICS.json" % (fighter.upper(), cand.upper()))
            rt = _json("docs/generated/%s_SEMANTIC_REACTION_V11_%s_ROUNDTRIP.json" % (fighter.upper(), cand.upper()))
            assert metrics["max_extreme_verts"] == 0
            assert metrics["max_limb_length_rel_error"] == 0.0
            assert metrics["max_root_xz"] < 0.03
            assert metrics["legacy_axis_hack"] is False
            assert metrics["dynamic_classification"] == "HIT_REACTION"
            assert metrics["start_continuity"]["L_upperarm_dev"] < 4.0
            assert metrics["end_continuity"]["L_upperarm_dev"] < 4.0
            assert metrics["max_upperarm_from_down"] < 70.0
            assert metrics["max_upperarm_from_down"] <= v1_from + 8.0
            assert metrics["max_yaw_from_canonical"] < 18.0
            assert rt["bone_count"] == 101
            assert rt["ok"] is True
            blob = json.dumps(metrics["texture_authority"]).lower()
            assert fighter in blob


def test_torso_stronger_than_v1_and_ordered():
    for fighter in ("terere", "jaguarete"):
        peaks = []
        for cand in ("a", "b", "c"):
            metrics = _json("docs/generated/%s_SEMANTIC_REACTION_V11_%s_METRICS.json" % (fighter.upper(), cand.upper()))
            peaks.append(metrics["peak_torso_dev"])
            assert metrics["peak_torso_dev"] >= 3.5
        assert peaks[0] < peaks[1] < peaks[2]


def test_lab_isolated_no_debug_overlay():
    terere = _read("scenes/debug/TerereSemanticReactionV11Lab.tscn")
    jaguarete = _read("scenes/debug/JaguareteSemanticReactionV11Lab.tscn")
    gd = _read("scripts/debug/semantic_reaction_v11_lab.gd")
    assert "SEMANTIC_REACTION_V11" in terere
    assert "semantic_reaction_v11_a.glb" in terere
    assert "semantic_reaction_v1.glb" in terere
    assert "semantic_reaction_v11_a.glb" in jaguarete
    assert "actorcore_animation_lab" not in terere
    assert "production_animation_lab" not in terere
    assert "semantic_solver_v2_lab" not in terere
    assert "_rebuild_skeleton" not in gd
    assert "_rebuild_bbox" not in gd
    assert "global_position" not in gd
    assert "KEY_5" in gd
    for token in FORBIDDEN:
        assert token not in terere
        assert token not in jaguarete
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert 'pipeline_id = "ACTORCORE_V4"' in catalog
    for fighter, digest in V4.items():
        glb = PROJECT_ROOT / "assets/fighters/processed" / fighter / ("%s_game_ready_v4.glb" % fighter)
        assert hashlib.sha256(glb.read_bytes()).hexdigest().upper() == digest
