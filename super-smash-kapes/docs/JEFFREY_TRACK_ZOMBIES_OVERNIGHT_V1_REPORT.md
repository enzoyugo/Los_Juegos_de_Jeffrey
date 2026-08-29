# Los Juegos de Jeffrey — Track + Zombies overnight V1

## MASTER VERDICT

**JEFFREY_TRACK_ZOMBIES_OVERNIGHT_V1_READY**

Owner can F6 two playable things:

1. `scenes/debug/TrackGeneratorV2Lab.tscn` — validated SHORT / MEDIUM / LONG kit tracks, shared road materials, BASELINE car.
2. `scenes/zombies/ZombiesMain.tscn` — spawn → shoot → points → door → wall SMG → rounds → MAX AMMO → die/restart.

4WHEEL is **not** promoted. TrackMain still uses greybox V1 + BASELINE. Zombies stays `development` in the registry.

| Stream | Verdict |
| --- | --- |
| Track | `TRACK_OVERNIGHT_V1_READY_FOR_HUMAN_REVIEW` |
| Zombies | `ZOMBIES_VERTICAL_SLICE_V1_READY_FOR_HUMAN_PLAYTEST` |

Reports:

- `docs/TRACK_GENERATOR_AND_VISUAL_FOUNDATION_V2_REPORT.md`
- `docs/ZOMBIES_VERTICAL_SLICE_V1_REPORT.md`

---

## TRACK

### Playable

- **Generator lab:** F6 `TrackGeneratorV2Lab.tscn` (BASELINE car). Keys **1 / 2 / 3** load frozen showcases.
- **V6 jump lab:** F6 `TrackJumpTrajectoryLandingLab.tscn` now defaults to the human-review candidate without env vars. HUD shows `V6 HUMAN REVIEW` or `NOT V6 HUMAN REVIEW CONFIG`.

### Generator

Additive `TrackGeneratorV2` over existing modular GLBs. Generate → validate → reject → retry (max 40). TrackMain still uses `scripts/track/track_generator.gd`.

Allowed tonight: `start`, `finish`, `straight_medium`, `curve_l_45`, `curve_r_45`, `boost_straight`, `landing_straight_long`. No random jumps/ramps/gaps. No 90° / chicane / short-long GLBs (they do not exist).

| Showcase | Seed | Pieces | Path | Difficulty |
| --- | --- | --- | --- | --- |
| SHORT | 11 | 14 | ~326 m | PICANTE |
| MEDIUM | 21 | 21 | ~529 m | PICANTE |
| LONG | 31 | 40 | ~994 m | PICANTE |

All three `ACCEPTED` on attempt 0.

### Visuals

Shared `NoiseTexture2D` (256) on existing `track_asphalt_v1.tres` / `track_shoulder_v1.tres` / `track_guardrail_v1.tres`. Same resource paths. Colliders unchanged. **HUMAN_REVIEW** for “is this pretty enough” — functional arcade read, not a theme pass.

### Boost reset

`TrackPiece.rearm_boost_trigger()` + V6 `reset_to` rearm. Same-process 3/3 `BOOST_ENTRY` via `body_entered`. Status `TRACK_BOOST_RESET_OK`.

### V6 F6 defaults (plain F6)

`mode=full` `steer=zero` `gap=30` `landing extra=24` `sym mounts=true` `controller=4WHEEL` (lab only). Env still overrides.

### Not done / human

- TrackMain not cut over to V2.
- Kit still 11 GLBs; rhythm is 45° + 12/24/36 m only.
- Asphalt aesthetics.
- V6 jump still needs owner eyes (centered takeoff, 30 m gap, ~1/3 deck).

---

## ZOMBIES

### Playable loop

F6 `ZombiesMain.tscn`:

spawn plaza → pistol (mag/reserve) → kill for points → **E** `GALERÍA` (1000) → wall SMG (1800) → survive round → `RONDA N` → MAX AMMO pickup → die → **R** restart.

### Map

Code-built Shopping-inspired greybox (plaza, corridor, door, galería). Terracotta/cream + `SHOPPING del SOL` Label3D. **Exterior GLB not instanced** (169 m shell, no interior).

### Systems

Player FPS, hitscan pistol + SMG resources, one zombie type (nav mesh bake, 14 polygons headless; chase fallback), rounds via `next_count()`, points, buyable door, wall buy, MAX AMMO, HUD, game over, F8/F9/F10 debug.

Reload is **G** (project **R** is `restart_match`).

### Tests

`ZombiesSystemsLab` 8/8 `ALL_PASS` (fire, reload, kill, door locked/open, wall buy, round, max ammo).

### Not done / human

- 1P only. No perks, mystery box, bosses, 2P split.
- Shopping exterior not in the playable space.
- No audio. Placeholder gun/zombie meshes.

---

## TESTS

| Gate | Result |
| --- | --- |
| pytest | **323 passed** |
| path scan | checked 203 unique 203 **missing=0** |
| `[JEFFREY_VALIDATE]` | **OK** (showcases ACCEPTED, zombies tokens, FL steer/spin 0.000 after freeze) |
| D3D12 Forward+ smokes | TrackMain, TrackGeneratorV2Lab, ZombiesMain, ZombiesSystemsLab, M0Playground — **exit 0, no 0x8007000e** |
| Kit GLBs | still **11** |
| `CONTROLLER_MODE` | still **BASELINE** |

Logs: `docs/generated/overnight_v1/`.

---

## MORNING

### Track

1. F6 `scenes/debug/TrackGeneratorV2Lab.tscn`
2. **1 / 2 / 3** SHORT / MEDIUM / LONG
3. **T** difficulty · **R** new seed · **G** next seed · **F4** collision · **C** reset
4. Drive if desired (WASD, BASELINE)
5. F6 `scenes/debug/TrackJumpTrajectoryLandingLab.tscn`
6. Confirm HUD **V6 HUMAN REVIEW** (4WHEEL, ZERO, SYM ON, GAP 30, LANDING 60)

Human questions: Does the generated rhythm read as a race track? Do asphalt/shoulder/rails separate? Does V6 stay centered over the 30 m gap?

### Zombies

1. F6 `scenes/zombies/ZombiesMain.tscn`
2. WASD, mouse, **LMB** shoot, **G** reload, **E** interact
3. **F8** +5000 if the door is too slow to farm
4. Open `GALERÍA`, buy SMG, finish a round, grab MAX AMMO, die, **R**

Human questions: Is the map readable? Does the door actually block until purchase? Does the SMG feel like a second weapon?

### Do not

- Promote 4WHEEL.
- Treat Zombies as finished/canonical.
- Require hub navigation; F6 the scenes above.
