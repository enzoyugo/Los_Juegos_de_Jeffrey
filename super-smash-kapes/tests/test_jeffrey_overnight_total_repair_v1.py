"""Overnight repair V1 — regressions from manual smoke failures."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_costanera_h_is_explicitly_typed() -> None:
    src = _read("scripts/stages/costanera_stage.gd")
    assert "var h: float" in src
    assert "var h :=" not in src


def test_smash_ko_guards_show_ko() -> None:
    src = _read("scripts/core/m0_playground.gd")
    assert 'has_method("show_ko")' in src
    assert "stage_visual.show_ko()" in src


def test_all_catalog_stages_have_ko_contract() -> None:
    base = _read("scripts/stages/jeffrey_smash_stage_base.gd")
    defensores = _read("scripts/stages/defensores_stage.gd")
    assert "func show_ko()" in base
    assert "func show_final_ko()" in base
    assert "func show_ko()" in defensores
    catalog = _read("scripts/stages/stage_catalog.gd")
    for scene in (
        "DefensoresDelChacoStage.tscn",
        "PalacioDeLopezStage.tscn",
        "CostaneraDeAsuncionStage.tscn",
    ):
        assert scene in catalog
        tscn = _read(f"scenes/stages/{scene}")
        assert "script" in tscn.lower() or "ExtResource" in tscn


def test_track_menu_uses_shared_character_portrait() -> None:
    menu = _read("scripts/ui/jeffrey/track_menu_screen.gd")
    definition = _read("scripts/core/jeffrey/shared_character_definition.gd")
    assert "portrait_texture" not in menu
    assert "var portrait: Texture2D" in definition
    assert "def.portrait" in menu


def test_track_main_defaults_to_four_wheel() -> None:
    main = _read("scripts/track/track_main.gd")
    assert "FOUR_WHEEL_SCENE_PATH" in main
    assert "TrackCarWheelPhysics.tscn" in main
    assert 'controller=FOUR_WHEEL_V1"' in main or "controller=FOUR_WHEEL_V1" in main
    assert 'override == "BASELINE"' in main
    wheel_scene = _read("scenes/track/TrackCarWheelPhysics.tscn")
    assert "use_articulated = true" in wheel_scene


def test_articulated_v3_glb_exists() -> None:
    glb = PROJECT_ROOT / "assets/vehicles/track/processed/track_car_base_v3_articulated_clean.glb"
    assert glb.exists()
    assert glb.stat().st_size > 500_000


def test_zombies_lifecycle_avoids_orphan_restart() -> None:
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    main = _read("scripts/zombies/zombies_main.gd")
    assert "_clear_mode_hosts" in app
    assert "jeffrey_zombies_host" in main
    assert 'zombies_host.call("_restart")' not in app
    assert "jeffrey_mode_host" in app


def test_modes_are_playable_in_hub() -> None:
    registry = _read("scripts/core/jeffrey/game_mode_registry.gd")
    assert '"Track"' in registry
    assert registry.count("ModeDef.AVAIL_PLAYABLE") >= 3
    assert "\t\ttrue,\n\t\t2,\n\t\t10," in registry
    assert "\t\ttrue,\n\t\t1,\n\t\t2," in registry


def test_zombies_production_env_is_v3() -> None:
    zmap = _read("scripts/zombies/zombies_map.gd")
    assert "shopping_del_sol_zombies_environment_v3.glb" in zmap
    assert "v4_3_candidate.glb" not in zmap
    assert "lab-only" in zmap or "V3" in zmap
