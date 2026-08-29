"""V9 content orchestrator. Copies finish runoff, then Blender process/SDS/urban/characters."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.find_blender import blender_version, find_blender  # noqa: E402

KIT = ROOT / "assets" / "track" / "processed" / "kit_v8_15m"


def copy_runoff() -> None:
    src_json = KIT / "track_straight_long_v1.json"
    src_glb = KIT / "track_straight_long_v1.glb"
    dst_json = KIT / "track_finish_runoff_v1.json"
    dst_glb = KIT / "track_finish_runoff_v1.glb"
    doc = json.loads(src_json.read_text(encoding="utf-8"))
    doc["piece_id"] = "finish_runoff"
    doc["type"] = "runoff"
    doc["tags"] = ["runoff", "finish"]
    doc["glb"] = "track_finish_runoff_v1.glb"
    dst_json.write_text(json.dumps(doc, indent=2), encoding="utf-8")
    shutil.copy2(src_glb, dst_glb)
    print("FINISH_RUNOFF", dst_glb)


def patch_overlap() -> None:
    extra = 0.18
    n = 0
    for path in sorted(KIT.glob("track_*.json")):
        doc = json.loads(path.read_text(encoding="utf-8"))
        if float(doc.get("v9_overlap", 0.0)) >= extra - 0.001:
            continue
        changed = False
        for box in doc.get("collision") or []:
            if str(box.get("kind")) != "road":
                continue
            size = list(box.get("size") or [16.8, 0.2, 2.0])
            while len(size) < 3:
                size.append(1.0)
            size[2] = float(size[2]) + extra
            size[1] = max(float(size[1]), 0.24)
            box["size"] = size
            changed = True
        if changed:
            doc["v9_overlap"] = extra
            path.write_text(json.dumps(doc, indent=2), encoding="utf-8")
            n += 1
    print("PATCH_OVERLAP", n)


def write_inventory() -> None:
    raw = ROOT / "assets" / "raw_models"
    out_dir = ROOT / "docs" / "generated" / "asset_usage_v9"
    out_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    mapping = [
        ("vaz_2104_-_raw_scan.glb", "USE_BOTH", "scan wagon; process parked derivative"),
        ("toyota-hilux-revo-prerunner-2021.zip", "USE_BOTH", "Paraguayan-appropriate pickup"),
        ("wrecked-car.zip", "USE_SHOPPING", "one atmospheric wreck only"),
        ("psx_industrial_pack.glb", "USE_BOTH", "industrial clutter already processed"),
        ("cement_bags_low-poly.glb", "USE_BOTH", "service-area prop"),
        ("market-al-danube.zip", "USE_BOTH", "inspect children; extract generic urban parts"),
        ("ice_scream_3_shopping_center_map.glb", "REJECT", "unrelated branded shopping map"),
        ("portal-gate-sci-fi.zip", "REJECT", "sci-fi, not SDS/Track"),
    ]
    for name, cls, why in mapping:
        p = raw / name
        rows.append(
            {
                "raw_source_path": str(p).replace("\\", "/"),
                "raw_file": name,
                "source_format": p.suffix,
                "source_size": p.stat().st_size if p.exists() else 0,
                "classification": cls,
                "why": why,
            }
        )
    (out_dir / "shopping_asset_usage_manifest.json").write_text(json.dumps({"assets": rows}, indent=2), encoding="utf-8")
    (out_dir / "track_asset_usage_manifest.json").write_text(json.dumps({"assets": rows}, indent=2), encoding="utf-8")
    print("INVENTORY", out_dir)


def main() -> int:
    exe = find_blender()
    if exe is None:
        print("BLENDER_REQUIRED")
        return 2
    print("BLENDER_EXECUTABLE", exe)
    print("BLENDER_VERSION", blender_version(exe))
    scripts = [
        ROOT / "tools" / "blender" / "track" / "process_raw_library_v9.py",
        ROOT / "tools" / "blender" / "track" / "build_urban_kit_v2.py",
        ROOT / "tools" / "blender" / "zombies" / "build_sds_environment_v2.py",
        ROOT / "tools" / "blender" / "zombies" / "build_zombie_pistol_foundation_v1.py",
    ]
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    if not only:
        copy_runoff()
        patch_overlap()
        write_inventory()
    elif only == "kit":
        copy_runoff()
        patch_overlap()
        return 0
    names = {"raw": 0, "urban": 1, "sds": 2, "chars": 3}
    if only in names:
        scripts = [scripts[names[only]]]
    for script in scripts:
        cmd = [str(exe), "--background", "--python", str(script)]
        print("RUN", " ".join(cmd))
        code = subprocess.call(cmd, cwd=str(ROOT))
        if code != 0:
            print("FAIL", script, code)
            if only:
                return code
            print("CONTINUE")
    print("V9_CONTENT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
