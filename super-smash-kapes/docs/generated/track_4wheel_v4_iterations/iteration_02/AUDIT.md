# AUDIT iteration_02 — low-speed tire blend + rest stabilization + long deck

## PRIMARY VERDICT

FAIL (jump settle). Stationary creep gate PASS.

## STATIONARY

Harness that failed in iteration_01 now PASSES after near-zero slip blend + rest stabilization.

yaw0_rest: lateral=0.0000 m, forward=0.0000 m, yaw_delta=0.000°, final_lat_speed=0, PASS=true

yaw ±5° rest: PASS

impulse ±0.2 m/s: settles, final_lat_speed=0, lateral remaining 0.0155 m (limit 0.02), PASS=true

throttle_launch: speed immediately overcomes rest (forward 24.5 m in 2 s), PASS=true

steer_at_rest: lateral_displacement=0.0000 m, PASS=true

RESET_SETTLE only after explicit reset_to generations 1–7. Landing SKIP for settle. No freeze.

## JUMP

Route now has landing_straight_long before curves. Seams 0.

VALID_TAKEOFF at 14.2 m/s.

FIRST_CONTACT piece=landing_straight_long, 4 wheels, peak_c=0.074, peak_f up to 18000 N (real suspension).

Then bounce AIRBORNE and MISSED_LANDING_LEFT (x=-6.24). SETTLED=false. PASS=false.

Hypothesis: jump_small still owns a 14 m land pad; nearest-origin piece id can label jump-pad contact as the long deck; full throttle held through landing launches a bounce.

## DEFECTS TO FIX NEXT

1. Shorten jump_small land pad so ballistic first contact is on landing_straight_long.
2. Piece location by along-track local Z, not distance to origin.
3. Jump-validate driver: release throttle after VALID_TAKEOFF so landing is not a powered bounce.
4. Do not change FRONT_GRIP / SPRING / YAW_ASSIST / ENGINE.
