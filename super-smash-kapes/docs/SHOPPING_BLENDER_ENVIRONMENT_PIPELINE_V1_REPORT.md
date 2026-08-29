# Shopping Blender environment pipeline V1

## Primary Verdict

**SHOPPING_BLENDER_REQUIRED**

Blender is not installed (`tools/find_blender.py` → `BLENDER_REQUIRED`). No GLB was faked. Outdoor SDS visual is **not** claimed.

## Local raw inventory (not loaded at Godot runtime)

`assets/raw_models/` is `.gdignore`d. Present on disk:

| Asset | Notes |
|---|---|
| `market-al-danube.zip` + extracted `Market AL_DANUBE.fbx` | Parking/commercial candidate. **Do not import tenant logos** (H&M texture present). |
| `psx_industrial_pack.glb` | Containers / industrial. Runtime only after processed copy. |
| `cement_bags_low-poly.glb` | Props. |
| `vaz_2104_-_raw_scan.glb` | Parked-car candidate (static mesh only). |
| `wrecked-car.zip` + `export_002.glb` | Parked wreck candidate. Heavy textures. |
| `toyota-hilux-revo-prerunner-2021.zip` | Vehicle static mesh candidate. |
| `ice_scream_3_shopping_center_map.glb` | Unrelated mall. Do not use as SDS identity. |
| `portal-gate-sci-fi.zip` | Not SDS architecture. |

No stylized low-poly **zombie** or **pistol** mesh exists in this library (Phase 15 skipped). Requirement: separate stylized low-poly zombie + pistol. Do not box-build them.

## What was prepared

- `docs/JEFFREY_GAME_PRODUCTION_PIPELINE_V1.md`
- `assets/environments/shopping_del_sol/blender/README.md`
- `assemble_shopping_del_sol_v1.py` (scaffold only — cube/plane is **not** SDS)
- `tools/build_shopping_blender_env.py`

No `exports/shopping_del_sol_zombies_environment_v1.glb`.

## Gameplay preserved

ZombiesMain: parking spawn, 1500 SHOPPING door, nav, wall-buy, MAX AMMO.

## Surgical Godot bugfixes (not a visual rebuild)

- Interior roof kept inside the mall volume so parking sky is open.
- Entrance omni/spot energy and exposure reduced.
- Existing shopping GLB remains loaded-hidden (volumetric shell).

These do **not** make the map look like Shopping del Sol.

## When Blender exists

1. Assemble parking + facade + entrance from references (Street View stays `.gdignore`d — do not import into Godot).
2. Extract generic parking parts from market-al-danube **without tenant logos**.
3. Place real vehicle static meshes (VAZ / Hilux / wreck as appropriate).
4. Export optimized GLB.
5. Godot: visual instance + existing collision proxies / nav.
6. Human only: `SHOPPING_BLENDER_ENVIRONMENT_V1_READY_FOR_HUMAN_REVIEW`.
