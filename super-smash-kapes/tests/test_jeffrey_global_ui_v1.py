"""Global UI V1: asset mapping, SOCO→Smash, boot flow, portraits."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
GLOBAL_UI = PROJECT_ROOT / "assets" / "ui" / "global"

EXPECTED_ASSETS = [
    "boot/boot_background.png",
    "boot/los_juegos_de_jeffrey_logo.png",
    "boot/boot_press_enter.png",
    "boot/boot_controls_strip.png",
    "boot/boot_ambience_overlay.png",
    "players_today/players_today_background.png",
    "players_today/players_today_title.png",
    "players_today/player_card_selected.png",
    "players_today/player_card_unselected.png",
    "players_today/new_player_card.png",
    "players_today/selected_players_panel.png",
    "players_today/continue_button.png",
    "players_today/back_button.png",
    "players_today/players_today_controls_strip.png",
    "hub/hub_background.png",
    "hub/los_juegos_de_jeffrey_logo.png",
    "hub/mode_soco.png",
    "hub/mode_track.png",
    "hub/mode_zombies.png",
    "hub/edit_players_button.png",
    "hub/active_players_panel.png",
    "hub/hub_controls_strip.png",
]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_global_ui_core_assets_exist() -> None:
    missing = [rel for rel in EXPECTED_ASSETS if not (GLOBAL_UI / rel).exists()]
    assert missing == [], f"GLOBAL_UI_ASSET_MISSING {missing}"


def test_global_ui_assets_are_not_a_single_screenshot() -> None:
    assets = _read("scripts/ui/jeffrey/global_ui_assets.gd")
    boot = _read("scripts/ui/jeffrey/boot_screen.gd")
    players = _read("scripts/ui/jeffrey/players_today_screen.gd")
    hub = _read("scripts/ui/jeffrey/hub_screen.gd")
    for source in (assets, boot, players, hub):
        assert "boot_background.png" in source or "BOOT_BACKGROUND" in source or "Assets.BOOT" in source or "hub_mode_order" in source or "PLAYER_CARD" in source
    assert "BOOT_BACKGROUND" in boot
    assert "BOOT_LOGO" in boot
    assert "BOOT_PRESS_ENTER" in boot
    assert "PLAYERS_TITLE" in players
    assert "global_player_card.gd" in players
    assert "SelectedPanel" in players or "SELECTED_PLAYERS_PANEL" in players or "selected_players_panel.gd" in players
    assert "JeffreyPlayerChip" in players or "SELECTED_PLAYERS_PANEL" in players
    assert "MODE_ART" in hub or "hub_mode_order" in hub
    assert "ACTIVE_PLAYERS_PANEL" in hub


def test_soco_maps_to_smash_not_a_new_mode() -> None:
    assets = _read("scripts/ui/jeffrey/global_ui_assets.gd")
    hub = _read("scripts/ui/jeffrey/hub_screen.gd")
    registry = _read("scripts/core/jeffrey/game_mode_registry.gd")
    assert '"smash": MODE_SOCO' in assets
    assert '"racing": MODE_TRACK' in assets
    assert '"zombies": MODE_ZOMBIES' in assets
    assert 'MODE_SMASH := "smash"' in registry
    assert "hub_mode_order" in assets
    assert "smash" in hub
    assert "racing" in hub
    assert "zombies" in hub
    assert 'mode_chosen.emit(mode_id)' in hub


def test_boot_flow_and_auto_start_hooks() -> None:
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    assert "boot_screen.gd" in app
    assert "players_today_screen.gd" in app
    assert "hub_screen.gd" in app
    assert "_show_boot()" in app
    assert "SSK_AUTO_START_BATTLE" in app
    assert "_host_smash()" in app
    assert "smash_session_exited.connect" in app
    assert "_finish_mode_to_hub" in app
    assert "screen.back_pressed.connect(_show_mode_players)" in app


def test_profile_portrait_path_is_optional() -> None:
    profile = _read("scripts/core/jeffrey/player_profile.gd")
    assert "portrait_path" in profile
    assert 'data.get("portrait_path", "")' in profile


def test_players_today_is_logon_and_edit_has_own_screen() -> None:
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    players = _read("scripts/ui/jeffrey/players_today_screen.gd")
    edit = _read("scripts/ui/jeffrey/edit_players_screen.gd")
    assert "CONTEXT_EDIT" in players
    assert "edit_players_screen.gd" in app
    assert "_show_edit_players" in app
    assert "CreatePlayerModal" in players or "create_player_modal.gd" in players
    assert "create_player_modal.gd" in edit
    assert "NEW_PLAYER_CARD" in players
    assert "EditPlayerCard" in edit or "edit_player_card.gd" in edit


def test_ui_textures_load_lossless_without_mips() -> None:
    assets = _read("scripts/ui/jeffrey/global_ui_assets.gd")
    assert "ImageTexture.create_from_image" in assets
    assert "image.load(path)" in assets
    frame = _read("scripts/ui/jeffrey/global_screen_frame.gd")
    assert "TEXTURE_FILTER_LINEAR" in frame
