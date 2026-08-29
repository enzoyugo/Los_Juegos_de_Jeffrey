# Shopping Blender ↔ Godot integration V1

**Verdict: SHOPPING_BLENDER_GODOT_INTEGRATION_V1_READY_FOR_HUMAN_REVIEW** (environment lab first)

## Lab (required before ZombiesMain)

`scenes/debug/ShoppingBlenderEnvironmentV1Lab.tscn`

Loads the Blender GLB + simple floor proxies. No zombies. Camera at parking spawn `(0, 1.65, 28.5)` looking at the entrance `z=8.2`.

First five seconds should show: parking, cars, palms/trees, lamps, facade, main entrance. Open sky.

Measured after Godot import (2026-08-27):

```
[SDS_LAB] loaded=res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v1.glb HUMAN_REVIEW_PENDING
meshes=426 mats=22 env=1 camera pos=(0.0, 1.65, 28.5) looking entrance z=8.2
```

Do **not** auto-declare MATCH. Human judges whether this looks like Shopping del Sol.

## ZombiesMain (conservative)

If the processed GLB exists:

- `Parking.add_lot(..., visuals=false)` keeps nav/collision floors and boundary proxies
- Instances Blender env, **strips gameplay collision**
- Spawns OmniLights at `LIGHT_*` empties
- Hides the giant code-built “SHOPPING del SOL” Label3D
- Skips the old shell visual path

If the GLB is missing, previous code-built parking visuals remain.

Preserved: door `[E] ABRIR SHOPPING` (1500), wall-buy, MAX AMMO, interior greybox, nav bake.

Detailed env mesh is visual-only. No trimesh.

## Comparison

Authority image list: `docs/generated/sds_authority_images_v1.txt`

Do **not** auto-declare MATCH. Mark **HUMAN_REVIEW_PENDING**.
