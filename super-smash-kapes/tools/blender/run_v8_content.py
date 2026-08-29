"""Run Blender 5.2 content pipeline for Track 15 m kit, urban props, SDS env."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.find_blender import blender_version, find_blender  # noqa: E402
from tools.blender.track.widen_kit_metadata import main as widen  # noqa: E402

SCRIPTS = [
    ROOT / "tools" / "blender" / "track" / "build_kit_v8_15m.py",
    ROOT / "tools" / "blender" / "track" / "build_urban_kit_v1.py",
    ROOT / "tools" / "blender" / "zombies" / "build_sds_environment_v1.py",
]


def main() -> int:
    exe = find_blender()
    if exe is None:
        print("BLENDER_REQUIRED")
        return 2
    print("BLENDER_EXECUTABLE", exe)
    print("BLENDER_VERSION", blender_version(exe))
    widen()
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    scripts = SCRIPTS
    if only == "kit":
        scripts = [SCRIPTS[0]]
    elif only == "urban":
        scripts = [SCRIPTS[1]]
    elif only == "sds":
        scripts = [SCRIPTS[2]]
    for script in scripts:
        cmd = [str(exe), "--background", "--python", str(script)]
        print("RUN", " ".join(cmd))
        code = subprocess.call(cmd, cwd=str(ROOT))
        if code != 0:
            print("FAIL", script, code)
            return code
        if script == SCRIPTS[0]:
            kit = ROOT / "assets" / "track" / "processed" / "kit_v8_15m"
            glbs = list(kit.glob("track_*.glb"))
            if len(glbs) < 18:
                print("FAIL kit glb count", len(glbs))
                return 4
    print("V8_CONTENT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
