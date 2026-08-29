# JEFFREY PERFORMANCE + TRACK PRESENTATION DIAGNOSTIC V1 — Report

## Primary verdict

**JEFFREY_PERF_TRACK_DIAGNOSTIC_V1_PARTIAL**

Evidence-backed diagnosis and quick wins are in place (perf lab, track build timing, environment/HUD baseline). Full READY requires RTX 2060 SUPER confirmation run by human + screenshot before/after package.

---

## Main performance bottleneck

| Rank | Bottleneck | Evidence |
|------|------------|----------|
| **P0** | **Input lock during mode entry** | `ModeTransitionController` swallows all input while `_busy`; was 1.1–1.2s, now 0.72–0.82s. NAV leak test: **~1.18s per Hub↔Char cycle** (shell + wait frames). Matches human “stationary UI” periods. |
| **P0** | **Perceived sluggishness ≠ low FPS on target HW** | Agent lab used **Microsoft Basic Render Driver**; Hub ~25–31 FPS. User RTX 2060 (V1_1 boot) had no parse/load failure — sluggishness is **latency-dominated**, not GPU-bound on discrete card. |
| **P1** | **Synchronous track build hitch on Play** | `[TRACK_BUILD]` solids **48–96ms** for 370 bodies; total **52–102ms** one-frame stall when pressing GENERAR. |
| **P1** | **370 separate StaticBody3D drawables** | 1209 nodes, ~80–90 draw calls after generation — acceptable but not batching merged meshes. |
| **P2** | **JeffreyButton StyleBox churn** | `_repaint()` on every hover/focus — **fixed** with paint-key cache. |
| **P2** | **4096×4096 car atlas load at TrackMain ready** | texture_mem spike logged in TRACK_ATLAS probe (~170–240MB reported). One-time load cost. |

---

## Is the PC the problem?

**PARTLY — NOT PROVEN as primary cause on RTX 2060 SUPER**

- Automated metrics on **Basic Render Driver** show low FPS — **not representative** of the user’s NVIDIA GPU.
- Physics time during samples: **<3ms** — CPU physics is not the bottleneck.
- Human sluggishness correlates with **timed input locks (≈1s)** and **transition animation**, not sustained sub-15 FPS on shell screens.
- Track **visual** quality gap is **presentation pipeline**, not hardware limitation.

---

## Renderer comparison

| | Forward+ (D3D12) | GL Compatibility |
|--|------------------|------------------|
| GPU (agent) | Microsoft Basic Render Driver | ANGLE → Basic Render Driver |
| Hub FPS avg | 25.1 | 31.0 |
| Track generated FPS avg | 10.3 | 19.7 |
| Track draw calls | ~80 | ~158 |
| NAV 10× elapsed | 11.8s | 10.4s |
| Notes | Lower FPS in agent env | Higher draw calls; ANGLE warning |

**Recommendation:** Keep **Forward+ D3D12** as primary on RTX. Re-run lab on user GPU for authoritative numbers.

---

## Shell performance

| Metric | Forward+ (agent) |
|--------|------------------|
| Hub FPS avg | 25.1 |
| Hub frame ms avg | 33.8 |
| Hub nodes | 46 |
| Hub draw calls | 47 |
| Memory static | 89.1 MB |

Post-fix: StyleBox cache reduces hover churn (not visible in avg FPS on software renderer).

---

## Character Select performance

| Metric | Forward+ (agent) |
|--------|------------------|
| FPS avg | 27.9 |
| Frame ms avg | 75.5 |
| Frame ms max | **418.4** (first-frame spike) |
| Nodes | 57 |
| Draw calls | 33 |

Spike likely texture/layout cold start — monitor on RTX.

---

## Track performance

| Metric | TRACK_EMPTY | TRACK_GENERATED | TRACK_RACE |
|--------|-------------|-----------------|------------|
| FPS avg | 18.6 | 10.3 | 10.0 |
| Frame ms avg | 58.5 | 105.4 | 109.6 |
| Nodes | 57 | 1209 | 1209 |
| Draw calls | 58 | 80 | 90 |
| Physics ms | 2.6 | 1.2 | 0.9 |

**Build breakdown (370 solids):** generate ~2ms, solids **~65ms**, checkpoints ~3ms, env ~23ms, total **~94ms**.

---

## Scene-load timings

| Event | ms (measured) |
|-------|---------------|
| Track `generate()` | 1–3 |
| Track `_place_solids()` | 48–96 |
| Track checkpoints | 2–3 |
| Track environment | 0.2–23 |
| Track total build | 52–102 |
| Mode transition (code) | 720–820 (post-fix) |
| Shell fade | 280 |
| Hub↔Char ×10 (lab) | 10.4–11.8 s |

---

## UI latency

| Finding | Detail |
|---------|--------|
| Mode transition input block | All keys swallowed in `_unhandled_input` while `_busy` |
| Pre-fix duration | 1.1–1.2s |
| Post-fix duration | **0.72–0.82s** (floor 0.55s) |
| Shell transition | 280ms fade; no global input gate (overlap possible on fast nav) |
| JeffreyButton | Hover repaint caused redundant work — **cached** |

---

## Memory

| State | Static MB | Peak MB | Orphans |
|-------|-----------|---------|---------|
| Boot empty | 84.5 | 92.6 | 0 |
| Hub | 89.1 | 94.9 | 0 |
| Track generated | 105.6 | 105.6 | 0 |
| After NAV×10 | 99.9 | 107.8 | 0 |

**Leak test:** ui_roots_alive=1 after 10 navigations — **PASS**.

---

## Track visual diagnosis

Largest gaps (see [`TRACK_PRESENTATION_GAP_V1.md`](TRACK_PRESENTATION_GAP_V1.md)):

1. Empty sky void → **quick win: procedural sky + fog**
2. No shadows / flat lighting → **quick win: shadowed sun**
3. No horizon → **quick win: ground plane**
4. HUD disconnected from Jeffrey Track identity → **quick win: cyan timer panel**
5. Kit/scenery/props → **P1 asset pipeline** (labs exist, not promoted)

---

## Quick wins implemented

- `track_race.gd` — sky, fog, tonemap, shadows, horizon plane, build timing
- `track_generator.gd` — darker road albedo
- `track_hud.gd` — Jeffrey Track cyan timer hierarchy
- `mode_transition_definition.gd` + `mode_transition_controller.gd` — shorter transitions
- `jeffrey_button.gd` — StyleBox repaint cache
- `jeffrey_perf_sampler.gd` + `JeffreyPerformanceLab.tscn` + `tools/run_jeffrey_perf_lab.py`

---

## Before / after

| Metric | Before | After |
|--------|--------|-------|
| Mode transition lock | 1.1–1.2s | 0.72–0.82s |
| Track environment | Flat BG color | Sky + fog + shadows + ground |
| Track HUD timer | 28px gold | 36px cyan panel |
| StyleBox hover churn | Every event | Cached by state key |
| Perf regression gate | None | JeffreyPerformanceLab |

Full tables: `E:\JeffreyAIResearch\outputs\runtime-review\jeffrey_perf_track_v1\performance_before.md` and `performance_after.md`

---

## Tests

| Category | Result |
|----------|--------|
| JeffreyPerformanceLab (Forward+ D3D12) | **PASS** |
| JeffreyPerformanceLab (GL Compatibility) | **PASS** |
| `tests/test_jeffrey_perf_track_diagnostic_v1.py` | **PASS** (static + lab smoke) |
| Full pytest suite | Run after merge — track_race parse verified |

---

## Remaining work

### Performance
- Re-run perf lab on **RTX 2060 SUPER** (authoritative FPS)
- Consider async/deferred track solid placement (spread over frames) if Play hitch felt on RTX
- Merge static meshes or use MultiMesh for greybox solids (370 → fewer draw calls)
- Optional: input buffer during last 100ms of transition (careful with double-nav)
- Kill/reuse shell tweens on rapid `_present`

### Visual
- Promote selective V2 kit/scenery from labs (not full overhaul)
- Road marking textures
- Track HUD frame PNG
- Human screenshots: `03_track_before`, `04_track_after`, `05_track_pause`

### Assets
- See `TRACK_PRESENTATION_GAP_V1.md` P1/P2 rows
