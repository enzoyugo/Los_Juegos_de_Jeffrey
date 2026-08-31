# Jeffrey Gameplay / Physics QA Baseline V1

Date: 2026-08-31

## Scope

Bounded QA of existing Track/Hotseat, Smash Kapes, Zombies, and shared session/input logic. Existing dirty work is preserved; no reset, clean, stash, revert, or checkout was used.

## Repository baseline

| Item | Baseline |
|---|---|
| Branch | `main` |
| HEAD | `edd64c9cdfab581a09f36ca445406516dfbbdeb1` |
| Working tree | Dirty with pre-existing generated/imported files; untouched by this QA pass |
| Remote | `origin` = `https://github.com/enzoyugo/Los_Juegos_de_Jeffrey.git` |
| Godot | Existing project authority is Godot 4.7.2; executable path requires rediscovery on this host |
| Blender | 5.2.1 LTS available |

## Authoritative gameplay files

Track: `scripts/track/track_car_controller.gd`, `track_handling.gd`, `track_config.gd`, `track_fuel_system.gd`, `track_hotseat_v2.gd`, `track_checkpoint.gd`, `track_race.gd`, `track_ghost_player.gd`, `track_ghost_recorder.gd`.

Smash: `scripts/combat/attack_definition.gd`, fighter/controller/combat scripts, `scripts/stages/jeffrey_smash_stage_base.gd`, and existing Smash debug labs.

Zombies: `scripts/zombies/zombies_player.gd`, `zombies_enemy.gd`, `zombies_game_state.gd`, `zombies_waves.gd`, `zombies_main.gd`, and existing vertical-slice/debug labs.

Shared: `scripts/core/jeffrey/active_session.gd`, `copa_jeffrey_session.gd`, pause/results UI, and existing lifecycle/rematch harnesses.

## Existing QA entry points

`scripts/debug/validate_jeffrey_shell.gd`, `scripts/debug/smoke_track_4wheel_module_compat.gd`, `scripts/debug/track_drift_lab.gd`, `scripts/debug/zombies_systems_lab.gd`, `scripts/debug/rematch_resource_stability.gd`, and the mode-specific pytest suites under `tests/`.

## Initial observations

- Track vehicle logic is already isolated in `_physics_process`, uses delta-scaled handling, reset clears velocity and drift state, and exposes debug telemetry.
- Track fuel is per-player and clamped at zero; Last Dance/finish authority is in the hotseat/session logic.
- Ghost playback is a visual node rather than a physics controller in the existing validation harness.
- No fix is authorized from static inspection alone; each issue must be reproduced by a targeted test or runtime harness before editing.
