# Jeffrey Gameplay / Physics QA — Issue Ledger V1

Date: 2026-08-31  
Scope: observe, reproduce, classify, and minimally correct existing Track, Smash, Zombies, and shared session gameplay.

## Closed

### QA-001 — Shell validator expected obsolete Track authority

- Severity: P2 tooling / validation contract
- Reproduction: `ValidateJeffreyShell.tscn` failed on `CONTROLLER_MODE must remain BASELINE`.
- Evidence: runtime `TrackMain` instantiates `TrackCarWheelPhysics.tscn` and logs `controller=FOUR_WHEEL_V1`; `track_config.gd` also declares `CONTROLLER_MODE := "FOUR_WHEEL_V1"`.
- Fix: updated the three validator authority checks to expect `FOUR_WHEEL_V1`.
- Verification: `ValidateJeffreyShell.tscn` exits 0 and reports `[JEFFREY_VALIDATE] OK`.

## Observed, no code change justified

### QA-002 — Pre-existing generated stationary-stability fixture disagrees with current JSON

- Severity: P2 test-data contract
- Reproduction: full pytest baseline is `508 passed, 1 failed`; the failure expects `overall_rest_pass == false` in `docs/generated/track_4wheel_v4_iterations/iteration_01/stationary_stability.json`, while the current dirty fixture says `true`.
- Disposition: preserved unchanged because the file was already modified before this QA task. It is not a runtime failure and was not overwritten.

### QA-003 — Persistence validator intentionally exercises corrupt-save quarantine

- Severity: informational
- Evidence: shell validation emits `save corrupt — backup written ...; starting clean` while testing recovery. The validator completes successfully.
- Disposition: expected recovery-path diagnostic, not treated as a gameplay defect.

### QA-004 — Smash KO observation lab is intentionally long-lived

- Severity: informational
- Evidence: it logs `KO: P1` and `P1 respawned`, then remains available for observation.
- Disposition: stopped after a bounded observation window; no production code change.

## No reproducible runtime defects found

No reproducible Track reset/checkpoint/finish/hotseat failure, Smash double-KO/invalid-respawn failure, or Zombies weapon/wave/end-state failure was found in the bounded runs recorded for this task.
