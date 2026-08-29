"""Shopping del Sol V4.3 CANDIDATE — reference-locked Tripo reconstruction.

Does NOT overwrite V3, V4, V4.1, or V4.2. HUMAN_REVIEW_REQUIRED. Not SDS_V4_3_CANONICAL.

Primary exterior authority:
E:\\JeffreyAIResearch\\references\\shopping_del_sol\\facade\\sds_facade_target_v1.png

Raw GLBs are immutable. Facade identity comes from extracted Tripo components.
Manual meshes are joins/backing/grounding only.
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

BLEND = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "blender", "shopping_del_sol_zombies_environment_v4_3_candidate.blend")
EXPORT = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "blender", "exports", "shopping_del_sol_zombies_environment_v4_3_candidate.glb")
PROCESSED = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "processed", "shopping_del_sol_zombies_environment_v4_3_candidate.glb")
TEX_DIR = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "processed", "textures")
CARS = os.path.join(ROOT, "assets", "environments", "shared", "urban", "processed", "vehicles")
KIT = r"E:\JeffreyAIResearch\asset-library\processed\environment\shopping_del_sol\facade\v4_3_extracts"
DECISIONS = os.path.join(ROOT, "docs", "generated", "sds_v4_3_candidate_asset_decisions.json")
AUTHORITY = os.path.join(ROOT, "docs", "generated", "sds_v4_3_candidate_authority_frames.txt")
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
    tx, ty = x % tile, y % tile
    cx, cy = abs(tx - tile * 0.5), abs(ty - tile * 0.5)
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
    tx, ty = x % tile, y % tile
    n = ((x * 11 + y * 3) % 13) * 0.006
    if (tx < 10) or (ty < 10):
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
        "asphalt": bpy_util.new_mat("SDS43_Asphalt", (0.055, 0.055, 0.06), rough=0.92),
        "line": bpy_util.new_mat("SDS43_Line", (0.9, 0.88, 0.78), rough=0.42),
        "curb": bpy_util.new_mat("SDS43_Curb", (0.48, 0.46, 0.4), rough=0.82),
        "soil": bpy_util.new_mat("SDS43_Soil", (0.22, 0.16, 0.09), rough=0.93),
        "grass": bpy_util.new_mat("SDS43_Grass", (0.1, 0.28, 0.09), rough=0.84),
        "masonry": bpy_util.new_mat("SDS43_Masonry", (0.78, 0.72, 0.6), rough=0.64),
        "cream": bpy_util.new_mat("SDS43_Cream", (0.93, 0.9, 0.8), rough=0.4),
        "terra": bpy_util.new_mat("SDS43_Terra", (0.48, 0.28, 0.16), rough=0.72),
        "dark": bpy_util.new_mat("SDS43_MetalDark", (0.08, 0.08, 0.1), metal=0.62, rough=0.32),
        "metal": bpy_util.new_mat("SDS43_Metal", (0.18, 0.18, 0.2), metal=0.7, rough=0.28),
        "glass": bpy_util.new_mat("SDS43_Glass", (0.12, 0.18, 0.22), rough=0.06, metal=0.18, alpha=0.28),
        "glass_in": bpy_util.new_mat("SDS43_GlassIn", (0.92, 0.72, 0.42), rough=0.12, metal=0.02, alpha=0.55, emit=0.22),
        "glow": bpy_util.new_mat("SDS43_WarmGlow", (1.0, 0.68, 0.32), emit=0.42, rough=0.28),
        "star": bpy_util.new_mat("SDS43_Sun", (1.0, 0.78, 0.14), emit=2.6, rough=0.18),
        "sign": bpy_util.new_mat("SDS43_SignLit", (0.98, 0.94, 0.78), emit=1.4, rough=0.22),
        "trunk": bpy_util.new_mat("SDS43_Trunk", (0.28, 0.16, 0.08), rough=0.9),
        "leaf": bpy_util.new_mat("SDS43_Leaf", (0.08, 0.28, 0.1), rough=0.72),
        "lamp": bpy_util.new_mat("SDS43_Lamp", (1.0, 0.92, 0.7), emit=4.2),
        "wood": bpy_util.new_mat("SDS43_VaultWood", (0.55, 0.34, 0.15), rough=0.48),
        "brick": bpy_util.new_mat("SDS43_Brick", (0.48, 0.22, 0.16), rough=0.78),
        "shop": bpy_util.new_mat("SDS43_ShopDark", (0.06, 0.06, 0.07), metal=0.15, rough=0.45),
        "plank": bpy_util.new_mat("SDS43_Plank", (0.38, 0.24, 0.12), rough=0.8),
        "bench": bpy_util.new_mat("SDS43_Bench", (0.22, 0.14, 0.08), rough=0.72),
        "rail_wood": bpy_util.new_mat("SDS43_RailWood", (0.42, 0.26, 0.12), rough=0.45),
        "cool": bpy_util.new_mat("SDS43_Moon", (0.7, 0.82, 1.0), emit=1.4, rough=0.25),
        "green": bpy_util.new_mat("SDS43_ZombieGreen", (0.22, 0.85, 0.18), emit=0.85, rough=0.35),
        "tape_y": bpy_util.new_mat("SDS43_TapeY", (0.95, 0.82, 0.12), emit=0.4, rough=0.5),
        "tape_k": bpy_util.new_mat("SDS43_TapeK", (0.06, 0.06, 0.06), rough=0.55),
        "banner": bpy_util.new_mat("SDS43_Banner", (0.08, 0.45, 0.12), emit=0.35, rough=0.6),
        "vine": bpy_util.new_mat("SDS43_Vine", (0.07, 0.22, 0.08), rough=0.85),
        "tile": _mat_tex("SDS43_InteriorTile", tile_img, rough=0.24, scale=(3.2, 3.2, 1.0)),
        "plaza": _mat_tex("SDS43_PlazaTile", plaza_img, rough=0.5, scale=(3.6, 3.6, 1.0)),
    }


def _place_kit(col, rel, name, target, gx, gy, gz, rot=(0.0, 0.0, 0.0), mode="max_xy"):
    import mathutils

    path = os.path.join(KIT, rel)
    if not os.path.isfile(path):
        print("KIT_MISSING", rel)
        return None
    imported = bpy_util.import_glb(path)
    joined = bpy_util.join_objects(imported, name)
    if joined is None:
        return None
    joined.rotation_euler = rot
    bpy_util.apply_transforms(joined)
    corners = [joined.matrix_world @ mathutils.Vector(c) for c in joined.bound_box]
    xs = [c.x for c in corners]
    ys = [c.y for c in corners]
    zs = [c.z for c in corners]
    dx, dy, dz = max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)
    if mode == "height":
        span = max(dz, 0.001)
    elif mode == "width":
        span = max(dx, 0.001)
    else:
        span = max(dx, dy, 0.001)
    scale = float(target) / span
    joined.scale = (scale, scale, scale)
    bpy_util.apply_transforms(joined)
    joined.location = _g(gx, gy, gz)
    bpy_util.link(joined, col)
    print("KIT_PLACE", name, "mode", mode, "scale", round(scale, 2), "span", round(span, 3))
    return joined


def _facade(col, mats):
    ## PRIMARY identity = extracted Tripo components. Manual = backing / joins / grounding only.
    _place_kit(col, os.path.join("arch", "arch_shell.glb"), "TripoArch", 16.8, 0.0, 0.0, 10.15, (0, 0, 0), "width")
    glass = _place_kit(col, os.path.join("glass", "glass_mass.glb"), "TripoGlass", 10.4, 0.0, 0.0, 8.45, (0, math.pi * 0.5, 0), "height")
    if glass is not None:
        ## Uniform scale made the vestibule ~10.7 m wide and hid the 3-bay cream portals.
        glass.scale = (0.58, 1.0, 1.0)
        bpy_util.apply_transforms(glass)
        glass.location = _g(0.0, 0.0, 8.45)
    _place_kit(col, os.path.join("logo_sign", "logo_mass.glb"), "TripoLogo", 2.55, 0.0, 5.75, 8.72, (0, 0, 0), "width")
    _place_kit(col, os.path.join("itau", "itau_storefront.glb"), "TripoItau", 4.2, -12.6, 0.0, 10.55, (0, 0, 0), "width")
    _place_kit(col, os.path.join("doorway", "doorway_mass.glb"), "TripoDoorR", 4.0, 12.6, 0.0, 10.55, (0, 0, 0), "width")
    _place_kit(col, os.path.join("wings", "wing_relief.glb"), "TripoWingL", 9.6, -13.4, 0.0, 9.15, (0, 0, 0), "width")
    _place_kit(col, os.path.join("wings", "wing_relief.glb"), "TripoWingR", 9.6, 13.4, 0.0, 9.15, (0, math.pi, 0), "width")
    _place_kit(col, os.path.join("planters", "planter_mass.glb"), "TripoPlanterL", 3.4, -10.2, 4.85, 10.45, (0, 0, 0), "width")
    _place_kit(col, os.path.join("planters", "planter_mass.glb"), "TripoPlanterR", 3.4, 10.2, 4.85, 10.45, (0, math.pi, 0), "width")
    _place_kit(col, os.path.join("warning_dressing", "warning_mass.glb"), "TripoWarnL", 5.1, -5.15, 2.15, 10.62, (0, 0, 0), "height")
    _place_kit(col, os.path.join("warning_dressing", "warning_mass.glb"), "TripoWarnR", 5.1, 5.15, 2.15, 10.62, (0, math.pi, 0), "height")
    _place_kit(col, os.path.join("columns", "column_cluster.glb"), "TripoFrameL", 7.6, -9.55, 0.0, 9.25, (0, 0, 0), "height")
    _place_kit(col, os.path.join("columns", "column_cluster.glb"), "TripoFrameR", 7.6, 9.55, 0.0, 9.25, (0, math.pi, 0), "height")

    ## Manual connectors only: backing so 3/4 does not show empty holes; warm volume behind glass.
    bpy_util.box("ArchBack", _s(8.6, 11.2, 0.45), _g(0, 5.6, 6.85), (0, 0, 0), mats["cream"], col)
    bpy_util.box("WingBackL", _s(9.4, 7.6, 1.6), _g(-13.4, 3.8, 8.35), (0, 0, 0), mats["brick"], col)
    bpy_util.box("WingBackR", _s(9.4, 7.6, 1.6), _g(13.4, 3.8, 8.35), (0, 0, 0), mats["brick"], col)
    bpy_util.box("JoinL", _s(1.2, 8.4, 1.8), _g(-8.9, 4.2, 9.05), (0, 0, 0), mats["cream"], col)
    bpy_util.box("JoinR", _s(1.2, 8.4, 1.8), _g(8.9, 4.2, 9.05), (0, 0, 0), mats["cream"], col)
    bpy_util.box("WarmBehindGlass", _s(5.0, 6.8, 1.1), _g(0, 3.9, 7.05), (0, 0, 0), mats["glow"], col)
    bpy_util.box("GreenAccentL", _s(1.1, 0.06, 0.16), _g(-8.3, 0.06, 10.55), (0, 0, 0), mats["green"], col)
    bpy_util.box("GreenAccentR", _s(1.1, 0.06, 0.16), _g(8.3, 0.06, 10.55), (0, 0, 0), mats["green"], col)
    bpy_util.box("BarrelL", _s(0.42, 0.7, 0.42), _g(-7.2, 0.38, 11.5), (0, 0, 0), mats["green"], col)
    bpy_util.box("BarrelR", _s(0.42, 0.7, 0.42), _g(7.2, 0.38, 11.5), (0, 0, 0), mats["dark"], col)
    bpy_util.empty("LIGHT_ENTRANCE", _g(0, 4.2, 10.2), (0, 0, 0), col, 0.9)
    bpy_util.empty("LIGHT_WING_L", _g(-12.4, 2.2, 11.0), (0, 0, 0), col, 0.35)
    bpy_util.empty("LIGHT_WING_R", _g(12.4, 2.2, 11.0), (0, 0, 0), col, 0.35)


def _palm(col, mats, x, z, h, name):
    bpy_util.cylinder("%s_Trunk" % name, 0.18, h, _g(x, h * 0.5, z), (0, 0, 0), mats["trunk"], col, 10)
    for i in range(6):
        ang = i * (math.tau / 6.0)
        bpy_util.box(
            "%s_Frond_%d" % (name, i),
            _s(0.22, 0.04, 2.6),
            _g(x + math.sin(ang) * 1.05, h + 0.15, z + math.cos(ang) * 1.05),
            (0.85, 0.0, ang),
            mats["leaf"],
            col,
        )
    bpy_util.ico("%s_Crown" % name, 0.35, _g(x, h + 0.12, z), mats["leaf"], col, 1)


def _lamp(col, mats, x, z, i):
    bpy_util.cylinder("LampPole_%02d" % i, 0.07, 6.8, _g(x, 3.4, z), (0, 0, 0), mats["metal"], col, 8)
    bpy_util.cylinder("LampHead_%02d" % i, 0.16, 0.28, _g(x, 6.85, z + 0.55), (1.1, 0, 0), mats["lamp"], col, 8)
    bpy_util.empty("LIGHT_PARKING_%03d" % i, _g(x, 6.6, z + 0.5), (0, 0, 0), col, 0.45)


def _parking(col, mats, veg, lights):
    bpy_util.box("ParkingAsphalt", _s(88.0, 0.12, 58.0), _g(0, -0.06, 28.0), (0, 0, 0), mats["asphalt"], col)
    for z in range(16, 46, 4):
        bpy_util.box("Dash_%d" % z, _s(0.14, 0.02, 1.2), _g(0, 0.03, float(z)), (0, 0, 0), mats["line"], col)
    walk = bpy_util.box("PlazaWalk", _s(8.4, 0.06, 8.8), _g(0, 0.03, 13.2), (0, 0, 0), mats["plaza"], col)
    _ensure_uv(walk, 1.8)
    for i in range(7):
        bpy_util.box("Zebra_%d" % i, _s(0.48, 0.04, 2.4), _g(-2.4 + i * 0.8, 0.07, 11.15), (0, 0, 0), mats["line"], col)
    for i in range(3):
        bpy_util.box("Step_%d" % i, _s(6.4, 0.14, 0.45), _g(0, 0.08 + i * 0.14, 8.95 - i * 0.22), (0, 0, 0), mats["cream"], col)
    _palm(veg, mats, -19.6, 15.2, 8.2, "PalmL")
    _palm(veg, mats, 19.6, 15.2, 8.2, "PalmR")
    bpy_util.box("IslandL", _s(1.4, 0.22, 1.8), _g(-19.6, 0.12, 15.2), (0, 0, 0), mats["curb"], col)
    bpy_util.box("IslandR", _s(1.4, 0.22, 1.8), _g(19.6, 0.12, 15.2), (0, 0, 0), mats["curb"], col)
    bpy_util.box("SoilL", _s(1.1, 0.12, 1.5), _g(-19.6, 0.24, 15.2), (0, 0, 0), mats["soil"], col)
    bpy_util.box("SoilR", _s(1.1, 0.12, 1.5), _g(19.6, 0.24, 15.2), (0, 0, 0), mats["soil"], col)
    for i, x in enumerate((-2.4, 2.4)):
        bpy_util.cylinder("Bollard_%d" % i, 0.08, 0.62, _g(x, 0.32, 11.35), (0, 0, 0), mats["metal"], col, 8)
    for i, (x, z) in enumerate([(-19.5, 14.8), (19.5, 14.8), (-12.0, 26.0), (12.0, 26.0), (0.0, 42.0)], start=1):
        _lamp(lights, mats, x, z, i)


def _fan_vault(col, mats, cx, cz, y, radius=9.2, n=16):
    bpy_util.box("SkylightFrame", _s(3.2, 0.2, 3.2), _g(cx, y, cz), (0, 0, 0), mats["wood"], col)
    bpy_util.box("SkylightGlass", _s(2.6, 0.06, 2.6), _g(cx, y + 0.08, cz), (0, 0, 0), mats["glass_in"], col)
    for i in range(n):
        ang = i * (math.tau / n)
        mx = cx + math.cos(ang) * radius * 0.55
        mz = cz + math.sin(ang) * radius * 0.55
        bpy_util.box("VaultBeam_%02d" % i, _s(0.2, 0.16, radius * 0.9), _g(mx, y - 0.8, mz), (0.32, 0.0, ang + math.pi * 0.5), mats["wood"], col)


def _interior(col, mats):
    floor = bpy_util.box("HallFloor", _s(18.0, 0.08, 14.0), _g(0, 0.0, 1.6), (0, 0, 0), mats["tile"], col)
    _ensure_uv(floor, 1.5)
    bpy_util.box("HallWallL", _s(0.4, 10.0, 14.0), _g(-9.1, 5.0, 1.6), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("HallWallR", _s(0.4, 10.0, 14.0), _g(9.1, 5.0, 1.6), (0, 0, 0), mats["masonry"], col)
    for i, z in enumerate((4.6, 0.4)):
        bpy_util.box("ShopGlassL_%d" % i, _s(5.0, 3.3, 0.06), _g(-6.4, 1.8, z - 1.4), (0, 0, 0), mats["glass_in"], col)
        bpy_util.box("ShopRoomL_%d" % i, _s(4.6, 2.9, 1.8), _g(-6.4, 1.65, z - 2.4), (0, 0, 0), mats["shop"], col)
        bpy_util.box("ShopGlassR_%d" % i, _s(5.0, 3.3, 0.06), _g(6.4, 1.8, z - 1.4), (0, 0, 0), mats["glass_in"], col)
        bpy_util.box("ShopRoomR_%d" % i, _s(4.6, 2.9, 1.8), _g(6.4, 1.65, z - 2.4), (0, 0, 0), mats["shop"], col)
        bpy_util.cylinder("ColL_%d" % i, 0.36, 8.8, _g(-4.2, 4.4, z), (0, 0, 0), mats["cream"], col, 14)
        bpy_util.cylinder("ColR_%d" % i, 0.36, 8.8, _g(4.2, 4.4, z), (0, 0, 0), mats["cream"], col, 14)
        bpy_util.empty("LIGHT_INTERIOR_%03d" % (i + 1), _g(0, 7.4, z), (0, 0, 0), col, 0.5)
    atrium_z = -14.0
    atrium = bpy_util.box("AtriumFloor", _s(28.0, 0.08, 22.0), _g(0, 0.0, atrium_z), (0, 0, 0), mats["tile"], col)
    _ensure_uv(atrium, 1.4)
    bpy_util.box("AtriumWell", _s(7.6, 0.04, 7.6), _g(0, 0.05, atrium_z - 1.0), (0, 0, 0), mats["plaza"], col)
    bpy_util.ico("AtriumPlant", 1.0, _g(0, 1.35, atrium_z - 1.0), mats["leaf"], col, 2)
    bpy_util.box("AtriumWallN", _s(28.2, 14.4, 0.4), _g(0, 7.2, -24.8), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("AtriumWallL", _s(0.4, 14.4, 22.0), _g(-14.0, 7.2, atrium_z), (0, 0, 0), mats["masonry"], col)
    bpy_util.box("AtriumWallR", _s(0.4, 14.4, 22.0), _g(14.0, 7.2, atrium_z), (0, 0, 0), mats["masonry"], col)
    _fan_vault(col, mats, 0.0, atrium_z, 10.4, 9.0, 12)
    for i in range(12):
        bpy_util.box("Stair_%02d" % i, _s(6.2, 0.14, 0.38), _g(0, 0.08 + i * 0.42, -18.2 - i * 0.28), (0, 0, 0), mats["metal"], col)
    bpy_util.box("MezzU", _s(26.0, 0.2, 4.4), _g(0, 6.1, -22.6), (0, 0, 0), mats["wood"], col)
    bpy_util.box("MezzL", _s(4.0, 0.2, 14.0), _g(-11.8, 6.1, atrium_z), (0, 0, 0), mats["wood"], col)
    bpy_util.box("MezzR", _s(4.0, 0.2, 14.0), _g(11.8, 6.1, atrium_z), (0, 0, 0), mats["wood"], col)
    bpy_util.box("RailGlassF", _s(20.0, 1.0, 0.05), _g(0, 6.7, -20.45), (0, 0, 0), mats["glass"], col)
    bpy_util.box("MezzShopA", _s(6.6, 2.7, 0.06), _g(-6.0, 7.6, -24.5), (0, 0, 0), mats["glass_in"], col)
    bpy_util.box("MezzShopB", _s(6.6, 2.7, 0.06), _g(6.0, 7.6, -24.5), (0, 0, 0), mats["glass_in"], col)
    bpy_util.empty("LIGHT_ATRIUM", _g(0, 11.8, atrium_z), (0, 0, 0), col, 1.1)


def _instance_cars(col):
    files = [os.path.join(CARS, "hilux_parked.glb"), os.path.join(CARS, "vaz_parked.glb")]
    if os.path.isfile(AMAROK):
        files.append(AMAROK)
    slots = [(-12.4, 19.2, 0.08), (12.6, 19.4, 3.05)]
    usable = [p for p in files if os.path.isfile(p)]
    print("SDS_V4_3_CARS", [os.path.basename(p) for p in usable])
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
    for i, (x, z, yaw) in enumerate(slots):
        src = templates[i % len(templates)]
        obj = src if i < len(templates) else src.copy()
        if i >= len(templates):
            obj.data = src.data
            col.objects.link(obj)
        obj.location = _g(x, 0.0, z)
        obj.rotation_euler = (0.0, 0.0, float(yaw))
        obj.name = "Parked_%02d" % i
        keep.append(obj)
    import bpy

    for o in list(col.objects):
        if o.type == "MESH" and o not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    return len(keep)


def _background(col, mats):
    bpy_util.ico("Moon", 3.2, _g(18.0, 22.0, -40.0), mats["cool"], col, 2)
    for i, x in enumerate((-46, 38)):
        h = 22.0 + i * 4.0
        bpy_util.box("Tower_%d" % i, _s(8.0, h, 8.0), _g(x, h * 0.5, -32.0), (0, 0, 0), mats["masonry"], col)


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
    open(AUTHORITY, "w", encoding="utf-8").write(
        "\n".join(
            [
                "HUMAN_REVIEW_REQUIRED",
                "CANDIDATE shopping_del_sol_zombies_environment_v4_3_candidate",
                "NOT_CANONICAL",
                "PRIMARY_FACADE\tE:\\JeffreyAIResearch\\references\\shopping_del_sol\\facade\\sds_facade_target_v1.png",
                "RAW_FACADE\tE:\\JeffreyAIResearch\\asset-library\\raw\\environment\\shopping_del_sol\\facade",
                "EXTRACTS\tE:\\JeffreyAIResearch\\asset-library\\processed\\environment\\shopping_del_sol\\facade\\v4_3_extracts",
            ]
        )
        + "\n"
    )


def _write_decisions(n_cars):
    import json

    rows = [
        {"part": "sds_facade_arch.glb / arch_shell", "decision": "KEEP_AFTER_CLEANUP", "why": "3-bay cream arch is the primary SDS silhouette"},
        {"part": "sds_facade_glass.glb / glass_mass", "decision": "KEEP_AFTER_CLEANUP", "why": "atrium grid + doors + embedded sun; scaled into arch cavity"},
        {"part": "sds_logo.glb / logo_mass", "decision": "KEEP_AFTER_CLEANUP", "why": "readable del Sol sunburst landmark"},
        {"part": "sds_architectural_doorway.glb", "decision": "KEEP_AFTER_CLEANUP", "why": "right boarded storefront, not a second main door"},
        {"part": "sds_columns.glb", "decision": "KEEP_AFTER_CLEANUP", "why": "cream frame portals at center-to-wing join"},
        {"part": "sds_brick_building_facade.glb", "decision": "KEEP_AFTER_CLEANUP", "why": "wing relief with balcony/window rhythm, not a 16m slab"},
        {"part": "sds_itau.glb", "decision": "KEEP_AFTER_CLEANUP", "why": "left SDS tenant storefront"},
        {"part": "sds_balcony_planter.glb", "decision": "KEEP_AFTER_CLEANUP", "why": "upper band planters"},
        {"part": "sds_warning.glb", "decision": "KEEP_AFTER_CLEANUP", "why": "skull banners as zombie dressing; mall still primary"},
        {"part": "cars", "decision": "USE", "used": n_cars},
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
    tile_path = os.path.join(TEX_DIR, "sds_interior_tile_v4_3_candidate.png")
    plaza_path = os.path.join(TEX_DIR, "sds_plaza_tile_v4_3_candidate.png")
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
    bpy_util.stats_report(EXPORT, {"asset": "shopping_del_sol_zombies_environment_v4_3_candidate", "state": "HUMAN_REVIEW_REQUIRED"})
    shutil.copy2(EXPORT, PROCESSED)
    import bpy

    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    _write_authority()
    _write_decisions(n_cars)
    print("SDS_ENV_V4_3_CANDIDATE_BUILT", EXPORT, "cars", n_cars, "HUMAN_REVIEW_REQUIRED")


if __name__ == "__main__":
    main()
