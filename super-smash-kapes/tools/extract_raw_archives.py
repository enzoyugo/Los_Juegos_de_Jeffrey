"""Deterministic ZIP extract into assets/raw_models/_extracted/<asset_id>/."""

from __future__ import annotations

import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "assets" / "raw_models"
DEST = RAW / "_extracted"


def asset_id(path: Path) -> str:
    return path.stem.lower().replace(" ", "_")


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    ignore = DEST / ".gdignore"
    if not ignore.exists():
        ignore.write_text("*\n", encoding="utf-8")
    for path in sorted(RAW.glob("*.zip")):
        aid = asset_id(path)
        target = DEST / aid
        target.mkdir(parents=True, exist_ok=True)
        marker = target / "_EXTRACTED_FROM.txt"
        if marker.exists() and any(target.iterdir()):
            print("skip existing", aid)
            continue
        print("extract", path.name, "->", target)
        with zipfile.ZipFile(path, "r") as zf:
            zf.extractall(target)
        marker.write_text(f"source={path.name}\n", encoding="utf-8")
    print("done")


if __name__ == "__main__":
    main()
