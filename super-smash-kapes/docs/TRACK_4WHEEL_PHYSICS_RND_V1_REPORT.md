# TRACK 4-WHEEL PHYSICS R&D V1

## Primary Verdict

TRACK_4WHEEL_PHYSICS_V1_READY_FOR_A_B_REVIEW

HUMAN_A_B_DRIVE_REVIEW_REQUIRED

This controller is **not** canonical. Production TrackMain stays BASELINE until a human A/B drive says otherwise.

## Baseline

- Current Track path: `TrackCarController` / `scenes/track/TrackCar.tscn`
- Marked `BASELINE_TRACK_CONTROLLER`
- `TrackConfig.CONTROLLER_MODE := "BASELINE"`
- Latest prior gate: TRACK_TEXTURE_ROAD_GHOST_V1_READY_FOR_HUMAN_REVIEW
- pytest suite kept; 4-wheel tests added
- Validator still requires Smash 2 fighters / 3 stocks / original spawns, Zombies load, road 11.0 m, ghost ACTIVE/YA start, shared atlas

## Blender Processing

See `docs/TRACK_CAR_ARTICULATED_V2_REPORT.md`.

- Source `track_car_base_v1.glb` untouched (SHA256 `b1dd649b39b0c701ccb5b11062b7087579702caa930d8a0b436dd4d581e725af`)
- Processed `res://assets/vehicles/track/processed/track_car_base_v2_articulated.glb`
- Five objects: Body + four wheel assemblies
- One shared material / one 4K atlas
- Tool: `tools/separate_track_car_wheels.py` (Blender 2.83)

## Wheel Geometry

Authoritative processed translations, then VisualRoot scale + offset (no 180° yaw on articulated):

| Wheel | Processed local | Chassis mount (m) |
| --- | --- | --- |
| FL | (-0.201, 0.085, -0.285) | (-0.886, 0.425, -1.256) |
| FR | (0.204, 0.085, -0.285) | (0.899, 0.425, -1.256) |
| RL | (-0.202, 0.085, 0.298) | (-0.891, 0.425, 1.314) |
| RR | (0.203, 0.085, 0.298) | (0.895, 0.425, 1.314) |

- Radius 0.35 m
- Steer pivot +Y, spin +X
- Source fused mesh still `WHEEL_STRUCTURE = FUSED_BODY_MESH` (ingest tests unchanged)

## Architecture

- One `RigidBody3D` chassis: `TrackWheelCar` / `TrackCarWheelPhysics.tscn`
- Four `TrackArcadeWheel` Node3D sensors (not RigidBodies, no joints)
- Collider remains BoxShape3D 1.80 × 0.82 × 3.55 at (0, 0.48, 0)
- Not `VehicleBody3D`
- Baseline `CharacterBody3D` controller is unmodified aside from a comment marker

## Suspension

Per-wheel downward `RayCast3D` (ShapeCast deferred: four rays are cheap and stable).

- rest_length 0.12 m, travel 0.14 m
- spring 32000, compression damper 3100, rebound 2400
- force along contact normal, applied at the contact point
- rail *sides* ignored via `normal.y < 0.42`
- load ≈ suspension force, used to scale tire force

## Tire Model

Arcade slip curve (not Pacejka), sampled in `TrackWheelPhysicsConfig.slip_curve_sample`:

0°→0, 2°→0.6, 5°→1.0, 10°→0.9, 20°→0.65, 30°+→0.45

Lateral force opposes lateral velocity and is applied at the wheel point. No direct chassis lateral-velocity overwrite.

Front grip 9200, rear 8600 (tunable). Max clamps per wheel.

## Steering

Front rays stay chassis-down. Tire forward/right rotate by steer angle around chassis up.

Speed-sensitive max steer: 0.55 rad low speed → 0.18 rad high speed. Smoothed. Shared angle both fronts (no Ackermann).

## Drivetrain

`DRIVE_TYPE = AWD` (configurable AWD / RWD / FWD). Engine force 6200 N total, split across driven wheels. High-speed scale 0.38, no hard velocity cut. Max speed 54 m/s to match V2 arcade target.

## Braking

Opposite longitudinal velocity while `forward_speed > 1.8`. Near zero, reverse force 2400 N. Applied through wheels. Same Track inputs as baseline (`S` / down).

## Drift

States: GRIP / DRIFT_ENTRY / DRIFT / DRIFT_RECOVERY / AIRBORNE

Entry: speed > 14, |steer| > 0.28, brake or `track_drift` (Shift).

Rear grip only: lerp to `DRIFT_REAR_GRIP = 0.38`. Front stays at 1.0.

Countersteer raises rear grip toward 0.72. Release → recovery over 0.42 s.

Primary yaw is tire forces. **Secondary** yaw-assist torque (`YAW_ASSIST_TORQUE` 420, plus 280 in drift) is documented and clamped (`MAX_YAW_RATE` 3.4). It is not the turn engine.

## Anti-roll

Front 5200 / rear 4600. Left vs right compression difference applies opposing point forces.

## Downforce

`DOWNFORCE * speed²` at COM, grounded wheels only. Must not overpower springs.

## Airborne / Landing

No ray hit → no tire / suspension force. Optional tiny air yaw (`AIR_CONTROL`). Landing uses compression damping + force clamp. Global physics tick unchanged (Smash-safe).

COM custom offset `(0, -0.12, 0.06)`. Angular damp 1.55.

## Visual Articulation

Articulated GLB bound under VisualRoot (`use_articulated = true`, yaw 0).

Wheels follow physics steer / spin / suspension length. Body is the chassis visual (physics roll/pitch, no extra fake tilt).

Ghosts stay on the fused source visual, Node3D playback, **no** wheel physics / no extra RigidBody.

## TrackWheelPhysicsLab

`res://scenes/debug/TrackWheelPhysicsLab.tscn`

- A straight, B slalom, C sweeper, D hairpin, E drift, F bumps, G jump, H rails
- Road width 11.0 m, shoulders 0.7, rails 0.9 m
- F5 A/B BASELINE vs 4WHEEL_V1 (no restart)
- F3 HUD, F4 collider, C reset
- Same chase camera for both
- Same Track input map

## A/B Integration

- Lab: F5
- TrackMain default: still `TrackCar.tscn`
- Optional: `SSK_TRACK_CONTROLLER=4WHEEL` (or `FOUR_WHEEL_V1`)
- Do not promote without human drive

## Texture Sharing

- Baseline still `preload`s source GLB (required by existing tests)
- Articulated is `load()`ed only when `use_articulated`
- Player materials still unique + shared `_shared_atlas` (no `src.duplicate()`)
- Ingest / validator share-check still requires one atlas RID
- A/B lab instantiates one car at a time

## Ghost Compatibility

- `TrackGhostPlayer` unchanged: no `TrackWheelCar` / `TrackArcadeWheel`
- Race clock PREPARE / COUNTDOWN hidden; ACTIVE / YA starts ghosts, input, timer, fuel together

## Tests

`python -m pytest tests/test_m0_combat.py tests/test_jeffrey_multimode_shell.py tests/test_jeffrey_shell_v2.py tests/test_jeffrey_global_ui_v1.py tests/test_jeffrey_global_ui_transitions_v1.py tests/test_track_greybox_v1.py tests/test_zombies_greybox_v1.py tests/test_ui_track_game_feel_v1.py tests/test_track_car_base_v1_ingest.py tests/test_track_texture_road_ghost_v1.py tests/test_track_4wheel_physics_v1.py -q --tb=line`

**116 passed**

## Validator

`ValidateJeffreyShell.tscn` headless, `--rendering-method gl_compatibility --audio-driver Dummy`

**`[JEFFREY_VALIDATE] OK`**

Includes Smash 2 fighters / 3 stocks / original spawns, Zombies load, road 11.0, ghost clock, shared atlas, 4-wheel scene/lab, BASELINE still canonical.

Runtime log: `articulated_wheel_binds=4` when `use_articulated` is set. Atlas ID shared across player/ghost/4-wheel materials.

## Performance

- 4 raycasts on the single hotseat physics car
- Ghosts are visuals only
- No global physics tick change

## Known Issues

- Human D3D12 window still not certified (prior sprint)
- Yaw-assist is present (secondary). If the car still feels “rotated by code”, lower `YAW_ASSIST_TORQUE` toward 0
- RayCast not ShapeCast; edge crests may be slightly less stable
- Articulated round-trip flipped model forward to −Z; fused source still needs 180° yaw
- Wheel visual split is torus-based, not a full mechanical brake-disc CAD separation
- Debug force lines not shipped
- 4-wheel handling is first-pass arcade tune, not a claim of “more fun”
- Articulated GLB import uses `gltf/embedded_image_handling=3` (embed uncompressed). Extract-to-JPEG was tried and hit a WebP pack failure; sidecar atlas was removed so D3D12 cloning is not reintroduced via a second 4K file
- Ingest lab still dumps the raw fused source tree on stdout; key 3 is the articulated preview

## Human A/B Review Required

Drive BASELINE then 4WHEEL_V1 in `TrackWheelPhysicsLab` (F5). Compare acceleration, steering, planted feel, drift, suspension, recovery, speed, fun.

Do not replace canonical TrackMain from this report.

## Recommendation

Keep BASELINE canonical. Use 4WHEEL_V1 only in the physics lab / env override until a human signs off.
