"""Phase 17: benchmark asset metrics from inspection + bake outputs."""
import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import file_size, write_json
from actorcore_paths import ASSET_METRICS_JSON, CHARACTERS, INVENTORY_JSON


def _load_json(path):
    if not os.path.isfile(path):
        return {}
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def build_metrics() -> dict:
    inventory = _load_json(INVENTORY_JSON)
    report = {"characters": {}}
    for key, cfg in CHARACTERS.items():
        rig = _load_json(cfg["rig_json"])
        motion = _load_json(cfg["motion_audit"])
        roundtrip = _load_json(cfg["roundtrip_audit"])
        meshes = rig.get("meshes", [])
        poly_count = sum(m.get("polygons", 0) for m in meshes)
        vert_count = sum(m.get("vertices", 0) for m in meshes)
        tex = inventory.get("characters", {}).get(key, {}).get("textures", [])
        report["characters"][key] = {
            "polygon_count": poly_count,
            "vertex_count": vert_count,
            "bones": rig.get("bone_count", 0),
            "material_count": len(rig.get("materials", [])),
            "texture_count": len(tex),
            "texture_dimensions": [t.get("resolution") for t in tex if t.get("resolution")],
            "source_fbx_size_bytes": file_size(cfg["fbx"]),
            "exported_glb_size_bytes": file_size(cfg["output_glb"]),
            "preview_blend_size_bytes": file_size(cfg["preview_blend"]),
            "motion_accepted": motion.get("motion_audit", {}).get("accepted", False),
            "roundtrip_accepted": roundtrip.get("roundtrip_accepted", False),
        }
    return report


def main() -> None:
    write_json(ASSET_METRICS_JSON, build_metrics())
    print("Wrote %s" % ASSET_METRICS_JSON)


if __name__ == "__main__":
    main()
