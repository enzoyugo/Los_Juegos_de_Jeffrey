# Los Juegos de Jeffrey — Track + Zombies consolidation V3

## MASTER VERDICT

**JEFFREY_TRACK_ZOMBIES_CONSOLIDATION_V3_PARTIAL**

Two playable modes were consolidated without promoting 4WHEEL to TrackMain and without replacing the working Zombies interior.

| Stream | Verdict |
|---|---|
| Track | `TRACK_4WHEEL_GENERATOR_V4_READY_FOR_HUMAN_REVIEW` |
| Zombies | `ZOMBIES_SHOPPING_PARKING_V3_READY_FOR_HUMAN_PLAYTEST` |

PARTIAL (master) because: (1) no parking/facade PNG captures (headless), (2) Shopping shell AABB is large (~99×15×52 m after 0.42 scale) and orientation/clipping need a human F6, (3) 4WHEEL module matrix is throttle-straight structural smoke, not a steered 90/chicane racing line.

Not blocked: generator lab defaults 4WHEEL, 900/900 batch accept, boost 3/3, Zombies parking→buy door→interior loop, D3D12 no OOM, pytest 337, `[JEFFREY_VALIDATE] OK`.

Reports:

- `docs/TRACK_4WHEEL_GENERATOR_AND_PROCEDURAL_CONSOLIDATION_V4_REPORT.md`
- `docs/ZOMBIES_SHOPPING_PARKING_AND_SHELL_V3_REPORT.md`
- `docs/SHOPPING_RAW_ASSET_INVENTORY_V1.md`

## Track (summary)

`GENERATOR_LAB_BASELINE_REASON=C+I` — lab hardcoded BASELINE scene; canonical TrackMain firewall. Not a 4WHEEL physics fail.

- Lab default **4WHEEL**, **F2** BASELINE, same seed/sequence
- TrackMain `CONTROLLER_MODE := "BASELINE"`
- Incremental composer + 1–3 backtrack; empty compose ≠ START/FINISH
- Batch: **100% × 9 configs**, median 0–2, LONG p95 7–9
- Showcases: seeds **12 / 25 / 31**
- Boost 4WHEEL generated: **apply=3 hits=3**
- Offtrack grass + checkpoint reset
- Gentle slope/crest JSON (no new GLBs; kit stays 17)
- No banked-45 (stretch)

## Zombies (summary)

Authoritative opening is the **parking lot**. Main door **1500 SHOPPING**. Interior gameplay authority preserved. Shell GLB visual only. market-al-danube = layout reference, not a loaded scene. PSX industrial pack = selective processed props. Sci-fi portal / Ice Scream map / BeamNG wreck rejected.

Audio bank + wav import. Viewmodels/zombie windup/HUD/vignette polish. Crowd slot jitter.

## Do not auto-promote

Do **not** switch TrackMain to 4WHEEL. Do **not** switch TrackMain to generator V4. Do **not** mark Zombies final.

## Tests

| Gate | Result |
|---|---|
| pytest | **337 passed** |
| path scan | missing=0 |
| `[JEFFREY_VALIDATE]` | **OK** (expected CI corrupt-save `push_error`) |
| generator showcases | ACCEPTED 12/25/31 |
| 4WHEEL module compat | PASS |
| 4WHEEL boost gen | PASS 3/3 |
| ZombiesSystemsLab | ALL_PASS |
| D3D12 scenes | TrackGeneratorV2Lab, TrackJump, TrackMain, ShoppingZombiesIntegrationLab, ZombiesMain, ZombiesSystemsLab, M0Playground — **no 0x8007000e** |

## Human morning tests

**Track:** F6 `TrackGeneratorV2Lab.tscn` → CONTROLLER 4WHEEL → 1/2/3 → F2 BASELINE.

**Zombies:** F6 `ZombiesMain.tscn` → spawn outside → facade → fight → buy SHOPPING → walk in → gallery/SMG/MAX AMMO.
