# AUDIT iteration_03 — shorten jump land pad

## PRIMARY VERDICT

FAIL

## CHANGE

jump_small land_length 14 m → 2 m so ballistic contact targets landing_straight_long.
Piece location uses along-track local Z.
Jump-validate released throttle at VALID_TAKEOFF (too early).

## STATIONARY

Not re-measured. Iteration 02 rest PASS remains the candidate.

## JUMP

VALID_TAKEOFF at 5.9 m/s (too slow vs 14–20 m/s window).
MISSED_LANDING_LEFT. No valid landing.

## NEXT

Keep 2 m land pad. Hold throttle until FIRST_CONTACT, then release so landing can settle.
Do not retune grip/spring/COM.
