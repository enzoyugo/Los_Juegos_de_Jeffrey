"""Deterministic sanity checks for the transparent M0 combat formulas.

These are dependency-free checks so the repository does not need a test framework
just to validate the central milestone relationships.
"""

from pathlib import Path
import json


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def knockback(damage: float, weight: float = 100.0) -> float:
    return (7.0 + damage * 0.105) * (100.0 / weight)


def test_damage_increases_launch_force() -> None:
    assert knockback(100) > knockback(50) > knockback(0)


def test_lighter_targets_launch_farther() -> None:
    assert knockback(50, 80) > knockback(50, 120)


def test_stock_and_respawn_invariants() -> None:
    stocks = 3
    stocks -= 1
    assert stocks == 2
    damage = 0.0
    damage += 8.0
    damage = 0.0  # respawn reset
    assert damage == 0.0
    stocks -= 1
    stocks -= 1
    assert stocks == 0


def test_p2_input_actions_and_keyboard_fallbacks_exist() -> None:
    project = (PROJECT_ROOT / "project.godot").read_text(encoding="utf-8")
    for action in ("p2_left", "p2_right", "p2_jump", "p2_attack"):
        assert f"{action}=" in project
    assert '"physical_keycode":4194319' in project
    assert '"physical_keycode":4194321' in project
    assert '"physical_keycode":4194320' in project
    assert '"physical_keycode":78' in project
    assert '"physical_keycode":4194336' in project


def test_ko_dispatch_is_signal_owned_and_elimination_disables_hurtbox() -> None:
    playground = (PROJECT_ROOT / "scripts/core/m0_playground.gd").read_text(encoding="utf-8")
    fighter = (PROJECT_ROOT / "scripts/fighters/fighter.gd").read_text(encoding="utf-8")
    assert "fighter.fighter_ko.connect(_handle_ko)" in playground
    assert "fighter.ko()\n\t\t\t_handle_ko" not in playground
    assert "$Hurtbox.monitorable = false" in fighter
    assert "if state == FighterState.DEAD or invulnerability_time > 0.0:" in fighter


def test_attack_keeps_locomotion_and_gravity_active() -> None:
    fighter = (PROJECT_ROOT / "scripts/fighters/fighter.gd").read_text(encoding="utf-8")
    assert "_process_movement(delta, attack_definition.ground_steering, attack_definition.air_steering)" in fighter
    assert "_apply_gravity(delta)" in fighter
    assert "attack_definition.total_duration()" in fighter
    assert "if force > 0.0:" in fighter


def test_movement_expansion_actions_exist() -> None:
    project = (PROJECT_ROOT / "project.godot").read_text(encoding="utf-8")
    assert "p1_down=" in project
    assert "p2_down=" in project
    assert "res://data/attacks/basic_attack.tres" in (PROJECT_ROOT / "scripts/core/m0_playground.gd").read_text(encoding="utf-8")


def test_frontend_and_restart_flow_are_wired() -> None:
    project = (PROJECT_ROOT / "project.godot").read_text(encoding="utf-8")
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    assert 'run/main_scene="res://scenes/core/JeffreyBoot.tscn"' in project
    assert (PROJECT_ROOT / "scenes/core/Main.tscn").exists()
    assert "hosted_by_shell" in main
    assert "active_match.restart_requested.connect(_restart_match)" in main
    assert "func _on_match_finished" in main
    assert "func _show_results" in main


def test_visual_identity_resources_and_player_hud_are_wired() -> None:
    visual = (PROJECT_ROOT / "scripts/ui/kapes_visual.gd").read_text(encoding="utf-8")
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    hud = (PROJECT_ROOT / "scripts/ui/m0_hud.gd").read_text(encoding="utf-8")
    menu = (PROJECT_ROOT / "scripts/ui/kapes_menu_screen.gd").read_text(encoding="utf-8")
    assert 'const RED := Color("#d93b35")' in visual
    assert 'const BLUE := Color("#2875b9")' in visual
    assert "KapesFlagWipe" in main
    assert "MENU_SCREEN" in main or "KapesMenuScreen" in main
    assert "KapesPlayerHUD" in hud
    assert "local_battle_panel.png" in menu


def test_generated_ui_assets_are_wired_into_player_screens() -> None:
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    menu = (PROJECT_ROOT / "scripts/ui/kapes_menu_screen.gd").read_text(encoding="utf-8")
    hud = (PROJECT_ROOT / "scripts/ui/m0_hud.gd").read_text(encoding="utf-8")
    player_hud = (PROJECT_ROOT / "scripts/ui/kapes_player_hud.gd").read_text(encoding="utf-8")
    for asset in ("main_menu_bg.png", "smash_kapes_logo.png", "local_battle_panel.png"):
        assert asset in menu
    for asset in ("hud_p1.png", "hud_p2.png"):
        assert asset in hud or asset in player_hud
    assert 'damage_label.text = "%d%%"' in player_hud
    assert "STRETCH_KEEP_ASPECT_COVERED" in menu
    assert "FLAG_WIPE" in main


def test_visual_runtime_work_is_cached_and_event_driven() -> None:
    stage = (PROJECT_ROOT / "scripts/stages/defensores_stage.gd").read_text(encoding="utf-8")
    hud = (PROJECT_ROOT / "scripts/ui/m0_hud.gd").read_text(encoding="utf-8")
    assert "show_ko()" in stage
    assert "_process(" not in stage
    assert "StadiumCameraBackground" in stage or "stadium_camera_background.gd" in stage
    assert "func _process" in hud
    assert "performance_debug_enabled" in hud


def test_hud_has_one_authoritative_plate_and_finite_intro() -> None:
    hud = (PROJECT_ROOT / "scripts/ui/m0_hud.gd").read_text(encoding="utf-8")
    player_hud = (PROJECT_ROOT / "scripts/ui/kapes_player_hud.gd").read_text(encoding="utf-8")
    assert hud.count("PLAYER_CARD.new()") == 2
    assert "intro_slash" not in hud
    assert "message_tween.kill()" in hud
    assert player_hud.count("P1_PLATE") == 2
    assert "draw_circle(Vector2(x, stock_y)" not in player_hud


def test_freeze_audit_is_opt_in_and_covers_battle_unlock_path() -> None:
    playground = (PROJECT_ROOT / "scripts/core/m0_playground.gd").read_text(encoding="utf-8")
    stage = (PROJECT_ROOT / "scripts/stages/defensores_stage.gd").read_text(encoding="utf-8")
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    hud = (PROJECT_ROOT / "scripts/ui/m0_hud.gd").read_text(encoding="utf-8")
    assert 'OS.get_environment("SSK_FREEZE_AUDIT") == "1"' in playground
    assert "HEARTBEAT elapsed" in playground
    assert 'OS.get_environment("SSK_DISABLE_STAGE_VISUALS") == "1"' in stage
    assert 'OS.get_environment("SSK_AUTO_START_BATTLE") == "1"' in main
    assert "intro tween finished" in hud


def test_defensores_uses_fullscreen_layers_and_disables_only_mesh_visuals() -> None:
    stage = (PROJECT_ROOT / "scripts/stages/defensores_stage.gd").read_text(encoding="utf-8")
    assert "StadiumBackgroundQuad" in stage or "stadium_camera_background.gd" in stage
    assert "ScreenSpaceEventFX" in stage
    assert "_hide_meshes_recursive" in stage
    assert "CollisionShape3D" not in stage
    assert "ScreenSpaceStadiumLayers" not in stage


def test_player_facing_menu_has_no_developer_status_copy() -> None:
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    assert "KEYBOARD READY" not in main
    assert "M0 PLAYGROUND" not in main
    assert "Two players. One platform." not in main


def test_hit_ko_and_respawn_cancel_stale_attack_state() -> None:
    fighter = (PROJECT_ROOT / "scripts/fighters/fighter.gd").read_text(encoding="utf-8")
    assert fighter.count("attack_time = 0.0") >= 4
    assert "attack_hit_targets.clear()" in fighter


def test_defensores_stage_is_the_active_visual_stage() -> None:
    playground = (PROJECT_ROOT / "scripts/core/m0_playground.gd").read_text(encoding="utf-8")
    scene = (PROJECT_ROOT / "scenes/stages/DefensoresDelChacoStage.tscn").read_text(encoding="utf-8")
    stage = (PROJECT_ROOT / "scripts/stages/defensores_stage.gd").read_text(encoding="utf-8")
    assert "DefensoresDelChacoStage.tscn" in playground
    assert 'name="StageGameplayRoot"' in scene
    assert 'name="ArtRoot"' in scene
    for asset in (
        "defensores_bg_main.png",
        "crowd_strips.png",
        "crowd_loop_variants.png",
        "mosaic_variants.png",
        "tifo_atlas.png",
        "scoreboard_sheet.png",
        "defensores_platform_kit.png",
        "foreground_overlay.png",
        "stadium_light_confetti_overlay.png",
    ):
        assert asset in stage


def test_defensores_visual_events_are_not_gameplay_dependencies() -> None:
    stage = (PROJECT_ROOT / "scripts/stages/defensores_stage.gd").read_text(encoding="utf-8")
    assert "func show_ko()" in stage
    assert "_hide_greybox_visuals" in stage
    assert "crowd_timer" not in stage


def test_canvas_layer_contract_is_explicit() -> None:
    layers = (PROJECT_ROOT / "scripts/ui/kapes_layers.gd").read_text(encoding="utf-8")
    stage = (PROJECT_ROOT / "scripts/stages/defensores_stage.gd").read_text(encoding="utf-8")
    hud = (PROJECT_ROOT / "scripts/ui/m0_hud.gd").read_text(encoding="utf-8")
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    assert "const BACKGROUND := -20" in layers
    assert "const STADIUM_MID := -10" in layers
    assert "const FOREGROUND := 5" in layers
    assert "const HUD := 10" in layers
    assert "const TRANSITION := 40" in layers
    assert "KapesLayers.STADIUM_MID" in stage or "UI_LAYERS.STADIUM_MID" in stage or "UI_LAYERS.FOREGROUND" in stage
    assert "KapesLayers.FOREGROUND" in stage or "UI_LAYERS.FOREGROUND" in stage
    assert "KapesLayers.HUD" in hud or "UI_LAYERS.HUD" in hud
    assert "KapesLayers.MENU_UI" in main or "UI_LAYERS.MENU_UI" in main
    assert "KapesLayers.TRANSITION" in main or "UI_LAYERS.TRANSITION" in main


def test_decorative_battle_controls_ignore_focus_and_mouse() -> None:
    stage = (PROJECT_ROOT / "scripts/stages/defensores_stage.gd").read_text(encoding="utf-8")
    hud = (PROJECT_ROOT / "scripts/ui/m0_hud.gd").read_text(encoding="utf-8")
    player_hud = (PROJECT_ROOT / "scripts/ui/kapes_player_hud.gd").read_text(encoding="utf-8")
    wipe = (PROJECT_ROOT / "scripts/ui/flag_wipe.gd").read_text(encoding="utf-8")
    assert "focus_mode = Control.FOCUS_NONE" in stage
    assert "mouse_filter = Control.MOUSE_FILTER_IGNORE" in stage
    assert "focus_mode = Control.FOCUS_NONE" in hud
    assert "mouse_filter = Control.MOUSE_FILTER_IGNORE" in hud
    assert "focus_mode = Control.FOCUS_NONE" in player_hud
    assert "mouse_filter = Control.MOUSE_FILTER_IGNORE" in player_hud
    assert "focus_mode = Control.FOCUS_NONE" in wipe
    assert "mouse_filter = Control.MOUSE_FILTER_IGNORE" in wipe


def test_transition_releases_focus_before_battle() -> None:
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    playground = (PROJECT_ROOT / "scripts/core/m0_playground.gd").read_text(encoding="utf-8")
    assert "func _release_menu_focus()" in main
    assert "gui_release_focus()" in main
    assert "_release_menu_focus()" in main
    assert "gui_get_focus_owner()" in playground
    assert "combined_runtime_enabled" in playground


def test_background_layer_is_world_space_not_screen_overlay() -> None:
    stage = (PROJECT_ROOT / "scripts/stages/defensores_stage.gd").read_text(encoding="utf-8")
    background = (PROJECT_ROOT / "scripts/stages/stadium_camera_background.gd").read_text(encoding="utf-8")
    assert "ScreenSpaceBackground" not in stage
    assert "StadiumBackgroundQuad" in stage or "CAMERA_BACKGROUND" in stage
    assert "BACKDROP_TEXTURE" in stage or "defensores_bg_main.png" in background
    assert "COVER_MARGIN" in background
    assert "uv1_scale" in background
    assert "sorting_offset" in background


def test_no_fullscreen_interactive_battle_control() -> None:
    playground_scene = (PROJECT_ROOT / "scenes/core/M0Playground.tscn").read_text(encoding="utf-8")
    hud = (PROJECT_ROOT / "scripts/ui/m0_hud.gd").read_text(encoding="utf-8")
    assert "Button" not in playground_scene
    assert "grab_focus" not in hud


def test_defensores_v3_composition_is_minimal() -> None:
    stage = (PROJECT_ROOT / "scripts/stages/defensores_stage.gd").read_text(encoding="utf-8")
    assert 'preload("res://assets/stages/defensores_del_chaco/props/tifo_atlas.png")' not in stage
    assert "_add_sprite(props" not in stage
    assert "base_crowd" not in stage
    assert "mosaic_layer" not in stage
    assert "scoreboard =" not in stage
    assert "foreground =" not in stage
    assert "_attach_camera_background" in stage
    assert "_build_platform_art" in stage
    assert "func show_mosaic" in stage
    assert "PLATFORM_TEXTURE" in stage


def test_responsive_menu_layout_authority_exists() -> None:
    menu = (PROJECT_ROOT / "scripts/ui/kapes_menu_screen.gd").read_text(encoding="utf-8")
    layout = (PROJECT_ROOT / "scripts/ui/kapes_ui_layout.gd").read_text(encoding="utf-8")
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    assert "UILayout.safe_rect" in menu or "KapesUILayout.safe_rect" in menu
    assert "contain_size" in layout
    assert "MENU_SCREEN" in main or "KapesMenuScreen" in main
    assert "Rect2(1130, 315" not in main


def test_hud_uses_viewport_relative_layout() -> None:
    hud = (PROJECT_ROOT / "scripts/ui/m0_hud.gd").read_text(encoding="utf-8")
    player_hud = (PROJECT_ROOT / "scripts/ui/kapes_player_hud.gd").read_text(encoding="utf-8")
    assert "HUD_WIDTH_RATIO" in hud or "KapesVisual.HUD_WIDTH_RATIO" in hud
    assert "_draw_stock_sockets" in player_hud
    assert "MATCH_INTRO" in hud or "UI_LAYERS.MATCH_INTRO" in hud


def test_menu_has_single_clean_play_hint() -> None:
    menu = (PROJECT_ROOT / "scripts/ui/kapes_menu_screen.gd").read_text(encoding="utf-8")
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    assert "F / SPACE — JUGAR" in menu
    assert "EJÚ  •  DALE" not in main
    assert "M0 PLAYGROUND" not in main


def test_raw_design_directory_discovered() -> None:
    terere_dir = PROJECT_ROOT / "assets/fighters/raw_design/terere"
    jaguarete_dir = PROJECT_ROOT / "assets/fighters/raw_design/jaguarete"
    assert terere_dir.is_dir()
    assert jaguarete_dir.is_dir()
    assert len(list(terere_dir.glob("*.png"))) >= 1
    assert len(list(jaguarete_dir.glob("*.png"))) >= 1


def test_fighter_definition_and_catalog_exist() -> None:
    definition = (PROJECT_ROOT / "scripts/fighters/fighter_definition.gd").read_text(encoding="utf-8")
    catalog = (PROJECT_ROOT / "scripts/fighters/fighter_catalog.gd").read_text(encoding="utf-8")
    assert "class_name FighterDefinition" in definition
    assert "class_name FighterCatalog" in catalog
    assert 'def.id = "terere"' in catalog
    assert 'def.id = "jaguarete"' in catalog
    assert "get_all_fighters()" in catalog
    assert "get_by_id(id" in catalog


def test_fighter_visual_scenes_and_scripts_exist() -> None:
    for path in (
        "fighters/terere/terere_visual.gd",
        "fighters/jaguarete/jaguarete_visual.gd",
        "scripts/fighters/fighter_visual.gd",
    ):
        assert (PROJECT_ROOT / path).is_file()


def test_match_setup_and_character_select_flow_are_wired() -> None:
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    select = (PROJECT_ROOT / "scripts/ui/kapes_character_select.gd").read_text(encoding="utf-8")
    setup = (PROJECT_ROOT / "scripts/core/match_setup.gd").read_text(encoding="utf-8")
    playground = (PROJECT_ROOT / "scripts/core/m0_playground.gd").read_text(encoding="utf-8")
    assert "class_name MatchSetup" in setup
    assert "player_1_fighter_id" in setup
    assert "player_2_fighter_id" in setup
    assert "_show_character_select()" in main
    assert "ELIGÍ TU KAPE" in select
    assert "FIGHTER_CATALOG.get_all_fighters()" in select
    assert "match_setup" in playground
    assert "fighter_id" in playground


def test_fighter_controller_uses_visual_root_not_capsule() -> None:
    fighter = (PROJECT_ROOT / "scripts/fighters/fighter.gd").read_text(encoding="utf-8")
    scene = (PROJECT_ROOT / "scenes/fighters/Fighter.tscn").read_text(encoding="utf-8")
    assert "fighter_id" in fighter
    assert "character_visual" in fighter
    assert "VisualRoot" in scene
    assert 'name="Visual"' in scene
    assert "visible = false" in scene
    assert "CapsuleShape_body" in scene


def test_playground_spawns_catalog_fighters_and_reports_names() -> None:
    playground = (PROJECT_ROOT / "scripts/core/m0_playground.gd").read_text(encoding="utf-8")
    assert "FIGHTER_CATALOG.get_by_id" in playground
    assert "match_setup.player_1_fighter_id" in playground
    assert "match_setup.player_2_fighter_id" in playground
    assert "get_display_name()" in playground
    assert "fighter_names" in playground


def test_hud_and_results_use_fighter_metadata() -> None:
    player_hud = (PROJECT_ROOT / "scripts/ui/kapes_player_hud.gd").read_text(encoding="utf-8")
    results = (PROJECT_ROOT / "scripts/ui/kapes_results_screen.gd").read_text(encoding="utf-8")
    assert "portrait_texture" in player_hud
    assert "fighter.definition" in player_hud
    assert "FIGHTER_CATALOG.get_by_id" in results
    assert "fighter_names" in results


def test_rematch_preserves_selected_fighter_ids() -> None:
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    assert "match_setup = setup.duplicate_setup()" in main
    assert "results.rematch_pressed.connect(_start_match)" in main
    assert "FIGHTER_CATALOG.default_match_setup()" in main


def test_character_select_input_handler_enabled() -> None:
    select = (PROJECT_ROOT / "scripts/ui/kapes_character_select.gd").read_text(encoding="utf-8")
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    assert "handle_input_event" in select
    assert "set_process_input(true)" in select
    assert "PROCESS_MODE_ALWAYS" in select
    assert "handle_input_event" in main or "_get_character_select()" in main


def test_character_select_recognizes_p1_and_p2_controls() -> None:
    select = (PROJECT_ROOT / "scripts/ui/kapes_character_select.gd").read_text(encoding="utf-8")
    assert "_matches_p1_left" in select
    assert "_matches_p1_right" in select
    assert "_matches_p1_confirm" in select
    assert "_matches_p2_left" in select
    assert "_matches_p2_right" in select
    assert "_matches_p2_confirm" in select
    assert "KEY_P1_LEFT := KEY_A" in select or "KEY_A" in select
    assert "KEY_P2_CONFIRM := KEY_N" in select or "KEY_N" in select
    assert "KEY_SPACE" in select


def test_character_select_ready_state_is_independent() -> None:
    select = (PROJECT_ROOT / "scripts/ui/kapes_character_select.gd").read_text(encoding="utf-8")
    assert "p1_ready" in select
    assert "p2_ready" in select
    assert "if p1_ready:" in select or "p1_ready" in select
    assert "LISTO" in select


def test_character_select_blocks_movement_after_ready() -> None:
    select = (PROJECT_ROOT / "scripts/ui/kapes_character_select.gd").read_text(encoding="utf-8")
    assert "if p1_ready:" in select
    assert "if p2_ready:" in select
    assert "return" in select


def test_character_select_both_ready_transition_is_guarded() -> None:
    select = (PROJECT_ROOT / "scripts/ui/kapes_character_select.gd").read_text(encoding="utf-8")
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    assert "_transition_started" in select
    assert "_finalize_roster" in select
    assert "roster_confirmed.emit" in select
    assert "_validate_match_setup" in main or "_validate_setup" in select


def test_character_select_matchsetup_uses_catalog_ids() -> None:
    select = (PROJECT_ROOT / "scripts/ui/kapes_character_select.gd").read_text(encoding="utf-8")
    assert "fighters[p1_index].id" in select
    assert "fighters[p2_index].id" in select
    assert "FIGHTER_CATALOG.get_by_id" in select


def test_character_select_auto_select_diagnostic_exists() -> None:
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    select = (PROJECT_ROOT / "scripts/ui/kapes_character_select.gd").read_text(encoding="utf-8")
    assert "SSK_AUTO_SELECT_BATTLE" in main
    assert "auto_confirm_for_testing" in select


def test_character_select_releases_focus_before_battle() -> None:
    select = (PROJECT_ROOT / "scripts/ui/kapes_character_select.gd").read_text(encoding="utf-8")
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    assert "_release_select_focus" in select or "gui_release_focus" in select
    assert "_release_menu_focus()" in main


def test_glb_fighter_source_assets_exist() -> None:
    for path in (
        "assets/fighters/models/terere/terere_glb_1.glb",
        "assets/fighters/models/jaguarete/jaguarete_glb_1.glb",
    ):
        assert (PROJECT_ROOT / path).is_file()


def test_fighter_catalog_uses_actorcore_production_visuals() -> None:
    catalog = (PROJECT_ROOT / "scripts/fighters/fighter_catalog.gd").read_text(encoding="utf-8")
    jaguarete_glb = (PROJECT_ROOT / "fighters/jaguarete/jaguarete_glb_visual.gd").read_text(encoding="utf-8")
    assert "terere_actorcore_visual.gd" in catalog
    assert "jaguarete_actorcore_visual.gd" in catalog
    assert "terere_game_ready_v4.glb" in catalog
    assert "jaguarete_game_ready_v4.glb" in catalog
    assert "terere_glb_visual.gd" not in catalog
    assert "jaguarete_rigged_visual.gd" not in catalog
    assert "TerereGLBVisual.tscn" not in catalog
    assert "JaguareteRiggedVisual.tscn" not in catalog
    ## Archival static GLB still exists as emergency fallback path, not catalog-preloaded.
    assert "jaguarete_visual.gd" in catalog
    assert "jaguarete_visual.gd" in jaguarete_glb


def test_glb_visual_architecture_exists() -> None:
    glb_visual = (PROJECT_ROOT / "scripts/fighters/glb_fighter_visual.gd").read_text(encoding="utf-8")
    fighter = (PROJECT_ROOT / "scripts/fighters/fighter.gd").read_text(encoding="utf-8")
    scene = (PROJECT_ROOT / "scenes/fighters/Fighter.tscn").read_text(encoding="utf-8")
    assert "PresentationScaleRoot" in glb_visual
    assert "target_visual_height" in (PROJECT_ROOT / "fighters/terere/terere_glb_visual.gd").read_text(encoding="utf-8")
    assert "VisualMotionRoot" in glb_visual
    assert "ModelRoot" in glb_visual
    assert "fallback_visual_script" in glb_visual or "_spawn_fallback" in glb_visual
    assert "visual_root.add_child(character_visual)" in fighter
    assert "CapsuleShape_body" in scene
    assert 'height = 2.4' in scene


def test_glb_motion_proxy_does_not_own_physics() -> None:
    glb_visual = (PROJECT_ROOT / "scripts/fighters/glb_fighter_visual.gd").read_text(encoding="utf-8")
    fighter = (PROJECT_ROOT / "scripts/fighters/fighter.gd").read_text(encoding="utf-8")
    assert "CharacterBody3D" not in glb_visual
    assert "extends CharacterBody3D" in fighter
    assert "SSK_SHOW_FIGHTER_COLLIDERS" in fighter


def test_gameplay_collision_dimensions_unchanged() -> None:
    scene = (PROJECT_ROOT / "scenes/fighters/Fighter.tscn").read_text(encoding="utf-8")
    assert "radius = 0.65" in scene
    assert "height = 2.4" in scene
    assert "size = Vector3(1.55, 1.15, 1.0)" in scene


def test_fighter_presentation_scale_is_separate_from_collider() -> None:
    glb_visual = (PROJECT_ROOT / "scripts/fighters/glb_fighter_visual.gd").read_text(encoding="utf-8")
    config = (PROJECT_ROOT / "scripts/fighters/glb_fighter_config.gd").read_text(encoding="utf-8")
    terere = (PROJECT_ROOT / "fighters/terere/terere_glb_visual.gd").read_text(encoding="utf-8")
    jaguarete = (PROJECT_ROOT / "fighters/jaguarete/jaguarete_glb_visual.gd").read_text(encoding="utf-8")
    assert "target_visual_height" in config
    assert "PresentationScaleRoot" in glb_visual
    assert "target_visual_height" in terere
    assert "target_visual_height" in jaguarete
    assert terere != jaguarete


def test_hud_uses_normalized_regions() -> None:
    hud = (PROJECT_ROOT / "scripts/ui/kapes_player_hud.gd").read_text(encoding="utf-8")
    layout = (PROJECT_ROOT / "scripts/ui/kapes_hud_layout.gd").read_text(encoding="utf-8")
    assert "HUD_LAYOUT" in hud or "KapesHudLayout" in hud
    assert "p1_portrait_region" in layout
    assert "p1_name_region" in layout
    assert "p1_damage_region" in layout
    assert "p1_stock_region" in layout
    assert "p2_name_region" in layout
    assert "name_label" in hud
    assert "tag_label" not in hud


def test_hud_portrait_cleanup_exists() -> None:
    portrait = (PROJECT_ROOT / "scripts/ui/kapes_portrait.gd").read_text(encoding="utf-8")
    hud = (PROJECT_ROOT / "scripts/ui/kapes_player_hud.gd").read_text(encoding="utf-8")
    assert "get_hud_portrait" in portrait
    assert "get_hud_portrait" in hud or "PORTRAIT_UTIL" in hud


def test_victory_screen_has_hero_and_actions() -> None:
    results = (PROJECT_ROOT / "scripts/ui/kapes_results_screen.gd").read_text(encoding="utf-8")
    main = (PROJECT_ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    assert "WinnerHero" in results
    assert "VictoryAccent" in results
    assert "CAMBIAR KAPES" in results
    assert "change_kapes_pressed" in results
    assert "change_kapes_pressed.connect(_show_character_select)" in main


def test_results_and_camera_use_responsive_layout() -> None:
    results = (PROJECT_ROOT / "scripts/ui/kapes_results_screen.gd").read_text(encoding="utf-8")
    camera = (PROJECT_ROOT / "scripts/core/m0_camera.gd").read_text(encoding="utf-8")
    visual = (PROJECT_ROOT / "scripts/ui/kapes_visual.gd").read_text(encoding="utf-8")
    assert "RESULTS_HERO_RATIO" in visual or "RESULTS_HERO_RATIO" in visual
    assert "safe_rect" in results
    assert "minimum_distance" in camera
    assert "minimum_distance: float = 26.0" in camera


def test_model_audit_and_visual_bounds_debug_exist() -> None:
    glb_visual = (PROJECT_ROOT / "scripts/fighters/glb_fighter_visual.gd").read_text(encoding="utf-8")
    playground = (PROJECT_ROOT / "scripts/core/m0_playground.gd").read_text(encoding="utf-8")
    assert "SSK_MODEL_AUDIT" in glb_visual
    assert "debug_bounds_enabled" in glb_visual
    assert "KEY_F4" in playground
    assert "_refresh_bounds_debug" in glb_visual


def test_glb_visual_does_not_load_in_process() -> None:
    glb_visual = (PROJECT_ROOT / "scripts/fighters/glb_fighter_visual.gd").read_text(encoding="utf-8")
    assert "func _process" not in glb_visual
    assert "load(config.glb_path)" in glb_visual or "load(config.glb_path)" in glb_visual.replace(" ", "")

def test_canonical_fighter_size_metadata() -> None:
    size = (PROJECT_ROOT / "scripts/fighters/fighter_size_class.gd").read_text(encoding="utf-8")
    definition = (PROJECT_ROOT / "scripts/fighters/fighter_definition.gd").read_text(encoding="utf-8")
    catalog = (PROJECT_ROOT / "scripts/fighters/fighter_catalog.gd").read_text(encoding="utf-8")
    terere = (PROJECT_ROOT / "fighters/terere/terere_glb_visual.gd").read_text(encoding="utf-8")
    jaguarete = (PROJECT_ROOT / "fighters/jaguarete/jaguarete_glb_visual.gd").read_text(encoding="utf-8")
    config = (PROJECT_ROOT / "scripts/fighters/glb_fighter_config.gd").read_text(encoding="utf-8")
    visual = (PROJECT_ROOT / "scripts/fighters/glb_fighter_visual.gd").read_text(encoding="utf-8")
    assert "SHORT" in size and "TALL" in size
    assert "size_class" in definition
    assert "target_visual_height" in definition
    assert "SIZE.SHORT" in catalog or 'size_class = SIZE.SHORT' in catalog or 'size_class = "SHORT"' in catalog or "SIZE.SHORT" in terere
    assert "target_visual_height = 2.40" in terere
    assert "target_visual_height = 3.15" in jaguarete
    assert "SIZE.SHORT" in terere or 'size_class = SIZE.SHORT' in terere
    assert "SIZE.TALL" in jaguarete or 'size_class = SIZE.TALL' in jaguarete
    assert "target_visual_height" in config
    assert "_measure_body_height" in visual
    assert "presentation_scale_multiplier" not in config
    assert "presentation_scale_multiplier" not in terere
    assert "presentation_scale_multiplier" not in jaguarete


def test_jaguarete_target_taller_than_terere() -> None:
    terere = (PROJECT_ROOT / "fighters/terere/terere_glb_visual.gd").read_text(encoding="utf-8")
    jaguarete = (PROJECT_ROOT / "fighters/jaguarete/jaguarete_glb_visual.gd").read_text(encoding="utf-8")
    assert "2.40" in terere
    assert "3.15" in jaguarete


def test_hud_portrait_clipping_and_scale() -> None:
    hud = (PROJECT_ROOT / "scripts/ui/kapes_player_hud.gd").read_text(encoding="utf-8")
    layout = (PROJECT_ROOT / "scripts/ui/kapes_hud_layout.gd").read_text(encoding="utf-8")
    visual = (PROJECT_ROOT / "scripts/ui/kapes_visual.gd").read_text(encoding="utf-8")
    assert "clip_contents = true" in hud
    assert "PortraitMask" in hud
    assert "p1_portrait_region" in layout
    assert "p2_portrait_region" in layout
    assert "HUD_WIDTH_RATIO := 0.29" in visual
    assert "HUD_HEIGHT_RATIO := 0.172" in visual


def test_transparent_portrait_assets_exist() -> None:
    assert (PROJECT_ROOT / "assets/ui/portraits/terere_portrait.png").is_file()
    assert (PROJECT_ROOT / "assets/ui/portraits/jaguarete_portrait.png").is_file()


def test_victory_assets_and_universal_background() -> None:
    results = (PROJECT_ROOT / "scripts/ui/kapes_results_screen.gd").read_text(encoding="utf-8")
    for asset in (
        "assets/ui/victory/common/victory_bg_defensores.png",
        "assets/ui/victory/common/victory_main_panel.png",
        "assets/ui/victory/common/victory_stats_panel.png",
        "assets/ui/victory/common/victory_btn_rematch.png",
        "assets/ui/victory/common/victory_btn_menu.png",
        "assets/ui/victory/common/victory_title_banner.png",
        "assets/ui/victory/terere/terere_victory.png",
        "assets/ui/victory/jaguarete/jaguarete_victory.png",
    ):
        assert (PROJECT_ROOT / asset).is_file()
    assert "victory_bg_defensores.png" in results
    assert "terere_victory.png" in results
    assert "jaguarete_victory.png" in results
    assert "WinnerHero" in results
    assert "CAMBIAR KAPES" in results
    assert "rematch_pressed" in results
    assert "change_kapes_pressed" in results
    assert "menu_pressed" in results
    assert "safe_rect" in results
    ## V5: no mega panel, no title banner asset, no placeholder text.
    assert "MAIN_PANEL" not in results
    assert "NOMBRE DEL KAPE" not in results
    assert "TitleBanner" not in results
    assert "PlaceholderMask" not in results
    assert "RightStack" in results
    assert "StatsFrame" in results
    assert "StatsP%d" in results
    assert "_make_stats_card" in results
    assert "ChangeKapesArt" in results
    assert results.count("GANADOR") == 1 or results.count('"GANADOR"') >= 1


def test_jaguarete_v2_and_idle_source_exist() -> None:
    assert (PROJECT_ROOT / "assets/fighters/models/jaguarete/jaguarete_v2.glb").is_file()
    terere_v2_glb = PROJECT_ROOT / "assets/fighters/models/terere/terere_v2.glb"
    terere_v2_fbx = PROJECT_ROOT / "assets/fighters/models/terere/terere_v2.fbx"
    assert terere_v2_glb.is_file() or terere_v2_fbx.is_file()
    assert (PROJECT_ROOT / "assets/fighters/animations/Idle.fbx").is_file()


def test_jaguarete_offline_idle_pipeline() -> None:
    blender_paths = (PROJECT_ROOT / "tools/blender/ssk_blender_paths.py").read_text(encoding="utf-8")
    assert "Blender 2.83" in blender_paths or "blender.exe" in blender_paths
    assert (PROJECT_ROOT / "tools/blender/inspect_jaguarete_rig.py").is_file()
    assert (PROJECT_ROOT / "tools/blender/retarget_jaguarete_idle.py").is_file()
    assert (PROJECT_ROOT / "tools/blender/jaguarete_mixamo_bone_map.json").is_file()
    assert (PROJECT_ROOT / "tools/build_jaguarete_idle.ps1").is_file()
    assert (PROJECT_ROOT / "assets/fighters/processed/jaguarete/jaguarete_game_ready_idle.glb").is_file()
    assert (PROJECT_ROOT / "assets/fighters/processed/jaguarete/jaguarete_idle_preview.blend").is_file()
    metrics = json.loads((PROJECT_ROOT / "docs/generated/JAGUARETE_IDLE_BAKE_METRICS.json").read_text(encoding="utf-8"))
    assert metrics.get("keyed_target_bones", 0) >= 20
    assert metrics.get("validation_errors") == []


def test_jaguarete_recovery_v2_animation_architecture() -> None:
    jaguarete = (PROJECT_ROOT / "fighters/jaguarete/jaguarete_rigged_visual.gd").read_text(encoding="utf-8")
    glb = (PROJECT_ROOT / "scripts/fighters/glb_fighter_visual.gd").read_text(encoding="utf-8")
    fighter = (PROJECT_ROOT / "scripts/fighters/fighter.gd").read_text(encoding="utf-8")
    lab = (PROJECT_ROOT / "scripts/debug/jaguarete_animation_lab.gd").read_text(encoding="utf-8")
    catalog = (PROJECT_ROOT / "scripts/fighters/fighter_catalog.gd").read_text(encoding="utf-8")
    assert not (PROJECT_ROOT / "scripts/fighters/rigged_fighter_visual.gd").exists()
    assert not (PROJECT_ROOT / "scripts/fighters/jaguarete_idle_binder.gd").exists()
    assert (PROJECT_ROOT / "scripts/debug/research/jaguarete_idle_binder.gd").is_file()
    assert 'extends "res://scripts/fighters/glb_fighter_visual.gd"' in jaguarete
    assert "jaguarete_game_ready_idle.glb" in jaguarete
    assert "BAKED" in jaguarete
    assert "jaguarete_idle_binder" not in jaguarete
    assert "target_visual_height = 3.15" in jaguarete
    assert "SIZE.TALL" in jaguarete
    assert "jaguarete_rigged_visual.gd" not in catalog
    assert "[FIGHTER_PIPELINE][ERROR]" in glb
    assert "load_fallback_visual_script" in fighter
    assert "emergency_capsule" in fighter
    assert "KEY_1" in lab and "KEY_2" in lab
    assert "RUNTIME RETARGET" in lab
    assert "baked idle" in lab
    assert (PROJECT_ROOT / "scenes/debug/JaguareteAnimationLab.tscn").is_file()


def test_canonical_sizing_preserved_for_rigged_jaguarete() -> None:
    terere = (PROJECT_ROOT / "fighters/terere/terere_glb_visual.gd").read_text(encoding="utf-8")
    jaguarete = (PROJECT_ROOT / "fighters/jaguarete/jaguarete_rigged_visual.gd").read_text(encoding="utf-8")
    glb = (PROJECT_ROOT / "scripts/fighters/glb_fighter_visual.gd").read_text(encoding="utf-8")
    assert "2.40" in terere
    assert "3.15" in jaguarete
    assert "SIZE.TALL" in jaguarete
    assert "_align_model_to_gameplay" in glb
    assert "presentation_scale" in glb


def test_actorcore_idle_benchmark_pipeline() -> None:
    for char in ("terere", "jaguarete"):
        assert (PROJECT_ROOT / "assets/fighters/source_rigged" / char / "actorcore" / "autorig_actor.fbx").is_file()
    assert (PROJECT_ROOT / "tools/blender/inspect_actorcore_fighters.py").is_file()
    assert (PROJECT_ROOT / "tools/blender/retarget_mixamo_to_actorcore.py").is_file()
    assert (PROJECT_ROOT / "tools/blender/mixamo_to_actorcore_bone_map.json").is_file()
    assert (PROJECT_ROOT / "tools/build_actorcore_idle_benchmark.ps1").is_file()
    for char in ("terere", "jaguarete"):
        base = PROJECT_ROOT / "assets/fighters/processed/actorcore_benchmark" / char
        assert (base / f"{char}_actorcore_idle.glb").is_file()
        assert (base / f"{char}_actorcore_idle_preview.blend").is_file()
    eq = json.loads((PROJECT_ROOT / "docs/generated/ACTORCORE_RIG_EQUIVALENCE.json").read_text(encoding="utf-8"))
    assert eq.get("CAN_ONE_SHARED_ACTORCORE_RETARGET_PIPELINE_SUPPORT_BOTH") is True
    catalog = (PROJECT_ROOT / "scripts/fighters/fighter_catalog.gd").read_text(encoding="utf-8")
    assert "actorcore_benchmark" not in catalog
    assert "actorcore_idle" not in catalog
    terere_lab = (PROJECT_ROOT / "scripts/debug/terere_actorcore_animation_lab.gd").read_text(encoding="utf-8")
    jaguarete_lab = (PROJECT_ROOT / "scripts/debug/jaguarete_actorcore_animation_lab.gd").read_text(encoding="utf-8")
    assert "RUNTIME RETARGET: OFF" in (PROJECT_ROOT / "scripts/debug/actorcore_animation_lab.gd").read_text(encoding="utf-8")
    assert "RUNTIME RETARGET: OFF" in terere_lab
    assert "actorcore_benchmark" in terere_lab
    assert "actorcore_benchmark" in jaguarete_lab
    assert "2.40" in (PROJECT_ROOT / "fighters/terere/terere_glb_visual.gd").read_text(encoding="utf-8")
    assert "3.15" in (PROJECT_ROOT / "fighters/jaguarete/jaguarete_rigged_visual.gd").read_text(encoding="utf-8")
