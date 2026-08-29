"""Track Environment Kit V1 — file + lab smoke gates."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get("GODOT", r"E:\Godot_v4.7.2-stable_win64.exe"))


def test_env_kit_scripts_exist() -> None:
    assert (ROOT / "scripts/track/track_environment_kit_v1.gd").is_file()
    assert (ROOT / "scripts/track/track_environment_placer_v1.gd").is_file()
    assert (ROOT / "scenes/debug/TrackEnvironmentKitV1Lab.tscn").is_file()
    assert (ROOT / "scenes/debug/TrackEnvironmentKitV1Capture.tscn").is_file()


def test_track_race_wires_env_kit() -> None:
    text = (ROOT / "scripts/track/track_race.gd").read_text(encoding="utf-8")
    assert "track_environment_placer_v1.gd" in text
    assert "_place_environment_kit" in text
    assert "SSK_TRACK_SCENERY" in (ROOT / "scripts/track/track_environment_placer_v1.gd").read_text(
        encoding="utf-8"
    )


def test_env_kit_lab_pass() -> None:
    if not GODOT.is_file():
        return
    log = ROOT / "outputs" / "perf" / "logs" / "track_env_kit_v1_lab.log"
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
        "240",
        "res://scenes/debug/TrackEnvironmentKitV1Lab.tscn",
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=90, check=False)
    body = log.read_text(encoding="utf-8", errors="replace") if log.is_file() else ""
    combined = body + "\n" + (proc.stdout or "") + "\n" + (proc.stderr or "")
    assert "[TRACK_ENV_KIT_V1_LAB] PASS" in combined, combined[-2000:]
