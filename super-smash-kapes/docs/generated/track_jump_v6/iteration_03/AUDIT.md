# AUDIT iteration_03 — landing capture calibration

## Hypothesis

With centered takeoff (iter 02), ballistic range from lip is 55.8 m. Gap 10 + deck 36 overshoots. Calibrate gap=30 m, deck=60 m (extra 24 m parented to landing_straight_long). Zero steer. Physics mounts remain symmetrized.

## PRIMARY VERDICT

PASS_SETTLED

takeoff 29.20 m/s vx≈0 yaw≈0 first_contact=landing_straight_long station=19.97 remain=40.03

## Longitudinal findings

Predicted deck station 25.81 / actual 19.97 (6 m early). Still inside first third of 60 m. Airborne forces 0.

TAKEOFF_EDGE / boost / ramp unchanged. Landing start z -91.2 → -111.2 (gap +20 m only).

## Lateral findings

x at contact 0.00005. x_peak 0.068 m. Left/right lat impulse equal ~0.012.

## Changes

SSK_GAP_LENGTH=30, SSK_LANDING_EXTRA_M=24, SSK_V6_STEER=zero, SSK_V6_SYM_MOUNTS=1.

Gap 30 m is a real unsupported stunt at 4.4 m car scale (not a 1 m trickle).

## Compression / settle

peak_c RL/RR=0.14 m, FL/FR≈0.053 m. peak_f rear 18 kN. time_to_4=6.22 s. No second airborne. SETTLED on landing_straight_long.

## Auditor verdict

Nominal single run PASS. Next: 3/3 identical nominal.
