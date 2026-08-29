# CANONICAL_RUNTIME_AUTHORITY

Last updated with **JEFFREY_FULL_GAME_CANONICALIZATION_AND_TRACK_MENU_V1**.

## Shell

| Item | Authority |
|------|-----------|
| Boot scene | `res://scenes/core/JeffreyBoot.tscn` → `JeffreyApp` |
| Flow | Boot → Players Today → Hub → Mode |
| Hub | `scripts/ui/jeffrey/hub_screen.gd` |
| Transitions | `mode_transition_controller.gd` / Zombies loading screen |
| Status | **PRODUCTION** |

## Smash

| Item | Authority |
|------|-----------|
| Host | `scenes/core/Main.tscn` hosted by shell |
| Fighters | `FighterCatalog` — terere, jaguarete, cartes, fort, pajaro_campana |
| Stages | `StageCatalog` — defensores, palacio, costanera |
| Fort production GLB | `fort_stylized_v1.glb` (**INTERIM**) |
| Fort V2 | `fort_stylized_v2_candidate.glb` — **EXPERIMENTAL** (`SSK_FORT_V2_CANDIDATE=1` only) |
| Stage visuals | Palacio/Costanera Blender visual GLBs under `ArtRoot` (collision unchanged) |
| Status | **PRODUCTION gameplay / INTERIM human art** |

## Track

| Item | Authority |
|------|-----------|
| Menu | `scripts/ui/jeffrey/track_menu_screen.gd` + `assets/ui/track/menu_v1/` |
| Race host | `scenes/track/TrackMain.tscn` |
| Length | `TrackConfig` corta/media/larga |
| Difficulty | `TrackConfig` tranqui/picante/demente (UI: FÁCIL/NORMAL/DIFÍCIL) |
| Generator | `track_generator.gd` procedural |
| Cars | production TrackCar + current El Gallo / Chick Hicks character cosmetics |
| Status | **PRODUCTION** (menu V1 + procedural race) |

## Zombies

| Item | Authority |
|------|-----------|
| Menu | `scripts/ui/jeffrey/zombies_menu_screen.gd` |
| Host | `scenes/zombies/ZombiesMain.tscn` |
| Map | Shopping del Sol current stable path in ZombiesMain |
| Status | **PRODUCTION** (latest verified stable, not newest lab) |

## Labs / candidates (non-default)

- `scenes/debug/*`
- `SSK_FORT_V2_CANDIDATE`, `SSK_TRACK_CONTROLLER`, `SSK_USE_SEMANTIC_V2_CANDIDATE`, etc.
- ActorCore / semantic labs for Tereré/Jaguareté candidates

Do **not** route Hub defaults through labs.
