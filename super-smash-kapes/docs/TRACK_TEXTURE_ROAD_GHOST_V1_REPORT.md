# TRACK TEXTURE / ROAD / GHOST V1 REPORT

## Primary Verdict

TRACK_TEXTURE_ROAD_GHOST_V1_READY_FOR_HUMAN_REVIEW

Not self-certified as fun. GPU texture stability on a visible D3D12 window still needs the owner to drive.

## Baseline

- Branch `master`, prior ingest: `TRACK_CAR_BASE_V1_INGEST_READY_FOR_HUMAN_REVIEW`
- Source GLB untouched
- Car runtime ~2.14 × 1.42 × 4.40 m
- Previous road width: **8.0 m** (~3.7 car widths)
- Ghosts called `play()` inside `_spawn_ghosts()` during countdown

## Texture Error

**Root cause:** per-instance `material.duplicate()` of the imported GLB material cloned the embedded 4K atlas / unique GPU resources. `load()` of the GLB on every VisualRoot plus uncached road materials amplified D3D12 `0x8007000e`.

**Fix:** preload one PackedScene; capture one shared `Texture2D`; lightweight unique player materials; one shared ghost material; no imported `duplicate()`; road color cache.

**Resource ownership:** one atlas RID for all TrackCar visuals. Player mats unique. Ghost mat shared.

**D3D12:** headless Forward Plus (Windows default) IngestLab / PhysicsLab / TrackMain: **PASS** (no `0x8007000e`, no RID cascade). Visible editor window still needs human confirmation.

**GL_COMPATIBILITY:** validator + labs **PASS**.

Details: `docs/TRACK_CAR_TEXTURE_MEMORY_V1_REPORT.md`

## TrackCar Resource Sharing

| | |
|---|---|
| base atlas | static `_shared_atlas` from imported albedo |
| player material | unique `StandardMaterial3D`, shared atlas |
| ghost material | one static transparent mat, shared atlas |
| instance behavior | transform + optional albedo_color accent only |

## Road Width

| | |
|---|---|
| before | `ROAD_WIDTH = 8.0` |
| after | `ROAD_WIDTH = 11.0` (rollback literal `ROAD_WIDTH_V1 = 8.0`) |
| shoulder | 0.7 m each side |
| car-to-road | 11.0 / 2.14 ≈ **5.1 car widths** |

Curves use the same `ROAD_WIDTH` per step (no accidental narrowing). Finish remains `width + 1.5`.

`PIECE_TIME` not rebalanced. Wider road may shave a little off real run time; fuel formula unchanged.

## Guardrails

- Left/right rails on standard segments (start, straights, arcs, chicanes, hills, jump ramp/land)
- Height 0.9 m, thickness 0.22 m, BoxShape3D via existing solid placer
- Follow curve steps (short sections, not one chord across the road)
- Shoulders (darker strip) between asphalt and rail
- Jump **gap** has no geometry (intentional)

## Generator

Sequence/pick/diversity unchanged. `_pack_road` emits `kind`: road / shoulder / rail. Piece metadata `has_left_guardrail` / `has_right_guardrail`.

Seams: rails use the same per-step overlap as road (`step_len + 0.35` on arcs).

## Ghost Timing

**Old:** `_spawn_ghosts()` → `ghost.play()` while countdown ran. Ghost elapsed = wall time from countdown start (~3 s ahead).

**New:** `_spawn_ghosts()` only `setup()` + `arm()` (hidden, transform = sample 0). `_on_race_started()` → `begin_playback()` + `set_elapsed(0)`.

## Countdown

`TrackRaceClock`: PREPARE → COUNTDOWN → ACTIVE → FINISHED.

| | input | timer | fuel | ghost |
|---|---|---|---|---|
| COUNTDOWN | locked | 0 | frozen | hidden, t=0 |
| ACTIVE | unlocked | race elapsed | current player | playback = race elapsed |
| checkpoint reset | stays ACTIVE | continues | continues | continues (not rewound) |
| restart from start | new countdown | 0 | frozen until GO | re-armed, hidden |

One start event: `_on_race_started()`.

## Tests

**111 passed**

New: `tests/test_track_texture_road_ghost_v1.py` (3). Existing tests kept.

## Validator

`[JEFFREY_VALIDATE] OK`

gl_compatibility headless. Expected corrupt-save `push_error` only.

Texture share log: same `atlas_id` across player and ghost instances.

## Smash Integrity

Smash playground still 2 fighters / 3 stocks / original spawns. No Smash gameplay file edits.

Headless boots (Forward Plus / D3D12 path, no `CreateResource` / RID cascade):

- TrackCarIngestLab
- TrackPhysicsLab
- TrackMain

## Known Issues

- Fused-mesh wheels still deferred
- Paint still one atlas
- D3D12 window (non-headless) not certified by this agent
- Wider road may make expected_time slightly conservative

## Human Review Required

1. IngestLab / PhysicsLab / TrackMain: car texture stays on, no CreateResource spam
2. Road feels multi-line; rails catch fall-offs without launching the car
3. Ghost frozen during 3-2-1, leaves with YA
4. 2-player hotseat ghosts + Last Dance GO timing
