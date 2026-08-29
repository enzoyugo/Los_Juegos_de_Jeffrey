"""Jeffrey UI System V1 static and Copa continuity tests."""

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (PROJECT_ROOT / rel).read_text(encoding="utf-8")


def test_ui_system_core_files_exist() -> None:
    assert (PROJECT_ROOT / "scripts/ui/jeffrey/system/jeffrey_theme.gd").exists()
    assert (PROJECT_ROOT / "scripts/ui/jeffrey/system/jeffrey_ui_motion.gd").exists()
    assert (PROJECT_ROOT / "scripts/ui/jeffrey/system/jeffrey_shell_transition.gd").exists()
    assert (PROJECT_ROOT / "scripts/ui/jeffrey/components/jeffrey_button.gd").exists()
    assert (PROJECT_ROOT / "scripts/ui/jeffrey/components/jeffrey_modal.gd").exists()
    assert (PROJECT_ROOT / "scenes/debug/JeffreyUISystemV1Lab.tscn").exists()


def test_no_third_party_addons_installed() -> None:
    addons = PROJECT_ROOT / "addons"
    forbidden = [
        "easytransition",
        "simple-gui-transitions",
        "settings_menus",
        "maaacks_menus_template",
        "GDUIComponentLibrary",
    ]
    if addons.exists():
        names = {p.name.lower() for p in addons.iterdir()}
        for name in forbidden:
            assert name not in names


def test_copa_canonical_apis_untouched() -> None:
    core = _read("scripts/core/jeffrey/jeffrey_core.gd")
    session = _read("scripts/core/jeffrey/copa_jeffrey_session.gd")
    assert "record_match_result" in core
    assert "recorded_match_ids" in session
    assert "start_new_copa" in core
    assert "copa = " in core


def test_copa_ui_still_consumes_jeffrey_core() -> None:
    hub = _read("scripts/ui/jeffrey/copa_jeffrey_hub_panel.gd")
    board = _read("scripts/ui/jeffrey/copa_jeffrey_scoreboard_screen.gd")
    assert "JeffreyCore.copa" in hub
    assert "JeffreyCore.copa" in board
    assert "record_match_result" not in hub
    assert "record_match_result" not in board


def test_nueva_copa_requires_confirmation() -> None:
    confirm = _read("scripts/ui/jeffrey/copa_jeffrey_confirm_dialog.gd")
    modal = _read("scripts/ui/jeffrey/components/jeffrey_modal.gd")
    assert "jeffrey_modal.gd" in confirm
    assert "focus_secondary" in modal or "focus_secondary: bool = true" in modal
    assert "destructive" in modal
    assert "CANCELAR" in confirm


def test_options_binds_jeffrey_core_settings() -> None:
    options = _read("scripts/ui/jeffrey/options_screen.gd")
    assert "JeffreyCore.settings" in options
    assert "JeffreyCore.save()" in options
    assert "shell_frame.gd" not in options


def test_shell_uses_jeffrey_transition() -> None:
    app = _read("scripts/core/jeffrey/jeffrey_app.gd")
    assert "jeffrey_shell_transition.gd" in app
    assert "ShellTransition.present" in app


def test_copa_regression_tests_still_present() -> None:
    assert (PROJECT_ROOT / "tests/test_copa_jeffrey_v1.py").exists()
    assert (PROJECT_ROOT / "scenes/debug/CopaJeffreyLab.tscn").exists()
