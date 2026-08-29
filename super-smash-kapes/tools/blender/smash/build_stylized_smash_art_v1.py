"""Build stylized Smash production GLBs + portrait renders (Blender 5.x).

Usage (from repo tools):
  blender --background --python tools/blender/smash/build_stylized_smash_art_v1.py

Outputs under assets/fighters/processed/<id>/ and assets/stages/*/visual/
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Vector

ROOT = Path(__file__).resolve().parents[3]
OUT_REVIEW = Path(r"E:\JeffreyAIResearch\outputs\runtime-review\smash_art_asset_production_v1")
STATS = []


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        bpy.ops.preferences.addon_enable(module="io_scene_gltf2")
    except Exception:
        pass
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.render.engine = "BLENDER_EEVEE_NEXT" if hasattr(bpy.types, "BLENDER_EEVEE_NEXT") else "BLENDER_EEVEE"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.film_transparent = True
    # Prefer Standard view transform so party-game colors stay saturated in portraits.
    try:
        scene.view_settings.view_transform = "Standard"
        scene.view_settings.look = "None"
        scene.view_settings.exposure = 0.35
    except Exception:
        pass
    # Lights
    bpy.ops.object.light_add(type="SUN", location=(4, -3, 8))
    sun = bpy.context.object
    sun.data.energy = 5.0
    sun.rotation_euler = Euler((0.7, 0.2, 0.4), "XYZ")
    bpy.ops.object.light_add(type="AREA", location=(-3, 2, 4))
    area = bpy.context.object
    area.data.energy = 140.0
    area.data.size = 4.0
    # Fill from front so white/gold read clearly in portraits.
    bpy.ops.object.light_add(type="AREA", location=(1.5, 4.0, 2.5))
    fill = bpy.context.object
    fill.data.energy = 100.0
    fill.data.size = 3.0


def mat(name: str, color, rough=0.55, metal=0.0, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf is None:
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    rgba = (float(color[0]), float(color[1]), float(color[2]), 1.0)
    m.diffuse_color = rgba
    for key in ("Base Color", "Base Color", "Color"):
        sock = bsdf.inputs.get(key) if hasattr(bsdf.inputs, "get") else None
        if sock is None:
            try:
                sock = bsdf.inputs[key]
            except Exception:
                continue
        try:
            sock.default_value = rgba
            break
        except Exception:
            continue
    for key, val in (("Roughness", rough), ("Metallic", metal)):
        try:
            if key in bsdf.inputs:
                bsdf.inputs[key].default_value = float(val)
        except Exception:
            pass
    if emit > 0:
        try:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = rgba
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = float(emit)
        except Exception:
            pass
    return m


def assign(obj, material):
    if obj.data.materials:
        obj.data.materials[0] = material
    else:
        obj.data.materials.append(material)


def prim(kind: str, name: str, loc, scale=(1, 1, 1), rot=(0, 0, 0), material=None):
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    elif kind == "uv_sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, location=loc, segments=16, ring_count=10)
    elif kind == "cylinder":
        bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=1, location=loc, vertices=12)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(radius1=0.5, depth=1, location=loc, vertices=12)
    else:
        raise ValueError(kind)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = Euler(rot, "XYZ")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.location = loc
    if material:
        assign(obj, material)
    return obj


def parent(child, parent_obj):
    child.parent = parent_obj


def join_selected(name: str):
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    return obj


def count_tris(objs) -> int:
    total = 0
    for o in objs:
        if o.type != "MESH":
            continue
        mesh = o.data
        mesh.calc_loop_triangles()
        total += len(mesh.loop_triangles)
    return total


def export_glb(path: Path, objs):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        use_selection=True,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
    )


def setup_camera_portrait(target_z=1.6, dist=4.2):
    """Framed 3/4 view looking at character from +Y (front features face +Y)."""
    cam_data = bpy.data.cameras.new("PortraitCam")
    cam = bpy.data.objects.new("PortraitCam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    # Front-right of character (+Y is forward for our mesh cues).
    cam.location = (dist * 0.55, dist, target_z * 0.55)
    look = Vector((0.0, 0.0, target_z * 0.72))
    direction = look - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = 45
    bpy.context.scene.camera = cam
    return cam


def render_png(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def render_review_angles(review_dir: Path, target_z: float):
    """Front / 3-4 / side / gameplay-distance stills for review package."""
    review_dir.mkdir(parents=True, exist_ok=True)
    shots = {
        "front": ((0.0, 4.5, target_z * 0.9), (0.0, 0.0, target_z * 0.85)),
        "three_quarter": ((2.8, 3.8, target_z * 0.95), (0.0, 0.0, target_z * 0.8)),
        "side": ((5.0, 0.0, target_z * 0.9), (0.0, 0.0, target_z * 0.85)),
        "gameplay_distance": ((1.5, 12.0, 4.5), (0.0, 0.0, target_z * 0.7)),
    }
    cam = bpy.context.scene.camera
    if cam is None:
        cam = setup_camera_portrait(target_z)
    for name, (loc, look) in shots.items():
        cam.location = loc
        direction = Vector(look) - Vector(loc)
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        render_png(review_dir / f"{name}.png")


def build_fort(root):
    white = mat("FortWhite", (1.0, 0.98, 0.94), rough=0.45)
    gold = mat("FortGold", (1.0, 0.82, 0.22), rough=0.35, metal=0.35, emit=0.35)
    skin = mat("FortSkin", (0.95, 0.78, 0.62), rough=0.5)
    dark = mat("FortDark", (0.12, 0.1, 0.16), rough=0.55)
    hair = mat("FortHair", (0.08, 0.06, 0.05), rough=0.7)
    glass = mat("FortGlass", (0.05, 0.05, 0.08), rough=0.15, metal=0.4)

    root_empty = bpy.data.objects.new("FortRoot", None)
    bpy.context.scene.collection.objects.link(root_empty)

    torso = prim("cube", "Torso", (0, 0, 1.15), (0.95, 0.55, 1.15), material=white)
    shoulders = prim("cube", "Shoulders", (0, 0, 1.55), (1.35, 0.48, 0.38), material=white)
    head = prim("uv_sphere", "Head", (0, 0.08, 2.05), (0.62, 0.62, 0.7), material=skin)
    hair_m = prim("uv_sphere", "Hair", (0, -0.08, 2.22), (0.64, 0.62, 0.42), material=hair)
    glasses = prim("cylinder", "Glasses", (0, 0.30, 2.08), (0.44, 0.1, 0.44), rot=(math.pi / 2, 0, 0), material=gold)
    # Gold glam as front trim (keep white torso readable).
    jacket = prim("cube", "JacketFlare", (0, 0.28, 1.15), (0.85, 0.08, 0.55), material=gold)
    lapel = prim("cube", "Lapel", (0, 0.30, 1.55), (0.7, 0.06, 0.2), material=gold)
    arm_l = prim("cylinder", "ArmL", (-0.75, 0, 1.25), (0.22, 0.22, 0.7), material=skin)
    arm_r = prim("cylinder", "ArmR", (0.75, 0, 1.25), (0.22, 0.22, 0.7), material=skin)
    # Theatrical open-arm pose (readable slap silhouette).
    arm_r.rotation_euler = Euler((0.35, 0.0, -0.85), "XYZ")
    bpy.ops.object.select_all(action="DESELECT")
    arm_r.select_set(True)
    bpy.context.view_layer.objects.active = arm_r
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    hand_r = prim("uv_sphere", "HandR", (1.1, 0.5, 1.35), (0.28, 0.28, 0.28), material=skin)
    leg_l = prim("cylinder", "LegL", (-0.28, 0, 0.45), (0.24, 0.24, 0.7), material=dark)
    leg_r = prim("cylinder", "LegR", (0.28, 0, 0.45), (0.24, 0.24, 0.7), material=dark)
    foot_l = prim("cube", "FootL", (-0.28, 0.12, 0.08), (0.32, 0.45, 0.14), material=gold)
    foot_r = prim("cube", "FootR", (0.28, 0.12, 0.08), (0.32, 0.45, 0.14), material=gold)
    star = prim("uv_sphere", "Star", (0, 0, 2.55), (0.18, 0.18, 0.18), material=gold)
    # Iconic dark sunglasses lenses (silhouette cue).
    lens_l = prim("uv_sphere", "LensL", (-0.14, 0.34, 2.08), (0.14, 0.08, 0.1), material=glass)
    lens_r = prim("uv_sphere", "LensR", (0.14, 0.34, 2.08), (0.14, 0.08, 0.1), material=glass)

    objs = [
        torso, shoulders, head, hair_m, glasses, lens_l, lens_r, jacket, lapel,
        arm_l, arm_r, hand_r, leg_l, leg_r, foot_l, foot_r, star,
    ]
    for o in objs:
        parent(o, root_empty)
    return root_empty, objs


def build_cartes(root):
    navy = mat("CartesNavy", (0.14, 0.18, 0.26), rough=0.5)
    skin = mat("CartesSkin", (0.82, 0.66, 0.47), rough=0.5)
    red = mat("CartesRed", (0.78, 0.16, 0.16), rough=0.45)
    white = mat("CartesWhite", (0.96, 0.94, 0.87), rough=0.5)
    blue = mat("CartesBlue", (0.16, 0.46, 0.72), rough=0.45)
    dark = mat("CartesDark", (0.08, 0.09, 0.12), rough=0.6)
    hair = mat("CartesHair", (0.15, 0.12, 0.1), rough=0.7)

    root_empty = bpy.data.objects.new("CartesRoot", None)
    bpy.context.scene.collection.objects.link(root_empty)

    torso = prim("cube", "Torso", (0, 0, 1.1), (1.05, 0.6, 1.2), material=navy)
    head = prim("uv_sphere", "Head", (0, 0.05, 1.95), (0.7, 0.7, 0.72), material=skin)
    hair_m = prim("cube", "Hair", (0, -0.05, 2.15), (0.72, 0.55, 0.25), material=hair)
    sash_r = prim("cube", "SashR", (0, 0.05, 1.3), (1.1, 0.62, 0.12), material=red)
    sash_w = prim("cube", "SashW", (0, 0.06, 1.22), (0.25, 0.63, 0.12), material=white)
    sash_b = prim("cube", "SashB", (0.25, 0.06, 1.22), (0.25, 0.63, 0.12), material=blue)
    arm_l = prim("cylinder", "ArmL", (-0.72, 0, 1.2), (0.26, 0.26, 0.65), material=skin)
    arm_r = prim("cylinder", "ArmR", (0.72, 0, 1.2), (0.26, 0.26, 0.65), material=skin)
    leg_l = prim("cylinder", "LegL", (-0.3, 0, 0.42), (0.28, 0.28, 0.65), material=dark)
    leg_r = prim("cylinder", "LegR", (0.3, 0, 0.42), (0.28, 0.28, 0.65), material=dark)
    foot_l = prim("cube", "FootL", (-0.3, 0.08, 0.08), (0.34, 0.42, 0.14), material=dark)
    foot_r = prim("cube", "FootR", (0.3, 0.08, 0.08), (0.34, 0.42, 0.14), material=dark)

    objs = [torso, head, hair_m, sash_r, sash_w, sash_b, arm_l, arm_r, leg_l, leg_r, foot_l, foot_r]
    for o in objs:
        parent(o, root_empty)
    return root_empty, objs


def build_pajaro(root):
    yellow = mat("PajaroYellow", (0.98, 0.86, 0.12), rough=0.35)
    cream = mat("PajaroCream", (1.0, 0.92, 0.55), rough=0.35)
    beak = mat("PajaroBeak", (0.92, 0.42, 0.08), rough=0.4)
    red = mat("PajaroRed", (0.85, 0.12, 0.12), rough=0.35)
    wing = mat("PajaroWing", (0.85, 0.95, 0.35), rough=0.4)
    dark = mat("PajaroDark", (0.08, 0.08, 0.08), rough=0.35)

    root_empty = bpy.data.objects.new("PajaroRoot", None)
    bpy.context.scene.collection.objects.link(root_empty)

    body = prim("uv_sphere", "Body", (0, 0, 1.05), (0.95, 0.8, 1.0), material=yellow)
    head = prim("uv_sphere", "Head", (0, 0.12, 1.78), (0.58, 0.58, 0.58), material=cream)
    beak_m = prim("cone", "Beak", (0, 0.52, 1.72), (0.18, 0.42, 0.18), rot=(math.pi / 2, 0, 0), material=beak)
    crest = prim("cube", "Crest", (0, 0.05, 2.15), (0.12, 0.22, 0.4), material=red)
    eye_l = prim("uv_sphere", "EyeL", (-0.18, 0.42, 1.85), (0.12, 0.12, 0.12), material=dark)
    eye_r = prim("uv_sphere", "EyeR", (0.18, 0.42, 1.85), (0.12, 0.12, 0.12), material=dark)
    wing_l = prim("cube", "WingL", (-0.7, 0.05, 1.15), (0.6, 0.1, 0.38), rot=(0, 0, 0.35), material=wing)
    wing_r = prim("cube", "WingR", (0.7, 0.05, 1.15), (0.6, 0.1, 0.38), rot=(0, 0, -0.35), material=wing)
    # Alias wings as ArmL/ArmR so Godot procedural motion can flap.
    wing_l.name = "ArmL"
    wing_r.name = "ArmR"
    leg_l = prim("cylinder", "LegL", (-0.18, 0, 0.4), (0.1, 0.1, 0.45), material=beak)
    leg_r = prim("cylinder", "LegR", (0.18, 0, 0.4), (0.1, 0.1, 0.45), material=beak)

    objs = [body, head, beak_m, crest, eye_l, eye_r, wing_l, wing_r, leg_l, leg_r]
    for o in objs:
        parent(o, root_empty)
    return root_empty, objs


def build_palacio_visual():
    stone = mat("PalaceStone", (0.55, 0.48, 0.38), rough=0.75)
    dark = mat("PalaceDark", (0.08, 0.1, 0.16), rough=0.7)
    window = mat("PalaceWindow", (0.95, 0.82, 0.35), rough=0.3, emit=2.5)
    red = mat("FlagRed", (0.78, 0.16, 0.16), rough=0.45)
    white = mat("FlagWhite", (0.95, 0.94, 0.88), rough=0.45)
    blue = mat("FlagBlue", (0.16, 0.46, 0.72), rough=0.45)

    root = bpy.data.objects.new("PalacioVisualRoot", None)
    bpy.context.scene.collection.objects.link(root)
    objs = []
    # Place far behind combat (visual only). Local Z is depth toward camera negative.
    base = prim("cube", "PalaceBody", (0, -18, 6), (18, 3, 10), material=stone)
    objs.append(base)
    for x in (-12, 12):
        tower = prim("cube", "Tower", (x, -18, 9), (4, 3.2, 14), material=stone)
        objs.append(tower)
    roof = prim("cube", "Roof", (0, -18, 13), (8, 3.4, 4), material=dark)
    objs.append(roof)
    for i, x in enumerate(range(-10, 11, 4)):
        w = prim("cube", f"Win{i}", (x, -16.3, 5.5), (1.2, 0.3, 1.8), material=window)
        objs.append(w)
    for i, (x, m) in enumerate([(-2, red), (0, white), (2, blue)]):
        flag = prim("cube", f"Flag{i}", (x, -16.0, 15.5), (1.6, 0.15, 0.9), material=m)
        objs.append(flag)
    plaza = prim("cube", "Plaza", (0, -12, 0.2), (28, 8, 0.3), material=dark)
    objs.append(plaza)
    for o in objs:
        parent(o, root)
    return root, objs


def build_costanera_visual():
    water = mat("River", (0.12, 0.35, 0.48), rough=0.25)
    city = mat("City", (0.1, 0.13, 0.2), rough=0.7)
    lamp = mat("Lamp", (0.96, 0.84, 0.43), rough=0.3, emit=3.0)
    walk = mat("Walk", (0.35, 0.38, 0.4), rough=0.8)
    green = mat("Tree", (0.2, 0.45, 0.22), rough=0.7)

    root = bpy.data.objects.new("CostaneraVisualRoot", None)
    bpy.context.scene.collection.objects.link(root)
    objs = []
    river = prim("cube", "River", (0, -20, -0.5), (50, 12, 0.4), material=water)
    objs.append(river)
    walkway = prim("cube", "Walkway", (0, -10, 0.15), (40, 4, 0.25), material=walk)
    objs.append(walkway)
    for i, x in enumerate(range(-20, 21, 5)):
        h = 4 + (abs(i) % 4) * 1.6
        b = prim("cube", f"Bldg{i}", (x, -24, h * 0.5 + 0.5), (3.5, 2.5, h), material=city)
        objs.append(b)
    for i, x in enumerate((-16, -8, 0, 8, 16)):
        pole = prim("cylinder", f"Pole{i}", (x, -9, 1.5), (0.1, 0.1, 3.0), material=city)
        bulb = prim("uv_sphere", f"Bulb{i}", (x, -9, 3.1), (0.35, 0.35, 0.35), material=lamp)
        objs.extend([pole, bulb])
    for i, x in enumerate((-12, 12)):
        canopy = prim("uv_sphere", f"Tree{i}", (x, -8, 1.8), (1.4, 1.4, 1.4), material=green)
        objs.append(canopy)
    for o in objs:
        parent(o, root)
    return root, objs


def process_fighter(fid: str, builder, portrait_z: float):
    reset()
    _root, objs = builder(None)
    tris = count_tris(objs)
    glb = ROOT / f"assets/fighters/processed/{fid}/{fid}_stylized_v1.glb"
    export_glb(glb, objs + ([_root] if _root else []))
    setup_camera_portrait(portrait_z)
    portrait = ROOT / f"assets/ui/portraits/{fid}_portrait.png"
    victory = ROOT / f"assets/ui/victory/{fid}/{fid}_victory.png"
    render_png(portrait)
    # Victory: slightly taller frame, same look-at.
    bpy.context.scene.render.resolution_x = 512
    bpy.context.scene.render.resolution_y = 640
    if bpy.context.scene.camera:
        setup_camera_portrait(portrait_z, dist=4.8)
    render_png(victory)
    bpy.context.scene.render.resolution_x = 512
    bpy.context.scene.render.resolution_y = 512
    review = OUT_REVIEW / "fighters" / fid
    render_png(review / "select_portrait.png")
    render_png(review / "victory_portrait.png")
    render_review_angles(review, portrait_z)
    # Wireframe-ish orthographic stats still (reuse gameplay distance camera).
    entry = {
        "id": fid,
        "glb": str(glb),
        "tris": tris,
        "portrait": str(portrait),
        "victory": str(victory),
        "review_dir": str(review),
    }
    STATS.append(entry)
    print("FIGHTER_OK", json.dumps(entry))
    return entry


def process_stage(sid: str, builder, out_rel: str):
    reset()
    _root, objs = builder()
    tris = count_tris(objs)
    glb = ROOT / out_rel
    export_glb(glb, objs + ([_root] if _root else []))
    entry = {"id": sid, "glb": str(glb), "tris": tris}
    STATS.append(entry)
    print("STAGE_OK", json.dumps(entry))
    return entry


def main():
    OUT_REVIEW.mkdir(parents=True, exist_ok=True)
    process_fighter("fort", build_fort, 1.7)
    process_fighter("cartes", build_cartes, 1.55)
    process_fighter("pajaro_campana", build_pajaro, 1.5)
    process_stage("palacio", build_palacio_visual, "assets/stages/palacio_de_lopez/visual/palacio_visual_v1.glb")
    process_stage("costanera", build_costanera_visual, "assets/stages/costanera_de_asuncion/visual/costanera_visual_v1.glb")
    summary = OUT_REVIEW / "blender_build_stats.json"
    summary.write_text(json.dumps(STATS, indent=2), encoding="utf-8")
    print("SMASH_ART_BLENDER_V1_PASS", summary)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("SMASH_ART_BLENDER_V1_FAIL", exc)
        raise
