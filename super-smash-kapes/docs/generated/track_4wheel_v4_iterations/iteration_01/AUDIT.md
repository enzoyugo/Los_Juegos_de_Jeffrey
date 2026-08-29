# AUDIT iteration_01 — current 4WHEEL, no physics change

## PRIMARY VERDICT

FAIL

Harness reproduced human-visible stationary creep. Jump route still lands into curve_l_45.

## STATIONARY

Current pre-fix build **reproduces measurable creep**.

yaw0_rest (fixed world camera, zero input, 10s after 2s settle):

- lateral_displacement = 0.1103 m (limit 0.02)
- forward_displacement = 0.4123 m (limit 0.02)
- yaw_delta = 12.019 deg (limit 0.25)
- final_lat_speed = 0.872 m/s (not ~0)
- net_force_x_peak = 30964 N
- contacts_stable = true (4/4)
- PASS=false

All 5 cases FAIL. overall_rest_pass=false.

## FORCE / ROOT CAUSE (hypothesis for builder)

Near-zero slip uses `atan2(v_lat, max(|v_long|, 1.0))`. The 1.0 m/s floor inflates slip angle whenever the car is nearly stopped, producing tens of kN of lateral force, yaw chatter, and self-propulsion. Linear damp 0.10 is too weak to kill the leftover. Do not freeze the body. Do not raise global LINEAR_DAMP.

## JUMP ROUTE

FAIL by architecture. SEQUENCE is jump_small → curve_l_45. No landing_straight_long. No recovery straight before curves.

## AIRBORNE / LANDING

Spawn drop emits RESET_SETTLE then TRACK_4WHEEL_LANDING with real compression. That is a settle, not a jump landing. RESET_SETTLE window is time-based and can mis-label later events. Deferred to a later iteration after creep is fixed.

## CAMERA

Not evaluated this iteration (stationary used fixed world camera as required).

## DEFECTS TO FIX NEXT

1. Near-zero tire lateral force must oppose residual velocity, not create motion.
2. Optional rest stabilization on flat, zero-input, 4-wheel grounded.
3. Reset must actually zero RigidBody velocity (PhysicsServer).
4. Do not change FRONT_GRIP / SPRING / YAW_ASSIST / ENGINE.
