# TRACK 4WHEEL ARTICULATED TRANSFORM FIX V1
# + EXTENDED PHYSICS VALIDATION LAB

## Primary Verdict

**TRACK_4WHEEL_ARTICULATED_V1_READY_FOR_HUMAN_REVIEW**

The two visual/transform defects that blocked 4WHEEL review are fixed:

1. Articulated body now faces chassis −Z (track forward). Physics forward, visual mesh nose, and track −Z agree. No inverse throttle/steer, no RigidBody yaw hack.
2. The four wheel visuals sit in rest pose on their axle pivots. STEER_ONLY / SPIN_ONLY keep the wheel center fixed. SUSPENSION_ONLY moves along the suspension axis only. Full articulation no longer orbits or detaches.

The 5-piece modular pilot is unchanged (exact seams, road 11.0 / shoulders 0.7 / rails 0.9). Three additional **pilot** modules exist for physics stress only: `ramp_small`, `jump_small`, `boost_straight`. Total generated GLBs: **8**. The remaining 14 kit pieces were **not** generated. BASELINE remains canonical. 4WHEEL is still parallel and is **not** promoted.

Human still has to drive `Track4WheelExtendedPhysicsLab` and answer: does the car feel supported by four tires on bumps, ramp, airborne extension, and landing compression?

## Original Human Defects

Observed on a real 4WHEEL lab drive:

| Bug | Symptom | Not the cause |
|---|---|---|
| A | Articulated car visually faced backwards vs travel / chassis forward | Handling, inverted throttle, chassis yaw |
| B | Four wheel visuals exploded, orbited, detached, or transformed wildly | Independent RigidBody wheels, suspension tuning |

Logs at the time: BASELINE `authority=source articulated_wheel_binds=0`; 4WHEEL `authority=articulated articulated_wheel_binds=4`. The four wheel nodes were found. The defect was after bind/mount.

## Root Causes

**Bug A — backwards body**

- Track / physics convention: +Y up, −Z forward, +X right.
- Source fused GLB (`track_car_base_v1.glb`) is still +Z-nose. BASELINE correctly applies `SOURCE_VISUAL_YAW_DEGREES = 180` on **VisualRoot**.
- Processed articulated GLB wheel **node translations** already live in −Z-forward chassis space (`FL.z < 0`, `RL.z > 0`).
- Body **mesh vertices** are still the source +Z-nose island. V2 notes that claimed a full −Z-nose round-trip were wrong for the body mesh.
- Reusing the source 180° yaw on the whole articulated VisualRoot would also flip wheel mounts vs physics sensors.

**Bug B — exploding wheels**

Three compounding transform errors, not four exploding RigidBodies (wheels remain `Node3D` sensors):

1. Bind copied the imported mesh global transform onto the mount (basis/scale leaked into the axle pivot).
2. Wheel mesh vertices are **not** centered on the node origin (FL centroid ~3 cm). Spinning around the node origin orbits the tire.
3. Suspension visual used physics metres under VisualRoot scale **≈ 4.409**, so travel was ~4.4× too large.

Typical invalid structure: `WheelMount.position = axle` **and** `WheelMesh.position = imported axle` → double translation → orbit.

## Body Orientation Fix

Physics chassis is **not** rotated. Art is corrected to physics.

| Path | Constant | Value | Applied on |
|---|---|---|---|
| Source / fused | `SOURCE_VISUAL_YAW_DEGREES` | 180 | VisualRoot |
| Articulated VisualRoot | `ARTICULATED_VISUAL_YAW_DEGREES` | **0** | VisualRoot |
| Articulated body mesh | `ARTICULATED_BODY_YAW_DEGREES` | **180** | **Body node only** |

`visual_forward()` for articulated mode is the Body mesh +Z axis after that yaw (source nose), which then matches chassis −Z.

Validator at identity spawn:

```
[TRACK_4WHEEL_ORIENT] chassis=(0.0, 0.0, -1.0) visual=(-0.0, 0.0, -1.0) track=(0.0, 0.0, -1.0) dot_cv=1.000
[TRACK_4WHEEL_BODY] body_yaw=180.0 visual_fwd=(-0.0, 0.0, -1.0) chassis_fwd=(0.0, 0.0, -1.0)
```

Extended lab F4 gizmos: CHASSIS FORWARD / VISUAL FORWARD / TRACK FORWARD.

## Wheel Pivot / Transform Fix

Chosen method (**B**, documented in `track_car_visual.gd`):

1. Read imported wheel global transform.
2. Axle = imported node origin + local mesh centroid.
3. `WheelMount` at that axle, **identity rotation and scale**, same parent.
4. Nested identity pivots: `SteerPivot` → `SuspensionPivot` → `SpinPivot`.
5. Reparent `WheelMesh` under `SpinPivot`, restore the captured global transform.
6. Rest-state visual matches the imported wheel. No jump from rebind.

Hierarchy:

```
WheelMount          chassis-space axle only
  SteerPivot        front Y rotation only
    SuspensionPivot suspension-axis translation only
      SpinPivot     local X rotation only
        WheelMesh   rest geometry; local offset = centroid correction only
```

Suspension visual: `susp.position.y = susp_m / VISUAL_SCALE` so world travel equals physics metres.

Spin: `fmod(angle, TAU)` on both visual apply and `TrackArcadeWheel.spin_angle`.

Front/rear assertion: FL/FR have negative Z, RL/RR positive Z under −Z-forward. Logged `front_rear_ok FL.z=-0.312 RL.z=0.279`.

Bind print (once per mount, not per frame):

```
[TRACK_4WHEEL_BIND] FL mount=(-0.201, 0.087, -0.312) mesh_rest=(-0.000, -0.002, 0.027) steer=Y spin=X
[TRACK_4WHEEL_BIND] FR mount=( 0.202, 0.087, -0.310) mesh_rest=( 0.002, -0.002, 0.025) steer=Y spin=X
[TRACK_4WHEEL_BIND] RL mount=(-0.201, 0.088,  0.279) mesh_rest=(-0.001, -0.003, 0.019) steer=Y spin=X
[TRACK_4WHEEL_BIND] RR mount=( 0.203, 0.084,  0.281) mesh_rest=(-0.000,  0.001, 0.017) steer=Y spin=X
```

Processed GLB was **not** rewritten.

## Rest Pose

All four mesh rest locals are near zero (centroid correction 1.7–2.7 cm, limit 8 cm). Validator rejects double translation.

Modes: `0 REST_ONLY`, `1 STEER_ONLY`, `2 SUSPENSION_ONLY`, `3 SPIN_ONLY`, `4 FULL`. Cycle with **V**. Direct: **6 / 7 / 8 / 9 / 0**. HUD shows `VISUAL_MODE`. Default for driving remains FULL after rest/pivot proof.

## Steer-only

Front wheels: Y rotation on `SteerPivot`. Rear: 0 steer in `STEER_ONLY`. Validator applies 0.45 rad on each bind: wheel **center** (mesh centroid in world) does not move (>2 cm would fail).

## Spin-only

All wheels: X rotation on `SpinPivot`. Center stays. No orbit. `fmod` prevents float growth under boost.

## Suspension-only

Translation on `SuspensionPivot` along mount +Y (chassis up). Validator: 8 cm physics → world ΔY ≥ 1 cm, |ΔX| and |ΔZ| ≤ 2 cm.

Airborne: ray miss sets `suspension_length = rest + travel` (visual extends). Landing compression is the spring travel, bounded by `MAX_SUSPENSION_FORCE`. No retune this sprint.

## Full Articulation

Enabled after 0–3. Composition is mount × steer(Y) × susp(Y translate) × spin(X) × mesh rest. F5 / reset calls `reset_motion()` so spin/suspension do not keep stale pose.

## F5 Instance Hygiene

Labs no longer `queue_free()` the old car (that left two physics authorities for a frame). Sequence: `remove_child` + `free()`. Both controllers `add_to_group("track_runtime_car")`. Visual `_exit_tree` decrements live visual count. PackedScenes may stay cached (allowed).

Logs:

```
live_track_car_count=1
```

after every completed switch. Validator: free then spawn → `live_track_car_count=1`. D3D12 extended smoke with F5 at frames 24 and 48: 4WHEEL → BASELINE → 4WHEEL, count stayed **1**.

`source_instances` in older logs mixed historical counters with live nodes. Live group count is the authority.

## Extended Modules

Generated **only** these three additional IDs (JSON already listed them; `--all` still exits 2):

| piece_id | GLB | Role |
|---|---|---|
| `ramp_small` | `track_ramp_small_v1.glb` | 12 m, height +1.8 m, ease-in pitch |
| `jump_small` | `track_jump_small_v1.glb` | 1.2 m lip + 7 m gap + 14 m landing, drop 0.85 m, no rails |
| `boost_straight` | `track_boost_straight_v1.glb` | 12 m straight + cheap marker strip + Area3D |

Pilot five remain. Total on disk: **8** GLBs. Command:

```
python scripts/blender/generate_track_kit_v1.py --extended
```

`ElevationBuilder` / `SpecialBuilder` are real dispatch paths, not stubs.

## Ramp Geometry

Parametric `t²` ease-in (not a 15° wedge seam):

```
s = t²
y = H s
along = L t
pitch = atan(2 t H / L)
fwd = (0, sin(pitch), −cos(pitch))
```

At EXIT: `(0, 1.8, -12)`, pitch ≈ **16.70°** (`atan(0.3)`). JSON `launch_angle_deg: 18` is metadata; the profile owns the actual tangent. Collision: 8 pitched `BoxShape3D` segments, overlap 0.04 m, rails follow the profile. Import: `gltf/embedded_image_handling=0`, no embedded images.

## Boost Behavior

Shared interface: `apply_track_boost(direction, magnitude)`.

| Rule | Implementation |
|---|---|
| Trigger | `Area3D` `BoostTrigger`, layer 0, mask 2, does not block |
| Direction | assembled piece −Z, **Y planarized** (no vertical launch) |
| Enter | `body_entered` once |
| Re-entry | ignored while pulse timer > 0.08 s |
| Pulse | 0.55 s, magnitude clamped 0.2–2.5 |
| BASELINE | extra along-track accel `ACCEL * 0.55 * mag * delta` |
| 4WHEEL | central force `ENGINE_FORCE * 0.85 * mag` at COM |
| Disable | **B** toggles `TrackPiece.boost_gameplay_enabled` |

No teleport velocity. No giant VFX — `START_FINISH` material strip only.

## Airborne

Natural ray miss. `TrackArcadeWheel.step` returns before spring / lateral / drive forces when the ray does not hit. Validator already asserts `lateral_tire_force(..., load=0) == 0`.

Logs once per event: `[AIRBORNE_ENTER]` / `[AIRBORNE_EXIT] dt=… land_vy=… max_c=… max_f=… ang=…`.

Spawn still drops from `PLAYER_SPAWN` y=1.15 onto y=0, so a short AIRBORNE_ENTER/EXIT at t≈0.42 s is expected and is **not** the jump. Jump gap has no collision boxes (sidecar check: gap z has no road box overlap).

## Landing

Jump landing deck at local y=−0.85, flat, 11 m road, no rails, 14 m long. Lip continues ramp pitch in local mesh; ENTRY pitch matches ramp EXIT so assembly world-flattens the jump root. Gap is unsupported. Recovery is physics, not a forced state. No sim thresholds this sprint — metrics are diagnostic only.

## Wheel Contact

4WHEEL spawn on the original 5-piece pilot: **grounded 4/4**, y=0.014, spawn ray hit y=0.0. Extended smoke: `max_seam=0.000000`. Physical sensors were **not** moved to hide visual error; visual mounts were rebuilt to the imported axle+centroid.

## BASELINE

Still `CONTROLLER_MODE := "BASELINE"`. TrackMain still instantiates `TrackCar.tscn`. BASELINE runs the extended route, uses the same boost Area3D, and does not use 4-wheel suspension. F5 A/B preserved. CharacterBody3D boost is the along-track pulse above.

## 4WHEEL

Parallel `TrackCarWheelPhysics.tscn` / `TrackWheelCar`. RigidBody3D chassis, four `TrackArcadeWheel` sensors. No grip/drift/engine retune this sprint. Articulated visual is the processed GLB with the split yaw + pivot bind. Optional air yaw only while 0/4 grounded (pre-existing).

## D3D12

Forward+ / D3D12, GPU NVIDIA GeForce RTX 2060 SUPER.

| Scene | Result |
|---|---|
| `TrackModularKitPilotLab` BASELINE | SMOKE END, create=false, tex ≈ 61.6 MB |
| `TrackModularKitPilotLab` 4WHEEL (isolated) | SMOKE END, grounded 4/4, seam 0, tex ≈ 61.6 MB |
| `Track4WheelExtendedPhysicsLab` BASELINE | SMOKE END, live=1, seam 0 |
| `Track4WheelExtendedPhysicsLab` 4WHEEL + F5×2 | SMOKE END, live=1, seam 0, tex ≈ 61.6 MB, no SCRIPT ERROR |
| `TrackMain.tscn` | clean (no CreateResource / 0x8007000e / SCRIPT ERROR) |
| `M0Playground.tscn` (Smash host) | clean |
| `ZombiesMain.tscn` | clean |

Atlas remains the canonical extracted 4K source albedo. No new unique atlas. New modules are geometry-only GLBs + shared untextured materials.

**Note:** four D3D12 Godot processes launched back-to-back without pause once hit `Create(Graphics)PipelineState 0x8007000e` / `DXGI_ERROR_DEVICE_REMOVED` on the second process. Isolated and spaced runs are clean. Tooling now sleeps 4 s between smokes. This is GPU process teardown, not a new atlas leak.

## Tests

Pytest after this sprint: see **Tests** count in the gate table below (full suite). New/updated coverage:

- Split `SOURCE_VISUAL_YAW` vs `ARTICULATED_*` yaw
- No chassis yaw-to-match-art
- Wheel bind does not double-translate
- Airborne skips tire forces
- Shared bounded boost
- F5 `old.free()` + `live_track_car_count`
- Exactly **8** generated modules; `--all` still refused
- Ramp/jump/boost parametric math, gap has no floor
- Import flags `gltf/embedded_image_handling=0`
- Original 5 GLBs still present; `pilot_ids` still the 5-piece list

Godot validator `_check_articulated_extended`: basis alignment, rest locals, steer/spin/susp centers, live count 1, boost Area3D, jump collision present.

## Validator

`ValidateJeffreyShell.tscn` headless `gl_compatibility`:

**`[JEFFREY_VALIDATE] OK`**

Expected CI `push_error` on corrupt-save quarantine remains. Pilot seams still 0.0 m / 0.0°. 4WHEEL spawn 4/4.

Path scanner: **177** refs, `missing=0`, `required_missing=0`.

## Human Review Required

Drive `scenes/debug/Track4WheelExtendedPhysicsLab.tscn`:

1. Confirm the car faces down the road (no 180° “backing up” while throttle is forward).
2. Cycle **V** / **6–0**: rest → steer in place → spin in place → susp up/down → full.
3. **F5** A/B: one car, one camera.
4. Boost strip: noticeable accel, steerable, no pop into the air, no runaway on re-entry.
5. Boost → ramp → gap → landing: extension in air, compression on impact, contact returns.
6. **B** off: same jump geometry at lower speed (geometry vs boost-speed).
7. **C** reset: no leftover spin/boost/air metrics.

Core question (do not auto-answer):

> Does 4WHEEL feel more like the car is actually supported by four tires?

Especially on bumps, ramp, airborne extension, landing compression.

## Known Issues

- Spawn drop still emits a short AIRBORNE_ENTER/EXIT; that is the 1.15 m spawn height, not the jump.
- Jump ENTRY pitch is authored to match this ramp’s `atan(2H/L)` (16.70°). A different preceding piece would need a matching ENTRY pitch.
- `mesh_rest` z ≈ 2 cm is the imported centroid vs node origin, not a remaining double-translate.
- Left/right spin sign was not changed; if a mirrored basis looks wrong in FULL, that is a follow-up, not a retune of grip.
- Rapid stacked D3D12 editor launches can still OOM PSO creation; wait between processes.
- TrackMain procedural generator does **not** consume these 8 GLBs yet (lab/pilot only).
- Handling (front/rear grip, drift, yaw assist, engine, max speed) was **not** retuned. Subjective feel goes to the next sprint.

## Recommendation

Do **not** promote 4WHEEL. Keep `CONTROLLER_MODE := "BASELINE"`.

This sprint unblocked visual authority and added a small airborne/boost lab. Promotion stays a human call after the drive above.

---

## Gate table

| Item | Value |
|---|---|
| Branch | `master` |
| HEAD | `f5b73e2` |
| Godot | 4.7.2.stable.official |
| GPU | NVIDIA GeForce RTX 2060 SUPER |
| Renderer | Forward+ / D3D12 |
| Canonical controller | `CONTROLLER_MODE := "BASELINE"` |
| 4WHEEL | parallel, not promoted |
| Generated modules | 8 (5 pilot + 3 extended) |
| Pilot seams | 0.0 m / 0.0° |
| Extended assembly seams | 0.0 m (`max_seam=0.000000`) |
| Texture mem (D3D12 labs) | ≈ 61.6 MB (same band) |
| Atlas | shared 4K source albedo |
| Validator | `[JEFFREY_VALIDATE] OK` |
| Path scan | 177 refs, required_missing=0 |
| Pytest | **277 passed** (was 266) |

## Keys (labs)

| Key | Action |
|---|---|
| F3 | HUD |
| F4 | colliders / seams / forward gizmos |
| F5 | BASELINE ↔ 4WHEEL |
| V | cycle visual mode |
| 6 7 8 9 0 | REST / STEER / SUSP / SPIN / FULL |
| B | boost gameplay on/off |
| C | reset to start |

## Files

- `scripts/track/track_car_visual_config.gd` — split yaw constants
- `scripts/track/track_car_visual.gd` — body yaw, method-B bind, modes, rest/center helpers
- `scripts/track/track_wheel_car.gd` / `track_car_controller.gd` — `apply_track_boost`, airborne metrics, group
- `scripts/track/track_arcade_wheel.gd` — `fmod` spin
- `scripts/track/track_piece.gd` — pitch collision, boost Area3D
- `scripts/blender/generate_track_kit_v1.py` — ElevationBuilder / SpecialBuilder, `--extended`
- `data/track/modules/track_kit_v1.json` — ramp/jump/boost params; `pilot_ids` still 5
- `scenes/debug/Track4WheelExtendedPhysicsLab.tscn`
- `docs/TRACK_MODULAR_GEOMETRY_CONTRACT_V1.md` — pitch, ramp profile, jump gap, boost semantics
