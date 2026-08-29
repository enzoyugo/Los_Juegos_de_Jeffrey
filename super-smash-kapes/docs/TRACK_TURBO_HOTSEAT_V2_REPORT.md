# Track Turbo Hotseat V2

## Primary Verdict

**TRACK_TURBO_HOTSEAT_V2_READY_FOR_HUMAN_REVIEW**

Last-place-drives after qualification. TrackMain still uses round-robin `TrackTurnManager.advance()` — this stack is **not** promoted.

## Rules

1. Qualification: roster order, everyone gets a run.
2. Then the current last place drives (worst `best_ms`; missing times sort last; ties use roster `order`).
3. Fuel = remaining attempt seconds (`expected_time * FUEL_MULTIPLIER`).
4. Fuel hits 0 mid-run → `ÚLTIMA OPORTUNIDAD`, run may finish.
5. After that run, if still last → cannot start another run.
6. Times stored as milliseconds.

Example from spec: 22.5 / 24.0 / 24.7 / 25.0 → Tomi; Tomi 23.8 → Santi. Encoded in `SmokeTrackHotseatV2.tscn`.

## HUD

`TrackTurboHud`: ranking top-right, TARGET, signed delta (not color-only), FUEL bar, low-fuel pulse, player name/color. Debug overlay off by default (F3 in showcase).

## Handoff

Result card ~2.2 s then next driver countdown 3 / 2 / 1 / ¡DALE!
