"""Separate four wheel assemblies from the fused Track car GLB.

Spatial selection only. Does not remodel, re-UV, or overwrite source.
Blender 2.83 compatible.
"""
import bpy
import math
import os
import sys

SRC = r"E:\SuperSmashKapes\super-smash-kapes\assets\vehicles\track\source\track_car_base_v1.glb"
DST = r"E:\SuperSmashKapes\super-smash-kapes\assets\vehicles\track\processed\track_car_base_v2_articulated.glb"
LOG = r"E:\SuperSmashKapes\super-smash-kapes\assets\vehicles\track\processed\wheel_split_log.txt"

# Blender is Z-up after glTF import: (x, y, z)_glTF → (x, z, y)_blender.
# Axle centers measured from source clusters, remapped into Blender space.
WHEELS = [
    ("Wheel_FL", (-0.201, 0.285, 0.085)),
    ("Wheel_FR", (0.204, 0.285, 0.085)),
    ("Wheel_RL", (-0.202, -0.298, 0.085)),
    ("Wheel_RR", (0.203, -0.298, 0.085)),
]
CAPTURE_MAJOR = 0.070
CAPTURE_TUBE = 0.018
TIRE_HALF_WIDTH = 0.034
KEEP_RADIUS = 0.105
MAX_WHEEL_Z = 0.175


def log(msg):
    print(msg)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(msg + "\n")


def dist(a, b):
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        bpy.ops.preferences.addon_enable(module="io_scene_gltf2")
    except Exception as e:
        log("addon_enable %s" % e)


def import_src():
    bpy.ops.import_scene.gltf(filepath=SRC)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("no mesh after glTF import")
    return meshes[0]


def separate_wheel(body, name, center):
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    mesh = body.data
    for v in mesh.vertices:
        co = v.co
        dx = co.x - center[0]
        dy = co.y - center[1]
        dz = co.z - center[2]
        radial = math.sqrt(dy * dy + dz * dz)
        axial = abs(dx)
        v.select = (
            co.z <= MAX_WHEEL_Z
            and axial <= TIRE_HALF_WIDTH
            and abs(radial - CAPTURE_MAJOR) <= CAPTURE_TUBE
        )
    selected = sum(1 for v in mesh.vertices if v.select)
    log("%s selected_verts=%d center=%s" % (name, selected, center))
    if selected < 20:
        bpy.ops.object.mode_set(mode="OBJECT")
        return None
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_linked()
    # re-filter: keep only linked verts still near this wheel (avoid stealing body)
    bpy.ops.object.mode_set(mode="OBJECT")
    for v in mesh.vertices:
        if not v.select:
            continue
        co = v.co
        dx = co.x - center[0]
        if dist((co.x, co.y, co.z), center) > KEEP_RADIUS or abs(dx) > TIRE_HALF_WIDTH * 1.55 or co.z > MAX_WHEEL_Z + 0.01:
            v.select = False
    kept = sum(1 for v in mesh.vertices if v.select)
    log("%s kept_verts=%d" % (name, kept))
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    # the new object is selected together with body; find the new mesh
    candidates = [o for o in bpy.context.selected_objects if o.type == "MESH" and o != body]
    if not candidates:
        # blender 2.83 may leave the split object as the only extra mesh
        extras = [o for o in bpy.context.scene.objects if o.type == "MESH" and o != body and o.name.startswith(body.name)]
        candidates = extras
    wheel = None
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o != body and o.name not in [w[0] for w in WHEELS] and not o.name.startswith("Wheel_"):
            if o.data and len(o.data.vertices) > 0:
                # likely the just-separated object if recently created
                wheel = o
    # Prefer the smallest extra mesh that isn't already renamed
    extras = [o for o in bpy.context.scene.objects if o.type == "MESH" and o != body and not o.name.startswith("Wheel_")]
    if extras:
        extras.sort(key=lambda o: len(o.data.vertices))
        wheel = extras[0]
    if wheel is None:
        log("%s SEPARATE_FAILED" % name)
        return None
    wheel.name = name
    # origin to axle center (source-local)
    bpy.ops.object.select_all(action="DESELECT")
    wheel.select_set(True)
    bpy.context.view_layer.objects.active = wheel
    bpy.context.scene.cursor.location = center
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    log("%s verts=%d origin=%s" % (name, len(wheel.data.vertices), tuple(wheel.location)))
    return wheel


def main():
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    if os.path.exists(LOG):
        os.remove(LOG)
    log("SRC=%s" % SRC)
    reset_scene()
    body = import_src()
    body.name = "Body"
    log("imported verts=%d" % len(body.data.vertices))
    wheels = []
    for name, center in WHEELS:
        w = separate_wheel(body, name, center)
        wheels.append(w)
    names = [o.name for o in bpy.context.scene.objects if o.type == "MESH"]
    log("mesh_objects=%s" % names)
    log("body_verts_after=%d" % len(body.data.vertices))
    bpy.ops.object.select_all(action="SELECT")
    # 2.83 glTF export
    kwargs = dict(filepath=DST, export_format="GLB")
    try:
        bpy.ops.export_scene.gltf(**kwargs)
    except TypeError:
        bpy.ops.export_scene.gltf(filepath=DST)
    log("exported %s exists=%s size=%s" % (DST, os.path.exists(DST), os.path.getsize(DST) if os.path.exists(DST) else 0))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log("EXCEPTION %s" % e)
        raise
