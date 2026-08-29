"""Global UI finalization + mode transitions V1 locks."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
GLOBAL_UI = PROJECT_ROOT / "assets" / "ui" / "global"

TRANSITION_ASSETS = [
    "transitions/soco/soco_transition_background.png",
    "transitions/soco/soco_title.png",
    "transitions/soco/soco_mode_banner.png",
    "transitions/soco/soco_global_header.png",
    "transitions/soco/soco_fist_emblem.png",
    "transitions/soco/soco_progress_bar.png",
    "transitions/soco/soco_controls_strip.png",
    "transitions/soco/soco_fx_overlay.png",
    "transitions/track/track_transition_background.png",
    "transitions/track/track_title.png",
    "transitions/track/track_mode_banner.png",
    "transitions/track/track_global_header.png",
    "transitions/track/track_generation_panel.png",
    "transitions/track/track_progress_bar.png",
    "transitions/track/track_controls_strip.png",
    "transitions/track/track_tip_panel.png",
    "transitions/track/track_fx_overlay.png",
    "transitions/zombies/zombies_transition_background.png",
    "transitions/zombies/zombies_title.png",
    "transitions/zombies/zombies_mode_banner.png",
    "transitions/zombies/zombies_global_header.png",
    "transitions/zombies/zombies_loading_panel.png",
    "transitions/zombies/zombies_progress_bar.png",
    "transitions/zombies/zombies_controls_strip.png",
    "transitions/zombies/zombies_player_panel.png",
    "transitions/zombies/zombies_fx_overlay.png",
]

SCREEN_ASSETS = [
    "edit_players/edit_players_background.png",
    "edit_players/edit_players_title.png",
    "edit_players/edit_player_card.png",
    "edit_players/edit_player_card_active.png",
    "edit_players/add_player_button.png",
    "edit_players/edit_players_controls_strip.png",
    "edit_players/edit_players_info_panel.png",
    "mode_players/mode_players_background.png",
    "mode_players/mode_players_title.png",
    "mode_players/mode_player_card.png",
    "mode_players/mode_player_card_selected.png",
    "mode_players/mode_players_summary_panel.png",
    "mode_players/continue_button.png",
    "mode_players/back_button.png",
    "mode_players/mode_players_controls_strip.png",
    "character_select/character_select_background.png",
    "character_select/character_select_title.png",
    "character_select/character_card.png",
    "character_select/character_card_selected.png",
    "character_select/character_random_card.png",
    "character_select/character_players_panel.png",
    "character_select/continue_button.png",
    "character_select/back_button.png",
    "character_select/character_select_controls_strip.png",
]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_transition_and_final_screen_assets_exist() -> None:
    missing = [rel for rel in TRANSITION_ASSETS + SCREEN_ASSETS if not (GLOBAL_UI / rel).exists()]
    assert missing == [], f"GLOBAL_UI_ASSET_MISSING {missing}"


def test_players_today_selected_panel_uses_containers() -> None:
    players = _read("scripts/ui/jeffrey/players_today_screen.gd")
    panel = _read("scripts/ui/jeffrey/selected_players_panel.gd")
    card = _read("scripts/ui/jeffrey/global_player_card.gd")
    assert "selected_players_panel.gd" in players
    assert "set_profile_ids" in panel
    assert "SELECCIONADOS HOY" in panel
    assert "SelectedPlayerRow" in panel or "selected_player_row.gd" in panel
    assert "VBoxContainer" in panel
    assert "NamePlate" in card
    assert "NameLabel" in card or "name_label" in card
    assert "CheckIndicator" in card
    assert "Capucarne" not in players
    assert "Burbuja" not in players
    assert "display_name" in players


def test_hub_roster_and_status_are_componentized() -> None:
    hub = _read("scripts/ui/jeffrey/hub_screen.gd")
    rows = _read("scripts/ui/jeffrey/active_player_row.gd")
    panel = _read("scripts/ui/jeffrey/active_players_panel.gd")
    mode_card = _read("scripts/ui/jeffrey/mode_select_card.gd")
    assert "active_players_panel.gd" in hub
    assert "mode_select_card.gd" in hub
    assert "gold_action_button.gd" in hub
    assert "status_label" in hub
    assert "PlayerRowsContainer" in panel
    assert "P%d" in rows
    assert "SLOT_BADGE_WIDTH" in rows
    assert "mode_badge" in mode_card
    assert "PRÓXIMAMENTE" not in hub


def test_edit_mode_and_character_screens_are_data_driven() -> None:
    edit = _read("scripts/ui/jeffrey/edit_players_screen.gd")
    mode = _read("scripts/ui/jeffrey/mode_player_select_screen.gd")
    chars = _read("scripts/ui/jeffrey/character_select_screen.gd")
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    assert "GridContainer" in edit
    assert "delete" not in edit.lower() or "no se borran" in edit
    assert "active_player_ids" in mode
    assert "SMASH_ADAPTER_PLAYERS" in mode
    assert "preselected_ids" in mode
    assert "RANDOM_CHARACTER_ID" in chars
    assert "pick_random_enabled" in chars
    assert "profile_id" in chars
    assert "character_id" in chars
    assert "player_slot" in chars
    assert "get_enabled_characters" in chars
    assert "character_select_screen.gd" in app
    assert "edit_players_screen.gd" in app
    assert "_show_mode_transition" in app
    assert "pending_participants" in app


def test_mode_transition_mappings_and_duplicate_guard() -> None:
    definition = _read("scripts/ui/jeffrey/mode_transition_definition.gd")
    controller = _read("scripts/ui/jeffrey/mode_transition_controller.gd")
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    registry = _read("scripts/core/jeffrey/game_mode_registry.gd")
    assert "MODE_SMASH" in definition
    assert "MODE_RACING" in definition
    assert "MODE_ZOMBIES" in definition
    assert "ENTRANDO A LA BATALLA" in definition
    assert "PREPARANDO TRACK" in definition
    assert "PREPARANDO MODO" in definition
    assert "GENERANDO PISTA" not in definition
    assert "GENERANDO PISTA" not in controller
    assert "NIVEL 27" not in controller
    assert "show_mode_transition" in controller
    assert "enum State" in controller
    assert "State.IDLE" in controller
    assert "is_busy" in controller
    assert "generation_started" in controller
    assert "generation_started.emit" not in controller
    assert "set_generation_stage" in controller
    assert "set_tip" in controller
    assert "begin_hosted_match" in app
    assert "HotseatComingSoon.tscn" in registry
    assert "TrackMain.tscn" in registry
    assert "ZombiesComingSoon.tscn" in registry
    assert "ZombiesMain.tscn" in registry
    assert "M0Playground.tscn" in registry
    assert "_transition_busy" in app


def test_player_identity_is_not_slot_or_character() -> None:
    setup = _read("scripts/core/match_setup.gd")
    chars = _read("scripts/ui/jeffrey/character_select_screen.gd")
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    mode = _read("scripts/ui/jeffrey/mode_player_select_screen.gd")
    assert "Never used as fighter identity" in setup
    assert "player_1_profile_id" in setup
    assert "player_1_fighter_id" in setup
    assert '"profile_id"' in chars
    assert '"character_id"' in chars
    assert '"player_slot"' in chars
    assert "pending_match_profile_ids" in app
    assert "pending_participants" in app
    assert "apply_logon_roster" not in mode
    assert "smash_fighter_id_for" in app
