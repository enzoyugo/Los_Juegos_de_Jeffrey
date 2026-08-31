"""Raster master fidelity locks for the 1920x1080 runtime composition."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def _read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def test_track_and_zombies_use_aspect_preserving_art() -> None:
    track = _read("scripts/track/track_hud.gd")
    zombies = _read("scripts/zombies/zombies_hud.gd")
    assert track.count("STRETCH_KEEP_ASPECT_CENTERED") >= 2
    assert zombies.count("STRETCH_KEEP_ASPECT_CENTERED") >= 1
    assert "Vector2(260, 195)" in track
    assert "Vector2(480, 360)" in track
    assert "Vector2(520, 173)" in zombies


def test_copa_is_full_screen_and_layered_from_masters() -> None:
    copa = _read("scripts/ui/jeffrey/copa_jeffrey_results_screen.gd")
    assert "Vector2(1920, 1080)" in copa
    for token in (
        "RESULT_BG",
        "RESULT_TITLE",
        "RESULT_LOGO",
        "RESULT_COPA",
        "05_player_stack_template.png",
        "06_puntos_sumados_template.png",
        "07_puntos_totales_template.png",
        "_copa_button",
        "STRETCH_KEEP_ASPECT_CENTERED",
    ):
        assert token in copa
