"""Jeffrey shell parse/load regression gate (V1.1 runtime recovery)."""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get("GODOT", r"E:\Godot_v4.7.2-stable_win64_console.exe"))

PARSE_FAIL_RE = re.compile(
    r"Parse Error|Could not resolve script|Failed to load script|Could not find base class",
    re.I,
)
PASS_MARKERS = {
    "shell_parse": "[JEFFREY_SHELL_PARSE] PASS",
    "boot": "[JEFFREY_MEM] boot",
}


def _run_godot(scene: str, *, headless: bool = True, quit_after: int = 120) -> subprocess.CompletedProcess[str]:
    cmd = [
        str(GODOT),
        "--path",
        str(PROJECT_ROOT),
        "--rendering-method",
        "forward_plus",
        "--audio-driver",
        "Dummy",
        "--quit-after",
        str(quit_after),
        scene,
    ]
    if headless:
        cmd[1:1] = ["--headless", "--display-driver", "headless"]
    return subprocess.run(
        cmd,
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=180,
    )


def _combined_output(proc: subprocess.CompletedProcess[str]) -> str:
    return (proc.stdout or "") + "\n" + (proc.stderr or "")


def test_shell_parse_gate_scene_exists() -> None:
    assert (PROJECT_ROOT / "scenes/debug/ValidateJeffreyShellParse.tscn").exists()
    assert (PROJECT_ROOT / "scripts/debug/validate_jeffrey_shell_parse.gd").exists()
    script = (PROJECT_ROOT / "scripts/debug/validate_jeffrey_shell_parse.gd").read_text(encoding="utf-8")
    assert "jeffrey_app.gd" in script
    assert "copa_jeffrey_confirm_dialog.gd" in script


def test_godot_shell_parse_gate_passes() -> None:
    assert GODOT.exists(), f"Godot executable missing: {GODOT}"
    proc = _run_godot("res://scenes/debug/ValidateJeffreyShellParse.tscn")
    out = _combined_output(proc)
    assert proc.returncode == 0, out
    assert PASS_MARKERS["shell_parse"] in out, out
    assert not PARSE_FAIL_RE.search(out), out


def test_godot_jeffrey_boot_parses_and_runs() -> None:
    assert GODOT.exists(), f"Godot executable missing: {GODOT}"
    proc = _run_godot("res://scenes/core/JeffreyBoot.tscn", quit_after=240)
    out = _combined_output(proc)
    assert proc.returncode == 0, out
    assert PASS_MARKERS["boot"] in out, out
    assert not PARSE_FAIL_RE.search(out), out
