from pathlib import Path

PROJECT_ROOT = Path(r"E:\SuperSmashKapes\super-smash-kapes")

V3 = PROJECT_ROOT / "assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v3.glb"
V4 = PROJECT_ROOT / "assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v4_candidate.glb"
SCRIPT = PROJECT_ROOT / "tools/blender/zombies/build_sds_environment_v4_candidate.py"
LAB = PROJECT_ROOT / "scenes/debug/ShoppingBlenderEnvironmentV4CandidateLab.tscn"


def test_v4_candidate_does_not_replace_v3_paths():
    src = SCRIPT.read_text(encoding="utf-8")
    assert "shopping_del_sol_zombies_environment_v4_candidate" in src
    assert "shopping_del_sol_zombies_environment_v3.blend" not in src
    assert "HUMAN_REVIEW_REQUIRED" in src
    assert V3.exists()
    lab = LAB.read_text(encoding="utf-8")
    assert "shopping_blender_environment_v4_candidate_lab.gd" in lab
    v3_lab = (PROJECT_ROOT / "scenes/debug/ShoppingBlenderEnvironmentV3Lab.tscn").read_text(encoding="utf-8")
    assert "v3_lab" in v3_lab or "v3" in v3_lab
    cam = (PROJECT_ROOT / "scripts/track/track_camera_candidate_v2.gd").read_text(encoding="utf-8")
    assert "class_name TrackCameraCandidateV2" in cam
    assert "CAND_FOV_MIN" in cam
    cfg = (PROJECT_ROOT / "scripts/track/track_config.gd").read_text(encoding="utf-8")
    assert "const CAM_FOV_MIN" in cfg
    assert "const CAM_LOOK_AHEAD" in cfg
    ## Canonical chase camera still consumes Config (values may be art-tuned).
    cam_live = (PROJECT_ROOT / "scripts/track/track_camera.gd").read_text(encoding="utf-8")
    assert "Config.CAM_LOOK_AHEAD" in cam_live
    zm = (PROJECT_ROOT / "scripts/zombies/zombies_main.gd").read_text(encoding="utf-8")
    assert "DEBUG_HEURISTIC_STUCK" in zm
    assert "ZOMBIE_SPEED" not in zm.split("func _tick_debug_stuck")[1][:400]


def test_v4_lab_falls_back_without_claiming_canonical():
    gd = (PROJECT_ROOT / "scripts/debug/shopping_blender_environment_v4_candidate_lab.gd").read_text(encoding="utf-8")
    assert "HUMAN_REVIEW_REQUIRED" in gd
    assert "SDS_V4_CANONICAL" in gd
    assert "canonical=false" in gd
