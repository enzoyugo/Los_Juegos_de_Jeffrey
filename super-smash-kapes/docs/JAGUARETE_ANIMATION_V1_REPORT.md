# Jaguareté Animation V1 Report

## Primary Verdict

**SSK_JAGUARETE_ANIMATION_V1_PARTIALLY_READY**

Architecture, semantic API, Mixamo remapping, canonical sizing, fallback stack,
Animation Lab, and automated tests are in place. Human skeletal playtest is
still required before READY — Blender is unavailable for a rest-pose bake
(BLOCKER-015), so runtime name remapping may show mild deformation.

## Rigged GLB Inspection

| Item | Value |
|------|-------|
| Path | `res://assets/fighters/models/jaguarete/jaguarete_v2.glb` |
| Hierarchy | `Armature / Skeleton3D` + skinned mesh |
| Skeleton3D | present |
| Bones | 41 (`Root`, `Hip`, `Pelvis`, limbs, spine, head; no finger/tail bones) |
| AnimationPlayer | none embedded |
| Neutral AABB height | ~1.0 (local) before presentation scale |

Tereré v2: inspect-only (`terere_v2.fbx` present; GLB sidecar import without file).
No Tereré animation integration this milestone.

## Skeleton Hierarchy

Root → Hip → Pelvis / Waist → Spine01 → Spine02 → NeckTwist* → Head  
Limbs: `L_/R_Clavicle` → Upperarm → Forearm → Hand; Thigh → Calf → Foot → ToeBase  
Twist helper bones present; fingers/tail absent.

## Mixamo Hierarchy

FBX Without Skin, 65 bones, `mixamorig5_*` naming, clip `mixamo_com`.  
Root: `mixamorig5_Hips`. Full finger set. No mesh (expected).

## Compatibility Decision

**PATH B — Godot runtime bone-name remapping**

PATH A (direct) blocked by name/hierarchy mismatch.  
PATH C (Blender bake) blocked — Blender not installed (BLOCKER-015).

## Retarget Strategy

`mixamo_jaguarete_retarget.gd` maps core Mixamo bones → Jaguareté bones, drops
unmapped finger/end tracks, strips hip/root translation (no root motion authority).

## Animation Inventory

| Semantic | Source FBX |
|----------|------------|
| idle | Idle.fbx |
| jump | Unarmed Jump.fbx |
| attack_neutral | Mutant Punch.fbx |
| hit_light | Reaction.fbx |
| ko | Falling Back Death.fbx |

## Semantic Contract

Gameplay uses `play_semantic(...)` only — never Mixamo filenames.  
`FighterAnimationSet.make_jaguarete_prototype()` owns mappings + playback speeds.

## Root Motion

CharacterBody3D owns world translation. Hip/root position tracks stripped on retarget.

## Idle / Jump / Attack / Hit / KO

Idle loops. Jump one-shot; if still airborne after end → safe idle hold.  
Attack playback speed ≈ clip_length / (0.10+0.12+0.24) so hitbox timing stays authoritative.  
Hit restarts on re-hit. KO uses Falling Back Death pose only (no collider drive).

## Canonical Size Preservation

`target_visual_height = 3.15`, `SIZE.TALL`.  
`presentation_scale = target / measured_neutral_body_height` once.  
Never recomputed from animated AABB. Camera/HUD frozen.

## Fallback

rigged v2 → static `jaguarete_glb_1.glb` → procedural `jaguarete_visual.gd`  
Logged once on failure.

## Animation Lab

`scenes/debug/JaguareteAnimationLab.tscn` — keys 1–5, A/D rotate, R reset.

## Performance

Clips loaded once at bind; no per-frame FBX parse or scale recompute.

## Tests

Extended `test_m0_combat.py` for v2 asset, semantic map, retarget, sizing, lab, victory V4.

## Human Playtest

Please capture:

1. Idle 2. Jump 3. Punch 4. Hit 5. KO  
6. Tereré vs Jaguareté side-by-side  
Note: feet sliding, deformation, elbow/knee breaks, root drift, attack impact align, rest pose.

## Next Step

Install Blender → bake `jaguarete_game_ready.glb` AnimationLibrary (PATH C) → re-verify poses → READY.
