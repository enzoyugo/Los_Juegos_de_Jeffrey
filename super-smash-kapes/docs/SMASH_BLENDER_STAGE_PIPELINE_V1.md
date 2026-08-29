# SMASH Blender Stage Pipeline V1

## Authority split

| Layer | Authority |
|-------|-----------|
| `StageGameplayRoot` | Collision, spawns, blasts — **unchanged** |
| `ArtRoot` / Blender visual GLB | Visual only |
| Camera sky quad + silhouette | Fallback if GLB missing |

## Toolchain

Same Blender 5.2.1 LTS + `tools/blender/smash/build_stylized_smash_art_v1.py`.

## Outputs

| Stage id | GLB |
|----------|-----|
| `palacio` | `assets/stages/palacio_de_lopez/visual/palacio_visual_v1.glb` |
| `costanera` | `assets/stages/costanera_de_asuncion/visual/costanera_visual_v1.glb` |

## Godot load path

`JeffreySmashStageBase._try_attach_visual_glb()`:

1. Uses `visual_glb_path` export or default path by `stage_id`
2. Instantiates under `ArtRoot` at `(0, -1, -28)`, scale `1.15`
3. Hides `jeffrey_stage_silhouette` group when GLB loads
4. Keeps far sky quad for atmosphere

Disable with env `SSK_DISABLE_STAGE_VISUALS=1`.

## Design intent

- **Palacio:** central mass + twin towers + emissive windows + flag colors
- **Costanera:** river plane, walkway, skyline blocks, lamps, trees
- Low contrast distant geometry; combat platform remains readable
- No collision on visual meshes

## Triangle budget (build stats)

See `E:\JeffreyAIResearch\outputs\runtime-review\smash_art_asset_production_v1\blender_build_stats.json`.
