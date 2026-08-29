"""Print Blender version and glTF export operator properties."""

import bpy

print("BLENDER", bpy.app.version_string)
print("FACTORY", hasattr(bpy.ops.wm, "read_factory_settings"))
try:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    print("READ_FACTORY_EMPTY OK")
except Exception as e:
    print("READ_FACTORY_EMPTY FAIL", type(e).__name__, e)
    try:
        bpy.ops.wm.read_homefile(use_empty=True)
        print("READ_HOMEFILE_EMPTY OK")
    except Exception as e2:
        print("READ_HOMEFILE FAIL", type(e2).__name__, e2)

op = bpy.ops.export_scene.gltf
print("GLTF_OP", op)
rna = bpy.ops.export_scene.get_rna_type("gltf") if hasattr(bpy.ops.export_scene, "get_rna_type") else None
try:
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    print("GLTF_PROPS", sorted(props))
except Exception as e:
    print("GLTF_PROPS_FAIL", type(e).__name__, e)
    try:
        print("DIR_OP", [k for k in dir(bpy.ops.export_scene) if "gltf" in k.lower()])
    except Exception:
        pass
