# Track Game Feel V1

## Baseline Problem

The greybox car yawed like a mesh and slid like a puck. Human report: “doesn't feel like driving… a piece of soap.”

See `docs/TRACK_GAME_FEEL_BASELINE_V1.md`.

## Current Physics Model

Arcade `CharacterBody3D`. Velocity is split into **forward** and **lateral** every physics frame.

1. Smooth digital steer (`STEER_RESPONSE`).
2. Speed-sensitive yaw authority (smoothstep from `STEER_LOW` → `STEER_HIGH`).
3. Exponential **lateral grip** (`damp_lateral`).
4. **Velocity align**: lerp planar velocity toward the car forward axis (arcade tires).
5. Accel tapers near `MAX_SPEED`.
6. Brake is strong while `along > REVERSE_ENTER_SPEED`; reverse only after that.
7. Yaw damping toward the velocity heading when steer is released.
8. Collision: extra lateral damp after `move_and_slide`.
9. Mild floor-snap increase with speed (arcade downforce).
10. Optional drift: brake + steer + speed reduces grip and slightly raises yaw.

Helpers live in `track_handling.gd` so they can be tested without Godot physics.

## Root Causes Found

- Lateral grip 9.8 was an order of magnitude too weak for arcade planting.
- `rotate_y` did not redirect velocity.
- No yaw settle on release.
- Camera follow (11) + no FOV made slip read worse than it was.

## Changes

- New `TrackHandling` math + `TRACK_HANDLING_V1` constants.
- Baseline constants kept as `BASELINE_*`.
- Chase camera: yaw lag toward the car, tighter follow, FOV 68→78.
- Cheap wheel steer/spin + slight body roll.
- `slip_amount` / `drift_amount` exposed for later FX.
- `TrackPhysicsLab.tscn` with a fixed (non-generated) course + F3 debug HUD.

## Config Before

See baseline table. Live `ACCEL` was 48, `LATERAL_GRIP` 9.8.

## Config After (TRACK_HANDLING_V1)

| Key | Value |
| --- | --- |
| ACCEL | 58 |
| HIGH_SPEED_ACCEL_SCALE | 0.38 |
| MAX_SPEED | 38 |
| BRAKE | 72 |
| REVERSE_ACCEL / MAX / ENTER | 18 / 9 / 1.6 |
| STEER_LOW / HIGH / REF / RESPONSE | 2.55 / 0.88 / 30 / 12 |
| LATERAL_GRIP | 16.5 |
| DRIFT_GRIP | 6.2 |
| VELOCITY_ALIGN | 9.0 |
| YAW_DAMPING | 3.4 |
| LINEAR_DRAG | 1.15 |
| CAM_FOLLOW / YAW_LAG | 16 / 8.5 |
| CAM_FOV | 68–78 |

Fuel multiplier unchanged: `expected_time * 2.75` (**provisional**).

## Physics Lab

`res://scenes/debug/TrackPhysicsLab.tscn`

Straight, sweep, hairpin, chicane, jump, downhill, wall recovery. No generator. WASD. F3 debug overlay.

## Camera

Third-person chase only. Heading-based look-ahead. Controlled yaw lag. Modest speed FOV. Not human-approved.

## Drift

Not a dedicated button. Brake + steer + speed > 10 lowers grip. Release restores grip. Unverified by a driver.

## Collision Recovery

Extra lateral damp after slide collisions. No teleport.

## Known Issues

- Handling is **implemented**, not human-driven.
- Lab course is box greybox, not art.
- Wheel visual is cylinders, not a vehicle rig.
- Keyboard is still digital underneath the smoother.
- Generator was **not** expanded this sprint.

## Manual Validation Needed

```text
TRACK_GAME_FEEL_V1_IMPLEMENTED
HUMAN_DRIVE_REVIEW_REQUIRED
```

Checks a human should run in the lab: straight (no unexplained drift), gentle corner, hairpin + brake, chicane, release-steer settle, wall recovery, high-speed stability.
