# SMASH Blender Fighter Pipeline V1

## Toolchain

| Item | Value |
|------|--------|
| Blender | `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` |
| Version | **Blender 5.2.1 LTS** |
| Script | `tools/blender/smash/build_stylized_smash_art_v1.py` |
| Style | Stylized party-game primitives (not ActorCore / photoreal) |

## Build command

```bat
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python tools/blender/smash/build_stylized_smash_art_v1.py
```

Run from `super-smash-kapes/` (script resolves `ROOT` as three parents above `tools/blender/smash/`).

## Outputs

| Fighter | GLB | Portraits |
|---------|-----|-----------|
| `fort` | `assets/fighters/processed/fort/fort_stylized_v1.glb` | `assets/ui/portraits/fort_portrait.png`, `assets/ui/victory/fort/fort_victory.png` |
| `cartes` | `assets/fighters/processed/cartes/cartes_stylized_v1.glb` | same pattern |
| `pajaro_campana` | `assets/fighters/processed/pajaro_campana/pajaro_campana_stylized_v1.glb` | same pattern |

Review package (outside repo):

`E:\JeffreyAIResearch\outputs\runtime-review\smash_art_asset_production_v1\fighters\<id>\`

Includes: `front`, `three_quarter`, `side`, `gameplay_distance`, `select_portrait`, `victory_portrait`.

## Godot integration

- Catalog: `FighterCatalog` sets `pipeline_id = JEFFREY_STYLIZED_BLENDER_V1`
- Visual: `jeffrey_stylized_glb_visual.gd` loads `production_glb_path`
- Fallback: `jeffrey_stylized_fighter_visual.gd` (procedural) if GLB missing
- Combat: unchanged — visual only; collision stays on `Fighter`
- Facing: GLB root rotated +90° Y so Blender +Y forward maps to Smash +X facing

## Animation contract (MVP)

No full skeleton in this sprint. Named mesh parts (`ArmL`/`ArmR`/`LegL`/`LegR`/`Star`) receive the same procedural motion as the fallback visual (idle bob, attack swing, hitstun, air legs).

If advanced rigging is needed later: export static GLB and keep this procedural layer — do not block art on rig perfection.

## Export settings

- Format: GLB
- `export_apply=True`, `export_yup=True`, selection only
- Materials: Principled BSDF, simple albedo/rough/metal/emission (no large textures)

## Safety bounds

- One Blender process
- Low-poly primitives (target well under dense remesh)
- 512×512 / 512×640 portrait renders
- Stop if memory behavior is abnormal
