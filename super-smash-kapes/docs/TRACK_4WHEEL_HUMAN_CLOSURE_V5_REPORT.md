# TRACK 4WHEEL human closure V5

## Primary Verdict

**TRACK_4WHEEL_V5_READY_FOR_HUMAN_REVIEW**

Generator V4 architecture is **frozen**. TrackMain stays **BASELINE**. Remaining 4WHEEL issues addressed without a handling retune. Do not promote.

## Generator Frozen State

No rewrite of incremental composer, occupancy grid, backtracking, or difficulty. Kit GLB count remains 17. Gentle elevation stays procedural JSON (no new GLBs).

## Wrong-Way Boost

Observed: `BOOST dir=(0,0,-1) dot_chassis≈-0.992` then `BOOST_DIRECTION_NEGATIVE` `push_error`.

That was a **gameplay state** (reverse / facing opposite the pad), not an engine error.

## Boost Direction Gate

`TrackConfig.BOOST_MIN_FORWARD_DOT := 0.25`

Before apply (4WHEEL and BASELINE):

- `dot_forward = dot(car_forward, boost_direction)`
- optional `dot_velocity` logged
- if `dot_forward < 0.25`: **do not apply**, log `[TRACK_BOOST] SKIP_WRONG_WAY`
- no `push_error`
- `_boost_timer` not armed (normal Area3D body_entered / exit / rearm)

Smoke: `scenes/debug/SmokeTrackBoostWrongWay.tscn` — `count=0 active=false PASS` (skip fired twice: explicit call + Area3D).

## Gentle Elevation

Pieces: `slope_up_gentle`, `crest_gentle`, `slope_down_gentle`.

Slope up/down remain a **single continuous box** (no seam inside the piece). Pitch ~0.06 rad over 24 m (~3.4°). That is actually gentle.

## Airborne Root Cause

**A + B (geometry), not suspension.**

`crest_gentle` was **two 12 m boxes** at **±0.083 rad**, meeting at a ridge. That is a ~9.5° instantaneous kink (plus inherited slope-up pitch of 0.06 when composed). Wheel rays lose the surface; `TRACK_AIRBORNE` then `NO_VALID_CONTACT` on landing because compression never built.

Not: F chassis bottoming / G suspension (not retuned) / C speed-only (normal generated speed should stay planted on a C1 bump).

## Geometry Fix

`track_crest_gentle_v1.json` rebuilt as **8 overlapping road segments** on a **haversine** bump (`0.5 * (1-cos(2πs))`):

- entry/exit pitch **0** (C1 with flat and with inherited grade)
- peak ~0.34 m
- max |pitch| ~0.041 rad
- max adjacent pitch delta ~0.034 rad (was ~0.166 at the old peak)

Visual uses the same collision boxes (procedural). Smoke: `SmokeTrackElevationContact.tscn` — `air_frames=25 crest_air=0 PASS` (the 25 air frames are `RESET_SETTLE` only).

## 4WHEEL Human Behavior

Lab default 4WHEEL, **F2** BASELINE. HUD: speed, grounded wheels n/4, piece id, boost, offtrack, AIRBORNE.

No change to FRONT_LATERAL_GRIP / SPRING / ENGINE / COM / TRAVEL. Lateral floaty is **deferred**.

## D3D12

Rendered 3-cycle harness **PASS**. See `docs/JEFFREY_D3D12_INTERMITTENT_RESOURCE_EXHAUSTION_V1_REPORT.md`. Track pieces still share asphalt `.tres`. TrackMain remains BASELINE in the repeat sequence.

## Tests

- pytest full **343 passed**
- `test_jeffrey_visual_stability_v4.py` (gate + crest smoothness + TrackMain firewall)
- `SmokeTrackBoostWrongWay` PASS
- `SmokeTrackElevationContact` PASS
- `[JEFFREY_VALIDATE] OK`
- Captures: `docs/generated/track_visual_v5/` (`4wheel_short`, `4wheel_medium`, `4wheel_elevation`, `boost_normal`, `boost_wrong_way_skip`)

Generator V4 900/900 batch was previously human-verified; architecture frozen, not re-run this close.

## Promotion Status

**Do not promote.** TrackMain `CONTROLLER_MODE := "BASELINE"`.

Human F6 `TrackGeneratorV2Lab.tscn`: SHORT/MEDIUM/LONG, 90s, chicanes, boost forward, reverse over boost, gentle slopes, offtrack, reset, finish. Then F2 BASELINE same track.
