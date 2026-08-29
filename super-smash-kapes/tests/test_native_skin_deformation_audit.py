"""Native AccuRIG skin deformation audit evidence. Does not claim visual playtest success."""

from pathlib import Path
import csv
import hashlib
import json


PROJECT_ROOT = Path(__file__).resolve().parents[1]
V4_HASHES = {
    "terere": "D880B8E9FE03F8F0169728259A0C51F0A931AED401B4AA30A32BCED94EA0CEBE",
    "jaguarete": "460BEE0AF4CF0CE3F9550948E3E69D349A9E3C1D1EFADE786178C8E5D639553C",
}


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _json(rel: str) -> dict:
    return json.loads(_read(rel))


def test_native_audit_csv_and_summary_exist() -> None:
    for name in (
        "TERERE_NATIVE_SKIN_DEFORMATION.csv",
        "JAGUARETE_NATIVE_SKIN_DEFORMATION.csv",
        "NATIVE_SKIN_AUDIT_SUMMARY.json",
        "TERERE_NATIVE_SKIN_AUDIT.json",
        "JAGUARETE_NATIVE_SKIN_AUDIT.json",
    ):
        path = PROJECT_ROOT / "docs/generated" / name
        assert path.is_file(), path
    for rel in (
        "docs/ACTORCORE_NATIVE_SKIN_DEFORMATION_AUDIT_V1.md",
        "tools/blender/native_skin_deformation_audit.py",
    ):
        assert (PROJECT_ROOT / rel).is_file()


def test_native_audit_did_not_use_mixamo() -> None:
    script = _read("tools/blender/native_skin_deformation_audit.py")
    assert "Idle.fbx" not in script
    assert "mixamo" not in script.lower() or "No Mixamo" in script
    ter = _json("docs/generated/TERERE_NATIVE_SKIN_AUDIT.json")
    jag = _json("docs/generated/JAGUARETE_NATIVE_SKIN_AUDIT.json")
    assert ter["mixamo_used"] is False
    assert jag["mixamo_used"] is False


def test_csv_has_original_and_4inf_variants() -> None:
    for name in ("TERERE_NATIVE_SKIN_DEFORMATION.csv", "JAGUARETE_NATIVE_SKIN_DEFORMATION.csv"):
        with (PROJECT_ROOT / "docs/generated" / name).open(encoding="utf-8") as fh:
            rows = list(csv.DictReader(fh))
        variants = {row["variant"] for row in rows}
        assert "original" in variants
        assert "4inf" in variants
        bones = {row["bone"] for row in rows}
        assert "CC_Base_L_Upperarm" in bones
        assert "STANDING_COMBO" in bones
        assert any(row["angle_deg"] == "60" and "Upperarm" in row["bone"] for row in rows)


def test_summary_is_allowed_verdict_and_case_3() -> None:
    data = _json("docs/generated/NATIVE_SKIN_AUDIT_SUMMARY.json")
    allowed = {
        "SSK_ACTORCORE_NATIVE_SKIN_HEALTHY_RETARGET_STILL_BLOCKED",
        "SSK_ACTORCORE_WEIGHT_CLAMP_ROOT_CAUSE_IDENTIFIED",
        "SSK_ACTORCORE_NATIVE_SKIN_ROOT_CAUSE_IDENTIFIED",
        "SSK_ACTORCORE_GLTF_BIND_ROOT_CAUSE_IDENTIFIED",
        "SSK_ACTORCORE_NATIVE_SKIN_AUDIT_INCONCLUSIVE",
    }
    assert data["primary_verdict"] in allowed
    assert data["mixamo_used_in_primary_experiment"] is False
    assert data["native_7_to_11x_explosion"] is False
    assert data["weight_clamp_is_root_cause"] is False
    assert data["decision_tree_case"] == 3


def test_native_audit_outputs_exist_off_production_paths() -> None:
    for rel in (
        "assets/fighters/processed/native_skin_audit/terere/terere_native_skin_audit.blend",
        "assets/fighters/processed/native_skin_audit/jaguarete/jaguarete_native_skin_audit.blend",
        "assets/fighters/processed/native_skin_audit/terere/terere_native_standing_test.glb",
        "assets/fighters/processed/native_skin_audit/jaguarete/jaguarete_native_standing_test.glb",
    ):
        path = PROJECT_ROOT / rel
        assert path.is_file(), path
        assert path.stat().st_size > 1000
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert "native_skin_audit" not in catalog
    assert "game_ready_v4.glb" in catalog


def test_production_v4_untouched_after_native_audit() -> None:
    for char, expected in V4_HASHES.items():
        path = PROJECT_ROOT / "assets/fighters/processed" / char / ("%s_game_ready_v4.glb" % char)
        digest = hashlib.sha256(path.read_bytes()).hexdigest().upper()
        assert digest == expected
    visual = _read("fighters/terere/terere_actorcore_visual.gd")
    assert "native_skin_audit" not in visual
