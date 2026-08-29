"""Stylized zombie + pistol foundation. Blender 5.2 CLI. Not wired as canonical gameplay art yet."""

from __future__ import annotations

import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from tools.blender.common import bpy_util  # noqa: E402

OUT_Z = os.path.join(ROOT, "assets", "characters", "zombies", "processed", "zombie_stylized_v1.glb")
OUT_P = os.path.join(ROOT, "assets", "weapons", "processed", "pistol_stylized_v1.glb")
BLEND = os.path.join(ROOT, "assets", "characters", "zombies", "blender", "zombie_pistol_foundation_v1.blend")


def _g(x, y, z):
    return (float(x), float(-z), float(y))


def _s(sx, sy, sz):
    return (float(sx), float(sz), float(sy))


def pistol(col, mats):
    bpy_util.box("Slide", _s(0.32, 0.14, 0.22), _g(0, 0.22, 0.05), (0, 0, 0), mats["slide"], col)
    bpy_util.box("Frame", _s(0.28, 0.1, 0.18), _g(0, 0.12, 0.02), (0, 0, 0), mats["frame"], col)
    bpy_util.box("Grip", _s(0.18, 0.28, 0.12), _g(0, -0.08, -0.04), (0.35, 0, 0), mats["grip"], col)
    bpy_util.box("Guard", _s(0.04, 0.12, 0.14), _g(0, 0.02, 0.1), (0, 0, 0), mats["frame"], col)
    bpy_util.cylinder("Barrel", 0.035, 0.16, _g(0, 0.2, 0.22), (1.5708, 0, 0), mats["slide"], col, 10)
    bpy_util.box("SightF", _s(0.02, 0.05, 0.02), _g(0, 0.3, 0.18), (0, 0, 0), mats["sight"], col)
    bpy_util.box("SightR", _s(0.06, 0.04, 0.02), _g(0, 0.3, -0.04), (0, 0, 0), mats["sight"], col)
    bpy_util.box("Mag", _s(0.12, 0.16, 0.08), _g(0, -0.18, 0.0), (0.2, 0, 0), mats["frame"], col)


def zombie(col, mats):
    bpy_util.ico("Head", 0.16, _g(0, 1.68, 0.02), mats["skin"], col, 2)
    bpy_util.box("Jaw", _s(0.12, 0.06, 0.1), _g(0, 1.54, 0.06), (0.2, 0, 0), mats["skin"], col)
    bpy_util.cylinder("Neck", 0.06, 0.12, _g(0, 1.48, 0), (0, 0, 0), mats["skin"], col, 8)
    bpy_util.box("Torso", _s(0.42, 0.55, 0.22), _g(0, 1.18, 0), (0, 0, 0), mats["cloth"], col)
    bpy_util.box("Pelvis", _s(0.34, 0.18, 0.2), _g(0, 0.82, 0), (0, 0, 0), mats["cloth2"], col)
    bpy_util.cylinder("ArmL", 0.055, 0.32, _g(-0.32, 1.22, 0), (0, 0, 0.4), mats["skin"], col, 8)
    bpy_util.cylinder("ArmR", 0.055, 0.32, _g(0.32, 1.22, 0), (0, 0, -0.4), mats["skin"], col, 8)
    bpy_util.ico("HandL", 0.055, _g(-0.42, 0.98, 0.04), mats["skin"], col, 1)
    bpy_util.ico("HandR", 0.055, _g(0.42, 0.98, 0.04), mats["skin"], col, 1)
    bpy_util.cylinder("ThighL", 0.08, 0.38, _g(-0.12, 0.55, 0), (0, 0, 0), mats["cloth2"], col, 8)
    bpy_util.cylinder("ThighR", 0.08, 0.38, _g(0.12, 0.55, 0), (0, 0, 0), mats["cloth2"], col, 8)
    bpy_util.cylinder("ShinL", 0.06, 0.36, _g(-0.12, 0.22, 0), (0, 0, 0), mats["skin"], col, 8)
    bpy_util.cylinder("ShinR", 0.06, 0.36, _g(0.12, 0.22, 0), (0, 0, 0), mats["skin"], col, 8)
    bpy_util.box("FootL", _s(0.1, 0.08, 0.22), _g(-0.12, 0.04, 0.06), (0, 0, 0), mats["cloth"], col)
    bpy_util.box("FootR", _s(0.1, 0.08, 0.22), _g(0.12, 0.04, 0.06), (0, 0, 0), mats["cloth"], col)
    bpy_util.ico("ShoulderL", 0.09, _g(-0.24, 1.42, 0), mats["cloth"], col, 1)
    bpy_util.ico("ShoulderR", 0.09, _g(0.24, 1.42, 0), mats["cloth"], col, 1)


def _export(col, path, extra):
    bpy_util.hide_all_mesh()
    for o in col.objects:
        o.hide_set(False)
        o.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy_util.export_glb(path, selected=True)
    bpy_util.stats_report(path, extra)


def main():
    bpy_util.reset_scene()
    mats = {
        "slide": bpy_util.new_mat("PistolSlide", (0.18, 0.18, 0.2), metal=0.7, rough=0.28),
        "frame": bpy_util.new_mat("PistolFrame", (0.12, 0.12, 0.13), metal=0.4, rough=0.4),
        "grip": bpy_util.new_mat("PistolGrip", (0.08, 0.08, 0.08), rough=0.7),
        "sight": bpy_util.new_mat("PistolSight", (0.7, 0.7, 0.72), metal=0.5, rough=0.3),
        "skin": bpy_util.new_mat("ZombieSkin", (0.42, 0.48, 0.32), rough=0.75),
        "cloth": bpy_util.new_mat("ZombieCloth", (0.18, 0.16, 0.14), rough=0.85),
        "cloth2": bpy_util.new_mat("ZombieCloth2", (0.12, 0.14, 0.18), rough=0.82),
    }
    pcol = bpy_util.collection("PISTOL")
    zcol = bpy_util.collection("ZOMBIE")
    pistol(pcol, mats)
    zombie(zcol, mats)
    _export(pcol, OUT_P, {"asset": "pistol_stylized_v1"})
    _export(zcol, OUT_Z, {"asset": "zombie_stylized_v1"})
    import bpy

    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("ZOMBIE_PISTOL_FOUNDATION", OUT_Z, OUT_P)


if __name__ == "__main__":
    main()
