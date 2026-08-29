"""Jeffrey stylized material pack V2 — stable under portrait + gameplay lighting."""

from __future__ import annotations

import bpy


def _bsdf(mat):
    node = mat.node_tree.nodes.get("Principled BSDF")
    if node is None:
        node = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    return node


def _set_rgba(bsdf, key: str, rgba) -> None:
    try:
        bsdf.inputs[key].default_value = rgba
    except Exception:
        pass


def _set_float(bsdf, key: str, value: float) -> None:
    try:
        bsdf.inputs[key].default_value = float(value)
    except Exception:
        pass


def make_material(
    name: str,
    color,
    *,
    rough: float = 0.55,
    metal: float = 0.0,
    emit: float = 0.0,
    specular: float = 0.35,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = _bsdf(mat)
    rgba = (float(color[0]), float(color[1]), float(color[2]), 1.0)
    mat.diffuse_color = rgba
    _set_rgba(bsdf, "Base Color", rgba)
    _set_float(bsdf, "Roughness", rough)
    _set_float(bsdf, "Metallic", metal)
    _set_float(bsdf, "Specular IOR Level", specular)
    if emit > 0.0:
        _set_rgba(bsdf, "Emission Color", rgba)
        _set_float(bsdf, "Emission Strength", emit)
    return mat


def assign(obj, material) -> None:
    if obj.data.materials:
        obj.data.materials[0] = material
    else:
        obj.data.materials.append(material)


class JeffreyMaterialsV2:
    """Named material set for stylized humanoids."""

    def __init__(self, prefix: str = "JSV2"):
        self.skin = make_material(f"{prefix}_SKIN", (0.92, 0.74, 0.58), rough=0.48, specular=0.25)
        self.hair = make_material(f"{prefix}_HAIR", (0.07, 0.05, 0.05), rough=0.72, specular=0.15)
        self.white_fabric = make_material(
            f"{prefix}_WHITE_FABRIC", (0.96, 0.95, 0.92), rough=0.62, metal=0.0, emit=0.04, specular=0.2
        )
        # Stylized gold: mild metal + tiny emit, not blown yellow.
        self.gold = make_material(
            f"{prefix}_GOLD", (0.86, 0.68, 0.28), rough=0.32, metal=0.55, emit=0.08, specular=0.45
        )
        self.dark_fabric = make_material(f"{prefix}_DARK_FABRIC", (0.10, 0.09, 0.12), rough=0.7, specular=0.15)
        self.glasses = make_material(
            f"{prefix}_GLASSES", (0.04, 0.04, 0.05), rough=0.18, metal=0.35, emit=0.02, specular=0.6
        )
        self.glasses_frame = make_material(
            f"{prefix}_GLASSES_FRAME", (0.78, 0.62, 0.22), rough=0.28, metal=0.6, emit=0.05, specular=0.5
        )
        self.silhouette = make_material(f"{prefix}_SILHOUETTE", (0.08, 0.08, 0.09), rough=1.0, metal=0.0)
        self.lip = make_material(f"{prefix}_LIP", (0.72, 0.35, 0.38), rough=0.45, specular=0.3)
        self.brow = make_material(f"{prefix}_BROW", (0.05, 0.04, 0.04), rough=0.7)
