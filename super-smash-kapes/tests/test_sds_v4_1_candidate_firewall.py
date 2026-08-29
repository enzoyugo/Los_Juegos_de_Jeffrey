from pathlib import Path

PROJECT_ROOT = Path(r"E:\SuperSmashKapes\super-smash-kapes")

V3 = PROJECT_ROOT / "assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v3.glb"
V4 = PROJECT_ROOT / "assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v4_candidate.glb"
V41 = PROJECT_ROOT / "assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v4_1_candidate.glb"
SCRIPT_V3 = PROJECT_ROOT / "tools/blender/zombies/build_sds_environment_v3.py"
SCRIPT_V4 = PROJECT_ROOT / "tools/blender/zombies/build_sds_environment_v4_candidate.py"
SCRIPT_V41 = PROJECT_ROOT / "tools/blender/zombies/build_sds_environment_v4_1_candidate.py"
LAB_V3 = PROJECT_ROOT / "scenes/debug/ShoppingBlenderEnvironmentV3Lab.tscn"
LAB_V4 = PROJECT_ROOT / "scenes/debug/ShoppingBlenderEnvironmentV4CandidateLab.tscn"
LAB_V41 = PROJECT_ROOT / "scenes/debug/ShoppingBlenderEnvironmentV4_1CandidateLab.tscn"
MAP = PROJECT_ROOT / "scripts/zombies/zombies_map.gd"


def test_v4_1_does_not_overwrite_v3_or_v4_paths():
    src = SCRIPT_V41.read_text(encoding="utf-8")
    assert "shopping_del_sol_zombies_environment_v4_1_candidate" in src
    assert "shopping_del_sol_zombies_environment_v3.blend" not in src
    assert "shopping_del_sol_zombies_environment_v4_candidate.blend" not in src
    assert "HUMAN_REVIEW_REQUIRED" in src
    assert "SDS_V4_1_CANONICAL" not in src.replace("Not SDS_V4_1_CANONICAL", "")
    assert V3.exists()
    assert V4.exists()
    assert V41.exists()
    assert SCRIPT_V3.exists()
    assert SCRIPT_V4.exists()
    lab = LAB_V41.read_text(encoding="utf-8")
    assert "shopping_blender_environment_v4_1_candidate_lab.gd" in lab
    assert LAB_V3.exists()
    assert LAB_V4.exists()


def test_v4_1_lab_is_candidate_only():
    gd = (PROJECT_ROOT / "scripts/debug/shopping_blender_environment_v4_1_candidate_lab.gd").read_text(encoding="utf-8")
    assert "HUMAN_REVIEW_REQUIRED" in gd
    assert "canonical=false" in gd
    assert "ENV_V41" in gd
    assert "zombies_environment_v4_1_candidate.glb" in gd


def test_zombies_map_still_points_at_v3_not_v4_1():
    text = MAP.read_text(encoding="utf-8")
    assert "shopping_del_sol_zombies_environment_v3.glb" in text
    assert "shopping_del_sol_zombies_environment_v4_1_candidate.glb" not in text
    assert "shopping_del_sol_zombies_environment_v4_candidate.glb" not in text
