# AUDIT iteration_04 — 3/3 nominal

## Hypothesis

Same layout as iter 03. Three identical scripted jumps.

## PRIMARY VERDICT

FAIL 2/3. Run 1 PASS, run 2 FAIL_UNDERSHOOT, run 3 PASS.

## Longitudinal findings

Run 1 and 3 identical: takeoff 29.20, station 19.97, SETTLED.

Run 2: boost area `body_entered` did not re-fire after `reset_to` teleport. Boost exit speed 19.3 vs 34.8. Takeoff 15.71 m/s, range 11.6 m, undershoot.

## Changes

None this iteration (diagnosis only). Next: re-apply boost on BOOST_ENTRY if pulse is inactive after reset. Not a handling retune.

## Auditor verdict

Nominal physics is repeatable when boost fires. Multi-run harness must re-arm boost after teleport. Do not roll back gap/deck/mounts.
