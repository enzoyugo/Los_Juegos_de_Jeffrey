# Track 15 m modular kit V1

**Verdict: TRACK_15M_KIT_V1_READY_FOR_HUMAN_REVIEW**

Human width decision: **asphalt = 15.0 m**. Shoulders 0.9 m each. Rails outside shoulders.

11 m kit in `assets/track/modules/generated/core/` is untouched rollback.

## Candidate path

`assets/track/processed/kit_v8_15m/`

Sidecar JSON is widened from 11 m (centerline / ENTRY / EXIT / piece lengths unchanged). Road collider `size[0] = 16.8` (15 + 2×0.9). Unpitched road `size[1] ≥ 0.20`. Longitudinal `size[2] += 0.10` for seam overlap.

Visual GLBs built in Blender 5.2.1 from those boxes: asphalt 15 m + visible shoulders + concrete/metal rails + start/finish gantries + boost pad/chevrons. Curves are rebuilt along the arc (not X-scaled).

Generator V4 is not modified. `TrackKitAssembler.assemble(parent, seq, kit_dir)` selects the kit. TrackMain still uses 11 m `CORE_DIR`.

## Modules

start, straight_short/medium/long, curve L/R 45/90, chicane LR/RL, boost_straight, ramp_takeoff, ramp_small, jump_small, landing_straight_long, slope_up/down_gentle, crest_gentle, finish, plus `track_checkpoint_gantry_v1.glb`.

## Labs

- `Track15mKitShowcase.tscn` — fixed sequence, 4WHEEL, no debug HUD
- `TrackTurboV8Showcase.tscn` — generated V4 routes with 15 m visuals

## Collision

Visual GLB is **not** gameplay collision. Godot keeps JSON box colliders. Surfaces are aligned by construction.

**HUMAN_REVIEW_PENDING** for width feel, seams, and gantry art.
