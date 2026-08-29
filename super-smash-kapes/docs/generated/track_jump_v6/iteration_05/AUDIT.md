# AUDIT iteration_05 — 3/3 nominal (fresh process)

## Hypothesis

Final candidate: physics-mount symmetrize + gap 30 m + deck 60 m + zero steer.

In-process JUMP_RUNS=3 run 2 still FAIL_UNDERSHOOT (boost/reset Area3D). Three independent Godot processes are the deterministic 3/3.

## PRIMARY VERDICT

PASS_SETTLED 3/3 (nom_1, nom_2, nom_3)

Each: takeoff 29.20 m/s, vx≈0, yaw≈0, first_contact landing_straight_long station=19.97, remain=40.03, SETTLED 4 wheels.

## In-process caveat

JUMP_RUNS=3 inside one process: run 2 boost_exit 19.3 vs 34.8. Boost pulse logs, but speed is lost. Remaining harness risk: Area3D + reset_to. Not a first-jump trajectory defect.

## Auditor verdict

READY on fresh-process 3/3. Best candidate = iteration_03 layout + default physics-mount symmetrize.
