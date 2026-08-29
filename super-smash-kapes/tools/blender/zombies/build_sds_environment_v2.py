"""Shopping del Sol exterior V2 — hero facade/entrance + processed vehicles. Blender 5.2 CLI."""

from __future__ import annotations

import math
import os
import shutil
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from tools.blender.common import bpy_util  # noqa: E402

BLEND = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "blender", "shopping_del_sol_zombies_environment_v2.blend")
EXPORT = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "blender", "exports", "shopping_del_sol_zombies_environment_v2.glb")
PROCESSED = os.path.join(ROOT, "assets", "environments", "shopping_del_sol", "processed", "shopping_del_sol_zombies_environment_v2.glb")
CARS = os.path.join(ROOT, "assets", "environments", "shared", "urban", "processed", "vehicles")
REVIEW = os.path.join(ROOT, "docs", "generated", "v9_visual_review", "shopping")
AUTHORITY = os.path.join(ROOT, "docs", "generated", "sds_v2_authority_frames.txt")


def _g(x, y, z):
    return (float(x), float(-z), float(y))


def _s(sx, sy, sz):
    return (float(sx), float(sz), float(sy))


def _mats():
    return {
        "asphalt": bpy_util.new_mat("SDS2_Asphalt", (0.08, 0.08, 0.09), rough=0.94),
        "line": bpy_util.new_mat("SDS2_Line", (0.88, 0.86, 0.74), rough=0.45),
        "curb": bpy_util.new_mat("SDS2_Curb", (0.58, 0.56, 0.5), rough=0.78),
        "soil": bpy_util.new_mat("SDS2_Soil", (0.26, 0.2, 0.12), rough=0.9),
        "grass": bpy_util.new_mat("SDS2_Grass", (0.18, 0.36, 0.14), rough=0.8),
        "terra": bpy_util.new_mat("SDS2_Terracotta", (0.66, 0.4, 0.26), rough=0.68),
        "cream": bpy_util.new_mat("SDS2_Cream", (0.86, 0.8, 0.66), rough=0.52),
        "dark": bpy_util.new_mat("SDS2_MetalDark", (0.16, 0.16, 0.18), metal=0.58, rough=0.38),
        "metal": bpy_util.new_mat("SDS2_MetalLight", (0.58, 0.59, 0.6), metal=0.62, rough=0.32),
        "glass": bpy_util.new_mat("SDS2_Glass", (0.38, 0.55, 0.6), rough=0.06, metal=0.12, alpha=0.38),
        "glow": bpy_util.new_mat("SDS2_WarmGlow", (1.0, 0.82, 0.55), emit=2.4, rough=0.2),
        "sign": bpy_util.new_mat("SDS2_Sign", (0.92, 0.78, 0.32), emit=1.1),
        "trunk": bpy_util.new_mat("SDS2_Trunk", (0.34, 0.22, 0.12), rough=0.9),
        "leaf": bpy_util.new_mat("SDS2_Leaf", (0.14, 0.42, 0.16), rough=0.72),
        "rubber": bpy_util.new_mat("SDS2_Rubber", (0.04, 0.04, 0.04), rough=0.96),
        "lamp": bpy_util.new_mat("SDS2_Lamp", (0.98, 0.9, 0.65), emit=3.6),
        "concrete": bpy_util.new_mat("SDS2_Concrete", (0.5, 0.5, 0.48), rough=0.86),
        "tile": bpy_util.new_mat("SDS2_Tile", (0.72, 0.7, 0.64), rough=0.4),
        "shrub": bpy_util.new_mat("SDS2_Shrub", (0.12, 0.32, 0.12), rough=0.85),
    }


def _palm(col, mats, x, z, h=6.0, name="Palm"):
    bpy_util.cylinder("%s_Trunk" % name, 0.18, h, _g(x, h * 0.5, z), (0, 0, 0), mats["trunk"], col, 12)
    bpy_util.cylinder("%s_Crown" % name, 0.28, 0.22, _g(x, h - 0.1, z), (0, 0, 0), mats["trunk"], col, 10)
    n = 11
    for i in range(n):
        ang = i * (math.tau / n)
        bpy_util.box(
            "%s_Frond_%d" % (name, i),
            _s(0.22, 0.035, 2.6),
            _g(x + math.sin(ang) * 1.15, h + 0.2, z + math.cos(ang) * 1.15),
            (0.42, 0.12, ang),
            mats["leaf"],
            col,
        )
    bpy_util.ico("%s_Heart" % name, 0.35, _g(x, h + 0.15, z), mats["leaf"], col, 1)


def _tree(col, mats, x, z, name="Tree"):
    bpy_util.cylinder("%s_Trunk" % name, 0.24, 4.6, _g(x, 2.3, z), (0, 0, 0), mats["trunk"], col, 10)
    bpy_util.ico("%s_A" % name, 1.7, _g(x, 5.1, z), mats["leaf"], col, 2)
    bpy_util.ico("%s_B" % name, 1.15, _g(x + 0.7, 4.6, z + 0.3), mats["leaf"], col, 1)


def _lamp(col, mats, x, z, i):
    bpy_util.cylinder("LampPole_%02d" % i, 0.1, 8.0, _g(x, 4.0, z), (0, 0, 0), mats["metal"], col, 10)
    bpy_util.box("LampArm_%02d" % i, _s(2.6, 0.09, 0.09), _g(x, 7.85, z), (0, 0, 0), mats["metal"], col)
    bpy_util.box("LampHeadL_%02d" % i, _s(0.4, 0.18, 0.28), _g(x - 1.2, 7.65, z), (0, 0, 0), mats["lamp"], col)
    bpy_util.box("LampHeadR_%02d" % i, _s(0.4, 0.18, 0.28), _g(x + 1.2, 7.65, z), (0, 0, 0), mats["lamp"], col)
    bpy_util.empty("LIGHT_PARKING_%03d" % i, _g(x, 7.4, z), (0, 0, 0), col, 0.6)


def _bollard(col, mats, x, z, i):
    bpy_util.cylinder("Bollard_%02d" % i, 0.09, 0.7, _g(x, 0.35, z), (0, 0, 0), mats["metal"], col, 8)


def _bin(col, mats, x, z, i):
    bpy_util.cylinder("Bin_%02d" % i, 0.28, 0.85, _g(x, 0.42, z), (0, 0, 0), mats["dark"], col, 10)


def _facade(col, mats):
    bpy_util.box("FacadeMassL", _s(18.4, 11.2, 2.4), _g(-14.6, 5.6, 8.2), (0, 0, 0), mats["terra"], col)
    bpy_util.box("FacadeMassR", _s(18.4, 11.2, 2.4), _g(14.6, 5.6, 8.2), (0, 0, 0), mats["terra"], col)
    bpy_util.box("ParapetL", _s(18.6, 0.55, 2.7), _g(-14.6, 11.35, 8.2), (0, 0, 0), mats["cream"], col)
    bpy_util.box("ParapetR", _s(18.6, 0.55, 2.7), _g(14.6, 11.35, 8.2), (0, 0, 0), mats["cream"], col)
    bpy_util.box("BandL", _s(17.6, 0.7, 0.35), _g(-14.6, 8.4, 9.45), (0, 0, 0), mats["cream"], col)
    bpy_util.box("BandR", _s(17.6, 0.7, 0.35), _g(14.6, 8.4, 9.45), (0, 0, 0), mats["cream"], col)
    for side in (-1.0, 1.0):
        for i in range(5):
            x = side * (7.4 + i * 2.9)
            bpy_util.box("Col_%d_%d" % (int(side), i), _s(0.32, 10.6, 0.45), _g(x, 5.3, 9.35), (0, 0, 0), mats["cream"], col)
            for row, y in enumerate((3.1, 6.2, 9.0)):
                bpy_util.box("Win_%d_%d_%d" % (int(side), i, row), _s(2.05, 1.85, 0.08), _g(x + side * 1.35, y, 9.48), (0, 0, 0), mats["glass"], col)
                bpy_util.box("Frame_%d_%d_%d" % (int(side), i, row), _s(2.18, 2.0, 0.12), _g(x + side * 1.35, y, 9.42), (0, 0, 0), mats["dark"], col)
    bpy_util.box("EntranceRecess", _s(8.4, 7.4, 1.6), _g(0, 3.7, 8.55), (0, 0, 0), mats["dark"], col)
    bpy_util.box("EntranceCanopy", _s(9.2, 0.28, 3.4), _g(0, 5.85, 9.6), (0, 0, 0), mats["cream"], col)
    bpy_util.box("CanopyRib", _s(9.0, 0.12, 0.18), _g(0, 5.7, 10.6), (0, 0, 0), mats["metal"], col)
    bpy_util.box("PortalL", _s(0.55, 7.2, 1.8), _g(-4.1, 3.6, 9.1), (0, 0, 0), mats["cream"], col)
    bpy_util.box("PortalR", _s(0.55, 7.2, 1.8), _g(4.1, 3.6, 9.1), (0, 0, 0), mats["cream"], col)
    bpy_util.box("Curtain", _s(7.6, 6.4, 0.1), _g(0, 3.5, 8.85), (0, 0, 0), mats["glass"], col)
    for i, x in enumerate((-3.0, -1.8, -0.6, 0.6, 1.8, 3.0)):
        bpy_util.box("Mullion_%d" % i, _s(0.07, 6.2, 0.14), _g(x, 3.4, 8.95), (0, 0, 0), mats["metal"], col)
    bpy_util.box("DoorL", _s(1.4, 2.7, 0.08), _g(-0.8, 1.4, 8.98), (0, 0, 0), mats["glass"], col)
    bpy_util.box("DoorR", _s(1.4, 2.7, 0.08), _g(0.8, 1.4, 8.98), (0, 0, 0), mats["glass"], col)
    bpy_util.box("DoorBar", _s(3.0, 0.08, 0.08), _g(0, 1.55, 9.05), (0, 0, 0), mats["metal"], col)
    bpy_util.box("SignMount", _s(9.4, 1.35, 0.28), _g(0, 7.15, 9.55), (0, 0, 0), mats["dark"], col)
    bpy_util.box("SignFace", _s(8.8, 1.05, 0.12), _g(0, 7.15, 9.72), (0, 0, 0), mats["sign"], col)
    bpy_util.box("SunMark", _s(1.2, 1.2, 0.1), _g(-3.4, 7.15, 9.8), (0, 0, 0), mats["glow"], col)
    bpy_util.empty("LIGHT_ENTRANCE_001", _g(0, 4.2, 9.8), (0, 0, 0), col, 0.9)
    bpy_util.empty("LIGHT_ENTRANCE_002", _g(-3.2, 5.4, 10.2), (0, 0, 0), col, 0.5)
    bpy_util.empty("LIGHT_ENTRANCE_003", _g(3.2, 5.4, 10.2), (0, 0, 0), col, 0.5)


def _interior(col, mats):
    bpy_util.box("PlazaFloor", _s(16.0, 0.08, 28.0), _g(0, 0.0, -8.0), (0, 0, 0), mats["tile"], col)
    bpy_util.box("PlazaWallL", _s(0.4, 6.4, 28.0), _g(-8.0, 3.2, -8.0), (0, 0, 0), mats["cream"], col)
    bpy_util.box("PlazaWallR", _s(0.4, 6.4, 28.0), _g(8.0, 3.2, -8.0), (0, 0, 0), mats["cream"], col)
    bpy_util.box("PlazaCeiling", _s(16.2, 0.2, 28.0), _g(0, 6.5, -8.0), (0, 0, 0), mats["concrete"], col)
    for i, z in enumerate((-2.0, -8.0, -14.0, -20.0)):
        bpy_util.cylinder("MallCol_%d" % i, 0.38, 6.2, _g(-4.2, 3.1, z), (0, 0, 0), mats["cream"], col, 12)
        bpy_util.cylinder("MallColR_%d" % i, 0.38, 6.2, _g(4.2, 3.1, z), (0, 0, 0), mats["cream"], col, 12)
        bpy_util.box("ShopFront_%d" % i, _s(5.6, 3.4, 0.12), _g(-5.0, 1.8, z - 3.2), (0, 0, 0), mats["glass"], col)
        bpy_util.box("ShopFrontR_%d" % i, _s(5.6, 3.4, 0.12), _g(5.0, 1.8, z - 3.2), (0, 0, 0), mats["glass"], col)
        bpy_util.box("CeilLight_%d" % i, _s(3.2, 0.08, 0.4), _g(0, 6.25, z), (0, 0, 0), mats["glow"], col)
        bpy_util.empty("LIGHT_INTERIOR_%03d" % (i + 1), _g(0, 5.8, z), (0, 0, 0), col, 0.5)
    bpy_util.box("KioskBody", _s(2.4, 2.2, 2.4), _g(0, 1.1, -10.0), (0, 0, 0), mats["dark"], col)
    bpy_util.box("KioskTop", _s(2.6, 0.12, 2.6), _g(0, 2.25, -10.0), (0, 0, 0), mats["sign"], col)
    bpy_util.box("BenchA", _s(1.8, 0.42, 0.55), _g(-2.4, 0.32, -6.0), (0, 0, 0), mats["dark"], col)
    bpy_util.box("PlanterA", _s(1.1, 0.55, 1.1), _g(2.6, 0.28, -6.2), (0, 0, 0), mats["concrete"], col)
    bpy_util.ico("ShrubA", 0.55, _g(2.6, 0.95, -6.2), mats["shrub"], col, 1)


def _instance_cars(col):
    files = [
        os.path.join(CARS, "hilux_parked.glb"),
        os.path.join(CARS, "vaz_parked.glb"),
    ]
    wreck = os.path.join(CARS, "wreck_parked.glb")
    slots = [
        (-8.4, 14.6, 0.04),
        (-8.2, 17.8, -0.03),
        (-8.5, 24.2, 0.06),
        (-8.3, 27.4, 0.02),
        (8.5, 15.0, 3.18),
        (8.3, 21.4, 3.10),
        (8.6, 24.6, 3.20),
        (16.5, 18.2, -1.52),
        (-16.6, 16.0, 0.1),
        (16.8, 27.0, -1.58),
        (-16.8, 31.6, 0.05),
        (8.4, 30.8, 3.08),
    ]
    usable = [p for p in files if os.path.isfile(p)]
    print("SDS_V2_PROCESSED_CARS", [os.path.basename(p) for p in usable])
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
    n = 0
    for i, (x, z, yaw) in enumerate(slots):
        src = templates[i % len(templates)]
        if i < 3:
            obj = src
        else:
            obj = src.copy()
            obj.data = src.data
            col.objects.link(obj)
        obj.location = _g(x, 0.0, z)
        obj.rotation_euler = (0.0, 0.0, float(yaw))
        obj.name = "Parked_%02d" % i
        n += 1
    if os.path.isfile(wreck) and os.path.getsize(wreck) < 12_000_000:
        imported = bpy_util.import_glb(wreck)
        joined = bpy_util.join_objects(imported, "WreckOne")
        if joined is not None:
            bpy_util.link(joined, col)
            joined.location = _g(-28.0, 0.0, 44.0)
            joined.rotation_euler = (0.0, 0.0, 0.4)
            n += 1
    return n


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
    bpy_util.box("ParkingAsphalt", _s(86.0, 0.12, 56.0), _g(0, -0.06, 26.0), (0, 0, 0), mats["asphalt"], park)
    bpy_util.box("ApproachAsphalt", _s(14.0, 0.1, 8.0), _g(0, -0.05, 10.0), (0, 0, 0), mats["asphalt"], park)
    for z in range(14, 44, 3):
        bpy_util.box("Dash_%d" % z, _s(0.16, 0.02, 1.35), _g(0, 0.03, float(z)), (0, 0, 0), mats["line"], park)
    for side in (-1.0, 1.0):
        for i in range(9):
            bpy_util.box("StallA_%d_%d" % (int(side), i), _s(4.8, 0.02, 0.07), _g(side * 8.2, 0.025, 13.2 + i * 3.15), (0, 0, 0), mats["line"], park)
        for i in range(8):
            bpy_util.box("StallB_%d_%d" % (int(side), i), _s(4.4, 0.02, 0.07), _g(side * 16.4, 0.025, 14.0 + i * 3.15), (0, 0, 0), mats["line"], park)
    bpy_util.box("PlazaPad", _s(12.0, 0.04, 4.6), _g(0, 0.02, 10.8), (0, 0, 0), mats["cream"], park)
    for i in range(6):
        bpy_util.box("Cross_%d" % i, _s(0.48, 0.03, 1.7), _g(-2.4 + i * 0.95, 0.04, 9.35), (0, 0, 0), mats["line"], park)
    for i, z in enumerate((16.5, 24.5, 32.5, 40.0)):
        bpy_util.box("IslandL_%d" % i, _s(1.5, 0.22, 5.2), _g(-5.6, 0.11, z), (0, 0, 0), mats["curb"], park)
        bpy_util.box("SoilL_%d" % i, _s(1.2, 0.16, 4.8), _g(-5.6, 0.2, z), (0, 0, 0), mats["soil"], park)
        bpy_util.box("GrassL_%d" % i, _s(1.0, 0.08, 4.5), _g(-5.6, 0.28, z), (0, 0, 0), mats["grass"], park)
        _palm(veg, mats, -5.6, z, 5.6 + i * 0.15, "PalmL_%d" % i)
        bpy_util.box("IslandR_%d" % i, _s(1.5, 0.22, 5.2), _g(5.6, 0.11, z), (0, 0, 0), mats["curb"], park)
        bpy_util.box("GrassR_%d" % i, _s(1.0, 0.08, 4.5), _g(5.6, 0.28, z), (0, 0, 0), mats["grass"], park)
        _palm(veg, mats, 5.6, z, 5.9, "PalmR_%d" % i)
    _facade(facade_c, mats)
    _interior(interior, mats)
    for i, (x, z) in enumerate([(-5.6, 16.5), (5.6, 16.5), (-5.6, 28.5), (5.6, 28.5), (-5.6, 40.0), (5.6, 40.0), (-21.5, 22.0), (21.5, 22.0)], start=1):
        _lamp(lights, mats, x, z, i)
    for i, x in enumerate((-3.2, -1.6, 1.6, 3.2)):
        _bollard(park, mats, x, 11.4, i + 1)
    _bin(park, mats, -6.8, 12.4, 1)
    _bin(park, mats, 6.8, 12.4, 2)
    n_cars = _instance_cars(veh)
    if n_cars < 6:
        paints = [
            bpy_util.new_mat("SDS2_PaintW", (0.86, 0.86, 0.84), metal=0.25, rough=0.35),
            bpy_util.new_mat("SDS2_PaintS", (0.55, 0.56, 0.58), metal=0.4, rough=0.32),
            bpy_util.new_mat("SDS2_PaintK", (0.08, 0.08, 0.09), metal=0.3, rough=0.4),
            bpy_util.new_mat("SDS2_PaintR", (0.45, 0.1, 0.1), metal=0.22, rough=0.4),
            bpy_util.new_mat("SDS2_PaintB", (0.12, 0.18, 0.38), metal=0.22, rough=0.38),
        ]
        for i, (x, z, yaw) in enumerate([(-8.4, 33.8, 0.0), (8.7, 37.2, 3.16), (-28.0, 20.0, 0.2), (28.2, 19.5, 3.2), (-12.0, 44.5, 1.55), (11.5, 45.0, -1.58)]):
            bpy_util.box("FbBody_%d" % i, _s(1.85, 0.55, 4.2), _g(x, 0.45, z), (0, 0, yaw), paints[i % 5], veh)
            bpy_util.box("FbCabin_%d" % i, _s(1.5, 0.48, 1.7), _g(x, 0.95, z - 0.2), (0, 0, yaw), mats["glass"], veh)
            for s in (-1.0, 1.0):
                bpy_util.cylinder("FbW_%d_%d" % (i, int(s)), 0.3, 0.22, _g(x + s * 0.82, 0.3, z - 1.3), (1.5708, 0, yaw), mats["rubber"], veh, 10)
                bpy_util.cylinder("FbW2_%d_%d" % (i, int(s)), 0.3, 0.22, _g(x + s * 0.82, 0.3, z + 1.2), (1.5708, 0, yaw), mats["rubber"], veh, 10)
    for i, x in enumerate((-50, -34, 34, 52, -62, 64)):
        h = 20.0 + (i % 4) * 6.0
        bpy_util.box("Tower_%d" % i, _s(9.0, h, 9.0), _g(x, h * 0.5, -24.0 - (i % 3) * 7.0), (0, 0, 0), mats["concrete"] if i % 2 == 0 else mats["cream"], bg)
        for row in range(8):
            bpy_util.box("TwWin_%d_%d" % (i, row), _s(7.2, 0.9, 0.08), _g(x, 2.0 + row * 2.1, -24.0 - (i % 3) * 7.0 + 4.6), (0, 0, 0), mats["glow"] if row % 2 == 0 else mats["glass"], bg)
    bpy_util.empty("PLAYER_SPAWN_VISUAL", _g(0, 1.6, 28.5), (0, 0, 0), marks, 1.4)
    bpy_util.empty("SHOPPING_MAIN_ENTRANCE", _g(0, 1.5, 8.2), (0, 0, 0), marks)
    bpy_util.empty("INTERIOR_THRESHOLD", _g(0, 1.2, 7.2), (0, 0, 0), marks)
    bpy_util.empty("SDS_BEAUTY_SPAWN", _g(0, 1.65, 28.5), (0, math.pi, 0), marks, 0.8)
    bpy_util.empty("SDS_BEAUTY_ENTRANCE", _g(0, 2.2, 16.0), (0, math.pi, 0), marks, 0.8)
    bpy_util.empty("SDS_BEAUTY_PARKING", _g(-18.0, 8.0, 36.0), (0, 0.7, 0), marks, 0.8)
    bpy_util.empty("SDS_BEAUTY_SIDE", _g(-22.0, 3.0, 10.0), (0, 1.2, 0), marks, 0.8)
    for src in (park, facade_c, veh, veg, lights, bg, marks, interior):
        for o in list(src.objects):
            if o.name not in export.objects:
                export.objects.link(o)


def _write_authority():
    os.makedirs(os.path.dirname(AUTHORITY), exist_ok=True)
    base = "assets/reference/shopping del sol/streetview/EXTERIOR"
    lines = [
        "HUMAN_REVIEW_PENDING",
        "MAIN_FACADE_WIDE\t%s/EXTERIOR_STATION_007_ENTRADA_PARKING_1" % base,
        "MAIN_ENTRANCE_WIDE\t%s/EXTERIOR_STATION_008_ENTRADA_PARKING_2" % base,
        "MAIN_ENTRANCE_CLOSE\t%s/EXTERIOR_STATION_007_ENTRADA_PARKING_1" % base,
        "PARKING_CENTER\t%s/EXTERIOR_STATION_001_ESTACIONAMIENTO_MEDIO_01" % base,
        "PARKING_LEFT\t%s/EXTERIOR_STATION_009_PARKING_1" % base,
        "PARKING_RIGHT\t%s/EXTERIOR_STATION_010_PARKING_2" % base,
        "PARKING_ISLAND\t%s/EXTERIOR_STATION_003_ESTACIONAMIENTO_MEDIO_03" % base,
        "VEHICLE_SCALE\t%s/EXTERIOR_STATION_011_PARKING_3" % base,
        "LIGHTING\t%s/EXTERIOR_STATION_012_PARKING_4" % base,
        "SIDE_FACADE\t%s/EXTERIOR_STATION_013_PARKING_5" % base,
        "URBAN_CONTEXT\t%s/EXTERIOR_STATION_014_PARKING_6" % base,
        "NIGHT\t%s/EXTERIOR_STATION_015_PARKING_SPHERE_1" % base,
    ]
    open(AUTHORITY, "w", encoding="utf-8").write("\n".join(lines) + "\n")


def _render_beauty():
    import bpy

    os.makedirs(REVIEW, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = 1280
    sc.render.resolution_y = 720
    sc.render.filepath = os.path.join(REVIEW, "beauty_spawn.png")
    cam = bpy.data.cameras.new("SDS_BEAUTY_CAM")
    cam_ob = bpy.data.objects.new("SDS_BEAUTY_CAM", cam)
    bpy.context.scene.collection.objects.link(cam_ob)
    bpy.context.scene.camera = cam_ob
    shots = [
        ("beauty_spawn.png", (0.0, -28.5, 1.65), (1.15, 0.0, 0.0)),
        ("beauty_entrance.png", (0.0, -16.0, 2.2), (1.2, 0.0, 0.0)),
        ("beauty_parking.png", (-18.0, -36.0, 8.0), (1.0, 0.0, 0.6)),
        ("beauty_side.png", (-22.0, -10.0, 3.0), (1.2, 0.0, 1.1)),
        ("beauty_facade.png", (0.0, -22.0, 4.5), (1.1, 0.0, 0.0)),
        ("beauty_night.png", (8.0, -30.0, 2.4), (1.1, 0.0, -0.2)),
    ]
    for name, loc, rot in shots:
        cam_ob.location = loc
        cam_ob.rotation_euler = rot
        sc.render.filepath = os.path.join(REVIEW, name)
        try:
            bpy.ops.render.render(write_still=True)
            print("RENDER", name)
        except Exception as exc:
            print("RENDER_SKIP", name, exc)


def main():
    bpy_util.reset_scene()
    mats = _mats()
    build(mats)
    os.makedirs(os.path.dirname(EXPORT), exist_ok=True)
    bpy_util.hide_all_mesh()
    export = bpy_util.collection("EXPORT_GODOT")
    for o in export.objects:
        if o.type in ("MESH", "EMPTY"):
            o.hide_set(False)
            o.hide_render = False
            o.select_set(True)
    bpy_util.export_glb(EXPORT, selected=True)
    bpy_util.stats_report(EXPORT, {"asset": "shopping_del_sol_zombies_environment_v2"})
    shutil.copy2(EXPORT, PROCESSED)
    import bpy

    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    _write_authority()
    # EEVEE/OpenGL stills crashed Blender 5.2 on this GPU (nvoglv64). GLB is the deliverable.
    print("SDS_ENV_V2_BUILT", EXPORT)


if __name__ == "__main__":
    main()
