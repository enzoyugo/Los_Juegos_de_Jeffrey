# TRACK VISUAL QUALITY V2 — Report

## Primary verdict

**TRACK_VISUAL_QUALITY_V2_PARTIAL**

Authored palette, road/curb separation, facade/signage atlases, start gantries, HUD language cleanup, and compact Track results are live on the existing MultiMesh/placer stack. Screenshot authority still reads **early polished indie / late prototype**, not trailer-ready polished indie — ground remains a flat green plane, asphalt is still smooth slabs, and distant skyline is easy to miss at race FOV.

---

## Screenshot-based visual verdict

| Question | Answer |
|----------|--------|
| Road visually readable? | **YES** — darker asphalt + edge lines + cream curbs |
| Clear world/road separation? | **PARTIAL** — better tonal split; ground still planar |
| Feel grounded? | **PARTIAL** |
| Background depth? | **PARTIAL** — skyline denser/closer; still weak in chase FOV |
| Buildings more than blank blocks? | **YES** — palette + triplanar facade windows |
| Recognizable art direction? | **PARTIAL** — cyan/gold Track identity; world still soft |
| HUD like game UI? | **YES** — micro-chips, Spanish labels, hint strip |
| Debug residue? | **MOSTLY CLEARED** |
| Interesting at first glance? | **PARTIAL** |
| Acceptable in prototype trailer? | **PARTIAL** — entry/results improved; race world not yet |

---

## Top 10 visual defects before

1. Giant flat grey ground  
2. Road ≈ environment tonal family  
3. Untextured building boxes  
4. Weak horizon / skyline  
5. Empty pale sky  
6. Guardrail dominance  
7. Weak roadside material identity  
8. No Asunción cues  
9. Unbelievable road surface  
10. Debug HUD / empty results / seed presentation  

---

## Fixes implemented

- `TrackVisualQualityV2` palette + facade atlas + signage atlas  
- Road asphalt / shoulder / curb / rail materials (collision sizes unchanged)  
- Visual-only curb solids  
- Lane edge + center markings  
- Layered ground tones + parking patches  
- Building material variants with triplanar facade  
- Signage atlas on billboard faces (UV-friendly boxes)  
- Barrier density reduced by zone  
- Start/finish gantries + checkpoint markers  
- Camera look-down (`CAM_LOOK_Y`, height/FOV/look-ahead tune)  
- HUD chips, Spanish terms, seed → `Pista #`, control hint strip  
- Compact Track results card  

---

## Road

Dark asphalt (`#1c2128`), warm shoulder, cream curb, darker concrete rails, white edge lines. Collision unchanged.

## Ground

Dirt / grass / concrete layers + parking MultiMesh patches. Still planar (no terrain height).

## Buildings

8-family palette; 4 MultiMesh material buckets; triplanar facade atlas (windows + storefront band).

## Horizon / sky

Warmer late-afternoon sky, reduced fog, closer denser skyline (16 blocks @ ~28 m). Chase FOV still shows lots of sky.

## Signage

`res://assets/track/environment/runtime/signage_atlas_v2.png` (1024×512, 8 boards). Live on billboard faces.

## Start/finish

Lightweight gantry + emissive paint (Area3D collision unchanged).

## Checkpoints

Paired marker posts + road paint (finish uses gantry).

## HUD

Micro side chips; `CONTROL` / `PUESTO` / `COMBUSTIBLE` / `RENDICIÓN`; no `P1 P1` duplication; hint strip; setup card + `Pista #`.

## Results

Compact Track shell (`±380×±200`), cyan wash, no expand spacer. Copa rows unchanged.

## Local identity

Warm plaster palette, palms retained, Tereré/Gallo/Costanera fictional boards, Asunción late-afternoon light. Not literal city recreation.

## Visual score before/after

| | Art V1 | VQ V2 |
|--|--------|-------|
| Art direction | 3–4 | **4** |
| Background | 3–4 | **3–4** |
| Asset quality | 3–4 | **4** |
| Polish | 4 | **4** |
| Party feel | 3–4 | **4** |

Gate: still **not** forced 5/5. Screenshot class: early polished indie.

## Performance before/after

RTX 2060 SUPER · D3D12 Forward+ · VALID

| | Art V1 | VQ V2 |
|--|--------|-------|
| TRACK_GENERATED | ~111 FPS / ~114 draw | **~95 FPS / ~134 draw** |
| TRACK_RACE | ~119 FPS / ~126 draw | **~109 FPS / ~146 draw** |
| Nodes (media) | ~877 | **~904** |
| MultiMesh batches | ~25–29 | **~38** |

≥90 FPS preserved; draw ≤150 preferred (race ~146).

## Physics integrity

Unchanged. Curbs `visual_only`. Checkpoint Areas unchanged. Rails collision sizes unchanged.

## Copa integrity

Unchanged (5/3/2/1/DNF=0, match_id). UI displays awarded rows only.

## Tests

VQ2 gates + SDS firewall camera lock loosened. Full pytest run after report.

## Screenshot package

`E:\JeffreyAIResearch\outputs\runtime-review\track_visual_quality_v2\`  
14 PNGs + `CAPTURE_META.json`

## Remaining art gaps

| Pri | Gap |
|-----|-----|
| P0 | Ground still reads as editor plane — needs cheap noise/terrain break |
| P0 | Road needs asphalt grain / wear (small shared texture) |
| P1 | Skyline must occupy chase FOV more (or camera/composition further) |
| P1 | Billboard atlas readability at distance |
| P1 | Zombies banner / Copa podium (out of scope) |
| P2 | True painted HUD frame PNG |

## Next recommended sprint

**TRACK WORLD SURFACE V1** — asphalt grain + ground breakup + chase-FOV skyline composition. Not another placer. Not performance.
