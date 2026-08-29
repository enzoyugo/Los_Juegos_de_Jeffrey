# Track Turbo + environment pipeline V7 — master

## MASTER VERDICT

**JEFFREY_TRACK_TURBO_AND_ENVIRONMENT_PIPELINE_V7_PARTIAL**

| Gate | Verdict |
|---|---|
| Track HUD error | `TRACK_GENERATOR_HUD_RUNTIME_ERROR_RESOLVED` |
| Driving feel | `TRACK_TURBO_DRIVING_FEEL_V7_READY_FOR_HUMAN_REVIEW` |
| Hotseat | `TRACK_TURBO_HOTSEAT_V2_READY_FOR_HUMAN_REVIEW` |
| Procedural show | `TRACK_PROCEDURAL_SHOW_V2_READY_FOR_HUMAN_REVIEW` |
| Scenery | `TRACK_ASUNCION_URBAN_SCENERY_V2_READY_FOR_HUMAN_REVIEW` |
| Shopping | `SHOPPING_BLENDER_REQUIRED` |
| F6 | `JEFFREY_F6_RUNTIME_STABILITY_V3_PARTIAL` |

TrackMain was **not** promoted to 4WHEEL. Generator V4 was **not** rewritten. Zombies gameplay was **not** replaced. Automated screenshots are **not** human visual approval. Agent READY ≠ canonical.

## Measured gates

- pytest **350 passed**
- `[JEFFREY_VALIDATE] OK` (expected CI corrupt-save `push_error`)
- HUD telemetry smoke PASS; lab HUD stress 95 cycles / 114 s, F2 BASELINE ↔ 4WHEEL, no `int(null)`
- Hotseat V2: after 22.5/24.0/24.7/25.0 last=Tomi; Tomi 23.8 → last=Santi; última flagged
- Rhythm analyzer: 180/180 accepted, mean score 0.581, max straight run 13. **Weights unchanged** (no 900-track generator rerun)
- Systems: 9 pieces, 6 checkpoints monotonic, FOV 70, 3 landmarks, scenery StaticBody count 0
- Windowed F6 10 launches PASS; Zombies video plateau 469–473 MB, static peak 156 MB

## What to F6 (human)

1. `TrackGeneratorV2Lab.tscn` — HUD on, 4WHEEL, F2 BASELINE, 1/2/3, T, R. Must not throw `Invalid call. Nonexistent int constructor`.
2. `TrackTurboV7Showcase.tscn` — 1/2/3 length, T difficulty, ENTER generate, watch reveal, SPACE DALE, drive, Shift drift, F3 debug, F8 skip. Last-place handoff after four finishes.
3. Width / camera / drift labs if comparing 14–16 m and chase framing (`VISUAL_REVIEW_PENDING`).
4. `ZombiesMain.tscn` — gameplay only. Close leftover Godot processes first. Outdoor SDS still waits on Blender.

## Pipeline

`docs/JEFFREY_GAME_PRODUCTION_PIPELINE_V1.md`

Human is the art director. Blender is the environment authoring app. Godot is gameplay.
