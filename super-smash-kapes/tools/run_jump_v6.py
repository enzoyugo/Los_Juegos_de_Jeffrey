"""Run TrackJumpTrajectoryLandingLab with V6 env. Does not retune handling."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get("GODOT", r"E:\Godot_v4.7.2-stable_win64_console.exe"))
SCENE = "res://scenes/debug/TrackJumpTrajectoryLandingLab.tscn"


def run(out_rel: str, extra: dict[str, str] | None = None, quit_after: int = 9000) -> int:
    env = os.environ.copy()
    env["SSK_TRACK_CONTROLLER"] = "4WHEEL"
    env["SSK_V6_OUT"] = "res://" + out_rel.replace("\\", "/")
    if extra:
        env.update(extra)
    cmd = [
        str(GODOT),
        "--path",
        str(ROOT),
        "--headless",
        "--display-driver",
        "headless",
        "--rendering-driver",
        "d3d12",
        "--rendering-method",
        "forward_plus",
        "--audio-driver",
        "Dummy",
        "--quit-after",
        str(quit_after),
        SCENE,
    ]
    print("RUN", " ".join(cmd))
    print("ENV", {k: env[k] for k in env if k.startswith("SSK_")})
    log_path = ROOT / out_rel / "godot.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run(
        cmd,
        cwd=str(ROOT),
        env=env,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=180,
    )
    text = (proc.stdout or "") + "\n" + (proc.stderr or "")
    log_path.write_text(text, encoding="utf-8")
    print("exit", proc.returncode, "log", log_path)
    for line in text.splitlines():
        if "TRACK_JUMP_V6" in line or "SCRIPT ERROR" in line or "Parser Error" in line or "ATLAS" in line or "atlas" in line.lower() and "4096" in line:
            print(line)
    return proc.returncode


def main() -> int:
    extra = {}
    for item in sys.argv[1:]:
        if "=" in item:
            k, v = item.split("=", 1)
            extra[k] = v
    out = extra.pop("OUT", "docs/generated/track_jump_v6/iteration_01")
    return 0 if run(out, extra) in (0, 1) else 2


if __name__ == "__main__":
    sys.exit(main())
