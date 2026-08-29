# Jaguareté Animation Recovery V2 Report

## Primary Verdict

**SSK_JAGUARETE_ANIMATION_RECOVERY_V2_PARTIALLY_READY**

Parser failure fixed. Jaguareté v2 should now render in battle (not capsule).
Idle bind attempted via `jaguarete_idle_binder.gd` (rotation-only Mixamo remap).
**HUMAN_REQUIRED** to confirm bones visibly move during idle.

## Previous Failure

Human playtest: P2 showed beige capsule; no skeletal animation.
Godot runtime error:

```
Parse Error: The member "TUMBLE_SPEED_THRESHOLD" already exists in parent class
Could not resolve class res://scripts/fighters/rigged_fighter_visual.gd
Failed to load script jaguarete_rigged_visual.gd
```

## Parser Root Cause

`rigged_fighter_visual.gd` extended `glb_fighter_visual.gd` but **redeclared**
`const TUMBLE_SPEED_THRESHOLD`, which Godot 4 treats as a duplicate parent member →
parse failure → `create_visual()` returned null → **emergency capsule**.

## Script Architecture Fix

- **Removed** `scripts/fighters/rigged_fighter_visual.gd` (broken middle layer).
- **Rewrote** `fighters/jaguarete/jaguarete_rigged_visual.gd` to extend
  `glb_fighter_visual.gd` directly.
- **Added** `scripts/fighters/jaguarete_idle_binder.gd` (RefCounted helper, idle only).
- **fighter.gd**: if primary visual script fails, tries `fallback_visual_script`
  (static v1) before capsule.

## V2 GLB Load

Path: `res://assets/fighters/models/jaguarete/jaguarete_v2.glb`  
Loaded via standard `glb_fighter_visual._load_glb_model()` — animation failure does
**not** trigger model fallback.

## Skeleton

Expected: `Armature/Skeleton3D`, 41 bones.  
Audit log prefix: `[JAG_RIG]` when `SSK_ANIMATION_AUDIT=1`.

## Idle Compatibility

| Jaguareté v2 | Mixamo Idle |
|--------------|-------------|
| Hip | mixamorig5_Hips |
| Waist | mixamorig5_Spine |
| Spine01 | mixamorig5_Spine1 |
| Spine02 | mixamorig5_Spine2 |
| NeckTwist01 | mixamorig5_Neck |
| Head | mixamorig5_Head |
| L_Clavicle | mixamorig5_LeftShoulder |
| L_Upperarm | mixamorig5_LeftArm |
| L_Forearm | mixamorig5_LeftForeArm |
| L_Hand | mixamorig5_LeftHand |
| R_Clavicle | mixamorig5_RightShoulder |
| R_Upperarm | mixamorig5_RightArm |
| R_Forearm | mixamorig5_RightForeArm |
| R_Hand | mixamorig5_RightHand |
| L_Thigh | mixamorig5_LeftUpLeg |
| L_Calf | mixamorig5_LeftLeg |
| L_Foot | mixamorig5_LeftFoot |
| R_Thigh | mixamorig5_RightUpLeg |
| R_Calf | mixamorig5_RightLeg |
| R_Foot | mixamorig5_RightFoot |

Finger/end bones dropped. Position tracks stripped (rotation-only remap).

## Retarget Path

**mixamo_name_remap_idle** (runtime rotation remap) — interim until Blender bake.  
Godot SkeletonProfileHumanoid / BoneMap not yet wired.  
**OFFLINE RETARGET REQUIRED** for production-quality idle (BLOCKER-015).

## Idle Playback

`jaguarete_idle_binder.bind_idle()` → AnimationPlayer `ssk/idle` loop.  
Failure logs warning but **model stays visible**.

## Root Motion

No hip position tracks imported. CharacterBody3D owns world motion.

## Canonical Size

`target_visual_height = 3.15`, `SIZE.TALL` — unchanged.  
Scale once from neutral AABB via `_align_model_to_gameplay()`.

## Fallback Chain

1. Jaguareté v2 rigged (`jaguarete_rigged_visual.gd`)
2. Static v1 GLB (`jaguarete_glb_visual.gd`) — via config delegate or fighter fallback
3. Procedural (`jaguarete_visual.gd`) — behind static GLB
4. **Capsule** — only if all scripts fail (`emergency_capsule` log)

## Animation Lab

`scenes/debug/JaguareteAnimationLab.tscn`  
Keys: **1** bind pose | **2** idle  
On-screen: MODEL / SKELETON / ANIMATION / RETARGET / FALLBACK

## Tests

63/63 passing. Parser regression + fallback tier + V5 victory structure.

## Godot Validation

`rig_script_load_test.gd`: all scripts load without parse errors.

## Human Required

Confirm in battle + lab:

- Jaguareté v2 mesh visible (not capsule)
- Idle bones move / mesh deforms
- No root drift
- Feet mostly grounded

## Remaining Blockers

- **BLOCKER-015**: Blender unavailable — bake `jaguarete_game_ready.glb` with AnimationLibrary
- Rest-pose mismatch may cause mild deformation until offline bake
