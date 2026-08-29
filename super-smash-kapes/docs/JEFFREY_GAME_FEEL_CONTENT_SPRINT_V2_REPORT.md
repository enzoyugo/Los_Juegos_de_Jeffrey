# Los Juegos de Jeffrey — Game feel + content sprint V2

## MASTER VERDICT

**JEFFREY_GAME_FEEL_CONTENT_SPRINT_V2_READY**

Owner can F6 two playable things and feel the overnight loops with readable combat and a boost that actually punches:

1. `scenes/debug/TrackGeneratorV2Lab.tscn` — BASELINE car, 17-piece kit, 90° / chicane / short / long, boost overspeed, ground + fog.
2. `scenes/zombies/ZombiesMain.tscn` — same 1P loop, unstacked crowd, viewmodels, TV HUD, code-built Shopping interior.

4WHEEL is **not** promoted. TrackMain still uses greybox V1 + BASELINE. Handling constants are unchanged. Zombies stays `development`. Shopping exterior GLB is **not** instanced.

| Stream | Verdict |
| --- | --- |
| Track | `TRACK_GAMEPLAY_CONTENT_V3_READY_FOR_HUMAN_REVIEW` |
| Zombies | `ZOMBIES_GAME_FEEL_V2_READY_FOR_HUMAN_PLAYTEST` |

Reports:

- `docs/TRACK_GAMEPLAY_CONTENT_V3_REPORT.md`
- `docs/ZOMBIES_GAME_FEEL_AND_SHOPPING_INTERIOR_V2_REPORT.md`

---

## TRACK

### Boost (hard gate)

Root cause was real: extra accel was applied, then `along` was clamped to `MAX_SPEED` (54). Near top speed the pulse did nothing.

BASELINE now allows `MAX_SPEED * BOOST_OVERSPEED` (**1.22** → 65.88 m/s) while the pulse is active. Duration **0.85 s**. Retrigger locked. Not unlimited.

| | entry | peak |
| --- | --- | --- |
| A (off) | 48.26 | **54.00** |
| B (on) | 48.26 | **65.88** |

**peak_delta = 11.88 m/s** (gate ≥ 4). `[TRACK_BOOST_DELTA] PASS`

Generated 3×: **apply_count=3** (not 30). `[TRACK_BOOST_GEN] PASS`  
4WHEEL reset lab still **3/3**. Pulse duration matched; `apply_central_force` and `ENGINE_FORCE` 6200 untouched.

HUD: `BOOST READY / ACTIVE`. Cyan chevrons + FOV punch. `CAM_DISTANCE` not retuned.

### Kit + generator V3

Original 11 GLBs kept. Six added. **Total 17.**

`straight_short` 12 m · `straight_long` 44 m · `curve_l_90` / `curve_r_90` r=24 · `chicane_lr` / `chicane_rl` EXIT yaw 0.

Hairpins skipped (stretch).

Frozen showcases (all ACCEPTED):

| | Seed | Diff | Pcs | Path |
| --- | --- | --- | --- | --- |
| SHORT | **11** | PICANTE | 13 | 244.7 m |
| MEDIUM | **21** | PICANTE | 26 | 515.5 m |
| LONG | **33** | DEMENTE | 36 | 825.8 m |

Union across 3: 90° + chicane + boost + short + long.

TrackMain still uses `scripts/track/track_generator.gd`. Lab keys unchanged: **1 / 2 / 3 / T / R / G / F4**.

### Visuals + landing

Shared `.tres` paths, still 256 `NoiseTexture2D`. Darker asphalt, less-orange shoulder, brighter rails. Lab: cheap ground at Y=−14 (no car collision), mild fog, box poles. Not a city.

**K** on V6 cycles CHASE → LANDING_SIDE → **LANDING_CLOSE** → TOPDOWN. No damper retune. Rear travel still hits 0.14 m / 18 kN; saturation is the designed ceiling.

`CONTROLLER_MODE := "BASELINE"`  
`FRONT_LATERAL_GRIP := 9200.0` · `SPRING_STRENGTH := 32000.0` · `YAW_ASSIST_TORQUE := 420.0` · `ENGINE_FORCE := 6200.0`  
`CENTER_OF_MASS_OFFSET := Vector3(0.0, -0.12, 0.06)` · `SUSPENSION_TRAVEL := 0.14` · `MAX_SUSPENSION_FORCE := 18000.0`

---

## ZOMBIES

Playable loop unchanged: plaza → pistol → points → **E** `GALERÍA` 1000 → wall SMG 1800 → rounds → MAX AMMO → die / **R**.

- **Crowd:** 11 slots on a 2.2 m ring + local separation. No zombie–zombie physics. `[ZOMBIES_CROWD] PASS min_nn=1.296 clustered=1`
- **Gun:** camera viewmodel (pistol / SMG), recoil, muzzle flash, hit marker. Hitscan unchanged.
- **Damage:** red vignette, HP flash, 0.4 s delay then GAME OVER.
- **HUD:** large RONDA / POINTS / HEALTH / AMMO for TV. Jeffrey gold kept.
- **Mall:** code-built storefronts, directory, benches, lights. **Shopping GLB used? No.** Nav still 14 polygons.

Rounds 1–3 lab: 6 → 8 → 10, all cleared. Original 8 systems still PASS. Fire still drops ammo.

Controls unchanged: WASD, LMB, **G** reload, **E** interact, F8/F9/F10 cheats. No mystery box / perks / bosses / 2P. No audio.

---

## TESTS

| Gate | Result |
| --- | --- |
| pytest | **330 passed** |
| path scan | checked 208 unique 208 **missing=0** |
| `[JEFFREY_VALIDATE]` | **OK** (showcases ACCEPTED 11/21/33, zombies feel tokens, FL steer/spin 0.000) |
| D3D12 Forward+ smokes | TrackMain, TrackGeneratorV2Lab, TrackJumpV6, ZombiesMain, ZombiesSystemsLab, M0Playground — **exit 0, no 0x8007000e** |
| Kit GLBs | **17** (original 11 kept) |
| `CONTROLLER_MODE` | still **BASELINE** |
| Zombies lab | `[ZOMBIES_SYSTEMS] ALL_PASS` + crowd + rounds 1–3 |
| V6 D3D12 | `human_review=true` `mode=full` `steer=zero` `gap=30` `sym=true` |

Logs: `docs/generated/feel_v2/`.

Parent merge (agents did not edit these): `tools/scan_resource_paths.py`, `scripts/debug/validate_jeffrey_shell.gd`. Stale 4WHEEL test that still demanded exactly 11 GLBs / `_boost_timer > 0.08` was updated to the V3 contract (original 11 still required).

---

## MORNING

### Track

1. F6 `scenes/debug/TrackGeneratorV2Lab.tscn`
2. **1 / 2 / 3** SHORT / MEDIUM / LONG
3. Drive boost pads at speed — should punch past the old 54 cap, chevrons + HUD
4. Look for 90° corners, chicanes, short vs long straights
5. F6 `scenes/debug/TrackJumpTrajectoryLandingLab.tscn`
6. Confirm HUD **V6 HUMAN REVIEW**. **K** for LANDING_CLOSE. F7 still TOPDOWN.

Human questions: Does boost feel like a pad, not a tooltip? Do 90s and chicanes read as a race track? Does LANDING_CLOSE show the deck without a physics retune?

### Zombies

1. F6 `scenes/zombies/ZombiesMain.tscn`
2. WASD, mouse, **LMB**, **G** reload, **E** interact
3. **F8** +5000 if the door is slow to farm
4. Open `GALERÍA`, buy SMG, survive a round, grab MAX AMMO, die, **R**
5. Watch whether a pack stays in a ring instead of a pillar, and whether the HUD reads from the couch

Human questions: Are zombies unstacked? Does the pistol/SMG feel like a gun? Does Shopping read as a mall without the exterior GLB?

### Do not

- Promote 4WHEEL.
- Cut TrackMain to generator V2/V3.
- Retune landing dampers from this sprint.
- Treat Zombies as finished/canonical.
- Require hub navigation; F6 the scenes above.

---

## Remaining (not blockers for this gate)

- Human feel pass (boost punch, chevrons, rhythm, gun, crowd, mall).
- Headless cannot certify FOV kick or material look.
- Hairpins not in the kit.
- Composer still retries on OVERLAP (SHORT attempt 1, MEDIUM 3, LONG 9).
- Reload is **G**, not R. No audio. 1P only.
