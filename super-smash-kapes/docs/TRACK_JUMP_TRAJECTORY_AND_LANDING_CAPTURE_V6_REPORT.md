# TRACK JUMP TRAJECTORY AND LANDING CAPTURE V6 REPORT

**Verdict: `TRACK_JUMP_TRAJECTORY_LANDING_CAPTURE_V6_READY_FOR_HUMAN_REVIEW`**

4WHEEL remains parallel. BASELINE remains canonical. Springs, grip, COM, and global yaw-assist constants were not retuned. Road width remains 11 m. V3 was not rebuilt. Atlas architecture was not touched. V5 gap/pad decomposition was not reopened.

Human F6 is requested on `scenes/debug/TrackJumpTrajectoryLandingLab.tscn` (see Human F6 Gate). Promotion is not requested.

---

## Primary Verdict

V5 `FAIL_OFFTRACK` is reproduced. The two blockers are independent:

- **Longitudinal:** a 10 m gap + 36 m deck places a ~29 m/s / 18° lip landing in the last ~3 m (or, once centered, beyond the 36 m deck).
- **Lateral:** V3-scaled physics ray mounts were 13 mm left/right asymmetric. Tire yaw integral from spawn produced vx≈-3.3 m/s and yaw≈6° at takeoff. Boost torque is 0. Zero-steer did not remove it.

Fixes (not suspension):

1. Symmetrize **physics** wheel mounts (visual V3 translations unchanged).
2. Calibrate landing: **gap 30 m**, **deck 60 m** (36 + 24 m extra owned by `landing_straight_long`).

3/3 independent Godot processes: `PASS_SETTLED`, bit-identical takeoff 29.20 m/s, first contact at 19.97 m into the 60 m deck (~33%), 40 m remaining, 4-wheel reacquisition, no second airborne.

---

## V5 Blocker

Takeoff 28.58 m/s, vx=-3.29, yaw=5.8°, first contact 32.9 m into 36 m (3 m left), then left boundary `FAIL_OFFTRACK`.

---

## V5 Reproduction

Iteration 01 (v5 steer, gap 10, deck 36):

- takeoff 28.58 m/s, vx=-3.285, yaw=5.80°
- first_contact=`landing_straight_long` station=32.88 remain=3.12
- `FAIL_OFFTRACK`

Harness matches V5 iter 05.

---

## Takeoff Velocity Vector

Centered candidate (iter 03/05):

| | value |
|---|---|
| speed | 29.20 m/s |
| world v | ≈ (0, 8.0, -29.2) |
| yaw | ≈ 0.000° |
| pitch | ~14.4–15° at lip |
| vx | 6e-6 m/s |

V5 dirty takeoff used the same lip but a yawed chassis, so world vx leaked.

---

## Lateral Drift Origin

First |vx|>0.15 at t=0.55 on `start` (launch transient). Material yaw exists before the ramp (~1.5° at boost) and is **amplified on the ramp** (1.5° → 5.8°).

Zero-steer control: takeoff vx=-2.83, yaw=5.12° — **worse**, so the V5 center-hold was not the source.

---

## Yaw Origin

Dominant integral spawn→takeoff (iter 01):

| subsystem | yaw impulse |
|---|---|
| tire | +1149 |
| yaw_assist | +3.7 |
| antiroll | -22 |
| boost | **0** |
| air_control | ~0 |

Physics mounts before fix: FL x=-0.899, FR x=+0.886 (13 mm). After symmetrize: ±0.8927. Takeoff yaw → 0.

Visual V3 `WHEEL_*_PROCESSED` is unchanged.

---

## Force/Torque Integrals

After the mount fix (iter 02+): tire lateral impulse ~0.03, left/right lat equal to 1e-5. Boost impulse_x = 0.

---

## Ramp Geometry Audit

9 pitched road boxes, max adjacent pitch step **2.47°**. Origins x=0, full width 12.4 m. Left/right normals on approach (0,1,0). Ramp is not the left/right bias; it amplifies an upstream yaw.

---

## Boost Audit

`apply_central_force` along piece -Z. Logged boost torque integral = 0. Pulse ends before takeoff (t≈3.15 vs takeoff t≈4.18). No continuous boost in flight.

---

## Ballistic Model

Uses measured (p, v) and ProjectSettings g=9.8:

y(t) = y0 + vy t − ½ g t², hit at COM plane ≈ landing_y + 0.92 m.

Dirty V5: t=1.48 s, range from lip 44.8 m, predicted hit x=-5.50 (rail). Actual station 32.88 vs pred 34.83 (~2 m).

Clean: t=1.83 s, range from lip **55.81 m**, predicted hit x=0.000, pred station 25.81, actual station 19.97 (6 m early, still first third). Airborne spring/damper/tire = 0.

---

## Predicted vs Actual Trajectory

See `docs/generated/track_jump_v6/iteration_03/topdown_trajectory.svg` and `side_trajectory.svg`. Headless viewport PNGs are dummy; SVG is the auditor plot.

---

## Landing Geometry Calibration

Measured clean range from lip ≈ 56 m. A 10 m gap + 36 m deck **overshoots** onto recovery (`FAIL_FIRST_CONTACT_WRONG_PIECE` in iter 02).

Chosen:

- gap = **30 m** (real unsupported stunt; car length 4.4 m)
- landing_straight_long = **60 m** (36 m kit + 24 m extra collider/mesh parented to the same piece_id)
- recovery = existing 24 m `straight_medium`

Touchdown ~20 m into 60 m (33%), remaining 40 m (≥20 m). TAKEOFF_EDGE / boost / ramp **unchanged** (boost origin z=-32, ramp entry z=-68, landing start -91.2 → -111.2).

---

## Final Gap

30 m `gap_logical`. Zero road collision. `has_gap=true`.

---

## Final Landing Deck

60 m, pitch 0, width 11.0 m, first physical road after the gap. Extra length is `collision_kind=road` with `track_piece_id=landing_straight_long`.

---

## Final Recovery Straight

24 m `straight_medium` after the deck. Curves after that. Settle occurs on the deck (hold 0.47 s) long before `curve_l_45`.

---

## Jump Run 1 / 2 / 3

Independent processes `iteration_05/nom_1` … `nom_3`:

| | all three |
|---|---|
| result | PASS_SETTLED |
| takeoff | 29.20 m/s, vx≈0, yaw≈0 |
| first contact | landing_straight_long, 2 wheels, station 19.97 m |
| remaining | 40.03 m |
| SETTLED | landing_straight_long, 4 wheels, speed 13.84 |

---

## Suspension Contact

peak_c FL/FR≈0.053 m, RL/RR=0.14 m (travel). peak_f rear 18 kN, front 5.8 kN. Valid compression. No body-before-wheel. No rail on the centered run. No spring retune.

---

## Settle

On landing/recovery road, ≥3 (actually 4) wheels, |vy| and ang rates inside lab thresholds, 0.45 s hold, no second airborne, inside 11 m width (x_peak 0.068 m).

---

## Stationary Regression

Physics tunables (springs, rest blend, grip) unchanged. Mount symmetrize is a 4WHEEL ray-position fix only.

StationaryStabilityLab (D3D12, 7 cases): **all PASS**, `overall_rest_pass=true`. Rest: 0.000 m drift, 0.000° yaw. Throttle launch: 24.5 m forward, 0 yaw. Low-speed blend was not edited.

---

## V3 Regression

`track_car_base_v3_articulated_clean.glb` not rebuilt. Visual wheel translations unchanged. mesh_rest remains (0,0,0). Semantic -Z unchanged.

---

## D3D12 / Atlas

Jump labs:

```
loaded=true
size=4096x4096
unique_texture_resources=1
fallback=false
rid_valid=true
```

No `0x8007000e`.

---

## Iterations

| Iter | Change | Result |
|---|---|---|
| 01 | reproduce V5 | FAIL_OFFTRACK, takeoff matches V5 |
| 02 | physics mount symmetrize | vx/yaw ≈ 0; overshoot 36 m deck |
| 03 | gap 30 + deck 60, zero steer | PASS_SETTLED |
| 04 | in-process 3/3 | 2/3 (run 2 reset/boost) |
| 05 | 3× fresh process | **3/3 PASS_SETTLED** |

Best candidate: iter 03 layout + default `v6_symmetrize_physics_mounts=true`. Newest in-process 3-run does not win.

---

## Tests

- Full pytest: **309 passed**
- `[JEFFREY_VALIDATE] OK`
- StationaryStabilityLab: rest PASS, throttle launch PASS
- Jump labs D3D12 atlas: 4096² unique=1 fallback=false

New: `tests/test_track_jump_trajectory_landing_v6.py`. V5 tests unchanged.

Dedicated Smash / Zombies D3D12 smokes were not re-run this sprint; validator instantiated TrackMain. Atlas in every 4WHEEL lab this session stayed 4096² / unique=1 / fallback=false.

---

## Validator

Added without weakening V4/V5:

- TRACK_TAKEOFF_LATERAL_STATE
- TRACK_TAKEOFF_YAW_STATE
- TRACK_BALLISTIC_PREDICTION
- TRACK_LANDING_CAPTURE_MARGIN
- TRACK_APPROACH_FORCE_BALANCE
- TRACK_RAMP_NORMAL_SYMMETRY
- TRACK_NOMINAL_3X_SETTLE

---

## Human F6 Gate

Open `scenes/debug/TrackJumpTrajectoryLandingLab.tscn` with:

```
SSK_TRACK_CONTROLLER=4WHEEL
SSK_V6_MODE=full
SSK_V6_STEER=zero
SSK_GAP_LENGTH=30
SSK_LANDING_EXTRA_M=24
SSK_V6_SYM_MOUNTS=1
```

Check: centered approach, real 30 m gap, lip ends at the edge, first contact on the long deck (~1/3), wheels compress, car stays on 11 m road, settles before curves, LANDING_SIDE shows lip/gap/deck.

F4 debug AABBs. F7 top-down.

---

## Remaining Risks

1. **In-process reset:** `JUMP_RUNS>1` without a new process can miss boost Area3D / leftover body state (iter 04 run 2). Fresh process is the 3/3 authority.
2. Ballistic vs actual station still ~6 m (pitch/COM). Capture margin is 40 m so it is not blocking.
3. Rear compression hits travel (0.14 m) on this landing. Geometry now passes; a later narrow landing-dynamics pass may look at that **without** reopening springs until a TRUE_LANDING_DYNAMICS_BLOCKER is declared.
4. 4WHEEL is still not promoted.
