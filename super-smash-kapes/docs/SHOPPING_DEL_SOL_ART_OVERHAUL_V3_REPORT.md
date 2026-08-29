# Shopping del Sol art overhaul V3

**Primary verdict: SHOPPING_DEL_SOL_ART_OVERHAUL_V3_PARTIAL**

**Recognition: SHOPPING_SDS_VISUAL_MATCH_HUMAN_REVIEW_REQUIRED**

This is an honest PARTIAL. V3 is a clear step up from V9/V2 (rectangular terracotta mall), but it is still a **stylized interpretation**. Do not treat this as a photographic match.

## What changed

Priority order was facade → parking → interior.

### Facade (highest effort)

V2 was a flat terracotta slab with a rectangular recess. That is not SDS.

V3 rebuilds the night-entrance identity from `EXTERIOR_STATION_034`:

- layered **cream arch** (three concentric rib shells + glass infill)
- **gold 8-point star** at the crown
- extruded **SHOPPING del SOL** lettering
- cream **portal piers** + canopy
- **square-pier wings** with recessed glass shopfronts and warm uplights at each pier base

This is the first version where the silhouette can read as “arched SDS entrance” instead of “generic mall box”.

### Parking / approach

- Center aisle + stall language kept
- **Zig-zag terracotta border** on a tiled pedestrian walk (the night-plaza marker)
- zebra at the doors
- curved-neck lamps
- island palms + low fan palms at the threshold
- **16 instanced Hilux + VAZ** parked cars
- PSX industrial pack once, service edge only

### Interior (first playable hall)

- **diamond-accent cream tile texture** (1024, generated, Godot-importable)
- hall ~20 m wide, visual ceiling ~11 m with **wood vault ribs** + skylight strip
- brick upper bands, storefront rhythm, kiosk
- code-built greybox meshes **hidden** when the Blender shell loads (collision / door 1500 / wall-buy / nav kept)

## What references were used

Listed in `docs/generated/sds_v3_authority_frames.txt`.

| Role | Source |
|---|---|
| Night arch / star / zig-zag plaza | `EXTERIOR_STATION_034` angle_000 |
| Street / massing | `EXTERIOR_STATION_016` |
| Parking approach / zebra | `EXTERIOR_STATION_007` |
| Lot density / islands | `EXTERIOR_STATION_001` |
| Floor diamonds + wide hall | `INTERIOR_STATION_032` |
| Atrium / brick upper | `INTERIOR_STATION_035` |
| Wood vault | `photos/references/shopping-del-sol.jpg` |

Street View is **not** imported into Godot (`.gdignore`).

## Which raw assets were used

See `docs/generated/sds_v3_asset_decisions.json`.

| Asset | Decision |
|---|---|
| Hilux FBX → `hilux_parked.glb` | **USED** in the lot |
| VAZ scan → `vaz_parked.glb` | **USED** in the lot (still carries a 4K albedo) |
| PSX industrial pack | **USED** once at the service edge |
| Wrecked car | **REJECT this pass** — 26 MB, fights “mall open at night” |
| Market AL DANUBE | **REJECT this pass** — extract is mixed branding/vegetation; SDS palms are custom |
| Cement bags | **REJECT this pass** — clutter vs facade-first |
| Ice Scream mall / sci-fi portal | **REJECT** — wrong identity |

## Which assets were custom-built in Blender

Arch, star, sign, piers, shopfronts, zig-zag plaza, tile textures, vault ribs, palms, fan palms, curved lamps, bollards, benches, interior columns/kiosk.

The library has **no** SDS arch, star, tile language, or vault. Those had to be authored.

## Measured export

Blender 5.2.1 LTS, no EEVEE (same GPU crash path as V2):

`meshes=725 vertices=628800 triangles=429252 materials=77 textures=3 file_bytes=7014820`

Lab runtime: meshes=723–725, mats=77, texn=3, static ~100 MB. VAZ albedo capped at 1024 to avoid D3D12 1×1/4K import failure.

## What remains weak / partial

- Arch is **segmented boxes**, not a smooth NURBS atrium. Better than V2’s rectangle; still not the real multi-shell glass atrium.
- Sign is default Blender font. Readable from spawn; extrusion can read reversed from the door threshold.
- Palms are improved frond bursts, not botanical.
- Interior hall is **wide and tall**, but diamond tiles are weak at gameplay camera and vault ribs do not yet read as the wood ceiling photo.
- First hall only. No mezzanine / circular atrium.
- Aviadores towers / bus shelters / Forever 21 slat wall were not rebuilt (facade-first).
- VAZ scan paint still looks noisy even at 1024.

## Gameplay firewalls

Door **1500**. Nav / rounds / wall-buy / gallery door unchanged. Visual GLB has **no trimesh**. `raw_models` not loaded at runtime.

## What to F6 first

1. `scenes/debug/ShoppingBlenderEnvironmentV3Lab.tscn` — **this is the art gate**. From spawn: do you see an arch + star + SHOPPING del SOL, or still a generic mall?
2. Then `scenes/zombies/ZombiesMain.tscn` — confirm door 1500, parking combat, interior after purchase.

Stills: `docs/generated/sds_v3_visual_review/` (after capture).

Blend source: `assets/environments/shopping_del_sol/blender/shopping_del_sol_zombies_environment_v3.blend`
