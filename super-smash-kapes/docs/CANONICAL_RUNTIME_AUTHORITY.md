# CANONICAL_RUNTIME_AUTHORITY

Last updated with **JEFFREY_OVERNIGHT_TOTAL_RUNTIME_REPAIR_AND_POLISH_V1**.

Evidence: headless TrackMain smoke `articulated_wheel_binds=4`, Costanera stage parse OK, Hub modes playable.

## Shell

| Item | Authority |
|------|-----------|
| Boot scene | `res://scenes/core/JeffreyBoot.tscn` → `JeffreyApp` |
| Flow | Boot → Players Today → Hub → Mode |
| Hub | `scripts/ui/jeffrey/hub_screen.gd` |
| Mode players | `mode_player_select_screen.gd` — card toggle is selection authority |
| Options | `options_screen.gd` |
| Transitions | `mode_transition_controller.gd` / Zombies loading screen |
| Mode registry | Smash / Track / Zombies all `AVAIL_PLAYABLE` + enabled |
| Status | **PRODUCTION** |

## Smash

| Item | Authority |
|------|-----------|
| Host | `scenes/core/Main.tscn` hosted by shell |
| Fighters | `FighterCatalog` — terere, jaguarete, cartes, fort, pajaro_campana |
| Stages | `StageCatalog` — defensores, palacio, costanera |
| Stage KO contract | `jeffrey_smash_stage_base.gd` `show_ko` / `show_final_ko`; M0Playground guards with `has_method` |
| Fort production GLB | `fort_stylized_v1.glb` (**INTERIM**) |
| Fort V2 | `fort_stylized_v2_candidate.glb` — **EXPERIMENTAL** (`SSK_FORT_V2_CANDIDATE=1` only) |
| Stage visuals | Palacio/Costanera Blender visual GLBs under `ArtRoot` (collision unchanged) |
| Pause | `kapes_pause_overlay.gd` |
| Status | **PRODUCTION gameplay / INTERIM human art** |

## Track

| Item | Authority |
|------|-----------|
| Menu | `scripts/ui/jeffrey/track_menu_screen.gd` + `assets/ui/track/menu_v1/` |
| Race host | `scenes/track/TrackMain.tscn` |
| **Vehicle (default)** | `scenes/track/TrackCarWheelPhysics.tscn` + `track_wheel_car.gd` + articulated visual |
| Visual GLB | `assets/vehicles/track/processed/track_car_base_v3_articulated_clean.glb` |
| Baseline fallback | `TrackCar.tscn` via `SSK_TRACK_CONTROLLER=BASELINE` |
| Length | `TrackConfig` corta/media/larga |
| Difficulty | `TrackConfig` tranqui/picante/demente (UI: FÁCIL/NORMAL/DIFÍCIL) |
| Generator | `track_generator.gd` procedural |
| HUD / pause | `track_hud.gd` + `track_hud_chrome_v1.gd` |
| Status | **PRODUCTION** (4-wheel default; menu V1; procedural race) |

## Zombies

| Item | Authority |
|------|-----------|
| Menu | `scripts/ui/jeffrey/zombies_menu_screen.gd` |
| Host | `scenes/zombies/ZombiesMain.tscn` (group `jeffrey_zombies_host`) |
| Environment | `shopping_del_sol_zombies_environment_v3.glb` via `zombies_map.gd` |
| V4.x candidates | Lab-only under `scenes/debug/` + processed `*_candidate.glb` — **NOT production** |
| Lifecycle | Shell rematch clears hosts via `_clear_mode_hosts` (no orphan `_restart`) |
| Status | **PRODUCTION** (V3 verified stable; V4 candidates need human approval) |

## Labs / candidates (non-default)

- `scenes/debug/*`
- `SSK_FORT_V2_CANDIDATE`, `SSK_TRACK_CONTROLLER=BASELINE`, `SSK_USE_SEMANTIC_V2_CANDIDATE`, etc.
- SDS V4.x Shopping labs

Do **not** route Hub defaults through labs.
