# ActorCore Rest-Axis Solver V1 Report

## Primary Verdict

**SSK_ACTORCORE_REST_AXIS_SOLVER_V1_BLOCKED**

The solver infrastructure is in place (true rest dumps, per-bone `C_bone`, Idle-only experimental GLBs, gates, Blender previews, isolated Godot labs, tests). It does **not** produce a playable standing Idle on AccuRIG.

Both fighters fail the deformation gate (`volume_ratio` 8.06 Tereré / 9.53 Jaguareté, limit 1.35) and classify as `DEFORMATION_INVALID`. Production V4 is untouched. Battle is not wired.

READY_FOR_HUMAN_IDLE_PLAYTEST requires `STANDING_IDLE` and `volume_ratio <= 1.35` on both fighters. That bar is not met.

## Root Cause Recap

Mixamo `Idle.fbx` bind/edit rest is T-pose. Idle **frame 1 is already standing** (LeftArm `matrix_basis` ≈ 61.5°). AccuRIG `CC_Base` bind is T-pose with a different rest axis set (hip `C_angle` ≈ 93.9°, upperarm ≈ 5–7°).

Any bake that uses Mixamo's **true rest-relative** T-pose→stand offset as AccuRIG pose inflates the skinned mesh ~7–11×. Bone lengths stay invariant (pure rotation). V4 avoided that by using **clip-relative** deltas from frame 1, which are near identity on AccuRIG bind — structurally safe, visually T-pose + sway.

## Why Frame-1 Relative Failed

```
delta = Mixamo(frame1)^-1 * Mixamo(frame)
AccuRIG.basis = delta
```

Frame 1 is standing, so `delta` is Idle sway only. AccuRIG never leaves T-pose. Humans rejected it. Using frame 1 as rest is mathematically the wrong bind.

## Mixamo Rest Basis

Source: `assets/fighters/animations/Idle.fbx` after disconnecting the action and clearing pose (`edit_bone.matrix_local`, not frame 1).

- 65 bones, Mixamo prefix `mixamorig5:`
- Object Rx = 90°, scale = 0.01 (FBX)
- Hips rest head `(0, 93.01, 0)` tail `(0, 105.09, 0)` — T-pose spine-up in armature space
- Dump: `docs/generated/MIXAMO_REST_BASIS.json`

## ActorCore Rest Basis

Source: `terere/.../autorig_actor.fbx` edit rest. Jaguareté bone names match (101 bones). Canonical for both.

- 101 bones, `CC_Base_*`
- Same FBX object Rx = 90°, scale = 0.01
- Hip rest head `(0, 0, 51.62)` — different local Y than Mixamo hips
- Dump: `docs/generated/ACTORCORE_REST_BASIS.json`

## Per-Bone Basis Conversion

```
C_bone = T_world_rest_rot^-1 * S_world_rest_rot
R_tgt = C_bone * R_src * C_bone^-1
```

Scale stripped via `matrix.decompose()`. Not raw Euler/quat copy.

Measured `C_angle` (selected): Hip 93.9°, L/R Thigh ~93°, L/R Upperarm ~5–7°. Arms already share world rest axes; hip/leg do not.

Values: `docs/generated/SOLVER_V1_C_BONES.json`. Math: `docs/generated/REST_AXIS_SOLVER_MATH.md`.

## Retarget Equation

Implemented exactly as specified, using true rest:

```
M_delta_src = inverse(M_src_rest_local) * M_src_anim_local
M_delta_target = C_bone * M_delta_src * inverse(C_bone)
M_target_anim = M_target_rest_local * M_delta_target
```

`M_src_rest_local` is parent-relative `matrix_local`, never frame 1. In Blender this `M_delta_src` is `matrix_basis`.

That equation probes at **volume_ratio 10.82** with arms still T-pose-like (109° from down). Additional generic methods (world-delta, bone-Y aim, raw low-C copy, Blender Copy Rotation WORLD on arms only) also fail the volume gate. Same code path for both fighters.

## Root Motion Policy

Idle: Hip X = 0, Z = 0. Hip Y = `(src.y - rest_y) * 0.001`. Max root XZ = 0.0 on both experimental bakes. No locomotion.

## Tereré Metrics

From `docs/generated/TERERE_IDLE_SOLVER_V1_METRICS.json`:

- method: `constraint_world_arms` (last auto-selected; all probed methods failed)
- rest bbox: 189.8 × 75.6 × 166.3
- max_volume_ratio: **8.057** (fail, limit 1.35)
- max_axis_ratio: **1.837** (fail, limit 1.30)
- max_limb_length_rel_error: **0.0** (pass)
- max_root_xz: 0.0
- idle_pose_classification: **DEFORMATION_INVALID**
- mid-frame mean upperarm from down: 97.7° (T-pose-like if volume had passed)
- textures: diffuse `29aedd817e4fbf69` (Tereré source `.fbm`)

## Jaguareté Metrics

From `docs/generated/JAGUARETE_IDLE_SOLVER_V1_METRICS.json`:

- method: same `constraint_world_arms`
- rest bbox: 186.8 × 104.2 × 173.1
- max_volume_ratio: **9.531** (fail)
- max_axis_ratio: **2.102** (fail)
- max_limb_length_rel_error: **0.0** (pass)
- idle_pose_classification: **DEFORMATION_INVALID**
- textures: diffuse `654179021409871a` (Jaguareté source `.fbm`, different from Tereré)

## T-Pose Detection

Upper-arm bone Y vs torso-down. ≥ 70° would be `T_POSE_LIKE` if volume passed. Volume failure forces `DEFORMATION_INVALID`. Detector is wired in solver + Godot overlay.

## Blender Roundtrip

Previews (Space plays the `idle` action; Mixamo armature stripped):

- `assets/fighters/processed/solver_v1/terere/terere_idle_solver_v1_preview.blend`
- `assets/fighters/processed/solver_v1/jaguarete/jaguarete_idle_solver_v1_preview.blend`

Do **not** treat these as playtest-ready; the skinned Idle is deformed.

## Godot Lab

Isolated, not in battle:

- `scenes/debug/TerereSolverV1Lab.tscn`
- `scenes/debug/JaguareteSolverV1Lab.tscn`

Keys: 1 REST, 2 solver_v1 Idle, 3 skeleton, 4 bbox. Overlay: fighter, solver version, bone count, animation, volume ratio, pose classification.

Headless `validate_solver_v1.gd`: both GLBs load via `GLTFDocument`, 101 bones, clip `idle`. Not wired into battle.

## Automated Tests

`tests/test_rest_axis_solver_v1.py` covers true rest (not frame 1), `C_bone` existence, frame-1-not-bind, volume gate consistency, bone-length invariance, T-pose enum, both experimental outputs, character-specific textures, production V4 SHA256 unchanged.

Existing overnight / production / combat tests are preserved.

## Human Validation Required

Do not promote solver_v1 over V4. A human Idle playtest of these experimental GLBs would see inflated meshes, not Mixamo standing Idle.

Keep using production V4 (`terere_game_ready_v4.glb` / `jaguarete_game_ready_v4.glb`) in battle until a later solver passes volume + `STANDING_IDLE`.

## Active Blockers

1. **True Mixamo rest-relative Idle is not a safe AccuRIG skin pose.** Requested CoB, world-delta, Y-aim, and Blender world Copy Rotation all explode volume 7–11× while mapped bone lengths stay constant.
2. **Arm-only transfer still explodes.** Failure is not only the 93° hip `C_bone`; putting Mixamo's standing arm onto AccuRIG upperarm/forearm (C ≈ 6°) still fails.
3. AccuRIG helper/twist/share bones remain unmapped; they keep bind-relative identity while deform bones leave bind, which is a plausible skinning amplifier (not proven as the sole cause).
4. V4 clip-relative Idle remains the only structurally safe baked clip, and it is T-pose + sway (BLOCKER-021).

## Files Created

- `tools/blender/rest_axis_solver_v1.py`
- `docs/generated/MIXAMO_REST_BASIS.json`
- `docs/generated/ACTORCORE_REST_BASIS.json`
- `docs/generated/REST_AXIS_SOLVER_MATH.md`
- `docs/generated/SOLVER_V1_C_BONES.json`
- `docs/generated/SOLVER_V1_SELECTED_METHOD.json`
- `docs/generated/SOLVER_V1_V4_UNTOUCHED.json`
- `docs/generated/TERERE_IDLE_SOLVER_V1_METRICS.json`
- `docs/generated/JAGUARETE_IDLE_SOLVER_V1_METRICS.json`
- `assets/fighters/processed/solver_v1/terere/terere_idle_solver_v1.glb`
- `assets/fighters/processed/solver_v1/terere/terere_idle_solver_v1_preview.blend`
- `assets/fighters/processed/solver_v1/jaguarete/jaguarete_idle_solver_v1.glb`
- `assets/fighters/processed/solver_v1/jaguarete/jaguarete_idle_solver_v1_preview.blend`
- `scripts/debug/solver_v1_animation_lab.gd`
- `scripts/debug/terere_solver_v1_lab.gd`
- `scripts/debug/jaguarete_solver_v1_lab.gd`
- `scenes/debug/TerereSolverV1Lab.tscn`
- `scenes/debug/JaguareteSolverV1Lab.tscn`
- `scripts/debug/validate_solver_v1.gd`
- `tests/test_rest_axis_solver_v1.py`
- `docs/ACTORCORE_REST_AXIS_SOLVER_V1_REPORT.md`

## Files Modified

None of: gameplay, UI, Victory, fighter catalog, ActorCore V4 visuals, canonical sizes, production V4 GLBs.

Production V4 SHA256 unchanged:

- Tereré `D880B8E9FE03F8F0169728259A0C51F0A931AED401B4AA30A32BCED94EA0CEBE`
- Jaguareté `460BEE0AF4CF0CE3F9550948E3E69D349A9E3C1D1EFADE786178C8E5D639553C`

## Recommended Next Step

Do not retarget more Mixamo clips with this solver. Next Idle attempt should treat AccuRIG **skin bind** as the constraint, not only bone axes:

1. Measure posed vs rest **vertex** displacement per influence (Upperarm vs UpperarmTwist vs share bones) on a single arm bone 60° swing to confirm the 8× volume source.
2. Either pose AccuRIG twist/helper bones with the deform bone, or use an AccuRIG-native standing bind / Reallusion clip instead of Mixamo T-pose→stand.
3. Keep V4 in battle until a bake is `STANDING_IDLE` with `volume_ratio <= 1.35` on both fighters.
