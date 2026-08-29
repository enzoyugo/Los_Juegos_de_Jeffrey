import bpy
import math

SRC = r"E:\SuperSmashKapes\super-smash-kapes\assets\vehicles\track\source\track_car_base_v1.glb"
WHEELS = [
    ("FL", (-0.201, 0.285, 0.085)),
    ("FR", (0.204, 0.285, 0.085)),
    ("RL", (-0.202, -0.298, 0.085)),
    ("RR", (0.203, -0.298, 0.085)),
]

bpy.ops.wm.read_factory_settings(use_empty=True)
try:
    bpy.ops.preferences.addon_enable(module="io_scene_gltf2")
except Exception:
    pass
bpy.ops.import_scene.gltf(filepath=SRC)
mesh_obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
verts = [v.co.copy() for v in mesh_obj.data.vertices]


def count_for(center, major, tube, half_w, hub_r, hub_w):
    n_tire = 0
    n_hub = 0
    for v in verts:
        dx = v.x - center[0]
        dy = v.y - center[1]
        dz = v.z - center[2]
        q = math.sqrt(dy * dy + dz * dz)
        if abs(dx) <= half_w and abs(q - major) <= tube:
            n_tire += 1
        elif abs(dx) <= hub_w and q <= hub_r:
            n_hub += 1
    return n_tire, n_hub

params = [
    (0.070, 0.018, 0.036, 0.050, 0.028),
    (0.072, 0.020, 0.040, 0.055, 0.032),
    (0.068, 0.016, 0.032, 0.045, 0.024),
    (0.075, 0.022, 0.042, 0.058, 0.034),
]
for p in params:
    print("params", p)
    for name, c in WHEELS:
        t, h = count_for(c, *p)
        print("  %s tire=%d hub=%d total=%d" % (name, t, h, t + h))
