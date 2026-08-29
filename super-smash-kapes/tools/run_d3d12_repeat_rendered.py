"""Run a windowed D3D12 Forward+ repeat-launch of real gameplay scenes."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get("GODOT", r"E:\Godot_v4.7.2-stable_win64_console.exe"))
FATAL_RE = re.compile(
    r"0x8007000e|CreateResource failed|uninitialized RID|uniform_set is null|"
    r"CrashHandlerException|signal 11|signal 4",
    re.I,
)


def main() -> int:
    if not GODOT.exists():
        print("GODOT missing:", GODOT)
        return 2
    env = os.environ.copy()
    env["SSK_D3D12_HOLD"] = env.get("SSK_D3D12_HOLD", "5.2")
    cmd = [
        str(GODOT),
        "--path",
        str(ROOT),
        "--verbose",
        "--audio-driver",
        "Dummy",
        "--rendering-driver",
        "d3d12",
        "--rendering-method",
        "forward_plus",
        "res://scenes/debug/D3D12RepeatLaunchLab.tscn",
    ]
    log_path = ROOT / "docs" / "generated" / "D3D12_REPEAT_RENDERED_V4.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    print("RUN", " ".join(cmd))
    proc = subprocess.run(
        cmd,
        cwd=str(ROOT),
        env=env,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=420,
    )
    text = (proc.stdout or "") + "\n" + (proc.stderr or "")
    log_path.write_text(text, encoding="utf-8")
    first = ""
    for line in text.splitlines():
        if FATAL_RE.search(line):
            first = line.strip()
            break
    print("exit", proc.returncode, "first_fatal=", first[:200] if first else "none")
    print("wrote", log_path)
    if first:
        return 1
    if "[D3D12_REPEAT] PASS" not in text:
        return 1
    return 0 if proc.returncode == 0 else proc.returncode


if __name__ == "__main__":
    sys.exit(main())
