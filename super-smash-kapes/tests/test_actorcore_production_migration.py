"""ActorCore production migration + GPU resource lifecycle regressions."""

from pathlib import Path
import json
import struct


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def _glb_json(path: Path) -> dict:
    with path.open("rb") as fh:
        magic = fh.read(4)
        assert magic == b"glTF", path
        _version, _length = struct.unpack("<II", fh.read(8))
        chunk_len, chunk_type = struct.unpack("<I4s", fh.read(8))
        payload = fh.read(chunk_len)
        assert chunk_type in (b"JSON", b"json")
    return json.loads(payload.decode("utf-8"))


def test_canonical_actorcore_v3_glbs_exist() -> None:
    for rel in (
        "assets/fighters/processed/terere/terere_game_ready_v3.glb",
        "assets/fighters/processed/jaguarete/jaguarete_game_ready_v3.glb",
        "assets/fighters/processed/terere/terere_game_ready_v4.glb",
        "assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb",
    ):
        path = PROJECT_ROOT / rel
        assert path.is_file(), path
        assert path.stat().st_size > 1_000_000


def test_actorcore_v3_contains_idle_and_skin() -> None:
    for rel in (
        "assets/fighters/processed/terere/terere_game_ready_v4.glb",
        "assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb",
    ):
        data = _glb_json(PROJECT_ROOT / rel)
        names = [a.get("name", "") for a in data.get("animations", [])]
        assert any(n.lower() == "idle" or n.lower().endswith("idle") for n in names), names
        assert data.get("skins"), rel
        assert data.get("meshes"), rel
        nodes = data.get("nodes", [])
        mixamo = [n.get("name", "") for n in nodes if "mixamo" in n.get("name", "").lower()]
        assert mixamo == [], mixamo


def test_fighter_catalog_uses_actorcore_v3() -> None:
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert "terere_actorcore_visual.gd" in catalog
    assert "jaguarete_actorcore_visual.gd" in catalog
    assert "terere_game_ready_v4.glb" in catalog
    assert "jaguarete_game_ready_v4.glb" in catalog
    assert "pipeline_id = \"ACTORCORE_V4\"" in catalog
    assert "terere_glb_visual.gd" not in catalog
    assert "jaguarete_rigged_visual.gd" not in catalog
    assert "TerereGLBVisual.tscn" not in catalog
    assert "JaguareteRiggedVisual.tscn" not in catalog
    assert "actorcore_benchmark" not in catalog
    assert "raw_design" not in catalog
    assert "fallback_visual_path" in catalog
    assert "load(\"res://fighters/terere/terere_visual.gd\")" not in catalog
    assert "load(\"res://fighters/jaguarete/jaguarete_visual.gd\")" not in catalog
    assert "victory_texture_path" in catalog
    assert "victory_texture = load" not in catalog


def test_old_3dai_models_are_not_production_authority() -> None:
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    terere = _read("fighters/terere/terere_actorcore_visual.gd")
    jaguarete = _read("fighters/jaguarete/jaguarete_actorcore_visual.gd")
    for blob in (catalog, terere, jaguarete):
        assert "terere_glb_1.glb" not in blob
        assert "jaguarete_v2.glb" not in blob
        assert "jaguarete_game_ready_idle.glb" not in blob
        assert "actorcore_benchmark" not in blob


def test_actorcore_runtime_retarget_off_and_play_api() -> None:
    visual = _read("scripts/fighters/actorcore_fighter_visual.gd")
    assert "runtime_retarget=false" in visual
    assert 'func play_animation(semantic: String)' in visual
    for clip in ("idle", "run", "jump", "attack_neutral", "hit_light", "ko", "victory"):
        assert clip in visual
    assert "PIPELINE_ID := \"ACTORCORE_V4\"" in visual
    assert "_idle_uses_skeletal" in visual
    assert "proxy_idle" in visual


def test_skeletal_idle_disables_proxy_bob() -> None:
    glb = _read("scripts/fighters/glb_fighter_visual.gd")
    actor = _read("scripts/fighters/actorcore_fighter_visual.gd")
    assert "func _idle_uses_skeletal" in glb
    assert "_idle_uses_skeletal()" in glb
    assert "bob = 0.0" in glb
    assert 'return _skeletal_idle_bound and not _using_fallback' in actor


def test_canonical_production_sizes() -> None:
    terere = _read("fighters/terere/terere_actorcore_visual.gd")
    jaguarete = _read("fighters/jaguarete/jaguarete_actorcore_visual.gd")
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert "target_visual_height = 2.40" in terere
    assert "target_visual_height = 3.15" in jaguarete
    assert "target_visual_height = 2.40" in catalog
    assert "target_visual_height = 3.15" in catalog


def test_one_visual_instance_contract() -> None:
    fighter = _read("scripts/fighters/fighter.gd")
    visual = _read("scripts/fighters/actorcore_fighter_visual.gd")
    assert "visual_root.add_child(character_visual)" in fighter
    assert fighter.count("add_child(character_visual)") == 1
    assert "visual_instances=1" in visual
    assert "ActorCoreFighterVisual" not in fighter


def test_fallback_resources_are_lazy() -> None:
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    fighter = _read("scripts/fighters/fighter.gd")
    glb = _read("scripts/fighters/glb_fighter_visual.gd")
    assert "fallback_visual_path" in catalog
    assert "fallback_visual_script = load" not in catalog
    assert "visual_scene = load" not in catalog
    assert "load_fallback_visual_script" in fighter
    assert "fallback_visual_path" in glb
    assert "[FIGHTER_PIPELINE][ERROR]" in glb
    assert "[FIGHTER_PIPELINE][ERROR]" in fighter
    assert "Baked GLB missing" not in glb
    assert "Baked GLB missing" not in fighter


def test_menu_and_results_not_preloaded_during_battle() -> None:
    main = _read("scripts/core/main.gd")
    assert 'const MENU_SCREEN := "res://scripts/ui/kapes_menu_screen.gd"' in main
    assert 'const RESULTS_SCREEN := "res://scripts/ui/kapes_results_screen.gd"' in main
    assert 'const CHARACTER_SELECT := "res://scripts/ui/kapes_character_select.gd"' in main
    assert "preload(\"res://scripts/ui/kapes_results_screen.gd\")" not in main
    assert "preload(\"res://scripts/ui/kapes_character_select.gd\")" not in main
    assert "preload(\"res://scripts/ui/kapes_menu_screen.gd\")" not in main
    assert "screen_root.queue_free()" in main
    stage = _read("scripts/stages/defensores_stage.gd")
    assert 'preload("res://assets/stages/defensores_del_chaco/mosaics/mosaic_variants.png")' not in stage
    assert 'preload("res://assets/stages/defensores_del_chaco/crowd/crowd_strips.png")' not in stage
    results = _read("scripts/ui/kapes_results_screen.gd")
    assert "preload(\"res://assets/ui/victory" not in results


def test_no_duplicate_stage_hero_background() -> None:
    stage = _read("scripts/stages/defensores_stage.gd")
    camera = _read("scripts/stages/stadium_camera_background.gd")
    assert 'preload("res://assets/stages/defensores_del_chaco/background/defensores_bg_main.png")' not in stage
    assert "defensores_bg_main.png" in camera
    assert 'name = "StadiumBackgroundQuad"' in camera
    assert 'get_node_or_null("StadiumBackgroundQuad")' in stage


def test_hit_flash_does_not_deep_duplicate_textures() -> None:
    glb = _read("scripts/fighters/glb_fighter_visual.gd")
    assert "duplicate(false)" in glb
    assert "_vram_compress_runtime_textures" in glb
    assert "_cache_flash_materials" in glb


def test_pipeline_audit_env_flag() -> None:
    visual = _read("scripts/fighters/actorcore_fighter_visual.gd")
    assert "SSK_FIGHTER_PIPELINE_AUDIT" in visual
    assert "[FIGHTER_PIPELINE]" in visual
    assert "skeleton_bones=" in visual


def test_portraits_remain_independent_2d_assets() -> None:
    catalog = _read("scripts/fighters/fighter_catalog.gd")
    assert "terere_portrait.png" in catalog
    assert "jaguarete_portrait.png" in catalog
    hud = _read("scripts/ui/kapes_player_hud.gd")
    assert "portrait_texture" in hud
    select = _read("scripts/ui/kapes_character_select.gd")
    assert "portrait" in select.lower()


def test_rematch_lifecycle_cleanup_hooks() -> None:
    main = _read("scripts/core/main.gd")
    playground = _read("scripts/core/m0_playground.gd")
    assert "func _restart_match" in main
    assert "active_match.queue_free()" in main
    assert "restart_requested" in playground
    assert (PROJECT_ROOT / "scripts/debug/rematch_resource_stability.gd").is_file()


def test_material_override_shares_textures() -> None:
    glb = _read("scripts/fighters/glb_fighter_visual.gd")
    assert "_cache_flash_materials" in glb
    assert "duplicate(false)" in glb
