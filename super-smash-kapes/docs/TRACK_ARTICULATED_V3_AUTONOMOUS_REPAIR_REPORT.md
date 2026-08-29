# TRACK ARTICULATED V3 AUTONOMOUS REPAIR REPORT

## Primary Verdict

**TRACK_ARTICULATED_V3_AUTONOMOUS_REPAIR_READY_FOR_HUMAN_REVIEW**

The audit harness fails current V2. V3 passes the same harness. Source vs V3 front/rear match. Isolated wheels are compact. Runtime 4WHEEL visual candidate is V3. BASELINE is unchanged. 4WHEEL is not promoted.

Human F6 of IntegrityLab then ExtendedPhysicsLab is still the visual certification gate. Do not treat this file as a substitute for those ten questions.

## Iterations

### Iteration 01 — V2 baseline

**Result: FAIL** (required harness self-check)

Defects: all four wheels fail AABB, radius, stray components, thin/long faces, spin sweep; embedded 4K image; FRONT camera shows the **rear** of the car vs source-after-180°.

Visual: FL/FR sheets; RL_090 spike; body_only_front is the rear fascia.

Fixes: none (reproduce only).

### Iteration 02 — V3 first split

**Result: FAIL** (auditor visual / ownership)

Automated radius/AABB/sweep: pass. Semantic morphology: pass. Front/rear match source.

Named defects:

- `KEEP_IN_ENVELOPE_WHEEL_COMPONENTS` — 908 in-envelope hub islands reassigned to Body (`centroid_r > 0.72 * r_max`).
- `RENDER_WHEELS_ALONG_AXLE` — isolation camera was FRONT (edge-on I-profile), not along +X.

### Iteration 03 — keep hub islands + axle-view renders

**Result: PASS** (geometry + semantic + isolated circular wheels)

Body 7655 / FL 2636 / FR 2568 / RL 2674 / RR 2636. Discarded 0. Markers −Z forward.

No further geometry iteration.

## Best Candidate

`assets/vehicles/track/processed/track_car_base_v3_articulated_clean.glb`

V2 kept at `track_car_base_v2_articulated.glb` for rollback/debug (`PROCESSED_ARTICULATED_V2_GLB`).

## Semantic Orientation

Source + 180° Y is the visual authority. V3 is exported in that space. `NOSE_MARKER − REAR_MARKER` is runtime semantic forward. Chassis −Z. No Body yaw, no throttle/steer invert.

## Wheel Geometry Integrity

Face-level ownership. Compact AABBs. max radius source ≤ 0.0953 (~0.42 m world). No unexplained outliers.

## Spin Sweep

Δr = 0 over 24 samples around +X.

## Runtime Pivot Integrity

WheelMount from authored axle translation. WheelMesh rest = identity. No inlier-centroid snap. Suspension uses `physics_meters_to_visual_local`.

## Airborne State

GROUNDED / AIRBORNE reporting with 3-frame debounce. Reasons: SPAWN_SETTLE, RESET_SETTLE, TRACK_AIRBORNE, JUMP_AIRBORNE (lab hint), OFFTRACK_AIRBORNE. One ENTER until EXIT. Physics contacts remain exact (no airborne tire forces).

## Landing Telemetry

`AIRBORNE_EXIT` no longer prints first-contact `max_c`. A 0.40 s window samples per-wheel peak compression/force, then `[TRACK_4WHEEL_LANDING]`.

Compression authority: `compression_m = clamp(rest_length - contact_length, 0, travel)` in `TrackArcadeWheel`. Visual suspension uses the same `rest - length`.

## Boost Direction

On pulse: `dot(boost_dir, chassis_forward)` and `dot(boost_dir, semantic_forward)` logged; error if negative.

## Camera

Extended lab only: `TrackExtendedDebugCamera`. Behind `REAR_MARKER`, look at `NOSE_MARKER`. **K** cycles CHASE_STANDARD / CHASE_CLOSE / LANDING_SIDE. TrackMain camera unchanged.

## Jump Classification

Debug `TAKEOFF_ZONE` / `LANDING_ZONE` on `jump_small`. Logs `VALID_TAKEOFF` / `VALID_LANDING` / `OFFTRACK_AIRBORNE`. F4 shows zones. No new track pieces.

## Atlas / D3D12

Unchanged architecture. V3 has no embedded texture. Import discards images. Shared canonical atlas.

Headless ValidateJeffreyShell after V3 import:

- `loaded=true`
- `4096x4096`
- `unique_texture_resources=1`
- `fallback=false`
- `rid_valid=true`
- no `CreateResource` / `0x8007000e`

## Tests

`tests/test_track_car_articulated_v3.py` (10 passed) plus existing 4WHEEL tests updated for V3 bind (no `keep_global` centroid hack).

## Validator

Added V3 file, labs, semantic −Z, compact world radius, landing window, debounce, jump zones, KEY_K. Old STEER/SPIN center ≤ 0.001 m kept.

`[JEFFREY_VALIDATE] OK`

Runtime bind: `semantic_fwd=(0,0,-1)`, `mesh_rest=(0,0,0)`, STEER/SPIN center delta `0`, world radius ≈ `0.42 m`, `live_track_car_count=1`. AIRBORNE_ENTER/EXIT used `RESET_SETTLE` (classified), not jump spam.

GDScript parse fix required for 4.7 inference: `track_4wheel_extended_physics_lab.gd` typed `airborne: bool` from `.get()`.

## Human F6 Gate

Open, in order:

1. `scenes/debug/TrackCarArticulatedIntegrityLab.tscn`
2. `scenes/debug/TrackCarSemanticOrientationLab.tscn`
3. `scenes/debug/Track4WheelExtendedPhysicsLab.tscn`

Questions for the owner only (not auto-answered):

1. Is the nose finally pointing forward?
2. Is the camera behind the actual rear?
3. Does each isolated wheel look like only a wheel?
4. Does any wheel create triangles/spikes while spinning?
5. Do front wheels steer in place?
6. Does boost push the car toward its nose?
7. Does the intended jump cross the actual gap?
8. Is landing on the intended landing deck?
9. Do you visibly see suspension compress?
10. Are there any speed=0 airborne spam events after settle?

## Known Issues

- Source tire is low-poly; do not confuse faceting with V2 sheets.
- Spawn from y=1.15 still produces a classified `SPAWN_SETTLE` airborne pair; that is not a jump.
- IntegrityLab V2 instance uses identity rest on dirty V2 meshes on purpose (forensic spin).

## Next Recommended Action

Human F6 the two labs. If those ten questions pass, handling tune can be a **later** sprint. Do not promote 4WHEEL. Do not retune springs/grip in this pass.
