from pathlib import Path

PROJECT_ROOT = Path(r"E:\SuperSmashKapes\super-smash-kapes")

V3 = PROJECT_ROOT / "assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v3.glb"
V4 = PROJECT_ROOT / "assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v4_candidate.glb"
V41 = PROJECT_ROOT / "assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v4_1_candidate.glb"
V42 = PROJECT_ROOT / "assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v4_2_candidate.glb"
SCRIPT = PROJECT_ROOT / "tools/blender/zombies/build_sds_environment_v4_2_candidate.py"
LAB = PROJECT_ROOT / "scenes/debug/ShoppingBlenderEnvironmentV4_2CandidateLab.tscn"
MAP = PROJECT_ROOT / "scripts/zombies/zombies_map.gd"


def test_v4_2_does_not_overwrite_prior_candidates():
    src = SCRIPT.read_text(encoding="utf-8")
    assert "shopping_del_sol_zombies_environment_v4_2_candidate" in src
    assert "shopping_del_sol_zombies_environment_v3.blend" not in src
    assert "shopping_del_sol_zombies_environment_v4_candidate.blend" not in src
    assert "shopping_del_sol_zombies_environment_v4_1_candidate.blend" not in src
    assert "HUMAN_REVIEW_REQUIRED" in src
    assert V3.exists()
    assert V4.exists()
    assert V41.exists()
    assert V42.exists()
    assert "shopping_blender_environment_v4_2_candidate_lab.gd" in LAB.read_text(encoding="utf-8")


def test_v4_2_lab_is_candidate_only():
    gd = (PROJECT_ROOT / "scripts/debug/shopping_blender_environment_v4_2_candidate_lab.gd").read_text(encoding="utf-8")
    assert "HUMAN_REVIEW_REQUIRED" in gd
    assert "canonical=false" in gd
    assert "v4_2_candidate.glb" in gd


def test_zombies_map_still_v3():
    text = MAP.read_text(encoding="utf-8")
    assert "shopping_del_sol_zombies_environment_v3.glb" in text
    assert "v4_2_candidate.glb" not in text
