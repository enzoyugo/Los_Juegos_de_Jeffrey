# TRACK 4WHEEL STRUCTURAL DYNAMICS CLOSURE V4 REPORT

## Primary Verdict

**TRACK_4WHEEL_STRUCTURAL_DYNAMICS_V4_BLOCKED**

Stationary lateral creep is measured and fixed. The clean-jump settle gate did not pass in five iterations. BASELINE remains canonical. 4WHEEL is not promoted.

## Human Video Findings

Authoritative input (not re-answered here):

- V3 body, chase camera, wheels, boost, atlas/D3D12: good.
- Remaining: stationary lateral creep; jump route into `curve_l_45` too soon; noisy `RESET_SETTLE`; landing summaries with `peak_c=0` / `peak_f=0`; debug camera losing landing context.

## Stationary Creep Reproduction

Iteration 01 harness (no physics change), fixed world camera, numerically flat slab:

| case | lateral m | forward m | yaw_delta deg | PASS |
| yaw0_rest | 0.1103 | 0.4123 | 12.019 | false |
| all 5 rest/impulse cases | — | — | — | false |

The new test **failed** while matching human-visible creep. The harness is adequate.

## Creep Root Cause

`lateral_tire_force` used `atan2(v_lat, max(|v_long|, 1.0))`. The 1.0 m/s floor inflates slip at rest, producing tens of kN of lateral force and self-propulsion. `LINEAR_DAMP = 0.10` cannot kill it. RigidBody `linear_velocity = ZERO` outside `_integrate_forces` was unreliable (fixed via `PhysicsServer3D.body_set_state`).

Not camera. Not a freeze. Not global damping.

## Force Breakdown

Iteration 01 yaw0_rest: `net_force_x_peak ≈ 30964 N`, 4/4 contacts, drift chatter.

Iteration 02 yaw0_rest: `net_force_x_peak ≈ 0.012 N`, `net_yaw_torque_peak ≈ 0.00008`, FL/FR compression 0.0311 / 0.0316 (symmetric).

## Low-Speed Tire Behavior

Original slip formula kept as `lateral_tire_force_slip()`.

`lateral_tire_force()` blends viscous `F = -v_lat * LOW_SPEED_LATERAL_DAMP * load_factor` below `LOW_SPEED_STABILITY_BEGIN_MPS` (0.45) to full slip at `LOW_SPEED_STABILITY_FULL_MPS` (2.40). `LOW_SPEED_LATERAL_DAMP = 1100`.

Rest stabilization (chassis damping, not freeze) when: zero throttle/brake/handbrake, 4 wheels down, speed < 0.12 m/s, yaw rate < 0.15, contact normals `y ≥ 0.999`. Steer at rest does **not** exit rest (front wheels may steer without translating). Throttle/brake/airborne/slope/boost exit immediately.

## Stationary Fix

- Near-zero slip blend (low-speed only).
- Rest planar/yaw damping.
- Reset via PhysicsServer (transform + linear + angular = 0; drift → GRIP; airborne flags cleared).

Handling constants unchanged: `FRONT_LATERAL_GRIP 9200`, `SPRING_STRENGTH 32000`, `YAW_ASSIST_TORQUE 420`, `ENGINE_FORCE 6200`, COM, high-speed steer.

## Flat-Road Stability Results

Iteration 02 (`Track4WheelStationaryStabilityLab.tscn`):

| case | result |
| yaw0_rest | lat 5.7e-7 m, yaw 0.000°, PASS |
| yaw ±5° rest | PASS |
| vlat ±0.2 m/s | settle, remaining lat 0.0155 m, final_lat 0, PASS |
| throttle_launch | rest exits; 24.5 m forward in 2 s, PASS |
| steer_at_rest | lat 0.000 m, PASS |

`overall_rest_pass=true`.

## Yaw Stability

Rest yaw_delta 0.000°. Impulse max_yaw_rate 0.0001. Zero-input yaw-assist is `steer * speed` gated; at zero steer it is 0.

## High-Speed Regression

At 10 / 20 / 30 m/s, `lateral_tire_force` equals slip-only (planar ≥ 2.40). Validator: 20 m/s blend vs slip-only delta &lt; 0.01. Pytest mirrors −4140 / −5648.54 / −7145.77. BASELINE controller has no `REST_` / `LOW_SPEED_` symbols.

## Jump Route Previous Failure

Iteration 01 SEQUENCE: `jump_small → curve_l_45`. No long deck. Architecture FAIL.

## New Landing Deck

`landing_straight_long`: generated 36 m, width 11.0, pitch 0, roll 0, rails, no gap collider. Lab-only extra module (pilot still 5 pieces). SEQUENCE:

`start → straight_medium → boost_straight → straight_medium → ramp_small → jump_small → landing_straight_long → straight_medium → curve_l_45 → curve_r_45 → finish`

Seams all 0. `jump_small` still has a real 7 m unsupported gap (no hidden road). `jump_small` also still owns a 14 m land pad (see Remaining Risks).

## Valid Jump Sequence

Iteration 05 (14 m pad restored, throttle released after first contact):

- `VALID_TAKEOFF` at 14.2 m/s, camera `LANDING_SIDE`.
- `FIRST_CONTACT` on **jump_small** (4 wheels, peak_c ≈ 0.07, peak_f 13–18 kN).
- Bounce `TRACK_AIRBORNE`, then contact on `landing_straight_long` with `peak_c=0` in that window → `NO_VALID_CONTACT`.
- `SETTLED=false`. Jump PASS=false.

Iterations 03–04 shortened `jump_small` land to 2 m to force first contact onto the long deck; takeoff speed collapsed to 5.9 m/s. Rolled back.

## Landing Contact

True landings with compression/force are logged as `[TRACK_4WHEEL_LANDING]` with per-wheel peaks.

`peak_c=0` / `peak_f=0` are **not** successful landings: `NO_VALID_CONTACT`. Spawn/reset drops: `SKIP reason=RESET_SETTLE`.

## Suspension Compression

Real first contact (iter 02/05): FL/FR/RL/RR compression ~0.07 m, forces up to `MAX_SUSPENSION_FORCE` 18000 N. Post-bounce window can show `peak_c=0` with leftover force — classified invalid, not VALID_LANDING.

## Airborne State Machine

`AIRBORNE_ENTER` only when `want_air and not _was_airborne` (no re-enter while already airborne unless `reset_to` cleared the flag).

Debounce 3 frames. Reasons: `RESET_SETTLE` / `SPAWN_SETTLE` / `JUMP_AIRBORNE` / `TRACK_AIRBORNE` / `OFFTRACK_AIRBORNE`.

## Reset State

Each `reset_to` increments `reset_generation_id`, logs `[TRACK_RESET]`, zeros linear/angular via PhysicsServer, drift=GRIP, clears airborne/landing window, opens `_reset_context_open`. `RESET_SETTLE` allowed only while that context is open (until 4-wheel slow settle or timeout). Later airborne is not `RESET_SETTLE`. Observed: RESET_SETTLE only immediately after spawn/reset generations.

## Camera

Lab-only `TrackExtendedDebugCamera`. `LANDING_SIDE` is fixed to the landing deck (`follow_car_on_side=false`). Auto-switch to side on `VALID_TAKEOFF`, back to chase on `SETTLED`. `CHASE_CLOSE` pulled back (dist 11.4, height 3.35, look-ahead) so horizon/deck stay in frame. Does not replace TrackMain. F4 shows piece collision, takeoff/landing zones, wheel contact spheres. Camera is observer-only.

Headless jump screenshots of compression were **not** captured. Do not treat camera framing as visually certified.

## V3 Regression Check

V3 articulated GLB path unchanged. Source size 4_269_248. `mesh_rest=(0,0,0)` on all four binds. Steer/spin center delta 0. Semantic nose −Z. V3 was **not** rebuilt.

## Atlas / D3D12

Labs: `loaded=true`, `4096x4096`, `unique_texture_resources=1`, `fallback=false`, valid RID. D3D12 extended 90-frame smoke: no `0x8007000e`, seams 0, live=1. Texture mem reported ~62 MB on D3D12 (headless labs report 0 as expected). Smash/Zombies/TrackMain D3D12 matrix was **not** fully re-run this sprint.

## Iterations

| iter | defects in | change | stationary | jump | auditor |
| 01 | creep + bad route | harness only | FAIL (reproduced) | architecture FAIL | FAIL (required) |
| 02 | creep | low-speed blend + rest + long deck | PASS | first contact + compression, then bounce/left | FAIL jump settle |
| 03 | bounce | 2 m jump land; throttle off at takeoff | (held) | 5.9 m/s underspeed | FAIL |
| 04 | underspeed | 2 m pad, throttle until takeoff | (held) | 5.9 m/s underspeed | FAIL |
| 05 | underspeed | restore 14 m pad; throttle off after first contact | (held) | 14.2 m/s, contact on jump pad, bounce, no SETTLED | FAIL — stop |

Evidence: `docs/generated/track_4wheel_v4_iterations/iteration_0N/`.

## Tests

pytest: **300 passed** after inventory update 8→9 GLBs (`landing_straight_long`). V4 module covers harness creep detection, high-speed slip equality, jump fail categories, BASELINE leak, V3 untouched.

## Validator

`[JEFFREY_VALIDATE] OK`

## Human F6 Required

Automated READY is **not** claimed. Human should still inspect:

1. `Track4WheelStationaryStabilityLab.tscn` — 10 s zero input, fixed camera.
2. `Track4WheelExtendedPhysicsLab.tscn` — 3 clean jumps.
3. Optional BASELINE (F5) comparison.

Questions for the human (not answered here): stay visually fixed when stopped; sideways crawl; slow yaw; throttle from rest; jump onto long deck; wheel compression visible; settle before curves; reset/airborne weirdness.

## Remaining Risks

- **Jump first contact** is on `jump_small`'s own 14 m pad, not `landing_straight_long`. Shortening that pad to 2 m dropped takeoff to 5.9 m/s in this throttle-hold harness.
- **Landing bounce** after compressed contact (even with throttle released after first contact). Car can leave the pad and fail settle.
- **Throttle-hold approach** drifts ~1.3 m left over ~80 m before takeoff.
- Dedicated **slope** roll-down lab was not a separate Godot scene; rest ignores surfaces with `normal.y < 0.999`.
- Viewport screenshots of jump compression were not produced (headless).
- Smash / Zombies / TrackMain full D3D12 matrix not re-run this sprint.

4WHEEL remains parallel R&D. No game-feel retune. No promotion.
