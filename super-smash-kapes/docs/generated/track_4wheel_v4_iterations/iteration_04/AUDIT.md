# AUDIT iteration_04 — 2 m pad, throttle until takeoff

## PRIMARY VERDICT

FAIL

## JUMP

Takeoff still 5.9 m/s at z=-82.74 (same place as iteration 02's 14.2 m/s takeoff).
Shortening jump_small land to 2 m regresses approach speed / ballistic window.
MISSED_LANDING_LEFT. No FIRST_CONTACT.

## ROLLBACK

Restore jump_small land_length 14 m (iteration 02 geometry).
Keep landing_straight_long before curves.
Keep along-track piece location.
Iteration 05: 14 m pad + release throttle after FIRST_CONTACT to stop the bounce.

## STATIONARY

Not re-measured. Iteration 02 rest PASS remains.
