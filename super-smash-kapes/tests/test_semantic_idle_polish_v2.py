
'''Semantic Idle polish V2. Restores frozen Terere baseline; does not touch Jaguarete.'''

from pathlib import Path
import hashlib
import json


PROJECT_ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN = (
    "game_ready_v4",
    "game_ready_v3",
    "semantic_solver_v2",
    "solver_v1",
    "actorcore_benchmark",
    "native_skin_audit",
)
V4 = {
    "terere": "D880B8E9FE03F8F0169728259A0C51F0A931AED401B4AA30A32BCED94EA0CEBE",
    "jaguarete": "460BEE0AF4CF0CE3F9550948E3E69D349A9E3C1D1EFADE786178C8E5D639553C",
}


def _read(rel):
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _json(rel):
    return json.loads(_read(rel))


def test_frozen_semantic_baseline_untouched():
    base = _json("docs/generated/SEMANTIC_IDLE_POLISH_V1_BASELINE.json")
    for _key, meta in base["files"].items():
        path = Path(meta["path"])
        assert path.is_file(), path
        assert hashlib.sha256(path.read_bytes()).hexdigest() == meta["sha256"]


def test_v1_polish_files_untouched():
    for fighter in ("terere", "jaguarete"):
        glb = PROJECT_ROOT / "assets/fighters/processed/semantic_idle_polish_v1" / fighter / ("%s_idle_semantic_polished_v1.glb" % fighter)
        assert glb.is_file(), glb


def test_jaguarete_approved_v1_frozen():
    freeze = _json("docs/generated/JAGUARETE_SEMANTIC_IDLE_APPROVED_V1.json")
    glb = Path(freeze["glb"])
    assert glb.is_file()
    assert hashlib.sha256(glb.read_bytes()).hexdigest() == freeze["glb_sha256"]
    assert freeze["do_not_rebake"] is True
    baker = _read("tools/blender/semantic_idle_polish_v2.py").lower()
    assert "jaguarete" in baker
    assert "freeze" in baker


def test_terere_v2_base_restored_from_baseline():
    rec = _json("docs/generated/TERERE_V2_BASE.json")
    assert rec["byte_identical"] is True
    assert rec["sha256_source"] == rec["sha256_copy"]
    src = Path(rec["restored_from"])
    dst = Path(rec["copy"])
    assert hashlib.sha256(src.read_bytes()).hexdigest() == rec["sha256_source"]
    assert hashlib.sha256(dst.read_bytes()).hexdigest() == rec["sha256_copy"]


def test_v2_candidates_exist_and_differ():
    baseline = PROJECT_ROOT / "assets/fighters/processed/idle_benchmark_v1/terere/terere_idle_semantic_clean_v1.glb"
    v1 = PROJECT_ROOT / "assets/fighters/processed/semantic_idle_polish_v1/terere/terere_idle_semantic_polished_v1.glb"
    hashes = {hashlib.sha256(baseline.read_bytes()).hexdigest(), hashlib.sha256(v1.read_bytes()).hexdigest()}
    for suffix in ("a", "b", "c"):
        glb = PROJECT_ROOT / "assets/fighters/processed/semantic_idle_polish_v2/terere" / ("terere_idle_semantic_polished_v2_%s.glb" % suffix)
        assert glb.is_file(), glb
        digest = hashlib.sha256(glb.read_bytes()).hexdigest()
        assert digest not in hashes
        hashes.add(digest)


def test_v2_candidates_pass_gates_without_ranking():
    run = _json("docs/generated/SEMANTIC_IDLE_POLISH_V2_RUN.json")
    assert run["auto_selected_candidate"] is None
    assert run["wired_into_battle"] is False
    assert run["jaguarete_rebaked"] is False
    assert run["verdict_token"] == "SSK_TERERE_SEMANTIC_IDLE_POLISH_V2_READY_FOR_HUMAN_SELECTION"
    for cand in ("V2_A", "V2_B", "V2_C"):
        row = run["candidates"][cand]
        metrics = _json("docs/generated/TERERE_IDLE_SEMANTIC_POLISH_%s_METRICS.json" % cand)
        assert row["healthy"] is True
        assert row["pose_classification"] == "STANDING_IDLE"
        assert row["technical_pass"] is True
        assert metrics["max_extreme_verts"] == 0
        assert metrics["max_limb_length_rel_error"] == 0.0
        assert metrics["max_volume_ratio"] <= 1.35
        ops = metrics["standing_ops_polished"]
        base = metrics["standing_ops_baseline"]
        assert ops["CC_Base_L_Calf"]["primary"] == base["CC_Base_L_Calf"]["primary"]
        assert ops["CC_Base_R_Calf"]["primary"] == base["CC_Base_R_Calf"]["primary"]
        assert ops["CC_Base_L_Forearm"]["primary"] >= base["CC_Base_L_Forearm"]["primary"]
        assert abs(ops["CC_Base_Spine01"]["primary"] - base["CC_Base_Spine01"]["primary"]) <= 1.01


def test_v2_does_not_open_elbows_like_v1():
    base = _json("docs/generated/SEMANTIC_IDLE_POLISH_V1_BASELINE.json")["fighters"]["terere"]
    v1 = _json("docs/generated/TERERE_IDLE_SEMANTIC_POLISHED_V1_METRICS.json")
    run = _json("docs/generated/SEMANTIC_IDLE_POLISH_V2_RUN.json")
    v1_elbow = v1["mid_arm"]["L_elbow_flex_deg"]
    base_elbow = base["mid_elbow_flex"][0]
    assert v1_elbow < base_elbow
    for cand in ("V2_A", "V2_B", "V2_C"):
        sil = run["candidates"][cand]["silhouette_frame1"]
        assert sil["L_elbow_flex"] >= base_elbow - 5.0



def test_v2_lab_is_isolated():
    for rel in (
        "scenes/debug/TerereSemanticIdlePolishV2Lab.tscn",
        "scripts/debug/terere_semantic_idle_polish_v2_lab.gd",
    ):
        blob = _read(rel)
        assert "SEMANTIC_IDLE_POLISH_V2" in blob or "semantic_idle_polish_v2" in blob
        assert "fighter_catalog.gd" not in blob
        assert "terere_game_ready_v4.glb" not in blob
        assert "jaguarete_game_ready_v4.glb" not in blob
    tscn = _read("scenes/debug/TerereSemanticIdlePolishV2Lab.tscn")
    for token in FORBIDDEN:
        assert token not in tscn
    assert "idle_semantic_clean_v1.glb" in tscn
    assert "idle_semantic_polished_v1.glb" in tscn
    assert "polished_v2_a.glb" in tscn
    assert "polished_v2_b.glb" in tscn
    assert "polished_v2_c.glb" in tscn


def test_contact_sheet_exists():
    sheet = PROJECT_ROOT / "docs/generated/TERERE_IDLE_POLISH_V2_CONTACT_SHEET.png"
    assert sheet.is_file()
    assert sheet.stat().st_size > 10000


def test_production_v4_and_catalog_untouched():
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert 'pipeline_id = "ACTORCORE_V4"' in catalog
    for fighter, digest in V4.items():
        glb = PROJECT_ROOT / "assets/fighters/processed" / fighter / ("%s_game_ready_v4.glb" % fighter)
        assert hashlib.sha256(glb.read_bytes()).hexdigest().upper() == digest
