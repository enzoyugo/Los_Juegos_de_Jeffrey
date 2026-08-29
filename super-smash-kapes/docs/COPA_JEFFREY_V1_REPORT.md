# COPA JEFFREY V1 — Implementation Report

## Summary

Copa Jeffrey V1 adds a global party-session scoreboard across Boot → ¿Quiénes están hoy? → Hub → Smash / Track / Zombies. Scores persist for the running app session until **Nueva Copa** or a fresh boot logon (`is_new_session`).

## Architecture

Single mode-agnostic session object on the existing **`JeffreyCore`** autoload:

```
JeffreyCore
  ├── session (LJActiveSession)        — roster / session_id
  └── copa (LJCopaJeffreySession)    — points, wins, round_history, idempotency

JeffreyCore.record_match_result(payload)
JeffreyCore.record_smash_copa_match(...)
JeffreyCore.record_track_copa_match(...)
JeffreyCore.record_zombies_copa_match(...)
```

No per-mode score managers. Each mode produces a standardized payload with `match_id`, `mode`, `participants`, and `placements`.

**Idempotency:** `recorded_match_ids` dictionary rejects duplicate `match_id` values. Each mode generates a fresh `match_id` at match start via `JeffreyCore.generate_copa_match_id(mode)`.

**Persistence:** Runtime-only for V1. Copa state lives in memory on `JeffreyCore.copa` and survives scene/mode transitions. It is **not** written to `save.json` (player profiles remain persisted separately). App restart clears Copa scores; boot logon starts a fresh Copa tied to `LJActiveSession.session_id`.

## Files Created

| File | Purpose |
|------|---------|
| `scripts/core/jeffrey/copa_jeffrey_scoring.gd` | Placement points 5/3/2/1 |
| `scripts/core/jeffrey/copa_jeffrey_session.gd` | Session state, leaderboard, history, dedup |
| `scripts/ui/jeffrey/copa_jeffrey_hub_panel.gd` | Compact Hub leaderboard |
| `scripts/ui/jeffrey/copa_jeffrey_results_screen.gd` | Post-match COPA JEFFREY — RESULTADO |
| `scripts/ui/jeffrey/copa_jeffrey_scoreboard_screen.gd` | Full session scoreboard + últimas rondas |
| `scripts/ui/jeffrey/copa_jeffrey_confirm_dialog.gd` | Nueva Copa confirmation |
| `scripts/debug/copa_jeffrey_lab.gd` | Headless scoring/session tests |
| `scenes/debug/CopaJeffreyLab.tscn` | Lab scene |
| `tests/test_copa_jeffrey_v1.py` | Static contract tests |
| `docs/COPA_JEFFREY_V1_REPORT.md` | This report |

## Files Modified

| File | Change |
|------|--------|
| `scripts/core/jeffrey/jeffrey_core.gd` | `copa` instance, roster sync, mode adapters, `start_new_copa()` |
| `scripts/core/jeffrey/jeffrey_app.gd` | Copa results flow, scoreboard, Nueva Copa, `_finish_mode_to_hub()` |
| `scripts/ui/jeffrey/hub_screen.gd` | Copa panel + signals |
| `scripts/core/main.gd` | Smash Copa record (once per match_id) |
| `scripts/track/track_main.gd` | Track Copa record on session over, `restart_session()` |
| `scripts/zombies/zombies_main.gd` | Zombies Copa record on death (failed run) |
| `tests/test_jeffrey_shell_v2.py` | Updated exit hook assertion |
| `tests/test_jeffrey_global_ui_v1.py` | Updated exit hook assertion |

## Integrations by Mode

### Smash Kapes
- **Hook:** `Main._on_match_finished` after existing `record_smash_match`
- **Ranking:** Winner = 1st (5 pts), loser = 2nd (3 pts) from `winner_id` + `match_setup` profile IDs
- **Idempotency:** `_copa_match_id` generated in `_enter_match`; `_copa_recorded` guard
- **UX:** Kapes victory screen unchanged → Menu → Copa Jeffrey results → Hub or Revancha

### Track / Hotseat
- **Hook:** `TrackMain._record_copa_if_needed()` when `TrackTurnManager.session_over()`
- **Ranking:** `TrackTurnManager.rank_list()` — valid `best >= 0` get placements 1..N; DNF (`best < 0`) get 0 pts
- **Idempotency:** `_copa_match_id` on `_on_play`; `_copa_recorded` guard
- **UX:** Session end → Esc/Hub → Copa results → Hub or Revancha (`restart_session()`)

### Zombies
- **Hook:** `ZombiesMain._on_dead` → `_record_copa_if_needed(false)`
- **Contract:** No individual competitive ranking and **no team-clear win** in current gameplay. V1 records a **failed run: 0 points** for all participants. The `team_cleared` path (+3 each) exists in `JeffreyCore.record_zombies_copa_match` for future use if a clear condition is added.
- **Early hub exit** (pause, no death): no Copa record

## Scoring Rules (V1)

| Placement | Points |
|-----------|--------|
| 1st | 5 |
| 2nd | 3 |
| 3rd | 2 |
| 4th | 1 |
| DNF / failed | 0 |

Leaderboard sort: `total_points` ↓, `wins` ↓, `join_order` ↑.

## UI

| Screen | Access |
|--------|--------|
| Compact Hub panel | Top-right on Hub — top 4 + Ver más + Nueva Copa |
| COPA JEFFREY — RESULTADO | After completed match, before Hub |
| Full scoreboard | Hub → Ver más |
| Nueva Copa confirm | Hub panel, scoreboard, or shell overlay |

Buttons: **REVANCHA** / **VOLVER AL HUB** on results screen.

## Debug Support

```powershell
& "E:\Godot_v4.7.2-stable_win64_console.exe" `
  --path "E:\SuperSmashKapes\super-smash-kapes" `
  --headless --display-driver headless `
  --rendering-method gl_compatibility --audio-driver Dummy `
  --quit-after 120 `
  res://scenes/debug/CopaJeffreyLab.tscn
```

Lab covers: scoring table, 4-player awards, idempotency, accumulation, leaderboard, roster join/remove, Nueva Copa reset.

## Tests Added

**Python (static):** `tests/test_copa_jeffrey_v1.py` — 10 contract tests

**Godot (runtime):** `scenes/debug/CopaJeffreyLab.tscn` — 6 behavioral test groups

### Coverage checklist

1. New session starts at zero — lab `_test_session_flow`
2. 4-player 5/3/2/1 — lab
3. 3-player 5/3/2 — lab `_test_scoring_table`
4. 2-player 5/3 — lab idempotency test
5. DNF = 0 — `record_track_copa_match` + session logic
6. Cross-mode accumulation — lab `_test_leaderboard`
7. Scene transition no reset — runtime architecture (JeffreyCore autoload)
8. Duplicate blocked — lab `_test_idempotency`
9. Leaderboard ordering — lab
10. Tie-break wins — session sort + lab
11. Join at zero — lab `_test_roster_changes`
12. Removed player history kept — lab
13. Nueva Copa reset — lab + `start_new_copa()`
14. Roster not deleted — persistence unchanged
15. Smash once — `main.gd` guards + static test
16. Track once — `track_main.gd` guards + static test
17. Zombies failed-run contract — documented + static test
18. Shell regressions — see below

## Regression Results

```
pytest tests/test_copa_jeffrey_v1.py
       tests/test_jeffrey_shell_v2.py
       tests/test_jeffrey_multimode_shell.py
       tests/test_jeffrey_global_ui_v1.py
       tests/test_jeffrey_global_ui_transitions_v1.py
→ 37 passed
```

```
Godot CopaJeffreyLab.tscn (headless) → [COPA_JEFFREY_LAB] PASS
```

## Screenshots

Not captured in this headless agent environment (`viewport.get_texture()` is null under dummy renderer). Manual 1920×1080 captures recommended:

| ID | Scene |
|----|-------|
| A | Hub with compact Copa panel |
| B | COPA JEFFREY — RESULTADO after Track/Smash |
| C | Full scoreboard (Ver más) |
| D | Nueva Copa confirmation dialog |
| E | 2-player standings |
| F | 4-player standings |

## Known Limitations

- Copa scores do not persist across app restart (V1 runtime-only).
- Zombies awards 0 on death only; no +3 team clear until gameplay supports a win condition.
- Track Revancha returns to setup screen (user must press Play again).
- Smash still shows legacy Kapes victory screen before Copa overlay on hub exit.
- Screenshots require a visible Godot window / capture tooling.

## Final Verdict

**COPA_JEFFREY_V1_READY**

Smash and Track integrations are wired with idempotent recording. UI (Hub panel, results, scoreboard, Nueva Copa) is implemented. Regression suites pass. Duplicate scoring is blocked by `match_id` dedup (proven in lab).
