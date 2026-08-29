# TRACK GAMEPLAY CONTENT V3

**Verdict: `TRACK_GAMEPLAY_CONTENT_V3_READY_FOR_HUMAN_REVIEW`**

BASELINE remains canonical. 4WHEEL is not promoted. TrackMain is not cut to V2/V3. V3 car, jump geometry, V5 gap, and atlas were not reopened. Handling constants in `track_wheel_physics_config.gd` are unchanged. `CONTROLLER_MODE` stays `BASELINE`.

---

## 1. Boost (hard gate)

Root cause was real: extra accel was applied, then `along` was clamped to `MAX_SPEED` (54). Near top speed the pulse did nothing. Duration was 0.55 s.

BASELINE now:

- Extra accel `ACCEL * BOOST_ACCEL_SCALE * mag` (`0.85`)
- Duration **0.85 s**
- While `boost_active`, cap is `MAX_SPEED * BOOST_OVERSPEED` (**1.22** → 65.88 m/s), not unlimited
- Retrigger ignored while `_boost_timer > BOOST_RETRIGGER_LOCK` (0.08 s)
- Logs `[TRACK_BOOST] APPLY controller=BASELINE mag=... speed=...` and `[TRACK_BOOST] END`

4WHEEL pulse duration matches BASELINE. `apply_central_force` and `ENGINE_FORCE` (6200) are unchanged. No stacking. Existing `[TRACK_4WHEEL] BOOST` lines remain.

Area3D: `boost_area` mask=2, cars layer=2. `rearm_boost_trigger()` unchanged. `body_entered` only (not `body_shape_entered`).

Visual: cyan emissive chevron quads + `MARKER` override on boost pieces via `assets/track/materials/track_boost_v1.tres`. Activation: `TrackCamera.boost_punch`, HUD `BOOST READY / ACTIVE 0.Xs`, brief OmniLight flash (`TrackBoostFeedback`). `CAM_DISTANCE` not retuned.

---

## 2. Boost speed-delta (mandatory evidence)

Lab: `scenes/debug/TrackBoostDeltaLab.tscn`  
Env: `SSK_BOOST_DELTA=1`  
Output: `docs/generated/track_boost_v3/delta.json`

Layout: `start + straight_medium + boost_straight + straight_medium + finish`. BASELINE, scripted throttle=1, steer=0.

| | entry | +0.25 s | +0.50 s | peak |
|---|---|---|---|---|
| **A** (boost off) | 48.26 | 52.48 | 54.00 | **54.00** |
| **B** (boost on) | 48.26 | 65.88 | 65.88 | **65.88** |

**peak_delta = 11.88 m/s** (gate ≥ 4.0). `[TRACK_BOOST_DELTA] PASS`

Generated-track 3×: `SSK_BOOST_GEN_SMOKE=1` on `TrackGeneratorV2Lab`. Sequence includes `boost_straight`. Three `reset_to` + `rearm`. **apply_count=3, hits=3** (not 30). `[TRACK_BOOST_GEN] PASS`  
Output: `docs/generated/track_boost_v3/generated_3x.json`

TrackBoostResetLab 4WHEEL **3/3** `TRACK_BOOST_RESET_OK` still holds.

---

## 3. New kit pieces

```
python scripts/blender/generate_track_kit_v1.py --pieces=straight_short,straight_long,curve_l_90,curve_r_90,chicane_lr,chicane_rl
```

| id | EXIT | notes |
|---|---|---|
| `straight_short` | (0,0,-12) yaw 0 | length **12.0** m |
| `straight_long` | (0,0,-44) yaw 0 | length **44.0** m |
| `curve_l_90` | (-24,0,-24) yaw +90° | radius 24 |
| `curve_r_90` | (+24,0,-24) yaw −90° | radius 24 |
| `chicane_lr` | (0,0,-18) yaw 0 | `x = -4.5 * sin(π t)` |
| `chicane_rl` | (0,0,-18) yaw 0 | sign flipped |

ENTRY at origin. `road_width` 11. Collision present. Original 11 filenames kept. **GLB count = 17.**

Chicane uses many samples (curve-like). End headings forced to 0 so EXIT yaw ≈ 0. Hairpins skipped (stretch).

---

## 4. Generator rhythm V3

Same class `TrackGeneratorV2` (no parallel generator). Pool after pieces exist:

`start, finish, straight_short, straight_medium, straight_long, curve_l_45, curve_r_45, curve_l_90, curve_r_90, chicane_lr, chicane_rl, boost_straight`

`landing_straight_long`: rare, once per track, only as recovery after 90/chicane.

Mini-sections: SPEED / FLOW / TECH / RECOVERY. Rules: no 3+ identical in a row, no opposite 90 without a short/medium, no chicane→chicane, no boost→90.

Length bands (path ~28 m/s): SHORT 210–360 m / 8–16 pcs, MEDIUM 460–680 / 15–26, LONG 820–1160 / 24–42.

### Frozen showcases V3 (all ACCEPTED)

**SHORT_SHOWCASE** — seed **11**, PICANTE, 13 pcs, 244.7 m, 4 turns, attempt 1  
`start, straight_medium, boost_straight, straight_short, curve_l_45, straight_short, chicane_lr, straight_long, curve_r_45, straight_short, curve_r_45, straight_medium, finish`

**MEDIUM_SHOWCASE** — seed **21**, PICANTE, 26 pcs, 515.5 m, 8 turns, attempt 3  
includes `curve_l_90`, `chicane_rl`, `chicane_lr`, `boost_straight`, `straight_short`, `straight_long`, `landing_straight_long` (once)

**LONG_SHOWCASE** — seed **33**, DEMENTE, 36 pcs, 825.8 m, 12 turns, attempt 9  
includes `curve_r_90`, `chicane_rl`, `boost_straight` (2), `straight_short`, `straight_long`

**Union across 3:** 90 ✓, chicane ✓, boost ✓, straight_short ✓, straight_long ✓. Not the old 45-only kit.

Lab keys unchanged: 1/2/3/T/R/G/F4. BOOST HUD line. Cheap ground plane + fog + poles on first pieces.

---

## 5. Visuals + environment

Shared `.tres` (same paths, still 256 `NoiseTexture2D`, no atlas):

- Asphalt: darker, higher-contrast tiling noise, faint wear (`roughness = 0.85` kept)
- Shoulder: less saturated / less orange
- Rails: brighter contrast, metallic 0.58

Generator lab: visual-only ground plane at Y=−14 (no car collision), mild fog, cheap box poles/crowns along first four pieces. Not a city. Collision debug (F4) unchanged.

---

## 6. Landing camera + saturation

`MODE_LANDING_CLOSE` added. **K** on V6 lab cycles: CHASE → LANDING_SIDE → LANDING_CLOSE → TOPDOWN. F7 still jumps to TOPDOWN. LANDING_CLOSE: ~9 m from chassis, height 3.0 m, look at chassis.

V6 is CLOSED. No change to gap, takeoff, mounts, springs, grip, COM, yaw assist, travel (0.14), force cap (18000).

From existing V5/V6 telemetry (`docs/generated/track_jump_v6/human_review/`):

- Rear compression hits travel: RL/RR **0.14 m**
- Rear force hits cap: **18000**
- `landing_vy` **≈ −5.31**

**Verdict:** saturation is the designed travel ceiling. **No damper retune this sprint** (would need 3/3 `PASS_SETTLED` before/after). Camera only.

---

## 7. Tests / smoke

- `tests/test_track_gameplay_content_v3.py` — **pass**
- `test_track_modular_kit_pilot_v1.py` filenames — original 11 still present + new names
- `test_track_generator_v2.py` GLB count **17**
- Headless: TrackBoostDeltaLab **PASS**; TrackGeneratorV2Lab `SSK_GEN_SMOKE=1` **ACCEPTED** ×3; TrackBoostResetLab **3/3**
- V6 full jump 3/3 not re-run (camera only)

---

## Remaining blockers

- Human feel pass: boost punch, chevron read, generator rhythm, LANDING_CLOSE framing
- Headless cannot certify FOV kick or material look
- Hairpins not generated (stretch, skipped)
- Composer still retries on OVERLAP; frozen seeds accept on documented attempts (SHORT 1, MEDIUM 3, LONG 9)

---

## Validator tokens (parent)

```
CONTROLLER_MODE := "BASELINE"
BOOST_OVERSPEED := 1.22
BOOST_DURATION := 0.85
MAX_SPEED * Config.BOOST_OVERSPEED
[TRACK_BOOST] APPLY controller=BASELINE
[TRACK_BOOST] END
[TRACK_BOOST_DELTA] PASS
peak_delta=11.88
[TRACK_BOOST_GEN] PASS apply=3
[TRACK_GENERATOR_V2] ACCEPTED
TRACK_BOOST_RESET_OK 3/3
FRONT_LATERAL_GRIP := 9200.0
SPRING_STRENGTH := 32000.0
YAW_ASSIST_TORQUE := 420.0
ENGINE_FORCE := 6200.0
CENTER_OF_MASS_OFFSET := Vector3(0.0, -0.12, 0.06)
SUSPENSION_TRAVEL := 0.14
MAX_SUSPENSION_FORCE := 18000.0
MODE_LANDING_CLOSE
TRACK_GAMEPLAY_CONTENT_V3_READY_FOR_HUMAN_REVIEW
```

## Files (this workstream)

- `scripts/track/track_car_controller.gd`, `track_config.gd`, `track_camera.gd`, `track_piece.gd`, `track_piece_registry.gd`
- `scripts/track/track_wheel_car.gd` (duration only)
- `scripts/track/track_boost_feedback.gd` (new)
- `scripts/track/track_generator_v2.gd`, `track_generator_v2_validator.gd`, `track_generator_v2_lab.gd`
- `scripts/track/track_extended_debug_camera.gd`, `track_jump_trajectory_lab.gd` (K / LANDING_CLOSE)
- `scripts/debug/track_boost_delta_lab.gd`, `scenes/debug/TrackBoostDeltaLab.tscn`
- `scripts/blender/generate_track_kit_v1.py`, `data/track/modules/track_kit_v1.json`
- `assets/track/materials/track_asphalt_v1.tres`, `track_shoulder_v1.tres`, `track_guardrail_v1.tres`, `track_boost_v1.tres`
- 6 new GLB+JSON under `assets/track/modules/generated/core/`
- `data/track/generator_v2_showcases.json`
- `tests/test_track_gameplay_content_v3.py` + updates to kit/generator/render tests
- `docs/generated/track_boost_v3/delta.json`, `generated_3x.json`
