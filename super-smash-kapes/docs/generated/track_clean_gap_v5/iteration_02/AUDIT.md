# AUDIT iteration_02 — ramp_takeoff + gap_logical 7 m

## PRIMARY VERDICT

FAIL_BODY_CONTACT_BEFORE_WHEEL

## CHANGE

Replaced jump_small with ramp_takeoff (EXIT=TAKEOFF_EDGE) and gap_logical (no road collision). Gap 7 m.

## GEOMETRY

gap_empty=true (Godot AABB sweep).
takeoff_edge z=-81.20 (same as V4).
landing_start z=-88.20.

## JUMP

VALID_TAKEOFF 27.73 m/s (clean lip; V4 14.2 m/s was early launch off jump_small seam).
FIRST_CONTACT owner=landing_straight_long (4-id authority).
Airborne spring/tire=0.
Then chassis hit landing rail at x=-6.19 (left drift, 35.7 m onto 36 m deck).

## NEXT

Center driver on flats only; lengthen gap so contact is mid-deck. No suspension tune.
