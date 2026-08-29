# Track Game Feel — Baseline V1

Recorded **before** the handling rewrite. Source: `track_car_controller.gd` + `track_config.gd` as of overnight greybox.

## Implementation

- Body: `CharacterBody3D` + `move_and_slide`
- Velocity is written directly (not RigidBody forces)
- Forward = `-basis.z` (planar)
- Steer: `rotate_y(-steer * steer_scale * sign(along) * dt)` when `|along| > 0.4`
- Then reconstruct planar velocity as `forward * along + right * lateral`
- Lateral: `move_toward(lateral, 0, LATERAL_GRIP * dt)` with `LATERAL_GRIP = 9.8`
- Accel: constant `along += ACCEL * throttle * dt`, clamp to `MAX_SPEED`
- Brake: if `along > 0.25` subtract BRAKE, else reverse
- No input smoothing, no yaw damping, no velocity-to-heading align, no downforce, no collision lateral recovery
- Camera: exponential follow of a point behind the car; look-ahead along heading; no FOV change

## TRACK_HANDLING_BASELINE

| Key | Value |
| --- | --- |
| ACCEL | 48 |
| MAX_SPEED | 36 |
| BRAKE | 55 |
| REVERSE_ACCEL / REVERSE_MAX | 22 / 10 |
| STEER_LOW / STEER_HIGH | 2.15 / 0.72 |
| STEER_SPEED_REF | 28 |
| LATERAL_GRIP | 9.8 |
| COAST_FRICTION | 5.5 |
| GRAVITY | 32 |
| CAM_DISTANCE / HEIGHT / LOOK_AHEAD / FOLLOW | 8.6 / 3.15 / 11 / 11 |

## Why it felt like soap

1. **Yaw without tire redirect.** Steering rotated the mesh while the velocity vector stayed in the old direction, so every input injected slip.
2. **Weak lateral kill.** `move_toward` at 9.8 m/s² needs ~1.8s to dump 18 m/s of side speed. That is ice, not asphalt.
3. **No self-align.** Releasing steer left residual lateral forever (until the slow damp finished).
4. **Binary keyboard steer** mapped 1:1 into yaw. Instant max steer at any speed.
5. **Brake could invert** into reverse above walking speed (`along > 0.25`).
6. **Camera lagged** on a heading-only back vector, which exaggerates sideways motion.

These constants remain in `TrackConfig` as `BASELINE_*` for rollback.
