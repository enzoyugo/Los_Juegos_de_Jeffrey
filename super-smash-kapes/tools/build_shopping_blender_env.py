"""Build Shopping del Sol visual GLB via Blender. Exits BLENDER_REQUIRED if missing."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from find_blender import find_blender  # noqa: E402

BLEND_DIR = ROOT / "assets" / "environments" / "shopping_del_sol" / "blender"
EXPORT = BLEND_DIR / "exports" / "shopping_del_sol_zombies_environment_v1.glb"
SCRIPT = ROOT / "tools" / "blender" / "zombies" / "build_sds_environment_v1.py"


def main() -> int:
    blender = find_blender()
    if blender is None:
        print("BLENDER_REQUIRED")
        print("Install Blender 4.x and re-run tools/build_shopping_blender_env.py")
        print("Output would be:", EXPORT)
        return 2
    SCRIPT.parent.mkdir(parents=True, exist_ok=True)
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    if not SCRIPT.exists():
        print("missing assemble script", SCRIPT)
        return 3
    cmd = [str(blender), "--background", "--python", str(SCRIPT)]
    print("RUN", " ".join(cmd))
    proc = subprocess.run(cmd, cwd=str(ROOT))
    return proc.returncode


if __name__ == "__main__":
    raise SystemExit(main())
