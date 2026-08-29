"""Track/shared urban kit V2 — mid-poly vegetation, windowed buildings, Jeffrey landmark."""

from __future__ import annotations

import math
import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from tools.blender.common import bpy_util  # noqa: E402

OUT = os.path.join(ROOT, "assets", "environments", "shared", "urban", "processed")
BLEND = os.path.join(ROOT, "assets", "environments", "shared", "urban", "blender", "urban_kit_v2.blend")
REVIEW = os.path.join(ROOT, "docs", "generated", "v9_visual_review", "track")


def _g(x, y, z):
    return (float(x), float(-z), float(y))


def _s(sx, sy, sz):
    return (float(sx), float(sz), float(sy))


def _export(col, path):
    bpy_util.hide_all_mesh()
    for o in col.objects:
        o.hide_set(False)
        o.hide_render = False
        o.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy_util.export_glb(path, selected=True)
    bpy_util.stats_report(path, {"kit": "urban_v2"})


def main():
    bpy_util.reset_scene()
    mats = {
        "trunk": bpy_util.new_mat("U2_Trunk", (0.32, 0.2, 0.1), rough=0.9),
        "leaf": bpy_util.new_mat("U2_Leaf", (0.16, 0.42, 0.14), rough=0.7),
        "leaf2": bpy_util.new_mat("U2_Leaf2", (0.22, 0.38, 0.12), rough=0.72),
        "cream": bpy_util.new_mat("U2_Cream", (0.82, 0.78, 0.68), rough=0.55),
        "brick": bpy_util.new_mat("U2_Brick", (0.48, 0.28, 0.2), rough=0.8),
        "glass": bpy_util.new_mat("U2_Glass", (0.35, 0.5, 0.55), rough=0.1, metal=0.1, alpha=0.4),
        "glow": bpy_util.new_mat("U2_WinGlow", (0.95, 0.82, 0.5), emit=1.6),
        "gold": bpy_util.new_mat("U2_Gold", (0.86, 0.7, 0.22), metal=0.55, rough=0.32, emit=0.25),
        "black": bpy_util.new_mat("U2_Black", (0.06, 0.06, 0.07), metal=0.3, rough=0.4),
        "metal": bpy_util.new_mat("U2_Metal", (0.5, 0.52, 0.54), metal=0.7, rough=0.3),
        "concrete": bpy_util.new_mat("U2_Conc", (0.5, 0.5, 0.48), rough=0.86),
    }
    root = bpy_util.collection("EXPORT_GODOT")

    def palm(name, h, n):
        col = bpy_util.ensure_child(root, name)
        bpy_util.cylinder("Trunk", 0.17, h, _g(0, h * 0.5, 0), (0, 0, 0), mats["trunk"], col, 12)
        for i in range(n):
            ang = i * (math.tau / n)
            bpy_util.box("Frond_%d" % i, _s(0.2, 0.03, 2.5), _g(math.sin(ang) * 1.1, h + 0.15, math.cos(ang) * 1.1), (0.4, 0.1, ang), mats["leaf"], col)
        _export(col, os.path.join(OUT, "vegetation", name.lower() + ".glb"))

    palm("palm_v2_01", 5.8, 12)
    palm("palm_v2_02", 6.6, 14)

    def tree(name, h):
        col = bpy_util.ensure_child(root, name)
        bpy_util.cylinder("Trunk", 0.22, h, _g(0, h * 0.5, 0), (0, 0, 0), mats["trunk"], col, 10)
        bpy_util.ico("A", 1.65, _g(0, h + 0.5, 0), mats["leaf"], col, 2)
        bpy_util.ico("B", 1.1, _g(0.65, h + 0.1, 0.2), mats["leaf2"], col, 1)
        _export(col, os.path.join(OUT, "vegetation", name.lower() + ".glb"))

    tree("tree_v2_01", 4.4)
    tree("tree_v2_02", 5.2)

    def building(name, w, h, d, mat_wall):
        col = bpy_util.ensure_child(root, name)
        bpy_util.box("Mass", _s(w, h, d), _g(0, h * 0.5, 0), (0, 0, 0), mat_wall, col)
        bpy_util.box("Roof", _s(w + 0.3, 0.25, d + 0.3), _g(0, h + 0.1, 0), (0, 0, 0), mats["concrete"], col)
        cols = max(3, int(w / 2.2))
        rows = max(3, int(h / 2.4))
        for r in range(rows):
            for c in range(cols):
                x = -w * 0.35 + c * (w * 0.7 / max(cols - 1, 1))
                y = 1.4 + r * (h - 2.2) / max(rows - 1, 1)
                bpy_util.box("W_%d_%d" % (r, c), _s(0.7, 0.9, 0.08), _g(x, y, d * 0.51), (0, 0, 0), mats["glow"] if (r + c) % 2 == 0 else mats["glass"], col)
        bpy_util.box("Door", _s(1.1, 2.1, 0.1), _g(0, 1.05, d * 0.52), (0, 0, 0), mats["black"], col)
        _export(col, os.path.join(OUT, "architecture", name.lower() + ".glb"))

    os.makedirs(os.path.join(OUT, "architecture"), exist_ok=True)
    building("building_shop_01", 8.0, 7.2, 6.0, mats["brick"])
    building("building_shop_02", 10.0, 6.4, 7.0, mats["cream"])
    building("building_mid_01", 12.0, 16.0, 10.0, mats["cream"])
    building("building_mid_02", 11.0, 18.5, 9.0, mats["brick"])
    building("tower_01", 10.0, 28.0, 10.0, mats["concrete"])
    building("tower_02", 9.0, 34.0, 9.0, mats["cream"])

    col = bpy_util.ensure_child(root, "jeffrey_arch_v2")
    bpy_util.box("PostL", _s(0.7, 8.4, 0.7), _g(-4.2, 4.2, 0), (0, 0, 0), mats["black"], col)
    bpy_util.box("PostR", _s(0.7, 8.4, 0.7), _g(4.2, 4.2, 0), (0, 0, 0), mats["black"], col)
    bpy_util.box("Beam", _s(10.0, 1.1, 0.8), _g(0, 8.6, 0), (0, 0, 0), mats["gold"], col)
    bpy_util.box("Sign", _s(8.4, 1.6, 0.2), _g(0, 10.0, 0), (0, 0, 0), mats["black"], col)
    bpy_util.box("GoldBar", _s(7.6, 0.18, 0.22), _g(0, 10.0, 0.12), (0, 0, 0), mats["gold"], col)
    bpy_util.box("Island", _s(1.4, 1.4, 0.16), _g(0, 10.0, 0.22), (0, 0, 0), mats["gold"], col)
    _export(col, os.path.join(OUT, "landmarks", "jeffrey_arch_v2.glb"))

    col = bpy_util.ensure_child(root, "grandstand_v2")
    for i in range(5):
        bpy_util.box("Step_%d" % i, _s(10.0, 0.4, 1.4), _g(0, 0.3 + i * 0.55, -i * 0.9), (0, 0, 0), mats["concrete"], col)
    bpy_util.box("Roof", _s(11.0, 0.2, 5.5), _g(0, 4.2, -1.8), (0, 0, 0), mats["black"], col)
    _export(col, os.path.join(OUT, "landmarks", "grandstand_v2.glb"))

    import bpy

    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("URBAN_KIT_V2_BUILT", OUT)


if __name__ == "__main__":
    main()
