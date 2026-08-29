# Track visual lifetime audit V1

**Verdict: TRACK_VISUAL_LIFETIME_V1_BOUNDED** (candidate; confirm with 50-attempt smoke)

## Cause

`TrackCarVisual` counts instances in `_ready` / `_exit_tree`. Showcase `_spawn_car()` used `queue_free()` then immediately instantiated the next car, so `_exit_tree` had not run → `live_visuals` 1→2.

A new `TrackBoostFeedback` was also added every attempt.

`queue_free` of the previous car one frame later dropped the count back — it was **transition buffering**, plus a real feedback-node leak. Atlas unique texture resources stayed 1 (untouched).

## Fix

- `free()` the previous car before spawning (synchronous `_exit_tree`)
- Reuse one `TrackBoostFeedback`
- Skid marks persist across attempts, capped at 420

Smoke: `scenes/debug/SmokeTrackVisualLifetimeV1.tscn` (50 spawn/free). Expected live count 1 after idle frame, never 1→2→3→4 with ghosts off.

Do not touch shared atlas architecture.
