"""Copa Jeffrey V1 static locks and scoring contract tests."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_copa_core_files_exist() -> None:
    assert (PROJECT_ROOT / "scripts/core/jeffrey/copa_jeffrey_session.gd").exists()
    assert (PROJECT_ROOT / "scripts/core/jeffrey/copa_jeffrey_scoring.gd").exists()
    assert (PROJECT_ROOT / "scripts/ui/jeffrey/copa_jeffrey_hub_panel.gd").exists()
    assert (PROJECT_ROOT / "scripts/ui/jeffrey/copa_jeffrey_results_screen.gd").exists()
    assert (PROJECT_ROOT / "scripts/ui/jeffrey/copa_jeffrey_scoreboard_screen.gd").exists()
    assert (PROJECT_ROOT / "scripts/ui/jeffrey/copa_jeffrey_confirm_dialog.gd").exists()
    assert (PROJECT_ROOT / "scenes/debug/CopaJeffreyLab.tscn").exists()


def test_jeffrey_core_wires_copa_session() -> None:
    core = _read("scripts/core/jeffrey/jeffrey_core.gd")
    assert "var copa" in core
    assert "record_match_result" in core
    assert "record_smash_copa_match" in core
    assert "record_track_copa_match" in core
    assert "record_zombies_copa_match" in core
    assert "start_new_copa" in core
    assert "copa.start_new" in core
    assert "copa.sync_roster" in core


def test_scoring_rules_v1() -> None:
    scoring = _read("scripts/core/jeffrey/copa_jeffrey_scoring.gd")
    assert "PLACEMENT_POINTS" in scoring
    assert "5, 3, 2, 1" in scoring
    session = _read("scripts/core/jeffrey/copa_jeffrey_session.gd")
    assert "recorded_match_ids" in session
    assert "record_match_result" in session


def test_no_per_mode_score_managers() -> None:
    root = PROJECT_ROOT / "scripts"
    forbidden = [
        "smash_score_manager.gd",
        "track_score_manager.gd",
        "zombies_score_manager.gd",
    ]
    for name in forbidden:
        assert not (root / name).exists()
        assert not (root / "core" / "jeffrey" / name).exists()


def test_smash_records_copa_once() -> None:
    main = _read("scripts/core/main.gd")
    assert "_copa_match_id" in main
    assert "_copa_recorded" in main
    assert "record_smash_copa_match" in main
    assert "generate_copa_match_id" in main
    assert main.count("record_smash_copa_match") >= 1
    assert "_copa_recorded = true" in main


def test_track_records_copa_once() -> None:
    track = _read("scripts/track/track_main.gd")
    assert "_record_copa_if_needed" in track
    assert "record_track_copa_match" in track
    assert "session_over()" in track


def test_zombies_records_failed_run_without_fake_clear() -> None:
    zombies = _read("scripts/zombies/zombies_main.gd")
    core = _read("scripts/core/jeffrey/jeffrey_core.gd")
    assert "_record_copa_if_needed(false)" in zombies
    assert "team_cleared" in core
    assert "record_zombies_copa_match" in zombies


def test_hub_and_shell_ui_integration() -> None:
    hub = _read("scripts/ui/jeffrey/hub_screen.gd")
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    assert "CopaPanel" in hub or "copa_jeffrey_hub_panel" in hub
    assert "COPA JEFFREY" in hub or "copa_jeffrey_hub_panel.gd" in hub
    assert "_show_copa_results" in app
    assert "_show_nueva_copa_confirm" in app
    assert "_finish_mode_to_hub" in app
    assert "NUEVA COPA" in _read("scripts/ui/jeffrey/copa_jeffrey_confirm_dialog.gd")


def test_nueva_copa_does_not_touch_profiles() -> None:
    core = _read("scripts/core/jeffrey/jeffrey_core.gd")
    persistence = _read("scripts/core/jeffrey/jeffrey_persistence.gd")
    assert "start_new_copa" in core
    assert "profiles" in persistence
    assert "copa" not in persistence


def test_leaderboard_sort_contract() -> None:
    session = _read("scripts/core/jeffrey/copa_jeffrey_session.gd")
    assert "total_points" in session
    assert "wins" in session
    assert "join_order" in session


def test_existing_shell_regression_hooks_still_present() -> None:
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    assert "smash_character_select_cancelled.connect(_show_mode_players)" in app
    assert "mode_chosen.connect(_on_mode_chosen)" in app
