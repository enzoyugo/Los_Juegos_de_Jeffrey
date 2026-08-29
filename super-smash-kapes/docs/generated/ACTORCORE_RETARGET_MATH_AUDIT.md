# ActorCore Mixamo Retarget Mathematics Audit

Date: 2026-08-22  
Authority: Blender 2.83 numeric dumps, not visual guesswork.

## What the current production formula does

`apply_rest_relative_rotation` in `tools/blender/actorcore_benchmark_lib.py`:

```
s_rest = (source_arm.matrix_world @ source_bone.matrix_local).to_3x3()
t_rest = (target_arm.matrix_world @ target_bone.matrix_local).to_3x3()
world_rot = s_rest @ src_basis @ s_rest.inverted()
t_basis  = t_rest.inverted() @ world_rot @ t_rest
```

This is a change-of-basis of Mixamo **local** `matrix_basis` into ActorCore local axes.

It is **not** `target_pose = source_rotation` in object/world space.

It **is** intended to be:

```
target_pose = target_rest_basis_change(source_delta_from_source_rest)
```

The implementation matches that formula: `expected_vs_applied_angle_deg` is 0.0 for sampled bones (`TERERE_DEFORMATION_STAGE_CHAIN.json`). The code does what it says.

## Why that formula still explodes the mesh

The formula assumes Mixamo `matrix_basis` at the animated frame is a **small idle-scale delta** from Mixamo rest.

Idle.fbx is not that:

| Evidence | Value |
| --- | --- |
| Mixamo rest | T-pose |
| Mixamo Idle frame 1 Hips `matrix_basis` | ~49–52° plus location `(-3.3, -17.6, 0.9)` (cm-scale) |
| Mixamo Idle frame 1 LeftArm | ~61–66° |
| Max mapped bone at frame 1 | ~83–100° |
| Mixamo vs AccuRIG rest-axis mismatch | hip ~92°, mean mapped ~59° (`MIXAMO_ACTORCORE_REST_BASIS_AUDIT.json`) |

Copying a 50–100° T-pose→stand rotation through a ~90° rest-axis mismatch drives AccuRIG limbs the wrong way. Skinned AABB volume grows ~10×:

| Stage | Rest volume | Animated volume | Volume ratio |
| --- | --- | --- | --- |
| Source ActorCore FBX rest | ~2.39e6 | ~2.39e6 | 1.00 |
| After rest-relative bake (C) | ~2.39e6 | ~2.4e7 | ~10 |
| Production v3 GLB reimport (E/F) | ~2.39e6 | 2.499e7 | 10.47 |

Idle that actually stands should **narrow** (arms down). Observed idle **widens** (190 → 307). That is catastrophic deformation, not animation.

Constraint Copy Rotation (LOCAL/WORLD/POSE, with/without offset, invert-axis brute) never dropped volume_ratio below **2.29**. Still exploded.

## What is NOT the root cause

- Vertex groups: 0 unweighted, weight sums ≈ 1.0
- Missing armature modifier
- Godot import inventing tracks (GLB already exploded in Blender reimport)
- Intra-clip idle sway (5–25° around exploded frame 1) — audits that measure delta-from-first-frame hid the T→stand jump
- Armature object scale 0.01 (present at healthy rest too)
- >4 skin influences (15% verts; glTF clamp is secondary, not 10× volume)

## Repair chosen for production V4

Do **not** copy Mixamo rest-relative T→stand.

Copy **clip-relative** deltas versus Mixamo frame 1:

```
delta = Q_frame1.inverted() @ Q_frame
AccuRIG.rotation_quaternion = delta
location = (0, (src.y - ref_y) * HIP_Y_SCALE, 0)  # hip only
scale = (1,1,1)
```

Frame 1 of AccuRIG stays on the bind/T-pose. Later frames receive Mixamo intra-clip motion (idle-scale).

Honest limitation: idle reads as **T-pose + breathing**, not Mixamo standing. That is safer than an exploded standing pose. Human visual approval is still required.

`rest_relative` remains in the retargeter as an explicit opt-in that **must fail** the bbox gate (`volume_ratio > 1.35`).

## First broken pipeline stage

Corrected classifier uses volume, not `max(size)` as height.

| Character | A source rest | B source pose | C bake | D clean scene | E GLB | F Blender reimport | G Godot | H runtime |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Tereré | HEALTHY | HEALTHY | **BROKEN** | BROKEN (inherits C) | BROKEN | BROKEN | BROKEN (plays C) | BROKEN |
| Jaguareté | same shared retarget | same | **BROKEN** (same math) | BROKEN | BROKEN | BROKEN | BROKEN | BROKEN |

`FIRST_BROKEN_STAGE_TERERE = C_after_retarget`  
`FIRST_BROKEN_STAGE_JAGUARETE = C_after_retarget` (shared Mixamo→ActorCore math; Jaguareté bind/skin forensics generated separately)
