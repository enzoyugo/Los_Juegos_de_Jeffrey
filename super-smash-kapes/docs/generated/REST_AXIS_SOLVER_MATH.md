# Rest-Axis Solver Math (Idle)

This document is the authority for Mixamo → ActorCore `CC_Base` Idle retarget
in `tools/blender/rest_axis_solver_v1.py`. It does **not** use animation
frame 1 as bind pose.

## Spaces

Blender distinguishes:

| Quantity | Meaning |
| --- | --- |
| `bone.matrix_local` | Rest pose of the bone in armature space (edit/bind). |
| Parent-relative rest `R` | `parent.matrix_local^-1 * bone.matrix_local` (root: `matrix_local`). |
| `pose.bone.matrix_basis` | Rest-relative transform in parent space. Identity = rest. |
| `pose.bone.matrix` | Animated armature-space matrix. |
| World rest | `armature.matrix_world * bone.matrix_local` |

True Mixamo rest is taken from `Idle.fbx` after disconnecting the action and
clearing pose. ActorCore rest is taken from `autorig_actor.fbx` the same way.
Frame 1 of Idle is already a standing pose on Mixamo; it is **animation**, not
bind.

## Per-bone change of basis `C_bone`

Mixamo and AccuRIG `CC_Base` bones do not share local axes or roll. A rotation
expressed in Mixamo local coordinates must be rewritten in ActorCore local
coordinates before it is applied.

Let `S` be the 3×3 of Mixamo world rest (columns = Mixamo local XYZ in world).
Let `T` be the 3×3 of ActorCore world rest.

```
C_bone = T^-1 * S
```

Then a Mixamo-local vector `v_src` maps to ActorCore-local `v_tgt = C_bone * v_src`.
A Mixamo-local rotation `R_src` converts by conjugation:

```
R_tgt = C_bone * R_src * C_bone^-1
```

`C_bone` is computed once from rest authorities, never from frame 1.
FBX object scale (Mixamo and AccuRIG both import at 0.01) is **stripped**
via `matrix.decompose()` so `C` is a pure rotation.

Canonical values: `docs/generated/SOLVER_V1_C_BONES.json`.

This is **not** copying raw Euler or raw quaternion components.

## Source local delta (true rest)

```
M_src_rest_local = parent_relative_rest(Mixamo bone)
M_src_anim_local = parent.matrix^-1 * pose.matrix     (root: pose.matrix)

M_delta_src = inverse(M_src_rest_local) * M_src_anim_local
```

In Blender, `M_delta_src` equals `pose.bone.matrix_basis` when the bind pose is
the true rest (which it is after pose-clear). Frame 1's `matrix_basis` is a
large T-pose→stand offset and is **not** used as rest.

## User conjugation (method `parent_relative_cob`)

```
M_delta_target = C_bone * M_delta_src * inverse(C_bone)
M_target_anim_basis = M_delta_target
```

Because `matrix_basis` is already rest-relative:

```
M_target_anim = M_target_rest_local * M_delta_target
```

This is the requested local equation. Overnight V3 used the same conjugation
with world-rest `C` on Mixamo Idle's large rest-relative angles and exploded
the skinned mesh (~10× volume). The solver **probes** this method first.

## World-delta apply (method `world_delta_hierarchy`)

If conjugation fails volume / limb / T-pose gates, the same generic solver
applies the world rotation each Mixamo bone underwent onto ActorCore rest,
then converts the desired armature matrix into `matrix_basis` **parents first**
so parent motion is not double-counted:

```
M_src_rest_world = armature_world * bone.matrix_local
M_src_anim_world = armature_world * pose.matrix

world_delta = M_src_anim_world * inverse(M_src_rest_world)     # rotation only

M_target_world = world_delta * M_target_rest_world
```

Conversion to parent-relative basis:

```
rest_pr = parent.bone.matrix_local^-1 * bone.matrix_local
matrix_basis = rest_pr^-1 * parent.pose.matrix^-1 * desired_armature_matrix
```

Selected method is written to `docs/generated/SOLVER_V1_SELECTED_METHOD.json`
and reused for both Tereré and Jaguareté. No per-fighter rotation hacks.

## Bone-Y aim (method `bone_y_aim`)

If conjugation and world-delta still fail deformation gates, the solver aims
each ActorCore bone **Y** at the Mixamo posed bone **Y** in world space, then
copies Mixamo twist around that Y. This matches Idle silhouette without
pushing a ~90° hip rest-axis mismatch through the full 3-axis delta.

```
swing = rest_Y_tgt.rotation_difference(anim_Y_src)
aimed = swing * rest_q_tgt
twist = project_onto_Y( anim_q_src * inverse(swing_src * rest_q_src) )
desired_q = twist * aimed
```

Parents are converted to `matrix_basis` first so child world aims are not
double-counted.

## Root / hip policy (Idle)

- Root / hip translation X = 0, Z = 0 (no world locomotion).
- Hip Y = `(src.location.y - src_rest.location.y) * 0.001`.
- Rest hip location is measured on the cleared Mixamo pose, not frame 1.

## Why clip-relative (frame 1) failed

```
delta = Mixamo(frame1)^-1 * Mixamo(frame)
ActorCore.basis = delta
```

Idle frame 1 is already standing, so `delta` is a small sway. AccuRIG bind is
T-pose, so the bake is T-pose + sway. It is structurally safe (volume ≈ 1.0)
and visually rejected.

## T-pose detector

Upper-arm bone Y versus torso-down (head − hip, negated):

- mean angle ≥ 70° → `T_POSE_LIKE` (arms near horizontal)
- volume_ratio > 1.35 or limb-length error > 4% → `DEFORMATION_INVALID`
- otherwise → `STANDING_IDLE`

Limb lengths compared at rest vs posed: upper arm, forearm, thigh, calf (L/R).

## Probe results (Tereré Idle, true Mixamo rest)

Mixamo LeftArm `matrix_basis` at Idle frame 1 / 55 is **61.5° / 66.6°** — the
clip is standing relative to Mixamo T-pose rest. Frame 1 is not rest.

| Method | volume_ratio | mean upperarm from down | class |
| --- | --- | --- | --- |
| `parent_relative_cob` (requested equation) | 10.82 | 108.9° | DEFORMATION_INVALID |
| `world_delta_hierarchy` | 10.82 | 108.9° | DEFORMATION_INVALID |
| `raw_low_c` (copy Mixamo basis on C<40° bones only) | 8.81 | 113.5° | DEFORMATION_INVALID |
| `bone_y_aim` (all mapped bones) | 7.22 | 47.5° | DEFORMATION_INVALID |
| `arm_y_aim_only` | 6.93 | 97.7° | DEFORMATION_INVALID |
| `constraint_world_arms` (Blender Copy Rotation WORLD on upperarm+forearm) | 7.71 | 97.7° | DEFORMATION_INVALID |

Hip/thigh `C_angle` ≈ 93°. Arm `C_angle` ≈ 5–7°. Limb lengths stayed invariant
(rotation-only). Skinned volume still exploded, including when hip/spine stayed
at ActorCore rest. Copying Mixamo's standing arm into AccuRIG is not a safe
skin pose on this bind.

Jaguareté with the same generic method: volume_ratio **9.53**, same classification.
