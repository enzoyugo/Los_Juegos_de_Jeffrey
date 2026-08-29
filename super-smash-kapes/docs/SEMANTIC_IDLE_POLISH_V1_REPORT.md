# Semantic Idle Polish V1

## Primary Verdict

**SSK_SEMANTIC_IDLE_POLISH_V1_READY_FOR_HUMAN_APPROVAL**

Tereré Semantic Idle was polished with small, documented standing offsets. Jaguareté Semantic Idle standing pose is preserved; only a light intra-clip hip XY plant was added. Both candidates remain technically healthy (`STANDING_IDLE`, 101 bones, volume ≤ 1.35, extreme verts 0, limb-length error 0). Traditional Idle, Clean Rig V1, battle, and Production V4 were not touched.

This is not a production wire. Human A/B/C in the polish labs is the remaining authority.

## Human Baseline

Frozen in `docs/generated/SEMANTIC_IDLE_POLISH_V1_BASELINE.json` (hashes of the current `idle_benchmark_v1` semantic GLBs/blends). Those files were **not** overwritten.

Human notes going in:

- **Jaguareté:** almost production-ready. Keep pose and motion. Inspect 0.24 m foot drift vs rest and high hand from-down.
- **Tereré:** clearly better than rest/traditional, no longer T-pose, animation healthy, but torso slightly compressed/hunched and arms/hands a bit held. Modest polish, not a rewrite.

## Tereré Issues

From the frozen semantic bake:

- `CC_Base_Spine01` standing primary sat at SAFE **+12°** with **10.9° match error** vs Mixamo torso lean ~1°. Rest spine is already ~14° from up, so the clamp left a hunched read.
- Shared clavicle 8°/5° shrugged the poncho line.
- Elbows ~81°/75° read as Mixamo “held forward”.
- Hands 10°/6° plus Mixamo intra kept wrists a bit posed.
- Knee standing 40° on a short vessel body reads as squat/compression.
- Foot drift 0.105 m is mostly stance vs T-pose rest, not a walk.

## Tereré Changes

All offsets live in `POLISH["terere"]` in `tools/blender/semantic_idle_polish_v1.py`. No per-frame character hacks.

| Parameter | Baseline | Polish |
| --- | --- | --- |
| Spine01 primary / SAFE | +12 / 12 | **+18 / 24** (unhunch toward Mixamo ~1° from up) |
| Clavicle | 8 / 5 | **3 / 1.5** |
| Upperarm | solved 44 / 52 | **+6°** extra lowering |
| Elbow | 80 | **× 0.78** (~62°) |
| Knee | 40 | **× 0.55** (~22°) |
| Hand | 10 / 6 | **4 / 1** |
| Channel gain | 1.0 | 0.90 |
| Head intra | 1.0 | 0.60 |
| Torso intra | 1.0 | 0.75 |
| Knee intra | 1.0 | 0.85 |
| Foot stabilize | off | hip XY plant, gain 0.55 |

Mid-pose vs frozen semantic:

| Metric | Baseline | Polished |
| --- | --- | --- |
| Volume ratio | 0.655 | **0.775** (less collapsed bbox) |
| Spine from up | ~14.3° | **10.8°** |
| L/R upperarm from-down | 37.1° / 30.3° | 35.7° / 28.3° |
| L/R elbow | 81.1° / 75.0° | **62.3° / 59.0°** |
| L/R hand from-down | 52.8° / 56.6° | **37.7° / 39.2°** |
| Foot vs rest | 0.105 m | **0.069 m** |
| Root XZ | 0.018 m | **0.006 m** |
| Extreme verts | 0 | 0 |
| Class | STANDING_IDLE | STANDING_IDLE |

Hands stay below shoulders. Not T-pose (upperarm from-down remains ~28–36°, not ~87°).

The vessel mesh still reads as a cup from the side; polish does not reshape the model.

## Jaguareté Preservation

`preserve_standing: true` copies frozen `standing_ops` (Spine01 **−4°**, upperarms 36/44, elbows 68/80, hands 10/6). No global amplitude cut.

Only intra-clip hip XY compensation (gain 0.40) so feet wander less during the clip.

High hand from-down (~95–102°) is **kept**. Human already signed off on the look.

## Foot Drift

`max_foot_drift` is measured **vs T-pose rest**. Bent-knee standing will always show centimeters of delta. That is stance, not sliding.

Intra-clip travel (plant quality):

| Fighter | vs rest (baseline → polish) | Intra-clip L/R travel | Pelvis XY correction |
| --- | --- | --- | --- |
| Tereré | 0.105 → 0.069 m | 0.029 / 0.030 m | 0.006 m |
| Jaguareté | 0.237 → 0.221 m | 0.034 / 0.035 m | 0.010 m |

Jaguareté 0.24 m vs rest is the standing knee pose the human liked. No IK, no snapping. Root XZ stays ≤ 0.010 m.

## Hand / Arm Pose

**Tereré:** elbows opened from ~80° toward ~60°; upperarms lowered 6°; wrists 4°/1° instead of 10°/6°. Still bent, not locked.

**Jaguareté:** unchanged standing arm/hand ops. Palms that read high from-down remain, per “do not over-polish”.

## Silhouette

Blender stills (mid clip): `docs/generated/semantic_idle_polish_v1_screenshots/{terere,jaguarete}_{front,three_quarter,side}.png`

Tereré: compact, hands below shoulder line, elbows readable, feet planted, torso ~3.5° more upright than baseline. Jaguareté: same production-ready silhouette with a slightly stabler plant.

## Deformation Metrics

Gates: 101 bones, volume ≤ 1.35, extreme verts 0, limb-length error ~0, STANDING_IDLE, no sideways, no root walk.

| Candidate | Volume | Extreme | Limb | Root XZ | Class | Pass |
| --- | --- | --- | --- | --- | --- | --- |
| Tereré polished | 0.775 | 0 | 0 | 0.006 | STANDING_IDLE | yes |
| Jaguareté polished | 0.920 | 0 | 0 | 0.010 | STANDING_IDLE | yes |

GLB roundtrip: both **101 bones**, `technical_pass true`.

## GLB Roundtrip

| File | Roundtrip |
| --- | --- |
| `terere_idle_semantic_polished_v1.glb` | ok, 101 bones, STANDING_IDLE |
| `jaguarete_idle_semantic_polished_v1.glb` | ok, 101 bones, STANDING_IDLE |

No legacy orientation hacks. No runtime proxy. Textures still packed Clean Rig PBR (2048 Diffuse + Normal).

## Human A/B Instructions

F6, click the game window. Editor 3D numbers still move the viewport camera (Emulate Numpad).

**Tereré:** `scenes/debug/TerereSemanticIdlePolishV1Lab.tscn`

**Jaguareté:** `scenes/debug/JaguareteSemanticIdlePolishV1Lab.tscn`

| Key | Overlay |
| --- | --- |
| 1 | REST |
| 2 | SEMANTIC BASELINE (frozen `idle_benchmark_v1` semantic) |
| 3 | SEMANTIC POLISHED |
| 4 / 5 / 6 | skeleton / bbox / reset camera |

Same camera for all three. Judge: Tereré 3 vs 2 for less hunch / less held arms; Jaguareté 3 vs 2 should look almost identical.

## Production Safety

- Clean Rig V1 `.blend`/`.glb` hashes unchanged
- `idle_benchmark_v1` semantic hashes unchanged
- Traditional Idle unchanged
- FighterCatalog / V4 unchanged
- Battle HUD / gameplay unchanged
- Polish writes only to `semantic_idle_polish_v1/`

## Files Created

- `docs/generated/SEMANTIC_IDLE_POLISH_V1_BASELINE.json`
- `tools/blender/semantic_idle_polish_v1.py`
- `assets/fighters/processed/semantic_idle_polish_v1/terere/terere_idle_semantic_polished_v1.blend` / `.glb`
- `assets/fighters/processed/semantic_idle_polish_v1/jaguarete/jaguarete_idle_semantic_polished_v1.blend` / `.glb`
- `scenes/debug/TerereSemanticIdlePolishV1Lab.tscn`
- `scenes/debug/JaguareteSemanticIdlePolishV1Lab.tscn`
- `scripts/debug/terere_semantic_idle_polish_v1_lab.gd`
- `scripts/debug/jaguarete_semantic_idle_polish_v1_lab.gd`
- `scripts/debug/validate_semantic_idle_polish_v1_labs.gd`
- `tests/test_semantic_idle_polish_v1.py`
- metrics / roundtrip / Godot JSON under `docs/generated/`
- screenshots under `docs/generated/semantic_idle_polish_v1_screenshots/`

Touched for overlay reuse only: `scripts/debug/idle_retarget_benchmark_lab.gd` (optional overlay titles + polish pipeline id). Existing rest/traditional/semantic labs keep default labels.

## Recommended Next Step

Human F6 A/B/C. If Tereré polished reads as the better idle and Jaguareté is unchanged-or-better, keep these GLBs as the Semantic Idle candidate. **Do not wire into battle until that approval.**
