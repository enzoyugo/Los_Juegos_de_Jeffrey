"""Portrait / review camera scene for humanoid V2."""

from __future__ import annotations

from pathlib import Path

import bpy
from mathutils import Vector

from .bpy_scene import look_at


def ensure_camera(name: str = "PortraitCam") -> bpy.types.Object:
    cam_data = bpy.data.cameras.new(name)
    cam = bpy.data.objects.new(name, cam_data)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam


def frame_character(cam, look_z: float = 1.35, dist: float = 3.6, side: float = 1.4, height: float = 1.45):
    cam.location = (side, dist, height)
    look_at(cam, Vector((0.0, 0.0, look_z)))
    cam.data.lens = 50


def render_still(path: Path, res_x: int = 768, res_y: int = 768) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def render_angle_set(out_dir: Path, look_z: float = 1.35, prefix: str = "") -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    cam = bpy.context.scene.camera or ensure_camera()
    shots = {
        "FRONT": ((0.0, 4.2, look_z * 0.95), (0.0, 0.0, look_z * 0.85)),
        "3Q": ((2.4, 3.6, look_z), (0.0, 0.0, look_z * 0.8)),
        "SIDE": ((4.6, 0.2, look_z * 0.95), (0.0, 0.0, look_z * 0.85)),
        "GAMEPLAY": ((1.2, 11.0, 3.8), (0.0, 0.0, look_z * 0.65)),
    }
    paths = {}
    for name, (loc, look) in shots.items():
        cam.location = loc
        look_at(cam, Vector(look))
        cam.data.lens = 40 if name == "GAMEPLAY" else 50
        path = out_dir / f"{prefix}{name}.png"
        render_still(path)
        paths[name] = str(path)
    return paths


def render_select_victory(out_dir: Path, look_z: float = 1.45, prefix: str = "") -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    cam = bpy.context.scene.camera or ensure_camera()
    # SELECT: upper body + face
    frame_character(cam, look_z=look_z, dist=3.2, side=1.2, height=look_z + 0.15)
    cam.data.lens = 55
    select = out_dir / f"{prefix}SELECT.png"
    render_still(select, 768, 768)
    # VICTORY: slightly wider theatrical
    frame_character(cam, look_z=look_z * 0.9, dist=4.0, side=1.8, height=look_z)
    cam.data.lens = 45
    victory = out_dir / f"{prefix}VICTORY.png"
    render_still(victory, 768, 960)
    return {"SELECT": str(select), "VICTORY": str(victory)}


def apply_silhouette_world() -> None:
    """Neutral flat backdrop for silhouette passes (opaque black)."""
    scene = bpy.context.scene
    scene.render.film_transparent = False
    try:
        world = bpy.data.worlds.new("SilhouetteWorld")
        scene.world = world
        world.use_nodes = True
        bg = world.node_tree.nodes.get("Background")
        if bg:
            bg.inputs[0].default_value = (0.92, 0.92, 0.94, 1.0)
            bg.inputs[1].default_value = 1.0
    except Exception:
        pass
