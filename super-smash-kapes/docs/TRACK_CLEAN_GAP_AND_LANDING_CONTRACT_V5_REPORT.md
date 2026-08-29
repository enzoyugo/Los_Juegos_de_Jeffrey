# TRACK CLEAN GAP AND LANDING CONTRACT V5 REPORT

**Verdict: `TRACK_CLEAN_GAP_LANDING_V5_BLOCKED`**

4WHEEL remains parallel. BASELINE remains canonical. Handling constants were not retuned. V3 was not rebuilt. Atlas architecture was not touched. Stationary creep was not reopened.

Human F6 is **not** requested. Promotion is **not** requested.

---

## Primary Verdict

Closed-loop V5 (5 iterations) **separated takeoff from landing geometry** and **proved an empty gap**. The V4 first-contact failure (`jump_small`) is reproduced by the new harness. After decomposition, **first wheel contact is `landing_straight_long`** with real compression/force.

The car still **does not SETTLED 3/3** on the 11 m deck. Best iteration (05) lands on the deck near its exit with residual left velocity and goes `FAIL_OFFTRACK`.

Remaining cause is **ballistic range + lateral rate at clean-lip takeoff speed (~28.6 m/s)**, not a hidden pad and not a spring/damper constant.

---

## V4 Blocker

V4 `TRACK_4WHEEL_STRUCTURAL_DYNAMICS_V4_BLOCKED` jump settle:

- VALID_TAKEOFF **14.2 m/s**
- FIRST_CONTACT **`jump_small`** (4 wheels, peak_c≈0.07 m, 13–18 kN)
- Then bounce; `landing_straight_long` later showed `NO_VALID_CONTACT`

`jump_small` owned lip + gap + **14 m pad**. The pad was the first physical surface after takeoff.

---

## 14m vs 2m Investigation

Offline assembly (`tools/analyze_clean_gap_v5.py`) for land_length 14 m vs 2 m, same route:

| Quantity | 14 m | 2 m | Delta |
|---|---|---|---|
| TAKEOFF_EDGE world | (0, 2.190, -81.2) | identical | **0.0 m** |
| Boost entry | identical | identical | **0.0 m** |
| Ramp entry | identical | identical | **0.0 m** |
| Jump EXIT / deck start | z=-102.2 | z=-90.2 | **12.0 m** |
| Sample count | 57 | 27 | tessellation only |
| Pad boxes after takeoff | all | all | true |

Answers:

- The 14 m “pad” is **after takeoff**, part of **landing**, and **is the piece EXIT**.
- It is **not** approach. Shortening it **does not** move TAKEOFF_EDGE, boost, or ramp.
- It **does** move the next piece (`landing_straight_long`) by the land-length delta.
- It does **not** shorten acceleration distance to the lip.

Evidence: `docs/generated/track_clean_gap_v5/iteration_01/pad_14_vs_2.json`

---

## Takeoff Speed Root Cause

V4 14.2 → 5.9 m/s was **not** caused by post-takeoff pad length.

Geometry at the lip is invariant. V4 iteration_03 (2 m pad) **released throttle at VALID_TAKEOFF** and logged 5.9 m/s / `MISSED_LANDING_LEFT`. V4 iteration_05 (14 m pad) **held throttle until FIRST_CONTACT** and logged 14.2 m/s.

V5 iteration_01 (14 m pad, throttle held until takeoff then coast) reproduced **14.17 m/s** and `first_contact=jump_small`.

Clean `ramp_takeoff` (no jump seam) produces **~28.6 m/s** at the same approach/boost. The old 14.2 m/s was **early airborne on `jump_small`’s combined piece**, not the true lip speed.

---

## Old jump_small Contract

One piece, three jobs:

- Lip 1.2 m at 18°
- Gap 7 m (`solid=false`)
- Land pad 14 m at drop 0.85 m
- `centerline_length = 22.2 m`
- EXIT at end of pad, not at TAKEOFF_EDGE

First physical contact after takeoff was the pad (along > 1.2 m).

---

## New Ramp Contract

`ramp_takeoff` (`track_ramp_takeoff_v1.glb`):

- 12 m hermite ramp (height 1.8 m → 18°) + 1.2 m lip
- EXIT / `TAKEOFF_EDGE` at (0, 2.190, -13.2) local
- **No road after the lip**
- Guardrails **false** (iter 05) so rail caps cannot sit in the ballistic path
- World TAKEOFF_EDGE remains **z = -81.2** (same as V4)

---

## Gap Contract

`gap_logical` (`track_gap_logical_v1.glb`):

- ENTRY = takeoff edge (pitch 18°)
- EXIT = landing start (pitch 0, height_delta -1.24 m)
- Runtime `SSK_GAP_LENGTH` moves EXIT only
- **collision = []** (no road, rail, or invisible bridge)
- Debug MARKER posts only

Godot AABB sweep iteration_02/05: `gap_empty=true`, `gap_road_collision=[]`.

---

## Landing Deck Contract

`landing_straight_long` unchanged: 36 m, pitch 0, road 11.0 m, first physical road after the gap.

Iter 05 first contact: `hit_ids.landing_straight_long=1` via wheel ray collider ownership (`contact_piece_id`).

---

## Assembly Independence

Python invariance (gap 6 / 10 / 14 m):

- TAKEOFF_EDGE identical
- Boost identical
- Ramp identical
- Landing start moves by **−4 m** in z per +4 m gap (`assembly_invariance.json` PASS)

Changing gap does not move approach/boost/ramp/lip.

---

## Collision Inventory

V4 layout: road boxes of `jump_small` pad occupy the interval TAKEOFF_EDGE → `landing_straight_long` (harness `gap_empty=false`).

V5 layout: zero road collision in that interval (`gap_empty=true`). No hidden catch plane was added.

---

## First Contact Authority

`TrackArcadeWheel` exposes `contact_piece_id` / `contact_collider_name` from the ray collider’s `track_piece_id` meta.

Iter 01: `jump_small:4`  
Iter 02/05: `landing_straight_long`

Body-before-wheel is logged separately (`BODY_CONTACT_BEFORE_WHEEL`). Iter 05: `body_precontact=false`.

---

## Deterministic Jump Driver

V5 lab `TrackCleanGapLandingLab.tscn`:

- Scripted throttle=1 until VALID_TAKEOFF, then 0
- Steer=0 in air and on ramp
- Light center-hold on **flats only** (stay-centered driver, not handling retune)
- No drift, no manual reset during a counted run

---

## Jump 1 / Jump 2 / Jump 3

3/3 SETTLED was **not** reached. Best single run is iteration_05 run 1:

| | Iter 05 |
|---|---|
| Takeoff | 28.58 m/s, x=-0.63, yaw=5.8° |
| Airborne forces | spring=0, damper=0, tire=0 |
| First contact | `landing_straight_long`, 1 wheel → 2 |
| Compression | RR 0.085 m, FL 0.033 m; f up to 18 kN |
| Deck station | 32.9 m of 36 m |
| Result | **FAIL_OFFTRACK** (left boundary) after 0.32 s on deck |

---

## Landing Compression

Valid: peak_c > 0 and peak_f > 1 on first deck contact (iter 04/05). Not `NO_VALID_CONTACT`.

---

## Reacquisition

Iter 05: time_to_2 = 5.97 s, time_to_4 = **-1**. Four-wheel reacquisition not achieved before offtrack.

---

## Settle

SETTLED definition in lab: ≥2 wheels, on landing/recovery, |vy|<1.6, ang rates <2.4, hold 0.45 s.

Not reached. Window ended in FAIL_OFFTRACK.

---

## Recovery

`straight_medium` after the deck is the recovery straight; curves follow. The car never reached `curve_l_45` in the best run.

---

## Airborne Forces

Iter 05 while airborne and grounded_n=0: spring=0, damper=0, tire=0. Boost pulse ended at t=3.15 s, before takeoff (~4.18 s).

---

## Stationary Regression

No change to `LOW_SPEED_*`, rest damp, FRONT/REAR grip, springs, COM, or `REST_ENTER_*`. V4 iter 02 rest PASS remains the freeze. Not re-run this sprint (physics tunables untouched).

---

## V3 Regression

`track_car_base_v3_articulated_clean.glb` not rebuilt. Source size still 4_269_248. mesh_rest=(0,0,0) in V5 lab binds. Validator OK.

---

## D3D12 / Atlas

Jump labs (D3D12 / Forward+ / headless):

```
loaded=true
size=4096x4096
unique_texture_resources=1
fallback=false
rid_valid=true
```

No `0x8007000e`, no invalid RID in these runs.

---

## Iterations

| Iter | Layout | Result | Note |
|---|---|---|---|
| 01 | V4 jump_small 14 m | FAIL_FIRST_CONTACT_WRONG_PIECE | Harness reproduced V4 |
| 02 | V5 gap 7 m | FAIL_BODY_CONTACT_BEFORE_WHEEL | First contact **on deck**; rail at x=-6 |
| 03 | V5 gap 14 m + ramp steer | incomplete | Steer-on-ramp killed takeoff speed |
| 04 | V5 gap 10 m, strong center | FAIL_NO_SETTLE | Over-center; zone miss; compression still on deck |
| 05 | V5 gap 10 m, light center, no ramp rails | FAIL_OFFTRACK | **Best.** Deck contact + compression, then left exit |

Best candidate: **iteration_05**. Newest does not automatically win; 05 is best on first-contact geometry + compression.

---

## Tests

- Full pytest: **305 passed** after inventory count 9→11 (new `ramp_takeoff`, `gap_logical` GLBs)
- `[JEFFREY_VALIDATE] OK`

---

## Validator

Added without weakening old gates:

- `TRACK_TAKEOFF_TRANSFORM_INVARIANCE`
- `TRACK_GAP_COLLISION_EMPTY`
- `TRACK_FIRST_CONTACT_LANDING_DECK`
- `TRACK_NO_BODY_PRECONTACT`
- `TRACK_CLEAN_JUMP_SETTLE`
- `TRACK_RECOVERY_BEFORE_CURVE`

Plus `TrackCleanGapLandingLab.tscn`, `gap_logical` collision_count==0, `ramp_takeoff` road collision, wheel `contact_piece_id`.

---

## Human F6 Required

**No.** Automated READY rule failed (no 3/3 SETTLED). Do not open the lab for human jump review as a pass gate.

Debug lab for later work: `scenes/debug/TrackCleanGapLandingLab.tscn`  
Extended V4 lab remains: `scenes/debug/Track4WheelExtendedPhysicsLab.tscn`

---

## Remaining Risks

1. **Clean-lip takeoff ~28.6 m/s** vs old 14.2 m/s. Range ~40 m vs 36 m deck starting 10 m after the lip → touchdown in the last ~3 m.
2. **Lateral rate** vx≈-3.3 m/s, yaw≈6° at takeoff → x grows to -5.3 at contact on an 11 m road. Not solved by emptying the gap.
3. Next structural options (not done; iteration cap): longer landing deck, slightly larger gap to move station forward, or a yaw/vx dump that is **not** a spring retune. Do **not** widen the deck to 30 m.
4. 4WHEEL is still not promoted.

---

## Ready rule (explicit)

| Gate | Status |
|---|---|
| V4 first-contact reproduced | PASS (iter 01) |
| 14 m→2 m speed explained | PASS (geometry invariant; harness confound) |
| Approach/takeoff decoupled from gap | PASS |
| Ramp ends at takeoff edge | PASS |
| Gap zero road collision | PASS |
| First wheel contact = landing_straight_long | PASS (iter 02+) |
| No body precontact (best run) | PASS (iter 05) |
| Valid compression | PASS (iter 05) |
| 3/3 SETTLED on landing/recovery | **FAIL** |
| Settle before curves | N/A (offtrack first) |
| Stationary tunables frozen | PASS (untouched) |
| V3 / atlas / pytest / validator | PASS |

**`TRACK_CLEAN_GAP_LANDING_V5_BLOCKED`**
