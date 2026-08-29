# TRACK ENVIRONMENT KIT V1 — Report

## Primary verdict

**TRACK_ENVIRONMENT_KIT_V1_PARTIAL**

Live procedural Track now has a MultiMesh-first Asunción-inspired environment kit with four presentation zones, improved sky/ground/fog, and entry preview. Physics and Copa unchanged. RTX Track FPS remains ≥90. Final look still reads as stylized low-poly primitives — bespoke mesh upgrade remains an art gap (not a systems gap).

---

## Art direction

Stylized low-poly Paraguay / Asunción roadside cues:

- streetlights, utility poles, curbs, guard rails
- small commercial / residential block masses
- billboards + Jeffrey cyan banners
- trees / palms (green zones)
- distant skyline ring + silhouette strips
- warmer late-afternoon procedural sky + haze

Not photoreal. Not Shopping del Sol. Not a city recreation.

---

## Kit pieces created/promoted

Godot-native shared meshes (no unlicensed packs; urban GLB labs left for a future MultiMesh bake sprint):

| Piece | Implementation |
|-------|----------------|
| Street light | pole + emissive head MultiMeshes |
| Utility pole | tall box |
| Low wall / fence | roadside wall segment |
| Tree A | trunk + crown |
| Palm | trunk + crown |
| Small commercial building | box mass |
| Block / residential building | taller mass |
| Billboard | pole + gold face |
| Road sign | plate |
| Guard rail | near-road rail |
| Curb / sidewalk | near-road strip |
| Distant city block | skyline ring |
| Skyline silhouette | far strip |
| Banner | cyan flag plane |
| Ground patch | roadside context pads |

Debug toggle: `SSK_TRACK_SCENERY=0` disables kit placement.

---

## Procedural placement architecture

`TrackEnvironmentPlacerV1` samples road solids (`kind=="road"`), derives lateral offsets from solid transforms, and places visual-only props outside driveline clearance.

- Near: curb / rail / signs (speed references)
- Mid: lamps / trees / walls
- Far: buildings / billboards
- Distant: skyline ring (~38–60 m)

Derived RNG from track seed (`seed * 7919 ^ constant`) — track geometry seed unchanged.

---

## Zone system

Presentation-only (not player-facing rules):

| Zone | Emphasis |
|------|----------|
| URBAN | lamps, walls, small buildings, signs |
| COMMERCIAL | billboards, large blocks, banners |
| GREEN | palms/trees, sparse buildings |
| OPEN | poles, signs, walls + skyline reliance |

Runs of 5–12 samples; palette shuffled so all four zones appear on medium+ tracks.

---

## MultiMesh architecture

- One `MultiMeshInstance3D` per kit mesh type
- Shared materials (solid colors; lamp emission)
- ~20 batches / ~200–330 instances typical
- Inventory MultiMesh count ~29 (was ~9)

No per-prop PackedScene instantiation on the live race path.

Also fixed Track rebuild: `queue_free` → immediate `free()` so preview→play no longer doubles the scene tree.

---

## Track entry improvement

`TrackMain` builds a preview world behind setup (~17–25 ms) so entry is not empty void. Production host already calls `setup()` before `add_child`.

---

## Track gameplay improvement

Road is grounded with:

- larger ground planes
- roadside kit density
- skyline ring
- warmer sky / stronger fog haze
- near-road curbs/rails/lamps for speed parallax

Still low-poly blocky — intentional V1 scaffolding, not final art.

---

## Before/after visual score (Track)

| Metric | Before (sign-off) | After (kit V1) |
|--------|-------------------|----------------|
| Art direction | 2 | **3** |
| Visual hierarchy | 3 | **3** |
| Background quality | 1–2 | **3** |
| Polish | 3 | **3** |
| Party-game feel | 2 | **3** |
| Prototype void feel | Strong | **Reduced** |

Material improvement: yes. Near-shippable Track world: no (needs authored meshes).

---

## Performance before/after

RTX 2060 SUPER · D3D12 Forward+ · 1920×1080 · `PERFORMANCE_VALID=YES`

| Scenario | Before | After | Notes |
|----------|--------|-------|-------|
| TRACK_GENERATED FPS | ~129 | **108** | ≥90 ✓ (~16% drop) |
| TRACK_RACE FPS | ~136 | **100** | ≥90 ✓ (~26% drop — at reassessment edge, still valid) |
| Draw calls | ~80 / ~92 | **~109 / ~121** | well under 200 |
| Nodes | ~850 | **~872** | controlled |
| Build | ~17–20 ms | **~19–27 ms** | OK |

---

## Nodes/draw calls

Typical media seed:

- nodes ~814 (race inventory)
- MultiMesh batches ~29
- env instances ~220–240

---

## Physics integrity

- No driving physics changes
- No track generator rule changes
- Env props are visual MultiMeshes only (no vehicle collision)
- Road/rail StaticBody collision path unchanged

---

## Tests

| Gate | Result |
|------|--------|
| pytest | **424 passed** (was 421; +env kit tests) |
| Shell parse | PASS |
| CopaJeffreyLab | PASS |
| TrackEnvironmentKitV1Lab | PASS |
| Perf Lab RTX | PASS / VALID |
| Capture package | PASS (9 PNGs) |

---

## Screenshot package

`E:\JeffreyAIResearch\outputs\runtime-review\track_environment_kit_v1\`

- `01_kit_lab.png`
- `02_track_before.png` (scenery off)
- `03_track_after_urban.png`
- `04_track_after_green.png`
- `05_track_after_commercial.png`
- `06_track_entry.png`
- `07_track_gameplay.png`
- `08_track_pause.png`
- `09_track_results.png`
- `CAPTURE_META.json`
- `perf_sanity.log`

Lab: `res://scenes/debug/TrackEnvironmentKitV1Lab.tscn`  
Capture: `res://scenes/debug/TrackEnvironmentKitV1Capture.tscn`

---

## Remaining art gaps

**Closed (systems):** P0 Track environment kit placement + MultiMesh scaffolding.

**Still open:**

| Pri | Gap |
|-----|-----|
| P0 | Track HUD frame (bespoke) |
| P1 | Promote urban GLB kit into MultiMesh/shared-mesh bake (palms, buildings, lamps) for higher art quality |
| P1 | Track / Zombies result banners |
| P1 | Copa podium |

Do not hide these with random gradients.

---

## Next recommended sprint

**ART ASSETS** — Track HUD frame first (P0), then MultiMesh bake of existing urban GLBs into this placer, then result banners.

Not another performance sprint unless FPS falls below 90 on RTX.
