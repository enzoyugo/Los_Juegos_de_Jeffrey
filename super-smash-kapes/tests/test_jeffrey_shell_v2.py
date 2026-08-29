"""Shell V2 static locks: theme split, mode status, duplicate names, navigation."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_global_shell_does_not_bind_smash_title_art() -> None:
    chrome = _read("scripts/ui/jeffrey/jeffrey_shell_chrome.gd")
    background = _read("scripts/ui/jeffrey/shell_background.gd")
    assets = _read("scripts/ui/jeffrey/shell_assets.gd")
    smash_theme = _read("scripts/ui/jeffrey/smash_shell_theme.gd")
    assert "main_menu_bg.png" not in chrome
    assert "main_menu_bg.png" not in background
    assert "assets/ui/global/" in assets
    assert "main_menu_bg.png" in smash_theme
    assert (PROJECT_ROOT / "assets/ui/menu/main_menu_bg.png").exists()


def test_mode_availability_drives_badges() -> None:
    definition = _read("scripts/core/jeffrey/game_mode_definition.gd")
    registry = _read("scripts/core/jeffrey/game_mode_registry.gd")
    select = _read("scripts/ui/jeffrey/hub_screen.gd")
    assert "AVAIL_PLAYABLE" in definition
    assert "AVAIL_DEVELOPMENT" in definition
    assert "AVAIL_LOCKED" in definition
    assert "func status_label" in definition
    assert "AVAIL_PLAYABLE" in registry
    assert "AVAIL_DEVELOPMENT" in registry
    assert "AVAIL_LOCKED" in registry
    assert "PRÓXIMAMENTE" not in select
    assert "el resto llega después" not in select
    assert "status_label" in select
    assert 'mode_chosen.emit(mode_id)' in select


def test_duplicate_names_and_session_api() -> None:
    store = _read("scripts/core/jeffrey/player_profile_store.gd")
    session = _read("scripts/core/jeffrey/active_session.gd")
    assert "normalize_display_name" in store
    assert 'last_error = "duplicate"' in store
    assert "remove_player" in session
    assert "add_player" in session


def test_mode_player_selection_is_shared_and_validates() -> None:
    screen = _read("scripts/ui/jeffrey/mode_player_select_screen.gd")
    assert "global_player_card.gd" in screen or "PlayerCard" in screen
    assert "set_art_enabled" in screen
    assert "Necesitás al menos" in screen
    assert "Teclado" in screen
    assert "P1 teclado" not in screen
    assert "GameModeRegistry" in screen or "ModeRegistry" in screen
    assert "active_player_ids" in screen


def test_back_from_placeholder_is_one_step() -> None:
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    assert "screen.back_pressed.connect(_show_mode_players)" in app
    assert "smash_character_select_cancelled.connect(_show_mode_players)" in app
    assert "smash_session_exited.connect" in app
    assert "_finish_mode_to_hub" in app


def test_pause_host_fix_does_not_require_screen_root() -> None:
    main = _read("scripts/core/main.gd")
    assert "if active_match == null:" in main
    assert "if screen_root == null:\n\t\treturn" not in main.replace("    ", "\t")
