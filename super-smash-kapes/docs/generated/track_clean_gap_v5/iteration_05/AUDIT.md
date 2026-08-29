# AUDIT iteration_05 — light center, no ramp rails, gap 10 m (best V5)

## PRIMARY VERDICT

FAIL_OFFTRACK

Best candidate for geometry. Settle not achieved. Max iterations.

## CHANGE

ramp_takeoff guardrails=false. TAKEOFF_ZONE width 16 m. Light flat-only center-hold. Gap 10 m.

## GEOMETRY

gap_empty=true.
takeoff_edge unchanged vs V4 (-81.2 m).
landing_straight_long is first physical road after gap.

## JUMP

VALID_TAKEOFF 28.58 m/s, x=-0.63, vx=-3.29, yaw=5.8°.
Airborne forces spring=0 damper=0 tire=0.
FIRST_CONTACT landing_straight_long (collider owner), 1 wheel then 2.
peak_c RR=0.085 m, peak_f=18 kN (valid compression).
Contact 32.9 m onto 36 m deck (near exit), x=-5.27, yaw=9.7°.
Left boundary crossed before SETTLED. time_to_4=-1.

## CAUSE

Clean-lip speed ~28.6 m/s produces ~40 m range. 10 m gap + 36 m deck puts touchdown at the last 3 m.
Residual vx/yaw from the approach grows x from -0.63 to -5.3 in 1.68 s, then off the 11 m deck.
Not a first-contact geometry miss. Not a suspension-constant defect (compression/force present).
Do not retune springs to hide lateral miss.

## READY

No. TRACK_CLEAN_GAP_LANDING_V5_BLOCKED.
