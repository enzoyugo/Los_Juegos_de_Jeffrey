# Track airborne seam root cause V2

**Verdict: TRACK_AIRBORNE_SEAM_V2_PARTIAL**

## Observation (human V7)

Repeated `TRACK_AIRBORNE` near world `(31–33, y ≈ -0.09, z = -187 to -188)` at 23–35 m/s. Not treated as a suspension bug.

## Instrumentation

On `TRACK_AIRBORNE` (not RESET_SETTLE / SPAWN_SETTLE), `TrackWheelCar` now logs:

- current / previous / next piece ids
- world position / speed
- per-wheel grounded, hit point, normal, collider kind/name, compression

V8 showcase writes `report_piece_id` / `prev` / `next` from nearest assembled piece.

## Geometry first (15 m candidate only)

- Unpitched road collider thickness ≥ 0.20 m (top stays ~0)
- Longitudinal overlap +0.10 m on each road box
- 11 m kit unchanged
- `SPRING_STRENGTH`, `SUSPENSION_TRAVEL`, `MAX_SUSPENSION_FORCE`, COM **not** retuned

## Pass criterion (human)

Drive the same location at 25 / 35 / 45 / 55 m/s with no unintended airborne.

Automation did not replay that exact world sample (it depends on a generated seed). Classification remains **possible seam**; 15 m overlap is the candidate fix. Not RESOLVED until a human (or instrumented seed replay) confirms the coordinate is quiet.
