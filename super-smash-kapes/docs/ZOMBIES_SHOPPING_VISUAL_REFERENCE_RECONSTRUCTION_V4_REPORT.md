# Zombies Shopping visual reference reconstruction V4

## Primary Verdict

**ZOMBIES_SHOPPING_VISUAL_V4_PARTIAL**

**Visual capability:** **ZOMBIES_VISUAL_PIPELINE_LIMITATION_DETECTED**

This sprint used real Street View coverage, photos, the Shopping GLB, local 3D packs, and a full lighting pass. The exterior is **better than the 48×34 brown pad**, but it is **not** “YES, THIS IS SHOPPING DEL SOL” from spawn. Declaring READY would be self-congratulation.

The limiting factor is **not missing references**. It is the **Godot code-built / kit-box pipeline** plus a **volumetric GLB that cannot be used as a facade**. Next step should be **A (Blender environment assembly)** or **C (dedicated environment artist)**. Tripo / photogrammetry are optional later; they are not required to explain this result.

## Reference Set

See `docs/SHOPPING_REFERENCE_COVERAGE_AND_VISUAL_AUTHORITY_V1.md`.

30 exterior + 13 interior Street View stations, 32 photo stills, 260 PNG frames (~517 MB) **not imported** (`.gdignore`). Authority is Street View parking + night entrance + skyline stills. Interior timber vault was **not** rebuilt (gameplay interior preserved).

## Selected Authority Frames

| Role | Path | In-game grade |
|---|---|---|
| Parking center | `streetview/EXTERIOR/EXTERIOR_STATION_001_ESTACIONAMIENTO_MEDIO_01/contact_sheet.jpg` | **POOR** composition vs 02_parking_wide (kit boxes, weak car read) |
| Street / facade | `EXTERIOR_STATION_016_OUTSIDE_FRONT_1/contact_sheet.jpg` | **POOR** — terracotta mass exists, not SDS silhouette |
| Night entrance | `EXTERIOR_STATION_034_EXTERIOR_FRONT_SPHERE_NIGHT/contact_sheet.jpg` | **PARTIAL** — glowing glass + cream piers + `SHOPPING del SOL` |
| Night plaza + towers | `photos/references/unnamed.webp` | **POOR** — cheap labeled boxes, not those towers |
| Interior hall | `photos/references/shopping-del-sol.jpg` | **N/A** this sprint (gameplay plaza kept) |

Spawn pixel sample (`01_spawn.png`, 1920×1080): ~39% night-sky, ~5% light vehicle, ~3% terracotta, palms/zombies present. That is an **outdoor night parking composition**, not a black void. It is still greybox art.

## Shell Alignment

GLB `shopping_del_sol_exterior_v01.glb` native AABB ~99.4 × 15.2 × 52.1 m. Direct children include `SDS_MainBuilding`, 24 wings, two 56×56 pavilions, plus facade/glass/canopy modules.

Attempts this sprint:

1. Uniform scale as a volume → parking swallowed / house-sized.
2. Non-uniform slab `0.36 / 0.05` → remaining unnamed roofs/canopies still covered spawn.
3. Hide volumes + clip world Z to a 6–12 m facade band → remaining visible AABB **85.7 × 30.8 × 5.8 m** with source UVs that read as giant tiles.
4. **Final:** keep the node loaded (`shell_loaded=true`, markers, tests) and **hide `_inst`**. Readable facade is **code-built terracotta + glass arch + sun disc**.

The GLB is a **volumetric mall**, not a facade plate. Using it at readable scale puts parking inside the building. That is a shell-quality / workflow limit, not a missing-reference limit.

## Parking Reconstruction

- Combat/nav asphalt still ~48×34 m (pathing unchanged).
- Visual lot ~78×52 m plus side pads and street edge toward +Z.
- Center dashed two-lane aisle; stall lines L/R; outer row.
- Curbed grass islands + palms on a grid (not a forest).
- Tan plaza tiles + dark bands + crosswalk at the doors.
- Low curb boundaries instead of a 2.4 m brown box wall.
- Distant non-colliding cars / street lamps for scale.

## Vehicle Assets

Hilux FBX **USED_REFERENCE only**. VAZ scan too large. Runtime: shared sedan / SUV / pickup in `zombies_visual_kit.gd`, ~24 instances, mixed colors, collision only on combat-pad cars. Distant cars: no collision.

Box cars do not read as a busy SDS lot in wide shots (`02_parking_wide` car_white ≈ 0.1%). Silhouette density is there; fidelity is not.

## Parking Assets

PSX industrial pack **USED_RUNTIME** on service edges. Lamps/islands/curbs are kit meshes with shared materials.

market-al-danube remains **USED_REFERENCE** (FBX + H&M art; no Blender GLB extract this sprint).

## Vegetation

Palms (frond ring) on aisle islands; leafy trees on outer islands. Rhythm from station 001. They read as low-poly props, not SDS landscaping.

## Lamps

Tall grey poles, **double-arm** heads, warm Omni pools. Present; not photographic.

## Main Entrance

Glass pane, cream piers + canopy, gold sun disc, `SHOPPING del SOL`, dual Omni + facade spots. Buyable door **1500** unchanged. Prompt `[E] ABRIR SHOPPING`.

`04_main_entrance_locked.png`: cream/glass center, terracotta wings, palms — **PARTIAL** landmark. Not the real arched atrium.

Interior roof was shortened so it does not cover parking (`z` max ~7.2 m).

## Background Skyline

Cheap towers with window emission, blue strip, red vertical, `ibis` / `BYSPANIA` labels. Location cues, not architecture.

## Lighting

Night **operating mall**: sky `#2a3854`, ambient 1.05, exposure 1.28, moon 0.42, fog 0.0035. Not abandoned black. Entrance is the brightest object. Zombies stay readable (green cloth + eyes).

## Visual Match Captures

`docs/generated/zombies_visual_v4/`

| Shot | Grade | Notes |
|---|---|---|
| 01_spawn / spawn_reference_match | PARTIAL | Night sky + lot + glow entrance. Box art. Cars weak. |
| 02_parking_wide | POOR | Overhead-ish; green islands yes; cars do not read. |
| 03_facade | PARTIAL | Terracotta + sky. Not SDS facade language. |
| 04_main_entrance_locked | PARTIAL | Glow + glass + sign. No real arch identity. |
| 05_combat_parking | POOR | Weak car/lamp read. |
| 06_main_entrance_open | PARTIAL | Door open, glass, gameplay intact. |
| 07_transition_inside | PARTIAL | Plaza threshold. |
| 08_interior | POOR vs timber vault | Gameplay plaza, not SDS hall. |
| 09_night_lighting | PARTIAL | Warm lamps, not black crush. |
| 10_reference_match | POOR vs Street View | Same spawn language, not a match. |

## Remaining Differences

- No photogrammetry / no artist-assembled blockout of the real lot.
- GLB unused visually (hidden after clip).
- Palms are box fronds; cars are kit boxes.
- No real SDS logo bitmap (Label3D only).
- Interior still code-built terracotta plaza.
- Tenant brands from Street View not reproduced (intentional).

## Performance

Shared materials/meshes. Unique textures walked on ZombiesMain: **5**. MeshInstances ~1129 (kit boxes). Video mem ~517 MB plateau in the D3D12 harness (includes 4K track atlas still resident in ResourceCache after Track scenes). Street View not loaded.

## Human Review

F6 `scenes/zombies/ZombiesMain.tscn`. First 10 seconds: “is this Shopping del Sol?” Expected honest answer: **mall-parking-at-night prototype, not SDS.**

Then: fight, 1500 door, walk in, GALERÍA, SMG, MAX AMMO, die.

Pacing logs: `[ZOMBIES_PACING] mark=750|1000|1250|1500`. Cost **not** changed.

## Pipeline experiment — what failed

| Candidate limit | Verdict |
|---|---|
| Insufficient references | **No.** 30+13 stations + photos were inventoried and classified. |
| Asset quality | **Partial.** Usable cars were FBX/scans too heavy; kit boxes replaced them. |
| Shell quality | **Yes.** Volumetric GLB fights parking scale; source UVs tile badly. |
| Godot workflow | **Yes.** Code-built BoxMesh + triplanar 32² is the entire exterior language. |
| Procedural/code-built art | **Yes — primary.** More boxes do not become SDS. |
| Cursor visual-spatial | **Contributing.** Camera/GLB overlaps were iterated; composition improved; fidelity did not. |
| Lighting/material pipeline | **Secondary.** Night operating look is OK; materials still collapse to tiles. |
| Gameplay preservation | **Not the blocker.** Nav/door/spawns were kept; visuals were free to change. |

Recommended next: **A** Blender assembly of parking+facade from the same references, exported as a **thin visual-only** GLB (no gameplay collision), **or C** an environment artist. Do not spend another sprint adding code-built props and calling it SDS.
