"""Jeffrey Overnight Polish Marathon V1 gates."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get("GODOT", r"E:\Godot_v4.7.2-stable_win64.exe"))


def test_overnight_assets_exist() -> None:
    assert (ROOT / "scripts/ui/jeffrey/copa_jeffrey_podium_v1.gd").is_file()
    assert (ROOT / "scripts/ui/jeffrey/zombies_result_banner_v1.gd").is_file()
    assert (ROOT / "scenes/debug/JeffreyOvernightPolishV1Capture.tscn").is_file()
    assert "asphalt_grain_v1" in (ROOT / "scripts/track/track_visual_quality_v2.gd").read_text(encoding="utf-8")


def test_copa_podium_wired() -> None:
    text = (ROOT / "scripts/ui/jeffrey/copa_jeffrey_scoreboard_screen.gd").read_text(encoding="utf-8")
    assert "copa_jeffrey_podium_v1" in text


def test_zombies_banner_wired() -> None:
    text = (ROOT / "scripts/zombies/zombies_hud.gd").read_text(encoding="utf-8")
    assert "zombies_result_banner_v1" in text


def test_ui_audio_inventory_ready() -> None:
    text = (ROOT / "scripts/ui/jeffrey/global_ui_audio.gd").read_text(encoding="utf-8")
    assert "has_pack" in text
    assert "EXPECTED_DIR" in text
    assert "play_countdown" in text
    ui = ROOT / "assets/audio/ui"
    assert (ui / "navigate.wav").is_file()
    assert (ui / "confirm.wav").is_file()


def test_hud_spanish_hints() -> None:
    hud = (ROOT / "scripts/track/track_hud.gd").read_text(encoding="utf-8")
    assert "ACELERAR" in hud
    assert "jeffrey_input_hint" in hud
    assert "PRESUPUESTO" not in hud
