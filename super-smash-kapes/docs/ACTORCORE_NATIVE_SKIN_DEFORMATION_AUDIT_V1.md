# ActorCore Native Skin Deformation Audit V1

## Primary Verdict

**SSK_ACTORCORE_NATIVE_SKIN_HEALTHY_RETARGET_STILL_BLOCKED**

Phase 4 branch: **NATIVE_SKIN_HEALTHY_RETARGET_BROKEN**

Decision-tree **CASE 3**: native AccuRIG source skin and the 4-influence processed copy both articulate without 5×–10× mesh growth. A Mixamo-free standing pose is structurally acceptable. The 7–11× Idle explosion remains in the Mixamo→ActorCore retarget/bind conversion path.

## Why This Test Was Necessary

Rest-axis solver V1 implemented true Mixamo-rest mathematics and several alternative formulations. Bone lengths stayed invariant. Every standing-pose retarget still inflated the skinned mesh ~7–11×. Frame-1-relative V4 stayed safe only by remaining near AccuRIG bind. That pattern implied the failure might sit **below** retarget: native skin, 4-influence clamp, helpers, or glTF inverse bind.

This audit posed each fighter’s **own** AccuRIG armature and skin. No Mixamo. No retarget. No constraints. No copied animation.

## Tereré Native Articulation

Source: `assets/fighters/source_rigged/terere/actorcore/autorig_actor.fbx` (50 382 vertices, max 6 influences, 7 583 verts with >4 influences).

Upperarm local Z, sign −1 (lowers the arm). 60° volume_ratio **0.814** (mesh shrinks as the arm leaves T-pose). 75° **1.023**. Zero NaNs, zero extreme vertices.

Manual standing (arms ~62°, slight elbow/knee): volume_ratio **0.864**, max_axis_ratio **0.94**, class **HEALTHY**.

## Jaguareté Native Articulation

Source: `assets/fighters/source_rigged/jaguarete/actorcore/autorig_actor.fbx` (47 292 vertices, max 6 influences, 10 797 verts with >4 influences).

Upperarm 60° volume_ratio **0.792**, class **HEALTHY**. Right forearm 90° on the anatomically chosen local X: **0.747**, **HEALTHY**.

Manual standing: volume_ratio **1.728**, max_axis_ratio **1.06**, 0 extreme vertices, class **STRESSED** on a pose-dependent bbox gate — not a 7–11× vertex explosion.

## Controlled Rotation Results

CSV: `docs/generated/TERERE_NATIVE_SKIN_DEFORMATION.csv`, `docs/generated/JAGUARETE_NATIVE_SKIN_DEFORMATION.csv`.

| Pose | Tereré original | Jaguareté original |
| --- | --- | --- |
| L upperarm 0–75° | HEALTHY (0.76–1.02) | HEALTHY (arm 60° = 0.79) |
| L forearm 90° | HEALTHY 0.79 | HEALTHY |
| R forearm 90° | bbox 2.94 **BROKEN label**, 0 extreme verts | HEALTHY 0.75 (better axis pick) |
| Thigh 60° | HEALTHY | STRESSED 1.56 (bbox, 0 extreme) |
| Knee 90° | HEALTHY | HEALTHY |
| Head 30° | STRESSED 2.26 (bbox nod) | STRESSED 2.21 (bbox nod) |
| Standing combo | **HEALTHY 0.864** | STRESSED 1.73 / axis 1.06 |

Tereré’s only `BROKEN` row is right elbow 90° around local Z (axis picker disagreed with the left arm’s local X). Bbox grew because the forearm swung the wrong way. **extreme_vertex_count = 0**. That is not AccuRIG skin disintegration.

No pose reached 5× volume. Solver V1’s 7–11× class of failure did **not** appear in native articulation.

## Original vs 4-Influence Skin

Tereré 7 583 verts had >4 weights; after clamp, 0. Jaguareté 10 797 → 0.

For every controlled pose, original and 4-influence volume_ratio / axis / displacements match to reporting precision (tiny float noise only at 60°+). **The game 4-weight clamp is not the 7–11× root cause.**

## Extreme Vertex Analysis

Standing: 0 extreme vertices on both fighters.

The only forensic keys were Tereré `R_Forearm|90` variants. The dump lists **no vertices** above the extreme displacement cutoff. Failure mode there is bbox occupancy, not flown-off skin points.

No evidence of cross-limb weights detonating a native 60° arm pose.

## Twist / Helper Bone Analysis

~23k Tereré / ~27k Jaguareté vertices carry Twist, Share, Facial, or Breast influences.

A Twist→parent collapse pass recorded 0 remapped groups on the experimental copies (no Twist-named vertex groups to merge, or names did not match `*Twist*`). The `twist_collapsed` mesh still tracked original metrics 1:1.

Helpers are present in the source skin. They do **not** prevent a healthy native 60° upperarm or Tereré standing pose. They are therefore not a sufficient explanation for Mixamo rest-relative explosion.

## Armature Modifier Audit

Both fighters:

- Armature modifier target = `Armature`
- `use_deform_preserve_volume` = false
- Armature Rx = 90°, scale = 0.01 (FBX)
- Mesh parented to armature, mesh Rx = −90°, mesh scale = 1

Applying rotation+scale on a **copy** then repeating upperarm 60° kept volume_ratio ≈ 0.81 (Tereré) / 0.79 (Jaguareté). Object transform apply does not recreate the 7–11× failure. Source files were not modified.

Blender 2.83 does not expose numeric inverse-bind IDs on `Mesh`; skinning is vertex groups + armature modifier.

## Manual Standing Pose

Mixamo-free, ActorCore bones only:

- upperarms ~62° on the lowering axis
- elbows ~28°
- calves ~18°
- torso/head identity

Exports:

- `assets/fighters/processed/native_skin_audit/terere/terere_native_standing_test.glb`
- `assets/fighters/processed/native_skin_audit/jaguarete/jaguarete_native_standing_test.glb`

Tereré standing volume_ratio **0.864** (HEALTHY). Jaguareté **1.728** (STRESSED bbox only).

## GLB Roundtrip

Reimported standing GLBs: 101 bones. Evaluated frame 1 vs frame 10 bbox ratio **1.0** (animation did not produce a second evaluated pose in this roundtrip, and source-unit comparison is not meaningful after glTF meter conversion). Reimport did **not** explode to 7–11×. glTF bind is not identified as the Idle explosion stage.

## Earliest Failing Stage

**C — Mixamo → ActorCore retarget / rest-axis conversion**, not:

- native AccuRIG skin
- 4-influence export clamp
- FBX object scale (apply-copy stayed healthy)
- glTF reimport of a native standing clip

## Root Cause

AccuRIG source skin **can** take ordinary native rotations and a constructed standing pose. The rest-axis solver still fails because it injects Mixamo T-pose→stand deltas (and/or world Copy Rotation of Mixamo posed bones) into AccuRIG local/world spaces that are not the same pose the native skin was bound for.

Native 60° upperarm is safe. Mixamo’s ~61° LeftArm `matrix_basis` copied or conjugated onto AccuRIG is not the same 60° native rotation — that was the solver V1 mistake.

## Recommended Repair

1. Keep production V4 in battle.
2. Do not retarget more Mixamo clips with rest-relative or world-copy solvers until the Mixamo local delta is expressed as **AccuRIG-native axis angles** (the axes measured in this audit: upperarm local Z with opposite signs L/R).
3. Validate any new bake against this native standing reference (Tereré 0.86 volume, 0 extreme verts), not against Mixamo frame 1.
4. Optional: rebuild Idle by driving AccuRIG bones with the native lowering/flexion axes instead of Mixamo matrices.

## Automated Tests

Existing suite preserved. Added `tests/test_native_skin_deformation_audit.py` for evidence files, no-Mixamo primary path, CSV variants, allowed verdict, off-catalog outputs, V4 SHA256.

Tests do not claim a human-approved Idle.

## Human Validation Files

Open in Blender 2.83 (LABEL empties mark each pose along X):

- `assets/fighters/processed/native_skin_audit/terere/terere_native_skin_audit.blend`
- `assets/fighters/processed/native_skin_audit/jaguarete/jaguarete_native_skin_audit.blend`

Poses: REST, upperarm 30/60, elbow 90, thigh 45, knee 90, standing.

## Production Safety

Catalog and ActorCore V4 visuals still point at `*_game_ready_v4.glb`. SHA256 unchanged:

- Tereré `D880B8E9FE03F8F0169728259A0C51F0A931AED401B4AA30A32BCED94EA0CEBE`
- Jaguareté `460BEE0AF4CF0CE3F9550948E3E69D349A9E3C1D1EFADE786178C8E5D639553C`

Gameplay, UI, Victory, and canonical sizes were not modified.

## Files Created

- `tools/blender/native_skin_deformation_audit.py`
- `docs/generated/TERERE_NATIVE_SKIN_DEFORMATION.csv`
- `docs/generated/JAGUARETE_NATIVE_SKIN_DEFORMATION.csv`
- `docs/generated/TERERE_NATIVE_SKIN_AUDIT.json`
- `docs/generated/JAGUARETE_NATIVE_SKIN_AUDIT.json`
- `docs/generated/NATIVE_SKIN_AUDIT_SUMMARY.json`
- `assets/fighters/processed/native_skin_audit/terere/terere_native_skin_audit.blend`
- `assets/fighters/processed/native_skin_audit/jaguarete/jaguarete_native_skin_audit.blend`
- `assets/fighters/processed/native_skin_audit/terere/terere_native_standing_test.glb`
- `assets/fighters/processed/native_skin_audit/jaguarete/jaguarete_native_standing_test.glb`
- `tests/test_native_skin_deformation_audit.py`
- `docs/ACTORCORE_NATIVE_SKIN_DEFORMATION_AUDIT_V1.md`

## Files Modified

None of production V4, catalog, gameplay, UI, or Victory.
