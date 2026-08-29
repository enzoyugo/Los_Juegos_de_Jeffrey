# Zombies Shopping parking + shell V3

## Primary Verdict

**ZOMBIES_SHOPPING_PARKING_V3_READY_FOR_HUMAN_PLAYTEST**

The map starts **outside** in the Shopping del Sol parking lot. Main entrance is buyable (**1500**, `[E] ABRIR SHOPPING`). Interior plaza / galería / wall-buy / rounds / MAX AMMO are unchanged as gameplay authority. Shopping exterior GLB is a **visual shell** (no mesh collision). Raw packs were inventoried; only processed industrial props plus code-built cars/lot were used.

Visual alignment of the large shell vs parking/interior still needs a human F6 look. No PNG captures (headless). That does not block the playable loop.

## New Level Flow

PARKING LOT SPAWN `(0, 0.05, 28.5)` looking toward the facade  
→ early waves in the lot  
→ farm points  
→ buy **SHOPPING** 1500  
→ walk through the doorway into the code-built plaza  
→ existing GALERÍA 1000 → SMG wall-buy → rounds → MAX AMMO → game over

## Raw Asset Inventory

See `docs/SHOPPING_RAW_ASSET_INVENTORY_V1.md`. Source dir `assets/raw_models/` is RAW AUTHORITY (`.gdignore`, not edited destructively). Zips extracted only under `assets/raw_models/_extracted/<id>/`. No license/readme files were present; licenses recorded as **unknown**.

## market-al-danube Analysis

FBX + textures (includes trademark tenant art). Godot Blender import is disabled, so the FBX is not a runtime scene.

Used as **reference only**: lanes parallel to a commercial frontage, curb islands, lamp grid, painted stalls, crosswalk at entrance, lot bounded by fences/walls. Not cloned. H&M (or any) logos not copied.

## Selected Parking Assets

- **USE:** processed `assets/environments/shopping_del_sol/processed/psx_industrial_pack.glb` — crate / barrel / dumpster / container, box collision, pack instance freed after clone.
- **USE (in-tree):** `shopping_del_sol_exterior_v01.glb` visual shell.
- **USE (code-built):** parked + wrecked car proxies, asphalt, curbs, lamps, planters, fences, crosswalk.

## Rejected Assets

| Asset | Verdict |
|---|---|
| ice_scream_3_shopping_center_map | REJECT (unrelated IP, 2821 meshes) |
| portal-gate-sci-fi | REJECT (sci-fi language) |
| wrecked-car GLB | REJECT runtime (BeamNG scatter, ~471 m AABB) |
| vaz_2104 raw scan | REFERENCE_ONLY (~8× scale, 25 MB) |
| cement_bags_low-poly | REFERENCE_ONLY (texture-heavy) |
| market-al-danube FBX | REFERENCE_ONLY |

## Asset Processing

Runtime never depends on zip internals or `_extracted/`. Industrial pack copied to `shopping_del_sol/processed/`. Godot import run for wavs + processed GLB.

## Shopping GLB Source

`res://assets/environments/shopping_del_sol/models/final/shopping_del_sol_exterior_v01.glb` (~351 KB, 5088 tris). Fallback: blockout GLB, then code-built terracotta facade.

## Shopping Scale

Integration lab / ZombiesMain:

`[ZOMBIES_SHELL] loaded=… aabb=(-49.69, -3.61, -21.2) size=(99.39, 15.20, 52.08)`

World AABB after lab scale **0.42**, rot Y **180**, pos `(0, 0, 8.2)`. ~99 m wide × ~15 m tall × ~52 m deep. Parking lot is 48×34 m — shell is wider than the combat pad. Collision on the GLB is stripped (`collision_layer=0`, `COL_` hidden).

## Shopping Orientation

Markers on the shell node: `SHOPPING_CENTER`, `SHOPPING_FRONT`, `MAIN_ENTRANCE`, `WORLD_UP`. Front heuristic uses AABB Z. Human must confirm the facade faces +Z parking.

## Main Entrance

Buyable door at `(0, 0, 8.2)`, cost **1500**, name **SHOPPING**. Prompt `[E] ABRIR SHOPPING`. Glow + `SHOPPING del SOL` Label3D. After purchase: points deducted, shutter hides, nav rebaked, indoor spawn pool enabled, persists for the match.

## Parking Lot Design

`zombies_parking.gd`: 48×34 m asphalt, stall lines, lane arrows, curbs, seven lamps, eight static cars (box collision), planters, fences/barriers, crosswalk, industrial clutter on the service edges. Night-ish env: dark lot, warm facade/lamp light. Zombies stay readable (skin `#6a7a5c` vs asphalt `#2a2c30`).

## Parking Combat Flow

Open center aisle, cover from parked/wrecked cars, multiple approach vectors from 9 parking spawn markers (corners / behind cars / perimeter). Not a maze. Facade is the landmark from spawn.

## Parking Zombie Spawns

Until `shopping_open`: parking pool only. After purchase: mix parking + plaza; gallery after GALERÍA. `spawn_points_for(player_pos)` favors the player’s current act.

## Entrance Purchase

Before: door collision + nav obstacle; interior unreachable. After: unlock, `shopping_opened`, rebake. ZombiesSystemsLab still PASSes door_locked / door_open (gallery door API). Main entrance is the same `ZombiesBuyableDoor` class.

## Exterior-to-Interior Transition

No teleport. Player walks the 5 m doorway into the existing plaza floor. Shell is visual only; gameplay walls remain code-built terracotta.

## Gameplay Interior Preservation

Plaza floors, storefronts (TERERÉ MARKET, CHIPÁ EXPRESS, …), gallery door at `(0,0,-18)` cost 1000, SMG wall-buy, nav bake, rounds — kept.

## Collision

Shell: no mesh collision. Proxies: facade wings, parking fences, car boxes, industrial boxes. Interior: existing StaticBody3D authority.

## Navigation

`PARSED_GEOMETRY_STATIC_COLLIDERS`. Boot: `nav_mode=navigation_mesh polygons=28 shopping_open=false`. After doors, rebake. 28 polys is coarse but pathing worked in systems lab.

## D3D12 Memory

ShoppingZombiesIntegrationLab + ZombiesMain: shell loaded, **no `0x8007000e`**, no invalid RID. Validator peak with extra Track cars ~378 MB static (not the zombies map). ZombiesMain smoke: clean after wav import.

## Weapon Models

Code-built pistol/SMG viewmodels: barrel, grip, magazine, sights, muzzle flash. Not final art. Identifiable silhouettes.

## Zombie Model

Articulated humanoid: head, torso, arms, legs. Walk bob, arm swing.

## Animations

Procedural: chase bob, **WINDUP** 0.28 s (`attack_started`) before damage, attack hold, hit flash, death fade. Not invisible contact damage.

## Damage Feedback

Hit flash `_vignette_pulse = 0.16` then light low-HP vignette (~0.10–0.15), not a persistent full red wash.

## HUD

ROUND large, AMMO large, POINTS high, HP smaller bar. Technical text **F3 only**.

## Audio

`ZombiesAudio` bank (not hardcoded in player): pistol, SMG, zombie attack/hurt/death, player hit, door buy, round start, MAX AMMO, shopping open. Placeholder WAVs under `data/zombies/audio/`. Loader uses imported `AudioStream` or PCM fallback.

## Tests

- pytest 337 passed (includes `test_zombies_shopping_parking_v3.py`)
- `[ZOMBIES_SYSTEMS] ALL_PASS` (fire, reload, kill, door, wall-buy, round, MAX AMMO, feel, crowd, rounds 1–3)
- `[ZOMBIES_VALIDATE] slice_tokens_ok`
- Integration lab: `shell=true spawn=(0, 0.05, 28.5) parking=9 plaza=3`
- Path scan missing=0
- Screenshots: **not captured** (headless)

## Human Review

F6 `scenes/zombies/ZombiesMain.tscn`

Expected: outside, parking, Shopping facade visible, fight, buy entrance 1500, walk in, plaza/gallery loop, SMG, MAX AMMO, die/restart.

Questions: Does the exterior read as Shopping del Sol? Is the lot a lot or a prop dump? Is the door obvious? Does outside→inside feel coherent? Shell clipping? Nav after open? Weapons/zombies better? Damage red quieter? HUD hierarchy?
