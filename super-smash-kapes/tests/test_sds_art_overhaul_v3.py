"""SDS V3 art overhaul firewalls. Gameplay loop unchanged."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_v3_files_exist() -> None:
    for rel in (
        "tools/blender/zombies/build_sds_environment_v3.py",
        "scenes/debug/ShoppingBlenderEnvironmentV3Lab.tscn",
        "scripts/debug/shopping_blender_environment_v3_lab.gd",
        "assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v3.glb",
        "assets/environments/shopping_del_sol/processed/textures/sds_interior_tile_v3.png",
        "assets/environments/shopping_del_sol/processed/textures/sds_plaza_tile_v3.png",
        "docs/SHOPPING_DEL_SOL_ART_OVERHAUL_V3_REPORT.md",
        "docs/generated/sds_v3_authority_frames.txt",
        "docs/generated/sds_v3_asset_decisions.json",
    ):
        assert (PROJECT_ROOT / rel).exists(), rel


def test_gameplay_firewalls() -> None:
    zcfg = _read("scripts/zombies/zombies_config.gd")
    assert "MAIN_ENTRANCE_COST := 1500" in zcfg
    mmap = _read("scripts/zombies/zombies_map.gd")
    assert "BLENDER_ENV_V3" in mmap
    assert "raw_models" not in mmap
    assert "_hide_codebuilt_visuals" in mmap
    assert "CORE_DIR_V8_15M" not in _read("scripts/track/track_main.gd")


def test_v3_prefers_lab() -> None:
    f6 = _read("scripts/debug/f6_repeat_stability_lab.gd")
    assert "ShoppingBlenderEnvironmentV3Lab.tscn" in f6
    glb = PROJECT_ROOT / "assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v3.glb"
    assert glb.stat().st_size > 1_000_000
