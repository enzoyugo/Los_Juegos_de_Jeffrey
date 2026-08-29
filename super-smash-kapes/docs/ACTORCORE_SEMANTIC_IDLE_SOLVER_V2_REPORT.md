# ActorCore Semantic Idle Solver V2 Report

## Primary Verdict

**SSK_ACTORCORE_SEMANTIC_IDLE_SOLVER_V2_READY_FOR_HUMAN_PLAYTEST**

Arm-chain follow-up: `docs/ACTORCORE_SEMANTIC_V2_ARM_CHAIN_REPORT.md`. Canonical standing was previously keyed as T-pose because a new empty action reset the pose before keying. After the fix, bake-time arms-from-down is Tereré **17.2°** / Jaguareté **27.4°**, volume **0.577 / 0.822**. Production V4 is still not swapped.

Both fighters use one generic `CC_Base` solver. Mixamo quaternions are never copied onto AccuRIG. Idle is reconstructed as **canonical native standing + Mixamo intra-idle semantic deltas**. Automated gates pass:

| Gate | Tereré | Jaguareté |
| --- | --- | --- |
| `pose_classification` | `STANDING_IDLE` | `STANDING_IDLE` |
| max `volume_ratio` | 0.577 | 0.822 |
| volume limit 1.35 | PASS | PASS |
| max axis ratio | 0.883 | 0.936 |
| extreme vertices | 0 | 0 |
| limb length error | 0.0 | 0.0 |
| arms from down (standing) | 17.2° | 27.4° |
| textures | AccuRIG Tereré `29aedd817e4fbf69` | AccuRIG Jaguareté `654179021409871a` |
| production V4 SHA256 | unchanged | unchanged |

Battle, UI, Victory, and production V4 are untouched. This is **not** a production swap. Human playtest in the isolated labs is still required before considering V4 replacement.

## Why Matrix Retarget Was Abandoned

Rest-axis solver V1 copied Mixamo rest-relative `matrix_basis` (or an equivalent `C_bone` conjugation) onto AccuRIG. Mixamo Idle **frame 1 is already standing** (~61° LeftArm basis). AccuRIG bind is T-pose with different rest axes. That transfer exploded AABB volume **7–11×** with invariant bone lengths.

The native-skin audit then proved AccuRIG skin is healthy: native 60° upperarm **shrinks** the mesh (Tereré 0.81, Jaguareté 0.79). The remaining broken layer was Mixamo matrix/quat copy, not weights, glTF bind, or 4-influence clamp.

V2 therefore never assigns Mixamo `rotation_quaternion` / `matrix_basis` onto ActorCore bones.

## Native Axis Profile

Dump: `docs/generated/ACTORCORE_NATIVE_AXIS_PROFILE.json`

Derived on Tereré AccuRIG by controlled native articulation (not bone-name guessing). Shared for both fighters.

| Bone | Primary axis | Sign | Kind |
| --- | --- | --- | --- |
| Hip | LOCAL_X | −1 | flex_spine |
| Spine01 / Spine02 | LOCAL_X | +1 | flex_spine |
| NeckTwist01 | LOCAL_X | −1 | nod_head |
| Head | LOCAL_X | +1 | nod_head |
| L Clavicle / L Upperarm | LOCAL_Z | −1 | lower_arm |
| R Clavicle / R Upperarm | LOCAL_Z | +1 | lower_arm |
| L/R Forearm | LOCAL_X | −1 | bend_elbow |
| L Hand | LOCAL_X | −1 | bend_elbow |
| R Hand | LOCAL_Z | +1 | bend_elbow |
| L/R Thigh, Calf, Foot | LOCAL_X | +1 | hip / knee |

Twist axis is LOCAL_Y on all profiled bones. Twist/helper bones are **not** keyed. Elbow axis pick is volume-aware so R_Forearm stays LOCAL_X (the native-audit LOCAL_Z pick on Tereré R_Forearm was a bad 90° bbox outlier).

## Mixamo Semantic Extraction

Source: `assets/fighters/animations/Idle.fbx`  
Dump: `docs/generated/MIXAMO_IDLE_SEMANTIC_CHANNELS.json`

Per frame the solver stores **world anatomical channels vs Mixamo edit rest** and **intra-idle deltas vs Mixamo standing (frame 1)**. No quaternions, no matrices.

Mixamo rest vs standing (world angles):

- Shoulder from-down: 90° / 90° rest → 45.3° / 36.8° standing (arms already lowered at clip start)
- Elbow flexion: 0° rest → 80.6° / 100.4° standing
- Knee flexion: ~3° rest → ~50° standing

Reconstruction **does not** apply rest→stand as AccuRIG pose. Only `intra_idle_delta_from_standing` is used, with:

- shoulder from-down inverted into AccuRIG lowering (higher Mixamo from-down = less AccuRIG lowering)
- channel gain 0.45
- per-channel clamps (shoulders ±5°, elbows ±3.5°, knees ±2°, torso ±2°, head ±3°)

## Canonical Standing Pose

Dump: `docs/generated/ACTORCORE_CANONICAL_STANDING_POSE.json`

Authored on AccuRIG native axes, not Mixamo bind:

- L/R Upperarm **60°** lowering
- L/R Forearm **10°** flexion
- knees not pre-bent (Jaguareté native 18° calf expanded AABB to 1.73 with 0 extreme verts)

Tereré standing quality: arms **28.6° from down**, elbows **10.7°**, `arms_lowered_from_tpose = true`.

Idle animates **around this standing pose**, never around T-pose.

## Idle Reconstruction

```
ActorCoreCanonicalStanding
  + Mixamo intra-idle semantic deltas (clamped, shoulder-inverted)
  → AccuRIG native-axis rotations on deform bones only
```

Hip X/Z stay 0. Hip Y uses Mixamo intra-idle `hip_y * 0.001`. Same angles for Tereré and Jaguareté.

Experimental clips only: `rest`, `canonical_standing`, `idle`.

## Tereré Metrics

From `docs/generated/TERERE_IDLE_SEMANTIC_V2_METRICS.json`

- max volume_ratio **0.603** (limit 1.35)
- max axis_ratio **0.883**
- standing-only volume **0.587**, class `STANDING_IDLE`
- mid-frame arms 29.5° from down, elbows ~10–11°
- 0 extreme vertices, limb lengths invariant, root XZ 0
- diffuse SHA16 `29aedd817e4fbf69`

## Jaguareté Metrics

From `docs/generated/JAGUARETE_IDLE_SEMANTIC_V2_METRICS.json`

- max volume_ratio **1.076** (limit 1.35)
- max axis_ratio **0.936**
- standing-only volume **1.038**, class `STANDING_IDLE`
- mid-frame arms 23.0° from down, elbows ~13–14°
- 0 extreme vertices, limb lengths invariant, root XZ 0
- diffuse SHA16 `654179021409871a`

First bake with 22° standing elbows failed this mesh’s AABB gate (max 1.688, same bbox-only pattern as the native standing audit). Reducing standing elbows to 10° and clamping Idle deltas brought volume under 1.35 **without character-specific bone rotations**.

## Channel Isolation Results

From `docs/generated/SEMANTIC_V2_CHANNEL_ISOLATION.json` (mid Idle, standing + that group only):

| Group | Tereré vol / class | Jaguareté vol / class |
| --- | --- | --- |
| A arms | 0.580 / STANDING_IDLE | 0.997 / STANDING_IDLE |
| B torso/head | 0.589 / STANDING_IDLE | 1.051 / STANDING_IDLE |
| C legs | 0.590 / STANDING_IDLE | 1.046 / STANDING_IDLE |
| D combined | 0.584 / STANDING_IDLE | 1.017 / STANDING_IDLE |

No isolated channel is the deformation source. Jaguareté AABB is mesh-extent sensitive (rest local Y is the thin axis); it is not a 7–11× vertex explosion.

## Deformation Gates

Hard fails did **not** trigger on either fighter:

- `volume_ratio > 1.35` — no (0.603 / 1.076)
- principal axis expansion grossly abnormal — no (both < 1.0 vs rest)
- extreme vertices — 0
- limb length change — 0.0

Pose class is `STANDING_IDLE` (arms well below the 70° T-pose threshold). Not `T_POSE_LIKE`. Not `DEFORMATION_INVALID`.

## Blender Preview

Open and press Space (Idle is the active action):

- `assets/fighters/processed/semantic_solver_v2/terere/terere_idle_semantic_v2_preview.blend`
- `assets/fighters/processed/semantic_solver_v2/jaguarete/jaguarete_idle_semantic_v2_preview.blend`

NLA tracks: `rest`, `canonical_standing`, `idle`. Viewport empties `_SWITCH_1_REST`, `_SWITCH_2_CANONICAL_STANDING`, `_SWITCH_3_IDLE`.

## Godot Lab

Isolated scenes (not in battle):

- `scenes/debug/TerereSemanticSolverV2Lab.tscn`
- `scenes/debug/JaguareteSemanticSolverV2Lab.tscn`

Controls: **1 REST · 2 CANONICAL STANDING · 3 IDLE · 4 SKELETON · 5 BBOX**

Overlay: solver version, volume ratio, pose classification, bone count, idle source (`Idle.fbx`), root XZ.

Headless load: `SEMANTIC_SOLVER_V2_GODOT_LAB=PASS`  
`docs/generated/SEMANTIC_SOLVER_V2_GODOT_LAB_VALIDATION.txt`

Both GLBs: 101 bones, clips `rest` / `canonical_standing` / `idle`, 10 Idle rotation tracks.

## Production Safety

- Catalog and fighter visuals still point at `*_game_ready_v4.glb`
- V4 SHA256 unchanged:
  - Tereré `D880B8E9FE03F8F0169728259A0C51F0A931AED401B4AA30A32BCED94EA0CEBE`
  - Jaguareté `460BEE0AF4CF0CE3F9550948E3E69D349A9E3C1D1EFADE786178C8E5D639553C`
- No gameplay / UI / Victory edits
- Solver has no `if character == "terere"` bone hacks

## Automated Tests

`pytest tests -q` → **132 passed** (prior suite preserved; `tests/test_semantic_idle_solver_v2.py` added).

Coverage includes: native-axis profile, canonical standing, Mixamo semantic channels, no Mixamo quat copy, production V4 unchanged, both GLBs, character textures, volume gate consistency, pose class, limb invariance, zero extreme verts, channel isolation, generic CC_Base solver, isolated labs.

## Human Validation Required

Confirm in Blender (Space) and Godot labs (keys 1/2/3) that Idle **reads as a relaxed standing fighter**:

1. Arms clearly lowered vs T-pose (automated: ~23–30° from down)
2. Slight elbow bend visible (authored 10°; Mixamo’s 80–100° elbow is **not** transferred as a rest offset)
3. Knees not locked or sitting
4. Torso/head upright and readable
5. Idle sway is subtle by design (gain 0.45). If it looks too still, raise gain after another volume pass — do not copy Mixamo matrices
6. Textures stay character-specific
7. No candy-wrapper / exploding mesh

Do not replace production V4 until that playtest is accepted.

## Files Created

- `tools/blender/semantic_idle_solver_v2.py`
- `docs/generated/ACTORCORE_NATIVE_AXIS_PROFILE.json`
- `docs/generated/MIXAMO_IDLE_SEMANTIC_CHANNELS.json`
- `docs/generated/ACTORCORE_CANONICAL_STANDING_POSE.json`
- `docs/generated/SEMANTIC_V2_CHANNEL_ISOLATION.json`
- `docs/generated/TERERE_IDLE_SEMANTIC_V2_METRICS.json`
- `docs/generated/JAGUARETE_IDLE_SEMANTIC_V2_METRICS.json`
- `docs/generated/SEMANTIC_SOLVER_V2_GODOT_LAB_VALIDATION.txt`
- `docs/ACTORCORE_SEMANTIC_IDLE_SOLVER_V2_REPORT.md`
- `assets/fighters/processed/semantic_solver_v2/terere/terere_idle_semantic_v2.glb`
- `assets/fighters/processed/semantic_solver_v2/terere/terere_idle_semantic_v2_preview.blend`
- `assets/fighters/processed/semantic_solver_v2/jaguarete/jaguarete_idle_semantic_v2.glb`
- `assets/fighters/processed/semantic_solver_v2/jaguarete/jaguarete_idle_semantic_v2_preview.blend`
- `scripts/debug/semantic_solver_v2_lab.gd`
- `scripts/debug/terere_semantic_solver_v2_lab.gd`
- `scripts/debug/jaguarete_semantic_solver_v2_lab.gd`
- `scripts/debug/validate_semantic_solver_v2.gd`
- `scenes/debug/TerereSemanticSolverV2Lab.tscn`
- `scenes/debug/JaguareteSemanticSolverV2Lab.tscn`
- `tests/test_semantic_idle_solver_v2.py`

## Files Modified

None of production battle, UI, Victory, catalog, fighter visuals, or V4 GLBs. V2 lives entirely on experimental paths.

## Recommended Next Step

Human playtest Idle only in the V2 labs / Blender previews. If the standing read is accepted, the same architecture (native standing + Mixamo intra-clip semantics) can be applied to the next clip. Do not wire into production battle yet.
