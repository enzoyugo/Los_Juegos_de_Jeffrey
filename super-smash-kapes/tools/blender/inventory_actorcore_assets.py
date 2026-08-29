"""Phase 1: filesystem inventory for ActorCore source packages."""
import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from datetime import datetime, timezone

from actorcore_benchmark_lib import file_size, iso_mtime, png_dimensions, write_json
from actorcore_paths import CHARACTERS, GENERATED_DIR, INVENTORY_JSON


def _texture_entries(fbm_dir: str) -> list:
    entries = []
    if not os.path.isdir(fbm_dir):
        return entries
    for name in sorted(os.listdir(fbm_dir)):
        path = os.path.join(fbm_dir, name)
        if not os.path.isfile(path):
            continue
        entry = {
            "path": path.replace("\\", "/"),
            "name": name,
            "size_bytes": file_size(path),
            "modified_utc": iso_mtime(path),
        }
        if name.lower().endswith(".png"):
            entry["resolution"] = png_dimensions(path)
        entries.append(entry)
    return entries


def build_inventory() -> dict:
    inventory = {
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "characters": {},
    }
    for key, cfg in CHARACTERS.items():
        fbx = cfg["fbx"]
        inventory["characters"][key] = {
            "label": cfg["label"],
            "fbx_path": fbx.replace("\\", "/"),
            "json_path": cfg["json"].replace("\\", "/"),
            "fbm_dir": cfg["fbm_dir"].replace("\\", "/"),
            "fbx_size_bytes": file_size(fbx),
            "json_size_bytes": file_size(cfg["json"]),
            "fbx_modified_utc": iso_mtime(fbx),
            "json_modified_utc": iso_mtime(cfg["json"]),
            "textures": _texture_entries(cfg["fbm_dir"]),
            "fbx_content": {
                "mesh": None,
                "armature": None,
                "skin_weights": None,
                "animations": None,
                "blendshapes": None,
            },
        }
    return inventory


def main() -> None:
    os.makedirs(GENERATED_DIR, exist_ok=True)
    data = build_inventory()
    write_json(INVENTORY_JSON, data)
    print("Wrote %s" % INVENTORY_JSON)


if __name__ == "__main__":
    main()
