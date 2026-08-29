"""Find Blender. Prefer newest installed Windows build."""

from __future__ import annotations

import os
import shutil
from pathlib import Path

CANDIDATES = [
    Path(r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"),
    Path(r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"),
    Path(r"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe"),
    Path(r"C:\Program Files\Blender Foundation\Blender 4.5\blender.exe"),
    Path(r"C:\Program Files\Blender Foundation\Blender 4.4\blender.exe"),
    Path(r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe"),
    Path(r"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe"),
    Path(r"C:\Program Files\Blender Foundation\Blender 4.1\blender.exe"),
    Path(r"C:\Program Files\Blender Foundation\Blender 4.0\blender.exe"),
    Path(r"C:\Program Files\Blender Foundation\Blender 3.6\blender.exe"),
    Path(r"C:\Program Files\Blender Foundation\Blender 2.83\blender.exe"),
    Path(r"C:\Program Files\Blender Foundation\Blender 2.82\blender.exe"),
]


def find_blender() -> Path | None:
    env = os.environ.get("BLENDER_EXE", "").strip()
    if env and Path(env).exists():
        return Path(env)
    which = shutil.which("blender")
    if which:
        return Path(which)
    root = Path(r"C:\Program Files\Blender Foundation")
    if root.exists():
        found: list[Path] = sorted(root.glob("Blender */blender.exe"), reverse=True)
        if found:
            return found[0]
    for p in CANDIDATES:
        if p.exists():
            return p
    return None


def blender_version(exe: Path) -> str:
    import subprocess

    try:
        out = subprocess.check_output([str(exe), "--version"], text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return "unknown"
    line = (out.splitlines() or [""])[0].strip()
    return line or "unknown"


if __name__ == "__main__":
    found = find_blender()
    if found is None:
        print("BLENDER_REQUIRED")
        raise SystemExit(2)
    ver = blender_version(found)
    print("BLENDER_EXECUTABLE", found)
    print("BLENDER_VERSION", ver)
