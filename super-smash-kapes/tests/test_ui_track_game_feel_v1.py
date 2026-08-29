"""UI surgical layout + Track game-feel V1 locks."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_card_name_lives_inside_nameplate_on_art_root() -> None:
    card = _read("scripts/ui/jeffrey/global_player_card.gd")
    styles = _read("scripts/ui/jeffrey/global_ui_styles.gd")
    host = _read("scripts/ui/jeffrey/texture_fit_host.gd")
    layout = _read("scripts/ui/jeffrey/global_ui_layout.gd")
    assert "NamePlate" in card
    assert "NameLabel" in card
    assert "ArtRoot" in card
    assert "AspectRatioContainer" in card
    assert "LAYOUT_BANNER" in card
    assert "NAMEPLATE_TOP := 0.888" in styles
    assert "BANNER_NAME_LEFT" in styles
    assert "contain_centered" in layout
    assert "art_space" in host
    assert "TU NOMBRE AQUÍ" not in card


def test_selected_and_hub_rows_are_art_relative() -> None:
    panel = _read("scripts/ui/jeffrey/selected_players_panel.gd")
    hub = _read("scripts/ui/jeffrey/active_players_panel.gd")
    row = _read("scripts/ui/jeffrey/active_player_row.gd")
    assert "texture_fit_host.gd" in panel
    assert "SelectedRowsContainer" in panel
    assert "SelectedCount" in panel
    assert "display_name" in panel
    assert "texture_fit_host.gd" in hub
    assert "NameSafeZone" in row
    assert "SlotBadgeSafeZone" in row
    assert "P%d" in row
    assert "hub_row_top" in hub


def test_character_cards_are_larger_and_registry_driven() -> None:
    styles = _read("scripts/ui/jeffrey/global_ui_styles.gd")
    chars = _read("scripts/ui/jeffrey/character_select_screen.gd")
    card = _read("scripts/ui/jeffrey/character_card.gd")
    assert "CHAR_CARD_MIN := Vector2(430, 538)" in styles
    assert "CHAR_PORTRAIT_BOTTOM := 0.66" in styles
    assert "get_enabled_characters" in chars
    assert "RANDOM_CHARACTER_ID" in chars
    assert "NamePlate" in card
    assert "AspectRatioContainer" in card
    assert "TU NOMBRE AQUÍ" not in chars


def test_mode_players_use_banner_cards_from_active_session() -> None:
    mode = _read("scripts/ui/jeffrey/mode_player_select_screen.gd")
    assert "LAYOUT_BANNER" in mode
    assert "active_player_ids" in mode
    assert "GameModeRegistry" in mode or "ModeRegistry" in mode
    assert "texture_fit_host.gd" in mode


def test_track_handling_helpers_and_last_dance_contract() -> None:
    handling = _read("scripts/track/track_handling.gd")
    turns = _read("scripts/track/track_turn_manager.gd")
    last = _read("scripts/track/track_last_dance.gd")
    cam = _read("scripts/track/track_camera.gd")
    assert "damp_lateral" in handling
    assert "steer_authority" in handling
    assert "brake_or_reverse_delta" in handling
    assert "wants_drift" in handling
    assert 'last_dance[pid] = "active"' in turns or "last_dance_state = \"active\"" in turns
    assert "surrender" in turns
    assert "_overtook_someone" in turns
    assert "player_states" in turns
    assert "STATE_ACTIVE" in last
    assert "CAM_FOV_MAX" in cam
    assert "CAM_YAW_LAG" in cam
