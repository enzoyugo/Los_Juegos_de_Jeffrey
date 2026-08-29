# Track 4WHEEL generator + procedural consolidation V4

## Primary Verdict

**TRACK_4WHEEL_GENERATOR_V4_READY_FOR_HUMAN_REVIEW**

`TrackGeneratorV2Lab` is now a 4WHEEL proving ground. Default controller is **4WHEEL**. F2 toggles BASELINE on the **same** seed/sequence. TrackMain is unchanged: `CONTROLLER_MODE := "BASELINE"`. Generator V4 was **not** promoted to TrackMain.

## Why Generator Lab Was BASELINE

`GENERATOR_LAB_BASELINE_REASON=C+I`

Not a 4WHEEL physics/module blocker.

- **C:** `track_generator_v2_lab.gd` historically hardcoded `TrackCar.tscn` (`BASELINE_SCENE_PATH`) and never instantiated `TrackCarWheelPhysics.tscn`.
- **I:** Canonical firewall. Production TrackMain stays BASELINE. Lab-only 4WHEEL is allowed.

Ruled out as the original cause: D (cannot traverse modules), E (reset missing), F (boost incomplete), G (camera mismatch), H (performance). Those were later lab-integration items, not why the default was BASELINE.

## 4WHEEL Integration

Lab loads `res://scenes/track/TrackCarWheelPhysics.tscn` when `_mode == "4WHEEL"`. Camera uses `camera_target()`. Boost feedback is shared. Reset recreates no mixed chassis state.

D3D12 lab boot log:

`CONTROLLER=4WHEEL (TrackMain remains BASELINE)`

## Controller Toggle

- **F2:** 4WHEEL ↔ BASELINE
- Same seed, same generated sequence, same spawn, same difficulty/length
- Despawn/recreate car, reset boost triggers, timer, offtrack checkpoint
- HUD: `CONTROLLER 4WHEEL` / `CONTROLLER BASELINE`

## Module Compatibility

`scenes/debug/Track4WheelModuleCompat.tscn` (scripted throttle, steer 0, D3D12).

`[TRACK_4WHEEL_COMPAT] PASS` — every listed module `entered=true`, `completion=true`, `rail_hit=false`, `offtrack=false`.

| Module | entered | exited | notes |
|---|---|---|---|
| start / finish / straight_short | yes | yes | spawn drop settle |
| straight_medium / long | yes | no (1.6s window) | not a geometry fail |
| curve 45 / 90 | yes | no | steer=0; yaw/roll small |
| chicane lr/rl | yes | no | no rail hit |
| boost_straight | yes | no | pulse fired |
| slope_up / crest / slope_down | yes | no | contacts after settle |

`airborne_unintended=true` and `wheel_contacts_min=0` on **all** rows because spawn starts in `RESET_SETTLE` (car drops onto the piece). That is not a rail launch. Human F6 still owns 90°/chicane *steering* feel.

Peak D3D12 static during matrix: ~84.5 MB. No `0x8007000e`.

## 90 Degree Test

Automated: 4WHEEL enters `curve_l_90` / `curve_r_90` without rail hit. Scripted steer is 0, so this is structural (no snag / no invisible wall), not a full racing line.

Human: enter at low / nominal / high reasonable speed. Do not retune grip if the only issue is entering too fast.

## Chicane Test

Automated: `chicane_lr` / `chicane_rl` entered, no rail hit, no chassis snag in 1.6s throttle. Human: centered entry, moderate speed, L-R transition.

## Boost 4WHEEL

`SSK_BOOST_GEN_SMOKE=1` on `TrackGeneratorV2Lab` (default 4WHEEL, sequence `start → straight_medium → boost_straight → straight_medium → finish`):

`[TRACK_BOOST_GEN] PASS apply=3 hits=3`

Each hit: `BOOST APPLY controller=4WHEEL mag=1.35 speed≈24.7`. Pulse ends (`BOOST_PULSE_END t=0.850`). Drive cap while boosted is `MAX_SPEED * 1.22` (`track_arcade_wheel.gd` `drive_cap`). Consecutive boost pieces are now rejected (`CONTROLLER_COMPAT`).

## Generator Architecture Before

Random full sequence → validate whole track → discard. Empty candidates were logged as `START/FINISH`. MEDIUM/LONG often burned 40 attempts on OVERLAP / SELF_CROSS / HEADING / DIFFICULTY / LENGTH.

## Incremental Composer

For each next piece: legal candidates → cheap difficulty/heading weights → local occupancy grid (10 m cells) → reject overlap / 3D crossing immediately → append.

`CONTROLLER_COMPAT`: straight after boost (not another boost, not 90/chicane/elevation); chicane needs a straight approach.

## Backtracking

If no legal piece: pop 1–3, try another branch. Inner guard 48. Consecutive failed backtracks cap at 5, then that attempt is `COMPOSE_EMPTY` (skipped, **not** counted as START/FINISH). Top-level `MAX_ATTEMPTS` remains 40 (`seed * 10007 + attempt * 17`).

## Batch Acceptance Metrics

100 seeds × 9 configs (seeds 1000–1099). File: `docs/generated/track_generator_v4/batch_metrics.json`.

| Config | success | median attempt | p95 attempt |
|---|---|---|---|
| SHORT TRANQUI | 100% | 0 | 1 |
| SHORT PICANTE | 100% | 0 | 1 |
| SHORT DEMENTE | 100% | 0 | 1 |
| MEDIUM TRANQUI | 100% | 0 | 4 |
| MEDIUM PICANTE | 100% | 0 | 3 |
| MEDIUM DEMENTE | 100% | 0 | 3 |
| LONG TRANQUI | 100% | 2 | 9 |
| LONG PICANTE | 100% | 2 | 7 |
| LONG DEMENTE | 100% | 1 | 7 |

**900/900 accepted.** No config 40/40 fail. LONG p95 is the remaining cost of empty inner composes; still ≪ 40.

Frozen lab showcases (regenerated, vocabulary union still valid):

| | Seed | Diff | Pcs | Path |
|---|---|---|---|---|
| SHORT | **12** | PICANTE | 12 | 251.3 m |
| MEDIUM | **25** | PICANTE | 25 | 494.9 m |
| LONG | **31** | DEMENTE | 35 | 845.5 m |

## Offtrack Behavior

Arcade policy in the lab (not TrackMain):

- Road: normal
- Shoulder: grip/drag penalty; delayed reset
- Grass `StaticBody3D` tagged `offtrack` at y≈−0.48 (driveable, not visual-only void)
- Far from track (`FAR_M=38`) or below (`FALL_Y=−8`) or prolonged offtrack (~2.8 s): reset to last **safe checkpoint** (all wheels grounded, on road, speed sane)

Does not reset on a single shoulder kiss.

## Elevation Modules

JSON + procedural boxes only (kit GLB count stays **17**):

- `slope_up_gentle` (~24 m, +1.44 m)
- `slope_down_gentle`
- `crest_gentle`

No intended airborne. Max cumulative height 8 m. Consecutive elevation limited. Banked 45 curves were a stretch goal and were **not** shipped.

## Warning Cleanup

Active sprint:

- `compression_m(rest_m, …)` replaces rest_length shadowing
- `COMPOSE_EMPTY` no longer mislabeled START/FINISH
- `boxes_overlap` restored (was accidentally merged into `y_ranges_overlap`)
- Integration lab `look_at` after `add_child`

Legacy Track warnings (V1 generator, old labs) left untouched.

## Tests

- pytest: **337 passed**
- path scan: missing=0
- generator smoke showcases: ACCEPTED 12 / 25 / 31
- `[TRACK_4WHEEL_COMPAT] PASS`
- `[TRACK_BOOST_GEN] PASS apply=3 hits=3`
- `[JEFFREY_VALIDATE] OK`
- D3D12: TrackGeneratorV2Lab, TrackJumpTrajectoryLandingLab, TrackMain — no `0x8007000e`

## Human Review

F6 `scenes/debug/TrackGeneratorV2Lab.tscn`

Expected HUD: **CONTROLLER 4WHEEL**, seed, length, difficulty, BOOST, OFFTRACK.

1 / 2 / 3 = SHORT / MEDIUM / LONG. **F2** = BASELINE comparison (same track). **C** reset.

Questions: 90s, chicanes, boost into next curve, grass slow/reset, gentle slopes, generation reliability.
