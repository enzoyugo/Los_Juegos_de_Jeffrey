"""Build 15 m Track visual GLBs from widened sidecar JSON. Blender 5.2 CLI.

Does not overwrite 11 m sources. One .blend holds every module collection.
"""

from __future__ import annotations

import json
import math
import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from tools.blender.common import bpy_util  # noqa: E402

DST = os.path.join(ROOT, "assets", "track", "processed", "kit_v8_15m")
BLEND = os.path.join(ROOT, "assets", "track", "blender", "track_kit_v8_15m.blend")
ASPHALT_W = 15.0
SHOULDER_W = 0.9


def _euler(yaw, pitch=0.0):
    return (float(pitch), 0.0, float(yaw))


def _godot_to_blender(x, y, z):
    return (float(x), float(-z), float(y))


def _size_godot_to_blender(sx, sy, sz):
    return (float(sx), float(sz), float(sy))


def _right(yaw):
    return math.cos(yaw), -math.sin(yaw)


def _mats():
    return {
        "asphalt": bpy_util.new_mat("Asphalt15", (0.07, 0.075, 0.08), rough=0.94),
        "asphalt_wear": bpy_util.new_mat("AsphaltWear15", (0.11, 0.11, 0.12), rough=0.88),
        "shoulder": bpy_util.new_mat("Shoulder15", (0.28, 0.26, 0.22), rough=0.86),
        "rail_metal": bpy_util.new_mat("RailMetal15", (0.62, 0.64, 0.66), metal=0.72, rough=0.32),
        "rail_concrete": bpy_util.new_mat("RailConcrete15", (0.42, 0.42, 0.40), rough=0.78),
        "mark": bpy_util.new_mat("Mark15", (0.86, 0.84, 0.74), rough=0.48),
        "boost": bpy_util.new_mat("Boost15", (0.12, 0.78, 0.88), emit=1.4, rough=0.35),
        "gantry": bpy_util.new_mat("Gantry15", (0.16, 0.16, 0.18), metal=0.45, rough=0.4),
        "lamp_off": bpy_util.new_mat("GantryLampOff", (0.12, 0.04, 0.04), rough=0.4),
        "lamp_on": bpy_util.new_mat("GantryLampOn", (0.85, 0.18, 0.08), emit=2.2),
        "cyan": bpy_util.new_mat("JeffreyCyan", (0.15, 0.72, 0.78), emit=0.9),
        "brand": bpy_util.new_mat("JeffreyBrand", (0.85, 0.72, 0.22), emit=0.35, rough=0.45),
    }


def _road_visual(box, mats, road_col, n_road):
    origin = list(box.get("origin") or [0, 0, 0])
    size = list(box.get("size") or [16.8, 0.20, 2.0])
    yaw = float(box.get("yaw", 0.0))
    pitch = float(box.get("pitch", 0.0))
    rot = _euler(yaw, pitch)
    loc = _godot_to_blender(origin[0], origin[1], origin[2])
    asphalt = bpy_util.box(
        "ROAD_%02d" % n_road,
        _size_godot_to_blender(ASPHALT_W, max(size[1], 0.08), size[2]),
        loc,
        rot,
        mats["asphalt"],
        road_col,
    )
    rx, rz = _right(yaw)
    n_sh = 0
    for sign in (-1.0, 1.0):
        n_sh += 1
        lat = ASPHALT_W * 0.5 + SHOULDER_W * 0.5
        ox = origin[0] + sign * lat * rx
        oz = origin[2] + sign * lat * rz
        bpy_util.box(
            "SHOULDER_%02d_%d" % (n_road, n_sh),
            _size_godot_to_blender(SHOULDER_W, max(size[1] * 0.85, 0.06), size[2]),
            _godot_to_blender(ox, origin[1] + 0.01, oz),
            rot,
            mats["shoulder"],
            road_col,
        )
    edge_lat = ASPHALT_W * 0.5 - 0.08
    for sign in (-1.0, 1.0):
        ox = origin[0] + sign * edge_lat * rx
        oz = origin[2] + sign * edge_lat * rz
        bpy_util.box(
            "EDGE_%02d_%s" % (n_road, "L" if sign < 0 else "R"),
            _size_godot_to_blender(0.10, 0.02, size[2] * 0.92),
            _godot_to_blender(ox, origin[1] + size[1] * 0.5 + 0.015, oz),
            rot,
            mats["mark"],
            road_col,
        )
    return asphalt


def _rail_visual(box, mats, rail_col, n_rail):
    origin = list(box.get("origin") or [0, 0, 0])
    size = list(box.get("size") or [0.22, 0.9, 2.0])
    yaw = float(box.get("yaw", 0.0))
    pitch = float(box.get("pitch", 0.0))
    rot = _euler(yaw, pitch)
    loc_base = _godot_to_blender(origin[0], 0.18, origin[2])
    bpy_util.box(
        "RAILBASE_%02d" % n_rail,
        _size_godot_to_blender(0.28, 0.36, size[2]),
        loc_base,
        rot,
        mats["rail_concrete"],
        rail_col,
    )
    bpy_util.box(
        "RAILMETAL_%02d" % n_rail,
        _size_godot_to_blender(0.08, 0.12, size[2] * 0.98),
        _godot_to_blender(origin[0], 0.72, origin[2]),
        rot,
        mats["rail_metal"],
        rail_col,
    )
    length = max(float(size[2]), 1.0)
    posts = max(int(length / 2.2), 1)
    for i in range(posts):
        t = (i + 0.5) / float(posts)
        along = (t - 0.5) * length
        fx, fz = -math.sin(yaw), -math.cos(yaw)
        px = origin[0] + along * fx
        pz = origin[2] + along * fz
        bpy_util.box(
            "RAILPOST_%02d_%d" % (n_rail, i),
            _size_godot_to_blender(0.07, 0.78, 0.07),
            _godot_to_blender(px, 0.42, pz),
            rot,
            mats["rail_metal"],
            rail_col,
        )


def _gantry(name_prefix, z_godot, w, mats, col, lamp=False):
    bpy_util.box(
        name_prefix + "_BEAM",
        _size_godot_to_blender(w + 3.2, 0.38, 0.38),
        _godot_to_blender(0, 4.35, z_godot),
        (0, 0, 0),
        mats["gantry"],
        col,
    )
    bpy_util.box(
        name_prefix + "_POLE_L",
        _size_godot_to_blender(0.24, 4.5, 0.24),
        _godot_to_blender(-(w * 0.5 + 1.2), 2.25, z_godot),
        (0, 0, 0),
        mats["gantry"],
        col,
    )
    bpy_util.box(
        name_prefix + "_POLE_R",
        _size_godot_to_blender(0.24, 4.5, 0.24),
        _godot_to_blender(w * 0.5 + 1.2, 2.25, z_godot),
        (0, 0, 0),
        mats["gantry"],
        col,
    )
    bpy_util.box(
        name_prefix + "_BRAND",
        _size_godot_to_blender(3.6, 0.55, 0.12),
        _godot_to_blender(0, 4.85, z_godot - 0.15),
        (0, 0, 0),
        mats["brand"],
        col,
    )
    if lamp:
        for i, x in enumerate((-0.9, 0.0, 0.9)):
            bpy_util.box(
                name_prefix + "_LAMP_%d" % (i + 1),
                _size_godot_to_blender(0.28, 0.28, 0.22),
                _godot_to_blender(x, 4.05, z_godot + 0.22),
                (0, 0, 0),
                mats["lamp_off"] if i < 2 else mats["lamp_on"],
                col,
            )


def build_piece(doc, mats, root_col):
    pid = str(doc.get("piece_id", "piece"))
    piece_col = bpy_util.ensure_child(root_col, "PIECE_%s" % pid)
    road_col = bpy_util.ensure_child(piece_col, "%s_ROAD" % pid)
    rail_col = bpy_util.ensure_child(piece_col, "%s_RAIL" % pid)
    extra_col = bpy_util.ensure_child(piece_col, "%s_EXTRA" % pid)
    mark_col = bpy_util.ensure_child(piece_col, "%s_MARK" % pid)

    boxes = list(doc.get("collision") or [])
    n_road = 0
    n_rail = 0
    for box in boxes:
        kind = str(box.get("kind", "road"))
        if kind == "road":
            n_road += 1
            _road_visual(box, mats, road_col, n_road)
        elif kind == "rail":
            n_rail += 1
            _rail_visual(box, mats, rail_col, n_rail)

    bpy_util.join_named("ROAD", road_col)
    bpy_util.join_named("RAILBASE", rail_col)
    bpy_util.join_named("RAILMETAL", rail_col)

    entry = doc.get("entry") or {}
    ex = doc.get("exit") or {}
    eo = entry.get("origin") or [0, 0, 0]
    xo = ex.get("origin") or [0, 0, 0]
    bpy_util.empty("ENTRY", _godot_to_blender(eo[0], eo[1], eo[2]), _euler(float(entry.get("yaw", 0.0))), mark_col)
    bpy_util.empty("EXIT", _godot_to_blender(xo[0], xo[1], xo[2]), _euler(float(ex.get("yaw", 0.0))), mark_col)
    bpy_util.empty("SCENERY_LEFT_NEAR", _godot_to_blender(-10.2, 0, -2), (0, 0, 0), mark_col)
    bpy_util.empty("SCENERY_RIGHT_NEAR", _godot_to_blender(10.2, 0, -2), (0, 0, 0), mark_col)
    bpy_util.empty("SCENERY_LEFT_FAR", _godot_to_blender(-18.0, 0, -4), (0, 0, 0), mark_col)
    bpy_util.empty("SCENERY_RIGHT_FAR", _godot_to_blender(18.0, 0, -4), (0, 0, 0), mark_col)
    bpy_util.empty("SIGN_LEFT", _godot_to_blender(-9.8, 1.6, -3), (0, 0, 0), mark_col)
    bpy_util.empty("SIGN_RIGHT", _godot_to_blender(9.8, 1.6, -3), (0, 0, 0), mark_col)
    bpy_util.empty("LANDMARK", _godot_to_blender(16.0, 0, -6), (0, 0, 0), mark_col)

    ptype = str(doc.get("type", ""))
    w = float(doc.get("road_width", ASPHALT_W))
    if ptype == "start":
        _gantry("START", -1.5, w, mats, extra_col, lamp=True)
        bpy_util.empty("PLAYER_SPAWN", _godot_to_blender(0, 1.15, -2.6), (0, 0, 0), mark_col)
        for x in (-2.2, -0.75, 0.75, 2.2):
            bpy_util.box(
                "START_LANE_%.0f" % (x * 10),
                _size_godot_to_blender(0.12, 0.02, 2.4),
                _godot_to_blender(x, 0.04, -3.2),
                (0, 0, 0),
                mats["mark"],
                extra_col,
            )
    if ptype == "finish":
        _gantry("FINISH", -6.5, w, mats, extra_col, lamp=False)
        bpy_util.empty("FINISH_TRIGGER_ANCHOR", _godot_to_blender(0, 0.5, -6.5), (0, 0, 0), mark_col)
        for i in range(8):
            colr = mats["mark"] if i % 2 == 0 else mats["gantry"]
            bpy_util.box(
                "FINISH_CHECK_%d" % i,
                _size_godot_to_blender(1.6, 0.03, 0.55),
                _godot_to_blender(-6.4 + i * 1.7, 0.05, -6.5),
                (0, 0, 0),
                colr,
                extra_col,
            )
    if ptype == "boost":
        length = float(doc.get("centerline_length", 12.0))
        bpy_util.box(
            "BOOST_PAD",
            _size_godot_to_blender(w * 0.62, 0.05, length * 0.55),
            _godot_to_blender(0, 0.05, -length * 0.5),
            (0, 0, 0),
            mats["boost"],
            extra_col,
        )
        for i in range(3):
            bpy_util.box(
                "BOOST_CHEVRON_%d" % i,
                _size_godot_to_blender(1.6 - i * 0.15, 0.04, 0.35),
                _godot_to_blender(0, 0.08, -length * 0.35 - i * 1.4),
                (0, 0, 0),
                mats["cyan"],
                extra_col,
            )
    glb_name = str(doc.get("glb") or "")
    if not glb_name.endswith(".glb"):
        glb_name = "track_%s_v1.glb" % pid
    return piece_col, pid, glb_name


def build_checkpoint_gantry(mats, root_col):
    col = bpy_util.ensure_child(root_col, "PIECE_checkpoint_gantry")
    extra = bpy_util.ensure_child(col, "checkpoint_EXTRA")
    mark = bpy_util.ensure_child(col, "checkpoint_MARK")
    w = ASPHALT_W
    bpy_util.box("CP_BEAM", _size_godot_to_blender(w + 2.6, 0.22, 0.22), _godot_to_blender(0, 4.2, 0), (0, 0, 0), mats["cyan"], extra)
    bpy_util.box("CP_POLE_L", _size_godot_to_blender(0.18, 4.3, 0.18), _godot_to_blender(-(w * 0.5 + 1.0), 2.15, 0), (0, 0, 0), mats["cyan"], extra)
    bpy_util.box("CP_POLE_R", _size_godot_to_blender(0.18, 4.3, 0.18), _godot_to_blender(w * 0.5 + 1.0, 2.15, 0), (0, 0, 0), mats["cyan"], extra)
    bpy_util.empty("ENTRY", _godot_to_blender(0, 0, 0), (0, 0, 0), mark)
    bpy_util.empty("EXIT", _godot_to_blender(0, 0, 0), (0, 0, 0), mark)
    return col


def _export_collection(col, glb_path, extra):
    bpy_util.hide_all_mesh()
    for child in col.children_recursive if hasattr(col, "children_recursive") else []:
        pass
    stack = [col]
    seen = set()
    while stack:
        c = stack.pop()
        if c.name in seen:
            continue
        seen.add(c.name)
        for ch in c.children:
            stack.append(ch)
        for o in c.objects:
            o.hide_set(False)
            o.hide_render = False
            o.select_set(True)
    bpy_util.export_glb(glb_path, selected=True)
    bpy_util.stats_report(glb_path, extra)


def main():
    os.makedirs(DST, exist_ok=True)
    only = os.environ.get("SSK_KIT_PIECE", "").strip()
    files = sorted(f for f in os.listdir(DST) if f.endswith(".json") and f.startswith("track_"))
    bpy_util.reset_scene()
    bpy_util.collection("00_REFERENCE")
    bpy_util.collection("01_ROAD")
    bpy_util.collection("02_BARRIERS")
    bpy_util.collection("03_GANTRIES")
    bpy_util.collection("04_SCENERY")
    bpy_util.collection("05_LANDMARKS")
    export_root = bpy_util.collection("EXPORT_GODOT")
    mats = _mats()
    built = 0
    exports = []
    for name in files:
        doc = json.loads(open(os.path.join(DST, name), encoding="utf-8").read())
        pid = str(doc.get("piece_id", ""))
        if only and pid != only:
            continue
        print("BUILD_PIECE", pid)
        col, pid, glb_name = build_piece(doc, mats, export_root)
        exports.append((col, os.path.join(DST, glb_name), {"piece_id": pid}))
        built += 1
    cp_col = build_checkpoint_gantry(mats, export_root)
    exports.append((cp_col, os.path.join(DST, "track_checkpoint_gantry_v1.glb"), {"piece_id": "checkpoint_gantry"}))
    for col, path, extra in exports:
        print("EXPORT_PIECE", extra.get("piece_id"), path)
        try:
            _export_collection(col, path, extra)
        except Exception as exc:
            print("EXPORT_FAIL", extra.get("piece_id"), type(exc).__name__, exc)
            raise
    # Unhide everything for human .blend review.
    import bpy

    for o in bpy.data.objects:
        o.hide_set(False)
        o.hide_render = False
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("KIT_V8_BUILT", built, "blend", BLEND)


if __name__ == "__main__":
    main()
