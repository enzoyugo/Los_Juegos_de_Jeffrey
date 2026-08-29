"""Shopping del Sol V4.2 CANDIDATE — facade deconstruction and cohesion.

Does NOT overwrite V3, V4, or V4.1. HUMAN_REVIEW_REQUIRED. Not SDS_V4_2_CANONICAL.

Primary exterior authority:
E:\\JeffreyAIResearch\\references\\shopping_del_sol\\facade\\sds_facade_target_v1.png

Rule: one authority per zone. No stacked Tripo+manual+old arch languages.
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

BLEND = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "blender", "shopping_del_sol_zombies_environment_v4_2_candidate.blend")
EXPORT = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "blender", "exports", "shopping_del_sol_zombies_environment_v4_2_candidate.glb")
PROCESSED = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "processed", "shopping_del_sol_zombies_environment_v4_2_candidate.glb")
TEX_DIR = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "processed", "textures")
CARS = os.path.join(ROOT, "assets", "environments", "shared", "urban", "processed", "vehicles")
KIT = r"E:\JeffreyAIResearch\asset-library\processed\environment\shopping_del_sol\facade"
DECISIONS = os.path.join(ROOT, "docs", "generated", "sds_v4_2_candidate_asset_decisions.json")
AUTHORITY = os.path.join(ROOT, "docs", "generated", "sds_v4_2_candidate_authority_frames.txt")
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
        "asphalt": bpy_util.new_mat("SDS42_Asphalt", (0.055, 0.055, 0.06), rough=0.92),
        "line": bpy_util.new_mat("SDS42_Line", (0.9, 0.88, 0.78), rough=0.42),
        "curb": bpy_util.new_mat("SDS42_Curb", (0.48, 0.46, 0.4), rough=0.82),
        "soil": bpy_util.new_mat("SDS42_Soil", (0.22, 0.16, 0.09), rough=0.93),
        "grass": bpy_util.new_mat("SDS42_Grass", (0.1, 0.28, 0.09), rough=0.84),
        "masonry": bpy_util.new_mat("SDS42_Masonry", (0.78, 0.72, 0.6), rough=0.64),
        "cream": bpy_util.new_mat("SDS42_Cream", (0.93, 0.9, 0.8), rough=0.4),
        "terra": bpy_util.new_mat("SDS42_Terra", (0.48, 0.28, 0.16), rough=0.72),
        "dark": bpy_util.new_mat("SDS42_MetalDark", (0.08, 0.08, 0.1), metal=0.62, rough=0.32),
        "metal": bpy_util.new_mat("SDS42_Metal", (0.18, 0.18, 0.2), metal=0.7, rough=0.28),
        "glass": bpy_util.new_mat("SDS42_Glass", (0.12, 0.18, 0.22), rough=0.06, metal=0.18, alpha=0.28),
        "glass_in": bpy_util.new_mat("SDS42_GlassIn", (0.92, 0.72, 0.42), rough=0.12, metal=0.02, alpha=0.55, emit=0.22),
        "glow": bpy_util.new_mat("SDS42_WarmGlow", (1.0, 0.68, 0.32), emit=1.15, rough=0.28),
        "star": bpy_util.new_mat("SDS42_Sun", (1.0, 0.78, 0.14), emit=2.6, rough=0.18),
        "sign": bpy_util.new_mat("SDS42_SignLit", (0.98, 0.94, 0.78), emit=1.4, rough=0.22),
        "trunk": bpy_util.new_mat("SDS42_Trunk", (0.28, 0.16, 0.08), rough=0.9),
        "leaf": bpy_util.new_mat("SDS42_Leaf", (0.08, 0.28, 0.1), rough=0.72),
        "lamp": bpy_util.new_mat("SDS42_Lamp", (1.0, 0.92, 0.7), emit=4.2),
        "wood": bpy_util.new_mat("SDS42_VaultWood", (0.55, 0.34, 0.15), rough=0.48),
        "brick": bpy_util.new_mat("SDS42_Brick", (0.48, 0.22, 0.16), rough=0.78),
        "shop": bpy_util.new_mat("SDS42_ShopDark", (0.06, 0.06, 0.07), metal=0.15, rough=0.45),
        "plank": bpy_util.new_mat("SDS42_Plank", (0.38, 0.24, 0.12), rough=0.8),
        "bench": bpy_util.new_mat("SDS42_Bench", (0.22, 0.14, 0.08), rough=0.72),
        "rail_wood": bpy_util.new_mat("SDS42_RailWood", (0.42, 0.26, 0.12), rough=0.45),
        "cool": bpy_util.new_mat("SDS42_Moon", (0.7, 0.82, 1.0), emit=1.4, rough=0.25),
        "green": bpy_util.new_mat("SDS42_ZombieGreen", (0.22, 0.85, 0.18), emit=0.85, rough=0.35),
        "tape_y": bpy_util.new_mat("SDS42_TapeY", (0.95, 0.82, 0.12), emit=0.4, rough=0.5),
        "tape_k": bpy_util.new_mat("SDS42_TapeK", (0.06, 0.06, 0.06), rough=0.55),
        "banner": bpy_util.new_mat("SDS42_Banner", (0.08, 0.45, 0.12), emit=0.35, rough=0.6),
        "vine": bpy_util.new_mat("SDS42_Vine", (0.07, 0.22, 0.08), rough=0.85),
        "tile": _mat_tex("SDS42_InteriorTile", tile_img, rough=0.24, scale=(3.2, 3.2, 1.0)),
        "plaza": _mat_tex("SDS42_PlazaTile", plaza_img, rough=0.5, scale=(3.6, 3.6, 1.0)),
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
    span = max(max(xs) - min(xs), max(ys) - min(ys), 0.001)
    scale = float(target_w) / span
    joined.scale = (scale, scale, scale)
    bpy_util.apply_transforms(joined)
    joined.rotation_euler = rot
    bpy_util.apply_transforms(joined)
    joined.location = _g(gx, gy, gz)
    bpy_util.link(joined, col)
    print("KIT_PLACE", name, "scale", round(scale, 2))
    return joined


def _half_torus(col, mat, major, minor, z_face, y_lift, name, segs=56, height_scale=1.42):
    """One continuous cream arch. Scaled on Z so it is tall without becoming a 20 m circle."""
    import bpy

    loc = _g(0.0, y_lift, z_face)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=float(major),
        minor_radius=float(minor),
        major_segments=int(segs),
        minor_segments=10,
        location=loc,
        rotation=(math.pi * 0.5, 0.0, 0.0),
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy_util.apply_transforms(obj)
    obj.scale = (1.0, 1.0, float(height_scale))
    bpy_util.apply_transforms(obj)
    cut_z = loc[2]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for v in obj.data.vertices:
        world = obj.matrix_world @ v.co
        v.select = world.z < (cut_z + 0.04)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.delete(type="VERT")
    bpy.ops.object.mode_set(mode="OBJECT")
    if mat is not None:
        if obj.data.materials:
            obj.data.materials[0] = mat
        else:
            obj.data.materials.append(mat)
    bpy_util.link(obj, col)
    return obj


def _sun(col, mats, x, y, z):
    bpy_util.ico("SunDisc", 0.55, _g(x, y, z), mats["star"], col, 2)
    for i in range(8):
        ang = i * (math.pi / 8.0)
        bpy_util.box("SunRay_%d" % i, _s(1.35, 0.12, 0.06), _g(x, y, z), (0.0, ang, 0.0), mats["star"], col)
    bpy_util.empty("LIGHT_SUN", _g(x, y, z + 0.15), (0, 0, 0), col, 0.4)


def _shopping_sign(col, mats):
    """Readable SHOPPING bar. Block letters beat eight identical cubes."""
    glyphs = {
        "S": ["01110", "10000", "01110", "00001", "11110"],
        "H": ["10001", "10001", "11111", "10001", "10001"],
        "O": ["01110", "10001", "10001", "10001", "01110"],
        "P": ["11110", "10001", "11110", "10000", "10000"],
        "I": ["11111", "00100", "00100", "00100", "11111"],
        "N": ["10001", "11001", "10101", "10011", "10001"],
        "G": ["01110", "10000", "10111", "10001", "01110"],
    }
    bar = bpy_util.box("SignBar", _s(4.9, 0.62, 0.1), _g(0, 3.22, 8.62), (0, 0, 0), mats["dark"], col)
    text = "SHOPPING"
    x0 = -2.05
    for ch in text:
        rows = glyphs[ch]
        for r, row in enumerate(rows):
            for c, bit in enumerate(row):
                if bit != "1":
                    continue
                bpy_util.box(
                    "Sign_%s_%d_%d" % (ch, r, c),
                    _s(0.09, 0.09, 0.05),
                    _g(x0 + c * 0.11, 3.42 - r * 0.1, 8.7),
                    (0, 0, 0),
                    mats["sign"],
                    col,
                )
        x0 += 0.62
    return bar


def _tape(col, mats, x, y, z):
    for i in range(4):
        mat = mats["tape_y"] if i % 2 == 0 else mats["tape_k"]
        bpy_util.box("Tape_%0.1f_%d" % (x, i), _s(1.7, 0.08, 0.03), _g(x, y + i * 0.55, z), (0, 0, 0.7 if i % 2 else -0.7), mat, col)


def _facade(col, mats):
    ## ONE arch: two continuous torus shells. Arch is the skyline (taller than glass and wings).
    _half_torus(col, mats["cream"], 6.55, 0.7, 10.12, 0.18, "ArchOuter", 64, 1.42)
    _half_torus(col, mats["cream"], 5.85, 0.36, 10.28, 0.22, "ArchInner", 56, 1.42)
    bpy_util.box("ArchBaseL", _s(1.25, 4.0, 1.5), _g(-6.45, 2.0, 10.12), (0, 0, 0), mats["cream"], col)
    bpy_util.box("ArchBaseR", _s(1.25, 4.0, 1.5), _g(6.45, 2.0, 10.12), (0, 0, 0), mats["cream"], col)
    ## Tympanum fill so glass sits IN the arch instead of a rectangle floating behind it.
    bpy_util.box("ArchFillL", _s(0.95, 7.2, 0.5), _g(-3.55, 3.75, 9.55), (0, 0, 0), mats["cream"], col)
    bpy_util.box("ArchFillR", _s(0.95, 7.2, 0.5), _g(3.55, 3.75, 9.55), (0, 0, 0), mats["cream"], col)
    bpy_util.box("ArchFillTop", _s(7.2, 1.15, 0.5), _g(0, 8.15, 9.55), (0, 0, 0), mats["cream"], col)

    ## ONE glass vestibule: dark front glass, warm interior plane, one mullion rhythm.
    bpy_util.box("GlassVestibule", _s(7.4, 7.5, 0.05), _g(0, 3.9, 8.58), (0, 0, 0), mats["glass"], col)
    bpy_util.box("GlassInner", _s(6.8, 6.9, 0.04), _g(0, 3.95, 7.35), (0, 0, 0), mats["glass_in"], col)
    bpy_util.box("GlassRimL", _s(0.18, 7.75, 0.22), _g(-3.78, 3.9, 8.5), (0, 0, 0), mats["dark"], col)
    bpy_util.box("GlassRimR", _s(0.18, 7.75, 0.22), _g(3.78, 3.9, 8.5), (0, 0, 0), mats["dark"], col)
    bpy_util.box("GlassRimT", _s(7.7, 0.18, 0.22), _g(0, 7.72, 8.5), (0, 0, 0), mats["dark"], col)
    bpy_util.box("GlassRimB", _s(7.7, 0.18, 0.22), _g(0, 0.22, 8.5), (0, 0, 0), mats["dark"], col)
    bpy_util.box("MullionC", _s(0.1, 6.8, 0.08), _g(0, 3.85, 8.62), (0, 0, 0), mats["dark"], col)
    bpy_util.box("MullionL", _s(0.1, 6.8, 0.08), _g(-2.2, 3.85, 8.62), (0, 0, 0), mats["dark"], col)
    bpy_util.box("MullionR", _s(0.1, 6.8, 0.08), _g(2.2, 3.85, 8.62), (0, 0, 0), mats["dark"], col)
    bpy_util.box("MullionH1", _s(7.1, 0.1, 0.08), _g(0, 5.55, 8.62), (0, 0, 0), mats["dark"], col)
    bpy_util.box("MullionH2", _s(7.1, 0.1, 0.08), _g(0, 2.95, 8.62), (0, 0, 0), mats["dark"], col)

    bpy_util.box("VestFloor", _s(7.6, 0.08, 2.4), _g(0, 0.02, 7.55), (0, 0, 0), mats["cream"], col)
    bpy_util.box("DoorL", _s(1.28, 2.55, 0.07), _g(-0.74, 1.32, 6.9), (0, 0, 0), mats["glass"], col)
    bpy_util.box("DoorR", _s(1.28, 2.55, 0.07), _g(0.74, 1.32, 6.9), (0, 0, 0), mats["glass"], col)
    bpy_util.box("DoorFrame", _s(2.85, 2.8, 0.14), _g(0, 1.42, 6.78), (0, 0, 0), mats["dark"], col)
    _tape(col, mats, -0.74, 0.7, 7.0)
    _tape(col, mats, 0.74, 0.7, 7.0)

    _sun(col, mats, 0.0, 7.15, 8.22)
    _shopping_sign(col, mats)

    ## Cream transition frames (reference: rectangles flanking the arch). Slightly below arch apex.
    for side in (-1.0, 1.0):
        bpy_util.box("CreamFrame_%d" % int(side), _s(1.7, 8.8, 2.45), _g(side * 8.05, 4.4, 9.28), (0, 0, 0), mats["cream"], col)
        bpy_util.box("GreenAccent_%d" % int(side), _s(1.2, 0.06, 0.18), _g(side * 8.05, 0.06, 10.42), (0, 0, 0), mats["green"], col)
        bpy_util.box("Banner_%d" % int(side), _s(0.7, 4.6, 0.05), _g(side * 6.35, 4.1, 10.48), (0, 0, 0), mats["banner"], col)

    ## ONE wing language: brick mass + storefront + balcony. No 5-pier grid. No 16m Tripo slab.
    for side in (-1.0, 1.0):
        bpy_util.box("WingMass_%d" % int(side), _s(8.8, 7.1, 2.8), _g(side * 13.2, 3.55, 9.15), (0, 0, 0), mats["brick"], col)
        bpy_util.box("WingJoin_%d" % int(side), _s(1.5, 8.2, 2.4), _g(side * 9.05, 4.1, 9.22), (0, 0, 0), mats["cream"], col)
        bpy_util.box("ShopOpen_%d" % int(side), _s(5.4, 3.15, 0.08), _g(side * 12.4, 1.7, 10.62), (0, 0, 0), mats["shop"], col)
        bpy_util.box("ShopLeak_%d" % int(side), _s(4.8, 2.6, 1.2), _g(side * 12.4, 1.55, 9.7), (0, 0, 0), mats["glow"] if side < 0 else mats["shop"], col)
        bpy_util.box("Awning_%d" % int(side), _s(5.8, 0.12, 1.1), _g(side * 12.4, 3.45, 10.95), (0, 0, 0.12 * side), mats["terra"], col)
        bpy_util.box("Balcony_%d" % int(side), _s(8.8, 0.22, 1.35), _g(side * 12.6, 5.05, 10.35), (0, 0, 0), mats["cream"], col)
        bpy_util.box("BalconyRail_%d" % int(side), _s(8.6, 0.55, 0.08), _g(side * 12.6, 5.45, 10.95), (0, 0, 0), mats["cream"], col)
        for v in range(5):
            bpy_util.box("Vine_%d_%d" % (int(side), v), _s(0.55, 1.6 + (v % 2) * 0.4, 0.08), _g(side * (9.4 + v * 1.5), 4.15, 10.7), (0, 0, 0), mats["vine"], col)
        bpy_util.box("UpperWin_%d" % int(side), _s(3.2, 1.8, 0.06), _g(side * 12.6, 6.55, 10.58), (0, 0, 0), mats["glass"], col)
        bpy_util.box("PlankA_%d" % int(side), _s(0.18, 2.6, 0.08), _g(side * 12.2, 1.7, 10.72), (0, 0, 0.55), mats["plank"], col)
        bpy_util.box("PlankB_%d" % int(side), _s(0.18, 2.6, 0.08), _g(side * 12.6, 1.7, 10.72), (0, 0, -0.55), mats["plank"], col)

    _place_kit(col, os.path.join("details", "sds_itau_kit_v001.glb"), "ItauShop", 3.1, -12.3, 0.02, 10.85, (0, 0, 0))
    _place_kit(col, os.path.join("details", "balcony_planter_3d_model_kit_v001.glb"), "PlanterL", 1.8, -10.6, 5.15, 10.5, (0, 0, 0))
    _place_kit(col, os.path.join("details", "balcony_planter_3d_model_kit_v001.glb"), "PlanterR", 1.8, 10.6, 5.15, 10.5, (0, math.pi, 0))

    bpy_util.box("BarrelL", _s(0.42, 0.7, 0.42), _g(-7.4, 0.38, 11.4), (0, 0, 0), mats["green"], col)
    bpy_util.box("BarrelR", _s(0.42, 0.7, 0.42), _g(7.4, 0.38, 11.4), (0, 0, 0), mats["dark"], col)
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
        bpy_util.box("Zebra_%d" % i, _s(0.4, 0.04, 1.7), _g(-2.4 + i * 0.8, 0.07, 10.35), (0, 0, 0), mats["line"], col)
    for i in range(3):
        bpy_util.box("Step_%d" % i, _s(6.4, 0.14, 0.45), _g(0, 0.08 + i * 0.14, 8.95 - i * 0.22), (0, 0, 0), mats["cream"], col)
    _palm(veg, mats, -17.4, 14.4, 8.4, "PalmL")
    _palm(veg, mats, 17.4, 14.4, 8.4, "PalmR")
    bpy_util.box("IslandL", _s(1.4, 0.22, 1.8), _g(-17.4, 0.12, 14.4), (0, 0, 0), mats["curb"], col)
    bpy_util.box("IslandR", _s(1.4, 0.22, 1.8), _g(17.4, 0.12, 14.4), (0, 0, 0), mats["curb"], col)
    bpy_util.box("SoilL", _s(1.1, 0.12, 1.5), _g(-17.4, 0.24, 14.4), (0, 0, 0), mats["soil"], col)
    bpy_util.box("SoilR", _s(1.1, 0.12, 1.5), _g(17.4, 0.24, 14.4), (0, 0, 0), mats["soil"], col)
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
    _fan_vault(col, mats, 0.0, atrium_z, 14.2, 10.5, 16)
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
    slots = [(-7.8, 15.6, 0.04), (7.8, 15.8, 3.14), (-8.4, 28.0, 0.05), (16.0, 24.0, -1.5)]
    usable = [p for p in files if os.path.isfile(p)]
    print("SDS_V4_2_CARS", [os.path.basename(p) for p in usable])
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
                "CANDIDATE shopping_del_sol_zombies_environment_v4_2_candidate",
                "NOT_CANONICAL",
                "PRIMARY_FACADE\tE:\\JeffreyAIResearch\\references\\shopping_del_sol\\facade\\sds_facade_target_v1.png",
                "PART_MAP\tE:\\JeffreyAIResearch\\docs\\SDS_REFERENCE_FACADE_PART_MAP_V1.md",
            ]
        )
        + "\n"
    )


def _write_decisions(n_cars):
    import json

    rows = [
        {"part": "sds_facade_arch_kit", "decision": "REJECT", "why": "VISUALLY_WORSE_THAN_MANUAL vs target cream arch; competed with 3 shells in V4.1"},
        {"part": "sds_facade_glass_kit", "decision": "REJECT", "why": "opaque blob; one clean vestibule instead"},
        {"part": "architectural_doorway_kit", "decision": "REJECT", "why": "stacked with manual doors"},
        {"part": "sds_collumns_kit", "decision": "REJECT", "why": "competed with cream frames"},
        {"part": "brick_building_facade_kit", "decision": "REJECT", "why": "BAD_PROPORTIONS 16m slab vs subordinate wings in target"},
        {"part": "sds_logo_kit", "decision": "REJECT", "why": "competed with sun landmark"},
        {"part": "sds_itau_kit", "decision": "KEEP_AFTER_CLEANUP", "why": "left tenant in target; placed in wing opening"},
        {"part": "balcony_planter_kit", "decision": "KEEP_AFTER_CLEANUP", "why": "balcony band only, not driveway clutter"},
        {"part": "sds_warning_kit", "decision": "REFERENCE_ONLY", "why": "REFERENCE_MISMATCH"},
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
    tile_path = os.path.join(TEX_DIR, "sds_interior_tile_v4_2_candidate.png")
    plaza_path = os.path.join(TEX_DIR, "sds_plaza_tile_v4_2_candidate.png")
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
    bpy_util.stats_report(EXPORT, {"asset": "shopping_del_sol_zombies_environment_v4_2_candidate", "state": "HUMAN_REVIEW_REQUIRED"})
    shutil.copy2(EXPORT, PROCESSED)
    import bpy

    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    _write_authority()
    _write_decisions(n_cars)
    print("SDS_ENV_V4_2_CANDIDATE_BUILT", EXPORT, "cars", n_cars, "HUMAN_REVIEW_REQUIRED")


if __name__ == "__main__":
    main()
