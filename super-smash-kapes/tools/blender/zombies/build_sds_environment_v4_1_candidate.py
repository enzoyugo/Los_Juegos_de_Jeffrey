"""Shopping del Sol V4.1 CANDIDATE — Tripo-assisted facade + atrium rebuild.

Does NOT overwrite V3 or V4. State: HUMAN_REVIEW_REQUIRED. Not SDS_V4_1_CANONICAL.

Authority:
- EXTERIOR_STATION_034 night arch / star / SHOPPING del SOL / zigzag plaza
- EXTERIOR_STATION_007 / 001 parking
- INTERIOR_STATION_032 / 035 hall + atrium
- photos/shopping-del-sol.jpg wood fan vault + stairs

Gameplay anchors unchanged: spawn z=28.5, entrance z=8.2. No trimesh. No EEVEE.
Tripo SDS facade kit is placed as primary entrance massing; manual work completes depth/sign/interior.
"""

from __future__ import annotations

import math
import os
import shutil
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from tools.blender.common import bpy_util  # noqa: E402

BLEND = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "blender", "shopping_del_sol_zombies_environment_v4_1_candidate.blend")
EXPORT = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "blender", "exports", "shopping_del_sol_zombies_environment_v4_1_candidate.glb")
PROCESSED = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "processed", "shopping_del_sol_zombies_environment_v4_1_candidate.glb")
TEX_DIR = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "processed", "textures")
CARS = os.path.join(ROOT, "assets", "environments", "shared", "urban", "processed", "vehicles")
KIT = r"E:\JeffreyAIResearch\asset-library\processed\environment\shopping_del_sol\facade"
DECISIONS = os.path.join(ROOT, "docs", "generated", "sds_v4_1_candidate_asset_decisions.json")
AUTHORITY = os.path.join(ROOT, "docs", "generated", "sds_v4_1_candidate_authority_frames.txt")
AMAROK = r"E:\JeffreyAIResearch\asset-library\processed\vehicles\low_poly\2009_volkswagen_amarok_low_poly\v001\2009_volkswagen_amarok_low_poly.glb"


def _g(x, y, z):
    return (float(x), float(-z), float(y))


def _s(sx, sy, sz):
    return (float(sx), float(sz), float(sy))


def _write_png_pixels(path, size, fn):
    import bpy

    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = bpy.data.images.new(os.path.basename(path), width=size, height=size, alpha=False)
    px = [0.0] * (size * size * 4)
    for y in range(size):
        for x in range(size):
            r, g, b = fn(x, y, size)
            i = (y * size + x) * 4
            px[i] = r
            px[i + 1] = g
            px[i + 2] = b
            px[i + 3] = 1.0
    img.pixels = px
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def _interior_tile(x, y, size):
    tile = size // 4
    tx = x % tile
    ty = y % tile
    cx = abs(tx - tile * 0.5)
    cy = abs(ty - tile * 0.5)
    n = ((x * 13 + y * 7) % 17) * 0.004
    if cx + cy < tile * 0.16:
        return (0.42, 0.22, 0.14)
    if cx + cy < tile * 0.22:
        return (0.72, 0.62, 0.48)
    if tx < 6 or ty < 6:
        return (0.58, 0.52, 0.42)
    return (0.84 + n, 0.78, 0.66)


def _plaza_tile(x, y, size):
    tile = size // 5
    tx = x % tile
    ty = y % tile
    n = ((x * 11 + y * 3) % 13) * 0.006
    band = (tx < 10) or (ty < 10)
    if band:
        return (0.48, 0.32, 0.18)
    return (0.70 + n, 0.58, 0.38)


def _mat_tex(name, img, rough=0.55, scale=(4.0, 4.0, 1.0)):
    import bpy

    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = scale
    coord = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(coord.outputs["UV"], mapping.inputs["Vector"])
    nt.links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    sock = bsdf.inputs.get("Roughness")
    if sock:
        sock.default_value = rough
    return mat


def _ensure_uv(obj, scale=4.0):
    import bpy

    bpy_util._active(obj)
    if not obj.data.uv_layers:
        obj.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.uv.cube_project(cube_size=float(scale), correct_aspect=True, scale_to_bounds=False)
    except TypeError:
        bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")


def _mats(tile_img, plaza_img):
    return {
        "asphalt": bpy_util.new_mat("SDS41_Asphalt", (0.06, 0.06, 0.07), rough=0.95),
        "line": bpy_util.new_mat("SDS41_Line", (0.92, 0.9, 0.8), rough=0.4),
        "curb": bpy_util.new_mat("SDS41_Curb", (0.5, 0.48, 0.42), rough=0.82),
        "soil": bpy_util.new_mat("SDS41_Soil", (0.22, 0.16, 0.09), rough=0.93),
        "grass": bpy_util.new_mat("SDS41_Grass", (0.12, 0.32, 0.1), rough=0.84),
        "masonry": bpy_util.new_mat("SDS41_Masonry", (0.8, 0.74, 0.62), rough=0.64),
        "cream": bpy_util.new_mat("SDS41_Cream", (0.92, 0.88, 0.76), rough=0.42),
        "terra": bpy_util.new_mat("SDS41_Terra", (0.5, 0.28, 0.15), rough=0.72),
        "dark": bpy_util.new_mat("SDS41_MetalDark", (0.1, 0.1, 0.12), metal=0.62, rough=0.32),
        "metal": bpy_util.new_mat("SDS41_Metal", (0.62, 0.64, 0.66), metal=0.72, rough=0.22),
        "glass": bpy_util.new_mat("SDS41_Glass", (0.45, 0.68, 0.78), rough=0.03, metal=0.12, alpha=0.28),
        "glass_in": bpy_util.new_mat("SDS41_GlassIn", (0.92, 0.9, 0.78), rough=0.06, metal=0.06, alpha=0.38, emit=0.55),
        "glow": bpy_util.new_mat("SDS41_WarmGlow", (1.0, 0.76, 0.4), emit=3.6, rough=0.2),
        "star": bpy_util.new_mat("SDS41_Star", (1.0, 0.84, 0.16), emit=7.2, rough=0.14),
        "sign": bpy_util.new_mat("SDS41_SignLit", (0.98, 0.98, 0.96), emit=3.4, rough=0.18),
        "trunk": bpy_util.new_mat("SDS41_Trunk", (0.3, 0.18, 0.09), rough=0.92),
        "leaf": bpy_util.new_mat("SDS41_Leaf", (0.1, 0.34, 0.12), rough=0.68),
        "fan": bpy_util.new_mat("SDS41_FanPalm", (0.16, 0.38, 0.14), rough=0.7),
        "lamp": bpy_util.new_mat("SDS41_Lamp", (1.0, 0.9, 0.58), emit=5.0),
        "wood": bpy_util.new_mat("SDS41_VaultWood", (0.58, 0.36, 0.16), rough=0.48),
        "brick": bpy_util.new_mat("SDS41_Brick", (0.52, 0.26, 0.18), rough=0.8),
        "shop": bpy_util.new_mat("SDS41_ShopDark", (0.07, 0.07, 0.08), metal=0.18, rough=0.42),
        "bench": bpy_util.new_mat("SDS41_Bench", (0.22, 0.14, 0.08), rough=0.72),
        "rail_wood": bpy_util.new_mat("SDS41_RailWood", (0.42, 0.26, 0.12), rough=0.45),
        "cool": bpy_util.new_mat("SDS41_CoolLight", (0.75, 0.88, 1.0), emit=2.4, rough=0.2),
        "emerg": bpy_util.new_mat("SDS41_Emerg", (0.95, 0.25, 0.12), emit=1.6, rough=0.3),
        "tile": _mat_tex("SDS41_InteriorTile", tile_img, rough=0.24, scale=(3.2, 3.2, 1.0)),
        "plaza": _mat_tex("SDS41_PlazaTile", plaza_img, rough=0.5, scale=(3.6, 3.6, 1.0)),
    }


def _place_kit(col, rel, name, target_w, gx, gy, gz, rot=(0.0, 0.0, 0.0)):
    import mathutils

    path = os.path.join(KIT, rel)
    if not os.path.isfile(path):
        print("KIT_MISSING", rel)
        return None
    imported = bpy_util.import_glb(path)
    joined = bpy_util.join_objects(imported, name)
    if joined is None:
        return None
    corners = [joined.matrix_world @ mathutils.Vector(c) for c in joined.bound_box]
    xs = [c.x for c in corners]
    ys = [c.y for c in corners]
    zs = [c.z for c in corners]
    sx = max(xs) - min(xs)
    sy = max(ys) - min(ys)
    sz = max(zs) - min(zs)
    span = max(sx, sy, 0.001)
    scale = float(target_w) / span
    joined.scale = (scale, scale, scale)
    bpy_util.apply_transforms(joined)
    joined.rotation_euler = rot
    bpy_util.apply_transforms(joined)
    joined.location = _g(gx, gy, gz)
    bpy_util.link(joined, col)
    print("KIT_PLACE", name, "src_span", round(span, 3), "scale", round(scale, 2), "tris_est", bpy_util.triangle_count([joined]))
    return joined


def _letter(col, mats, ch, x, y, z, w=0.42, h=0.58, d=0.1):
    if ch == " ":
        return None
    return bpy_util.box("Sign_%s_%0.1f" % (ch, x), _s(w, h, d), _g(x, y, z), (0, 0, 0), mats["sign"], col)


def _sign_readable(col, mats):
    ## Box letters facing parking (+Z). Do not use mirrored text meshes.
    text = "SHOPPING del SOL"
    x0 = -5.05
    x = x0
    for ch in text:
        w = 0.22 if ch == " " else (0.28 if ch.islower() else 0.4)
        h = 0.42 if ch.islower() else 0.62
        _letter(col, mats, ch, x + w * 0.5, 7.15, 9.42, w * 0.86, h, 0.11)
        x += w + 0.06
    bpy_util.box("SignBacking", _s(10.6, 0.95, 0.08), _g(0, 7.15, 9.28), (0, 0, 0), mats["dark"], col)


def _star(col, mats, x, y, z):
    bpy_util.box("StarA", _s(1.7, 0.38, 0.14), _g(x, y, z), (0, 0, 0.0), mats["star"], col)
    bpy_util.box("StarB", _s(1.7, 0.38, 0.14), _g(x, y, z), (0, 0, math.pi * 0.25), mats["star"], col)
    bpy_util.box("StarC", _s(1.7, 0.38, 0.14), _g(x, y, z), (0, 0, math.pi * 0.5), mats["star"], col)
    bpy_util.box("StarD", _s(1.7, 0.38, 0.14), _g(x, y, z), (0, 0, math.pi * 0.75), mats["star"], col)
    bpy_util.box("StarCore", _s(0.42, 0.42, 0.16), _g(x, y, z + 0.08), (0, 0, 0), mats["glow"], col)


def _arch_segments(col, mat, radius, thick, depth, z_face, y0, n=28, name="Arch"):
    for i in range(n):
        t0 = 0.10 + (math.pi - 0.20) * i / n
        t1 = 0.10 + (math.pi - 0.20) * (i + 1) / n
        t = 0.5 * (t0 + t1)
        xx = math.cos(t) * radius
        yy = math.sin(t) * radius + y0
        span = radius * abs(t1 - t0) + 0.08
        bpy_util.box("%s_%02d" % (name, i), _s(thick, span, depth), _g(xx, yy, z_face), (0.0, -(t - math.pi * 0.5), 0.0), mat, col)


def _facade(col, mats):
    ## Tripo kit first (front-facing SDS photo reconstructions), then manual depth.
    _place_kit(col, os.path.join("arch", "sds_facade_arch_kit_v001.glb"), "TripoArch", 13.6, 0.0, 0.02, 9.85, (0, 0, 0))
    _place_kit(col, os.path.join("glass", "sds_facade_glass_kit_v001.glb"), "TripoGlass", 8.8, 0.0, 1.4, 8.55, (0, math.pi * 0.5, 0))
    _place_kit(col, os.path.join("entrance", "architectural_doorway_3d_model_kit_v001.glb"), "TripoDoor", 4.6, 0.0, 0.02, 7.15, (0, 0, 0))
    _place_kit(col, os.path.join("details", "sds_logo_kit_v001.glb"), "TripoLogo", 3.4, 0.0, 8.6, 8.95, (0, 0, 0))
    _place_kit(col, os.path.join("wings", "sds_collumns_kit_v001.glb"), "TripoColsL", 4.2, -7.4, 0.0, 9.4, (0, 0, 0))
    _place_kit(col, os.path.join("wings", "sds_collumns_kit_v001.glb"), "TripoColsR", 4.2, 7.4, 0.0, 9.4, (0, math.pi, 0))
    _place_kit(col, os.path.join("wings", "brick_building_facade_3d_model_kit_v001.glb"), "TripoWingL", 16.5, -16.5, 0.0, 8.35, (0, 0, 0))
    _place_kit(col, os.path.join("wings", "brick_building_facade_3d_model_kit_v001.glb"), "TripoWingR", 16.5, 16.5, 0.0, 8.35, (0, math.pi, 0))
    _place_kit(col, os.path.join("details", "sds_itau_kit_v001.glb"), "TripoItau", 3.8, 11.6, 0.0, 11.4, (0, 0, 0))
    _place_kit(col, os.path.join("details", "balcony_planter_3d_model_kit_v001.glb"), "TripoPlanterL", 2.2, -4.8, 0.0, 11.6, (0, 0, 0))
    _place_kit(col, os.path.join("details", "balcony_planter_3d_model_kit_v001.glb"), "TripoPlanterR", 2.2, 4.8, 0.0, 11.6, (0, 0, 0))

    _arch_segments(col, mats["cream"], 6.7, 0.38, 1.15, 10.35, 0.15, 32, "ShellOuter")
    _arch_segments(col, mats["cream"], 6.15, 0.28, 0.95, 10.85, 0.22, 30, "ShellMid")
    _arch_segments(col, mats["cream"], 5.7, 0.2, 0.75, 11.25, 0.28, 28, "ShellInner")
    bpy_util.box("GlassOuter", _s(9.4, 6.4, 0.05), _g(0, 3.2, 8.92), (0, 0, 0), mats["glass_in"], col)
    bpy_util.box("GlassMid", _s(8.6, 5.8, 0.05), _g(0, 3.3, 7.85), (0, 0, 0), mats["glass"], col)
    bpy_util.box("GlassInner", _s(7.8, 5.2, 0.05), _g(0, 3.4, 6.95), (0, 0, 0), mats["glass_in"], col)
    for i, x in enumerate((-3.4, -1.7, 0.0, 1.7, 3.4)):
        bpy_util.box("Mullion_%d" % i, _s(0.07, 5.6, 0.1), _g(x, 2.9, 8.95), (0, 0, 0), mats["metal"], col)
    bpy_util.box("VestFloor", _s(8.8, 0.08, 2.8), _g(0, 0.02, 7.4), (0, 0, 0), mats["cream"], col)
    bpy_util.box("VestCeil", _s(9.0, 0.16, 3.0), _g(0, 5.55, 7.4), (0, 0, 0), mats["cream"], col)
    bpy_util.box("DoorL", _s(1.5, 2.9, 0.08), _g(-0.82, 1.48, 6.72), (0, 0, 0), mats["glass"], col)
    bpy_util.box("DoorR", _s(1.5, 2.9, 0.08), _g(0.82, 1.48, 6.72), (0, 0, 0), mats["glass"], col)
    bpy_util.box("DoorFrame", _s(3.35, 3.15, 0.18), _g(0, 1.6, 6.62), (0, 0, 0), mats["metal"], col)
    bpy_util.box("Canopy", _s(14.4, 0.26, 4.8), _g(0, 5.72, 9.85), (0, 0, 0), mats["cream"], col)
    bpy_util.box("CanopyLip", _s(13.6, 0.14, 0.2), _g(0, 5.5, 12.15), (0, 0, 0), mats["metal"], col)
    _star(col, mats, 0.0, 9.55, 8.15)
    _sign_readable(col, mats)
    for side in (-1.0, 1.0):
        bpy_util.box("Portal_%d" % int(side), _s(1.45, 9.2, 3.6), _g(side * 5.85, 4.6, 7.6), (0, 0, 0), mats["cream"], col)
        for i in range(5):
            x = side * (8.5 + i * 3.9)
            bpy_util.box("Pier_%d_%d" % (int(side), i), _s(0.78, 8.6, 0.9), _g(x, 4.3, 9.62), (0, 0, 0), mats["cream"], col)
            bpy_util.box("PierUp_%d_%d" % (int(side), i), _s(0.32, 0.1, 0.32), _g(x, 0.2, 9.95), (0, 0, 0), mats["glow"], col)
            bpy_util.box("ShopG_%d_%d" % (int(side), i), _s(2.6, 3.2, 0.06), _g(x + side * 1.9, 1.7, 9.68), (0, 0, 0), mats["glass_in" if i % 2 == 0 else "glass"], col)
            bpy_util.box("ShopRoom_%d_%d" % (int(side), i), _s(2.4, 2.8, 1.6), _g(x + side * 1.9, 1.5, 8.55), (0, 0, 0), mats["shop"], col)
            bpy_util.box("ShopUpper_%d_%d" % (int(side), i), _s(2.6, 2.4, 0.06), _g(x + side * 1.9, 5.4, 9.62), (0, 0, 0), mats["glass"], col)
            bpy_util.empty("LIGHT_PIER_%d_%d" % (int(side), i), _g(x, 1.5, 10.2), (0, 0, 0), col, 0.3)
    bpy_util.empty("LIGHT_ENTRANCE_001", _g(0, 4.5, 10.3), (0, 0, 0), col, 1.0)
    bpy_util.empty("LIGHT_STAR", _g(0, 9.4, 8.4), (0, 0, 0), col, 0.45)


def _zigzag_plaza(col, mats):
    walk = bpy_util.box("PlazaWalk", _s(9.6, 0.06, 10.6), _g(0, 0.03, 13.4), (0, 0, 0), mats["plaza"], col)
    _ensure_uv(walk, 1.6)
    for i in range(12):
        zz = 9.2 + i * 0.82
        step = 0.55 if i % 2 == 0 else 0.0
        bpy_util.box("ZigL_%d" % i, _s(0.82, 0.05, 0.76), _g(-4.4 - step, 0.06, zz), (0, 0, 0), mats["terra"], col)
        bpy_util.box("ZigR_%d" % i, _s(0.82, 0.05, 0.76), _g(4.4 + step, 0.06, zz), (0, 0, 0), mats["terra"], col)
    for i in range(7):
        bpy_util.box("Zebra_%d" % i, _s(0.42, 0.04, 1.85), _g(-2.5 + i * 0.85, 0.07, 9.15), (0, 0, 0), mats["line"], col)


def _palm(col, mats, x, z, h, name):
    bpy_util.cylinder("%s_Trunk" % name, 0.14, h, _g(x, h * 0.5, z), (0, 0, 0), mats["trunk"], col, 12)
    n = 11
    for i in range(n):
        ang = i * (math.tau / n)
        bpy_util.box("%s_F_%d" % (name, i), _s(0.14, 0.025, 3.1), _g(x + math.sin(ang) * 1.15, h + 0.08, z + math.cos(ang) * 1.15), (0.62, 0.06, ang), mats["leaf"], col)
        bpy_util.box("%s_G_%d" % (name, i), _s(0.1, 0.02, 2.2), _g(x + math.sin(ang + 0.18) * 0.65, h + 0.42, z + math.cos(ang + 0.18) * 0.65), (0.22, -0.04, ang + 0.12), mats["leaf"], col)
    bpy_util.ico("%s_Heart" % name, 0.28, _g(x, h + 0.1, z), mats["leaf"], col, 1)


def _lamp(col, mats, x, z, i):
    bpy_util.cylinder("LampPole_%02d" % i, 0.075, 7.4, _g(x, 3.7, z), (0, 0, 0), mats["metal"], col, 10)
    bpy_util.cylinder("LampCurve_%02d" % i, 0.055, 1.5, _g(x, 7.55, z + 0.45), (0.85, 0, 0), mats["metal"], col, 8)
    bpy_util.cylinder("LampHead_%02d" % i, 0.18, 0.32, _g(x, 7.15, z + 1.05), (1.2, 0, 0), mats["lamp"], col, 10)
    bpy_util.empty("LIGHT_PARKING_%03d" % i, _g(x, 7.0, z + 1.0), (0, 0, 0), col, 0.5)


def _parking(col, mats, veg, lights):
    bpy_util.box("ParkingAsphalt", _s(88.0, 0.12, 58.0), _g(0, -0.06, 28.0), (0, 0, 0), mats["asphalt"], col)
    for z in range(16, 46, 3):
        bpy_util.box("Dash_%d" % z, _s(0.16, 0.02, 1.3), _g(0, 0.03, float(z)), (0, 0, 0), mats["line"], col)
    for side in (-1.0, 1.0):
        for i in range(10):
            z = 13.4 + i * 3.15
            bpy_util.box("Stall_%d_%d" % (int(side), i), _s(5.0, 0.02, 0.07), _g(side * 8.4, 0.025, z), (0, 0, 0), mats["line"], col)
            bpy_util.box("StallEnd_%d_%d" % (int(side), i), _s(0.07, 0.02, 2.9), _g(side * 10.85, 0.025, z + 1.45), (0, 0, 0), mats["line"], col)
    _zigzag_plaza(col, mats)
    islands = ((-1.0, 17.0), (1.0, 17.0), (-1.0, 33.0), (1.0, 25.5), (1.0, 41.0), (-1.0, 41.0))
    for i, (side, z) in enumerate(islands):
        bpy_util.box("Island_%d" % i, _s(1.7, 0.24, 5.2), _g(side * 5.7, 0.12, z), (0, 0, 0), mats["curb"], col)
        bpy_util.box("Soil_%d" % i, _s(1.35, 0.16, 4.8), _g(side * 5.7, 0.22, z), (0, 0, 0), mats["soil"], col)
        bpy_util.box("Grass_%d" % i, _s(1.15, 0.08, 4.5), _g(side * 5.7, 0.3, z), (0, 0, 0), mats["grass"], col)
        _palm(veg, mats, side * 5.7, z, 6.0 + (i % 3) * 0.25, "Palm_%d" % i)
    for i, x in enumerate((-3.6, -1.8, 1.8, 3.6)):
        bpy_util.cylinder("Bollard_%d" % i, 0.09, 0.72, _g(x, 0.36, 11.2), (0, 0, 0), mats["metal"], col, 8)
    bpy_util.box("BenchL", _s(1.9, 0.12, 0.48), _g(-3.4, 0.42, 12.4), (0, 0, 0), mats["bench"], col)
    bpy_util.box("BenchLS", _s(1.9, 0.32, 0.12), _g(-3.4, 0.22, 12.4), (0, 0, 0), mats["curb"], col)
    bpy_util.box("BenchR", _s(1.9, 0.12, 0.48), _g(3.4, 0.42, 12.4), (0, 0, 0), mats["bench"], col)
    bpy_util.box("BinL", _s(0.42, 0.72, 0.42), _g(-6.2, 0.36, 12.0), (0, 0, 0), mats["dark"], col)
    bpy_util.box("BinR", _s(0.42, 0.72, 0.42), _g(6.2, 0.36, 12.0), (0, 0, 0), mats["dark"], col)
    for i, (x, z) in enumerate([(-5.7, 17.0), (5.7, 17.0), (-5.7, 33.0), (5.7, 33.0), (-22.0, 24.0), (22.0, 24.0), (0.0, 44.0)], start=1):
        _lamp(lights, mats, x, z, i)


def _fan_vault(col, mats, cx, cz, y, radius=9.2, n=18):
    bpy_util.box("SkylightFrame", _s(3.4, 0.22, 3.4), _g(cx, y, cz), (0, 0, 0), mats["wood"], col)
    bpy_util.box("SkylightGlass", _s(2.8, 0.06, 2.8), _g(cx, y + 0.08, cz), (0, 0, 0), mats["glass_in"], col)
    for i in range(n):
        ang = i * (math.tau / n)
        mx = cx + math.cos(ang) * radius * 0.55
        mz = cz + math.sin(ang) * radius * 0.55
        bpy_util.box(
            "VaultBeam_%02d" % i,
            _s(0.22, 0.18, radius * 0.92),
            _g(mx, y - 0.85, mz),
            (0.32, 0.0, ang + math.pi * 0.5),
            mats["wood"],
            col,
        )
        bpy_util.box("VaultSpot_%02d" % i, _s(0.08, 0.06, 0.08), _g(mx, y - 0.55, mz), (0, 0, 0), mats["glow"], col)


def _interior(col, mats):
    floor = bpy_util.box("HallFloor", _s(20.0, 0.08, 16.4), _g(0, 0.0, 2.0), (0, 0, 0), mats["tile"], col)
    _ensure_uv(floor, 1.5)
    bpy_util.box("HallWallL", _s(0.42, 10.4, 16.4), _g(-10.1, 5.2, 2.0), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("HallWallR", _s(0.42, 10.4, 16.4), _g(10.1, 5.2, 2.0), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("BrickBandL", _s(0.18, 3.4, 16.0), _g(-9.88, 8.2, 2.0), (0, 0, 0), mats["brick"], col)
    bpy_util.box("BrickBandR", _s(0.18, 3.4, 16.0), _g(9.88, 8.2, 2.0), (0, 0, 0), mats["brick"], col)
    _fan_vault(col, mats, 0.0, 2.0, 11.6, 9.6, 16)
    for i, z in enumerate((5.4, 1.2, -2.4)):
        bpy_util.box("ShopGlassL_%d" % i, _s(5.6, 3.5, 0.06), _g(-6.9, 1.85, z - 1.55), (0, 0, 0), mats["glass_in"], col)
        bpy_util.box("ShopRoomL_%d" % i, _s(5.2, 3.1, 2.2), _g(-6.9, 1.7, z - 2.7), (0, 0, 0), mats["shop"], col)
        bpy_util.box("ShopBandL_%d" % i, _s(5.5, 0.42, 0.1), _g(-6.9, 3.7, z - 1.42), (0, 0, 0), mats["sign" if i != 1 else "cool"], col)
        bpy_util.box("ShopGlassR_%d" % i, _s(5.6, 3.5, 0.06), _g(6.9, 1.85, z - 1.55), (0, 0, 0), mats["glass" if i == 1 else "glass_in"], col)
        bpy_util.box("ShopRoomR_%d" % i, _s(5.2, 3.1, 2.2), _g(6.9, 1.7, z - 2.7), (0, 0, 0), mats["shop"], col)
        bpy_util.box("ShopBandR_%d" % i, _s(5.5, 0.42, 0.1), _g(6.9, 3.7, z - 1.42), (0, 0, 0), mats["sign"], col)
        bpy_util.cylinder("ColL_%d" % i, 0.4, 9.2, _g(-4.5, 4.6, z), (0, 0, 0), mats["cream"], col, 16)
        bpy_util.cylinder("ColR_%d" % i, 0.4, 9.2, _g(4.5, 4.6, z), (0, 0, 0), mats["cream"], col, 16)
        bpy_util.empty("LIGHT_INTERIOR_%03d" % (i + 1), _g(0, 7.6, z), (0, 0, 0), col, 0.55)
    bpy_util.box("KioskBody", _s(2.6, 2.2, 2.6), _g(0, 1.1, 1.4), (0, 0, 0), mats["shop"], col)
    bpy_util.box("KioskTop", _s(2.85, 0.1, 2.85), _g(0, 2.25, 1.4), (0, 0, 0), mats["sign"], col)
    bpy_util.box("HallBench", _s(2.4, 0.12, 0.5), _g(-2.8, 0.42, 3.6), (0, 0, 0), mats["bench"], col)
    bpy_util.box("ATM", _s(0.7, 1.4, 0.35), _g(4.4, 0.72, 4.2), (0, 0, 0), mats["dark"], col)
    bpy_util.box("ATMScreen", _s(0.42, 0.32, 0.04), _g(4.4, 1.05, 4.4), (0, 0, 0), mats["cool"], col)

    atrium_z = -14.0
    atrium = bpy_util.box("AtriumFloor", _s(30.0, 0.08, 24.0), _g(0, 0.0, atrium_z), (0, 0, 0), mats["tile"], col)
    _ensure_uv(atrium, 1.4)
    bpy_util.box("AtriumWell", _s(8.4, 0.04, 8.4), _g(0, 0.05, atrium_z - 1.2), (0, 0, 0), mats["plaza"], col)
    bpy_util.box("AtriumAnchor", _s(2.4, 0.55, 2.4), _g(0, 0.3, atrium_z - 1.2), (0, 0, 0), mats["curb"], col)
    bpy_util.ico("AtriumPlant", 1.15, _g(0, 1.5, atrium_z - 1.2), mats["fan"], col, 2)
    bpy_util.box("AtriumWallN", _s(30.2, 15.2, 0.42), _g(0, 7.6, -25.8), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("AtriumWallL", _s(0.42, 15.2, 24.0), _g(-15.0, 7.6, atrium_z), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("AtriumWallR", _s(0.42, 15.2, 24.0), _g(15.0, 7.6, atrium_z), (0, 0, 0), mats["masonry"], col)
    _fan_vault(col, mats, 0.0, atrium_z, 14.8, 11.5, 20)
    for i in range(14):
        bpy_util.box("Stair_%02d" % i, _s(6.6, 0.14, 0.4), _g(0, 0.08 + i * 0.42, -18.6 - i * 0.28), (0, 0, 0), mats["metal"], col)
        bpy_util.box("StairNos_%02d" % i, _s(6.6, 0.03, 0.05), _g(0, 0.16 + i * 0.42, -18.42 - i * 0.28), (0, 0, 0), mats["line"], col)
    bpy_util.box("Escalator", _s(1.35, 0.12, 6.8), _g(-4.6, 2.4, -20.4), (0.55, 0, 0), mats["dark"], col)
    bpy_util.box("EscalatorR", _s(1.35, 0.12, 6.8), _g(4.6, 2.4, -20.4), (0.55, 0, 0), mats["dark"], col)
    bpy_util.box("MezzU", _s(28.0, 0.2, 4.8), _g(0, 6.15, -23.2), (0, 0, 0), mats["wood"], col)
    bpy_util.box("MezzL", _s(4.4, 0.2, 16.0), _g(-12.6, 6.15, atrium_z), (0, 0, 0), mats["wood"], col)
    bpy_util.box("MezzR", _s(4.4, 0.2, 16.0), _g(12.6, 6.15, atrium_z), (0, 0, 0), mats["wood"], col)
    bpy_util.box("RailGlassF", _s(22.0, 1.05, 0.05), _g(0, 6.8, -20.85), (0, 0, 0), mats["glass"], col)
    bpy_util.box("RailCapF", _s(22.2, 0.06, 0.08), _g(0, 7.35, -20.85), (0, 0, 0), mats["rail_wood"], col)
    bpy_util.box("RailGlassL", _s(0.05, 1.05, 15.2), _g(-10.45, 6.8, atrium_z), (0, 0, 0), mats["glass"], col)
    bpy_util.box("RailGlassR", _s(0.05, 1.05, 15.2), _g(10.45, 6.8, atrium_z), (0, 0, 0), mats["glass"], col)
    bpy_util.box("MezzShopA", _s(7.2, 2.9, 0.06), _g(-6.6, 7.75, -25.45), (0, 0, 0), mats["glass_in"], col)
    bpy_util.box("MezzShopB", _s(7.2, 2.9, 0.06), _g(6.6, 7.75, -25.45), (0, 0, 0), mats["glass_in"], col)
    bpy_util.box("DarkShop", _s(4.8, 3.2, 0.06), _g(-12.4, 1.7, -25.4), (0, 0, 0), mats["shop"], col)
    bpy_util.box("EmergLight", _s(0.18, 0.12, 0.08), _g(-12.4, 3.5, -25.2), (0, 0, 0), mats["emerg"], col)
    bpy_util.empty("LIGHT_ATRIUM", _g(0, 12.2, atrium_z), (0, 0, 0), col, 1.3)
    bpy_util.empty("LIGHT_MEZZANINE", _g(0, 8.6, -22.0), (0, 0, 0), col, 0.6)

    bpy_util.box("BranchAFloor", _s(18.4, 0.08, 12.4), _g(-23.0, 0.0, atrium_z), (0, 0, 0), mats["tile"], col)
    bpy_util.box("BranchAWallN", _s(18.4, 9.0, 0.38), _g(-23.0, 4.5, -19.9), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("BranchAWallS", _s(18.4, 9.0, 0.38), _g(-23.0, 4.5, -8.1), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("BranchAEnd", _s(0.38, 9.0, 12.4), _g(-32.1, 4.5, atrium_z), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("BranchAGlow", _s(0.2, 2.2, 4.0), _g(-31.85, 3.4, atrium_z), (0, 0, 0), mats["glow"], col)
    for i, z in enumerate((-10.4, -17.6)):
        bpy_util.box("BranchAShop_%d" % i, _s(5.0, 3.3, 0.06), _g(-23.0, 1.75, z), (0, 0, 0), mats["glass_in"], col)
    bpy_util.empty("LIGHT_BRANCH_A", _g(-23.0, 6.4, atrium_z), (0, 0, 0), col, 0.5)
    bpy_util.box("BranchBFloor", _s(18.4, 0.08, 12.4), _g(23.0, 0.0, atrium_z), (0, 0, 0), mats["tile"], col)
    bpy_util.box("BranchBWallN", _s(18.4, 9.0, 0.38), _g(23.0, 4.5, -19.9), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("BranchBWallS", _s(18.4, 9.0, 0.38), _g(23.0, 4.5, -8.1), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("BranchBEnd", _s(0.38, 9.0, 12.4), _g(32.1, 4.5, atrium_z), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("BranchBGlow", _s(0.2, 2.2, 4.0), _g(31.85, 3.4, atrium_z), (0, 0, 0), mats["cool"], col)
    for i, z in enumerate((-10.4, -17.6)):
        bpy_util.box("BranchBShop_%d" % i, _s(5.0, 3.3, 0.06), _g(23.0, 1.75, z), (0, 0, 0), mats["glass_in"], col)
    bpy_util.empty("LIGHT_BRANCH_B", _g(23.0, 6.4, atrium_z), (0, 0, 0), col, 0.5)


def _instance_cars(col):
    files = [os.path.join(CARS, "hilux_parked.glb"), os.path.join(CARS, "vaz_parked.glb")]
    if os.path.isfile(AMAROK):
        files.append(AMAROK)
    slots = [
        (-8.5, 14.8, 0.04),
        (-8.3, 18.0, -0.02),
        (-8.6, 24.4, 0.05),
        (8.6, 15.2, 3.16),
        (8.4, 21.6, 3.12),
        (8.7, 31.0, 3.18),
        (16.6, 18.4, -1.52),
        (-16.7, 16.2, 0.08),
        (-16.9, 32.0, 0.04),
        (16.4, 36.0, -1.5),
        (-8.2, 40.4, 0.02),
        (28.0, 22.0, 1.2),
    ]
    usable = [p for p in files if os.path.isfile(p)]
    print("SDS_V4_1_CARS", [os.path.basename(p) for p in usable])
    if not usable:
        return 0
    templates = []
    for path in usable:
        imported = bpy_util.import_glb(path)
        joined = bpy_util.join_objects(imported, os.path.splitext(os.path.basename(path))[0])
        if joined is None:
            continue
        bpy_util.link(joined, col)
        templates.append(joined)
    keep = []
    n = 0
    for i, (x, z, yaw) in enumerate(slots):
        src = templates[i % len(templates)]
        obj = src if i < len(templates) else src.copy()
        if i >= len(templates):
            obj.data = src.data
            col.objects.link(obj)
        obj.location = _g(x, 0.0, z)
        obj.rotation_euler = (0.0, 0.0, float(yaw))
        obj.name = "Parked_%02d" % i
        n += 1
        keep.append(obj)
    import bpy

    for o in list(col.objects):
        if o.type == "MESH" and o not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    return n


def _background(col, mats):
    for i, x in enumerate((-48, -32, 34, 52)):
        h = 20.0 + (i % 3) * 6.0
        bpy_util.box("Tower_%d" % i, _s(9.0, h, 9.0), _g(x, h * 0.5, -30.0 - (i % 2) * 6.0), (0, 0, 0), mats["masonry"], col)
        for row in range(8):
            bpy_util.box("TwWin_%d_%d" % (i, row), _s(7.4, 0.7, 0.08), _g(x, 2.4 + row * 2.1, -30.0 - (i % 2) * 6.0 + 4.55), (0, 0, 0), mats["glow"] if row % 3 else mats["glass"], col)


def build(mats):
    park = bpy_util.collection("03_PARKING")
    facade_c = bpy_util.collection("02_FACADE")
    veh = bpy_util.collection("04_VEHICLES")
    veg = bpy_util.collection("05_VEGETATION")
    lights = bpy_util.collection("06_LIGHTS")
    bg = bpy_util.collection("07_BACKGROUND")
    marks = bpy_util.collection("08_MARKERS")
    interior = bpy_util.collection("09_INTERIOR")
    export = bpy_util.collection("EXPORT_GODOT")
    _parking(park, mats, veg, lights)
    _facade(facade_c, mats)
    _interior(interior, mats)
    n_cars = _instance_cars(veh)
    _background(bg, mats)
    bpy_util.empty("PLAYER_SPAWN_VISUAL", _g(0, 1.6, 28.5), (0, 0, 0), marks, 1.4)
    bpy_util.empty("SHOPPING_MAIN_ENTRANCE", _g(0, 1.5, 8.2), (0, 0, 0), marks)
    for src in (park, facade_c, veh, veg, lights, bg, marks, interior):
        for o in list(src.objects):
            if o.name not in export.objects:
                export.objects.link(o)
    return n_cars


def _write_authority():
    os.makedirs(os.path.dirname(AUTHORITY), exist_ok=True)
    base = "assets/reference/shopping del sol"
    open(AUTHORITY, "w", encoding="utf-8").write(
        "\n".join(
            [
                "HUMAN_REVIEW_REQUIRED",
                "CANDIDATE shopping_del_sol_zombies_environment_v4_1_candidate",
                "NOT_CANONICAL",
                "MAIN_ENTRANCE_NIGHT_ARCH\t%s/streetview/EXTERIOR/EXTERIOR_STATION_034_EXTERIOR_FRONT_SPHERE_NIGHT/angle_000.png" % base,
                "INTERIOR_WOOD_VAULT\t%s/photos/references/shopping-del-sol.jpg" % base,
                "INTERIOR_HALL_TILES\t%s/streetview/INTERIOR/INTERIOR_STATION_032_INTERIOR_HALL_1/angle_000.png" % base,
                "INTERIOR_ATRIUM\t%s/streetview/INTERIOR/INTERIOR_STATION_035_INTERIOR_HALL_2/angle_000.png" % base,
                "PARKING_APPROACH\t%s/streetview/EXTERIOR/EXTERIOR_STATION_007_ENTRADA_PARKING_1/contact_sheet.jpg" % base,
            ]
        )
        + "\n"
    )


def _write_decisions(n_cars):
    import json

    rows = [
        {"raw": "tripo_sds_facade_kit", "decision": "USE_CANDIDATE", "why": "primary SDS photo-reconstructions scaled into entrance/wings"},
        {"raw": "vaz/hilux/amarok", "decision": "USE_SHOPPING", "why": "Godot-proven or prior SDS parked cars; clustered not packed", "used": n_cars > 0},
        {"raw": "suggan", "decision": "REJECT_THIS_PASS", "why": "15 textures; keep out of hero GLB bulk"},
        {"raw": "sds_warning.glb", "decision": "REFERENCE_ONLY", "why": "generic warning mass; not SDS identity"},
        {"raw": "custom V4.1 atrium/vault/stairs/sign", "decision": "USE_CANDIDATE", "why": "manual completion of kit; HUMAN_REVIEW_REQUIRED"},
    ]
    os.makedirs(os.path.dirname(DECISIONS), exist_ok=True)
    open(DECISIONS, "w", encoding="utf-8").write(json.dumps(rows, indent=2))


def _sanitize_images():
    import bpy

    for img in list(bpy.data.images):
        size = getattr(img, "size", None)
        w = int(size[0]) if size else 0
        h = int(size[1]) if size else 0
        if w < 8 or h < 8:
            print("DROP_TINY_IMAGE", img.name, w, h)
            bpy.data.images.remove(img)
            continue
        if max(w, h) > 1024:
            img.scale(1024, 1024)
            try:
                img.pack()
            except Exception:
                pass


def main():
    bpy_util.reset_scene()
    os.makedirs(TEX_DIR, exist_ok=True)
    tile_path = os.path.join(TEX_DIR, "sds_interior_tile_v4_1_candidate.png")
    plaza_path = os.path.join(TEX_DIR, "sds_plaza_tile_v4_1_candidate.png")
    tile_img = _write_png_pixels(tile_path, 1024, _interior_tile)
    plaza_img = _write_png_pixels(plaza_path, 1024, _plaza_tile)
    try:
        tile_img.pack()
        plaza_img.pack()
    except Exception:
        pass
    mats = _mats(tile_img, plaza_img)
    n_cars = build(mats)
    _sanitize_images()
    os.makedirs(os.path.dirname(EXPORT), exist_ok=True)
    bpy_util.hide_all_mesh()
    export = bpy_util.collection("EXPORT_GODOT")
    for o in export.objects:
        if o.type in ("MESH", "EMPTY", "FONT"):
            o.hide_set(False)
            o.hide_render = False
            o.select_set(True)
    bpy_util.export_glb(EXPORT, selected=True)
    bpy_util.stats_report(EXPORT, {"asset": "shopping_del_sol_zombies_environment_v4_1_candidate", "state": "HUMAN_REVIEW_REQUIRED"})
    shutil.copy2(EXPORT, PROCESSED)
    import bpy

    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    _write_authority()
    _write_decisions(n_cars)
    print("SDS_ENV_V4_1_CANDIDATE_BUILT", EXPORT, "cars", n_cars, "HUMAN_REVIEW_REQUIRED")


if __name__ == "__main__":
    main()
