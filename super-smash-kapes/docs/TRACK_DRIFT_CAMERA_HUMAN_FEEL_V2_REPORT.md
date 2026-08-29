# Track drift / camera human feel V2

**Verdict: TRACK_DRIFT_CAMERA_V2_READY_FOR_HUMAN_REVIEW**

Logic kept. No rewrite of 4WHEEL or Hotseat.

## Drift states

| State | Meaning |
|---|---|
| `drift_armed` | Input wants drift; slip still below threshold. Log `DRIFT_ARM`. Grip barely reduced. |
| `drift` | `abs(slip) ≥ 0.10` or yaw rate ≥ 0.85. Log `DRIFT_ACTIVE`. Full rear-grip drop. |
| `drift_recover` | Input released. Log `DRIFT_PEAK` then `DRIFT_EXIT`. |

This stops `DRIFT ENTER slip=0.00` from reading as a real slide.

Smoke / skids fire only while `drift_state == drift` and slip > 0.08.

## Camera

- Extra lateral / velocity blend **only** while `DRIFT_ACTIVE`
- `road_look_dir` from next piece tangent (V8 `_update_piece_report`)
- Boost FOV pulse unchanged
- Clip ray still 1 | 128 (buildings / landmarks)

## Reveal V4

Final camera uses route AABB + several orbit candidates; rejects views that immediately hit scenery.

## HUD

Smaller checkpoint delta, gold/black summary panel, `[ DALE ] [ OTRA ]` as choices (keyboard still works), qualification chip `TODOS MARCAN TIEMPO` → `AHORA EL ÚLTIMO SIGUE`.

Human must still feel a 90° as “this is a drift corner.”
