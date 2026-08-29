import bpy
import math

SRC = r"E:\SuperSmashKapes\super-smash-kapes\assets\vehicles\track\source\track_car_base_v1.glb"
CENTER = (-0.201, 0.285, 0.085)
MAJOR = 0.070
TUBE = 0.016
HALF_W = 0.032

bpy.ops.wm.read_factory_settings(use_empty=True)
try:
    bpy.ops.preferences.addon_enable(module="io_scene_gltf2")
except Exception:
    pass
bpy.ops.import_scene.gltf(filepath=SRC)
body = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="DESELECT")
bpy.ops.object.mode_set(mode="OBJECT")
mesh = body.data
n = 0
for v in mesh.vertices:
    dx = v.co.x - CENTER[0]
    dy = v.co.y - CENTER[1]
    dz = v.co.z - CENTER[2]
    q = math.sqrt(dy * dy + dz * dz)
    hit = abs(dx) <= HALF_W and abs(q - MAJOR) <= TUBE
    v.select = hit
    if hit:
        n += 1
print("torus_selected", n)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_linked()
bpy.ops.object.mode_set(mode="OBJECT")
linked = sum(1 for v in mesh.vertices if v.select)
print("after_select_linked", linked)
