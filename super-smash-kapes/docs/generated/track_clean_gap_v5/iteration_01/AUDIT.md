# AUDIT iteration_01 — reproduce V4 first-contact

## PRIMARY VERDICT

FAIL_FIRST_CONTACT_WRONG_PIECE (harness PASS: known-bad layout detected)

## HARNESS

V4 route (jump_small 14 m pad) through V5 lab. Scripted throttle, no drift.

## JUMP

VALID_TAKEOFF 14.17 m/s at z≈-82.73 (matches V4 14.2 m/s).
FIRST_CONTACT owner=jump_small, 4 wheels (hit_ids jump_small:4).
settle_on_landing_straight_long=false.

## 14m vs 2m

TAKEOFF_EDGE world identical (delta 0.0 m). Boost/ramp unchanged.
EXIT / landing_straight_long start move 12.0 m when pad 14→2.
All pad boxes are AFTER takeoff (along>1.2 m).
The pad is the piece EXIT, not approach.
V4 14.2→5.9 m/s was a harness throttle-policy confound (iter_03 released at takeoff, iter_05 held until first contact), not pad geometry before the lip.

## NEXT

Decompose ramp_takeoff + gap_logical. Do not retune suspension.
