# TRACK ART ASSETS V1 — Report

## Primary verdict

**TRACK_ART_ASSETS_V1_PARTIAL**

Track HUD now has intentional cyan racing chrome (dynamic labels preserved). Existing urban GLBs are baked to `res://assets/track/environment/runtime/*.res` and promoted into the existing MultiMesh placer. Track results use a Track-branded banner. Physics and Copa unchanged. RTX Track FPS remains ≥90 (Race ~119). Final “authored party-game art” still needs richer textures/signage atlas and a true PNG HUD frame if desired — systems + first-party promotion are in place.

---

## Existing GLB inventory

| Asset | Path | ~KB | Action |
|-------|------|-----|--------|
| lamp_street | `assets/environments/shared/urban/lighting/lamp_street.glb` | 6.4 | **PROMOTE** |
| barrier_01 | `.../street_props/barrier_01.glb` | 3.7 | **PROMOTE** |
| building_small_01 | `.../street_props/building_small_01.glb` | 16.7 | **PROMOTE** |
| building_med_01 | `.../street_props/building_med_01.glb` | 38.4 | **PROMOTE** |
| building_mid_01 | `.../processed/architecture/building_mid_01.glb` | 49.9 | PROMOTE (fallback/skyline) |
| building_shop_01 | `.../processed/architecture/building_shop_01.glb` | 19 | REFERENCE / baked |
| tower_01 | `.../processed/architecture/tower_01.glb` | 70.3 | **PROMOTE** (skyline) |
| billboard_01 | `.../street_props/billboard_01.glb` | 5.2 | **PROMOTE** |
| palm_v2_01 | `.../processed/vegetation/palm_v2_01.glb` | 23.8 | **PROMOTE** |
| tree_v2_01 | `.../processed/vegetation/tree_v2_01.glb` | 15.3 | **PROMOTE** |
| fence_01 | `.../street_props/fence_01.glb` | 10.6 | REFERENCE (baked) |
| wreck/vaz/hilux/market/cement/psx | various 1–26 MB | — | **REJECT** (too heavy / wrong role) |

---

## Assets promoted

Baked runtime meshes:

- `res://assets/track/environment/runtime/lamp_street.res`
- `res://assets/track/environment/runtime/barrier.res`
- `res://assets/track/environment/runtime/building_small.res`
- `res://assets/track/environment/runtime/building_med.res`
- `res://assets/track/environment/runtime/building_mid.res`
- `res://assets/track/environment/runtime/building_shop.res`
- `res://assets/track/environment/runtime/tower.res`
- `res://assets/track/environment/runtime/billboard.res`
- `res://assets/track/environment/runtime/palm.res`
- `res://assets/track/environment/runtime/tree.res`
- `res://assets/track/environment/runtime/fence.res`

Live MultiMesh piece IDs: LAMP/TREE/PALM/BUILDING_SMALL/BUILDING_BLOCK/BILLBOARD/BARRIER/SKYLINE_PROMOTED.

Source GLBs preserved.

---

## Assets rejected

Heavy vehicle/industrial/market GLBs (see inventory) — not MultiMesh-friendly for Track race density.

---

## Runtime mesh bake

`TrackEnvRuntimeMeshesV1.bake_all_to_disk()` extracts largest/merged meshes from GLBs and saves `.res` under `assets/track/environment/runtime/`. Lab re-bakes safely. Live path prefers baked `.res`, falls back to extract.

---

## Materials

Shared palette retained for primitives. **Promoted GLB MultiMeshes keep authored materials** (no flattening override). Selective shadows on buildings/trees/barriers; skyline/lamps/billboards off.

---

## HUD frame

`TrackHudChromeV1` — first-party StyleBox racing chrome:

- asymmetric cyan frame, accent bar, ▸ TRACK ◂ brand row
- PRIMARY timer
- SECONDARY `MEJOR`
- side chips for driver / checks / rank / fuel

Dynamic text only. Countdown uses large cyan digits + **DALE**. Checkpoint flash + FINISH flash added.

Status: intentional Track identity — not a plain debug Label. Still not a bespoke PNG illustration (documented if artist wants a painted frame).

---

## Countdown / checkpoint / finish

- Countdown: large cyan numbers → **DALE**
- Checkpoint: brief cyan `CHECK n / total`
- Finish: `FINISH · time` then results after existing delay

---

## Result banner

Racing mode results show Track cyan banner (`TRACK` / `RESULTADO`) above Copa standings. Copa points still from `JeffreyCore` awarded rows only.

---

## Visual before/after

| Metric | Env kit V1 | Art assets V1 |
|--------|------------|---------------|
| Art direction | 3 | **3–4** |
| Background | 3 | **3–4** |
| Asset quality | 2–3 | **3–4** |
| Polish | 3 | **4** (HUD/results) |
| Party-game feel | 3 | **3–4** |

Material improvement: yes. Near-shippable illustrated art: not yet.

---

## Performance before/after

RTX 2060 SUPER · D3D12 Forward+ · VALID

| | Env kit V1 | Art V1 |
|--|------------|--------|
| TRACK_GENERATED FPS | ~108 | **~111** |
| TRACK_RACE FPS | ~100 | **~119** |
| Draw | ~109 / ~121 | **~114 / ~126** |
| Nodes | ~872 | **~877** |
| Build | ~19–27 ms | **~20–33 ms** |

≥90 FPS preserved; draw &lt;140.

---

## Copa integrity

Unchanged (5/3/2/1/DNF=0, match_id). Lab PASS.

---

## Physics integrity

Unchanged. Env still visual-only MultiMesh.

---

## Tests

**428 pytest passed** · Shell parse PASS · Copa PASS · Art lab PASS · Perf VALID

---

## Screenshot package

`E:\JeffreyAIResearch\outputs\runtime-review\track_art_assets_v1\`

15 PNGs (entry/urban before/after, commercial/green/open, HUD, countdown, checkpoint, finish, results, art lab) + `CAPTURE_META.json` + `perf_sanity.log`

---

## Remaining asset gaps

| Pri | Gap |
|-----|-----|
| P1 | Optional painted PNG Track HUD frame (chrome StyleBox is interim shippable) |
| P1 | Signage atlas (LOS JUEGOS / COPA text boards) |
| P1 | Zombies result banner |
| P1 | Copa podium |
| P2 | Richer building/vegetation texture pass on promoted meshes |

---

## Next recommended sprint

**ART ASSETS** — signage atlas + optional painted HUD frame, then Zombies banner / Copa podium. Not performance. Not another placer rewrite.
