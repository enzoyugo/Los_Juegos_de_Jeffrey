# TRACK ARTICULATED CAR ASSET INTEGRITY V3 AND DYNAMICS SANITY REPORT

## Primary Verdict

**TRACK_ARTICULATED_V3_READY_FOR_HUMAN_REVIEW**

## Human Video Defects

V2 backwards body; stray wheel sheets; spin triangles; center-delta insufficient; AIRBORNE_ENTER speed=0; landing max_f with max_c=0; camera lost jump context; V2 split leftovers.

## V2 Root Cause

`select_linked` contamination + leftover verts at ~0.47 m local, plus centroid/Z-flip “nose” that placed the wing on −Z.

## Semantic Nose Authority

Source-after-180° visual + high-Y wing at +Z + `NOSE_MARKER`/`REAR_MARKER`. Not centroid. Not wheel labels.

## Source vs V3

Front camera: both cars show bumper/headlights. Rear camera: both show wing/exhaust.

## V3 Build Pipeline

Immutable source → `build_track_car_articulated_v3.py` face split → geometry-only GLB.

## Body Mesh Integrity

Complete nose/rear/wing/shell. Wheel wells empty for articulation.

## Wheel Mesh Integrity

### FL / FR / RL / RR

See `TRACK_CAR_V3_MESH_OWNERSHIP.json` and `docs/TRACK_CAR_ARTICULATED_V3_ASSET_INTEGRITY_REPORT.md`. Compact AABB, max_r bounded, 0 outliers, spin sweep pass.

## Pivot / Origin State

Authored axle. Runtime rest ≈ 0. No centroid hack.

## Spin Sweep

Pass. Δr = 0.

## Runtime Visual Hierarchy

WheelMount / SteerPivot / SuspensionPivot / SpinPivot / WheelMesh. VisualRoot scale only. `physics_meters_to_visual_local`.

## Camera Semantics

Extended lab: behind REAR_MARKER toward NOSE_MARKER. K = CHASE / CHASE_CLOSE / LANDING_SIDE. TrackMain unchanged.

## Boost Forward Validation

Logged dots vs chassis and semantic forward; fail if negative.

## Airborne State Machine

Debounced reporting. Reasons including SPAWN_SETTLE. No ENTER without EXIT.

## Zero-Speed Airborne Events

Spawn/reset classified; not counted as jump. Stationary after settle should not re-enter.

## Jump Classification

TAKEOFF_ZONE → airborne → LANDING_ZONE = VALID. Else OFFTRACK_AIRBORNE.

## Landing Compression Telemetry

0.40 s post-contact window. Per-wheel peak_c / peak_f. Same `compression_m` as spring and visual.

## Visual Suspension Mapping

`susp = rest - length` = compression_m. Local Y = physics_meters_to_visual_local(susp).

## D3D12 / Atlas

Unchanged. V3 no embed. Shared atlas.

## Tests

New V3 pytest module. Existing suite extended.

## Validator

Old gates kept. New V3 / semantic / radius / landing / airborne / jump / camera gates.

`[JEFFREY_VALIDATE] OK` after V3 import and the `airborne: bool` parse fix in `track_4wheel_extended_physics_lab.gd`.

## Human F6 Status

**NOT DONE.** Automated loop complete. Owner must F6 IntegrityLab then ExtendedPhysicsLab and answer the ten questions. This report does not answer them.

## Known Issues

Low-poly source tires. SPAWN_SETTLE drop from spawn height 1.15 m.

## Recommended Next Action

Human visual certification. Then, only if that passes, a later handling-tune sprint. Do not promote 4WHEEL now.
