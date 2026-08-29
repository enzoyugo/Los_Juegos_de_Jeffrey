"""Process raw library assets into shared urban processed GLBs. Blender 5.2 CLI."""

from __future__ import annotations

import json
import os
import shutil
import sys
import traceback

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from tools.blender.common import bpy_util  # noqa: E402

RAW = os.path.join(ROOT, "assets", "raw_models")
EX = os.path.join(RAW, "_extracted")
OUT = os.path.join(ROOT, "assets", "environments", "shared", "urban", "processed")
MANIFEST = os.path.join(ROOT, "docs", "generated", "asset_usage_v9", "processing_log_v9.json")
BLEND = os.path.join(ROOT, "assets", "environments", "shared", "urban", "blender", "processed_raw_v9.blend")


def _record(rows, **kwargs):
    rows.append(kwargs)
    print("ASSET", kwargs.get("raw_file"), kwargs.get("classification"), kwargs.get("processed_glb_path", ""))


def _export_joined(objs, dest, target_len, max_tris, col):
    obj = bpy_util.join_objects(objs, os.path.splitext(os.path.basename(dest))[0])
    if obj is None:
        return None, 0
    bpy_util.link(obj, col)
    bpy_util.normalize_to_length(obj, target_len)
    bpy_util.drop_to_ground(obj)
    tris = bpy_util.triangle_count([obj])
    if tris > max_tris and tris > 0:
        ratio = max(max_tris / float(tris), 0.02)
        bpy_util.decimate(obj, ratio)
        tris = bpy_util.triangle_count([obj])
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    bpy_util.hide_all_mesh()
    obj.hide_set(False)
    obj.hide_render = False
    obj.select_set(True)
    bpy_util.export_glb(dest, selected=True)
    bpy_util.stats_report(dest, {"processed": os.path.basename(dest)})
    return dest, tris


def _process_file(rows, raw_path, dest, classification, target_len, max_tris, kind, col):
    bpy_util.reset_scene()
    col = bpy_util.collection("EXPORT_GODOT")
    ext = os.path.splitext(raw_path)[1].lower()
    try:
        if ext in (".glb", ".gltf"):
            imported = bpy_util.import_glb(raw_path)
        elif ext == ".fbx":
            imported = bpy_util.import_fbx(raw_path)
        elif ext == ".obj":
            imported = bpy_util.import_obj(raw_path)
        else:
            _record(rows, raw_source_path=raw_path, raw_file=os.path.basename(raw_path), classification="REJECT", rejection_reason="unsupported format")
            return
        dest_path, tris = _export_joined(imported, dest, target_len, max_tris, col)
        _record(
            rows,
            raw_source_path=raw_path.replace("\\", "/"),
            raw_file=os.path.basename(raw_path),
            source_format=ext,
            source_size=os.path.getsize(raw_path),
            classification=classification,
            processed_glb_path=dest_path.replace("\\", "/") if dest_path else "",
            final_triangles=tris,
            kind=kind,
        )
    except Exception as exc:
        _record(
            rows,
            raw_source_path=raw_path.replace("\\", "/"),
            raw_file=os.path.basename(raw_path),
            classification="REJECT",
            rejection_reason="%s: %s" % (type(exc).__name__, exc),
        )
        traceback.print_exc()


def main():
    rows = []
    os.makedirs(os.path.join(OUT, "vehicles"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "industrial"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "docs", "generated", "asset_usage_v9"), exist_ok=True)

    vaz = os.path.join(RAW, "vaz_2104_-_raw_scan.glb")
    if os.path.isfile(vaz):
        _process_file(rows, vaz, os.path.join(OUT, "vehicles", "vaz_parked.glb"), "USE_BOTH", 4.3, 22000, "wagon", None)

    wreck = os.path.join(EX, "wrecked-car", "source", "export_002.glb")
    if os.path.isfile(wreck):
        _process_file(rows, wreck, os.path.join(OUT, "vehicles", "wreck_parked.glb"), "USE_SHOPPING", 4.4, 28000, "wreck", None)

    hilux = os.path.join(EX, "toyota-hilux-revo-prerunner-2021", "source", "hilux_revo_21.fbx")
    if os.path.isfile(hilux):
        _process_file(rows, hilux, os.path.join(OUT, "vehicles", "hilux_parked.glb"), "USE_BOTH", 5.2, 30000, "pickup", None)
    else:
        _record(rows, raw_file="toyota-hilux-revo-prerunner-2021.zip", classification="REJECT", rejection_reason="fbx missing after extract")

    psx = os.path.join(RAW, "psx_industrial_pack.glb")
    dst_psx = os.path.join(OUT, "industrial", "psx_industrial_pack.glb")
    if os.path.isfile(psx):
        os.makedirs(os.path.dirname(dst_psx), exist_ok=True)
        shutil.copy2(psx, dst_psx)
        processed_sds = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "processed", "psx_industrial_pack.glb")
        if os.path.isfile(processed_sds):
            shutil.copy2(processed_sds, dst_psx)
        _record(rows, raw_file="psx_industrial_pack.glb", classification="USE_BOTH", processed_glb_path=dst_psx.replace("\\", "/"), kind="industrial")

    bags = os.path.join(RAW, "cement_bags_low-poly.glb")
    if os.path.isfile(bags):
        _process_file(rows, bags, os.path.join(OUT, "industrial", "cement_bags.glb"), "USE_BOTH", 1.4, 8000, "prop", None)

    ice = os.path.join(RAW, "ice_scream_3_shopping_center_map.glb")
    if os.path.isfile(ice):
        _record(rows, raw_file="ice_scream_3_shopping_center_map.glb", classification="REJECT", rejection_reason="unrelated third-party shopping map / branding")

    gate = os.path.join(RAW, "portal-gate-sci-fi.zip")
    if os.path.isfile(gate):
        _record(rows, raw_file="portal-gate-sci-fi.zip", classification="REJECT", rejection_reason="sci-fi aesthetic, not SDS/Track urban")

    market = os.path.join(EX, "market-al-danube", "source", "Market AL_DANUBE.fbx")
    if os.path.isfile(market):
        try:
            bpy_util.reset_scene()
            imported = bpy_util.import_fbx(market)
            names = sorted(o.name for o in imported)
            print("MARKET_OBJECTS", len(names))
            dump = os.path.join(ROOT, "docs", "generated", "asset_usage_v9", "market_al_danube_objects.txt")
            open(dump, "w", encoding="utf-8").write("\n".join(names) + "\n")
            keys = ("lamp", "light", "car", "tree", "palm", "bench", "bollard", "planter", "sign", "fence", "barrier")
            hits = [o for o in imported if any(k in o.name.lower() for k in keys)]
            print("MARKET_HITS", len(hits), [o.name for o in hits[:40]])
            if hits:
                dest = os.path.join(OUT, "street_props", "market_extracted_cluster.glb")
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                bpy_util.hide_all_mesh()
                for o in hits:
                    if o.type == "MESH":
                        o.hide_set(False)
                        o.select_set(True)
                bpy_util.export_glb(dest, selected=True)
                _record(rows, raw_file="Market AL_DANUBE.fbx", classification="USE_BOTH", processed_glb_path=dest.replace("\\", "/"), kind="extracted_cluster", runtime_note="child objects inspected")
            else:
                _record(rows, raw_file="Market AL_DANUBE.fbx", classification="REFERENCE_ONLY", rejection_reason="imported; no generic named lamp/car/tree children to extract")
        except Exception as exc:
            _record(rows, raw_file="Market AL_DANUBE.fbx", classification="REFERENCE_ONLY", rejection_reason="import failed: %s" % exc)
            traceback.print_exc()

    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    try:
        import bpy

        bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    except Exception:
        pass
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    open(MANIFEST, "w", encoding="utf-8").write(json.dumps(rows, indent=2))
    print("PROCESS_RAW_V9", len(rows), MANIFEST)


if __name__ == "__main__":
    main()
