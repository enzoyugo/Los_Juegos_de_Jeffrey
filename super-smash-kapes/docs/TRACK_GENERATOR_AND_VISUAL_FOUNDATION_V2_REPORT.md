# TRACK GENERATOR AND VISUAL FOUNDATION V2

## Primary verdict

**TRACK_OVERNIGHT_V1_READY_FOR_HUMAN_REVIEW**

Also: **TRACK_GENERATOR_V2_READY_FOR_HUMAN_REVIEW**

Additive procedural assembler over the existing modular GLB kit. Validate → reject → retry until accept or 40 attempts. Three frozen PICANTE showcases all **ACCEPTED** on attempt 0. Shared asphalt / shoulder / rail materials now use tiled `NoiseTexture2D` (256) without per-piece maps. Same-process boost Area3D rearm after `reset_to` is **3/3**. TrackMain still uses greybox `TrackGenerator`. `CONTROLLER_MODE` stays **BASELINE**. Wheel handling constants stay frozen. No 90° / chicane / jump / ramp pieces in random generation.

Owner still drives `TrackGeneratorV2Lab` for scale, curve rhythm, and material read. This report does not claim photoreal road art or production TrackMain cutover.

## Baseline (unchanged)

| Item | Value |
|---|---|
| Godot | 4.7.2.stable.official |
| Canonical controller | `CONTROLLER_MODE := "BASELINE"` |
| 4WHEEL | lab / boost-reset only; not promoted |
| Handling | `track_wheel_physics_config.gd` frozen (springs 32000, front grip 9200, yaw assist 420, COM `(0,-0.12,0.06)`) |
| TrackMain | still old greybox `TrackGenerator` |
| Kit GLBs | still **11** under `assets/track/modules/generated/core/` |
| V6 jump lab defaults | not retuned (rearm call only after `reset_to`) |

## Architecture

New files only. V1 greybox generator is untouched.

| File | Role |
|---|---|
| `scripts/track/track_generator_v2.gd` | `class_name TrackGeneratorV2`. `generate(seed, length, difficulty)` |
| `scripts/track/track_generator_v2_validator.gd` | Simulated pose + AABB validation, no scene tree |
| `scripts/track/track_generator_v2_lab.gd` | Assemble accepted kit, BASELINE car, HUD |
| `scenes/debug/TrackGeneratorV2Lab.tscn` | Human + `SSK_GEN_SMOKE=1` |
| `data/track/generator_v2_showcases.json` | Frozen seeds + sequences |
| `scripts/debug/smoke_track_generator_v2.gd` | Headless parse + three showcases |
| `scripts/debug/track_boost_reset_lab.gd` | Same-process 3× boost |
| `scenes/debug/TrackBoostResetLab.tscn` | `SSK_BOOST_RESET_SMOKE=1` |
| `tests/test_track_generator_v2.py` | Static locks |

### API

```
func generate(seed_value: int, length_id: String, difficulty_id: String) -> Dictionary
```

Length aliases: `SHORT` / `corta` / `MEDIUM` / `media` / `LONG` / `larga` (any case).  
Difficulty aliases: `TRANQUI` / `PICANTE` / `DEMENTE` and `track_config` lowercase ids.

Length and difficulty are independent.

Retry: `rng.seed = seed * 10007 + attempt * 17`, max **40**. Fail returns `accepted=false`, `validation_result="fail"`, accumulated `rejection_reasons`. Lab does **not** assemble a rejected sequence.

Logging:

```
[TRACK_GENERATOR_V2] seed=... attempt=... length=... difficulty=... pieces=... path_m=... turns=... elev=... reject=...
[TRACK_GENERATOR_V2] ACCEPTED
```

### Allowed kit (GLBs exist)

| piece_id | Role tonight |
|---|---|
| `start` | 8 m, required first |
| `finish` | 8 m, required last |
| `straight_medium` | 24 m recovery / body |
| `curve_l_45` / `curve_r_45` | ~23.56 m, yaw ±45° |
| `boost_straight` | 12 m, allowed in random gen |
| `landing_straight_long` | 36 m long straight, **not** a jump landing |

Forbidden in the V2 pool: `ramp_*`, `jump_*`, `gap_logical`, and kit IDs with **no GLB** (`straight_short`, `straight_long`, `curve_*_90`, chicanes, hairpins, slopes).

Assembly uses existing `TrackPiece.tscn` + `align_entry_to` like the modular kit pilot. Validation simulates `world_entry = cursor`, `world_exit = cursor * local_exit` from sidecar `meta.exit` **before** instantiate.

### Length bands (path estimates, ~28 m/s, not timing-fit)

| Length | Path | Pieces (incl. start/finish) |
|---|---|---|
| SHORT | 220–340 m | 8–14 |
| MEDIUM | 480–650 m | 16–24 |
| LONG | 840–1120 m | 26–40 |

## Validation

Reject reason strings:

| Code | Meaning |
|---|---|
| `SEAM_POS` / `SEAM_ROT` | Sequential exit→entry must be ~0 (simulated composition is tautological; lab also measures instanced seams) |
| `OVERLAP` | Non-neighbor collision-box AABBs overlap beyond ~5 cm (neighbors allowed for seams) |
| `SELF_CROSS` / `HEADING` | Same spatial fail; no bridges |
| `ELEVATION` | `|Y| > 8 m` (all kit pieces tonight are flat) |
| `DRIVEABILITY` | No immediate opposite 45 after 45; min 1 straight after two consecutive curves; min 1 straight before finish |
| `VARIETY` | No 4+ identical `piece_id` in a row; no all-straights; no >3 consecutive same-direction curves |
| `START/FINISH` | Must begin `start`, end `finish` |
| `NO_STUNT` | Sequence must not contain ramp/jump/gap ids |
| `DIFFICULTY` | TRANQUI curve fraction ≤ ~36% and no consecutive curves, boost rare; PICANTE ~33–57%; DEMENTE ~43–72% |
| `LENGTH` | Path/piece count outside the band |

Composer already enforces driveability and spatial trial placement so most seeds accept on attempt 0. Validator remains the authority.

## Frozen showcase seeds

All PICANTE. Variety over difficulty purity. All **ACCEPTED** attempt 0.

### SHORT_SHOWCASE — seed **11**

- 14 pieces, ~326 m, 5 turns
- `start, straight_medium, curve_l_45, straight_medium, curve_l_45, straight_medium, curve_r_45, curve_r_45, landing_straight_long, landing_straight_long, straight_medium, curve_r_45, straight_medium, finish`

### MEDIUM_SHOWCASE — seed **21**

- 21 pieces, ~529 m, 7 turns
- `start, straight_medium, curve_r_45, curve_r_45, straight_medium, curve_l_45, landing_straight_long, straight_medium, straight_medium, landing_straight_long, landing_straight_long, curve_l_45, landing_straight_long, curve_l_45, landing_straight_long, curve_r_45, landing_straight_long, boost_straight, curve_l_45, straight_medium, finish`

### LONG_SHOWCASE — seed **31**

- 40 pieces, ~994 m, 13 turns
- `start, curve_r_45, straight_medium, landing_straight_long, curve_r_45, curve_r_45, straight_medium, landing_straight_long, straight_medium ×3, curve_l_45, boost_straight, landing_straight_long, curve_l_45, curve_l_45, straight_medium, curve_r_45, straight_medium, straight_medium, curve_r_45, straight_medium, straight_medium, curve_l_45, straight_medium, landing_straight_long, curve_r_45, straight_medium, landing_straight_long, landing_straight_long, straight_medium, boost_straight, landing_straight_long, curve_l_45, straight_medium, curve_r_45, curve_r_45, straight_medium, landing_straight_long, finish`

Authority: `data/track/generator_v2_showcases.json`. Smoke: `docs/generated/track_generator_v2/smoke.json`.

## Materials (first pass, not photoreal)

Same `resource_path` so `TrackPiece._apply_shared_materials` still matches `Registry.ASPHALT` / `SHOULDER` / `GUARDRAIL`.

| Resource | Look |
|---|---|
| `track_asphalt_v1.tres` | Darker grey-blue, roughness **0.85**, 256 NoiseTexture2D, `uv1_triplanar=false` |
| `track_shoulder_v1.tres` | Distinct tan/ochre so 0.7 m shoulders read vs 11 m asphalt |
| `track_guardrail_v1.tres` | Lighter metal, metallic ~0.38 |
| `track_marker_v1.tres` | Left yellow |

No unique per-piece 4K maps. No collision or GLB mesh edits. UV continuity stays longitudinal-meter; albedo noise tiles.

## Boost reset

Known issue: in-process `JUMP_RUNS>1` did not re-fire Area3D `body_entered`.

Fix (minimal):

1. `TrackPiece.rearm_boost_trigger()` — `monitoring=false` then `set_deferred("monitoring", true)`. Boost strength unchanged.
2. `track_jump_trajectory_lab.gd` `_reset_for_next_run` only: after `car.reset_to`, loop pieces and rearm. V6 defaults/HUD untouched.
3. `TrackWheelCar.reset_to`: still clears `boost_active` / `_boost_timer`; now also increments `boost_generation`. `apply_track_boost` magnitude unchanged.

`TrackBoostResetLab`: `start + boost_straight + finish`, 4WHEEL, scripted throttle, 3 in-process `reset_to` runs.

**Result: `TRACK_BOOST_RESET_OK` 3/3.** All three `BOOST_ENTRY` via `body_entered`. Audit: `docs/generated/track_boost_reset/audit.json`.

Do **not** pass `--quit-after 600` on this lab; 600 is frames and can cut run 3. The lab quits itself under `SSK_BOOST_RESET_SMOKE=1` or headless.

## Lab — TrackGeneratorV2Lab

- Assembles **accepted** tracks only with `TrackPiece.tscn`
- BASELINE `TrackCar.tscn`. Does **not** read/set `SSK_TRACK_CONTROLLER=4WHEEL`
- Keys: **1** SHORT_SHOWCASE, **2** MEDIUM, **3** LONG, **T** cycle difficulty then regenerate current seed, **R** new seed, **G** next seed, **F4** collision debug, **C** reset, **F3** HUD
- HUD: seed, length, difficulty, piece count, path, accept/fail reasons, controls
- Chase cam: existing `track_camera.gd`
- Environment: sun + grey-blue sky color
- `SSK_GEN_SMOKE=1`: generate all 3 showcases, write smoke JSON, print `ACCEPTED`, quit 0

## Smoke

Generator (PowerShell `;` not `&&`). Set `SSK_GEN_SMOKE=1`:

```
E:\Godot_v4.7.2-stable_win64_console.exe --path e:\SuperSmashKapes\super-smash-kapes --headless --display-driver headless --rendering-driver d3d12 --rendering-method forward_plus --audio-driver Dummy --quit-after 600 res://scenes/debug/TrackGeneratorV2Lab.tscn
```

Result tonight: three `ACCEPTED`, no `SCRIPT ERROR`. Parse-check also loaded generator, validator, both labs, `track_piece.gd`, `track_wheel_car.gd`, `track_jump_trajectory_lab.gd`.

Boost:

```
$env:SSK_BOOST_RESET_SMOKE="1"
E:\Godot_v4.7.2-stable_win64_console.exe --path e:\SuperSmashKapes\super-smash-kapes --headless --display-driver headless --rendering-driver d3d12 --rendering-method forward_plus --audio-driver Dummy res://scenes/debug/TrackBoostResetLab.tscn
```

Pytest: `tests/test_track_generator_v2.py` + modular-kit material lock update — **passed**.

## Human F6

1. Open `scenes/debug/TrackGeneratorV2Lab.tscn` (not TrackMain).
2. Confirm HUD shows seed 11 / SHORT / PICANTE and **BASELINE**.
3. Drive: 11 m asphalt should read darker grey-blue; 0.7 m shoulders ochre; rails lighter metal.
4. Press **2** then **3** for MEDIUM/LONG showcases. F4 for collision boxes. T/R/G as needed.
5. Optional: `TrackBoostResetLab.tscn` — watch three boost pulses after in-process resets.
6. Do **not** expect jumps, 90° pieces, or 4WHEEL as default.

## Remaining blockers

- TrackMain is still greybox V1. V2 is lab-only until a later cutover.
- Kit has no 90° / chicane / short/long straight GLBs, so rhythm is 45° + 12/24/36 m straights only.
- No elevation / stunt pieces in random gen (by design tonight).
- Materials are toy-arcade noise, not a shared photoreal atlas.
- `--quit-after N` is **frames** in Godot 4.7; boost lab must self-quit.
- Parent still needs to merge `validate_jeffrey_shell.gd` / `scan_resource_paths.py` for new scenes.

## Suggested validator tokens (parent)

```
TRACK_GENERATOR_V2
TRACK_GENERATOR_V2_ACCEPTED
TRACK_GENERATOR_V2_LAB
TRACK_GENERATOR_V2_SHOWCASES
TRACK_ASPHALT_NOISE_V1
TRACK_SHOULDER_NOISE_V1
TRACK_GUARDRAIL_NOISE_V1
TRACK_BOOST_RESET_OK
TRACK_BOOST_REARM
CONTROLLER_MODE_BASELINE
TRACK_MAIN_STILL_V1
TRACK_KIT_GLB_COUNT_11
```

Optional fail tokens: `TRACK_GENERATOR_V2_REJECT`, `TRACK_BOOST_RESET_PARTIAL`.
