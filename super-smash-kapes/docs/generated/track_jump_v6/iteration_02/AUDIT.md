# AUDIT iteration_02 — physics mount symmetrize

## Hypothesis

13 mm FL/FR physics-mount asymmetry (V3 visual translations scaled) causes tire yaw from spawn. Boost torque is 0. Zero-steer did not remove yaw. Symmetrize physics ray mounts only; V3 visual unchanged.

## PRIMARY VERDICT

FAIL_FIRST_CONTACT_WRONG_PIECE (lateral PASS; flew over 36 m deck onto recovery)

takeoff speed=29.20 vx=0.000007 yaw=-0.00009°

## Longitudinal findings

Clean aligned takeoff increases ballistic range:

- t_hit = 1.833 s
- predicted range from lip = 55.81 m
- predicted hit x = 0.000036 (centerline)
- 10+36 geometry: contact ~46 m into / past 36 m deck → first wheel on `straight_medium` recovery

## Lateral findings

Physics mounts now FL/FR/RL/RR |x|=0.8927.

Takeoff |vx| << 0.5, |yaw| << 1°. TRACK_TAKEOFF_LATERAL_STATE and TRACK_TAKEOFF_YAW_STATE pass.

Tire lateral integrals at boost entry were 0.

## Changes

SSK_V6_SYM_MOUNTS=1. No spring/grip/COM/yaw-assist retune. No road widen. No V3 rebuild.

## Landing geometry calibration (next)

Need gap/deck so first contact remains landing_straight_long at ~1/3 with ≥20 m remaining.

Measured range ~56 m from lip. Plan: gap=30 m, deck=60 m → station ~26 m (43%), remaining ~34 m.

## Auditor verdict

Lateral root cause confirmed and repaired. Do not roll back mounts. Iterate landing capture only.
