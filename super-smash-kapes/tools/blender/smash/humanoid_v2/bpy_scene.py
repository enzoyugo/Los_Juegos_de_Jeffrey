"""Blender scene helpers for Jeffrey stylized humanoid V2."""

from __future__ import annotations

from pathlib import Path

import bpy
from mathutils import Euler, Vector


def enable_gltf() -> None:
    try:
        bpy.ops.preferences.addon_enable(module="io_scene_gltf2")
    except Exception:
        pass


def reset_scene(exposure: float = 0.2) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    enable_gltf()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.render.engine = "BLENDER_EEVEE_NEXT" if hasattr(bpy.types, "BLENDER_EEVEE_NEXT") else "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.film_transparent = True
    try:
        scene.view_settings.view_transform = "Standard"
        scene.view_settings.look = "None"
        scene.view_settings.exposure = exposure
    except Exception:
        pass


def setup_three_point(key_energy: float = 120.0, fill_energy: float = 55.0, rim_energy: float = 80.0) -> None:
    bpy.ops.object.light_add(type="AREA", location=(2.8, 3.6, 3.2))
    key = bpy.context.object
    key.name = "KeyLight"
    key.data.energy = key_energy
    key.data.size = 2.4
    key.rotation_euler = Euler((0.85, 0.15, 0.55), "XYZ")

    bpy.ops.object.light_add(type="AREA", location=(-3.2, 2.0, 2.4))
    fill = bpy.context.object
    fill.name = "FillLight"
    fill.data.energy = fill_energy
    fill.data.size = 3.5
    fill.rotation_euler = Euler((1.0, -0.2, -0.7), "XYZ")

    bpy.ops.object.light_add(type="AREA", location=(0.4, -3.5, 2.8))
    rim = bpy.context.object
    rim.name = "RimLight"
    rim.data.energy = rim_energy
    rim.data.size = 2.0
    rim.rotation_euler = Euler((1.2, 0.0, 3.14), "XYZ")

    bpy.ops.object.light_add(type="SUN", location=(4, -2, 8))
    sun = bpy.context.object
    sun.name = "SunSoft"
    sun.data.energy = 1.4
    sun.rotation_euler = Euler((0.65, 0.15, 0.35), "XYZ")


def look_at(obj, target: Vector) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def export_glb(path: Path, objs) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        if o is None:
            continue
        o.select_set(True)
        for child in o.children_recursive:
            child.select_set(True)
    bpy.context.view_layer.objects.active = next((o for o in objs if o is not None), None)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        use_selection=True,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        export_animations=True,
        export_skins=True,
    )


def save_blend(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(path))


def count_tris(objs) -> int:
    total = 0
    seen = set()
    for o in objs:
        if o is None:
            continue
        stack = [o] + list(o.children_recursive)
        for node in stack:
            if node.type != "MESH" or node.name in seen:
                continue
            seen.add(node.name)
            mesh = node.data
            mesh.calc_loop_triangles()
            total += len(mesh.loop_triangles)
    return total


def mesh_objects(root) -> list:
    out = []
    for o in [root] + list(root.children_recursive):
        if o.type == "MESH":
            out.append(o)
    return out
