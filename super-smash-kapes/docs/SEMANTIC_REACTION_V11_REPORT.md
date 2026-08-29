# Semantic Reaction V1.1

Impact-readability polish on frozen Reaction V1. Torso / hip / head overlay only. Not wired into battle. No candidate is auto-selected.

## Primary Verdict

**SSK_SEMANTIC_REACTION_V11_READY_FOR_HUMAN_SELECTION**

Three candidates (LIGHT / MEDIUM / STRONG) baked for both fighters. All six are technically healthy (`HIT_REACTION`, 101 bones, 0 extreme verts, limb error 0, root X/Z 0, start/end continuity 0). Isolated comparison labs load without per-frame errors.

Human still chooses V1, LIGHT, MEDIUM, STRONG, or NONE. This report does not rank them.

## Human Finding

Reaction V1 was technically healthy and visible, but read as a small flinch / surprise rather than a fighting-game hit. Peak torso vs idle was ~1.1° (Tereré) / ~1.2° (Jaguareté). Primary weakness: torso / hip recoil.

V1.1 keeps V1 arm, foot, root, and timing logic and adds a calibrated pitch overlay.

## Frozen Reaction V1

Immutable baseline: `docs/generated/FROZEN_SEMANTIC_REACTION_V1.json`. V1 GLBs were not overwritten.

| Fighter | V1 GLB SHA256 | Peak torso V1 |
|---|---|---|
| Tereré | `cbc7397f3e5ab48c9d8a3f02e249f228aa9cf3125d72bc9db39ff88157f0deaf` | 1.104° |
| Jaguareté | `782028a8c484ee32648c3d2b30bff45e6161871ad087a6a83f3efd21936a5dd1` | 1.202° |

Approved idle authorities and Production V4 hashes still match. Clean Rig V1 was not modified.

## Torso Recoil Design

V1 spine-vs-character-up barely moved (~1°) because Pose B already uses most of the Spine01 SAFE clamp, and hip rotation tilts the whole character so that metric stays flat.

V1.1 measures **world torso tilt**: character up (head−hip) vs world Z. That is what reads at gameplay distance.

Overlay (after V1 ops, arms untouched except safety clamp):

1. Hip local pitch on the axis that raises world tilt with ~0 yaw (Tereré `local_x-`, Jaguareté `local_x+`). 10° hip → 10° world tilt, 0° yaw.
2. Unclamped Spine01 extra on the native flex axis, signed so world tilt increases.
3. Head extra on the native nod axis, **3 frames later**, smaller than torso.

Baker: `tools/blender/semantic_reaction_v11.py`. Outputs:

`assets/fighters/processed/semantic_reaction_v11/{fighter}/{fighter}_semantic_reaction_v11_{a,b,c}.{glb,blend}`

Animation name remains `reaction`. Traditional Mixamo→CC CoB was not used.

## Hip Conversion

Mixamo horizontal hip travel stays converted as in V1 (no world X/Z). V1.1 adds:

- small FK hip pitch (LIGHT ~2.2°, STRONG ~5.5°)
- extra vertical compression (LIGHT 0.012 m, STRONG 0.024 m at peak envelope)
- extra knee flex (LIGHT 0.8°, STRONG 2.2° at peak envelope)

Hip location is restored after rotation so compression is kept. Root X/Z remains 0.

## Head Lag

Head overlay uses the same recoil envelope shifted **−3 frames**. Amplitude is subordinate in pose-op degrees (head peak extra ~2.6° LIGHT / ~5.5° STRONG vs larger spine extra). Recovery is the same Mixamo shape as V1, so head does not keep bobbling after the body returns.

## Candidate Light

Target world torso 5–7° (aimed 6°).

| | Tereré | Jaguareté |
|---|---|---|
| Peak world torso | **5.673°** | **5.258°** |
| In band | yes | yes |
| Peak upperarm vs idle | 12.093° | 19.618° |
| Max from-down | 36.304° | 38.863° |
| Min elbow | 78.7° | 77.7° |
| Yaw (XY) | 0.29° | 0.03° |
| L/R foot XY span | 0.024 / 0.014 m | 0.021 / 0.021 m |
| Extreme verts | 0 | 0 |
| GLB SHA256 | `9a960142dcdda746e6c0a9bd7d78ff503f201c5a64c4d50c8a80b04ca2be8773` | `20e40791b709e8f6f3d933430785f2b663cbfa7788bfd735a200adf1c6ae718f` |

## Candidate Medium

Target 8–11° (aimed 9.5°).

| | Tereré | Jaguareté |
|---|---|---|
| Peak world torso | **9.174°** | **8.667°** |
| In band | yes | yes |
| Peak upperarm vs idle | 11.823° | 19.722° |
| Max from-down | 36.310° | 38.861° |
| Min elbow | 78.7° | 77.7° |
| Yaw (XY) | 0.29° | 0.03° |
| L/R foot XY span | 0.032 / 0.023 m | 0.027 / 0.036 m |
| Extreme verts | 0 | 0 |
| GLB SHA256 | `e805b8efc8756cb436e30e8c69a21fb830acdad4d64e81d0dcfad0112e5f9d30` | `fdcc6efb22f61beb8e150dd529763d8980a5f3d2a232fa987089e40b57d14dc3` |

## Candidate Strong

Target 12–15° (aimed 13.5°).

| | Tereré | Jaguareté |
|---|---|---|
| Peak world torso | **13.177°** | **12.635°** |
| In band | yes | yes |
| Peak upperarm vs idle | 11.540° | 19.825° |
| Max from-down | 36.316° | 38.859° |
| Min elbow | 78.7° | 77.7° |
| Yaw (XY) | 0.28° | 0.02° |
| L/R foot XY span | 0.042 / 0.035 m | 0.046 / 0.054 m |
| Extreme verts | 0 | 0 |
| Volume vs T-pose rest | 0.646 | 1.008 |
| GLB SHA256 | `8e2c591862c515326270697f18f54f8709d67bafef1e0f11a6fc59fd8881b398` | `e64b8a50a778ace01e180ee80352de794944a2482822ec0fab9639fb680fcf57` |

Ordered LIGHT < MEDIUM < STRONG on both fighters. Jaguareté STRONG volume 1.008 is vs T-pose rest (leaned silhouette), not a mesh spike; extreme verts stay 0.

## Arm Preservation

V1 arm ops and safety limits are reused. Overlay does not raise upperarm / elbow / wrist gains.

| | V1 from-down | V1.1 max from-down (A/B/C) | V1 peak arm | V1.1 peak arm |
|---|---|---|---|---|
| Tereré | 36.294° | 36.304 / 36.310 / 36.316° | 12.588° | 12.093 / 11.823 / 11.540° |
| Jaguareté | 38.867° | 38.863 / 38.861 / 38.859° | 19.417° | 19.618 / 19.722 / 19.825° |

Arms stay compact. Elbows stay bent (min 78.7° / 77.7°). Tiny from-down change is secondary follow from torso pitch, under V1 + 8°.

## Grounding

Root X/Z = 0 on all six bakes and GLB roundtrips. No stance widen. Foot XY span rises slightly with STRONG hip pitch (still centimeters, not a slide step). Extra knee / hip Z compression is envelope-shaped and returns to idle.

## Continuity

Motion weight is 0 at frames 1 and 56. Overlay shape is 0 there. Measured start/end vs approved idle:

spine, L/R upperarm, L/R elbow, L/R hand, hip = **0.0** on every candidate.

IDLE → REACTION → IDLE should not snap.

## Godot Lab

Standalone. Does not extend other labs. No skeleton/bbox debug. No `global_position` before `add_child`. No battle / HUD.

| Lab | Path |
|---|---|
| Tereré | `scenes/debug/TerereSemanticReactionV11Lab.tscn` |
| Jaguareté | `scenes/debug/JaguareteSemanticReactionV11Lab.tscn` |
| Script | `scripts/debug/semantic_reaction_v11_lab.gd` |
| Launcher | `tools/launch_semantic_reaction_v11.ps1` |

Keys:

1. APPROVED IDLE  
2. ORIGINAL REACTION V1  
3. V1.1 LIGHT  
4. V1.1 MEDIUM  
5. V1.1 STRONG  
6. reset camera  

Single-trigger only: idle → selected clip once → idle. Camera is closer than V1 (Tereré y=1.45 z=4.15, Jaguareté y=1.9 z=5.45) so torso/head can be judged without losing the feet.

Headless load (`--quit-after 180`, `gl_compatibility`, Dummy audio): both labs printed IDLE at t=0, exit 0, no `SCRIPT ERROR`, no `is_inside_tree`, no `Array[Node]` assignment.

## Human Selection Required

Do not treat LIGHT / MEDIUM / STRONG as a ranked list. Play both labs and pick:

- keep **V1** (current flinch)
- **LIGHT** (~5–6° world torso)
- **MEDIUM** (~9°)
- **STRONG** (~13°)
- or **NONE**

Goal: a hit that is instantly readable at gameplay distance without looking cartoonishly broken.

## Production Safety

- `wired_into_battle`: false  
- `auto_selected`: false  
- `reaction_v1_modified`: false  
- `idle_assets_modified`: false  
- `FighterCatalog` still `pipeline_id = "ACTORCORE_V4"`  
- pytest `tests/test_semantic_reaction_v11.py`: 5 passed  

Do not ship a candidate into gameplay until a human picks one.

## Recommended Next Step

Human A/B in the V1.1 labs (keys 2–5). If a candidate is approved, freeze that GLB as Reaction V1.1 authority and only then consider a later battle wire. If STRONG feels too much fold or LIGHT still reads as a flinch, say so; do not average candidates automatically.
