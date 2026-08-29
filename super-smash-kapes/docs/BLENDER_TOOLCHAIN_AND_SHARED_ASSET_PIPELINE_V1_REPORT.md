# Blender toolchain and shared asset pipeline V1

**Verdict: JEFFREY_BLENDER_PIPELINE_V1_READY**

Blender **5.2.1 LTS** is the authoring executable. Godot remains gameplay authority. Raw sources are never overwritten.

## Detected

| Key | Value |
|---|---|
| BLENDER_EXECUTABLE | `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` |
| BLENDER_VERSION | Blender 5.2.1 LTS |

Detection: `python tools/find_blender.py`

## Layout

```
tools/blender/common/bpy_util.py     Principled BSDF, GLB export, stats
tools/blender/track/                 15 m kit + urban kit
tools/blender/zombies/               SDS outdoor environment
tools/blender/run_v8_content.py      CLI orchestrator
```

Policy: `blender.exe --background --python script.py`. No mouse automation.

## Output contract

| Kind | Path |
|---|---|
| RAW | `assets/raw_models/` (`.gdignore`, not runtime) |
| BLENDER SOURCE | `assets/**/blender/*.blend` |
| PROCESSED GLB | `assets/**/processed/` and kit_v8_15m |
| SDS EXPORT | `assets/environments/shopping_del_sol/blender/exports/` + processed copy |

GLB export: apply transforms, Y-up via glTF exporter, Principled materials (Blender 5 has no `use_nodes=False` diffuse path).

Every export prints `BLENDER_STATS` JSON: objects, meshes, vertices, triangles, materials, textures, AABB, file bytes.

## Shared urban kit

`assets/environments/shared/urban/{vehicles,vegetation,lighting,street_props,industrial}/`

Track (arcade daylight) and Zombies (night parking) instance the same meshes with different lighting.

## Classification (raw)

See `docs/SHOPPING_RAW_ASSET_INVENTORY_V1.md`. Runtime this sprint uses Blender-authored low-poly urban kit + existing processed `psx_industrial_pack.glb`. Hilux/VAZ/market FBX remain REFERENCE_ONLY. Ice Cream mall / sci-fi gate REJECT.

## Human

Open `.blend` files for visual authority. Automation passing is not canonical.
