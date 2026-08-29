# Track procedural show and rhythm V2

## Primary Verdict

**TRACK_PROCEDURAL_SHOW_V2_READY_FOR_HUMAN_REVIEW**

Generator V4 composition is unchanged. Reveal is a post-process animation. Rhythm analyzer **collects statistics only** (no rejection, no weight rewrite).

Batch: 9 settings × 20 = **180/180 accepted**, mean `RHYTHM_SCORE` 0.581, max straight run 13. Full 900 is `SSK_RHYTHM_FULL=1` (9×100). Weights not touched.

## Reveal

`TrackGenerationReveal`: hide pieces, show 50–120 ms each (adaptive), camera follows EXIT. F8 skip. Summary: length, difficulty, seed, meters, curves, boosts, crests, checkpoints. DALE / OTRA.

## Checkpoints

`TrackCheckpointLayout.plan` after generate: SHORT 3–5, MEDIUM 5–8, LONG 7–12, plus finish. Gantry is teal; finish is gold. Distinct from cyan BOOST.

Reset still uses the lab safe-transform fallback; last checkpoint as reset authority is showcase-next, not a generator change.

## Rhythm

`TrackRhythmAnalyzer` phrases: ACCELERATION, TURN_TEST, RECOVERY, HIGH_SPEED, TECHNICAL, SPECTACLE, FINISH_PUSH. `RHYTHM_SCORE` is diagnostic. Batch smoke: 9 settings × 20 (×100 if `SSK_RHYTHM_FULL=1`). Weights not touched → no mandatory 900-track generator rerun.
