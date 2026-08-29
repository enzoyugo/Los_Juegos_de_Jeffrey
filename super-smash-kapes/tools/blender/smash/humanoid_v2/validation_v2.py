"""Automatic quality checks for humanoid V2 candidates."""

from __future__ import annotations

import json
from pathlib import Path

import bpy
from mathutils import Vector

from .bpy_scene import count_tris, mesh_objects


def bounding_box(root) -> dict:
    mins = Vector((1e9, 1e9, 1e9))
    maxs = Vector((-1e9, -1e9, -1e9))
    any_mesh = False
    for obj in mesh_objects(root):
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            mins.x = min(mins.x, world.x)
            mins.y = min(mins.y, world.y)
            mins.z = min(mins.z, world.z)
            maxs.x = max(maxs.x, world.x)
            maxs.y = max(maxs.y, world.y)
            maxs.z = max(maxs.z, world.z)
            any_mesh = True
    if not any_mesh:
        return {"min": [0, 0, 0], "max": [0, 0, 0], "size": [0, 0, 0]}
    size = maxs - mins
    return {
        "min": [mins.x, mins.y, mins.z],
        "max": [maxs.x, maxs.y, maxs.z],
        "size": [size.x, size.y, size.z],
        "height": size.z,
    }


def validate_candidate(root, glb_path: Path | None = None) -> dict:
    meshes = mesh_objects(root)
    mats = set()
    issues = []
    for m in meshes:
        if not m.data.materials:
            issues.append(f"missing_material:{m.name}")
        for slot in m.data.materials:
            if slot:
                mats.add(slot.name)
        # inverted normals heuristic: negative scale
        if m.scale.x * m.scale.y * m.scale.z < 0:
            issues.append(f"negative_scale:{m.name}")
    bbox = bounding_box(root)
    height = float(bbox.get("height") or bbox.get("size", [0, 0, 0])[2])
    if bbox.get("min", [0, 0, 0])[2] < -0.05:
        issues.append("feet_below_floor")
    if height < 1.2 or height > 3.5:
        issues.append(f"height_out_of_range:{height:.2f}")
    tris = count_tris([root])
    if tris > 25000:
        issues.append(f"tris_high:{tris}")
    if tris < 2000:
        issues.append(f"tris_suspiciously_low:{tris}")
    report = {
        "triangle_count": tris,
        "object_count": len(meshes),
        "material_count": len(mats),
        "materials": sorted(mats),
        "bbox": bbox,
        "height": height,
        "glb_size_bytes": glb_path.stat().st_size if glb_path and glb_path.is_file() else None,
        "issues": issues,
        "ok": len([i for i in issues if not i.startswith("tris_suspiciously")]) == 0 or tris >= 2000,
    }
    # ok if no structural issues (allow note-level warnings)
    structural = [i for i in issues if not i.startswith("tris_")]
    report["ok"] = len(structural) == 0
    return report


def write_report(path: Path, report: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2), encoding="utf-8")
