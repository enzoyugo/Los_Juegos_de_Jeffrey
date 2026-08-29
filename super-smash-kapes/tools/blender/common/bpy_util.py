"""Blender 5.x helpers. Importable only inside Blender."""

from __future__ import annotations

import json
import os


def enable_gltf():
    import bpy

    try:
        bpy.ops.preferences.addon_enable(module="io_scene_gltf2")
    except Exception:
        pass


def reset_scene():
    import bpy

    try:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    except TypeError:
        bpy.ops.wm.read_homefile(use_empty=True)
    enable_gltf()
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0


def collection(name):
    import bpy

    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def ensure_child(parent, name):
    import bpy

    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
    if name not in parent.children:
        parent.children.link(col)
    return col


def link(obj, col):
    import bpy

    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)


def _set_socket(bsdf, names, value):
    for name in names:
        sock = bsdf.inputs.get(name)
        if sock is None:
            continue
        try:
            sock.default_value = value
            return True
        except Exception:
            continue
    return False


def new_mat(name, color, emit=0.0, rough=0.78, metal=0.0, alpha=1.0):
    import bpy

    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None)
        if out is not None:
            nt.links.new(bsdf.outputs[0], out.inputs[0])
    rgba = (float(color[0]), float(color[1]), float(color[2]), float(alpha))
    _set_socket(bsdf, ["Base Color"], rgba)
    _set_socket(bsdf, ["Roughness"], float(rough))
    _set_socket(bsdf, ["Metallic"], float(metal))
    if alpha < 0.999:
        mat.blend_method = "BLEND"
        _set_socket(bsdf, ["Alpha"], float(alpha))
    if emit > 0.0:
        _set_socket(bsdf, ["Emission Color", "Emission"], rgba)
        _set_socket(bsdf, ["Emission Strength"], float(emit))
    return mat


def _active(obj):
    import bpy

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_transforms(obj):
    import bpy

    _active(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def box(name, size, loc, rot_euler, mat, col):
    import bpy

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (float(size[0]), float(size[1]), float(size[2]))
    obj.rotation_euler = rot_euler
    apply_transforms(obj)
    if mat is not None:
        if obj.data.materials:
            obj.data.materials[0] = mat
        else:
            obj.data.materials.append(mat)
    link(obj, col)
    return obj


def cylinder(name, radius, depth, loc, rot_euler, mat, col, verts=12):
    import bpy

    bpy.ops.mesh.primitive_cylinder_add(
        vertices=int(verts),
        radius=float(radius),
        depth=float(depth),
        location=loc,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_euler = rot_euler
    apply_transforms(obj)
    if mat is not None:
        obj.data.materials.append(mat)
    link(obj, col)
    return obj


def ico(name, radius, loc, mat, col, subdiv=1):
    import bpy

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=int(subdiv), radius=float(radius), location=loc)
    obj = bpy.context.active_object
    obj.name = name
    apply_transforms(obj)
    if mat is not None:
        obj.data.materials.append(mat)
    link(obj, col)
    return obj


def plane(name, size, loc, rot_euler, mat, col):
    import bpy

    bpy.ops.mesh.primitive_plane_add(size=float(size), location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_euler = rot_euler
    apply_transforms(obj)
    if mat is not None:
        obj.data.materials.append(mat)
    link(obj, col)
    return obj


def empty(name, loc, rot_euler, col, size=1.2):
    import bpy

    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = float(size)
    obj.location = loc
    obj.rotation_euler = rot_euler
    link(obj, col)
    return obj


def join_named(prefix, col):
    import bpy

    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in col.objects if o.type == "MESH" and o.name.startswith(prefix)]
    if len(objs) < 2:
        return objs[0] if objs else None
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = prefix.rstrip("_")
    return objs[0]


def join_objects(objs, name):
    import bpy

    meshes = [o for o in objs if o is not None and o.type == "MESH"]
    if not meshes:
        return None
    if len(meshes) == 1:
        meshes[0].name = name
        return meshes[0]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    meshes[0].name = name
    return meshes[0]


def hide_all_mesh():
    import bpy

    for o in bpy.data.objects:
        o.hide_set(True)
        o.hide_render = True
        o.select_set(False)


def show_collection(col, visible=True):
    for o in col.objects:
        o.hide_set(not visible)
        o.hide_render = not visible
        o.select_set(visible)
        if visible:
            import bpy

            bpy.context.view_layer.objects.active = o


def import_glb(path):
    import bpy

    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [o for o in bpy.data.objects if o not in before]


def import_fbx(path):
    import bpy

    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(path), automatic_bone_orientation=True)
    return [o for o in bpy.data.objects if o not in before]


def import_obj(path):
    import bpy

    before = set(bpy.data.objects)
    try:
        bpy.ops.wm.obj_import(filepath=str(path))
    except Exception:
        bpy.ops.import_scene.obj(filepath=str(path))
    return [o for o in bpy.data.objects if o not in before]


def mesh_objects(objs=None):
    import bpy

    src = objs if objs is not None else bpy.data.objects
    return [o for o in src if o.type == "MESH"]


def triangle_count(objs=None):
    n = 0
    for o in mesh_objects(objs):
        mesh = o.data
        mesh.calc_loop_triangles()
        n += len(mesh.loop_triangles)
    return n


def join_objects(objs, name="Joined"):
    import bpy

    meshes = mesh_objects(objs)
    if not meshes:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    if obj is not None:
        obj.name = name
    return obj


def normalize_to_length(obj, target_len, axis="y"):
    """Scale so the longest world AABB side ≈ target_len (meters). axis unused; uses max dim."""
    import bpy
    from mathutils import Vector

    _active(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    xs = [c.x for c in corners]
    ys = [c.y for c in corners]
    zs = [c.z for c in corners]
    dim = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    if dim < 0.001:
        return obj
    s = float(target_len) / dim
    obj.scale = (s, s, s)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def drop_to_ground(obj):
    from mathutils import Vector

    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    min_z = min(c.z for c in corners)
    obj.location.z -= min_z
    return obj


def decimate(obj, ratio):
    import bpy

    _active(obj)
    mod = obj.modifiers.new(name="DecimateV9", type="DECIMATE")
    mod.ratio = float(ratio)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj



def export_glb(path, selected=False):
    import bpy

    os.makedirs(os.path.dirname(path), exist_ok=True)
    enable_gltf()
    kwargs = {
        "filepath": path,
        "export_format": "GLB",
        "export_apply": True,
        "export_yup": True,
    }
    if selected:
        kwargs["use_selection"] = True
        kwargs["use_visible"] = True
    optional = {
        "export_texcoords": True,
        "export_normals": True,
        "export_materials": "EXPORT",
        "export_cameras": False,
        "export_lights": False,
        "export_extras": True,
    }
    last_err = None
    for extra in ({}, optional):
        try:
            bpy.ops.export_scene.gltf(**{**kwargs, **extra})
            return path
        except TypeError as e:
            last_err = e
    # Last resort: minimal kwargs.
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB")
    if last_err:
        print("GLTF_EXPORT_FALLBACK", last_err)
    return path


def aabb_of_meshes():
    import bpy
    from mathutils import Vector

    mins = Vector((1e9, 1e9, 1e9))
    maxs = Vector((-1e9, -1e9, -1e9))
    any_mesh = False
    for o in bpy.data.objects:
        if o.type != "MESH" or o.hide_get():
            continue
        any_mesh = True
        for corner in o.bound_box:
            w = o.matrix_world @ Vector(corner)
            mins.x = min(mins.x, w.x)
            mins.y = min(mins.y, w.y)
            mins.z = min(mins.z, w.z)
            maxs.x = max(maxs.x, w.x)
            maxs.y = max(maxs.y, w.y)
            maxs.z = max(maxs.z, w.z)
    if not any_mesh:
        return [0, 0, 0], [0, 0, 0]
    return [mins.x, mins.y, mins.z], [maxs.x, maxs.y, maxs.z]


def stats_report(path, extra=None):
    import bpy

    meshes = [o for o in bpy.data.objects if o.type == "MESH" and not o.hide_get()]
    verts = sum(len(o.data.vertices) for o in meshes)
    tris = 0
    for o in meshes:
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
    imgs = list(bpy.data.images)
    tex_dims = [[int(im.size[0]), int(im.size[1]), im.name] for im in imgs if getattr(im, "size", None)]
    mn, mx = aabb_of_meshes()
    row = {
        "glb": path,
        "objects": len([o for o in bpy.data.objects if not o.hide_get()]),
        "meshes": len(meshes),
        "vertices": verts,
        "triangles": tris,
        "materials": len(bpy.data.materials),
        "textures": len(imgs),
        "texture_dimensions": tex_dims,
        "aabb_min": mn,
        "aabb_max": mx,
        "file_bytes": os.path.getsize(path) if os.path.exists(path) else 0,
    }
    if extra:
        row.update(extra)
    print("BLENDER_STATS", json.dumps(row))
    return row
