"""Launch Blender 2.83 to build kit_v8_15m GLBs."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from tools.find_blender import blender_version, find_blender  # noqa: E402
from tools.blender.track.widen_kit_metadata import main as widen  # noqa: E402

BUILD = ROOT / "tools" / "blender" / "track" / "build_kit_v8_15m.py"


def main() -> int:
    exe = find_blender()
    if exe is None:
        print("BLENDER_REQUIRED")
        return 2
    print("BLENDER_EXECUTABLE", exe)
    print("BLENDER_VERSION", blender_version(exe))
    widen()
    cmd = [str(exe), "--background", "--python", str(BUILD)]
    print("RUN", " ".join(cmd))
    return subprocess.call(cmd)


if __name__ == "__main__":
    raise SystemExit(main())
