"""D3D12 smoke for TrackModularKitPilotLab. Does not retune physics."""

from __future__ import annotations

import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get("GODOT", r"E:\Godot_v4.7.2-stable_win64_console.exe"))
FATAL_RE = re.compile(
    r"CreateResource failed|0x8007000e|uninitialized RID|Texture binding is not valid|"
    r"uniform_set is null|Could not preload resource file|Parser Error",
    re.I,
)


def run_smoke(controller: str, frames: int, windowed: bool, scene: str, env_smoke: str, env_frames: str, marker: str, log_name: str) -> dict:
    env = os.environ.copy()
    env[env_smoke] = "1"
    env[env_frames] = str(frames)
    env["SSK_TRACK_CONTROLLER"] = controller
    cmd = [str(GODOT), "--path", str(ROOT), "--verbose", "--audio-driver", "Dummy"]
    if not windowed:
        cmd.extend(["--headless", "--display-driver", "headless"])
    cmd.extend(
        [
            "--rendering-driver",
            "d3d12",
            "--rendering-method",
            "forward_plus",
            "--quit-after",
            str(max(frames + 80, 120)),
            scene,
        ]
    )
    log_dir = ROOT / "docs" / "generated"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / log_name
    print("RUN", " ".join(cmd))
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
    first = ""
    create = False
    for line in text.splitlines():
        if FATAL_RE.search(line) and not first:
            first = line.strip()
        if "CreateResource" in line or "0x8007000e" in line:
            create = True
    ok = (
        proc.returncode == 0
        and not create
        and not first
        and marker in text
    )
    return {
        "controller": controller,
        "scene": scene,
        "ok": ok,
        "exit": proc.returncode,
        "create_resource": create,
        "first_error": first,
        "log": str(log_path.relative_to(ROOT)).replace("\\", "/"),
    }


def main() -> int:
    if not GODOT.exists():
        print("GODOT missing:", GODOT)
        return 2
    windowed = "--headless" not in sys.argv
    frames = 180
    specs = [
        ("BASELINE", "res://scenes/debug/TrackModularKitPilotLab.tscn", "SSK_PILOT_SMOKE", "SSK_PILOT_FRAMES", "[TRACK_PILOT] SMOKE END", "PILOT_SMOKE_BASELINE.log"),
        ("4WHEEL", "res://scenes/debug/TrackModularKitPilotLab.tscn", "SSK_PILOT_SMOKE", "SSK_PILOT_FRAMES", "[TRACK_PILOT] SMOKE END", "PILOT_SMOKE_4WHEEL.log"),
        ("BASELINE", "res://scenes/debug/Track4WheelExtendedPhysicsLab.tscn", "SSK_EXTENDED_SMOKE", "SSK_EXTENDED_FRAMES", "[TRACK_EXTENDED] SMOKE END", "EXTENDED_SMOKE_BASELINE.log"),
        ("4WHEEL", "res://scenes/debug/Track4WheelExtendedPhysicsLab.tscn", "SSK_EXTENDED_SMOKE", "SSK_EXTENDED_FRAMES", "[TRACK_EXTENDED] SMOKE END", "EXTENDED_SMOKE_4WHEEL.log"),
    ]
    rows = []
    for spec in specs:
        if rows:
            time.sleep(4.0)
        rows.append(run_smoke(spec[0], frames, windowed, spec[1], spec[2], spec[3], spec[4], spec[5]))
    for row in rows:
        print(
            row["scene"].split("/")[-1],
            row["controller"],
            "ok" if row["ok"] else "FAIL",
            "create=%s" % row["create_resource"],
            (row["first_error"] or "")[:160],
        )
    return 0 if all(row["ok"] for row in rows) else 1


if __name__ == "__main__":
    sys.exit(main())
