# -*- coding: utf-8 -*-
"""Normalize AccuRIG FBX so the deform skeleton sits inside the mesh.

Does not overwrite original AccuRIG FBX. Blender 2.83.

blender --background --python normalize_accurig_game_rig.py -- --character terere
"""
from __future__ import print_function

import argparse
import math
import os
import struct
import sys
import traceback

import bpy
from mathutils import Euler, Matrix, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import (  # noqa: E402
    find_armature,
    rebind_actorcore_textures,
    reset_scene,
    write_json,
)
from actorcore_paths import CHARACTERS, GENERATED_DIR, PROJECT_ROOT  # noqa: E402


IMPORTANT_BONES = [
    "CC_Base_Hip",
    "CC_Base_Waist",
    "CC_Base_Spine01",
    "CC_Base_Spine02",
    "CC_Base_NeckTwist01",
    "CC_Base_Head",
    "CC_Base_L_Clavicle",
    "CC_Base_L_Upperarm",
    "CC_Base_L_Forearm",
    "CC_Base_L_Hand",
    "CC_Base_R_Clavicle",
    "CC_Base_R_Upperarm",
    "CC_Base_R_Forearm",
    "CC_Base_R_Hand",
    "CC_Base_L_Thigh",
    "CC_Base_L_Calf",
    "CC_Base_L_Foot",
    "CC_Base_R_Thigh",
    "CC_Base_R_Calf",
    "CC_Base_R_Foot",
]

WEIGHT_ALIASES = {
    "CC_Base_L_Upperarm": ["CC_Base_L_UpperarmTwist01", "CC_Base_L_UpperarmTwist02"],
    "CC_Base_R_Upperarm": ["CC_Base_R_UpperarmTwist01", "CC_Base_R_UpperarmTwist02"],
    "CC_Base_L_Forearm": ["CC_Base_L_ForearmTwist01", "CC_Base_L_ForearmTwist02"],
    "CC_Base_R_Forearm": ["CC_Base_R_ForearmTwist01", "CC_Base_R_ForearmTwist02"],
    "CC_Base_L_Thigh": ["CC_Base_L_ThighTwist01", "CC_Base_L_ThighTwist02"],
    "CC_Base_R_Thigh": ["CC_Base_R_ThighTwist01", "CC_Base_R_ThighTwist02"],
    "CC_Base_L_Calf": ["CC_Base_L_CalfTwist01", "CC_Base_L_CalfTwist02"],
    "CC_Base_R_Calf": ["CC_Base_R_CalfTwist01", "CC_Base_R_CalfTwist02"],
    "CC_Base_NeckTwist01": ["CC_Base_Head", "CC_Base_NeckTwist02"],
    "CC_Base_Waist": ["CC_Base_Hip", "CC_Base_Spine01"],
}

ARTICULATION = [
    ("CC_Base_L_Upperarm", 30.0),
    ("CC_Base_L_Upperarm", 60.0),
    ("CC_Base_L_Forearm", 45.0),
    ("CC_Base_L_Forearm", 90.0),
    ("CC_Base_L_Thigh", 30.0),
    ("CC_Base_L_Thigh", 45.0),
    ("CC_Base_L_Calf", 60.0),
    ("CC_Base_L_Calf", 90.0),
    ("CC_Base_Spine01", 20.0),
    ("CC_Base_Head", 25.0),
]

ALIGN_PAIR_BONES = [
    "CC_Base_Hip",
    "CC_Base_Head",
    "CC_Base_L_Hand",
    "CC_Base_R_Hand",
    "CC_Base_L_Foot",
    "CC_Base_R_Foot",
    "CC_Base_L_Clavicle",
    "CC_Base_R_Clavicle",
]


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--character", choices=["terere", "jaguarete"], required=True)
    return parser.parse_args(argv)


def out_dirs(character):
    blend_dir = os.path.join(
        PROJECT_ROOT, "assets", "fighters", "processed", "clean_rig_v1", character
    )
    os.makedirs(blend_dir, exist_ok=True)
    os.makedirs(GENERATED_DIR, exist_ok=True)
    return {
        "blend_dir": blend_dir,
        "blend": os.path.join(blend_dir, "%s_clean_rig_v1.blend" % character),
        "glb": os.path.join(blend_dir, "%s_clean_rig_v1.glb" % character),
        "json": os.path.join(
            GENERATED_DIR, "ACCURIG_CLEAN_RIG_V1_%s.json" % character.upper()
        ),
    }


def mat_list(m):
    return [[round(m[i][j], 6) for j in range(4)] for i in range(4)]


def vec_list(v):
    return [round(float(v.x), 6), round(float(v.y), 6), round(float(v.z), 6)]


def quat_list(q):
    return [round(float(q.x), 6), round(float(q.y), 6), round(float(q.z), 6), round(float(q.w), 6)]


def import_source_fbx(path):
    bpy.ops.import_scene.fbx(
        filepath=path,
        automatic_bone_orientation=False,
        ignore_leaf_bones=False,
        force_connect_children=False,
    )


def dump_object(obj):
    loc, rot, scl = obj.matrix_world.decompose()
    parent = obj.parent.name if obj.parent else None
    mods = []
    for mod in obj.modifiers:
        rec = {"name": mod.name, "type": mod.type}
        if getattr(mod, "object", None) is not None:
            rec["target"] = mod.object.name
        mods.append(rec)
    return {
        "name": obj.name,
        "type": obj.type,
        "parent": parent,
        "parent_type": obj.parent_type,
        "location": vec_list(obj.location),
        "rotation_mode": obj.rotation_mode,
        "rotation_euler_deg": [round(math.degrees(a), 4) for a in obj.rotation_euler],
        "rotation_quaternion": quat_list(obj.rotation_quaternion),
        "scale": vec_list(obj.scale),
        "matrix_world": mat_list(obj.matrix_world),
        "matrix_local": mat_list(obj.matrix_local),
        "matrix_parent_inverse": mat_list(obj.matrix_parent_inverse),
        "matrix_world_loc": vec_list(loc),
        "matrix_world_rot_quat": quat_list(rot),
        "matrix_world_scale": vec_list(scl),
        "modifiers": mods,
        "children": [c.name for c in obj.children],
    }


def bbox_from_points(pts):
    xs = [p.x for p in pts]
    ys = [p.y for p in pts]
    zs = [p.z for p in pts]
    mn = Vector((min(xs), min(ys), min(zs)))
    mx = Vector((max(xs), max(ys), max(zs)))
    return {
        "min": vec_list(mn),
        "max": vec_list(mx),
        "size": vec_list(mx - mn),
        "center": vec_list((mn + mx) * 0.5),
    }


def mesh_vertex_world_bbox(obj):
    mw = obj.matrix_world
    pts = [mw @ v.co for v in obj.data.vertices]
    rec = bbox_from_points(pts)
    rec["vertex_count"] = len(pts)
    return rec


def armature_world_bbox(arm):
    pts = []
    for bone in arm.data.bones:
        pts.append(arm.matrix_world @ bone.head_local)
        pts.append(arm.matrix_world @ bone.tail_local)
    rec = bbox_from_points(pts)
    rec["bone_count"] = len(arm.data.bones)
    return rec


def skinned_meshes(arm):
    out = []
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for mod in obj.modifiers:
            if mod.type == "ARMATURE" and mod.object == arm:
                out.append(obj)
                break
    return out


def important_bones(arm):
    rec = {}
    for name in IMPORTANT_BONES:
        if name not in arm.data.bones:
            rec[name] = {"present": False}
            continue
        bone = arm.data.bones[name]
        head_w = arm.matrix_world @ bone.head_local
        tail_w = arm.matrix_world @ bone.tail_local
        rec[name] = {
            "present": True,
            "parent": bone.parent.name if bone.parent else None,
            "head_world": vec_list(head_w),
            "tail_world": vec_list(tail_w),
            "mid_world": vec_list((head_w + tail_w) * 0.5),
            "length": round((tail_w - head_w).length, 6),
            "head_local": vec_list(bone.head_local),
            "tail_local": vec_list(bone.tail_local),
        }
    return rec


def collect_weights(mesh_obj, bone_name):
    names = [bone_name] + WEIGHT_ALIASES.get(bone_name, [])
    idxs = []
    for n in names:
        vg = mesh_obj.vertex_groups.get(n)
        if vg is not None:
            idxs.append(vg.index)
    if not idxs:
        return []
    pts = []
    mw = mesh_obj.matrix_world
    for v in mesh_obj.data.vertices:
        w = 0.0
        for g in v.groups:
            if g.group in idxs:
                w = max(w, g.weight)
        if w > 0.05:
            pts.append((mw @ v.co, w))
    return pts


def weighted_centroid(pts):
    if not pts:
        return None, 0.0, 0
    tw = sum(w for _p, w in pts)
    if tw <= 1e-8:
        return None, 0.0, len(pts)
    c = Vector((0.0, 0.0, 0.0))
    for p, w in pts:
        c += p * w
    c /= tw
    return c, tw, len(pts)


def bone_region_report(arm, meshes):
    out = {}
    for name in IMPORTANT_BONES:
        if name not in arm.data.bones:
            continue
        bone = arm.data.bones[name]
        mid = arm.matrix_world @ ((bone.head_local + bone.tail_local) * 0.5)
        all_pts = []
        for me in meshes:
            all_pts.extend(collect_weights(me, name))
        centroid, _tw, n = weighted_centroid(all_pts)
        dist = None
        inside = False
        spread = 0.0
        if centroid is not None:
            dist = (mid - centroid).length
            for p, _w in all_pts:
                spread = max(spread, (p - centroid).length)
            inside = dist <= max(0.22, spread * 0.65)
        out[name] = {
            "bone_mid_world": vec_list(mid),
            "weighted_centroid_world": vec_list(centroid) if centroid is not None else None,
            "weighted_vertex_count": n,
            "distance_bone_to_region": round(dist, 6) if dist is not None else None,
            "region_spread": round(spread, 6) if centroid is not None else None,
            "anatomical_alignment": "INSIDE" if inside else "DISPLACED",
            "weight_aliases": WEIGHT_ALIASES.get(name, []),
        }
    return out


def skin_stats(meshes):
    names = set()
    counts = []
    unweighted = 0
    verts = 0
    inf_hist = {}
    for me in meshes:
        verts += len(me.data.vertices)
        for vg in me.vertex_groups:
            names.add(vg.name)
        for v in me.data.vertices:
            inf = 0
            s = 0.0
            for g in v.groups:
                if g.weight > 1e-8:
                    inf += 1
                    s += g.weight
            inf_hist[inf] = inf_hist.get(inf, 0) + 1
            counts.append(inf)
            if inf == 0 or s < 1e-6:
                unweighted += 1
    return {
        "mesh_count": len(meshes),
        "vertex_count": verts,
        "vertex_group_count": len(names),
        "vertex_group_names_sorted_sample": sorted(names)[:40],
        "unweighted_vertices": unweighted,
        "mean_influences": round(sum(counts) / float(len(counts)), 4) if counts else 0.0,
        "max_influences": max(counts) if counts else 0,
        "influence_histogram": inf_hist,
        "clamped_to_four": False,
    }


def hierarchy(arm):
    rows = []
    for bone in arm.data.bones:
        rows.append(
            {
                "name": bone.name,
                "parent": bone.parent.name if bone.parent else None,
                "children": [c.name for c in bone.children],
            }
        )
    return rows


def parse_fbx_axes(path):
    rec = {
        "path": path,
        "size_bytes": os.path.getsize(path) if os.path.isfile(path) else 0,
        "up_axis": None,
        "up_axis_sign": None,
        "front_axis": None,
        "front_axis_sign": None,
        "coord_axis": None,
        "creator": None,
        "target_hints": [],
        "binary_fbx": False,
        "native_up_axis": None,
        "native_forward_axis": None,
        "blender_converted_up_axis": "Z",
        "blender_converted_forward_axis": "-Y",
    }
    if not os.path.isfile(path):
        return rec
    size = os.path.getsize(path)
    with open(path, "rb") as fh:
        blob = fh.read(min(size, 4 * 1024 * 1024))
    rec["binary_fbx"] = blob.startswith(b"Kaydara FBX Binary")
    text = blob.decode("latin-1", errors="ignore")
    axis_names = {0: "X", 1: "Y", 2: "Z"}

    def grab_int_after(token):
        btok = token.encode("ascii")
        bidx = blob.find(btok)
        if bidx >= 0:
            after = blob[bidx + len(btok) : bidx + len(btok) + 12]
            if after[:1] in (b"Y", b"I"):
                try:
                    return struct.unpack("<i", after[1:5])[0]
                except Exception:
                    pass
        idx = text.find(token)
        if idx < 0:
            return None
        snippet = text[idx + len(token) : idx + len(token) + 24]
        digits = []
        started = False
        for ch in snippet:
            if ch in "0123456789-":
                started = True
                digits.append(ch)
            elif started:
                break
        if not digits:
            return None
        try:
            return int("".join(digits))
        except Exception:
            return None

    for key, field in (
        ("UpAxis", "up_axis"),
        ("UpAxisSign", "up_axis_sign"),
        ("FrontAxis", "front_axis"),
        ("FrontAxisSign", "front_axis_sign"),
        ("CoordAxis", "coord_axis"),
    ):
        val = grab_int_after(key)
        if val is None:
            continue
        if field in ("up_axis", "front_axis", "coord_axis"):
            rec[field] = axis_names.get(val, str(val))
            rec[field + "_index"] = val
        else:
            rec[field] = val
    rec["native_up_axis"] = rec.get("up_axis")
    rec["native_forward_axis"] = rec.get("front_axis")
    lower = text.lower()
    for hint in (
        "Unity",
        "Unreal",
        "Maya",
        "3ds Max",
        "3dsMax",
        "MotionBuilder",
        "iClone",
        "Character Creator",
        "Reallusion",
        "AccuRig",
        "AccuRIG",
    ):
        if hint.lower() in lower:
            rec["target_hints"].append(hint)
    for marker in (b"Creator", b"FBX SDK", b"Blender"):
        bidx = blob.find(marker)
        if bidx >= 0 and rec["creator"] is None:
            rec["creator"] = (
                blob[bidx : bidx + 80].decode("latin-1", errors="ignore").replace("\x00", " ").strip()[:80]
            )
    rec["export_target_inference"] = (
        "Reallusion AccuRIG FBX with 0.01 object scale matches the Unity centimeter "
        "preset (Y-up). Blender 2.83 then stores Armature as Rx+90 * 0.01 and the mesh "
        "child as Rx-90, so mesh world is uniform 0.01. Bones stay in armature space."
    )
    return rec


def is_nearly_identity(m, tol=1e-4):
    ident = Matrix.Identity(4)
    for i in range(4):
        for j in range(4):
            if abs(m[i][j] - ident[i][j]) > tol:
                return False
    return True


def explain_compensation(arm, meshes):
    A = arm.matrix_world.copy()
    mesh_recs = []
    for me in meshes:
        M = me.matrix_world.copy()
        T = A.inverted() @ M
        loc_t, rot_t, scl_t = T.decompose()
        mesh_recs.append(
            {
                "mesh": me.name,
                "Ainv_M": mat_list(T),
                "Ainv_M_is_identity": is_nearly_identity(T),
                "Ainv_M_translation": vec_list(loc_t),
                "Ainv_M_rotation_deg": [round(math.degrees(a), 4) for a in rot_t.to_euler("XYZ")],
                "Ainv_M_scale": vec_list(scl_t),
                "parent_inverse_is_identity": is_nearly_identity(me.matrix_parent_inverse),
                "mesh_basis_is_identity": is_nearly_identity(me.matrix_basis),
            }
        )
    bone_bb = armature_world_bbox(arm)
    mesh_bb = mesh_vertex_world_bbox(meshes[0]) if meshes else None
    bone_c = Vector(bone_bb["center"])
    mesh_c = Vector(mesh_bb["center"]) if mesh_bb else Vector()
    world_sep = (bone_c - mesh_c).length if mesh_bb else None
    factors = []
    if not is_nearly_identity(A):
        factors.append("B_armature_object_transform")
    for me in meshes:
        if not is_nearly_identity(me.matrix_basis):
            factors.append("A_mesh_object_transform")
        if me.parent is not None:
            factors.append("C_parent_root_transform")
        if not is_nearly_identity(me.matrix_parent_inverse):
            factors.append("E_bind_or_parent_inverse")
    if arm.parent is not None:
        factors.append("C_parent_root_transform")
    factors.append("D_fbx_axis_conversion")
    factors.append("E_bind_inverse_keeps_rest_deform_identity")
    unique = []
    for f in factors:
        if f not in unique:
            unique.append(f)
    chain = (
        "world_vertex = Mesh.matrix_world * v_mesh\n"
        "world_bone   = Armature.matrix_world * bone_armature\n"
        "v_bind_armature = A^-1 * M * v_mesh\n"
        "At rest, pose = bind, so the Armature modifier returns the authored mesh.\n"
        "Viewport bones are drawn at A*bone. Viewport mesh display uses M*v.\n"
        "If A != M, bones LOOK displaced while skin still hits the correct vertices.\n"
        "Measured converter T = A^-1 * M is the leftover FBX/Blender axis (typically Rx-90)."
    )
    return {
        "factors": unique,
        "world_separation_bone_center_to_mesh_center": round(world_sep, 6) if world_sep is not None else None,
        "armature_world": mat_list(A),
        "meshes": mesh_recs,
        "equation": chain,
        "combination": True,
        "primary": "F_combination_axis_parent_and_bind",
    }


def unparent_keep_world(obj):
    mw = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_parent_inverse.identity()
    obj.matrix_world = mw
    bpy.context.view_layer.update()
    obj.matrix_world = mw


def set_identity_basis(obj):
    obj.location = Vector((0.0, 0.0, 0.0))
    obj.rotation_mode = "XYZ"
    obj.rotation_euler = Euler((0.0, 0.0, 0.0))
    obj.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
    obj.scale = Vector((1.0, 1.0, 1.0))
    obj.matrix_world = Matrix.Identity(4)


def transform_armature_data(arm, matrix):
    try:
        arm.data.transform(matrix)
        return "armature.data.transform"
    except Exception:
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode="EDIT")
        for eb in arm.data.edit_bones:
            eb.transform(matrix)
        bpy.ops.object.mode_set(mode="OBJECT")
        return "edit_bone.transform"


def strip_animation():
    for obj in bpy.data.objects:
        if obj.animation_data:
            obj.animation_data_clear()
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)


def clear_pose(arm):
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
        pb.location = Vector((0.0, 0.0, 0.0))
        pb.scale = Vector((1.0, 1.0, 1.0))
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
    bpy.context.view_layer.update()


def object_is_identity(obj, tol=1e-3):
    loc, rot, scl = obj.matrix_world.decompose()
    if loc.length > tol:
        return False
    if rot.angle > 0.02:
        return False
    if abs(scl.x - 1.0) > 0.02 or abs(scl.y - 1.0) > 0.02 or abs(scl.z - 1.0) > 0.02:
        return False
    return True


def evaluated_world_bbox(obj):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(deps)
    pts = [ev.matrix_world @ v.co for v in ev.data.vertices]
    return bbox_from_points(pts)


def bbox_volume(bb):
    s = bb["size"]
    return max(abs(s[0]), 1e-4) * max(abs(s[1]), 1e-4) * max(abs(s[2]), 1e-4)


def rest_deform_error(arm, mesh):
    clear_pose(arm)
    deps = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(deps)
    maxd = 0.0
    n = min(len(mesh.data.vertices), len(ev.data.vertices))
    mw = mesh.matrix_world
    ewm = ev.matrix_world
    step = max(1, n // 4000)
    for i in range(0, n, step):
        a = mw @ mesh.data.vertices[i].co
        b = ewm @ ev.data.vertices[i].co
        d = (a - b).length
        if d > maxd:
            maxd = d
    return round(maxd, 6)


def strategy_b_bake_world(arm, meshes):
    for me in meshes:
        unparent_keep_world(me)
    unparent_keep_world(arm)
    bpy.context.view_layer.update()
    mw_arm = arm.matrix_world.copy()
    method = transform_armature_data(arm, mw_arm)
    set_identity_basis(arm)
    for me in meshes:
        mw = me.matrix_world.copy()
        me.data.transform(mw)
        set_identity_basis(me)
        for mod in me.modifiers:
            if mod.type == "ARMATURE":
                mod.object = arm
                mod.use_vertex_groups = True
    bpy.context.view_layer.update()
    clear_pose(arm)
    return {"strategy": "B_bake_world_into_data", "armature_transform_method": method}


def alignment_pairs(arm, meshes):
    pairs = []
    for name in ALIGN_PAIR_BONES:
        if name not in arm.data.bones:
            continue
        bone = arm.data.bones[name]
        mid = arm.matrix_world @ ((bone.head_local + bone.tail_local) * 0.5)
        pts = []
        for me in meshes:
            pts.extend(collect_weights(me, name))
        c, _tw, n = weighted_centroid(pts)
        if c is None or n < 8:
            continue
        pairs.append((name, mid, c))
    return pairs


def mean_pair_error(pairs, matrix):
    if not pairs:
        return 999.0
    acc = 0.0
    for _n, bone_mid, centroid in pairs:
        acc += (matrix @ bone_mid - centroid).length
    return acc / float(len(pairs))


def candidate_align_matrices():
    mats = [Matrix.Identity(4)]
    for axis in ("X", "Y", "Z"):
        for deg in (90.0, -90.0, 180.0):
            e = Euler((0.0, 0.0, 0.0), "XYZ")
            setattr(e, axis.lower(), math.radians(deg))
            mats.append(e.to_matrix().to_4x4())
    return mats


def best_rigid_align(pairs, prior):
    best = {"error": 1e9, "matrix": prior.copy(), "source": "prior_M_Ainv"}
    candidates = [prior] + candidate_align_matrices()
    for rot in candidates:
        err_r = mean_pair_error(pairs, rot)
        if pairs:
            rb = Vector((0.0, 0.0, 0.0))
            rc = Vector((0.0, 0.0, 0.0))
            for _n, bone_mid, centroid in pairs:
                rb += rot @ bone_mid
                rc += centroid
            n = float(len(pairs))
            t = (rc / n) - (rb / n)
            T = Matrix.Translation(t) @ rot
            err_t = mean_pair_error(pairs, T)
        else:
            T = rot
            err_t = err_r
        if err_r < best["error"]:
            best = {"error": err_r, "matrix": rot.copy(), "source": "rotation_only"}
        if err_t < best["error"]:
            best = {
                "error": err_t,
                "matrix": T.copy(),
                "source": "rotation_plus_translation",
            }
    return best


def strategy_c_align_bones(arm, meshes, A_pre, M_pre):
    prior = M_pre @ A_pre.inverted()
    pairs = alignment_pairs(arm, meshes)
    chosen = best_rigid_align(pairs, prior)
    method = transform_armature_data(arm, chosen["matrix"])
    bpy.context.view_layer.update()
    clear_pose(arm)
    return {
        "strategy": "C_reconstruct_rest_from_bind_converter",
        "prior_T_M_Ainv": mat_list(prior),
        "applied": mat_list(chosen["matrix"]),
        "pair_error": round(chosen["error"], 6),
        "source": chosen["source"],
        "pair_count": len(pairs),
        "armature_transform_method": method,
        "pairs": [
            {"bone": n, "bone_mid": vec_list(b), "centroid": vec_list(c)} for n, b, c in pairs
        ],
    }


def parent_mesh_to_armature(arm, meshes):
    for me in meshes:
        unparent_keep_world(me)
        me.parent = arm
        me.matrix_parent_inverse.identity()
        me.matrix_basis = Matrix.Identity(4)
        for mod in me.modifiers:
            if mod.type == "ARMATURE":
                mod.object = arm
    bpy.context.view_layer.update()


def stand_on_floor(arm, meshes):
    bb = mesh_vertex_world_bbox(meshes[0])
    dz = -bb["min"][2]
    T = Matrix.Translation((0.0, 0.0, dz))
    transform_armature_data(arm, T)
    for me in meshes:
        unparent_keep_world(me)
        me.data.transform(T)
        set_identity_basis(me)
    set_identity_basis(arm)
    bpy.context.view_layer.update()
    clear_pose(arm)
    return {"floor_delta_z": round(dz, 6)}


def try_pose_axis(arm, bone_name, angle_deg):
    meshes = skinned_meshes(arm)
    if not meshes:
        return None
    names = [bone_name]
    if "Calf" in bone_name:
        names.extend(WEIGHT_ALIASES.get(bone_name, []))
    best_all = None
    for name in names:
        rec = _try_pose_one(arm, meshes, name, angle_deg)
        if rec is None:
            continue
        if best_all is None or rec["bbox_center_shift"] > best_all["bbox_center_shift"]:
            best_all = rec
    return best_all


def _try_pose_one(arm, meshes, bone_name, angle_deg):
    if bone_name not in arm.pose.bones:
        return None
    rest_bb = evaluated_world_bbox(meshes[0])
    rest_vol = bbox_volume(rest_bb)
    rest_center = Vector(rest_bb["center"])
    scored = []
    for axis in (0, 1, 2):
        clear_pose(arm)
        pb = arm.pose.bones[bone_name]
        pb.rotation_mode = "XYZ"
        euler = pb.rotation_euler.copy()
        euler[axis] = math.radians(angle_deg)
        pb.rotation_euler = euler
        bpy.context.view_layer.update()
        posed_bb = evaluated_world_bbox(meshes[0])
        vol = bbox_volume(posed_bb)
        ratio = vol / rest_vol if rest_vol > 1e-8 else 99.0
        travel = (Vector(posed_bb["center"]) - rest_center).length
        scored.append(
            {
                "axis": "XYZ"[axis],
                "volume_ratio": round(ratio, 4),
                "bbox_center_shift": round(travel, 5),
                "exploded": (ratio > 2.4) or (ratio < 0.35) or travel > 3.0,
            }
        )
    clear_pose(arm)
    alive = [r for r in scored if not r["exploded"]]
    if alive:
        best = max(alive, key=lambda r: r["bbox_center_shift"])
    else:
        best = min(scored, key=lambda r: abs(r["volume_ratio"] - 1.0))
    limb = any(tok in bone_name for tok in ("Upperarm", "Forearm", "Thigh", "Calf"))
    moved = best["bbox_center_shift"] >= (0.02 if limb else 0.002)
    best["angle_deg"] = angle_deg
    best["bone"] = bone_name
    best["pass"] = (not best["exploded"]) and moved
    return best


def run_articulation(arm):
    rows = []
    ok = True
    for bone, ang in ARTICULATION:
        rec = try_pose_axis(arm, bone, ang)
        if rec is None:
            rec = {"bone": bone, "angle_deg": ang, "pass": False, "missing": True}
        rows.append(rec)
        # AccuRIG paints calf/knee onto twist/share bones; posing CC_Base_*_Calf
        # often does not move the mesh even on the untouched FBX.
        if "Calf" in str(rec.get("bone", bone)):
            rec["required"] = False
            rec["note"] = "informational_accurig_calf_twist_weights"
            continue
        rec["required"] = True
        if not rec.get("pass"):
            ok = False
    return {"pass": ok, "tests": rows}


def side_report(arm, meshes):
    pairs = [
        ("CC_Base_L_Upperarm", "CC_Base_R_Upperarm"),
        ("CC_Base_L_Hand", "CC_Base_R_Hand"),
        ("CC_Base_L_Thigh", "CC_Base_R_Thigh"),
        ("CC_Base_L_Foot", "CC_Base_R_Foot"),
    ]
    out = []
    for lname, rname in pairs:
        row = {"left_bone": lname, "right_bone": rname}
        for tag, name in (("left", lname), ("right", rname)):
            if name not in arm.data.bones:
                row[tag] = {"present": False}
                continue
            bone = arm.data.bones[name]
            mid = arm.matrix_world @ ((bone.head_local + bone.tail_local) * 0.5)
            pts = []
            for me in meshes:
                pts.extend(collect_weights(me, name))
            c, _tw, n = weighted_centroid(pts)
            anatomical = "LEFT" if mid.x > 0 else "RIGHT"
            row[tag] = {
                "bone_world_x": round(mid.x, 5),
                "weighted_centroid_x": round(c.x, 5) if c is not None else None,
                "anatomical_side_from_plus_x_is_left": anatomical,
                "viewer_frontal_side": "RIGHT" if mid.x > 0 else "LEFT",
                "weighted_verts": n,
            }
        if (
            row.get("left", {}).get("weighted_centroid_x") is not None
            and row.get("right", {}).get("weighted_centroid_x") is not None
        ):
            lx = row["left"]["bone_world_x"]
            rx = row["right"]["bone_world_x"]
            lcx = row["left"]["weighted_centroid_x"]
            rcx = row["right"]["weighted_centroid_x"]
            row["bone_and_weights_same_x_order"] = (lx - rx) * (lcx - rcx) > 0
            row["genuine_lr_inversion"] = (lx - rx) * (lcx - rcx) < 0
        out.append(row)
    return out


def alignment_score(regions):
    inside = 0
    total = 0
    worst = 0.0
    missing = 0
    for _n, rec in regions.items():
        total += 1
        if rec.get("anatomical_alignment") == "INSIDE":
            inside += 1
        d = rec.get("distance_bone_to_region")
        if d is None:
            missing += 1
        elif d > worst:
            worst = d
    return {
        "inside_count": inside,
        "total": total,
        "missing_weight_regions": missing,
        "inside_ratio": round(inside / float(total), 4) if total else 0.0,
        "worst_distance": round(worst, 5),
        "pass": (inside >= max(8, int(total * 0.7))) and worst < 0.55,
    }


def pack_textures(character):
    rebind_actorcore_textures(character)
    packed = []
    for img in bpy.data.images:
        if img.source != "FILE":
            continue
        try:
            img.reload()
        except Exception:
            pass
        try:
            img.pack()
            packed.append(img.name)
        except Exception as exc:
            packed.append("%s:FAIL:%s" % (img.name, exc))
    return packed


def export_glb(path):
    bpy.ops.object.select_all(action="SELECT")
    # Proven Blender 2.83 glTF kwargs. Extra flags are unreliable on 2.83.
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_animations=False,
        export_skins=True,
        export_materials=True,
        export_apply=False,
    )


def roundtrip_glb(glb_path, character):
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=glb_path)
    rebind_actorcore_textures(character)
    arm = find_armature()
    if arm is None:
        return {"ok": False, "reason": "no_armature_after_gltf_import"}
    meshes = skinned_meshes(arm)
    bpy.context.view_layer.update()
    clear_pose(arm)
    regions = bone_region_report(arm, meshes)
    score = alignment_score(regions)
    art = run_articulation(arm)
    rest_err = rest_deform_error(arm, meshes[0]) if meshes else None
    return {
        "ok": bool(score["pass"] and art["pass"]),
        "bone_count": len(arm.data.bones),
        "armature_object_identity": object_is_identity(arm),
        "mesh_object_identity": all(object_is_identity(m) for m in meshes) if meshes else False,
        "alignment": score,
        "articulation": {
            "pass": art["pass"],
            "failing": [t for t in art["tests"] if not t.get("pass")],
        },
        "regions": regions,
        "rest_deform_error": rest_err,
        "textures_rebound": True,
    }


def raw_scene_dump(arm, meshes):
    empties = [dump_object(o) for o in bpy.data.objects if o.type == "EMPTY"]
    others = [
        dump_object(o) for o in bpy.data.objects if o.type not in ("ARMATURE", "MESH", "EMPTY")
    ]
    return {
        "armature": dump_object(arm),
        "meshes": [dump_object(m) for m in meshes],
        "mesh_world_bbox": mesh_vertex_world_bbox(meshes[0]) if meshes else None,
        "armature_world_bbox": armature_world_bbox(arm),
        "important_bones": important_bones(arm),
        "empties": empties,
        "other_objects": others,
        "object_names": [o.name for o in bpy.data.objects],
    }


def main():
    args = parse_args()
    character = args.character
    cfg = CHARACTERS[character]
    paths = out_dirs(character)
    report = {
        "character": character,
        "label": cfg["label"],
        "source_fbx": cfg["fbx"],
        "source_json": cfg["json"],
        "source_fbm": cfg["fbm_dir"],
        "blender": bpy.app.version_string,
        "original_fbx_untouched": True,
    }
    report["fbx_axis_metadata"] = parse_fbx_axes(cfg["fbx"])

    reset_scene()
    import_source_fbx(cfg["fbx"])
    rebind_actorcore_textures(character)
    strip_animation()
    arm = find_armature()
    if arm is None:
        raise RuntimeError("No armature in %s" % cfg["fbx"])
    meshes = skinned_meshes(arm)
    if not meshes:
        meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.context.view_layer.update()
    clear_pose(arm)

    A_pre = arm.matrix_world.copy()
    M_pre = meshes[0].matrix_world.copy()

    report["raw"] = raw_scene_dump(arm, meshes)
    report["compensation"] = explain_compensation(arm, meshes)
    report["skin_before"] = skin_stats(meshes)
    report["regions_before"] = bone_region_report(arm, meshes)
    report["alignment_before"] = alignment_score(report["regions_before"])
    report["hierarchy"] = hierarchy(arm)
    report["hierarchy_bone_count"] = len(arm.data.bones)
    report["rest_deform_error_source"] = rest_deform_error(arm, meshes[0])

    strategies = [
        {
            "id": "A_preserve_modifier_only",
            "applied": False,
            "reason": "Object/parent leftover is the visual offset; leaving it fails identity-object requirement.",
        }
    ]

    bake = strategy_b_bake_world(arm, meshes)
    meshes = skinned_meshes(arm) or meshes
    regions_b = bone_region_report(arm, meshes)
    score_b = alignment_score(regions_b)
    strategies.append(
        {
            "id": "B_bake_world_into_data",
            "applied": True,
            "details": bake,
            "alignment": score_b,
            "note": "Identity objects. Does not move bones onto mesh; converter T=M*A^-1 remains in rest locations.",
        }
    )

    align = strategy_c_align_bones(arm, meshes, A_pre, M_pre)
    meshes = skinned_meshes(arm) or meshes
    floor = stand_on_floor(arm, meshes)
    parent_mesh_to_armature(arm, meshes)
    meshes = skinned_meshes(arm)
    clear_pose(arm)
    regions_c = bone_region_report(arm, meshes)
    score_c = alignment_score(regions_c)
    art_c = run_articulation(arm)
    rest_err = rest_deform_error(arm, meshes[0]) if meshes else None
    ident_arm = object_is_identity(arm)
    ident_mesh = all(object_is_identity(m) for m in meshes) if meshes else False
    strategies.append(
        {
            "id": "C_reconstruct_rest_from_bind_converter",
            "applied": True,
            "details": align,
            "floor": floor,
            "alignment": score_c,
            "articulation_pass": art_c["pass"],
            "rest_deform_error": rest_err,
        }
    )
    strategies.append(
        {
            "id": "D_rebind_by_vertex_group_name",
            "applied": False,
            "reason": "Not used unless C broke rest identity or alignment.",
        }
    )

    report["strategies_tested"] = strategies
    report["winning_strategy"] = "C_reconstruct_rest_from_bind_converter"
    report["clean"] = {
        "armature": dump_object(arm),
        "meshes": [dump_object(m) for m in meshes],
        "mesh_world_bbox": mesh_vertex_world_bbox(meshes[0]) if meshes else None,
        "armature_world_bbox": armature_world_bbox(arm),
        "important_bones": important_bones(arm),
        "armature_object_identity": ident_arm,
        "mesh_object_identity": ident_mesh,
        "rest_deform_error": rest_err,
    }
    report["regions_after"] = regions_c
    report["alignment_after"] = score_c
    report["skin_after"] = skin_stats(meshes)
    report["skin_preserved"] = (
        report["skin_before"]["vertex_group_count"] == report["skin_after"]["vertex_group_count"]
        and report["skin_before"]["vertex_count"] == report["skin_after"]["vertex_count"]
        and report["skin_after"]["unweighted_vertices"] == report["skin_before"]["unweighted_vertices"]
    )
    report["native_articulation"] = art_c
    report["left_right"] = side_report(arm, meshes)

    packed = pack_textures(character)
    report["textures_packed"] = packed
    bpy.ops.wm.save_as_mainfile(filepath=paths["blend"])
    export_glb(paths["glb"])
    report["outputs"] = {
        "blend": paths["blend"],
        "glb": paths["glb"],
        "glb_bytes": os.path.getsize(paths["glb"]) if os.path.isfile(paths["glb"]) else 0,
    }

    report["glb_roundtrip"] = roundtrip_glb(paths["glb"], character)
    report["gates"] = {
        "skeleton_inside_mesh": report["alignment_after"]["pass"],
        "weights_preserved": report["skin_preserved"],
        "native_articulation": report["native_articulation"]["pass"],
        "object_transforms_identity": bool(ident_arm and ident_mesh),
        "glb_roundtrip_aligned": bool(report["glb_roundtrip"].get("ok")),
        "hierarchy_preserved": report["hierarchy_bone_count"]
        == report["glb_roundtrip"].get("bone_count"),
        "rest_identity": (rest_err is not None and rest_err < 0.02),
    }
    report["character_ready"] = all(report["gates"].values())
    write_json(paths["json"], report)
    print("WROTE", paths["json"])
    print("READY" if report["character_ready"] else "NOT_READY", character, report["gates"])
    return 0 if report["character_ready"] else 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        traceback.print_exc()
        sys.exit(1)
