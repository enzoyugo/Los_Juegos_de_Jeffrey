# Jeffrey Blender asset-first V9 master

**Master verdict: JEFFREY_BLENDER_ASSET_FIRST_V9_READY_FOR_HUMAN_REVIEW**

Agent READY ≠ canonical. Human visual authority is mandatory.

## Sub-verdicts

| Area | Verdict |
|---|---|
| Assets | `JEFFREY_BLENDER_ASSET_FIRST_V2_PARTIAL` |
| Shopping env | `SHOPPING_DEL_SOL_BLENDER_V2_READY_FOR_HUMAN_REVIEW` |
| SDS recognition | `SHOPPING_SDS_VISUAL_MATCH_HUMAN_REVIEW_REQUIRED` |
| Track airborne | `TRACK_AIRBORNE_SEAMS_V3_PARTIAL` |
| Drift / camera | `TRACK_DRIFT_CAMERA_V2_READY_FOR_HUMAN_REVIEW` |
| Track scenery | `TRACK_ASUNCION_URBAN_ASSET_FIRST_V3_READY_FOR_HUMAN_REVIEW` |

## Firewalls

- Generator V4 frozen
- 11 m kit intact; 15 m still candidate
- TrackMain BASELINE
- No spring/COM retune
- Door 1500
- `raw_models` not loaded at runtime
- Street View not imported into Godot
- Visual meshes not trimesh collision

## What to open

**Track:** F6 `scenes/debug/TrackTurboV8Showcase.tscn`  
Judge: 15 m, finish runoff (no void), split HUD, drift ARM vs ACTIVE, scenery cars/palms, reveal framing.

Also: `Track15mKitShowcase.tscn`.

**Zombies:** F6 `scenes/debug/ShoppingBlenderEnvironmentV2Lab.tscn` **first**.  
Question: “Does this look like Shopping del Sol?”  
Then `ZombiesMain.tscn` (V2 GLB if imported, else V1).

Zombie/pistol GLBs are a **foundation** (`assets/characters/...`, `assets/weapons/...`) — not swapped into gameplay this sprint.

## F6 / memory (measured 2026-08-27)

Harness `F6RepeatStabilityLab.tscn` ×10, hold 3.2 s:

TrackTurboV8Showcase → ShoppingBlenderEnvironmentV2Lab → ZombiesMain

`[F6_STABILITY] PASS launches=10 fatal=false`

Peak static **308.8 MB**. Video plateau **~660 MB**. No OOM / mem=null / bad_alloc / signal 11.

SDS V2 lab: meshes=411 mats=70 texn=2. ZombiesMain loads the **V2** GLB.

Seam smoke: `samples=70 gaps=0` + `finish_runoff`.

pytest: **362 passed**. Path scan clean. `[JEFFREY_VALIDATE] OK`.

Visual review stills: `docs/generated/v9_visual_review/`

## Timebox leftovers

- Human 10–55 m/s seam drive (inspector is green; speed matrix is not automated)
- Hilux orientation/decimate if import is heavy
- Resize VAZ 4K albedo toward 1–2K if VRAM hurts
- Market AL DANUBE per-object extract if cluster is too mixed
- Full SDS interior
- Rig/animate zombie; wire pistol/zombie GLBs into gameplay (foundation only)
- EEVEE Blender beauty stills (disabled: `nvoglv64.dll` crash on this machine)
