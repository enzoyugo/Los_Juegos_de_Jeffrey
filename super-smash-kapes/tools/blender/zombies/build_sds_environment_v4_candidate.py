"""Shopping del Sol V4 CANDIDATE — architectural entrance + atrium volume.

Does NOT overwrite V3 blend/GLB/processed. State: HUMAN_REVIEW_REQUIRED.

Authority (same frames as V3, not memory):
- EXTERIOR_STATION_034 night: layered WHITE ARCH, gold 8-point star, SHOPPING del SOL.
- EXTERIOR_STATION_007 / 001: parking aisles, islands, zebra, curved-neck lamps.
- INTERIOR_STATION_032 / 035 + photos/shopping-del-sol.jpg: tiles, hall, atrium.

V3 problem: block building + decorative arch.
V4 objective: deeper multi-shell entry, glass depth, main atrium, mezzanine, branches.

Gameplay anchors unchanged: spawn z=28.5, entrance z=8.2. No trimesh. No EEVEE.
No PSX/raw library GLBs merged into this hero file.
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

BLEND = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "blender", "shopping_del_sol_zombies_environment_v4_candidate.blend")
EXPORT = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "blender", "exports", "shopping_del_sol_zombies_environment_v4_candidate.glb")
PROCESSED = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "processed", "shopping_del_sol_zombies_environment_v4_candidate.glb")
TEX_DIR = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "processed", "textures")
CARS = os.path.join(ROOT, "assets", "environments", "shared", "urban", "processed", "vehicles")
PSX = os.path.join(ROOT, "assets", "environments", "shared", "urban", "processed", "industrial", "psx_industrial_pack.glb")
MARKET = os.path.join(ROOT, "assets", "environments", "shared", "urban", "processed", "street_props", "market_extracted_cluster.glb")
DECISIONS = os.path.join(ROOT, "docs", "generated", "sds_v4_candidate_asset_decisions.json")
AUTHORITY = os.path.join(ROOT, "docs", "generated", "sds_v4_candidate_authority_frames.txt")


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
    tile = size // 8
    tx = x % tile
    ty = y % tile
    dx = min(tx, tile - tx)
    dy = min(ty, tile - ty)
    n = ((x * 13 + y * 7) % 17) * 0.004
    if dx + dy < int(tile * 0.11):
        return (0.22 + n, 0.16, 0.12)
    if tx < 5 or ty < 5:
        return (0.42, 0.38, 0.32)
    return (0.78 + n, 0.72, 0.62)


def _plaza_tile(x, y, size):
    tile = size // 6
    tx = x % tile
    ty = y % tile
    n = ((x * 11 + y * 3) % 13) * 0.006
    if tx < 8 or ty < 8:
        return (0.55, 0.42, 0.28)
    return (0.72 + n, 0.62, 0.42)


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
        "asphalt": bpy_util.new_mat("SDS3_Asphalt", (0.07, 0.07, 0.08), rough=0.94),
        "line": bpy_util.new_mat("SDS3_Line", (0.9, 0.88, 0.78), rough=0.42),
        "curb": bpy_util.new_mat("SDS3_Curb", (0.52, 0.5, 0.44), rough=0.8),
        "soil": bpy_util.new_mat("SDS3_Soil", (0.24, 0.18, 0.1), rough=0.92),
        "grass": bpy_util.new_mat("SDS3_Grass", (0.16, 0.34, 0.12), rough=0.82),
        "masonry": bpy_util.new_mat("SDS3_Masonry", (0.82, 0.76, 0.64), rough=0.62),
        "cream": bpy_util.new_mat("SDS3_Cream", (0.9, 0.86, 0.74), rough=0.48),
        "terra": bpy_util.new_mat("SDS3_TerraBand", (0.48, 0.28, 0.16), rough=0.7),
        "dark": bpy_util.new_mat("SDS3_MetalDark", (0.12, 0.12, 0.14), metal=0.55, rough=0.36),
        "metal": bpy_util.new_mat("SDS3_Metal", (0.55, 0.56, 0.58), metal=0.6, rough=0.3),
        "glass": bpy_util.new_mat("SDS3_Glass", (0.55, 0.72, 0.78), rough=0.04, metal=0.08, alpha=0.34),
        "glass_in": bpy_util.new_mat("SDS3_GlassIn", (0.85, 0.88, 0.82), rough=0.08, metal=0.05, alpha=0.42, emit=0.35),
        "glow": bpy_util.new_mat("SDS3_WarmGlow", (1.0, 0.78, 0.42), emit=3.2, rough=0.22),
        "star": bpy_util.new_mat("SDS3_Star", (1.0, 0.82, 0.18), emit=6.0, rough=0.18),
        "sign": bpy_util.new_mat("SDS3_SignLit", (0.95, 0.95, 0.92), emit=2.8, rough=0.25),
        "trunk": bpy_util.new_mat("SDS3_Trunk", (0.32, 0.2, 0.1), rough=0.9),
        "leaf": bpy_util.new_mat("SDS3_Leaf", (0.12, 0.38, 0.14), rough=0.7),
        "fan": bpy_util.new_mat("SDS3_FanPalm", (0.18, 0.4, 0.16), rough=0.68),
        "rubber": bpy_util.new_mat("SDS3_Rubber", (0.04, 0.04, 0.04), rough=0.96),
        "lamp": bpy_util.new_mat("SDS3_Lamp", (1.0, 0.88, 0.55), emit=4.2),
        "wood": bpy_util.new_mat("SDS3_VaultWood", (0.62, 0.42, 0.22), rough=0.55),
        "brick": bpy_util.new_mat("SDS3_Brick", (0.55, 0.28, 0.2), rough=0.78),
        "shop": bpy_util.new_mat("SDS3_ShopDark", (0.08, 0.08, 0.09), metal=0.15, rough=0.45),
        "bench": bpy_util.new_mat("SDS3_Bench", (0.28, 0.18, 0.1), rough=0.7),
        "tile": _mat_tex("SDS3_InteriorTile", tile_img, rough=0.28, scale=(6.0, 6.0, 1.0)),
        "plaza": _mat_tex("SDS3_PlazaTile", plaza_img, rough=0.55, scale=(5.0, 5.0, 1.0)),
    }


def _arch_segments(col, mat, radius, thick, depth, z_face, y0, n=20, name="Arch"):
    for i in range(n):
        t0 = 0.12 + (math.pi - 0.24) * i / n
        t1 = 0.12 + (math.pi - 0.24) * (i + 1) / n
        t = 0.5 * (t0 + t1)
        x = math.cos(t) * radius
        y = math.sin(t) * radius + y0
        span = radius * abs(t1 - t0) + 0.12
        bpy_util.box(
            "%s_%02d" % (name, i),
            _s(thick, span, depth),
            _g(x, y, z_face),
            (0.0, -(t - math.pi * 0.5), 0.0),
            mat,
            col,
        )


def _star(col, mats, x, y, z):
    bpy_util.box("StarA", _s(1.55, 0.42, 0.12), _g(x, y, z), (0, 0, 0.0), mats["star"], col)
    bpy_util.box("StarB", _s(1.55, 0.42, 0.12), _g(x, y, z), (0, 0, math.pi * 0.25), mats["star"], col)
    bpy_util.box("StarC", _s(1.55, 0.42, 0.12), _g(x, y, z), (0, 0, math.pi * 0.5), mats["star"], col)
    bpy_util.box("StarD", _s(1.55, 0.42, 0.12), _g(x, y, z), (0, 0, math.pi * 0.75), mats["star"], col)
    bpy_util.box("StarCore", _s(0.38, 0.38, 0.14), _g(x, y, z + 0.06), (0, 0, 0), mats["glow"], col)


def _sign_text(col, mats):
    import bpy

    bpy.ops.object.text_add(location=_g(0.0, 7.35, 9.55))
    ob = bpy.context.active_object
    ob.name = "SignShoppingDelSol"
    ob.data.body = "SHOPPING del SOL"
    ob.data.align_x = "CENTER"
    ob.data.align_y = "CENTER"
    ob.data.size = 0.62
    ob.data.extrude = 0.05
    ob.rotation_euler = (math.pi * 0.5, 0.0, 0.0)
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.active_object
    ob.scale = (-1.0, 1.0, 1.0)
    bpy_util.apply_transforms(ob)
    ob = bpy.context.active_object
    if ob.data.materials:
        ob.data.materials[0] = mats["sign"]
    else:
        ob.data.materials.append(mats["sign"])
    bpy_util.link(ob, col)
    return ob


def _facade(col, mats):
    z_face = 9.55
    _arch_segments(col, mats["cream"], 6.55, 0.52, 1.55, z_face, 0.12, 24, "ArchOuter")
    _arch_segments(col, mats["cream"], 6.05, 0.40, 1.25, z_face + 0.55, 0.18, 22, "ArchMid")
    _arch_segments(col, mats["cream"], 5.62, 0.30, 1.05, z_face + 1.05, 0.22, 20, "ArchInner")
    _arch_segments(col, mats["cream"], 5.28, 0.22, 0.85, z_face + 1.55, 0.28, 18, "ArchReveal")
    for i in range(14):
        t0 = 0.18 + (math.pi - 0.36) * i / 14
        t1 = 0.18 + (math.pi - 0.36) * (i + 1) / 14
        t = 0.5 * (t0 + t1)
        r = 5.05
        x = math.cos(t) * r
        y = math.sin(t) * r * 0.92 + 0.35
        span = r * abs(t1 - t0) + 0.2
        bpy_util.box("ArchGlass_%02d" % i, _s(0.08, span * 1.15, 0.1), _g(x, y, 8.95), (0.0, -(t - math.pi * 0.5), 0.0), mats["glass_in"], col)
    bpy_util.box("CurtainFill", _s(9.2, 5.2, 0.06), _g(0, 2.75, 8.78), (0, 0, 0), mats["glass_in"], col)
    bpy_util.box("CurtainDepth", _s(8.4, 4.8, 0.06), _g(0, 2.85, 7.55), (0, 0, 0), mats["glass"], col)
    bpy_util.box("VestibuleFloor", _s(8.6, 0.08, 2.4), _g(0, 0.02, 7.55), (0, 0, 0), mats["cream"], col)
    bpy_util.box("VestibuleCeil", _s(8.8, 0.18, 2.6), _g(0, 5.35, 7.55), (0, 0, 0), mats["cream"], col)
    for i, x in enumerate((-3.2, -1.6, 0.0, 1.6, 3.2)):
        bpy_util.box("Mullion_%d" % i, _s(0.08, 5.2, 0.12), _g(x, 2.7, 8.82), (0, 0, 0), mats["metal"], col)
    bpy_util.box("DoorL", _s(1.55, 2.85, 0.1), _g(-0.85, 1.45, 6.95), (0, 0, 0), mats["glass"], col)
    bpy_util.box("DoorR", _s(1.55, 2.85, 0.1), _g(0.85, 1.45, 6.95), (0, 0, 0), mats["glass"], col)
    bpy_util.box("DoorFrame", _s(3.4, 3.05, 0.16), _g(0, 1.55, 6.88), (0, 0, 0), mats["metal"], col)
    bpy_util.box("DoorBar", _s(2.9, 0.07, 0.07), _g(0, 1.5, 7.05), (0, 0, 0), mats["metal"], col)
    bpy_util.box("PortalL", _s(1.35, 8.8, 3.4), _g(-5.7, 4.4, 7.7), (0, 0, 0), mats["cream"], col)
    bpy_util.box("PortalR", _s(1.35, 8.8, 3.4), _g(5.7, 4.4, 7.7), (0, 0, 0), mats["cream"], col)
    bpy_util.box("Canopy", _s(13.2, 0.28, 4.4), _g(0, 5.62, 9.6), (0, 0, 0), mats["cream"], col)
    bpy_util.box("CanopyEdge", _s(12.5, 0.16, 0.22), _g(0, 5.42, 11.7), (0, 0, 0), mats["metal"], col)
    _star(col, mats, 0.0, 9.85, 9.85)
    _sign_text(col, mats)
    bpy_util.box("SignRail", _s(8.6, 0.08, 0.12), _g(0, 6.95, 9.5), (0, 0, 0), mats["dark"], col)
    for side in (-1.0, 1.0):
        bpy_util.box("WingMass_%d" % int(side), _s(18.8, 8.6, 3.4), _g(side * 16.2, 4.3, 8.0), (0, 0, 0), mats["masonry"], col)
        bpy_util.box("WingParapet_%d" % int(side), _s(19.0, 0.45, 3.7), _g(side * 16.2, 8.75, 8.0), (0, 0, 0), mats["cream"], col)
        for i in range(5):
            x = side * (8.4 + i * 3.85)
            bpy_util.box("Pier_%d_%d" % (int(side), i), _s(0.72, 8.4, 0.85), _g(x, 4.2, 9.55), (0, 0, 0), mats["cream"], col)
            bpy_util.box("PierLight_%d_%d" % (int(side), i), _s(0.28, 0.12, 0.28), _g(x, 0.18, 9.85), (0, 0, 0), mats["glow"], col)
            bpy_util.empty("LIGHT_PIER_%d_%d" % (int(side), i), _g(x, 1.4, 10.1), (0, 0, 0), col, 0.35)
            bpy_util.box("ShopGlass_%d_%d" % (int(side), i), _s(2.55, 3.15, 0.08), _g(x + side * 1.85, 1.7, 9.62), (0, 0, 0), mats["glass"], col)
            bpy_util.box("ShopUpper_%d_%d" % (int(side), i), _s(2.55, 2.35, 0.07), _g(x + side * 1.85, 5.35, 9.58), (0, 0, 0), mats["glass"], col)
            bpy_util.box("ShopLintel_%d_%d" % (int(side), i), _s(2.7, 0.22, 0.22), _g(x + side * 1.85, 3.4, 9.7), (0, 0, 0), mats["dark"], col)
    bpy_util.empty("LIGHT_ENTRANCE_001", _g(0, 4.4, 10.2), (0, 0, 0), col, 1.0)
    bpy_util.empty("LIGHT_ENTRANCE_002", _g(-4.2, 6.2, 10.4), (0, 0, 0), col, 0.55)
    bpy_util.empty("LIGHT_ENTRANCE_003", _g(4.2, 6.2, 10.4), (0, 0, 0), col, 0.55)
    bpy_util.empty("LIGHT_STAR", _g(0, 9.5, 9.4), (0, 0, 0), col, 0.4)


def _zigzag_plaza(col, mats):
    walk = bpy_util.box("PlazaWalk", _s(9.4, 0.06, 10.5), _g(0, 0.03, 13.4), (0, 0, 0), mats["plaza"], col)
    _ensure_uv(walk, 2.0)
    for i in range(12):
        z = 9.2 + i * 0.82
        step = 0.55 if i % 2 == 0 else 0.0
        bpy_util.box("ZigL_%d" % i, _s(0.85, 0.05, 0.78), _g(-4.35 - step, 0.06, z), (0, 0, 0), mats["terra"], col)
        bpy_util.box("ZigR_%d" % i, _s(0.85, 0.05, 0.78), _g(4.35 + step, 0.06, z), (0, 0, 0), mats["terra"], col)
    for i in range(7):
        bpy_util.box("Zebra_%d" % i, _s(0.42, 0.04, 1.85), _g(-2.5 + i * 0.85, 0.07, 9.15), (0, 0, 0), mats["line"], col)
    bpy_util.box("Threshold", _s(8.8, 0.05, 1.4), _g(0, 0.04, 8.55), (0, 0, 0), mats["cream"], col)


def _palm(col, mats, x, z, h, name):
    bpy_util.cylinder("%s_Trunk" % name, 0.16, h, _g(x, h * 0.5, z), (0, 0, 0), mats["trunk"], col, 14)
    bpy_util.cylinder("%s_Neck" % name, 0.2, 0.35, _g(x, h - 0.05, z), (0, 0, 0), mats["trunk"], col, 10)
    n = 9
    for i in range(n):
        ang = i * (math.tau / n)
        bpy_util.box(
            "%s_Frond_%d" % (name, i),
            _s(0.16, 0.03, 2.9),
            _g(x + math.sin(ang) * 1.05, h + 0.05, z + math.cos(ang) * 1.05),
            (0.55, 0.08, ang),
            mats["leaf"],
            col,
        )
        bpy_util.box(
            "%s_FrondB_%d" % (name, i),
            _s(0.12, 0.025, 2.2),
            _g(x + math.sin(ang + 0.2) * 0.7, h + 0.35, z + math.cos(ang + 0.2) * 0.7),
            (0.28, -0.05, ang + 0.15),
            mats["leaf"],
            col,
        )
    bpy_util.ico("%s_Heart" % name, 0.32, _g(x, h + 0.12, z), mats["leaf"], col, 1)


def _fan_palm(col, mats, x, z, name):
    bpy_util.cylinder("%s_St" % name, 0.12, 1.4, _g(x, 0.7, z), (0, 0, 0), mats["trunk"], col, 8)
    for i in range(7):
        ang = i * (math.tau / 7)
        bpy_util.box("%s_F_%d" % (name, i), _s(0.55, 0.04, 1.1), _g(x + math.sin(ang) * 0.35, 1.55, z + math.cos(ang) * 0.35), (0.7, 0, ang), mats["fan"], col)


def _lamp(col, mats, x, z, i):
    bpy_util.cylinder("LampPole_%02d" % i, 0.08, 7.4, _g(x, 3.7, z), (0, 0, 0), mats["metal"], col, 10)
    bpy_util.cylinder("LampCurve_%02d" % i, 0.06, 1.5, _g(x, 7.55, z + 0.45), (0.85, 0, 0), mats["metal"], col, 8)
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
        for i in range(8):
            z = 14.2 + i * 3.15
            bpy_util.box("StallB_%d_%d" % (int(side), i), _s(4.6, 0.02, 0.07), _g(side * 16.8, 0.025, z), (0, 0, 0), mats["line"], col)
    _zigzag_plaza(col, mats)
    for i, z in enumerate((17.0, 25.0, 33.0, 41.0)):
        for side, sx in ((-1.0, "L"), (1.0, "R")):
            bpy_util.box("Island%s_%d" % (sx, i), _s(1.65, 0.24, 5.4), _g(side * 5.7, 0.12, z), (0, 0, 0), mats["curb"], col)
            bpy_util.box("Soil%s_%d" % (sx, i), _s(1.3, 0.16, 5.0), _g(side * 5.7, 0.22, z), (0, 0, 0), mats["soil"], col)
            bpy_util.box("Grass%s_%d" % (sx, i), _s(1.1, 0.08, 4.7), _g(side * 5.7, 0.3, z), (0, 0, 0), mats["grass"], col)
            _palm(veg, mats, side * 5.7, z, 6.1 + i * 0.12, "Palm%s_%d" % (sx, i))
    for i, x in enumerate((-3.6, -1.8, 1.8, 3.6)):
        bpy_util.cylinder("Bollard_%d" % i, 0.09, 0.72, _g(x, 0.36, 11.2), (0, 0, 0), mats["metal"], col, 8)
    bpy_util.box("BenchL", _s(1.9, 0.42, 0.5), _g(-3.4, 0.32, 12.4), (0, 0, 0), mats["bench"], col)
    bpy_util.box("BenchR", _s(1.9, 0.42, 0.5), _g(3.4, 0.32, 12.4), (0, 0, 0), mats["bench"], col)
    _fan_palm(veg, mats, -6.8, 10.6, "FanL")
    _fan_palm(veg, mats, 6.8, 10.6, "FanR")
    for i, (x, z) in enumerate([(-5.7, 17.0), (5.7, 17.0), (-5.7, 33.0), (5.7, 33.0), (-22.0, 24.0), (22.0, 24.0), (0.0, 44.0)], start=1):
        _lamp(lights, mats, x, z, i)


def _interior(col, mats):
    ## ENTRY HALL (z ~ 6 → -2) then MAIN ATRIUM then BRANCH A/B + MEZZANINE.
    floor = bpy_util.box("HallFloor", _s(19.6, 0.08, 16.0), _g(0, 0.0, 2.0), (0, 0, 0), mats["tile"], col)
    _ensure_uv(floor, 2.2)
    bpy_util.box("HallWallL", _s(0.45, 9.6, 16.0), _g(-9.9, 4.8, 2.0), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("HallWallR", _s(0.45, 9.6, 16.0), _g(9.9, 4.8, 2.0), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("BrickBandL", _s(0.2, 3.2, 15.6), _g(-9.72, 7.4, 2.0), (0, 0, 0), mats["brick"], col)
    bpy_util.box("BrickBandR", _s(0.2, 3.2, 15.6), _g(9.72, 7.4, 2.0), (0, 0, 0), mats["brick"], col)
    for i, z in enumerate((5.2, 1.4, -2.2)):
        _arch_segments(col, mats["wood"], 9.4, 0.22, 0.55, z, 2.4, 16, "VaultRib_%d" % i)
        bpy_util.box("ShopL_%d" % i, _s(5.8, 3.6, 0.1), _g(-6.8, 1.9, z - 1.6), (0, 0, 0), mats["glass"], col)
        bpy_util.box("ShopFrameL_%d" % i, _s(6.1, 3.85, 0.18), _g(-6.8, 1.95, z - 1.52), (0, 0, 0), mats["shop"], col)
        bpy_util.box("ShopR_%d" % i, _s(5.8, 3.6, 0.1), _g(6.8, 1.9, z - 1.6), (0, 0, 0), mats["glass"], col)
        bpy_util.box("ShopFrameR_%d" % i, _s(6.1, 3.85, 0.18), _g(6.8, 1.95, z - 1.52), (0, 0, 0), mats["shop"], col)
        bpy_util.box("AwningL_%d" % i, _s(5.4, 0.08, 0.85), _g(-6.8, 3.85, z - 1.1), (0, 0, 0), mats["terra"], col)
        bpy_util.box("ShopSignL_%d" % i, _s(2.4, 0.35, 0.08), _g(-6.8, 3.55, z - 1.05), (0, 0, 0), mats["sign"], col)
        bpy_util.cylinder("ColL_%d" % i, 0.42, 8.8, _g(-4.6, 4.4, z), (0, 0, 0), mats["cream"], col, 14)
        bpy_util.cylinder("ColR_%d" % i, 0.42, 8.8, _g(4.6, 4.4, z), (0, 0, 0), mats["cream"], col, 14)
        bpy_util.box("SconceL_%d" % i, _s(0.22, 0.22, 0.12), _g(-4.6, 5.6, z + 0.5), (0, 0, 0), mats["glow"], col)
        bpy_util.empty("LIGHT_INTERIOR_%03d" % (i + 1), _g(0, 7.4, z), (0, 0, 0), col, 0.55)
    bpy_util.box("VaultCapHall", _s(18.8, 0.18, 16.2), _g(0, 11.35, 2.0), (0, 0, 0), mats["wood"], col)
    bpy_util.box("KioskBody", _s(2.8, 2.4, 2.8), _g(0, 1.2, 1.2), (0, 0, 0), mats["shop"], col)
    bpy_util.box("KioskTop", _s(3.05, 0.12, 3.05), _g(0, 2.45, 1.2), (0, 0, 0), mats["sign"], col)
    bpy_util.box("KioskGlass", _s(2.5, 1.4, 0.06), _g(0, 1.3, 2.58), (0, 0, 0), mats["glass"], col)
    bpy_util.box("HallBench", _s(2.2, 0.42, 0.55), _g(-2.6, 0.32, 3.4), (0, 0, 0), mats["bench"], col)
    bpy_util.box("Planter", _s(1.2, 0.55, 1.2), _g(3.0, 0.28, 3.2), (0, 0, 0), mats["curb"], col)
    bpy_util.ico("HallShrub", 0.62, _g(3.0, 1.0, 3.2), mats["fan"], col, 1)

    atrium_z = -14.0
    atrium = bpy_util.box("AtriumFloor", _s(28.0, 0.08, 22.0), _g(0, 0.0, atrium_z), (0, 0, 0), mats["tile"], col)
    _ensure_uv(atrium, 2.4)
    bpy_util.box("AtriumWell", _s(10.4, 0.04, 10.4), _g(0, 0.05, atrium_z), (0, 0, 0), mats["plaza"], col)
    bpy_util.box("AtriumRing", _s(12.2, 0.22, 12.2), _g(0, 0.14, atrium_z), (0, 0, 0), mats["cream"], col)
    bpy_util.box("AtriumWallN", _s(28.2, 14.4, 0.45), _g(0, 7.2, -25.0), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("AtriumWallS", _s(4.2, 14.4, 0.45), _g(-12.0, 7.2, -3.2), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("AtriumWallS2", _s(4.2, 14.4, 0.45), _g(12.0, 7.2, -3.2), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("AtriumOpenL", _s(0.45, 14.4, 22.0), _g(-14.0, 7.2, atrium_z), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("AtriumOpenR", _s(0.45, 14.4, 22.0), _g(14.0, 7.2, atrium_z), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("AtriumBrickL", _s(0.18, 4.2, 21.6), _g(-13.82, 10.8, atrium_z), (0, 0, 0), mats["brick"], col)
    bpy_util.box("AtriumBrickR", _s(0.18, 4.2, 21.6), _g(13.82, 10.8, atrium_z), (0, 0, 0), mats["brick"], col)
    bpy_util.box("AtriumSkylight", _s(11.0, 0.08, 11.0), _g(0, 14.6, atrium_z), (0, 0, 0), mats["glass_in"], col)
    bpy_util.box("AtriumRoofRing", _s(28.0, 0.28, 22.0), _g(0, 14.4, atrium_z), (0, 0, 0), mats["wood"], col)
    for i in range(8):
        ang = i * (math.tau / 8.0)
        bpy_util.cylinder("AtriumCol_%d" % i, 0.38, 13.6, _g(math.cos(ang) * 5.6, 6.8, atrium_z + math.sin(ang) * 5.6), (0, 0, 0), mats["cream"], col, 12)
    bpy_util.empty("LIGHT_ATRIUM", _g(0, 11.5, atrium_z), (0, 0, 0), col, 1.2)
    bpy_util.empty("LIGHT_ATRIUM_WARM", _g(0, 4.2, atrium_z + 3.0), (0, 0, 0), col, 0.7)

    bpy_util.box("MezzFloor", _s(22.0, 0.18, 4.6), _g(0, 6.2, -22.4), (0, 0, 0), mats["wood"], col)
    bpy_util.box("MezzRailF", _s(22.0, 1.05, 0.08), _g(0, 6.85, -20.15), (0, 0, 0), mats["metal"], col)
    bpy_util.box("MezzRailL", _s(0.08, 1.05, 4.4), _g(-10.95, 6.85, -22.4), (0, 0, 0), mats["metal"], col)
    bpy_util.box("MezzRailR", _s(0.08, 1.05, 4.4), _g(10.95, 6.85, -22.4), (0, 0, 0), mats["metal"], col)
    bpy_util.box("MezzShopA", _s(6.4, 2.8, 0.08), _g(-6.4, 7.8, -24.55), (0, 0, 0), mats["glass"], col)
    bpy_util.box("MezzShopB", _s(6.4, 2.8, 0.08), _g(6.4, 7.8, -24.55), (0, 0, 0), mats["glass"], col)
    bpy_util.empty("LIGHT_MEZZANINE", _g(0, 8.4, -22.0), (0, 0, 0), col, 0.55)
    bpy_util.empty("SDS_BEAUTY_MEZZANINE", _g(0, 7.6, -21.2), (0, math.pi, 0), col, 0.8)

    bpy_util.box("BranchAFloor", _s(18.0, 0.08, 12.0), _g(-22.0, 0.0, atrium_z), (0, 0, 0), mats["tile"], col)
    bpy_util.box("BranchAWallN", _s(18.0, 8.4, 0.4), _g(-22.0, 4.2, -19.8), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("BranchAWallS", _s(18.0, 8.4, 0.4), _g(-22.0, 4.2, -8.2), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("BranchAEnd", _s(0.4, 8.4, 12.0), _g(-31.0, 4.2, atrium_z), (0, 0, 0), mats["masonry"], col)
    for i, z in enumerate((-10.5, -17.5)):
        bpy_util.box("BranchAShop_%d" % i, _s(4.8, 3.2, 0.08), _g(-22.0, 1.7, z), (0, 0, 0), mats["glass"], col)
        bpy_util.box("BranchAFrame_%d" % i, _s(5.1, 3.45, 0.16), _g(-22.0, 1.75, z + 0.08), (0, 0, 0), mats["shop"], col)
    bpy_util.empty("LIGHT_BRANCH_A", _g(-22.0, 6.2, atrium_z), (0, 0, 0), col, 0.5)

    bpy_util.box("BranchBFloor", _s(18.0, 0.08, 12.0), _g(22.0, 0.0, atrium_z), (0, 0, 0), mats["tile"], col)
    bpy_util.box("BranchBWallN", _s(18.0, 8.4, 0.4), _g(22.0, 4.2, -19.8), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("BranchBWallS", _s(18.0, 8.4, 0.4), _g(22.0, 4.2, -8.2), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("BranchBEnd", _s(0.4, 8.4, 12.0), _g(31.0, 4.2, atrium_z), (0, 0, 0), mats["masonry"], col)
    for i, z in enumerate((-10.5, -17.5)):
        bpy_util.box("BranchBShop_%d" % i, _s(4.8, 3.2, 0.08), _g(22.0, 1.7, z), (0, 0, 0), mats["glass"], col)
        bpy_util.box("BranchBFrame_%d" % i, _s(5.1, 3.45, 0.16), _g(22.0, 1.75, z + 0.08), (0, 0, 0), mats["shop"], col)
    bpy_util.box("GalleryHint", _s(5.2, 3.4, 0.12), _g(22.0, 1.8, -19.55), (0, 0, 0), mats["dark"], col)
    bpy_util.empty("LIGHT_BRANCH_B", _g(22.0, 6.2, atrium_z), (0, 0, 0), col, 0.5)
    bpy_util.empty("SDS_BEAUTY_ATRIUM", _g(0, 1.7, atrium_z + 6.0), (0, math.pi, 0), col, 0.8)
    bpy_util.empty("SDS_BEAUTY_BRANCH", _g(-22.0, 1.7, atrium_z), (0, 1.57, 0), col, 0.8)


def _instance_cars(col):
    files = [
        os.path.join(CARS, "hilux_parked.glb"),
        os.path.join(CARS, "vaz_parked.glb"),
    ]
    slots = [
        (-8.5, 14.8, 0.04),
        (-8.3, 18.0, -0.02),
        (-8.6, 24.4, 0.05),
        (-8.4, 27.6, 0.01),
        (-8.5, 34.0, 0.03),
        (8.6, 15.2, 3.16),
        (8.4, 21.6, 3.12),
        (8.7, 24.8, 3.18),
        (8.5, 31.2, 3.10),
        (16.6, 18.4, -1.52),
        (16.8, 27.2, -1.55),
        (-16.7, 16.2, 0.08),
        (-16.9, 32.0, 0.04),
        (8.3, 37.4, 3.14),
        (-8.2, 40.4, 0.02),
        (16.4, 36.0, -1.5),
    ]
    usable = [p for p in files if os.path.isfile(p)]
    print("SDS_V4_CANDIDATE_CARS", [os.path.basename(p) for p in usable])
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
        if i < len(templates):
            obj = src
        else:
            obj = src.copy()
            obj.data = src.data
            col.objects.link(obj)
        obj.location = _g(x, 0.0, z)
        obj.rotation_euler = (0.0, 0.0, float(yaw))
        obj.name = "Parked_%02d" % i
        n += 1
        keep.append(obj)
    for o in list(col.objects):
        if o.type == "MESH" and o not in keep:
            import bpy
            bpy.data.objects.remove(o, do_unlink=True)
    return n


def _maybe_psx(col):
    ## Not merged into the hero GLB: prior packs embed 1x1 dummy images that break D3D12 import.
    if not os.path.isfile(PSX):
        return "SKIP missing"
    return "SKIP not merged into hero GLB (1x1/dummy tex risk); pack remains processed for optional later use"


def _background(col, mats):
    for i, x in enumerate((-48, -32, 34, 52, -62, 66)):
        h = 22.0 + (i % 4) * 7.0
        bpy_util.box("Tower_%d" % i, _s(10.0, h, 10.0), _g(x, h * 0.5, -28.0 - (i % 3) * 8.0), (0, 0, 0), mats["masonry"] if i % 2 == 0 else mats["cream"], col)
        for row in range(10):
            bpy_util.box("TwWin_%d_%d" % (i, row), _s(8.2, 0.85, 0.08), _g(x, 2.2 + row * 2.0, -28.0 - (i % 3) * 8.0 + 5.05), (0, 0, 0), mats["glow"] if row % 2 == 0 else mats["glass"], col)


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
    psx_note = _maybe_psx(park)
    print("SDS_V4_CANDIDATE_PSX", psx_note)
    if n_cars < 8:
        paints = [
            bpy_util.new_mat("SDS3_PaintW", (0.86, 0.86, 0.84), metal=0.25, rough=0.35),
            bpy_util.new_mat("SDS3_PaintS", (0.55, 0.56, 0.58), metal=0.4, rough=0.32),
            bpy_util.new_mat("SDS3_PaintK", (0.08, 0.08, 0.09), metal=0.3, rough=0.4),
        ]
        for i, (x, z, yaw) in enumerate([(-28.0, 22.0, 0.2), (28.2, 21.0, 3.2), (0.0, 48.0, 1.57)]):
            bpy_util.box("FbBody_%d" % i, _s(1.85, 0.55, 4.2), _g(x, 0.45, z), (0, 0, yaw), paints[i % 3], veh)
    _background(bg, mats)
    bpy_util.empty("PLAYER_SPAWN_VISUAL", _g(0, 1.6, 28.5), (0, 0, 0), marks, 1.4)
    bpy_util.empty("SHOPPING_MAIN_ENTRANCE", _g(0, 1.5, 8.2), (0, 0, 0), marks)
    bpy_util.empty("INTERIOR_THRESHOLD", _g(0, 1.2, 7.2), (0, 0, 0), marks)
    bpy_util.empty("SDS_BEAUTY_SPAWN", _g(0, 1.65, 28.5), (0, math.pi, 0), marks, 0.8)
    bpy_util.empty("SDS_BEAUTY_ENTRANCE", _g(0, 2.2, 16.0), (0, math.pi, 0), marks, 0.8)
    bpy_util.empty("SDS_BEAUTY_PARKING", _g(-18.0, 8.0, 36.0), (0, 0.7, 0), marks, 0.8)
    bpy_util.empty("SDS_BEAUTY_SIDE", _g(-22.0, 3.0, 10.0), (0, 1.2, 0), marks, 0.8)
    bpy_util.empty("SDS_BEAUTY_INTERIOR", _g(0, 1.7, 2.0), (0, math.pi, 0), marks, 0.8)
    for src in (park, facade_c, veh, veg, lights, bg, marks, interior):
        for o in list(src.objects):
            if o.name not in export.objects:
                export.objects.link(o)
    return n_cars, psx_note


def _write_authority():
    os.makedirs(os.path.dirname(AUTHORITY), exist_ok=True)
    base = "assets/reference/shopping del sol"
    lines = [
        "HUMAN_REVIEW_REQUIRED",
        "CANDIDATE shopping_del_sol_zombies_environment_v4_candidate",
        "NOT_CANONICAL",
        "MAIN_ENTRANCE_NIGHT_ARCH\t%s/streetview/EXTERIOR/EXTERIOR_STATION_034_EXTERIOR_FRONT_SPHERE_NIGHT/angle_000.png" % base,
        "MAIN_FACADE_STREET\t%s/streetview/EXTERIOR/EXTERIOR_STATION_016_OUTSIDE_FRONT_1/contact_sheet.jpg" % base,
        "PARKING_APPROACH\t%s/streetview/EXTERIOR/EXTERIOR_STATION_007_ENTRADA_PARKING_1/contact_sheet.jpg" % base,
        "PARKING_CENTER\t%s/streetview/EXTERIOR/EXTERIOR_STATION_001_ESTACIONAMIENTO_MEDIO_01/contact_sheet.jpg" % base,
        "INTERIOR_HALL_TILES\t%s/streetview/INTERIOR/INTERIOR_STATION_032_INTERIOR_HALL_1/angle_000.png" % base,
        "INTERIOR_ATRIUM\t%s/streetview/INTERIOR/INTERIOR_STATION_035_INTERIOR_HALL_2/angle_000.png" % base,
        "INTERIOR_WOOD_VAULT\t%s/photos/references/shopping-del-sol.jpg" % base,
        "ZIGZAG_PLAZA\t%s/streetview/EXTERIOR/EXTERIOR_STATION_034_EXTERIOR_FRONT_SPHERE_NIGHT/angle_000.png" % base,
    ]
    open(AUTHORITY, "w", encoding="utf-8").write("\n".join(lines) + "\n")


def _write_decisions(n_cars, psx_note):
    import json

    rows = [
        {"raw": "vaz_2104_-_raw_scan.glb", "decision": "USE_SHOPPING", "why": "real wagon silhouette in parking", "used": n_cars > 0},
        {"raw": "toyota-hilux-revo-prerunner-2021", "decision": "USE_SHOPPING", "why": "Paraguay-typical pickup in lot", "used": n_cars > 0},
        {"raw": "wrecked-car", "decision": "REJECT_THIS_PASS", "why": "26MB unique textures; wrecks fight 'mall open at night' identity. Atmosphere later, not in hero lot."},
        {"raw": "psx_industrial_pack.glb", "decision": "REJECT_THIS_PASS", "why": "processed pack exists but merging it into the hero GLB introduced a 1x1 dummy texture that broke D3D12 import", "note": psx_note},
        {"raw": "cement_bags_low-poly.glb", "decision": "REJECT_THIS_PASS", "why": "service clutter; would dilute facade-first composition"},
        {"raw": "market-al-danube", "decision": "REJECT_THIS_PASS", "why": "child extract is mixed vegetation/branding; palms are custom to match SDS silhouette instead of dumping H&M-era props"},
        {"raw": "ice_scream_3_shopping_center_map.glb", "decision": "REJECT", "why": "unrelated branded mall"},
        {"raw": "portal-gate-sci-fi", "decision": "REJECT", "why": "sci-fi, not SDS"},
        {"raw": "custom Blender V4 candidate", "decision": "USE_CANDIDATE", "why": "deeper vestibule, atrium well, mezzanine, lateral branches — HUMAN_REVIEW_REQUIRED, not V3 replacement"},
    ]
    os.makedirs(os.path.dirname(DECISIONS), exist_ok=True)
    open(DECISIONS, "w", encoding="utf-8").write(json.dumps(rows, indent=2))


def _sanitize_images():
    """Drop D3D12-illegal 1x1 embeds; cap unique maps at 1024."""
    import bpy

    for img in list(bpy.data.images):
        size = getattr(img, "size", None)
        w = int(size[0]) if size else 0
        h = int(size[1]) if size else 0
        name = img.name
        if w < 8 or h < 8:
            print("DROP_TINY_IMAGE", name, w, h)
            bpy.data.images.remove(img)
            continue
        if max(w, h) > 1024:
            img.scale(1024, 1024)
            try:
                img.pack()
            except Exception:
                pass
            print("CAP_TEX", name, w, h, "->1024")


def main():
    bpy_util.reset_scene()
    os.makedirs(TEX_DIR, exist_ok=True)
    tile_path = os.path.join(TEX_DIR, "sds_interior_tile_v4_candidate.png")
    plaza_path = os.path.join(TEX_DIR, "sds_plaza_tile_v4_candidate.png")
    tile_img = _write_png_pixels(tile_path, 1024, _interior_tile)
    plaza_img = _write_png_pixels(plaza_path, 1024, _plaza_tile)
    try:
        tile_img.pack()
        plaza_img.pack()
    except Exception:
        pass
    mats = _mats(tile_img, plaza_img)
    n_cars, psx_note = build(mats)
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
    bpy_util.stats_report(EXPORT, {"asset": "shopping_del_sol_zombies_environment_v4_candidate", "state": "HUMAN_REVIEW_REQUIRED"})
    shutil.copy2(EXPORT, PROCESSED)
    import bpy

    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    _write_authority()
    _write_decisions(n_cars, psx_note)
    print("SDS_ENV_V4_CANDIDATE_BUILT", EXPORT, "cars", n_cars, "HUMAN_REVIEW_REQUIRED")


if __name__ == "__main__":
    main()
