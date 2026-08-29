# AUDIT iteration_05 — restore 14 m pad, throttle release after first contact

## PRIMARY VERDICT

FAIL — jump SETTLED / first-contact-on-landing_straight_long not achieved. Max 5 iterations.

## CHANGE

Rolled back jump_small land_length to 14 m (2 m pad caused 5.9 m/s takeoff).
Hold throttle until FIRST_CONTACT, then release.
Along-track piece location kept.

## STATIONARY

Not re-run. Iteration 02 overall_rest_pass=true remains.

## JUMP

VALID_TAKEOFF 14.2 m/s.
FIRST_CONTACT on jump_small (4 wheels, peak_c≈0.07, peak_f 13–18 kN) — real suspension, but on jump_small's own pad, not landing_straight_long.
Bounce TRACK_AIRBORNE, then contact on landing_straight_long with peak_c=0 in the post-bounce window (NO_VALID_CONTACT). SETTLED=false.

## REGRESSION

V3 mesh_rest still (0,0,0). Atlas 4096 unique=1 fallback=false in prior lab runs. Handling constants unchanged.

## AUDITOR

Jump remain-on-deck: FAIL.
Stationary creep: PASS (iteration 02).
Ready gate: FAIL. Stop.
