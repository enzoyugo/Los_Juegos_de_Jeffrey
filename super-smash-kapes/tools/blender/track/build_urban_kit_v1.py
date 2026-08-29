"""Shared urban visual kit for Track + Zombies. Blender 5.2 CLI."""

from __future__ import annotations

import math
import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from tools.blender.common import bpy_util  # noqa: E402

OUT = os.path.join(ROOT, "assets", "environments", "shared", "urban")
BLEND = os.path.join(ROOT, "assets", "environments", "shared", "urban", "blender", "urban_kit_v1.blend")


def _g(x, y, z):
    return (float(x), float(-z), float(y))


def _s(sx, sy, sz):
    return (float(sx), float(sz), float(sy))


def _export(col, path, extra):
    bpy_util.hide_all_mesh()
    stack = [col]
    while stack:
        c = stack.pop()
        for ch in c.children:
            stack.append(ch)
        for o in c.objects:
            o.hide_set(False)
            o.hide_render = False
            o.select_set(True)
    bpy_util.export_glb(path, selected=True)
    bpy_util.stats_report(path, extra)


def palm(col, mats, variant=1):
    h = 5.4 if variant == 1 else 6.3
    bpy_util.cylinder("PalmTrunk", 0.16 if variant == 1 else 0.2, h, _g(0, h * 0.5, 0), (0, 0, 0), mats["trunk"], col, 10)
    bpy_util.cylinder("PalmRing", 0.22, 0.18, _g(0, h - 0.15, 0), (0, 0, 0), mats["trunk"], col, 8)
    n = 7 if variant == 1 else 9
    for i in range(n):
        ang = i * (math.tau / n)
        bpy_util.box(
            "Frond_%d" % i,
            _s(0.18, 0.04, 2.1 if variant == 1 else 2.5),
            _g(math.sin(ang) * 1.05, h + 0.15, math.cos(ang) * 1.05),
            (0.35, 0.0, ang),
            mats["leaf"],
            col,
        )
    bpy_util.join_named("Frond", col)
    bpy_util.join_named("Palm", col)


def tree(col, mats, variant=1):
    h = 4.2 if variant == 1 else 5.1
    bpy_util.cylinder("TreeTrunk", 0.22, h, _g(0, h * 0.5, 0), (0, 0, 0), mats["trunk"], col, 8)
    bpy_util.ico("TreeCrown", 1.55 if variant == 1 else 1.9, _g(0, h + 0.4, 0), mats["leaf"], col, 1)
    if variant == 2:
        bpy_util.ico("TreeCrown2", 1.2, _g(0.7, h + 0.1, 0.2), mats["leaf"], col, 1)


def lamp(col, mats, double=True):
    bpy_util.cylinder("LampPole", 0.09, 7.4, _g(0, 3.7, 0), (0, 0, 0), mats["metal"], col, 8)
    bpy_util.box("LampArm", _s(2.4 if double else 1.4, 0.08, 0.08), _g(0, 7.15, 0), (0, 0, 0), mats["metal"], col)
    bpy_util.box("LampHeadL", _s(0.35, 0.16, 0.22), _g(-1.1, 7.0, 0), (0, 0, 0), mats["lamp"], col)
    if double:
        bpy_util.box("LampHeadR", _s(0.35, 0.16, 0.22), _g(1.1, 7.0, 0), (0, 0, 0), mats["lamp"], col)


def car(col, mats, kind="sedan"):
    if kind == "sedan":
        bpy_util.box("Body", _s(1.85, 0.55, 4.2), _g(0, 0.45, 0), (0, 0, 0), mats["paint"], col)
        bpy_util.box("Cabin", _s(1.55, 0.48, 1.8), _g(0, 0.95, -0.25), (0, 0, 0), mats["glass"], col)
    elif kind == "suv":
        bpy_util.box("Body", _s(1.95, 0.72, 4.5), _g(0, 0.55, 0), (0, 0, 0), mats["paint2"], col)
        bpy_util.box("Cabin", _s(1.7, 0.55, 2.1), _g(0, 1.12, 0.05), (0, 0, 0), mats["glass"], col)
    else:
        bpy_util.box("Body", _s(1.9, 0.62, 4.8), _g(0, 0.5, 0), (0, 0, 0), mats["paint3"], col)
        bpy_util.box("Cabin", _s(1.6, 0.5, 1.6), _g(0, 1.05, 0.7), (0, 0, 0), mats["glass"], col)
        bpy_util.box("Bed", _s(1.7, 0.28, 1.7), _g(0, 0.72, -1.35), (0, 0, 0), mats["metal"], col)
    for i, z in enumerate((-1.35, 1.25)):
        for s in (-1.0, 1.0):
            bpy_util.cylinder("Wheel_%d_%d" % (i, int(s)), 0.32, 0.22, _g(s * 0.85, 0.32, z), (1.5708, 0, 0), mats["rubber"], col, 10)


def building_small(col, mats, variant=1):
    w, h, d = (7.5, 8.5, 6.0) if variant == 1 else ((6.2, 10.5, 5.4) if variant == 2 else (8.4, 7.2, 6.8))
    bpy_util.box("Mass", _s(w, h, d), _g(0, h * 0.5, 0), (0, 0, 0), mats["cream"] if variant != 2 else mats["brick"], col)
    bpy_util.box("Roof", _s(w + 0.4, 0.25, d + 0.4), _g(0, h + 0.1, 0), (0, 0, 0), mats["roof"], col)
    floors = 3 if variant != 2 else 4
    cols = 3
    for fy in range(floors):
        for fx in range(cols):
            bpy_util.box(
                "Win_%d_%d" % (fy, fx),
                _s(1.15, 1.25, 0.08),
                _g(-w * 0.28 + fx * (w * 0.28), 1.6 + fy * 2.05, d * 0.5 + 0.05),
                (0, 0, 0),
                mats["glass"],
                col,
            )


def building_med(col, mats, variant=1):
    w, h, d = (11.0, 18.0, 9.0) if variant == 1 else (13.0, 22.0, 10.0)
    bpy_util.box("Mass", _s(w, h, d), _g(0, h * 0.5, 0), (0, 0, 0), mats["concrete"] if variant == 1 else mats["cream"], col)
    bpy_util.box("Band", _s(w + 0.2, 0.6, d + 0.2), _g(0, h * 0.62, 0), (0, 0, 0), mats["brick"], col)
    for fy in range(6 if variant == 1 else 7):
        for fx in range(4):
            bpy_util.box(
                "Win_%d_%d" % (fy, fx),
                _s(1.4, 1.5, 0.08),
                _g(-w * 0.32 + fx * (w * 0.21), 2.2 + fy * 2.4, d * 0.5 + 0.04),
                (0, 0, 0),
                mats["glass"],
                col,
            )


def billboard(col, mats, variant=1):
    bpy_util.box("PostL", _s(0.18, 8.2, 0.18), _g(-2.4, 4.1, 0), (0, 0, 0), mats["metal"], col)
    bpy_util.box("PostR", _s(0.18, 8.2, 0.18), _g(2.4, 4.1, 0), (0, 0, 0), mats["metal"], col)
    bpy_util.box("Board", _s(6.4, 3.2, 0.14), _g(0, 7.4, 0), (0, 0, 0), mats["brand"] if variant == 1 else mats["cyan"], col)


def fence(col, mats):
    bpy_util.box("RailTop", _s(4.0, 0.06, 0.06), _g(0, 1.15, 0), (0, 0, 0), mats["metal"], col)
    bpy_util.box("RailMid", _s(4.0, 0.06, 0.06), _g(0, 0.65, 0), (0, 0, 0), mats["metal"], col)
    for i in range(5):
        bpy_util.box("Post_%d" % i, _s(0.08, 1.25, 0.08), _g(-1.8 + i * 0.9, 0.62, 0), (0, 0, 0), mats["metal"], col)


def barrier(col, mats):
    bpy_util.box("Base", _s(2.4, 0.35, 0.28), _g(0, 0.18, 0), (0, 0, 0), mats["concrete"], col)
    bpy_util.box("Rail", _s(2.3, 0.12, 0.08), _g(0, 0.72, 0), (0, 0, 0), mats["metal"], col)


def container(col, mats, variant=1):
    bpy_util.box("Box", _s(6.0, 2.5, 2.4), _g(0, 1.25, 0), (0, 0, 0), mats["cyan"] if variant == 1 else mats["brick"], col)
    bpy_util.box("Ribs", _s(6.05, 2.5, 0.08), _g(0, 1.25, 1.2), (0, 0, 0), mats["metal"], col)


def grandstand(col, mats):
    for i in range(5):
        bpy_util.box("Step_%d" % i, _s(10.0, 0.35, 1.1), _g(0, 0.4 + i * 0.55, -i * 0.85), (0, 0, 0), mats["concrete"], col)
    bpy_util.box("Roof", _s(10.4, 0.12, 4.8), _g(0, 4.2, -1.6), (0.25, 0, 0), mats["metal"], col)
    bpy_util.box("PostL", _s(0.18, 3.8, 0.18), _g(-4.8, 1.9, 0.4), (0, 0, 0), mats["metal"], col)
    bpy_util.box("PostR", _s(0.18, 3.8, 0.18), _g(4.8, 1.9, 0.4), (0, 0, 0), mats["metal"], col)


def jeffrey_landmark(col, mats):
    bpy_util.box("ArchL", _s(0.55, 9.5, 0.55), _g(-3.2, 4.75, 0), (0, 0, 0), mats["brand"], col)
    bpy_util.box("ArchR", _s(0.55, 9.5, 0.55), _g(3.2, 4.75, 0), (0, 0, 0), mats["brand"], col)
    bpy_util.box("ArchTop", _s(7.2, 0.55, 0.55), _g(0, 9.5, 0), (0, 0, 0), mats["brand"], col)
    bpy_util.box("Disc", _s(2.2, 2.2, 0.22), _g(0, 7.2, 0.4), (0, 0, 0), mats["cyan"], col)


def crane(col, mats):
    bpy_util.box("Mast", _s(0.45, 16.0, 0.45), _g(0, 8.0, 0), (0, 0, 0), mats["metal"], col)
    bpy_util.box("Jib", _s(14.0, 0.35, 0.35), _g(4.0, 15.4, 0), (0, 0, 0), mats["cyan"], col)
    bpy_util.box("Counter", _s(3.2, 0.5, 0.5), _g(-3.2, 15.3, 0), (0, 0, 0), mats["brick"], col)


def main():
    bpy_util.reset_scene()
    mats = {
        "trunk": bpy_util.new_mat("UrbanTrunk", (0.32, 0.22, 0.12), rough=0.9),
        "leaf": bpy_util.new_mat("UrbanLeaf", (0.18, 0.42, 0.16), rough=0.78),
        "metal": bpy_util.new_mat("UrbanMetal", (0.45, 0.47, 0.5), metal=0.65, rough=0.38),
        "lamp": bpy_util.new_mat("UrbanLamp", (0.95, 0.88, 0.65), emit=2.4),
        "paint": bpy_util.new_mat("CarPaintA", (0.15, 0.22, 0.38), metal=0.25, rough=0.35),
        "paint2": bpy_util.new_mat("CarPaintB", (0.42, 0.12, 0.1), metal=0.2, rough=0.4),
        "paint3": bpy_util.new_mat("CarPaintC", (0.72, 0.72, 0.7), metal=0.15, rough=0.42),
        "glass": bpy_util.new_mat("UrbanGlass", (0.35, 0.5, 0.55), rough=0.12, metal=0.05, alpha=0.55),
        "rubber": bpy_util.new_mat("UrbanRubber", (0.05, 0.05, 0.05), rough=0.95),
        "cream": bpy_util.new_mat("UrbanCream", (0.82, 0.76, 0.64), rough=0.7),
        "brick": bpy_util.new_mat("UrbanBrick", (0.55, 0.32, 0.24), rough=0.82),
        "concrete": bpy_util.new_mat("UrbanConcrete", (0.55, 0.55, 0.52), rough=0.85),
        "roof": bpy_util.new_mat("UrbanRoof", (0.28, 0.3, 0.32), rough=0.7),
        "brand": bpy_util.new_mat("JeffreyGold", (0.85, 0.7, 0.22), emit=0.4),
        "cyan": bpy_util.new_mat("JeffreyCyan", (0.15, 0.7, 0.78), emit=0.6),
    }
    jobs = [
        ("vegetation/palm_01.glb", palm, {"variant": 1}),
        ("vegetation/palm_02.glb", palm, {"variant": 2}),
        ("vegetation/tree_01.glb", tree, {"variant": 1}),
        ("vegetation/tree_02.glb", tree, {"variant": 2}),
        ("lighting/lamp_parking.glb", lamp, {"double": True}),
        ("lighting/lamp_street.glb", lamp, {"double": False}),
        ("vehicles/car_sedan.glb", car, {"kind": "sedan"}),
        ("vehicles/car_suv.glb", car, {"kind": "suv"}),
        ("vehicles/car_pickup.glb", car, {"kind": "pickup"}),
        ("street_props/building_small_01.glb", building_small, {"variant": 1}),
        ("street_props/building_small_02.glb", building_small, {"variant": 2}),
        ("street_props/building_small_03.glb", building_small, {"variant": 3}),
        ("street_props/building_med_01.glb", building_med, {"variant": 1}),
        ("street_props/building_med_02.glb", building_med, {"variant": 2}),
        ("street_props/billboard_01.glb", billboard, {"variant": 1}),
        ("street_props/billboard_02.glb", billboard, {"variant": 2}),
        ("street_props/fence_01.glb", fence, {}),
        ("street_props/barrier_01.glb", barrier, {}),
        ("street_props/grandstand_01.glb", grandstand, {}),
        ("street_props/jeffrey_arch_01.glb", jeffrey_landmark, {}),
        ("street_props/crane_01.glb", crane, {}),
        ("industrial/container_01.glb", container, {"variant": 1}),
        ("industrial/container_02.glb", container, {"variant": 2}),
    ]
    export_root = bpy_util.collection("EXPORT_GODOT")
    bpy_util.collection("00_REFERENCE")
    bpy_util.collection("04_SCENERY")
    bpy_util.collection("05_LANDMARKS")
    for rel, fn, kwargs in jobs:
        name = os.path.splitext(os.path.basename(rel))[0]
        col = bpy_util.ensure_child(export_root, name)
        fn(col, mats, **kwargs)
        path = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        print("EXPORT_URBAN", rel)
        _export(col, path, {"asset": rel})
    import bpy

    for o in bpy.data.objects:
        o.hide_set(False)
        o.hide_render = False
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("URBAN_KIT_BUILT", len(jobs), BLEND)


if __name__ == "__main__":
    main()
