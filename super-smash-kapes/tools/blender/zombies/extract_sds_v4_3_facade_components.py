"""SDS V4.3 — inspect raw facade GLBs and export extracted components.

Does NOT modify raw files. HUMAN_REVIEW_REQUIRED.
Not a new generator; sprint-local extract for V4.3 reconstruction.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from tools.blender.common import bpy_util  # noqa: E402

RAW = r"E:\JeffreyAIResearch\asset-library\raw\environment\shopping_del_sol\facade"
EXTRACT = r"E:\JeffreyAIResearch\asset-library\processed\environment\shopping_del_sol\facade\v4_3_extracts"
PREVIEW = r"E:\JeffreyAIResearch\outputs\runtime-review\sds_v4_3\raw_inspect"
AUDIT_JSON = r"E:\JeffreyAIResearch\outputs\runtime-review\sds_v4_3\raw_inspect\audit.json"

FILES = [
    ("sds_facade_arch.glb", "arch", "arch_shell"),
    ("sds_facade_glass.glb", "glass", "glass_mass"),
    ("sds_architectural_doorway.glb", "doorway", "doorway_mass"),
    ("sds_columns.glb", "columns", "column_cluster"),
    ("sds_brick_building_facade.glb", "wings", "wing_relief"),
    ("sds_logo.glb", "logo_sign", "logo_mass"),
    ("sds_itau.glb", "itau", "itau_storefront"),
    ("sds_balcony_planter.glb", "planters", "planter_mass"),
    ("sds_warning.glb", "warning_dressing", "warning_mass"),
]


def _sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _mesh_info(obj):
    from mathutils import Vector

    mesh = obj.data
    mesh.calc_loop_triangles()
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    xs = [c.x for c in corners]
    ys = [c.y for c in corners]
    zs = [c.z for c in corners]
    return {
        "name": obj.name,
        "verts": len(mesh.vertices),
        "tris": len(mesh.loop_triangles),
        "materials": [s.name for s in obj.material_slots],
        "aabb": {
            "min": [min(xs), min(ys), min(zs)],
            "max": [max(xs), max(ys), max(zs)],
            "size": [max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)],
        },
        "has_vertex_color": bool(getattr(mesh, "color_attributes", None) and len(mesh.color_attributes) > 0)
        or bool(getattr(mesh, "vertex_colors", None) and len(mesh.vertex_colors) > 0),
    }


def _preview(path, obj):
    import bpy
    from mathutils import Vector

    os.makedirs(os.path.dirname(path), exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.film_transparent = False
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    center = sum(corners, Vector((0, 0, 0))) / 8.0
    size = max((max(c[i] for c in corners) - min(c[i] for c in corners)) for i in range(3))
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(size * 1.35, 0.2)
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (center.x, center.y - size * 2.2, center.z)
    cam.rotation_euler = (1.5708, 0.0, 0.0)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)
    bpy.data.cameras.remove(cam_data)


def _export_obj(obj, path):
    import bpy

    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.hide_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy_util.export_glb(path, selected=True)


def _separate_loose(obj):
    import bpy

    bpy_util._active(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.mesh.separate(type="LOOSE")
    except Exception as exc:
        print("SEPARATE_LOOSE_FAIL", obj.name, exc)
    bpy.ops.object.mode_set(mode="OBJECT")
    return [o for o in bpy.context.view_layer.objects if o.type == "MESH" and o.select_get()]


def _bisect_keep_above(src, z_cut, name):
    import bpy

    bpy.ops.object.select_all(action="DESELECT")
    src.select_set(True)
    bpy.context.view_layer.objects.active = src
    bpy.ops.object.duplicate()
    dup = bpy.context.active_object
    dup.name = name
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.bisect(plane_co=(0.0, 0.0, z_cut), plane_no=(0.0, 0.0, 1.0), clear_inner=True, clear_outer=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    return dup


def _bisect_keep_below(src, z_cut, name):
    import bpy

    bpy.ops.object.select_all(action="DESELECT")
    src.select_set(True)
    bpy.context.view_layer.objects.active = src
    bpy.ops.object.duplicate()
    dup = bpy.context.active_object
    dup.name = name
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.bisect(plane_co=(0.0, 0.0, z_cut), plane_no=(0.0, 0.0, 1.0), clear_inner=False, clear_outer=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    return dup


def _ground_origin(obj):
    import bpy
    from mathutils import Vector

    bpy_util.apply_transforms(obj)
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    zmin = min(c.z for c in corners)
    obj.location.z -= zmin
    bpy_util.apply_transforms(obj)


def process_file(fname, bucket, stem):
    import bpy

    raw_path = os.path.join(RAW, fname)
    row = {
        "raw": raw_path,
        "bytes": os.path.getsize(raw_path),
        "sha256": _sha256(raw_path),
        "bucket": bucket,
        "objects_before": [],
        "extracts": [],
    }
    bpy_util.reset_scene()
    imported = bpy_util.import_glb(raw_path)
    meshes = [o for o in imported if o.type == "MESH"]
    for o in meshes:
        bpy_util.apply_transforms(o)
        row["objects_before"].append(_mesh_info(o))
    if not meshes:
        print("NO_MESH", fname)
        return row
    joined = bpy_util.join_objects(meshes, stem + "_joined")
    _ground_origin(joined)
    preview_path = os.path.join(PREVIEW, stem + "_front.png")
    _preview(preview_path, joined)
    row["preview"] = preview_path

    out_primary = os.path.join(EXTRACT, bucket, stem + ".glb")
    _export_obj(joined, out_primary)
    extracts = [
        {
            "id": stem,
            "path": out_primary,
            "source_object": joined.name,
            "cleanup": ["import_gltf", "join", "apply", "ground_z", "export_glb"],
            "triangle_count": _mesh_info(joined)["tris"],
            "aabb": _mesh_info(joined)["aabb"],
            "classification": "KEEP_AFTER_CLEANUP",
            "role": "primary_identity",
            "note": "Tripo fused mesh; loose-separate exploded into thousands of noise shells so the joined mesh is the object-level component",
        }
    ]

    if bucket == "wings":
        info = _mesh_info(joined)
        z0, z1 = info["aabb"]["min"][2], info["aabb"]["max"][2]
        z_lo = z0 + 0.42 * (z1 - z0)
        lower = _bisect_keep_below(joined, z_lo, "wing_lower_storefront")
        upper = _bisect_keep_above(joined, z_lo, "wing_upper_band")
        for piece, pid in ((lower, "wing_lower_storefront"), (upper, "wing_upper_band")):
            if piece is None or piece.type != "MESH" or len(piece.data.vertices) < 8:
                continue
            out = os.path.join(EXTRACT, bucket, pid + ".glb")
            _export_obj(piece, out)
            extracts.append(
                {
                    "id": pid,
                    "path": out,
                    "source_object": joined.name,
                    "cleanup": ["duplicate", "bisect_z", "export_glb"],
                    "triangle_count": _mesh_info(piece)["tris"],
                    "aabb": _mesh_info(piece)["aabb"],
                    "classification": "KEEP_AFTER_CLEANUP",
                    "role": "z_band",
                }
            )
            _preview(os.path.join(PREVIEW, pid + "_front.png"), piece)

    row["extracts"] = extracts
    return row


def main():
    os.makedirs(EXTRACT, exist_ok=True)
    os.makedirs(PREVIEW, exist_ok=True)
    for _, bucket, _ in FILES:
        os.makedirs(os.path.join(EXTRACT, bucket), exist_ok=True)
        os.makedirs(os.path.join(EXTRACT, "storefronts"), exist_ok=True)
        os.makedirs(os.path.join(EXTRACT, "misc_reference_only"), exist_ok=True)
    audit = []
    for fname, bucket, stem in FILES:
        print("PROCESS", fname)
        audit.append(process_file(fname, bucket, stem))
    with open(AUDIT_JSON, "w", encoding="utf-8") as f:
        json.dump(audit, f, indent=2)
    print("AUDIT_WRITTEN", AUDIT_JSON)
    print("EXTRACT_ROOT", EXTRACT)


if __name__ == "__main__":
    main()
