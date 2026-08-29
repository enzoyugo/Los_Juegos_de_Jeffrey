# Semantic Idle Polish V2

## Primary Verdict

**SSK_TERERE_SEMANTIC_IDLE_POLISH_V2_READY_FOR_HUMAN_SELECTION**

Tereré Semantic Idle was restored from the frozen Idle Benchmark V1 semantic standing pose, then given three tiny standing-only variants (A minimal, B moderate, C compact). Jaguareté approved V1 remains byte-frozen and was not rebaked. No candidate is auto-selected. Human silhouette choice is the remaining authority.

This is not a production wire. Battle, catalog, Clean Rig, Traditional Idle, and Production V4 were not touched.

## Human Rejection of V1

Tereré Polish V1 was **rejected on silhouette**, even though volume/upright metrics improved.

Observed V1 problems:

- arms too open / too horizontal
- silhouette closer to a lowered T-pose
- shoulders too spread
- elbows too open (standing elbow 80° scaled to ~62°)
- hands too far from the torso
- torso technically straighter but lost the compact, characterful stance
- frozen baseline looked more natural overall

Jaguareté Polish V1 is **approved / near-production** and is frozen as `JAGUARETE_SEMANTIC_IDLE_APPROVED_V1`.

## Why Metrics Misled V1

V1 ranked toward higher volume ratio and a more vertical spine. Those numbers came from opening elbows, dropping clavicles hard (8/5 → 3/1.5), extra upperarm lowering (+6°), unhunching spine (+12 → +18), and unsquatting knees (40 → ~22). The mesh filled more of its rest bbox, so volume rose (0.655 → 0.775), but the readable fighter silhouette got worse.

V2 treats metrics as **guardrails only** (101 bones, extreme verts 0, limb lengths stable, `STANDING_IDLE`). Candidates are **not** ranked by volume or spine-from-up.

## Frozen Baseline

Authority: Idle Benchmark V1 semantic `terere_idle_semantic_clean_v1` (hashes in `docs/generated/SEMANTIC_IDLE_POLISH_V1_BASELINE.json`).

`TERERE_V2_BASE` is a byte-identical copy of that GLB. All V2 candidates start from its `standing_ops`:

| Bone | Primary / secondary |
| --- | --- |
| Spine01 | 12 / 0 |
| Clavicles | 8 / 5 |
| Upperarms | 44 / 52 |
| Forearms (elbows) | 80 / 80 |
| Calves (knees) | 40 / 40 |
| Hands | 10 / 6 |
| Head | -8 / 0 |

Intra-idle Mixamo channels stay at gain 1.0. No foot stabilize. Knees never change.

## Candidate A

**V2_A MINIMAL — 95% baseline**

| Offset | Baseline | A |
| --- | --- | --- |
| Spine | 12 | 12 |
| Clavicle | 8 / 5 | 7.5 / 4.5 |
| Upperarm add | 0 | +1 |
| Elbow add | 0 | **+2** (82°, more bend, not less) |
| Hand | 10 / 6 | 9 / 5.5 |

Frame-1 silhouette: spine 12.0° from up, L/R upperarm 35.1°/27.6° from down (≈55°/62° down from horizontal), elbows **81.8°/78.6°**. Volume 0.657. Technical pass. 101 bones.

## Candidate B

**V2_B MODERATE — 90% baseline**

| Offset | Baseline | B |
| --- | --- | --- |
| Spine | 12 | **11** (−1° only) |
| Clavicle | 8 / 5 | 7 / 4 |
| Upperarm add | 0 | +2 |
| Elbow add | 0 | **+4** (84°) |
| Hand | 10 / 6 | 8.5 / 5 |

Frame-1 silhouette: spine 12.2° from up, L/R upperarm 34.7°/27.2° from down, elbows **83.8°/80.6°**. Volume 0.647. Technical pass. 101 bones.

## Candidate C

**V2_C COMPACT — baseline torso, slightly more compact arms**

| Offset | Baseline | C |
| --- | --- | --- |
| Spine | 12 | **12** (torso kept) |
| Clavicle | 8 / 5 | 6.5 / 3.5 |
| Upperarm add | 0 | +1.5 |
| Elbow add | 0 | **+6** (86°) |
| Hand | 10 / 6 | 8 / 4.5 |

Frame-1 silhouette: spine 12.0° from up, L/R upperarm 35.8°/28.3° from down, elbows **85.8°/82.6°**. Volume 0.653. Technical pass. 101 bones.

## Silhouette Comparison

Contact sheet: `docs/generated/TERERE_IDLE_POLISH_V2_CONTACT_SHEET.png`

Rows (top to bottom, color stripe): **BASELINE** (blue), **REJECTED V1** (red), **V2_A** (green), **V2_B** (yellow), **V2_C** (cyan).

Columns: t=0.0 / 0.9 / 1.8 / 2.7, front then three-quarter.

Godot lab (same camera when switching, shared clip time):

`scenes/debug/TerereSemanticIdlePolishV2Lab.tscn`

Keys: **1** BASELINE · **2** REJECTED V1 · **3** V2_A · **4** V2_B · **5** V2_C · **6** camera reset · Space pause.

Run with F6. Editor number keys still move the viewport camera.

## Technical Gates

All three V2 candidates:

- pose class `STANDING_IDLE`
- technical pass
- 101 bones on GLB roundtrip
- extreme verts = 0
- limb-length relative error = 0
- volume ratio ~0.65 (near baseline 0.655; V1's 0.775 was the misleading “win”)
- knees unchanged at 40°
- elbows bent *more* than baseline, never opened like V1

## Jaguareté Freeze

Record: `docs/generated/JAGUARETE_SEMANTIC_IDLE_APPROVED_V1.json`

Approved V1 polished GLB was hashed and not regenerated. Do not rebake unless a future byte-for-byte equivalent export is required.

## Human Selection Instructions

1. Open `scenes/debug/TerereSemanticIdlePolishV2Lab.tscn` and press F6.
2. Compare 1 (baseline you liked) vs 2 (rejected V1) vs 3/4/5.
3. Pick the variant that still reads SHORT / COMPACT / READY / RELAXED / ALIVE at gameplay distance.
4. If none beat baseline, keep baseline. Do not ship V1.

Do not pick by highest volume or most vertical spine.

## Production Safety

Not wired into battle. Unchanged: Clean Rig V1, Traditional Idle, FighterCatalog, hitboxes, hurtboxes, other clips, Production V4 GLBs.

## Files Created

- `tools/blender/semantic_idle_polish_v2.py`
- `assets/fighters/processed/semantic_idle_polish_v2/terere/terere_idle_semantic_v2_base.glb`
- `assets/fighters/processed/semantic_idle_polish_v2/terere/terere_idle_semantic_polished_v2_{a,b,c}.glb`
- `scenes/debug/TerereSemanticIdlePolishV2Lab.tscn`
- `scripts/debug/terere_semantic_idle_polish_v2_lab.gd`
- `scenes/debug/ValidateSemanticIdlePolishV2Labs.tscn`
- `docs/generated/TERERE_IDLE_POLISH_V2_CONTACT_SHEET.png`
- `docs/generated/SEMANTIC_IDLE_POLISH_V2_RUN.json`
- `docs/generated/JAGUARETE_SEMANTIC_IDLE_APPROVED_V1.json`
- `docs/generated/TERERE_V2_BASE.json`
- `tests/test_semantic_idle_polish_v2.py`

## Recommended Next Step

Human A/B/C in the V2 lab. After a pick, freeze that GLB as Tereré Semantic Idle authority. Only then consider a separate, explicit production-wire task.

No commit. No push.
