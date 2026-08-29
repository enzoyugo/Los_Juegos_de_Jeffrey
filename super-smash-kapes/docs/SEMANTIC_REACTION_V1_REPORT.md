# Semantic Reaction V1

First dynamic semantic clip. Mixamo `Reaction.fbx` around approved idle centers. Not wired into battle.

## Primary Verdict

**SSK_SEMANTIC_REACTION_V1_READY_FOR_HUMAN_PLAYTEST**

Both fighters produced technically healthy `reaction` clips on Clean Rig V1:

- 101 bones, 0 extreme verts, limb length error 0
- root X/Z = 0
- start/end continuity to approved idle = 0 on torso, arms, elbows, hands, hips
- dynamic class `HIT_REACTION` (not T-pose, not sideways, not deformation-invalid)
- arms stay compact (Tereré max from-down 36.3°, Jaguareté 38.9°)
- isolated Godot labs exist with idle / loop / single-trigger

Human still has to judge whether the hit *reads*. Mixamo torso lean in this clip is small (~3.7°). The transferred envelope is mostly **head + arm + elbow + knee**, not a deep body fold.

## Approved Authorities

Frozen in `docs/generated/APPROVED_IDLE_AUTHORITIES.json`. Neither idle GLB was rebaked.

| Fighter | Authority | GLB SHA256 | Bones | Clip |
|---|---|---|---|---|
| Tereré | Production Semantic Idle V1 / Pose B — Game Ready | `9306cfad82cd9a2c0daca67f12be5a4cfc10497061d405982db4647ba47bc7f6` | 101 | `idle` |
| Jaguareté | Approved Semantic Idle V1 (polished, frozen) | `e5e4dd145cc454bab39c456a3fbe8f194f56ceab0e9deb8fbb4a87d1686943a4` | 101 | `idle` |

Post-bake hash check: both idle SHA256 values still match.

## Reaction Source Analysis

Inspected from scratch: `assets/fighters/animations/Reaction.fbx`. Dump: `docs/generated/REACTION_FBX_SEMANTIC_SOURCE_DUMP.json`.

| Field | Evidence |
|---|---|
| Armature | `Armature` |
| Namespace | `mixamorig5:` |
| Bones | 65 Mixamo bones |
| Action | `Armature\|mixamo.com\|Layer0` |
| Frames | 1–56 |
| FPS | 30 |
| Duration | 1.867 s |
| Rest pose | T-pose (from-down 90°, elbows 0°) |
| Standing (frame 1) | Compact: L/R from-down 42.2/50.3, elbows 104/99.6 |
| Strongest intra channel | **shoulder** (28.2°) |
| Head intra max | 23.8° |
| Torso lean intra max | 3.67° |
| Knee intra max | 14.3° |
| Hip horizontal travel | 0.147 m |
| Root world X | −0.096 … 0.080 m (stripped on bake) |
| Root world Y | −0.056 … 0.081 m (stripped on bake) |
| Hip Z | 0.803 … 0.855 m (small vertical compression kept) |

Rest is T-pose. Frame 1 is already a standing fight pose. Relative motion is extracted from that standing frame, not from rest, and not from Mixamo absolute matrices.

Yaw measurement wraps (~166° intra at peak). That value is envelope-clamped on bake, not copied.

## Motion Phases

Derived from source torso/hip evidence. Frames were not renamed.

| Phase | Frames | Notes |
|---|---|---|
| ANTICIPATION | 1–6 | Present. Motion still near standing. |
| IMPACT | 7–10 | Fast onset. |
| RECOIL | 10–16 | Peak frame **12** (0.367 s to peak). |
| RECOVERY | 16–56 | 1.467 s return. |

Peak Mixamo pose (frame 12): torso lean +3.66°, head +3.65° vs standing, left elbow +22°, left shoulder **−6.7°** (more down, not T-pose), hip X −0.137 m.

Classification: hit reaction with mixed/forward-biased recoil. Horizontal Mixamo hip travel is converted into hip/torso lean, not world translation.

## Semantic Architecture

```
CANONICAL CHARACTER POSE
+ SEMANTIC MOTION EXTRACTION
+ CHARACTER-SAFE CLAMPS
+ BAKE
+ GLB
+ GODOT
```

- Canonical start = approved idle ops (Tereré Pose B, Jaguareté polished idle).
- Mixamo contributes **intra deltas only**.
- No Traditional CoB. No raw Mixamo quaternions. No runtime retarget.
- Intro 3 / outro 10 frames (smoothstep) so frame 1 and frame 56 equal the approved idle center.
- Root X = 0, Root Z = 0. Vertical hip compression only, scaled by motion weight.

### Documented gains

| Channel | Tereré | Jaguareté |
|---|---|---|
| torso_pitch_gain | 0.88 | 0.95 |
| torso_yaw_gain | 0.50 | 0.55 |
| torso_roll_gain | 0.35 | 0.40 |
| head_gain | 0.72 | 0.80 |
| clavicle_gain | 0.42 | 0.48 |
| upperarm_gain | 0.38 | 0.48 |
| elbow_gain | 0.52 | 0.58 |
| wrist_gain | 0.16 | 0.18 |
| hip_gain | 0.70 | 0.78 |
| knee_gain | 0.42 | 0.48 |
| vertical_compression_gain | 0.55 | 0.60 |

Envelopes (deg): Tereré spine 12 / head 9 / upperarm 12 / elbow 10. Jaguareté slightly larger (14 / 10 / 14 / 12).

Arm safety: Tereré from-down ≤ 56°, elbow ≥ 70°. Jaguareté from-down ≤ 64°, elbow ≥ 52°.

## Tereré Reaction

Identity: short, compact, Pose B game-ready.

| Metric | Value |
|---|---|
| Peak torso vs Pose B | 1.10° |
| Peak upperarm vs Pose B | 12.59° |
| Max from-down | 36.29° (Pose B center 36.08°) |
| Min elbow | 78.7° |
| Foot XY span L/R | 0.013 / 0.0006 m |
| Root XZ | 0 |
| Extreme verts | 0 |
| Volume ratio max | 0.658 (compact vs T-pose rest, no spike) |

Arms did **not** reopen toward T-pose. Peak arm change is compact (from-down stays at Pose B). Elbows stay bent. Hands remain connected. This is a compact flinch, not a Mixamo T-pose swing.

## Jaguareté Reaction

Identity: taller, more open approved idle. Idle asset itself was not modified.

| Metric | Value |
|---|---|
| Peak torso vs approved idle | 1.20° |
| Peak upperarm vs idle | 19.42° |
| Max from-down | 38.87° (idle center 38.44°) |
| Min elbow | 77.7° |
| Foot XY span L/R | 0.030 / 0.001 m |
| Root XZ | 0 |
| Extreme verts | 0 |
| Volume ratio max | 0.933 |

Larger arm follow-through than Tereré, still below T-pose. Tail was not extra-keyed; only mapped CC semantic bones. No mesh explosion.

## Torso / Head Motion

Mixamo torso lean in this clip is small (max intra 3.67°). Character-safe Spine01 clamp (SAFE 12°) plus Pose B already sitting at ~13° world lean means additional spine primary does not produce a deep fold.

Head Mixamo intra reaches 23.8°; baker uses head_gain 0.72 with a 9° envelope, so the head snap is the clearer upper-body read.

Human question 3 (“does the torso react enough?”) is the main visual risk. Do not treat 1.1° torso as a deep body hit. If playtest wants more fold, next step is a dedicated hip-pitch conversion from Mixamo horizontal travel — not Traditional CoB.

## Arm / Hand Motion

At Mixamo peak, left arm goes **more down** (−6.7° from-down) and left elbow flexes +22°. That is impact compression, not T-pose opening.

Baked result:

- Tereré max from-down 36.3° vs Pose B 36.1°
- Jaguareté max from-down 38.9° vs idle 38.4°
- Elbows stay anatomically bent (min 78.7° / 77.7°)
- Wrist gain kept low (0.16 / 0.18) to avoid flips

Opening that exists is impact follow-through, not Mixamo rest stance.

## Lower Body / Grounding

| | Tereré | Jaguareté |
|---|---|---|
| L foot XY span | 0.013 m | 0.030 m |
| R foot XY span | 0.0006 m | 0.001 m |
| visible_foot_slide | false | false |
| hip Z variance | 0.018 m | 0.028 m |

Feet stay near-stationary. Knees take Mixamo compression at knee_gain 0.42 / 0.48, envelope 8° / 9°. No hard foot lock.

## Start Continuity

Frame 1 motion weight = 0. Measured vs canonical idle:

All of spine, L/R upperarm, L/R elbow, L/R hand, hip = **0.0** for both fighters.

IDLE → REACTION should not snap.

## End Continuity

Frame 56 motion weight = 0. Same zeros as start for both fighters.

REACTION → IDLE should not snap.

## Root Motion

Policy: visual clip, gameplay position stays elsewhere.

- Root X = 0
- Root Z = 0
- Mixamo horizontal hip (0.147 m) converted to spine/hip recoil, not world translation
- Small vertical compression only (Tereré 0.018 m, Jaguareté 0.028 m hip Z variance)

`max_root_xz` = 0.0 on both bakes and both GLB roundtrips.

## Deformation Gates

| Gate | Tereré | Jaguareté |
|---|---|---|
| extreme verts | 0 | 0 |
| limb length error | 0 | 0 |
| volume ratio | 0.658 | 0.933 |
| axis ratio | 0.888 | 0.967 |
| principal X/Y/Z | 0.58 / 1.14 / 1.01 | 0.86 / 1.06 / 1.04 |
| sideways | no | no |
| T-pose | no | no |
| Traditional CoB | not used | not used |

evaluate_action mid-frame class is still `STANDING_IDLE` because lean stays under 40° and arms stay under 70° from-down. Dynamic class `HIT_REACTION` is the production authority for this clip.

## GLB Roundtrip

Fresh Blender import of each GLB:

| | Tereré | Jaguareté |
|---|---|---|
| bones | 101 | 101 |
| ok | true | true |
| extreme verts | 0 | 0 |
| limb error | 0 | 0 |
| root XZ | 0 | 0 |

Roundtrip frame range is 0–44 because glTF resamples 1.867 s at Blender’s import FPS. Clip duration is preserved. Roundtrip is not visual authority.

Textures remain packed fighter albedos/normals (`model_Pbr_Diffuse` / `model_Pbr_Normal`).

## Godot Reaction Labs

Standalone. They do **not** extend `production_animation_lab.gd`, `semantic_solver_v2_lab.gd`, or actorcore labs. No battle, no HUD.

| Lab | Path |
|---|---|
| Tereré | `scenes/debug/TerereSemanticReactionV1Lab.tscn` |
| Jaguareté | `scenes/debug/JaguareteSemanticReactionV1Lab.tscn` |
| Shared script | `scripts/debug/semantic_reaction_v1_lab.gd` |

Tereré loads Production Semantic Idle V1 + `terere_semantic_reaction_v1.glb`.  
Jaguareté loads approved polished idle + `jaguarete_semantic_reaction_v1.glb`.

Controls:

1. APPROVED IDLE  
2. REACTION LOOP  
3. SINGLE REACTION TRIGGER  
4. skeleton  
5. bbox  
6. reset camera  

Camera is stored on ready and restored on 1/2/3/6. It does not follow the clip.

## Single Trigger Test

Key 3:

1. Hides idle, shows reaction
2. Plays `reaction` once (`LOOP_NONE`)
3. Prints `[REACTION_LAB] fighter=... state=REACTION clip=reaction time=...`
4. On `animation_finished`, returns to approved idle and prints `state=IDLE`

This is the IDLE → HIT → RECOVER → IDLE path. Loop mode (key 2) is inspection only.

## Human Validation Required

Judge both labs with the same frozen camera:

1. Does the character clearly look HIT?
2. Is impact readable quickly? (source peak at 0.367 s)
3. Does the torso react enough? **Highest risk — Mixamo torso is small.**
4. Does the head follow naturally?
5. Do arms stay anatomically convincing? (should stay compact, not T-pose)
6. Do feet remain believable?
7. Does recovery return smoothly to Idle? (measured continuity is 0)
8. Does it still feel like TERERÉ / JAGUARETÉ rather than generic Mixamo?

Do not classify Windows Editor+F6 commit exhaustion as an animation failure.

## Scalability Assessment

Reaction is the first dynamic proof after Idle. It shows the architecture can:

- keep character-specific arm logic under a larger envelope
- plant feet without Traditional CoB
- return to approved idle without snap
- survive deformation gates

It does **not** yet prove the same gains/envelopes will work for punch, jump, or death clips. Those clips stay unprocessed.

Torso amplitude is source-limited here. A later clip with real Mixamo chest fold will be a better torso test than inventing fold on Reaction.

## Production Safety

- Battle not wired
- FighterCatalog still `pipeline_id = "ACTORCORE_V4"`
- Production V4 GLBs untouched
- Clean Rig V1 files untouched
- Approved idles untouched (`do_not_rebake: true`)
- Other Mixamo clips not processed

## Files Created

- `docs/generated/APPROVED_IDLE_AUTHORITIES.json`
- `docs/generated/REACTION_FBX_SEMANTIC_SOURCE_DUMP.json`
- `docs/generated/TERERE_SEMANTIC_REACTION_V1_METRICS.json`
- `docs/generated/TERERE_SEMANTIC_REACTION_V1_ROUNDTRIP.json`
- `docs/generated/JAGUARETE_SEMANTIC_REACTION_V1_METRICS.json`
- `docs/generated/JAGUARETE_SEMANTIC_REACTION_V1_ROUNDTRIP.json`
- `docs/generated/SEMANTIC_REACTION_V1_RUN.json`
- `tools/blender/semantic_reaction_v1.py`
- `assets/fighters/processed/semantic_reaction_v1/terere/terere_semantic_reaction_v1.blend`
- `assets/fighters/processed/semantic_reaction_v1/terere/terere_semantic_reaction_v1.glb`
- `assets/fighters/processed/semantic_reaction_v1/jaguarete/jaguarete_semantic_reaction_v1.blend`
- `assets/fighters/processed/semantic_reaction_v1/jaguarete/jaguarete_semantic_reaction_v1.glb`
- `scripts/debug/semantic_reaction_v1_lab.gd`
- `scenes/debug/TerereSemanticReactionV1Lab.tscn`
- `scenes/debug/JaguareteSemanticReactionV1Lab.tscn`
- `tools/launch_semantic_reaction_v1.ps1`
- `tests/test_semantic_reaction_v1.py`
- `docs/SEMANTIC_REACTION_V1_REPORT.md`

## Files Modified

None of: Clean Rig V1, approved idles, Traditional retarget, production V4, FighterCatalog, battle, HUD, other Mixamo clips.

## Recommended Next Step

Human playtest both isolated labs (key 1 then key 3). The lab runtime flood is fixed; judge animation quality now.

From any directory:

```powershell
powershell -ExecutionPolicy Bypass -File "E:\SuperSmashKapes\super-smash-kapes\tools\launch_semantic_reaction_v1.ps1" -Fighter terere
powershell -ExecutionPolicy Bypass -File "E:\SuperSmashKapes\super-smash-kapes\tools\launch_semantic_reaction_v1.ps1" -Fighter jaguarete
```

From the project root:

```powershell
cd E:\SuperSmashKapes\super-smash-kapes
powershell -ExecutionPolicy Bypass -File ".\tools\launch_semantic_reaction_v1.ps1" -Fighter terere
```

If the hit reads and recovery is clean, keep Reaction as the first approved dynamic clip and only then consider the next Mixamo clip. If torso does not read, add a hip-pitch conversion from Mixamo horizontal travel and rebake Reaction only — still no battle wiring.

## Reaction Lab Runtime Recovery

**SSK_SEMANTIC_REACTION_V1_LAB_RUNTIME_CLEAN**

Human finding was correct: the `reaction` clip was advancing, but debug helpers flooded the log.

Root causes (lab only, not the bake):

1. `_rebuild_skeleton()` ran every `_process` frame: `queue_free()` 101 markers, then set `global_position` **before** `add_child()`. That calls `get_global_transform()` while `!is_inside_tree()`.
2. `_model_aabb()` assigned an untyped `[]` / `[node]` ternary into `Array[Node]`, which Godot 4.7 rejects.
3. `_rebuild_bbox()` rebuilt a `BoxMesh` every frame and used `global_transform` without a live-node check.

Fixes in `scripts/debug/semantic_reaction_v1_lab.gd`:

- `_live(node)` requires `is_instance_valid`, `is_inside_tree()`, and not `is_queued_for_deletion()`.
- Idle and reaction stay instantiated; switches only toggle visibility.
- Switch contract: `_begin_switch()` → stop players / flip visibility → `_reacquire_debug_targets()` → restore debug if 4/5 are on.
- Skeleton markers are created once when key 4 enables; `_process` only updates positions.
- BBox mesh is created once when key 5 enables; `_process` only updates size/position.
- AABB walk builds `Array[Node]` by `append`, skips debug meshes and dead nodes.
- Key 3 still plays reaction with debug 4/5 off.

Launcher `tools/launch_semantic_reaction_v1.ps1` now resolves `$ProjectRoot = Split-Path -Parent $PSScriptRoot`, so it works from any cwd.

60 s standalone probes (`gl_compatibility`, Dummy audio, sequence 1 / 3 / 3 / 3 / 4 / 3 / 4 / 5 / 3 / 5, then idle until quit):

| Lab | Duration | Exit | `!is_inside_tree()` | `Array[Node]` | SCRIPT ERROR | Clip advanced | Returned to idle |
|---|---|---|---|---|---|---|---|
| Tereré | 66.4 s | 0 | none | none | none | yes | yes |
| Jaguareté | 65.9 s | 0 | none | none | none | yes | yes |

Logs: `docs/generated/TERERE_REACTION_LAB_RUNTIME_PROBE.log`, `docs/generated/JAGUARETE_REACTION_LAB_RUNTIME_PROBE.log`.

Reaction motion, gains, and idle/Clean Rig/battle assets were not changed.
