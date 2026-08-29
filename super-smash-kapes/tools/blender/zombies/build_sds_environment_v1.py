"""Shopping del Sol outdoor visual environment V1. Blender 5.2 CLI.

Scope: parking, facade, entrance, urban context, threshold. No full interior.
Visual-only export. Godot keeps gameplay collision / nav.
"""

from __future__ import annotations

import math
import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from tools.blender.common import bpy_util  # noqa: E402

BLEND = os.path.join(
    ROOT, "assets", "environments", "shopping_del_sol", "blender", "shopping_del_sol_zombies_environment_v1.blend"
)
EXPORT = os.path.join(
    ROOT,
    "assets",
    "environments",
    "shopping_del_sol",
    "blender",
    "exports",
    "shopping_del_sol_zombies_environment_v1.glb",
)
PROCESSED = os.path.join(
    ROOT,
    "assets",
    "environments",
    "shopping_del_sol",
    "processed",
    "shopping_del_sol_zombies_environment_v1.glb",
)
REF_GLB = os.path.join(
    ROOT, "assets", "environments", "shopping_del_sol", "models", "final", "shopping_del_sol_exterior_v01.glb"
)
AUTHORITY = os.path.join(ROOT, "docs", "generated", "sds_authority_images_v1.txt")


def _g(x, y, z):
    return (float(x), float(-z), float(y))


def _s(sx, sy, sz):
    return (float(sx), float(sz), float(sy))


def _mats():
    return {
        "asphalt": bpy_util.new_mat("SDS_Asphalt", (0.09, 0.09, 0.10), rough=0.95),
        "line": bpy_util.new_mat("SDS_Line", (0.86, 0.84, 0.72), rough=0.5),
        "curb": bpy_util.new_mat("SDS_Curb", (0.55, 0.53, 0.48), rough=0.8),
        "soil": bpy_util.new_mat("SDS_Soil", (0.28, 0.22, 0.14), rough=0.9),
        "grass": bpy_util.new_mat("SDS_Grass", (0.20, 0.38, 0.16), rough=0.82),
        "terra": bpy_util.new_mat("SDS_Terracotta", (0.62, 0.38, 0.24), rough=0.72),
        "cream": bpy_util.new_mat("SDS_Cream", (0.84, 0.78, 0.64), rough=0.58),
        "dark": bpy_util.new_mat("SDS_MetalDark", (0.18, 0.18, 0.2), metal=0.55, rough=0.4),
        "metal": bpy_util.new_mat("SDS_MetalLight", (0.55, 0.56, 0.58), metal=0.6, rough=0.35),
        "glass": bpy_util.new_mat("SDS_Glass", (0.42, 0.58, 0.62), rough=0.08, metal=0.08, alpha=0.42),
        "trunk": bpy_util.new_mat("SDS_Trunk", (0.32, 0.22, 0.12), rough=0.9),
        "leaf": bpy_util.new_mat("SDS_Leaf", (0.16, 0.4, 0.16), rough=0.78),
        "paint_a": bpy_util.new_mat("SDS_CarA", (0.12, 0.2, 0.38), metal=0.2, rough=0.38),
        "paint_b": bpy_util.new_mat("SDS_CarB", (0.55, 0.12, 0.1), metal=0.18, rough=0.4),
        "paint_c": bpy_util.new_mat("SDS_CarC", (0.78, 0.76, 0.7), metal=0.12, rough=0.45),
        "paint_d": bpy_util.new_mat("SDS_CarD", (0.12, 0.12, 0.12), metal=0.25, rough=0.4),
        "paint_e": bpy_util.new_mat("SDS_CarE", (0.18, 0.42, 0.28), metal=0.18, rough=0.42),
        "rubber": bpy_util.new_mat("SDS_Rubber", (0.05, 0.05, 0.05), rough=0.95),
        "lamp": bpy_util.new_mat("SDS_Lamp", (0.95, 0.88, 0.62), emit=3.2),
        "sign": bpy_util.new_mat("SDS_Sign", (0.9, 0.82, 0.55), emit=0.85),
        "concrete": bpy_util.new_mat("SDS_Concrete", (0.52, 0.52, 0.5), rough=0.86),
        "night_sky": bpy_util.new_mat("SDS_NightBand", (0.08, 0.1, 0.16), rough=1.0),
    }


def _palm(col, mats, x, z, h=5.6, name="Palm"):
    bpy_util.cylinder("%s_Trunk" % name, 0.16, h, _g(x, h * 0.5, z), (0, 0, 0), mats["trunk"], col, 8)
    for i in range(7):
        ang = i * (math.tau / 7.0)
        bpy_util.box(
            "%s_Frond_%d" % (name, i),
            _s(0.16, 0.04, 2.0),
            _g(x + math.sin(ang) * 0.95, h + 0.12, z + math.cos(ang) * 0.95),
            (0.4, 0.0, ang),
            mats["leaf"],
            col,
        )


def _tree(col, mats, x, z, name="Tree"):
    bpy_util.cylinder("%s_Trunk" % name, 0.22, 4.4, _g(x, 2.2, z), (0, 0, 0), mats["trunk"], col, 8)
    bpy_util.ico("%s_Crown" % name, 1.6, _g(x, 4.8, z), mats["leaf"], col, 1)


def _lamp(col, mats, x, z, i):
    bpy_util.cylinder("LampPole_%02d" % i, 0.09, 7.2, _g(x, 3.6, z), (0, 0, 0), mats["metal"], col, 8)
    bpy_util.box("LampArm_%02d" % i, _s(2.3, 0.08, 0.08), _g(x, 7.05, z), (0, 0, 0), mats["metal"], col)
    bpy_util.box("LampHeadL_%02d" % i, _s(0.32, 0.14, 0.22), _g(x - 1.05, 6.9, z), (0, 0, 0), mats["lamp"], col)
    bpy_util.box("LampHeadR_%02d" % i, _s(0.32, 0.14, 0.22), _g(x + 1.05, 6.9, z), (0, 0, 0), mats["lamp"], col)
    bpy_util.empty("LIGHT_PARKING_%03d" % i, _g(x, 6.7, z), (0, 0, 0), col, 0.6)


def _car(col, mats, x, y, z, yaw, kind, paint, name):
    rot = (0.0, 0.0, float(yaw))
    if kind == "sedan":
        bpy_util.box(name + "_Body", _s(1.85, 0.52, 4.15), _g(x, y + 0.45, z), rot, paint, col)
        bpy_util.box(name + "_Cabin", _s(1.5, 0.45, 1.7), _g(x, y + 0.92, z - 0.2), rot, mats["glass"], col)
    elif kind == "suv":
        bpy_util.box(name + "_Body", _s(1.95, 0.7, 4.45), _g(x, y + 0.55, z), rot, paint, col)
        bpy_util.box(name + "_Cabin", _s(1.65, 0.52, 2.0), _g(x, y + 1.1, z), rot, mats["glass"], col)
    else:
        bpy_util.box(name + "_Body", _s(1.9, 0.6, 4.7), _g(x, y + 0.5, z), rot, paint, col)
        bpy_util.box(name + "_Cabin", _s(1.55, 0.48, 1.55), _g(x, y + 1.02, z + 0.65), rot, mats["glass"], col)
    for i, lz in enumerate((-1.3, 1.2)):
        for s in (-1.0, 1.0):
            bpy_util.cylinder(
                "%s_W_%d_%d" % (name, i, int(s)),
                0.3,
                0.2,
                _g(x + s * 0.82, y + 0.3, z + lz),
                (1.5708, 0.0, yaw),
                mats["rubber"],
                col,
                8,
            )


def _island(col, mats, x, z, sx, sz, name):
    bpy_util.box(name + "_Curb", _s(sx, 0.22, sz), _g(x, 0.11, z), (0, 0, 0), mats["curb"], col)
    bpy_util.box(name + "_Soil", _s(sx - 0.25, 0.16, sz - 0.25), _g(x, 0.2, z), (0, 0, 0), mats["soil"], col)
    bpy_util.box(name + "_Grass", _s(sx - 0.4, 0.08, sz - 0.4), _g(x, 0.28, z), (0, 0, 0), mats["grass"], col)


def build(mats):
    bpy_util.collection("00_REFERENCE")
    block = bpy_util.collection("01_BLOCKOUT")
    facade_c = bpy_util.collection("02_FACADE")
    park = bpy_util.collection("03_PARKING")
    veh = bpy_util.collection("04_VEHICLES")
    veg = bpy_util.collection("05_VEGETATION")
    lights = bpy_util.collection("06_LIGHTS")
    bg = bpy_util.collection("07_BACKGROUND")
    marks = bpy_util.collection("08_MARKERS")
    export = bpy_util.collection("EXPORT_GODOT")

    # Parking plane — open sky, no roof.
    bpy_util.box("ParkingAsphalt", _s(86.0, 0.12, 56.0), _g(0, -0.06, 26.0), (0, 0, 0), mats["asphalt"], park)
    bpy_util.box("ApproachAsphalt", _s(14.0, 0.1, 8.0), _g(0, -0.05, 10.0), (0, 0, 0), mats["asphalt"], park)
    # Center aisle dashes.
    for z in range(14, 44, 3):
        bpy_util.box("Dash_%d" % z, _s(0.16, 0.02, 1.35), _g(0, 0.03, float(z)), (0, 0, 0), mats["line"], park)
    # Stall lines.
    for side in (-1.0, 1.0):
        x0 = side * 8.2
        for i in range(9):
            z = 13.2 + i * 3.15
            bpy_util.box("StallA_%d_%d" % (int(side), i), _s(4.8, 0.02, 0.07), _g(x0, 0.025, z), (0, 0, 0), mats["line"], park)
        x1 = side * 16.4
        for i in range(8):
            z = 14.0 + i * 3.15
            bpy_util.box("StallB_%d_%d" % (int(side), i), _s(4.4, 0.02, 0.07), _g(x1, 0.025, z), (0, 0, 0), mats["line"], park)
    # Plaza / crosswalk.
    bpy_util.box("Plaza", _s(12.0, 0.04, 4.6), _g(0, 0.02, 10.8), (0, 0, 0), mats["cream"], park)
    for i in range(6):
        bpy_util.box("Cross_%d" % i, _s(0.48, 0.03, 1.7), _g(-2.4 + i * 0.95, 0.04, 9.35), (0, 0, 0), mats["line"], park)
    # Islands.
    for i, z in enumerate((16.5, 24.5, 32.5, 40.0)):
        _island(park, mats, -5.6, z, 1.5, 5.2, "IslandL_%d" % i)
        _island(park, mats, 5.6, z, 1.5, 5.2, "IslandR_%d" % i)
        _palm(veg, mats, -5.6, z, 5.4 + (i % 2) * 0.4, "PalmL_%d" % i)
        _palm(veg, mats, 5.6, z, 5.7 + (i % 2) * 0.3, "PalmR_%d" % i)
    for i, z in enumerate((18.0, 28.0, 38.0)):
        _island(park, mats, -21.5, z, 1.8, 6.0, "IslandOL_%d" % i)
        _island(park, mats, 21.5, z, 1.8, 6.0, "IslandOR_%d" % i)
        _tree(veg, mats, -21.5, z, "TreeL_%d" % i)
        _palm(veg, mats, 21.5, z, 6.1, "PalmO_%d" % i)
    _island(park, mats, -3.4, 12.2, 1.8, 1.4, "PlanterL")
    _island(park, mats, 3.4, 12.2, 1.8, 1.4, "PlanterR")
    _palm(veg, mats, -3.4, 12.2, 4.8, "PalmEntL")
    _palm(veg, mats, 3.4, 12.2, 5.0, "PalmEntR")

    # Facade wings + entrance (Godot z≈8.7).
    bpy_util.box("FacadeWingL", _s(18.0, 10.4, 1.7), _g(-14.5, 5.2, 8.7), (0, 0, 0), mats["terra"], facade_c)
    bpy_util.box("FacadeWingR", _s(18.0, 10.4, 1.7), _g(14.5, 5.2, 8.7), (0, 0, 0), mats["terra"], facade_c)
    bpy_util.box("FacadeBandL", _s(16.0, 1.35, 0.35), _g(-14.5, 9.6, 9.45), (0, 0, 0), mats["dark"], facade_c)
    bpy_util.box("FacadeBandR", _s(16.0, 1.35, 0.35), _g(14.5, 9.6, 9.45), (0, 0, 0), mats["dark"], facade_c)
    for side in (-1.0, 1.0):
        for i in range(4):
            bpy_util.box(
                "Win_%s_%d" % ("L" if side < 0 else "R", i),
                _s(2.35, 2.15, 0.08),
                _g(side * (8.2 + i * 3.2), 6.4, 9.55),
                (0, 0, 0),
                mats["glass"],
                facade_c,
            )
            bpy_util.box(
                "WinLow_%s_%d" % ("L" if side < 0 else "R", i),
                _s(2.35, 1.75, 0.08),
                _g(side * (8.2 + i * 3.2), 3.4, 9.55),
                (0, 0, 0),
                mats["glass"],
                facade_c,
            )
    # Entrance frame / glass / mullions / canopy.
    bpy_util.box("EntranceCanopy", _s(7.6, 0.32, 1.9), _g(0, 5.65, 8.55), (0, 0, 0), mats["cream"], facade_c)
    bpy_util.box("EntrancePoleL", _s(0.42, 6.4, 1.35), _g(-3.6, 3.2, 8.55), (0, 0, 0), mats["cream"], facade_c)
    bpy_util.box("EntrancePoleR", _s(0.42, 6.4, 1.35), _g(3.6, 3.2, 8.55), (0, 0, 0), mats["cream"], facade_c)
    bpy_util.box("EntranceGlass", _s(6.5, 5.5, 0.1), _g(0, 3.35, 8.72), (0, 0, 0), mats["glass"], facade_c)
    for i, x in enumerate((-2.1, -0.7, 0.7, 2.1)):
        bpy_util.box("Mullion_%d" % i, _s(0.08, 5.4, 0.12), _g(x, 3.3, 8.78), (0, 0, 0), mats["dark"], facade_c)
    bpy_util.box("DoorL", _s(1.35, 2.6, 0.08), _g(-0.75, 1.35, 8.82), (0, 0, 0), mats["glass"], facade_c)
    bpy_util.box("DoorR", _s(1.35, 2.6, 0.08), _g(0.75, 1.35, 8.82), (0, 0, 0), mats["glass"], facade_c)
    bpy_util.box("SignBand", _s(8.4, 1.1, 0.22), _g(0, 6.55, 8.95), (0, 0, 0), mats["sign"], facade_c)
    bpy_util.box("SunDisc", _s(1.55, 1.55, 0.16), _g(0, 7.55, 8.9), (0, 0, 0), mats["sign"], facade_c)
    bpy_util.box("CanopyFront", _s(8.2, 0.12, 2.4), _g(0, 4.95, 9.4), (0, 0, 0), mats["cream"], facade_c)
    # Interior threshold volume (dark, no ceiling over parking).
    bpy_util.box("ThresholdFloor", _s(8.0, 0.08, 4.0), _g(0, 0.0, 6.2), (0, 0, 0), mats["concrete"], facade_c)
    bpy_util.box("ThresholdDark", _s(7.6, 4.6, 0.2), _g(0, 2.4, 6.4), (0, 0, 0), mats["dark"], facade_c)

    # Lamps
    lamp_pos = [
        (-5.6, 16.5),
        (5.6, 16.5),
        (-5.6, 28.5),
        (5.6, 28.5),
        (-5.6, 40.0),
        (5.6, 40.0),
        (-21.5, 22.0),
        (21.5, 22.0),
        (-21.5, 34.0),
        (21.5, 34.0),
    ]
    for i, (x, z) in enumerate(lamp_pos, start=1):
        _lamp(lights, mats, x, z, i)
    bpy_util.empty("LIGHT_ENTRANCE_001", _g(0, 3.6, 9.4), (0, 0, 0), lights, 0.8)
    bpy_util.empty("LIGHT_ENTRANCE_002", _g(-10.0, 0.6, 10.2), (0, 0, 0), lights, 0.5)
    bpy_util.empty("LIGHT_ENTRANCE_003", _g(10.0, 0.6, 10.2), (0, 0, 0), lights, 0.5)

    paints = [mats["paint_a"], mats["paint_b"], mats["paint_c"], mats["paint_d"], mats["paint_e"]]
    parked = [
        (-8.4, 14.6, 0.04, "suv", 0),
        (-8.2, 17.8, -0.03, "sedan", 1),
        (-8.5, 24.2, 0.06, "pickup", 2),
        (-8.3, 27.4, 0.02, "suv", 3),
        (-8.6, 33.8, -0.05, "sedan", 4),
        (-16.6, 16.0, 0.1, "suv", 1),
        (-16.4, 22.4, -0.08, "sedan", 2),
        (-16.8, 31.6, 0.05, "pickup", 0),
        (8.5, 15.0, 3.18, "sedan", 0),
        (8.3, 21.4, 3.10, "suv", 2),
        (8.6, 24.6, 3.20, "pickup", 1),
        (8.4, 30.8, 3.08, "suv", 3),
        (8.7, 37.2, 3.16, "sedan", 4),
        (16.5, 18.2, -1.52, "suv", 3),
        (16.8, 27.0, -1.58, "sedan", 1),
        (16.4, 35.4, -1.48, "pickup", 2),
        (-28.0, 20.0, 0.2, "suv", 4),
        (-28.4, 26.5, 0.05, "sedan", 0),
        (28.2, 19.5, 3.2, "pickup", 1),
        (27.8, 28.8, 3.05, "suv", 2),
        (-12.0, 44.5, 1.55, "suv", 3),
        (11.5, 45.0, -1.58, "sedan", 4),
    ]
    for i, row in enumerate(parked):
        _car(veh, mats, row[0], 0.0, row[1], row[2], row[3], paints[row[4] % 5], "Car_%02d" % i)

    # Urban background — far, not beside the drive aisle.
    for i, x in enumerate((-48, -32, 32, 50, -58, 62)):
        h = 18.0 + (i % 4) * 5.0
        bpy_util.box(
            "Tower_%d" % i,
            _s(8.0 + i * 0.4, h, 8.0),
            _g(x, h * 0.5, -22.0 - (i % 3) * 6.0),
            (0, 0, 0),
            mats["concrete"] if i % 2 == 0 else mats["cream"],
            bg,
        )
    bpy_util.box("StreetEdgeL", _s(0.4, 0.8, 40.0), _g(-40.0, 0.4, 22.0), (0, 0, 0), mats["curb"], bg)
    bpy_util.box("StreetEdgeR", _s(0.4, 0.8, 40.0), _g(40.0, 0.4, 22.0), (0, 0, 0), mats["curb"], bg)

    bpy_util.empty("PLAYER_SPAWN_VISUAL", _g(0, 1.6, 28.5), (0, 0, 0), marks, 1.4)
    bpy_util.empty("SHOPPING_MAIN_ENTRANCE", _g(0, 1.5, 8.2), (0, 0, 0), marks)
    bpy_util.empty("SHOPPING_CENTER", _g(0, 2.0, 0.0), (0, 0, 0), marks)
    bpy_util.empty("PARKING_CENTER", _g(0, 1.0, 26.0), (0, 0, 0), marks)
    bpy_util.empty("INTERIOR_THRESHOLD", _g(0, 1.2, 7.2), (0, 0, 0), marks)
    bpy_util.empty("ZOMBIE_APPROACH_A", _g(-16.5, 0.9, 36.0), (0, 0, 0), marks)
    bpy_util.empty("ZOMBIE_APPROACH_B", _g(16.5, 0.9, 36.5), (0, 0, 0), marks)

    # Link key collections under EXPORT_GODOT for a single visible export.
    for src in (park, facade_c, veh, veg, lights, bg, marks, block):
        for o in list(src.objects):
            if o.name not in export.objects:
                export.objects.link(o)

    if os.path.isfile(REF_GLB):
        try:
            ref = bpy_util.collection("00_REFERENCE")
            imported = bpy_util.import_glb(REF_GLB)
            for o in imported:
                bpy_util.link(o, ref)
                o.hide_set(True)
                o.hide_render = True
                o.name = "REF_" + o.name[:80]
            print("SDS_REF_IMPORTED", len(imported))
        except Exception as exc:
            print("SDS_REF_IMPORT_SKIP", type(exc).__name__, exc)


def _write_authority():
    os.makedirs(os.path.dirname(AUTHORITY), exist_ok=True)
    lines = [
        "HUMAN_REVIEW_PENDING",
        "REFERENCE_ONLY — never imported into Godot runtime.",
        "assets/reference/shopping del sol/photos/references/shopping-del-sol.jpg",
        "assets/reference/shopping del sol/photos/references/shopping-del-sol (1).jpg",
        "assets/reference/shopping del sol/photos/references/shopping-del-sol (2).jpg",
        "coverage: parking_center parking_left parking_right facade_wide entrance_wide entrance_close islands lamps vehicles street_edge towers",
    ]
    open(AUTHORITY, "w", encoding="utf-8").write("\n".join(lines) + "\n")


def main():
    bpy_util.reset_scene()
    mats = _mats()
    build(mats)
    os.makedirs(os.path.dirname(EXPORT), exist_ok=True)
    os.makedirs(os.path.dirname(PROCESSED), exist_ok=True)
    bpy_util.hide_all_mesh()
    export = bpy_util.collection("EXPORT_GODOT")
    for o in export.objects:
        if o.type == "MESH":
            o.hide_set(False)
            o.hide_render = False
            o.select_set(True)
    bpy_util.export_glb(EXPORT, selected=True)
    bpy_util.stats_report(EXPORT, {"asset": "shopping_del_sol_zombies_environment_v1"})
    import shutil

    shutil.copy2(EXPORT, PROCESSED)
    import bpy

    for o in bpy.data.objects:
        if not o.name.startswith("REF_"):
            o.hide_set(False)
            o.hide_render = False
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    _write_authority()
    print("SDS_ENV_BUILT", EXPORT)


if __name__ == "__main__":
    main()
