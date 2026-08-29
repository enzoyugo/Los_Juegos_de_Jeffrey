# V5 Animation Compatibility Benchmark Report

## Primary Verdict

**SSK_V5_ANIMATION_COMPATIBILITY_READY_FOR_HUMAN_SELECTION**

V5 is **not** canonical. This benchmark does **not** promote V5.

Both fighters received working **Idle** and **Reaction** transfers onto the V5 native skeleton via **SEMANTIC_REAPPLICATION** (not CC_Base curve copy). Deformation gates pass at bake time. GLB roundtrip passes. Isolated Godot comparison labs load. V1 idle/reaction authorities were not overwritten.

Human must still choose:

- PROMOTE V5
- KEEP V1
- PROMOTE JAGUARETE ONLY
- PROMOTE TERERE ONLY
- NEEDS MORE WORK

Reaction V1.1 MEDIUM is a **candidate only**. It is **not frozen**. Labs label it explicitly.

---

## V1 vs V5 Skeleton Compatibility

Core body bones are **SEMANTIC_MATCH_NAME_DIFF**, not identity matches.

| | Tereré | Jaguareté |
|---|---|---|
| V1 bones | 101 (`CC_Base_*`) | 101 |
| V5 bones | 102 (`pelvis`, `upperarm_l`, …) | 118 |
| Rest / local axes | Large rest-axis deltas (hip ~97°, spine ~81°) | Same pattern |
| Direct curve reuse | **No** | **No** |

V1 bind is compensated Rx90. V5 bind is `V5_BIND_SPACE_CLEAN`. Bone lengths, parents, and local Y axes are not interchangeable.

Tereré V5 **has no ring fingers** (`ring_01/02/03` MISSING_V5). Not fatal for Idle/Reaction.

Jaguareté V5 **has ring fingers and metacarpals** (NEW_V5 helpers/twists/IK also present).

Dump: `docs/generated/V5_ANIMATION_SKELETON_COMPATIBILITY.json`

---

## Transfer Strategy

Both fighters: **B. SEMANTIC_REAPPLICATION**

- Approved semantic channels (Mixamo intra, not absolute stance)
- V5 native skeleton + V5 axis profile
- V5 character-specific canonical idle pose reconstructed from silhouette, **not** V1 quats

**A DIRECT_CURVE_REUSE** is invalid: names, rest, and local axes differ.

**C BLOCK** was not required: pelvis / spine / arm / leg semantic chains exist.

Traditional CoB was not used.

---

## Tereré V5 Canonical Pose

Target: HUMAN-APPROVED Pose B silhouette.

Angular match vs V1 approved idle (not blindly optimized):

| Metric | V1 | V5 | Dev |
|---|---|---|---|
| L upperarm from-down | 36.1° | 37.1° | 1.0° |
| R upperarm from-down | 27.1° | 26.4° | 0.8° |
| L elbow | 89.8° | 88.1° | 1.7° |
| R elbow | 82.6° | 81.4° | 1.2° |
| Spine lean (head–hip vs world up) | 3.3° | 1.8° | 1.4° |
| Hands below shoulders | yes | yes | — |
| Root X/Z | 0 | 0 | — |

Linear metrics compared as ratios to head–hip span. Shoulder-width ratio differs because V5 native proportions differ from V1.

---

## Jaguareté V5 Canonical Pose

Target: frozen approved V1 idle silhouette.

| Metric | V1 | V5 | Dev |
|---|---|---|---|
| L upperarm from-down | 38.4° | 37.9° | 0.5° |
| R upperarm from-down | 30.5° | 38.2° | 7.7° |
| L elbow | 78.6° | 76.8° | 1.8° |
| R elbow | 90.5° | 91.7° | 1.2° |
| Spine lean | 2.5° | 2.4° | 0.1° |
| Hands below shoulders | yes | **no** | human must judge |
| Rest pelvis XY | ~0 | 0.037 (bind offset) | presentation only |

Jaguareté V5 idle still shows `hands_below_shoulders=false` after safety. Compact-arm silhouette is the main human question for this fighter.

Dump: `docs/generated/V5_IDLE_POSE_MATCH_METRICS.json`

---

## Tereré Idle

Architecture: V5 Pose B equivalent + Production Semantic Idle V1 motion.

- Animation name: `idle`
- Technical pass: **true**, class `STANDING_IDLE`
- Extreme verts vs T-pose rest: 0
- Limb length error: 0
- Root X/Z: 0
- Fingers: neutral (0° from rest), no explosion
- Gray PBR expected

Outputs:

- `assets/fighters/processed/v5_animation_benchmark/terere/terere_v5_idle_benchmark.blend`
- `assets/fighters/processed/v5_animation_benchmark/terere/terere_v5_idle_benchmark.glb`

V1 production idle was **not** overwritten.

---

## Jaguareté Idle

Architecture: V5 approved-idle equivalent + frozen polished semantic idle motion.

- Animation name: `idle`
- Technical pass: **true**, class `STANDING_IDLE`
- Extreme verts vs T-pose rest: **3009** (arm travel from T-pose on this mesh; bbox volume **shrinks** ~0.81, not an explosion; limb error 0)
- Root X/Z vs rest hip: 0
- Fingers: neutral
- `hands_below_shoulders` still false — human silhouette review required

Outputs:

- `assets/fighters/processed/v5_animation_benchmark/jaguarete/jaguarete_v5_idle_benchmark.blend`
- `assets/fighters/processed/v5_animation_benchmark/jaguarete/jaguarete_v5_idle_benchmark.glb`

V1 polished idle was **not** overwritten.

---

## Tereré Reaction

Approved authority: **FROZEN_SEMANTIC_REACTION_V1** (not MEDIUM).

- Animation name: `reaction`
- Class: `HIT_REACTION`
- Peak torso vs idle center: **5.0°** (V1 freeze recorded 1.1°)
- Peak upperarm: **17.2°** (V1 freeze 12.6°)
- Max from-down: 37.4°
- Min elbow: 78.0°
- Start/end continuity: **0** on spine/arms/hands/hip
- Root X/Z: 0
- Extreme verts vs idle-center rest: 0

### Reaction V1.1 MEDIUM candidate (not frozen)

- Peak torso **13.9°**, peak arm **17.4°**
- Labeled in labs as **REACTION MEDIUM CANDIDATE**
- Do not auto-select

---

## Jaguareté Reaction

Approved authority: **FROZEN_SEMANTIC_REACTION_V1**.

- Class: `HIT_REACTION`
- Peak torso: **5.8°** (V1 freeze 1.2°)
- Peak upperarm: **1.5°** (V1 freeze 19.4°) — **arm recoil is much weaker than V1**; torso is stronger
- Start/end continuity: 0
- Root X/Z: 0
- Extreme verts vs idle-center rest: 0

### MEDIUM candidate (not frozen)

- Peak torso **14.9°**, peak arm **1.4°**
- Still little arm recoil; torso overlay is the readable part

Human question 6–10 should treat **Reaction V1** and **MEDIUM** as separate clips.

---

## Finger / Hand Differences

| | Tereré V5 | Jaguareté V5 |
|---|---|---|
| Ring finger | **absent** (recorded, not fatal) | present + metacarpals |
| Idle/Reaction finger motion | none (neutral rest) | none |
| Finger explosion | no | no |
| Wrist | keyed small semantic wrist; R `from_down` still asymmetric vs L — human judge |

Missing Tereré channels: `CC_Base_L/R_Ring1/2/3` → `ring_0*_l/r`. Idle/Reaction do not require them.

---

## Deformation

Bake-time gates (Idle vs bind T-pose; Reaction vs canonical idle pose):

| Clip | Volume max | Limb err | Extreme | Sideways | Pass |
|---|---|---|---|---|---|
| Tereré idle | 0.94 | 0 | 0 | no | yes |
| Tereré reaction V1 | 1.07 | 0 | 0 | no | yes |
| Tereré reaction MEDIUM | ~1.07 | 0 | 0 | no | yes |
| Jaguareté idle | 0.81 | 0 | 3009 vs T-pose | no | yes* |
| Jaguareté reaction V1 | 1.06 | 0 | 0 vs idle | no | yes |
| Jaguareté reaction MEDIUM | ~1.06 | 0 | 0 vs idle | no | yes |

\*Jaguareté idle extreme count is lowered-arm travel vs T-pose, not mesh explosion (volume shrinks, limb lengths stable). Human still inspects the mesh.

GLB export warns **>4 joint influences clamped to 4** (Blender 2.83). Same as V5 rest ingest.

Dump: `docs/generated/V5_ANIMATION_DEFORMATION_METRICS.json`

---

## GLB Roundtrip

Each V5 clip: export → fresh Blender import → skeleton + animation + deformation subset.

All six roundtrips: **`ok: true`**. Pelvis present. Actions survive (`idle_Armature` / reaction). No orientation-drift flag.

Dump: `docs/generated/V5_ANIMATION_ROUNDTRIP.json`

---

## Presentation Scale

Presentation only. Mesh, rest pose, bone lengths, and colliders were **not** baked to gameplay height.

| Fighter | Target height | V5 native AABB Y (Godot) | V5 presentation scale | V1 native AABB Y | V1 presentation scale |
|---|---|---|---|---|---|
| Tereré | 2.40 | 0.997 | 2.41 | 1.663 | 1.44 |
| Jaguareté | 3.15 | (lab) | target/native | (lab) | target/native |

Camera does not move when switching 1/2/3/4/8. Views: F front / G 3/4 / H side. Key 7 resets camera.

---

## Godot Comparison Labs

Standalone. Do not inherit production animation stack.

- `scenes/debug/TerereV5AnimationCompatibilityLab.tscn`
- `scenes/debug/JaguareteV5AnimationCompatibilityLab.tscn`
- Launcher: `tools/launch_v5_animation_compatibility.ps1`

Controls:

1. V1 APPROVED IDLE
2. V5 IDLE
3. V1 REACTION (frozen)
4. V5 REACTION V1
5. skeleton
6. bbox
7. camera reset
8. V5 REACTION MEDIUM CANDIDATE (not frozen)

Headless validation: `all_ok=true`  
`docs/generated/V5_ANIMATION_COMPATIBILITY_GODOT_LAB_VALIDATION.json`

Run with `--rendering-method gl_compatibility --audio-driver Dummy`.

---

## V1 vs V5 Scorecard

Numeric scores do **not** promote V5.

| Axis | V5 vs V1 | Note |
|---|---|---|
| Bind simplicity | V5 better | Native clean bind vs Rx90 compensate |
| Animation transfer complexity | V5 worse | Semantic reapplication required; no curve reuse |
| Deformation (this benchmark) | technically healthy | Jaguareté idle T-pose extreme count is a known caveat |
| Hand / finger | human | Tereré missing ring; wrists asymmetric |
| Arm chain | human | Tereré idle match tight; Jaguareté hands-below-shoulders fail |
| Leg chain | human | Knees/stance as span ratios; feet planted |
| GLB reliability | pass | Roundtrip ok; 4-influence clamp remains |
| Godot import | pass | Isolated labs load |
| Special hacks | V5 better on bind | No CoB, no Rx90 reconstruct, no curve copy |

Dump: `docs/generated/V5_ANIMATION_COMPATIBILITY_SCORECARD.json`

---

## Human Selection Required

Judge in the labs (same camera, presentation height):

**Idle**
1. Does V5 preserve the approved silhouette?
2. Are arms/hands more natural?
3. Does V5 feel less rig-like?
4. Are fingers/wrists better?
5. Are feet more stable?

**Reaction**
6. Does impact still read clearly?
7. Does torso recoil work?
8. Do arms stay anatomically clean?
9. Does recovery return naturally?
10. Does V5 look better than V1?

Keep **Reaction V1** and **MEDIUM candidate** distinct. Jaguareté V5 Reaction V1 has **weak arm recoil** vs V1; torso is the readable channel.

---

## Production Safety

Not modified:

- FighterCatalog
- battle / hitboxes / hurtboxes / gameplay
- production fighter scenes
- animation state machine
- Clean Rig V1
- Production Semantic Idle V1
- Jaguareté frozen idle
- Frozen Reaction V1 GLBs
- Reaction V1.1 assets (only read as candidate reference)

No Punch / Jump / KO / Run / Victory processing.

No commit. No push.

---

## Files Created

**Clips**

- `assets/fighters/processed/v5_animation_benchmark/terere/terere_v5_idle_benchmark.blend|.glb`
- `assets/fighters/processed/v5_animation_benchmark/terere/terere_v5_reaction_v1_benchmark.blend|.glb`
- `assets/fighters/processed/v5_animation_benchmark/terere/terere_v5_reaction_medium_candidate_benchmark.blend|.glb`
- `assets/fighters/processed/v5_animation_benchmark/jaguarete/jaguarete_v5_idle_benchmark.blend|.glb`
- `assets/fighters/processed/v5_animation_benchmark/jaguarete/jaguarete_v5_reaction_v1_benchmark.blend|.glb`
- `assets/fighters/processed/v5_animation_benchmark/jaguarete/jaguarete_v5_reaction_medium_candidate_benchmark.blend|.glb`

**Tools / labs**

- `tools/blender/v5_animation_compatibility_benchmark.py`
- `tools/launch_v5_animation_compatibility.ps1`
- `scripts/debug/v5_animation_compatibility_lab.gd`
- `scripts/debug/terere_v5_animation_compatibility_lab.gd`
- `scripts/debug/jaguarete_v5_animation_compatibility_lab.gd`
- `scripts/debug/validate_v5_animation_compatibility_labs.gd`
- `scenes/debug/TerereV5AnimationCompatibilityLab.tscn`
- `scenes/debug/JaguareteV5AnimationCompatibilityLab.tscn`
- `scenes/debug/ValidateV5AnimationCompatibilityLabs.tscn`

**Dumps / report**

- `docs/generated/V5_ANIMATION_SKELETON_COMPATIBILITY.json`
- `docs/generated/V5_IDLE_POSE_MATCH_METRICS.json`
- `docs/generated/V5_ANIMATION_DEFORMATION_METRICS.json`
- `docs/generated/V5_ANIMATION_ROUNDTRIP.json`
- `docs/generated/V5_IDLE_BENCHMARK_METRICS.json`
- `docs/generated/V5_REACTION_V1_BENCHMARK_METRICS.json`
- `docs/generated/V5_REACTION_MEDIUM_CANDIDATE_METRICS.json`
- `docs/generated/V5_ANIMATION_COMPATIBILITY_SCORECARD.json`
- `docs/generated/V5_ANIMATION_COMPATIBILITY_RUN.json`
- `docs/generated/V5_ANIMATION_COMPATIBILITY_GODOT_LAB_VALIDATION.json`
- `docs/V5_ANIMATION_COMPATIBILITY_BENCHMARK_REPORT.md`

---

## Files Modified

None of the V1 / production animation authorities, Clean Rig V1, battle, catalog, or production fighter scenes.

New isolated lab/scripts/tools only.

---

## Recommended Next Step

Play both comparison labs at presentation height:

```
tools/launch_v5_animation_compatibility.ps1 -Fighter terere
tools/launch_v5_animation_compatibility.ps1 -Fighter jaguarete
```

Decide using the ten human questions. Do not treat this report’s technical pass as promotion.

Texture/gray PBR remains a **separate** asset issue from rig/animation quality.
