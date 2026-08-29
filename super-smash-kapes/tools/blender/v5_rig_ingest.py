# -*- coding: utf-8 -*-
"""V5 rig ingest + native articulation. Isolated candidate pipeline.

Does not touch Clean Rig V1, source_rigged, Mixamo, battle, or production V4.

Blender 2.83:

  blender --background --python v5_rig_ingest.py -- --character both
"""
from __future__ import print_function

import argparse
import hashlib
import json
import math
import os
import sys
import traceback
from collections import Counter
from datetime import datetime

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from actorcore_benchmark_lib import find_armature, reset_scene, write_json  # noqa: E402
from actorcore_paths import GENERATED_DIR, PROJECT_ROOT  # noqa: E402
from normalize_accurig_game_rig import (  # noqa: E402
    armature_world_bbox,
    bbox_from_points,
    bbox_volume,
    dump_object,
    evaluated_world_bbox,
    export_glb,
    is_nearly_identity,
    mat_list,
    mesh_vertex_world_bbox,
    object_is_identity,
    parse_fbx_axes,
    parent_mesh_to_armature,
    quat_list,
    rest_deform_error,
    set_identity_basis,
    stand_on_floor,
    strategy_b_bake_world,
    strategy_c_align_bones,
    strip_animation,
    transform_armature_data,
    unparent_keep_world,
    vec_list,
)


V5_ROOT = os.path.join(PROJECT_ROOT, "assets", "fighters", "source_rigged_v5")
CLEAN_V5_ROOT = os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "clean_rig_v5")
V1_ROOT = os.path.join(PROJECT_ROOT, "assets", "fighters", "processed", "clean_rig_v1")

CHARACTERS = {
    "jaguarete": {
        "label": "Jaguareté",
        "dir_candidates": ["jaguarete", "Jaguarete"],
        "fbx_name": "jaguarete_rigged_v5.fbx",
        "json_name": "jaguarete_rigged_v5.json",
        "canonical_height": 3.15,
    },
    "terere": {
        "label": "Tereré",
        "dir_candidates": ["terere", "Terere"],
        "fbx_name": "terere_rigged_v5.fbx",
        "json_name": "terere_rigged_v5.json",
        "canonical_height": 2.40,
    },
}

# Ordered candidates. Primary UE/AccuRIG V5 names first. Twist/helpers last.
SEMANTIC_CANDIDATES = {
    "PELVIS": ["pelvis", "CC_Base_Hip", "hip", "root"],
    "HIP": ["pelvis", "CC_Base_Hip", "hip"],
    "SPINE": ["spine_01", "CC_Base_Spine01", "spine01", "spine"],
    "SPINE_02": ["spine_02", "CC_Base_Spine02", "spine02"],
    "SPINE_03": ["spine_03", "spine03"],
    "CHEST": ["spine_03", "spine_02", "CC_Base_Spine02", "chest"],
    "NECK": ["neck_01", "CC_Base_NeckTwist01", "neck"],
    "HEAD": ["head", "CC_Base_Head"],
    "LEFT_CLAVICLE": ["clavicle_l", "CC_Base_L_Clavicle"],
    "RIGHT_CLAVICLE": ["clavicle_r", "CC_Base_R_Clavicle"],
    "LEFT_UPPERARM": ["upperarm_l", "CC_Base_L_Upperarm"],
    "RIGHT_UPPERARM": ["upperarm_r", "CC_Base_R_Upperarm"],
    "LEFT_FOREARM": ["lowerarm_l", "CC_Base_L_Forearm", "forearm_l"],
    "RIGHT_FOREARM": ["lowerarm_r", "CC_Base_R_Forearm", "forearm_r"],
    "LEFT_HAND": ["hand_l", "CC_Base_L_Hand"],
    "RIGHT_HAND": ["hand_r", "CC_Base_R_Hand"],
    "LEFT_THIGH": ["thigh_l", "CC_Base_L_Thigh"],
    "RIGHT_THIGH": ["thigh_r", "CC_Base_R_Thigh"],
    "LEFT_CALF": ["calf_l", "CC_Base_L_Calf"],
    "RIGHT_CALF": ["calf_r", "CC_Base_R_Calf"],
    "LEFT_FOOT": ["foot_l", "CC_Base_L_Foot"],
    "RIGHT_FOOT": ["foot_r", "CC_Base_R_Foot"],
    "LEFT_BALL": ["ball_l", "CC_Base_L_ToeBase", "toe_l"],
    "RIGHT_BALL": ["ball_r", "CC_Base_R_ToeBase", "toe_r"],
}

FINGER_SLOTS = []
for side, tag in (("LEFT", "l"), ("RIGHT", "r")):
    for finger in ("INDEX", "MIDDLE", "RING", "PINKY", "THUMB"):
        fl = finger.lower()
        for seg in (1, 2, 3):
            key = "%s_%s_0%d" % (side, finger, seg)
            FINGER_SLOTS.append(key)
            SEMANTIC_CANDIDATES[key] = [
                "%s_0%d_%s" % (fl, seg, tag),
                "CC_Base_%s_%s%d" % (side[0], finger.title(), seg),
                "CC_Base_%s_%s%d" % (side[0], finger.capitalize(), seg),
            ]
        meta_key = "%s_%s_METACARPAL" % (side, finger)
        SEMANTIC_CANDIDATES[meta_key] = ["%s_metacarpal_%s" % (fl, tag)]

HELPER_TOKENS = (
    "twist",
    "share",
    "ik_",
    "_ik",
    "facial",
    "tongue",
    "teeth",
    "jaw",
    "eye",
    "breast",
    "rib",
    "root",
)

ALIGN_SEMANTIC = [
    "HIP",
    "HEAD",
    "LEFT_HAND",
    "RIGHT_HAND",
    "LEFT_FOOT",
    "RIGHT_FOOT",
    "LEFT_CLAVICLE",
    "RIGHT_CLAVICLE",
]

WEIGHT_JOINTS = [
    ("shoulder", "LEFT_UPPERARM"),
    ("elbow", "LEFT_FOREARM"),
    ("wrist", "LEFT_HAND"),
    ("hip", "LEFT_THIGH"),
    ("knee", "LEFT_CALF"),
    ("ankle", "LEFT_FOOT"),
    ("index_01", "LEFT_INDEX_01"),
    ("middle_01", "LEFT_MIDDLE_01"),
    ("thumb_01", "LEFT_THUMB_01"),
]

ARTICULATION_SPEC = [
    {"id": "arm_upperarm_30", "semantic": "LEFT_UPPERARM", "angle": 30.0, "kind": "swing", "group": "arm",
     "follow": ["LEFT_FOREARM", "LEFT_HAND", "LEFT_INDEX_01"], "opposite": ["RIGHT_HAND"]},
    {"id": "arm_upperarm_60", "semantic": "LEFT_UPPERARM", "angle": 60.0, "kind": "swing", "group": "arm",
     "follow": ["LEFT_FOREARM", "LEFT_HAND", "LEFT_INDEX_01"], "opposite": ["RIGHT_HAND"]},
    {"id": "arm_forearm_45", "semantic": "LEFT_FOREARM", "angle": 45.0, "kind": "hinge", "group": "arm",
     "follow": ["LEFT_HAND", "LEFT_INDEX_01"], "opposite": ["RIGHT_HAND"]},
    {"id": "arm_forearm_90", "semantic": "LEFT_FOREARM", "angle": 90.0, "kind": "hinge", "group": "arm",
     "follow": ["LEFT_HAND", "LEFT_INDEX_01"], "opposite": ["RIGHT_HAND"]},
    {"id": "arm_wrist_mild", "semantic": "LEFT_HAND", "angle": 20.0, "kind": "twist", "group": "arm",
     "follow": ["LEFT_INDEX_01"], "opposite": ["RIGHT_HAND"]},
    {"id": "hand_index_bend", "semantic": "LEFT_INDEX_01", "angle": 45.0, "kind": "finger", "group": "hand",
     "follow": ["LEFT_INDEX_02", "LEFT_INDEX_03"], "neighbor": ["LEFT_MIDDLE_01"], "opposite": ["RIGHT_INDEX_01"]},
    {"id": "hand_middle_bend", "semantic": "LEFT_MIDDLE_01", "angle": 45.0, "kind": "finger", "group": "hand",
     "follow": ["LEFT_MIDDLE_02", "LEFT_MIDDLE_03"], "neighbor": ["LEFT_INDEX_01"], "opposite": ["RIGHT_MIDDLE_01"]},
    {"id": "hand_thumb_bend", "semantic": "LEFT_THUMB_01", "angle": 35.0, "kind": "finger", "group": "hand",
     "follow": ["LEFT_THUMB_02", "LEFT_THUMB_03"], "neighbor": ["LEFT_INDEX_01"], "opposite": ["RIGHT_THUMB_01"]},
    {"id": "hand_all_curl", "semantic": None, "angle": 30.0, "kind": "curl_all", "group": "hand",
     "follow": [], "opposite": ["RIGHT_HAND"]},
    {"id": "leg_thigh_30", "semantic": "LEFT_THIGH", "angle": 30.0, "kind": "swing", "group": "leg",
     "follow": ["LEFT_CALF", "LEFT_FOOT"], "opposite": ["RIGHT_FOOT"]},
    {"id": "leg_thigh_45", "semantic": "LEFT_THIGH", "angle": 45.0, "kind": "swing", "group": "leg",
     "follow": ["LEFT_CALF", "LEFT_FOOT"], "opposite": ["RIGHT_FOOT"]},
    {"id": "leg_calf_60", "semantic": "LEFT_CALF", "angle": 60.0, "kind": "hinge", "group": "leg",
     "follow": ["LEFT_FOOT"], "opposite": ["RIGHT_FOOT"]},
    {"id": "leg_calf_90", "semantic": "LEFT_CALF", "angle": 90.0, "kind": "hinge", "group": "leg",
     "follow": ["LEFT_FOOT"], "opposite": ["RIGHT_FOOT"]},
    {"id": "leg_foot_mild", "semantic": "LEFT_FOOT", "angle": 20.0, "kind": "twist", "group": "leg",
     "follow": ["LEFT_BALL"], "opposite": ["RIGHT_FOOT"]},
    {"id": "torso_spine_pitch", "semantic": "SPINE", "angle": 20.0, "kind": "pitch", "group": "torso",
     "follow": ["HEAD"], "opposite": []},
    {"id": "torso_spine_yaw", "semantic": "SPINE", "angle": 20.0, "kind": "yaw", "group": "torso",
     "follow": ["HEAD"], "opposite": []},
    {"id": "head_yaw", "semantic": "HEAD", "angle": 20.0, "kind": "yaw", "group": "head",
     "follow": [], "opposite": []},
    {"id": "head_pitch", "semantic": "HEAD", "angle": 15.0, "kind": "pitch", "group": "head",
     "follow": [], "opposite": []},
]

ROUNDTRIP_SUBSET = ["arm_upperarm_60", "arm_forearm_90", "leg_thigh_30", "leg_calf_90"]
# Remap 60° upperarm test to 45° for the GLB subset as specified.
ROUNDTRIP_OVERRIDE_ANGLE = {"arm_upperarm_60": 45.0}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--character", choices=["jaguarete", "terere", "both"], default="both")
    return p.parse_args(argv)


def iso_mtime(path):
    if not os.path.isfile(path) and not os.path.isdir(path):
        return None
    return datetime.fromtimestamp(os.path.getmtime(path)).isoformat()


def sha256_file(path, chunk=1024 * 1024):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        while True:
            block = fh.read(chunk)
            if not block:
                break
            h.update(block)
    return h.hexdigest()


def list_files(root):
    out = []
    if not os.path.isdir(root):
        return out
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            out.append(os.path.join(dirpath, name))
    return out


def resolve_character_paths(character):
    cfg = CHARACTERS[character]
    found_dir = None
    for cand in cfg["dir_candidates"]:
        d = os.path.join(V5_ROOT, cand)
        if os.path.isdir(d):
            found_dir = d
            break
    if found_dir is None:
        found_dir = os.path.join(V5_ROOT, cfg["dir_candidates"][0])
    fbx = os.path.join(found_dir, cfg["fbx_name"])
    sidecar = os.path.join(found_dir, cfg["json_name"])
    fbm = os.path.join(found_dir, os.path.splitext(cfg["fbx_name"])[0] + ".fbm")
    textures = os.path.join(found_dir, "textures")
    out_dir = os.path.join(CLEAN_V5_ROOT, character)
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(GENERATED_DIR, exist_ok=True)
    return {
        "character": character,
        "label": cfg["label"],
        "source_dir": found_dir,
        "fbx": fbx,
        "json": sidecar,
        "fbm_dir": fbm,
        "textures_dir": textures,
        "out_dir": out_dir,
        "blend": os.path.join(out_dir, "%s_clean_rig_v5.blend" % character),
        "glb": os.path.join(out_dir, "%s_clean_rig_v5.glb" % character),
        "canonical_height": cfg["canonical_height"],
    }


def sidecar_counts(json_path):
    rec = {
        "source_vertex_count": None,
        "source_material_count": None,
        "source_skeleton_count": None,
        "source_collision_bone_count": None,
        "json_mesh_names": [],
        "json_material_names": [],
        "json_texture_entries": {},
    }
    if not os.path.isfile(json_path):
        return rec
    with open(json_path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    obj = None
    if isinstance(data, dict):
        for _k, v in data.items():
            if isinstance(v, dict) and "Object" in v:
                obj = v["Object"]
                break
    bones = []
    materials = []
    if isinstance(obj, dict):
        for _oname, odata in obj.items():
            phys = (((odata or {}).get("Physics") or {}).get("Collision Shapes") or {})
            for bname in phys.keys():
                if bname != "meshes_0_":
                    bones.append(bname)
            meshes = (odata or {}).get("Meshes") or {}
            rec["json_mesh_names"] = list(meshes.keys())
            for mname, mdata in meshes.items():
                mats = (mdata or {}).get("Materials") or {}
                for mat_name, mat in mats.items():
                    materials.append(mat_name)
                    rec["json_texture_entries"][mat_name] = {
                        "Textures": (mat or {}).get("Textures") or {},
                        "Resource Textures": (mat or {}).get("Resource Textures") or {},
                    }
    rec["source_skeleton_count"] = 1 if bones else None
    rec["source_collision_bone_count"] = len(bones)
    rec["source_material_count"] = len(materials)
    rec["json_material_names"] = materials
    return rec


def source_inventory():
    gdignore = os.path.join(V5_ROOT, ".gdignore")
    inventory = {
        "generated_at": datetime.now().isoformat(),
        "root": V5_ROOT,
        "gdignore": gdignore,
        "gdignore_exists": os.path.isfile(gdignore),
        "fighters": {},
    }
    for character in ("jaguarete", "terere"):
        paths = resolve_character_paths(character)
        tex_files = list_files(paths["textures_dir"])
        fbm_files = list_files(paths["fbm_dir"])
        sidecar = sidecar_counts(paths["json"])
        rec = {
            "character": character,
            "label": paths["label"],
            "source_dir": paths["source_dir"],
            "fbx_path": paths["fbx"],
            "json_path": paths["json"],
            "texture_folders": [paths["textures_dir"], paths["fbm_dir"]],
            "texture_files": tex_files,
            "fbm_files": fbm_files,
            "fbx_exists": os.path.isfile(paths["fbx"]),
            "json_exists": os.path.isfile(paths["json"]),
            "fbx_size_bytes": os.path.getsize(paths["fbx"]) if os.path.isfile(paths["fbx"]) else 0,
            "json_size_bytes": os.path.getsize(paths["json"]) if os.path.isfile(paths["json"]) else 0,
            "fbx_sha256": sha256_file(paths["fbx"]) if os.path.isfile(paths["fbx"]) else None,
            "json_sha256": sha256_file(paths["json"]) if os.path.isfile(paths["json"]) else None,
            "fbx_modified": iso_mtime(paths["fbx"]),
            "json_modified": iso_mtime(paths["json"]),
            "texture_file_count": len(tex_files),
            "fbm_file_count": len(fbm_files),
        }
        rec.update(sidecar)
        inventory["fighters"][character] = rec
    return inventory


def import_source_fbx(path):
    bpy.ops.import_scene.fbx(
        filepath=path,
        automatic_bone_orientation=False,
        ignore_leaf_bones=False,
        force_connect_children=False,
        use_anim=False,
    )


def reset_shape_keys(meshes):
    names = []
    for me in meshes:
        sk = me.data.shape_keys
        if sk is None:
            continue
        for kb in sk.key_blocks:
            kb.value = 0.0
            names.append("%s:%s" % (me.name, kb.name))
        if me.data.shape_keys.animation_data:
            me.data.shape_keys.animation_data_clear()
    bpy.context.view_layer.update()
    return names


def skinned_meshes(arm):
    out = []
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for mod in obj.modifiers:
            if mod.type == "ARMATURE" and (mod.object == arm or mod.object is None):
                out.append(obj)
                break
    if not out:
        out = [o for o in bpy.data.objects if o.type == "MESH"]
    return out


def bone_lookup(arm):
    table = {}
    for bone in arm.data.bones:
        table[bone.name] = bone.name
        table[bone.name.lower()] = bone.name
    return table


def is_helper_name(name):
    n = name.lower()
    return any(tok in n for tok in HELPER_TOKENS)


def resolve_semantic(arm, role):
    table = bone_lookup(arm)
    for cand in SEMANTIC_CANDIDATES.get(role, []):
        hit = table.get(cand) or table.get(cand.lower())
        if hit:
            if is_helper_name(hit) and not role.startswith("NECK"):
                # Prefer non-helper if later candidates exist; otherwise accept.
                continue
            return hit
    # Fallback: unique substring match excluding helpers.
    role_l = role.lower()
    tokens = []
    if "UPPERARM" in role:
        tokens = ["upperarm"]
    elif "FOREARM" in role:
        tokens = ["lowerarm", "forearm"]
    elif "HAND" in role:
        tokens = ["hand"]
    elif "THIGH" in role:
        tokens = ["thigh"]
    elif "CALF" in role:
        tokens = ["calf"]
    elif "FOOT" in role:
        tokens = ["foot"]
    hits = []
    side = None
    if role.startswith("LEFT_"):
        side = "l"
    elif role.startswith("RIGHT_"):
        side = "r"
    for bone in arm.data.bones:
        n = bone.name.lower()
        if is_helper_name(bone.name):
            continue
        if tokens and not any(t in n for t in tokens):
            continue
        if side == "l" and not (
            n.endswith("_l") or "_l_" in n or "left" in n or n.startswith("cc_base_l_")
        ):
            continue
        if side == "r" and not (
            n.endswith("_r") or "_r_" in n or "right" in n or n.startswith("cc_base_r_")
        ):
            continue
        if tokens:
            hits.append(bone.name)
    if len(hits) == 1:
        return hits[0]
    return None


def build_semantic_map(arm):
    mapping = {}
    for role in SEMANTIC_CANDIDATES:
        name = resolve_semantic(arm, role)
        mapping[role] = {
            "bone": name,
            "present": name is not None,
            "is_helper": is_helper_name(name) if name else False,
            "candidates": SEMANTIC_CANDIDATES[role],
        }
    # Second pass: if a helper slipped in, try exact non-helper from table.
    table = bone_lookup(arm)
    for role, rec in mapping.items():
        if rec["bone"] and rec["is_helper"]:
            for cand in rec["candidates"]:
                hit = table.get(cand.lower())
                if hit and not is_helper_name(hit):
                    rec["bone"] = hit
                    rec["present"] = True
                    rec["is_helper"] = False
                    break
    return mapping


def sem_name(smap, role):
    rec = smap.get(role) or {}
    return rec.get("bone") if rec.get("present") else None


def world_head(arm, name):
    bone = arm.data.bones.get(name)
    if bone is None:
        return None
    return arm.matrix_world @ bone.head_local


def world_tail(arm, name):
    bone = arm.data.bones.get(name)
    if bone is None:
        return None
    return arm.matrix_world @ bone.tail_local


def pose_world_head(arm, name):
    pb = arm.pose.bones.get(name)
    if pb is None:
        return None
    return arm.matrix_world @ pb.head


def pose_world_tail(arm, name):
    pb = arm.pose.bones.get(name)
    if pb is None:
        return None
    return arm.matrix_world @ pb.tail


def clear_pose(arm):
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
        pb.location = Vector((0.0, 0.0, 0.0))
        pb.scale = Vector((1.0, 1.0, 1.0))
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.rotation_euler = Euler((0.0, 0.0, 0.0))
    bpy.context.view_layer.update()


def reset_shapekeys(meshes):
    rec = []
    for me in meshes:
        sk = me.data.shape_keys
        if sk is None:
            rec.append({"mesh": me.name, "shape_keys": 0})
            continue
        names = []
        for kb in sk.key_blocks:
            kb.value = 0.0
            names.append(kb.name)
        rec.append({"mesh": me.name, "shape_keys": len(names), "names_sample": names[:12]})
    bpy.context.view_layer.update()
    return rec


def transform_mesh_and_shapekeys(obj, matrix):
    """Bake an object matrix into mesh data, including shapekeys (Blender 2.83)."""
    original = []
    sk = obj.data.shape_keys
    if sk is not None:
        for kb in sk.key_blocks:
            original.append([p.co.copy() for p in kb.data])
    obj.data.transform(matrix)
    if sk is not None:
        for kb, coords in zip(sk.key_blocks, original):
            for i, co in enumerate(coords):
                kb.data[i].co = matrix @ co


def strategy_b_bake_world_with_shapes(arm, meshes):
    for me in meshes:
        unparent_keep_world(me)
    unparent_keep_world(arm)
    bpy.context.view_layer.update()
    mw_arm = arm.matrix_world.copy()
    method = transform_armature_data(arm, mw_arm)
    set_identity_basis(arm)
    for me in meshes:
        mw = me.matrix_world.copy()
        transform_mesh_and_shapekeys(me, mw)
        set_identity_basis(me)
        for mod in me.modifiers:
            if mod.type == "ARMATURE":
                mod.object = arm
                mod.use_vertex_groups = True
    bpy.context.view_layer.update()
    clear_pose(arm)
    return {
        "strategy": "B_bake_world_into_data_with_shapekeys",
        "armature_transform_method": method,
    }


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
        "vertex_group_names_sorted": sorted(names),
        "unweighted_vertices": unweighted,
        "mean_influences": round(sum(counts) / float(len(counts)), 4) if counts else 0.0,
        "max_influences": max(counts) if counts else 0,
        "influence_histogram": {str(k): v for k, v in sorted(inf_hist.items())},
        "clamped_to_four": False,
    }


def dump_materials():
    mats = []
    for mat in bpy.data.materials:
        images = []
        if mat.use_nodes and mat.node_tree:
            for node in mat.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image:
                    images.append({
                        "image": node.image.name,
                        "filepath": getattr(node.image, "filepath", ""),
                        "packed": bool(getattr(node.image, "packed_file", None)),
                        "size": list(node.image.size) if getattr(node.image, "size", None) else None,
                    })
        mats.append({"name": mat.name, "images": images})
    images = []
    for img in bpy.data.images:
        images.append({
            "name": img.name,
            "filepath": img.filepath,
            "packed": bool(getattr(img, "packed_file", None)),
            "size": list(img.size) if getattr(img, "size", None) else None,
            "source": img.source,
        })
    return {"materials": mats, "images": images}


def dump_bone_record(arm, bone):
    head_w = arm.matrix_world @ bone.head_local
    tail_w = arm.matrix_world @ bone.tail_local
    return {
        "name": bone.name,
        "parent": bone.parent.name if bone.parent else None,
        "children": [c.name for c in bone.children],
        "deform": bool(bone.use_deform),
        "connected": bool(bone.use_connect),
        "is_helper": is_helper_name(bone.name),
        "head_world": vec_list(head_w),
        "tail_world": vec_list(tail_w),
        "length": round((tail_w - head_w).length, 6),
        "head_local": vec_list(bone.head_local),
        "tail_local": vec_list(bone.tail_local),
    }


def anatomical_ok(arm, smap):
    pelvis = sem_name(smap, "PELVIS") or sem_name(smap, "HIP")
    head = sem_name(smap, "HEAD")
    l_foot = sem_name(smap, "LEFT_FOOT")
    r_foot = sem_name(smap, "RIGHT_FOOT")
    l_hand = sem_name(smap, "LEFT_HAND")
    r_hand = sem_name(smap, "RIGHT_HAND")
    rec = {"upright": False, "head_above_hips": False, "feet_below_hips": False, "front_heuristic": None}
    if pelvis and head:
        hp = world_head(arm, pelvis)
        hd = world_head(arm, head)
        rec["head_above_hips"] = hd.z > hp.z + 0.05
        rec["pelvis_world"] = vec_list(hp)
        rec["head_world"] = vec_list(hd)
    if pelvis and l_foot and r_foot:
        hp = world_head(arm, pelvis)
        lf = world_head(arm, l_foot)
        rf = world_head(arm, r_foot)
        rec["feet_below_hips"] = (lf.z < hp.z - 0.05) and (rf.z < hp.z - 0.05)
        rec["left_foot_world"] = vec_list(lf)
        rec["right_foot_world"] = vec_list(rf)
    rec["upright"] = bool(rec["head_above_hips"] and rec["feet_below_hips"])
    if l_hand and r_hand:
        rec["left_hand_world"] = vec_list(world_head(arm, l_hand))
        rec["right_hand_world"] = vec_list(world_head(arm, r_hand))
    # Front: +Y in Blender is typically back after FBX; character faces -Y.
    rec["front_heuristic"] = "blender_-Y_expected_after_fbx_axis_conversion"
    return rec


def classify_bind_space(arm, meshes):
    A = arm.matrix_world.copy()
    mesh_recs = []
    same_space = True
    for me in meshes:
        M = me.matrix_world.copy()
        T = A.inverted() @ M
        loc_t, rot_t, scl_t = T.decompose()
        ident = is_nearly_identity(T, tol=1e-3)
        if not ident:
            same_space = False
        mesh_recs.append({
            "mesh": me.name,
            "Ainv_M_is_identity": ident,
            "Ainv_M_translation": vec_list(loc_t),
            "Ainv_M_rotation_deg": [round(math.degrees(a), 4) for a in rot_t.to_euler("XYZ")],
            "Ainv_M_scale": vec_list(scl_t),
            "parent": me.parent.name if me.parent else None,
            "parent_inverse_is_identity": is_nearly_identity(me.matrix_parent_inverse),
            "mesh_basis_is_identity": is_nearly_identity(me.matrix_basis),
            "object": dump_object(me),
        })
    bone_bb = armature_world_bbox(arm)
    mesh_bb = mesh_vertex_world_bbox(meshes[0]) if meshes else None
    sep = None
    if mesh_bb:
        sep = (Vector(bone_bb["center"]) - Vector(mesh_bb["center"])).length
    arm_ident = object_is_identity(arm, tol=2e-3)
    mesh_ident = all(object_is_identity(m, tol=2e-3) for m in meshes) if meshes else False
    loc_a, rot_a, scl_a = A.decompose()
    compensated = (not same_space) or (sep is not None and sep > 0.25) or (
        rot_a.angle > 0.2 and not same_space
    )
    # If A≈M and bones sit in the mesh bbox, treat as clean even if objects have uniform scale.
    inside = False
    if mesh_bb:
        bc = Vector(bone_bb["center"])
        mn = Vector(mesh_bb["min"])
        mx = Vector(mesh_bb["max"])
        pad = Vector((0.15, 0.15, 0.15))
        inside = (
            mn.x - pad.x <= bc.x <= mx.x + pad.x
            and mn.y - pad.y <= bc.y <= mx.y + pad.y
            and mn.z - pad.z <= bc.z <= mx.z + pad.z
        )
    if same_space and inside:
        label = "V5_BIND_SPACE_CLEAN"
    else:
        label = "V5_BIND_SPACE_COMPENSATED"
        compensated = True
    return {
        "label": label,
        "compensated": compensated,
        "same_object_space": same_space,
        "bones_inside_mesh_bbox": inside,
        "world_separation_bone_center_to_mesh_center": round(sep, 6) if sep is not None else None,
        "armature_object_identity": arm_ident,
        "mesh_object_identity": mesh_ident,
        "armature": dump_object(arm),
        "meshes": mesh_recs,
        "mesh_world_bbox": mesh_bb,
        "armature_world_bbox": bone_bb,
    }


def chain_rows(arm, names):
    rows = []
    for name in names:
        if name not in arm.data.bones:
            rows.append({"name": name, "present": False})
            continue
        rec = dump_bone_record(arm, arm.data.bones[name])
        rec["present"] = True
        rec["anatomically_located"] = rec["length"] > 1e-5
        rows.append(rec)
    return rows


def primary_chains(arm, smap):
    def g(*roles):
        names = []
        for r in roles:
            n = sem_name(smap, r)
            if n:
                names.append(n)
        return names

    return {
        "spine_arm_left": chain_rows(arm, g(
            "PELVIS", "SPINE", "SPINE_02", "SPINE_03", "CHEST",
            "LEFT_CLAVICLE", "LEFT_UPPERARM", "LEFT_FOREARM", "LEFT_HAND",
        )),
        "spine_arm_right": chain_rows(arm, g(
            "PELVIS", "SPINE", "LEFT_CLAVICLE", "RIGHT_CLAVICLE",
            "RIGHT_UPPERARM", "RIGHT_FOREARM", "RIGHT_HAND",
        )),
        "leg_left": chain_rows(arm, g("PELVIS", "LEFT_THIGH", "LEFT_CALF", "LEFT_FOOT", "LEFT_BALL")),
        "leg_right": chain_rows(arm, g("PELVIS", "RIGHT_THIGH", "RIGHT_CALF", "RIGHT_FOOT", "RIGHT_BALL")),
        "fingers_left": chain_rows(arm, [
            sem_name(smap, k) for k in (
                "LEFT_INDEX_01", "LEFT_INDEX_02", "LEFT_INDEX_03",
                "LEFT_MIDDLE_01", "LEFT_MIDDLE_02", "LEFT_MIDDLE_03",
                "LEFT_RING_01", "LEFT_RING_02", "LEFT_RING_03",
                "LEFT_PINKY_01", "LEFT_PINKY_02", "LEFT_PINKY_03",
                "LEFT_THUMB_01", "LEFT_THUMB_02", "LEFT_THUMB_03",
            ) if sem_name(smap, k)
        ]),
        "fingers_right": chain_rows(arm, [
            sem_name(smap, k) for k in (
                "RIGHT_INDEX_01", "RIGHT_INDEX_02", "RIGHT_INDEX_03",
                "RIGHT_MIDDLE_01", "RIGHT_MIDDLE_02", "RIGHT_MIDDLE_03",
                "RIGHT_RING_01", "RIGHT_RING_02", "RIGHT_RING_03",
                "RIGHT_PINKY_01", "RIGHT_PINKY_02", "RIGHT_PINKY_03",
                "RIGHT_THUMB_01", "RIGHT_THUMB_02", "RIGHT_THUMB_03",
            ) if sem_name(smap, k)
        ]),
    }


def collect_weights(mesh_obj, bone_name):
    vg = mesh_obj.vertex_groups.get(bone_name)
    if vg is None:
        return []
    pts = []
    mw = mesh_obj.matrix_world
    for v in mesh_obj.data.vertices:
        w = 0.0
        for g in v.groups:
            if g.group == vg.index:
                w = g.weight
                break
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


def evaluated_points(mesh):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(deps)
    return [ev.matrix_world @ v.co for v in ev.data.vertices]


def displacement_stats(rest_pts, posed_pts):
    n = min(len(rest_pts), len(posed_pts))
    if n == 0:
        return {
            "max_disp": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0,
            "extreme_verts": 0, "nan_count": 0, "inf_count": 0,
        }
    disps = []
    nan_c = 0
    inf_c = 0
    for i in range(n):
        d = (posed_pts[i] - rest_pts[i]).length
        if math.isnan(d):
            nan_c += 1
            continue
        if math.isinf(d):
            inf_c += 1
            continue
        disps.append(d)
    if not disps:
        return {
            "max_disp": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0,
            "extreme_verts": 0, "nan_count": nan_c, "inf_count": inf_c,
        }
    disps.sort()
    def pct(p):
        idx = min(len(disps) - 1, max(0, int(round((p / 100.0) * (len(disps) - 1)))))
        return disps[idx]
    p50 = pct(50)
    p95 = pct(95)
    return {
        "max_disp": round(disps[-1], 6),
        "p50": round(p50, 6),
        "p95": round(p95, 6),
        "p99": round(pct(99), 6),
        "nan_count": nan_c,
        "inf_count": inf_c,
        "count": len(disps),
    }


def rotate_pose_bone(arm, name, axis, angle_deg):
    pb = arm.pose.bones[name]
    pb.rotation_mode = "QUATERNION"
    axis_v = Vector(axis).normalized()
    pb.rotation_quaternion = Quaternion(axis_v, math.radians(angle_deg))
    pb.location = Vector((0.0, 0.0, 0.0))
    pb.scale = Vector((1.0, 1.0, 1.0))


def character_basis(arm, smap):
    hip_n = sem_name(smap, "PELVIS") or sem_name(smap, "HIP")
    head_n = sem_name(smap, "HEAD")
    lu = sem_name(smap, "LEFT_UPPERARM")
    ru = sem_name(smap, "RIGHT_UPPERARM")
    up = Vector((0.0, 0.0, 1.0))
    if hip_n and head_n:
        up = (world_head(arm, head_n) - world_head(arm, hip_n))
        if up.length > 1e-6:
            up.normalize()
    right_dir = Vector((1.0, 0.0, 0.0))
    if lu and ru:
        right_dir = (world_head(arm, ru) - world_head(arm, lu))
        if right_dir.length > 1e-6:
            right_dir.normalize()
    forward = up.cross(right_dir)
    if forward.length < 0.1:
        forward = Vector((0.0, -1.0, 0.0))
    else:
        forward.normalize()
    return up, forward, right_dir


def pick_pose_axis(arm, meshes, bone_name, angle_deg, kind, child_name=None):
    rest_bb = evaluated_world_bbox(meshes[0])
    rest_vol = bbox_volume(rest_bb)
    rest_child = pose_world_head(arm, child_name) if child_name else None
    rest_tail = pose_world_tail(arm, bone_name)
    best = None
    axes = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))
    for axis in axes:
        for sign in (1.0, -1.0):
            clear_pose(arm)
            rotate_pose_bone(arm, bone_name, axis, sign * angle_deg)
            bpy.context.view_layer.update()
            posed_bb = evaluated_world_bbox(meshes[0])
            vol = bbox_volume(posed_bb)
            ratio = vol / rest_vol if rest_vol > 1e-8 else 99.0
            exploded = (ratio > 2.4) or (ratio < 0.35)
            child_travel = 0.0
            if rest_child is not None and child_name:
                posed_child = pose_world_head(arm, child_name)
                if posed_child is not None:
                    child_travel = (posed_child - rest_child).length
            elif rest_tail is not None:
                posed_tail = pose_world_tail(arm, bone_name)
                child_travel = (posed_tail - rest_tail).length
            score = child_travel
            if kind == "hinge" and rest_child is not None:
                # Prefer bringing the child toward the posed bone head (flex).
                parent_head = pose_world_head(arm, bone_name)
                posed_child = pose_world_head(arm, child_name)
                if parent_head is not None and posed_child is not None:
                    rest_len = (rest_child - world_head(arm, bone_name)).length
                    posed_len = (posed_child - parent_head).length
                    score = (rest_len - posed_len) + child_travel * 0.15
            rec = {
                "axis": axis,
                "sign": sign,
                "volume_ratio": ratio,
                "exploded": exploded,
                "child_travel": child_travel,
                "score": score,
            }
            if exploded:
                continue
            if best is None or rec["score"] > best["score"]:
                best = rec
    clear_pose(arm)
    if best is None:
        return {"axis": (1.0, 0.0, 0.0), "sign": 1.0, "volume_ratio": 1.0, "exploded": True, "child_travel": 0.0}
    return best


def follow_ok(rest, posed, min_travel):
    if rest is None or posed is None:
        return False, 0.0
    d = (posed - rest).length
    return d >= min_travel, d


def run_one_articulation(arm, meshes, smap, spec, axis_cache, rest_pts):
    kind = spec["kind"]
    angle = spec["angle"]
    group = spec["group"]
    if kind == "curl_all":
        fingers = []
        for role in (
            "LEFT_INDEX_01", "LEFT_MIDDLE_01", "LEFT_RING_01", "LEFT_PINKY_01", "LEFT_THUMB_01"
        ):
            n = sem_name(smap, role)
            if n:
                fingers.append((role, n))
        if not fingers:
            return {"id": spec["id"], "pass": False, "missing": True, "group": group}
        rest_bb = evaluated_world_bbox(meshes[0])
        rest_vol = bbox_volume(rest_bb)
        clear_pose(arm)
        used = []
        for role, name in fingers:
            child = None
            for nxt in ("%s_02" % role[:-1], role.replace("_01", "_02")):
                pass
            child_role = role.replace("_01", "_02")
            child = sem_name(smap, child_role)
            picked = pick_pose_axis(arm, meshes, name, angle, "finger", child)
            rotate_pose_bone(arm, name, picked["axis"], picked["sign"] * angle)
            used.append({"bone": name, "axis": list(picked["axis"]), "sign": picked["sign"]})
        bpy.context.view_layer.update()
        posed_pts = evaluated_points(meshes[0])
        posed_bb = evaluated_world_bbox(meshes[0])
        disp = displacement_stats(rest_pts, posed_pts)
        ratio = bbox_volume(posed_bb) / rest_vol if rest_vol > 1e-8 else 99.0
        mesh_h = max(rest_bb["size"][0], rest_bb["size"][1], rest_bb["size"][2], 0.2)
        spike = max(0.7 * mesh_h, (disp.get("p95") or 0.0) * 5.0, 0.4)
        exploded = (
            ratio > 2.4
            or ratio < 0.35
            or bool(disp.get("nan_count"))
            or bool(disp.get("inf_count"))
            or (disp.get("max_disp") or 0.0) > spike
        )
        clear_pose(arm)
        return {
            "id": spec["id"],
            "group": group,
            "kind": kind,
            "angle_deg": angle,
            "bones": used,
            "bbox_ratio": round(ratio, 4),
            "volume_ratio": round(ratio, 4),
            "displacement": disp,
            "exploded": exploded,
            "pass": not exploded,
            "required": True,
        }

    bone_role = spec["semantic"]
    bone_name = sem_name(smap, bone_role)
    if not bone_name:
        return {"id": spec["id"], "semantic": bone_role, "pass": False, "missing": True, "group": group, "required": True}

    follow_roles = spec.get("follow") or []
    child_name = None
    for fr in follow_roles:
        n = sem_name(smap, fr)
        if n:
            child_name = n
            break
    cache_key = (bone_name, kind)
    if cache_key not in axis_cache:
        axis_cache[cache_key] = pick_pose_axis(arm, meshes, bone_name, min(25.0, angle), kind, child_name)
    picked = axis_cache[cache_key]

    rest_follow = {}
    for fr in follow_roles:
        n = sem_name(smap, fr)
        rest_follow[fr] = pose_world_head(arm, n) if n else None
    rest_opp = {}
    for fr in spec.get("opposite") or []:
        n = sem_name(smap, fr)
        rest_opp[fr] = pose_world_head(arm, n) if n else None
    rest_nei = {}
    for fr in spec.get("neighbor") or []:
        n = sem_name(smap, fr)
        rest_nei[fr] = pose_world_head(arm, n) if n else None

    rest_bb = evaluated_world_bbox(meshes[0])
    rest_vol = bbox_volume(rest_bb)
    hip = sem_name(smap, "PELVIS") or sem_name(smap, "HIP")
    head = sem_name(smap, "HEAD")
    char_h = 1.0
    if hip and head:
        char_h = max(0.2, (world_head(arm, head) - world_head(arm, hip)).length)
    min_follow = char_h * (0.008 if kind in ("finger", "twist", "pitch", "yaw") else 0.02)

    clear_pose(arm)
    rotate_pose_bone(arm, bone_name, picked["axis"], picked["sign"] * angle)
    bpy.context.view_layer.update()

    posed_pts = evaluated_points(meshes[0])
    posed_bb = evaluated_world_bbox(meshes[0])
    disp = displacement_stats(rest_pts, posed_pts)
    ratio = bbox_volume(posed_bb) / rest_vol if rest_vol > 1e-8 else 99.0
    mesh_h = max(rest_bb["size"][0], rest_bb["size"][1], rest_bb["size"][2], 0.2)
    spike = max(0.7 * mesh_h, (disp.get("p95") or 0.0) * 5.0, 0.4)
    exploded = (
        ratio > 2.4
        or ratio < 0.35
        or bool(disp.get("nan_count"))
        or bool(disp.get("inf_count"))
        or (disp.get("max_disp") or 0.0) > spike
    )

    follow_report = []
    follow_pass = True
    for fr in follow_roles:
        n = sem_name(smap, fr)
        posed = pose_world_head(arm, n) if n else None
        ok, dist = follow_ok(rest_follow.get(fr), posed, min_follow)
        # Distal fingers may be missing.
        if n is None:
            follow_report.append({"semantic": fr, "present": False, "pass": True, "optional": True})
            continue
        follow_report.append({"semantic": fr, "bone": n, "travel": round(dist, 5), "pass": ok})
        if not ok:
            follow_pass = False

    opp_fail = False
    opp_report = []
    primary_travel = 0.0
    if follow_report:
        primary_travel = max([r.get("travel", 0.0) for r in follow_report] or [0.0])
    for fr, rest_p in rest_opp.items():
        n = sem_name(smap, fr)
        posed = pose_world_head(arm, n) if n else None
        dist = (posed - rest_p).length if (posed is not None and rest_p is not None) else 0.0
        leak = dist > max(min_follow * 0.6, primary_travel * 0.25) and dist > 0.01
        opp_report.append({"semantic": fr, "travel": round(dist, 5), "cross_side": leak})
        if leak and group in ("arm", "leg", "hand"):
            opp_fail = True

    nei_report = []
    nei_fail = False
    for fr, rest_p in rest_nei.items():
        n = sem_name(smap, fr)
        posed = pose_world_head(arm, n) if n else None
        dist = (posed - rest_p).length if (posed is not None and rest_p is not None) else 0.0
        leak = dist > max(min_follow * 1.2, primary_travel * 0.55)
        nei_report.append({"semantic": fr, "travel": round(dist, 5), "affected": leak})
        if leak:
            nei_fail = True

    # Limb length: parent+child bone chain should not scale.
    limb_err = 0.0
    if child_name:
        rest_len = (world_head(arm, child_name) - world_head(arm, bone_name)).length
        posed_len = (pose_world_head(arm, child_name) - pose_world_head(arm, bone_name)).length
        if rest_len > 1e-6:
            limb_err = abs(posed_len - rest_len) / rest_len

    # Joint locality: opposite-side mesh verts.
    locality = {"opposite_mesh_mean_disp": None, "pass": True}
    l_name = sem_name(smap, "LEFT_HAND")
    r_name = sem_name(smap, "RIGHT_HAND")
    if l_name and r_name and meshes:
        lx = world_head(arm, l_name).x
        rx = world_head(arm, r_name).x
        mid_x = 0.5 * (lx + rx)
        left_is_plus = lx > rx
        # For left tests, opposite verts have x on the right anatomical side.
        opp_disps = []
        n = min(len(rest_pts), len(posed_pts))
        step = max(1, n // 2500)
        for i in range(0, n, step):
            x = rest_pts[i].x
            on_right = x < mid_x if left_is_plus else x > mid_x
            if on_right:
                opp_disps.append((posed_pts[i] - rest_pts[i]).length)
        if opp_disps:
            mean_opp = sum(opp_disps) / float(len(opp_disps))
            locality["opposite_mesh_mean_disp"] = round(mean_opp, 6)
            if group in ("arm", "leg", "hand") and mean_opp > max(0.03, disp["p50"] * 3.0) and mean_opp > disp["p95"] * 0.5:
                locality["pass"] = False

    passed = (not exploded) and follow_pass and (not opp_fail) and (not nei_fail) and locality["pass"] and limb_err < 0.08
    clear_pose(arm)
    return {
        "id": spec["id"],
        "group": group,
        "semantic": bone_role,
        "bone": bone_name,
        "kind": kind,
        "angle_deg": angle,
        "axis": list(picked["axis"]),
        "sign": picked["sign"],
        "bbox_ratio": round(ratio, 4),
        "volume_ratio": round(ratio, 4),
        "limb_length_error": round(limb_err, 6),
        "displacement": disp,
        "follow": follow_report,
        "opposite": opp_report,
        "neighbor": nei_report,
        "locality": locality,
        "exploded": exploded,
        "detached": False,
        "pass": passed,
        "required": True,
        "notes": [],
    }


def run_articulation_suite(arm, meshes, smap, specs=None, angle_overrides=None):
    specs = specs or ARTICULATION_SPEC
    angle_overrides = angle_overrides or {}
    clear_pose(arm)
    rest_pts = evaluated_points(meshes[0]) if meshes else []
    axis_cache = {}
    tests = []
    ok = True
    groups = {"arm": True, "hand": True, "leg": True, "torso": True, "head": True}
    for spec in specs:
        spec2 = dict(spec)
        if spec2["id"] in angle_overrides:
            spec2["angle"] = angle_overrides[spec2["id"]]
        rec = run_one_articulation(arm, meshes, smap, spec2, axis_cache, rest_pts)
        tests.append(rec)
        if rec.get("required") and not rec.get("pass"):
            ok = False
            groups[rec.get("group") or "arm"] = False
    return {"pass": ok, "group_pass": groups, "tests": tests}


def weight_quality(arm, meshes, smap):
    joints = []
    major_reweight = False
    reasons = []
    for label, role in WEIGHT_JOINTS:
        name = sem_name(smap, role)
        row = {"joint": label, "semantic": role, "bone": name, "present": name is not None}
        if not name or name not in arm.data.bones:
            joints.append(row)
            continue
        bone = arm.data.bones[name]
        head = arm.matrix_world @ bone.head_local
        tail = arm.matrix_world @ bone.tail_local
        world_len = (tail - head).length
        radius = max(0.025, min(0.14, world_len * 0.65))
        group_w = Counter()
        max_inf = 0
        sampled = 0
        zero = 0
        for me in meshes:
            mw = me.matrix_world
            idx_to_name = {vg.index: vg.name for vg in me.vertex_groups}
            for v in me.data.vertices:
                p = mw @ v.co
                if (p - head).length > radius:
                    continue
                sampled += 1
                inf = 0
                s = 0.0
                for g in v.groups:
                    if g.weight <= 1e-8:
                        continue
                    inf += 1
                    s += g.weight
                    group_w[idx_to_name.get(g.group, "?")] += g.weight
                max_inf = max(max_inf, inf)
                if inf == 0 or s < 1e-6:
                    zero += 1
        top = group_w.most_common(8)
        row["sampled_vertices"] = sampled
        row["radius"] = round(radius, 5)
        row["zero_weight_gaps"] = zero
        row["max_influences"] = max_inf
        row["top_groups"] = [{"name": n, "weight_sum": round(w, 4)} for n, w in top]
        opp_name = None
        if name.endswith("_l"):
            opp_name = name[:-2] + "_r"
        elif name.endswith("_r"):
            opp_name = name[:-2] + "_l"
        elif "L_" in name:
            opp_name = name.replace("L_", "R_", 1)
        cross = []
        helper_dom = False
        primary_w = 0.0
        helper_w = 0.0
        for n, w in top:
            if opp_name and n == opp_name:
                cross.append(n)
            if is_helper_name(n):
                helper_w += w
            if n == name:
                primary_w += w
        helper_dom = helper_w > primary_w * 3.0 and helper_w > 0
        row["cross_side_groups"] = cross
        row["helper_domination"] = helper_dom
        row["primary_weight_sum"] = round(primary_w, 4)
        row["helper_weight_sum"] = round(helper_w, 4)
        if cross:
            major_reweight = True
            reasons.append("%s cross-side %s" % (label, cross))
        if sampled > 20 and zero > sampled * 0.25:
            major_reweight = True
            reasons.append("%s zero-weight gaps %d/%d" % (label, zero, sampled))
        if sampled > 20 and primary_w < 1e-4 and helper_w < 1e-4:
            major_reweight = True
            reasons.append("%s has no usable weights" % label)
        joints.append(row)
    return {
        "joints": joints,
        "major_reweight_required": major_reweight,
        "reasons": reasons,
    }


def left_right_validation(arm, meshes, smap):
    pairs = [
        ("LEFT_UPPERARM", "RIGHT_UPPERARM"),
        ("LEFT_HAND", "RIGHT_HAND"),
        ("LEFT_THIGH", "RIGHT_THIGH"),
        ("LEFT_FOOT", "RIGHT_FOOT"),
        ("LEFT_INDEX_01", "RIGHT_INDEX_01"),
    ]
    out = []
    ok = True
    for lrole, rrole in pairs:
        lname = sem_name(smap, lrole)
        rname = sem_name(smap, rrole)
        row = {"left_semantic": lrole, "right_semantic": rrole, "left_bone": lname, "right_bone": rname}
        for tag, name in (("left", lname), ("right", rname)):
            if not name or name not in arm.data.bones:
                row[tag] = {"present": False}
                continue
            bone = arm.data.bones[name]
            mid = arm.matrix_world @ ((bone.head_local + bone.tail_local) * 0.5)
            pts = []
            for me in meshes:
                pts.extend(collect_weights(me, name))
            c, _tw, n = weighted_centroid(pts)
            row[tag] = {
                "present": True,
                "bone_world": vec_list(mid),
                "weighted_centroid_world": vec_list(c) if c is not None else None,
                "weighted_verts": n,
            }
        if row.get("left", {}).get("present") and row.get("right", {}).get("present"):
            lx = row["left"]["bone_world"][0]
            rx = row["right"]["bone_world"][0]
            # Anatomical left is the more +X bone in the AccuRIG/Blender convention used by V1.
            row["plus_x_is_left"] = lx > rx
            row["bone_x_order_matches_names"] = (lx - rx) != 0
            lcx = (row["left"].get("weighted_centroid_world") or [None])[0]
            rcx = (row["right"].get("weighted_centroid_world") or [None])[0]
            if lcx is not None and rcx is not None:
                row["weights_same_x_order"] = (lx - rx) * (lcx - rcx) > 0
                row["genuine_lr_inversion"] = (lx - rx) * (lcx - rcx) < 0
                if row["genuine_lr_inversion"]:
                    ok = False
            else:
                row["weights_same_x_order"] = None
            row["pass"] = row.get("genuine_lr_inversion") is not True
        else:
            row["pass"] = False
            if lrole != "LEFT_INDEX_01":
                ok = False
            else:
                row["pass"] = True  # optional if missing
        out.append(row)
    return {"pass": ok, "pairs": out}


def pack_images():
    packed = []
    for img in bpy.data.images:
        if img.source != "FILE" and img.source != "TILED":
            # Still try packing generated/packed FBX embeds.
            pass
        try:
            if img.filepath:
                img.reload()
        except Exception:
            pass
        try:
            img.pack()
            packed.append({"name": img.name, "ok": True, "size": list(img.size) if img.size else None})
        except Exception as exc:
            packed.append({"name": img.name, "ok": False, "error": str(exc)})
    return packed


def hierarchy_sane(smap, chains):
    required = [
        "PELVIS", "SPINE", "HEAD",
        "LEFT_UPPERARM", "LEFT_FOREARM", "LEFT_HAND",
        "RIGHT_UPPERARM", "RIGHT_FOREARM", "RIGHT_HAND",
        "LEFT_THIGH", "LEFT_CALF", "LEFT_FOOT",
        "RIGHT_THIGH", "RIGHT_CALF", "RIGHT_FOOT",
    ]
    missing = [r for r in required if not (smap.get(r) or {}).get("present")]
    fingers_ok = (smap.get("LEFT_INDEX_01") or {}).get("present") and (smap.get("LEFT_THUMB_01") or {}).get("present")
    return {"pass": not missing and fingers_ok, "missing_required": missing, "fingers_present": fingers_ok}


def apply_clean_transforms(arm, meshes, bind, smap):
    decision = {
        "choice": None,
        "applied": [],
        "notes": [],
    }
    A_pre = arm.matrix_world.copy()
    M_pre = meshes[0].matrix_world.copy() if meshes else Matrix.Identity(4)

    if bind["label"] == "V5_BIND_SPACE_CLEAN":
        decision["choice"] = "V5_NATIVE_BIND_PRESERVED"
        decision["notes"].append("Mesh and armature occupy the same object space; bones sit inside the mesh bbox.")
        decision["notes"].append("Did not apply Clean Rig V1 Rx-90 bind reconstruction.")
        if not (object_is_identity(arm) and all(object_is_identity(m) for m in meshes)):
            bake = strategy_b_bake_world_with_shapes(arm, meshes)
            decision["applied"].append(bake)
            decision["notes"].append(
                "Baked uniform FBX 0.01 scale into data including shapekeys so object bases are identity."
            )
        bb = mesh_vertex_world_bbox(meshes[0]) if meshes else None
        min_z = (bb or {}).get("min", [0, 0, 0])[2]
        if bb is not None and abs(min_z) > 0.03:
            dz = -min_z
            T = Matrix.Translation((0.0, 0.0, dz))
            transform_armature_data(arm, T)
            for me in meshes:
                unparent_keep_world(me)
                transform_mesh_and_shapekeys(me, T)
                set_identity_basis(me)
            set_identity_basis(arm)
            decision["applied"].append({"floor_delta_z": round(dz, 6)})
        else:
            decision["applied"].append({"floor_skipped": True, "min_z": min_z})
        parent_mesh_to_armature(arm, meshes)
        clear_pose(arm)
        return decision

    decision["choice"] = "V5_NORMALIZED_FROM_COMPENSATED"
    decision["notes"].append("Bind space is compensated; reusing V1 bake+measured-align on V5 copies only.")
    bake = strategy_b_bake_world(arm, meshes)
    decision["applied"].append(bake)
    # Monkeypatch ALIGN_PAIR_BONES usage by passing V5 names into strategy_c via temporary.
    # strategy_c_align_bones uses ALIGN_PAIR_BONES from the V1 module. Temporarily replace.
    import normalize_accurig_game_rig as nrm
    old_pairs = list(nrm.ALIGN_PAIR_BONES)
    old_collect = nrm.collect_weights
    v5_names = [sem_name(smap, r) for r in ALIGN_SEMANTIC]
    v5_names = [n for n in v5_names if n]
    nrm.ALIGN_PAIR_BONES = v5_names
    try:
        align = strategy_c_align_bones(arm, meshes, A_pre, M_pre)
    finally:
        nrm.ALIGN_PAIR_BONES = old_pairs
    decision["applied"].append(align)
    floor = stand_on_floor(arm, meshes)
    decision["applied"].append({"floor": floor})
    parent_mesh_to_armature(arm, meshes)
    clear_pose(arm)
    return decision


def roundtrip_subset_specs():
    out = []
    for spec in ARTICULATION_SPEC:
        if spec["id"] in ROUNDTRIP_SUBSET or spec["id"] == "arm_upperarm_60":
            if spec["id"] in ROUNDTRIP_SUBSET:
                out.append(spec)
    # Ensure upperarm 45 via override on the 60 test if 45 isn't a separate id.
    have = {s["id"] for s in out}
    if "arm_upperarm_60" not in have:
        for spec in ARTICULATION_SPEC:
            if spec["id"] == "arm_upperarm_60":
                out.insert(0, spec)
                break
    return out


def glb_influence_note(stats_blend, stats_glb):
    note = (
        "Blender 2.83 glTF export commonly clamps vertex influences to 4. "
        "Blend weights are not modified to match GLB."
    )
    blend_max = (stats_blend or {}).get("max_influences")
    glb_max = (stats_glb or {}).get("max_influences")
    clamped = glb_max is not None and blend_max is not None and glb_max <= 4 and blend_max > 4
    return {
        "blender_283_note": note,
        "blend_max_influences": blend_max,
        "glb_max_influences": glb_max,
        "glb_clamped_to_four": bool(clamped or (glb_max is not None and glb_max <= 4 and blend_max and blend_max > 4)),
    }


def process_character(character, inventory_slot):
    paths = resolve_character_paths(character)
    report = {
        "character": character,
        "label": paths["label"],
        "source_fbx": paths["fbx"],
        "source_json": paths["json"],
        "blender": bpy.app.version_string,
        "original_fbx_untouched": True,
        "pipeline": "CLEAN_RIG_V5_CANDIDATE",
    }
    report["fbx_axis_metadata"] = parse_fbx_axes(paths["fbx"])

    reset_scene()
    import_source_fbx(paths["fbx"])
    strip_animation()
    arm = find_armature()
    if arm is None:
        report["ok"] = False
        report["error"] = "no_armature"
        return report
    meshes = skinned_meshes(arm)
    report["shape_keys"] = reset_shape_keys(meshes)
    bpy.context.view_layer.update()
    clear_pose(arm)

    smap = build_semantic_map(arm)
    bind = classify_bind_space(arm, meshes)
    anatomy = anatomical_ok(arm, smap)
    stats = skin_stats(meshes)
    mats = dump_materials()
    deform_count = sum(1 for b in arm.data.bones if b.use_deform)
    modifiers = []
    for me in meshes:
        for mod in me.modifiers:
            rec = {"mesh": me.name, "name": mod.name, "type": mod.type}
            if getattr(mod, "object", None) is not None:
                rec["target"] = mod.object.name
            modifiers.append(rec)

    report["structure"] = {
        "object_names": [o.name for o in bpy.data.objects],
        "mesh_count": len(meshes),
        "armature_count": len([o for o in bpy.data.objects if o.type == "ARMATURE"]),
        "bone_count": len(arm.data.bones),
        "deform_bone_count": deform_count,
        "skin_modifiers": modifiers,
        "vertex_groups": stats["vertex_group_names_sorted"],
        "max_influences_per_vertex": stats["max_influences"],
        "materials": mats,
        "skin": stats,
    }
    if inventory_slot is not None:
        inventory_slot["source_vertex_count"] = stats["vertex_count"]
        inventory_slot["blender_material_count"] = len(bpy.data.materials)
        inventory_slot["blender_skeleton_count"] = report["structure"]["armature_count"]
        inventory_slot["blender_bone_count"] = report["structure"]["bone_count"]

    report["orientation"] = anatomy
    report["bind_space"] = bind
    report["semantic_bone_map"] = smap
    report["hierarchy"] = {
        "bones": [dump_bone_record(arm, b) for b in arm.data.bones],
        "primary_chains": primary_chains(arm, smap),
        "sanity": hierarchy_sane(smap, None),
    }

    native = run_articulation_suite(arm, meshes, smap)
    report["native_articulation"] = native
    report["weight_quality"] = weight_quality(arm, meshes, smap)
    report["left_right"] = left_right_validation(arm, meshes, smap)
    report["rest_deform_error_source"] = rest_deform_error(arm, meshes[0]) if meshes else None

    stop_for_weights = report["weight_quality"]["major_reweight_required"]
    report["stopped_for_major_reweight"] = stop_for_weights

    decision = apply_clean_transforms(arm, meshes, bind, smap)
    meshes = skinned_meshes(arm) or meshes
    smap = build_semantic_map(arm)
    report["normalization"] = decision
    report["clean"] = {
        "armature": dump_object(arm),
        "meshes": [dump_object(m) for m in meshes],
        "mesh_world_bbox": mesh_vertex_world_bbox(meshes[0]) if meshes else None,
        "armature_world_bbox": armature_world_bbox(arm),
        "armature_object_identity": object_is_identity(arm),
        "mesh_object_identity": all(object_is_identity(m) for m in meshes) if meshes else False,
        "orientation": anatomical_ok(arm, smap),
        "rest_deform_error": rest_deform_error(arm, meshes[0]) if meshes else None,
        "skin": skin_stats(meshes),
    }
    report["native_articulation_after_clean"] = run_articulation_suite(arm, meshes, smap)

    packed = pack_images()
    report["textures_packed"] = packed
    bpy.ops.wm.save_as_mainfile(filepath=paths["blend"])
    export_glb(paths["glb"])
    report["outputs"] = {
        "blend": paths["blend"],
        "glb": paths["glb"],
        "blend_bytes": os.path.getsize(paths["blend"]) if os.path.isfile(paths["blend"]) else 0,
        "glb_bytes": os.path.getsize(paths["glb"]) if os.path.isfile(paths["glb"]) else 0,
        "glb_sha256": sha256_file(paths["glb"]) if os.path.isfile(paths["glb"]) else None,
    }

    # GLB roundtrip in a fresh scene.
    blend_subset = run_articulation_suite(
        arm, meshes, smap, specs=roundtrip_subset_specs(), angle_overrides=ROUNDTRIP_OVERRIDE_ANGLE
    )
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=paths["glb"])
    arm_g = find_armature()
    if arm_g is None:
        report["glb_roundtrip"] = {"ok": False, "reason": "no_armature_after_gltf_import"}
    else:
        meshes_g = skinned_meshes(arm_g)
        reset_shape_keys(meshes_g)
        bpy.context.view_layer.update()
        clear_pose(arm_g)
        smap_g = build_semantic_map(arm_g)
        stats_g = skin_stats(meshes_g)
        art_g = run_articulation_suite(
            arm_g, meshes_g, smap_g, specs=roundtrip_subset_specs(), angle_overrides=ROUNDTRIP_OVERRIDE_ANGLE
        )
        bone_count_match = len(arm_g.data.bones) == report["structure"]["bone_count"]
        # Compare subset pass/fail and volume ratios.
        material_diff = False
        by_id_b = {t["id"]: t for t in blend_subset.get("tests", [])}
        diffs = []
        for t in art_g.get("tests", []):
            b = by_id_b.get(t["id"])
            if not b:
                continue
            vr_b = b.get("volume_ratio") or 1.0
            vr_g = t.get("volume_ratio") or 1.0
            if abs(vr_b - vr_g) > 0.25 or (b.get("pass") != t.get("pass")):
                material_diff = True
                diffs.append({"id": t["id"], "blend": b.get("pass"), "glb": t.get("pass"),
                              "blend_vol": vr_b, "glb_vol": vr_g})
        orient_g = anatomical_ok(arm_g, smap_g)
        report["glb_roundtrip"] = {
            "ok": bool(art_g.get("pass") and bone_count_match and orient_g.get("upright") and not material_diff),
            "bone_count": len(arm_g.data.bones),
            "mesh_count": len(meshes_g),
            "materials": dump_materials(),
            "skin": stats_g,
            "orientation": orient_g,
            "articulation_subset": art_g,
            "blend_articulation_subset": blend_subset,
            "bone_count_match": bone_count_match,
            "material_deformation_diff": material_diff,
            "diffs": diffs,
            "upright": orient_g.get("upright"),
            "influences": glb_influence_note(report["clean"]["skin"], stats_g),
        }

    art_pass = bool(report["native_articulation"]["pass"] and report["native_articulation_after_clean"]["pass"])
    fingers = bool((smap.get("LEFT_INDEX_01") or {}).get("present") and (smap.get("LEFT_THUMB_01") or {}).get("present"))
    report["gates"] = {
        "source_import": True,
        "hierarchy_sane": report["hierarchy"]["sanity"]["pass"],
        "native_articulation": art_pass,
        "fingers": fingers,
        "no_cross_side": report["left_right"]["pass"],
        "clean_blend_exists": os.path.isfile(paths["blend"]),
        "glb_roundtrip": bool((report.get("glb_roundtrip") or {}).get("ok")),
        "no_major_reweight": not stop_for_weights,
    }
    report["character_ready"] = all(report["gates"].values())
    return report


def compare_vs_v1(v5_reports):
    comparison = {
        "generated_at": datetime.now().isoformat(),
        "note": "Rig quality only. No animation comparison. No Mixamo.",
        "fighters": {},
        "do_not_auto_promote": True,
        "human_must_choose": ["KEEP CLEAN RIG V1", "PROMOTE CLEAN RIG V5"],
    }
    for character, v5 in v5_reports.items():
        v1_path = os.path.join(GENERATED_DIR, "ACCURIG_CLEAN_RIG_V1_%s.json" % character.upper())
        v1 = {}
        if os.path.isfile(v1_path):
            with open(v1_path, "r", encoding="utf-8") as fh:
                v1 = json.load(fh)
        v1_bones = v1.get("hierarchy_bone_count")
        if v1_bones is None:
            v1_bones = (((v1.get("raw") or {}).get("armature_world_bbox") or {}).get("bone_count"))
        v5_smap = v5.get("semantic_bone_map") or {}
        v5_fingers = {
            "index": bool((v5_smap.get("LEFT_INDEX_01") or {}).get("present")),
            "middle": bool((v5_smap.get("LEFT_MIDDLE_01") or {}).get("present")),
            "ring": bool((v5_smap.get("LEFT_RING_01") or {}).get("present")),
            "pinky": bool((v5_smap.get("LEFT_PINKY_01") or {}).get("present")),
            "thumb": bool((v5_smap.get("LEFT_THUMB_01") or {}).get("present")),
            "metacarpals": bool((v5_smap.get("LEFT_INDEX_METACARPAL") or {}).get("present")),
        }
        v1_skin = v1.get("skin_after") or v1.get("skin_before") or {}
        v5_skin = ((v5.get("clean") or {}).get("skin")) or ((v5.get("structure") or {}).get("skin")) or {}
        v1_art = v1.get("native_articulation") or {}
        row = {
            "v1": {
                "bone_count": v1_bones,
                "max_influences": v1_skin.get("max_influences"),
                "vertex_count": v1_skin.get("vertex_count"),
                "bind_space": "COMPENSATED (AccuRIG Rx90 * 0.01 typical)",
                "normalization_required": True,
                "native_articulation_pass": v1_art.get("pass"),
                "finger_rig": "CC_Base Index/Middle/Ring/Pinky/Thumb 1-3",
                "glb_roundtrip_ok": ((v1.get("glb_roundtrip") or {}).get("ok")),
            },
            "v5": {
                "bone_count": (v5.get("structure") or {}).get("bone_count"),
                "max_influences": v5_skin.get("max_influences"),
                "vertex_count": v5_skin.get("vertex_count"),
                "bind_space": ((v5.get("bind_space") or {}).get("label")),
                "normalization": ((v5.get("normalization") or {}).get("choice")),
                "native_articulation_pass": ((v5.get("native_articulation") or {}).get("pass")),
                "fingers": v5_fingers,
                "glb_roundtrip_ok": ((v5.get("glb_roundtrip") or {}).get("ok")),
                "left_right_pass": ((v5.get("left_right") or {}).get("pass")),
                "weight_major_reweight": ((v5.get("weight_quality") or {}).get("major_reweight_required")),
            },
            "deltas": {
                "bone_count_delta": ((v5.get("structure") or {}).get("bone_count") or 0) - (v1_bones or 0),
                "v5_has_ring_fingers": v5_fingers["ring"],
                "v5_has_metacarpals": v5_fingers["metacarpals"],
                "v5_cleaner_bind_space": ((v5.get("bind_space") or {}).get("label") == "V5_BIND_SPACE_CLEAN"),
            },
        }
        comparison["fighters"][character] = row
    return comparison


def write_combined(v5_reports, inventory):
    hierarchy = {"generated_at": datetime.now().isoformat(), "fighters": {}}
    smap = {"generated_at": datetime.now().isoformat(), "fighters": {}}
    metrics = {"generated_at": datetime.now().isoformat(), "fighters": {}}
    for character, report in v5_reports.items():
        hierarchy["fighters"][character] = report.get("hierarchy")
        smap["fighters"][character] = report.get("semantic_bone_map")
        metrics["fighters"][character] = {
            "native": report.get("native_articulation"),
            "after_clean": report.get("native_articulation_after_clean"),
            "glb_roundtrip_subset": (report.get("glb_roundtrip") or {}).get("articulation_subset"),
        }
        audit_name = "V5_%s_RIG_AUDIT.json" % character.upper()
        write_json(os.path.join(GENERATED_DIR, audit_name), report)
    write_json(os.path.join(GENERATED_DIR, "V5_SOURCE_INVENTORY.json"), inventory)
    write_json(os.path.join(GENERATED_DIR, "V5_BONE_HIERARCHY.json"), hierarchy)
    write_json(os.path.join(GENERATED_DIR, "V5_SEMANTIC_BONE_MAP.json"), smap)
    write_json(os.path.join(GENERATED_DIR, "V5_NATIVE_ARTICULATION_METRICS.json"), metrics)
    write_json(os.path.join(GENERATED_DIR, "V5_VS_CLEAN_RIG_V1_COMPARISON.json"), compare_vs_v1(v5_reports))


def main():
    args = parse_args()
    characters = ["jaguarete", "terere"] if args.character == "both" else [args.character]
    inventory = source_inventory()
    write_json(os.path.join(GENERATED_DIR, "V5_SOURCE_INVENTORY.json"), inventory)
    print("INVENTORY gdignore=%s" % inventory["gdignore_exists"])
    sys.stdout.flush()
    reports = {}
    for character in characters:
        print("==== PROCESS", character, "====")
        sys.stdout.flush()
        slot = inventory["fighters"].get(character)
        rec = process_character(character, slot)
        reports[character] = rec
        print("READY" if rec.get("character_ready") else "NOT_READY", character, rec.get("gates"))
    write_combined(reports, inventory)
    all_ready = all(r.get("character_ready") for r in reports.values())
    print("ALL_READY" if all_ready else "PARTIAL_OR_BLOCKED")
    return 0 if all_ready else 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        traceback.print_exc()
        sys.exit(1)
