import bpy
import os

SRC = r"E:\SuperSmashKapes\super-smash-kapes\assets\vehicles\track\source\track_car_base_v1.glb"
OUT = r"E:\SuperSmashKapes\super-smash-kapes\assets\vehicles\track\processed\wheel_dump.txt"

bpy.ops.wm.read_factory_settings(use_empty=True)
try:
    bpy.ops.preferences.addon_enable(module="io_scene_gltf2")
except Exception:
    pass
bpy.ops.import_scene.gltf(filepath=SRC)
mesh_obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
verts = [v.co.copy() for v in mesh_obj.data.vertices]
xs = [v.x for v in verts]
ys = [v.y for v in verts]
zs = [v.z for v in verts]
lines = []
lines.append("count %d" % len(verts))
lines.append("X %s %s" % (min(xs), max(xs)))
lines.append("Y %s %s" % (min(ys), max(ys)))
lines.append("Z %s %s" % (min(zs), max(zs)))
low = [v for v in verts if v.z < 0.12]
lines.append("low_z<0.12 %d" % len(low))
if low:
    lines.append("low X %s %s" % (min(v.x for v in low), max(v.x for v in low)))
    lines.append("low Y %s %s" % (min(v.y for v in low), max(v.y for v in low)))
    lines.append("low Z %s %s" % (min(v.z for v in low), max(v.z for v in low)))
quads = {"xp_yp": [], "xn_yp": [], "xp_yn": [], "xn_yn": []}
for v in low:
    if abs(v.x) < 0.12:
        continue
    key = ("xp" if v.x >= 0 else "xn") + ("_yp" if v.y >= 0 else "_yn")
    quads[key].append(v)
for k in quads:
    vs = quads[k]
    if not vs:
        lines.append("%s empty" % k)
        continue
    cx = sum(v.x for v in vs) / len(vs)
    cy = sum(v.y for v in vs) / len(vs)
    cz = sum(v.z for v in vs) / len(vs)
    zmin = min(v.z for v in vs)
    zmax = max(v.z for v in vs)
    lines.append("%s n=%d c=(%.4f, %.4f, %.4f) z[%.3f,%.3f]" % (k, len(vs), cx, cy, cz, zmin, zmax))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
text = "\n".join(lines)
with open(OUT, "w", encoding="utf-8") as f:
    f.write(text)
print(text)
