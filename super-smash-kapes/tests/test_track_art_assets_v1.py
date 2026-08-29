"""Track Art Assets V1 gates."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get("GODOT", r"E:\Godot_v4.7.2-stable_win64.exe"))


def test_art_scripts_exist() -> None:
    assert (ROOT / "scripts/track/track_env_runtime_meshes_v1.gd").is_file()
    assert (ROOT / "scripts/track/track_hud_chrome_v1.gd").is_file()
    assert (ROOT / "scenes/debug/TrackArtAssetsV1Lab.tscn").is_file()


def test_hud_chrome_wired() -> None:
    text = (ROOT / "scripts/track/track_hud.gd").read_text(encoding="utf-8")
    assert "track_hud_chrome_v1.gd" in text
    assert "set_best" in text
    assert "flash_finish" in text


def test_results_track_banner() -> None:
    text = (ROOT / "scripts/ui/jeffrey/copa_jeffrey_results_screen.gd").read_text(encoding="utf-8")
    assert "make_result_banner" in text


def test_art_lab_pass() -> None:
    if not GODOT.is_file():
        return
    log = ROOT / "outputs" / "perf" / "logs" / "track_art_assets_v1_lab.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        str(GODOT),
        "--path",
        str(ROOT),
        "--display-driver",
        "windows",
        "--rendering-method",
        "forward_plus",
        "--rendering-driver",
        "d3d12",
        "--gpu-index",
        "0",
        "--audio-driver",
        "Dummy",
        "--resolution",
        "1280x720",
        "--log-file",
        str(log),
        "--quit-after",
        "360",
        "res://scenes/debug/TrackArtAssetsV1Lab.tscn",
    ]
    subprocess.run(cmd, capture_output=True, text=True, timeout=120, check=False)
    body = log.read_text(encoding="utf-8", errors="replace") if log.is_file() else ""
    assert "[TRACK_ART_ASSETS_V1_LAB] PASS" in body, body[-2500:]
