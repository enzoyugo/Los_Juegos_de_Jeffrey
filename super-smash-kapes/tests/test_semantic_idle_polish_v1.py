"""Semantic Idle polish V1. Does not overwrite the frozen semantic baseline."""

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


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _json(rel: str) -> dict:
    return json.loads(_read(rel))


def _sha256(rel: str) -> str:
    return hashlib.sha256((PROJECT_ROOT / rel).read_bytes()).hexdigest()


def test_baseline_semantic_files_not_overwritten() -> None:
    base = _json("docs/generated/SEMANTIC_IDLE_POLISH_V1_BASELINE.json")
    for _key, meta in base["files"].items():
        path = Path(meta["path"])
        assert path.is_file(), path
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert digest == meta["sha256"], meta["path"]


def test_polish_outputs_exist_and_differ_from_baseline() -> None:
    for fighter in ("terere", "jaguarete"):
        glb = PROJECT_ROOT / "assets/fighters/processed/semantic_idle_polish_v1" / fighter / ("%s_idle_semantic_polished_v1.glb" % fighter)
        blend = glb.with_suffix(".blend")
        baseline = PROJECT_ROOT / "assets/fighters/processed/idle_benchmark_v1" / fighter / ("%s_idle_semantic_clean_v1.glb" % fighter)
        assert glb.is_file(), glb
        assert blend.is_file(), blend
        assert hashlib.sha256(glb.read_bytes()).hexdigest() != hashlib.sha256(baseline.read_bytes()).hexdigest()


def test_polish_metrics_pass_gates() -> None:
    run = _json("docs/generated/SEMANTIC_IDLE_POLISH_V1_RUN.json")
    for fighter in ("terere", "jaguarete"):
        row = run["fighters"][fighter]
        metrics = _json("docs/generated/%s_IDLE_SEMANTIC_POLISHED_V1_METRICS.json" % fighter.upper())
        assert row["technical_pass"] is True
        assert row["pose_classification"] == "STANDING_IDLE"
        assert metrics["max_volume_ratio"] <= 1.35
        assert metrics["max_extreme_verts"] == 0
        assert metrics["max_limb_length_rel_error"] == 0.0
        assert metrics["max_root_xz"] < 0.05
        assert row["roundtrip_ok"] is True
        assert row["roundtrip_bones"] == 101


def test_terere_posture_moved_toward_upright_not_tpose() -> None:
    base = _json("docs/generated/SEMANTIC_IDLE_POLISH_V1_BASELINE.json")["fighters"]["terere"]
    pol = _json("docs/generated/TERERE_IDLE_SEMANTIC_POLISHED_V1_METRICS.json")
    mid = pol["mid_arm"]
    assert mid["L_elbow_flex_deg"] < base["mid_elbow_flex"][0]
    assert mid["R_elbow_flex_deg"] < base["mid_elbow_flex"][1]
    assert mid["CC_Base_L_Hand"]["from_down_deg"] < base["mid_hand_from_down"][0]
    assert 15.0 < mid["CC_Base_L_Upperarm"]["from_down_deg"] < 70.0
    sil = pol["silhouette"]["1"]
    assert sil["hands_below_shoulders"] is True
    assert sil["spine_from_up_deg"] < 16.0


def test_jaguarete_standing_ops_preserved() -> None:
    base = _json("docs/generated/SEMANTIC_IDLE_POLISH_V1_BASELINE.json")["fighters"]["jaguarete"]["standing_ops"]
    pol = _json("docs/generated/JAGUARETE_IDLE_SEMANTIC_POLISHED_V1_METRICS.json")["standing_ops_baseline"]
    assert pol["CC_Base_Spine01"]["primary"] == base["CC_Base_Spine01"]["primary"]
    assert pol["CC_Base_L_Upperarm"]["primary"] == base["CC_Base_L_Upperarm"]["primary"]
    assert pol["CC_Base_L_Hand"]["primary"] == base["CC_Base_L_Hand"]["primary"]


def test_polish_labs_are_isolated() -> None:
    for rel in (
        "scenes/debug/TerereSemanticIdlePolishV1Lab.tscn",
        "scenes/debug/JaguareteSemanticIdlePolishV1Lab.tscn",
        "scripts/debug/terere_semantic_idle_polish_v1_lab.gd",
        "scripts/debug/jaguarete_semantic_idle_polish_v1_lab.gd",
    ):
        blob = _read(rel)
        assert "semantic_idle_polish_v1" in blob or "SEMANTIC_IDLE_POLISH_V1" in blob
        assert "fighter_catalog.gd" not in blob
        for token in FORBIDDEN:
            assert token not in blob
        assert "terere_game_ready_v4.glb" not in blob
        assert "jaguarete_game_ready_v4.glb" not in blob


def test_polish_labs_compare_baseline_not_traditional() -> None:
    ter = _read("scenes/debug/TerereSemanticIdlePolishV1Lab.tscn")
    jag = _read("scenes/debug/JaguareteSemanticIdlePolishV1Lab.tscn")
    for blob in (ter, jag):
        assert "idle_semantic_clean_v1.glb" in blob
        assert "idle_semantic_polished_v1.glb" in blob
        assert "idle_traditional_v1.glb" not in blob
        assert "SEMANTIC BASELINE" in blob
        assert "SEMANTIC POLISHED" in blob


def test_production_v4_untouched() -> None:
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert "pipeline_id = \"ACTORCORE_V4\"" in catalog
    terere = PROJECT_ROOT / "assets/fighters/processed/terere/terere_game_ready_v4.glb"
    jaguarete = PROJECT_ROOT / "assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb"
    assert hashlib.sha256(terere.read_bytes()).hexdigest().upper() == "D880B8E9FE03F8F0169728259A0C51F0A931AED401B4AA30A32BCED94EA0CEBE"
    assert hashlib.sha256(jaguarete.read_bytes()).hexdigest().upper() == "460BEE0AF4CF0CE3F9550948E3E69D349A9E3C1D1EFADE786178C8E5D639553C"
