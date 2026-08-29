# Track airborne and seam closure V3

**Verdict: TRACK_AIRBORNE_SEAMS_V3_PARTIAL**

Springs / travel / COM **unchanged**.

## Classification

| Log pattern | Class |
|---|---|
| `source_piece=finish` after a valid finish | **POST_FINISH_RUNOFF** — not a gameplay seam once runoff exists |
| `curve_l_45 → curve_l_45` at ~26.7 m/s | real seam / inner-arc hole candidate |
| `chicane_rl → straight_short` at ~9.1 m/s | real contact hole (low speed = geometry) |

## Fixes shipped

1. **Finish runoff** piece `finish_runoff` (32–44 m of `straight_long` road after finish). Assembler appends it when `append_runoff=true`. Generator V4 **not** modified. TrackMain **not** modified.
2. Turbo V8: after the finish gate the car **coasts** on runoff (`ST_RUNOFF`) then freezes + handoff. `post_finish` → airborne reason `POST_FINISH_RUNOFF` (not `TRACK_AIRBORNE`).
3. **Collider names**: `RoadCollider_01`, `RoadCollider_Seam`, metas `track_piece_id`, `track_piece_instance`, `collision_kind`, `road_kind`.
4. Wheels keep `last_contact_*` so airborne logs print last ROAD hit instead of blank `kind=`.
6. **Seam stitch** boxes at each non-start ENTRY and at EXIT (~1.6 m long). **Skipped** on `gap_logical` / `has_gap` (intentional air) and EXIT stitch skipped on `ramp_takeoff`.
6. Extra **0.18 m** longitudinal overlap patched into existing 15 m kit JSON (`size.y` ≥ 0.24).
7. `TrackSeamContactInspector` + `SmokeTrackSeamContactV1.tscn`.

## Speed matrix

Automated seam rays cover center / ±25% / ±50% / near shoulder (~72% half-width). Full 10/25/35/45/55 m/s drive still needs **human**. Intentional jump/ramp/crest airborne is not suppressed.

## Seam inspector (2026-08-27, this sprint)

`SmokeTrackSeamContactV1.tscn` on the 15 m kit + `finish_runoff`:

```
[TRACK_SEAM] samples=70 gaps=0 steps=0 worst_gap=0.000 worst_dy=0.000 ok=true
[TRACK_SEAM_SMOKE] last=finish_runoff runoff=true ok=true
```

Earlier 70/70 GAP was inspector false-negative (rays started missing / 3D sample spacing treated as a hole). After `hit_from_inside`, more physics frames, and **ENTRY+EXIT stitch plates** (~1.6 m long, road+shoulder+1.2 m wide): **0 gaps**.

Springs / travel / COM still unchanged.

**Verdict stays PARTIAL** until a human (or drive lab) crosses seams at 10–55 m/s. Geometry coverage for the logged 9.1 m/s chicane hole is the intended fix.
