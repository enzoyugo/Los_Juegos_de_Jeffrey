# TRACK 4WHEEL VISUAL TRANSFORM REPAIR + EXTENDED DYNAMICS V2

## Primary Verdict

**TRACK_4WHEEL_EXTENDED_V2_PARTIAL**

Not promoted. BASELINE remains canonical. Handling and suspension tunables were not changed.

Automated transform gates now pass (STEER/SPIN center delta **0.000 m**, SUSPENSION along +Y only, FULL follows suspension, validator **OK**). Atlas F6 success from the owner is treated as still valid (`loaded=true`, `4096×4096`, `fallback=false`, `unique=1`). Atlas architecture was not modified.

PARTIAL because:

1. Real editor F6 of `Track4WheelExtendedPhysicsLab.tscn` was **not** run in this session. Body facing is proven by measured mesh/axle geometry, not by a human screenshot.
2. CLI extended smoke ended on `straight_medium`. Jump airborne was **not** observed on the boost→ramp→gap chain. Spawn-drop `AIRBORNE_ENTER/EXIT` only proves the state machine, not the jump.

Human review of the twelve questions is still required. Do not auto-answer them.

## Minimal Atlas F6 Baseline

Owner F6 of `TrackCarMinimalAtlasLab.tscn` (Godot 4.7.2 / D3D12 / Forward+ / RTX 2060 SUPER):

- `[TRACK_ATLAS] loaded=true`
- `size=4096x4096`
- `format=CompressedTexture2D`
- `material_users=5`
- `unique_texture_resources=1`
- `fallback=false`
- `rid_valid=true`

No `mem=null`, zero-byte image, `CreateResource 0x8007000e`, or invalid RID cascade.

This sprint left atlas load/fallback/RID code untouched.

CLI re-check after transform work (`TRANSFORM_MINIMAL_D3D12.log`): same atlas lines, `fallback=false`, no `Node not inside tree`.

## Minimal Lab Camera Fix

`track_car_minimal_atlas_lab.gd` called `Camera3D.look_at()` **before** `add_child`. Godot requires the node in the tree.

Fix: `add_child(cam)` then `look_at_from_position(Vector3(4.2, 2.4, 5.6), Vector3(0.0, 0.6, 0.0), Vector3.UP)`.

CLI D3D12: 0 camera errors.

## Human Visual Defects

| Bug | Symptom | Not the cause |
|---|---|---|
| A | Articulated car looks backwards vs travel | Steering sign, throttle sign, chassis forward, `body_yaw` log line |
| B | Wheels explode / orbit / detach | Independent RigidBody wheels, suspension spring values |

Logged `body_yaw=180` with `visual_fwd=(0,0,-1)` was **misleading**. `visual_forward()` was reading Body **local +Z** after a 180° yaw, which matches chassis −Z, while the processed mesh nose already lives on **local −Z**.

## Body Orientation Investigation

Processed GLB (`track_car_base_v2_articulated.glb`):

| Fact | Value |
|---|---|
| Node graph | Body and four wheels are **siblings** (Body yaw does not move wheels) |
| FL node Z | −0.285 (front) |
| RL node Z | +0.298 (rear) |
| Body AABB Z | −0.499 … +0.499 |
| Body vertex centroid Z | **−0.057** |
| Verts with Z < −0.15 | **7400** |
| Verts with Z > +0.15 | **5981** |

Front axles and body mass both sit on **−Z**. The processed Body is already −Z-nose.

`ARTICULATED_BODY_YAW_DEGREES = 180` rotated the rendered nose to **+Z** (rear) while the log still claimed −Z. That is the backwards car.

Fix: `ARTICULATED_BODY_YAW_DEGREES = 0`. `visual_forward()` / `body_model_nose()` = `−body.basis.z`. Physics chassis was not rotated.

## Geometric Forward

```
front_mid = (FL_mount + FR_mount) / 2
rear_mid  = (RL_mount + RR_mount) / 2
geometric_forward = (front_mid − rear_mid).normalized()
```

Validator at identity spawn:

```
chassis=(0,0,-1) visual=(0,0,-1) geometric=(-0.0009,0,-1) nose=(0,0,-1) track=(0,0,-1)
```

All four agree. Do not invert FL/FR physics mounts.

## Wheel Rest Pose

Authority: **inlier vertex centroid** of each imported wheel mesh (verts within 0.12 m of the raw mean). Full AABB is polluted by leftover split verts (`r_max` up to 0.50 m on FL).

After bind, `WheelMesh.transform` is forced so `basis * centroid = −origin`. Rest locals (SpinPivot space):

| Wheel | mesh_rest | centroid |
|---|---|---|
| FL | (−0.0005, −0.0013, 0.0307) | (0.0005, 0.0013, −0.0307) |
| FR | (0.0018, −0.0017, 0.0297) | (−0.0018, 0.0017, −0.0297) |
| RL | (−0.0010, −0.0023, 0.0177) | (0.0010, 0.0023, −0.0177) |
| RR | (−0.0007, 0.0014, 0.0187) | (0.0007, −0.0014, −0.0187) |

REST_ONLY (V / 6) disables steer, spin, and suspension. Wheels stay on these rest transforms.

## Steer Pivot

`SteerPivot` at axle, identity basis, scale `ONE`, yaw about local/chassis **+Y**.

FL/FR: ±25° (`0.436 rad`) used in the validator. RL/RR: `STEER_ONLY` live path zeros steer via `apply_wheel_states`.

## Spin Pivot

`SpinPivot` at the same axle. Spin about local **+X** (measured `spin_axis=(1,0,0)` on all four). `fmod(spin, TAU)` on the pivot. WheelMesh rest is re-applied every pose so spin cannot accumulate on the mesh.

## Suspension Pivot

`SuspensionPivot.position.y = susp_m / VISUAL_SCALE` so world travel equals physics metres. Axis is mount +Y.

## Root Cause Of Wheel Explosion

Two stacked errors, not exploding RigidBodies (wheels remain `Node3D` sensors):

1. **Pivot not exactly at the measured centroid after scaled `global_transform` restore.** VisualRoot scale ≈ 4.409. A ~2–3 cm local residual becomes ~10 cm world orbit — enough to fail STEER/SPIN and look like wheels flying off.
2. **`visual_forward()` / Body 180° disagreement** made the body face the rear, so wheels at −Z looked attached to the tail.

Fix: place `WheelMount` with `parent.to_local(world_centroid)`, identity pivot chain, `reparent(..., false)`, then **force** `mesh.transform.origin = basis * (−centroid)`. Runtime never writes WheelMesh except to restore `rest_transform`.

## Transform Fix

```
WheelMount          chassis-space axle (once)
  SteerPivot        yaw only (Y)
    SuspensionPivot +Y translation only
      SpinPivot     axle rotation only (X)
        WheelMesh   frozen rest transform
```

No per-frame `rotate_*` accumulation. No double application of imported translation.

## Center-Delta Measurements

Validator `CENTER_TOL = 0.001 m`. Measured **0.000000 m**.

| | REST | STEER ±25° | SPIN 0/90/180/270/360 | SUSPENSION 0.08 m | FULL |
|---|---|---|---|---|---|
| FL | rest pose | 0.000 | 0.000 | (0, 0.08, 0) | 0.000 vs susp |
| FR | rest pose | 0.000 | 0.000 | (0, 0.08, 0) | 0.000 vs susp |
| RL | rest pose | 0.000 | 0.000 | (0, 0.08, 0) | 0.000 vs susp |
| RR | rest pose | 0.000 | 0.000 | (0, 0.08, 0) | 0.000 vs susp |

MinimalAtlasLab CLI probe: same 0.000 steer/spin deltas.

## F5 Instance Hygiene

Labs still `remove_child` + `free()` the old car. Validator: live count **1**. Extended D3D12 smoke F5 at frames 24 and 48: count stayed **1**. Historical `source_instances` may rise; live group count is the authority.

## New Modules

Generated **only** these three additional IDs (`--extended`). Total generated GLBs: **8**. `--all` still exits 2.

| piece_id | GLB | Role |
|---|---|---|
| ramp_small | `track_ramp_small_v1.glb` | Hermite takeoff |
| jump_small | `track_jump_small_v1.glb` | lip + `has_gap` + landing |
| boost_straight | `track_boost_straight_v1.glb` | 11 m road + Area3D |

## Ramp Geometry

Cubic Hermite, 1 BU = 1 m:

- `y(0)=0`, `y'(0)=0` (tangent-continuous entry)
- `y(1)=1.8 m`, `y'(1)=tan(18°)·12 m`
- EXIT pitch = **18.0°** (matches `jump_small.entry_pitch_deg`)
- Collision: short pitched boxes, top follows the profile, `MIN_GROUND_NORMAL_Y = 0.42` unchanged

## Boost Implementation

Unchanged contract:

- `apply_track_boost(direction, magnitude)`
- direction = assembled piece `−basis.z`, Y planarized
- re-entry ignored while pulse timer `> 0.08 s`
- pulse 0.55 s
- BASELINE: extra along-track accel
- 4WHEEL: `apply_central_force` at COM, not `linear_velocity = huge`

`B` toggles `TrackPiece.boost_gameplay_enabled`. Area3D `collision_layer=0`, `mask=2`.

## Airborne Behavior

Ray miss: 0 spring, 0 damper, 0 tire forces. Visual suspension extends to droop. Spin continues. Logs once:

```
[TRACK_4WHEEL] AIRBORNE_ENTER
[TRACK_4WHEEL] AIRBORNE_EXIT dt=… land_vy=… max_c=… max_f=… ang=…
```

CLI extended 4WHEEL: spawn-drop `AIRBORNE_ENTER speed=0.0` then `AIRBORNE_EXIT dt=0.383 land_vy=-3.77`. That is spawn height **1.15 m**, not the jump.

## Landing Behavior

Landing deck is flat, `landing_drop_m = 0.85`, no gap collider, no vertical lip. Success criteria for a real jump landing remain a **human F6** item. Spawn-drop reacquisition worked in CLI.

## BASELINE Extended Test

CLI D3D12 `SSK_EXTENDED_SMOKE` BASELINE: `SMOKE END` live=1, max_seam=0, no `0x8007000e`. Validates route, boost Area3D, camera, module geometry. Not a suspension reference.

## 4WHEEL Extended Test

CLI D3D12 4WHEEL: atlas `loaded=true fallback=false unique=1`, 9 pieces, all seams **0.000000 m / 0.0000°**, live=1 after F5 toggles. Car was still on `straight_medium` at smoke end — boost→ramp→jump chain **not** completed under CLI.

## D3D12

| Scene | CLI_ISOLATED | EDITOR_F6 |
|---|---|---|
| MinimalAtlasLab | PASS (atlas + 0 camera errors + 0 center delta) | Owner baseline already PASS; camera fix not re-F6'd |
| PilotLab BASELINE / 4WHEEL | PASS | ungated this session |
| ExtendedPhysicsLab BASELINE / 4WHEEL | PASS (no CreateResource) | **ungated** |
| TrackMain | PASS | ungated |
| Smash `M0Playground` | PASS | ungated |
| ZombiesMain | PASS | ungated |

Do not merge CLI and F6.

## Tests

Pytest: **283 passed** (was 282; + processed-body −Z-nose measurement).

Also: look_at-after-add_child, Hermite ramp math, `has_gap`, body yaw 0, rest_transform, centroid snap.

Path scan: `checked_refs=179 missing=0 required_missing=0`.

## Validator

`ValidateJeffreyShell.tscn` headless Compatibility:

**`[JEFFREY_VALIDATE] OK`**

STEER_ONLY / SPIN_ONLY center checks were **not** weakened. Tolerance tightened from 0.02 m to **0.001 m**. All four wheels report 0.000 m.

## Human Review Required

Open `res://scenes/debug/Track4WheelExtendedPhysicsLab.tscn` F6 (D3D12 / Forward+). Close leftover Godot processes first.

Controls: WASD, Shift drift, C reset, F3 HUD, F4 gizmos, F5 controller, V visual mode (REST/STEER/SPIN/SUSPENSION/FULL), 6–0, B boost.

Do not auto-answer:

1. Does articulated body face the correct way?
2. Are all four wheel visuals stable?
3. Do front wheels visibly steer in place?
4. Do wheels spin around their own axle?
5. Does suspension extend/compress naturally?
6. Does 4WHEEL feel planted?
7. Does boost feel controllable?
8. Does takeoff feel natural?
9. Does the car clearly become airborne on the jump?
10. Does landing feel recoverable?
11. Does the chassis visibly absorb landing?
12. Is 4WHEEL more convincing than BASELINE?

HUD should show `BODY_YAW 0`, `GEOMETRIC_FWD` ≈ `VISUAL_FWD` ≈ `CHASSIS_FWD` ≈ −Z, `CENTER_DELTA` near 0, `unique=1 fallback=false`. Magenta fallback invalidates the run.

## Known Issues

- Spawn drop still logs a short AIRBORNE pair. Ignore it when judging the jump.
- A few leftover split verts remain on wheel meshes (`r_max` ~0.5 m local). They are excluded from the axle centroid; they may still flicker far from the hub if you stare at a spinning wheel. Not a pivot orbit.
- CLI smoke does not reach the gap. Jump airborne/landing is F6-only until a longer scripted drive exists.
- Chase camera now uses rear-axle midpoint on 4WHEEL (`+Z` = rear). BASELINE still uses CameraAnchor.

## Physics Changes

**NONE**

No FRONT_GRIP / REAR_GRIP / DRIFT_REAR_GRIP / YAW_ASSIST / ENGINE_FORCE / steer curve / COM / damp / spring / travel / rest length edits.

## Recommendation

Owner F6 ExtendedLab on D3D12. Confirm questions 1–5 from V / REST→STEER→SPIN→SUSPENSION, then drive boost→ramp→jump. If facing and wheels look correct and the jump goes 0/4 grounded then recovers, this can be promoted to `TRACK_4WHEEL_EXTENDED_V2_READY_FOR_HUMAN_REVIEW` without further transform work.

Until that F6 pass: remain **PARTIAL**. 4WHEEL stays parallel. BASELINE stays canonical.
