# Jaguareté Rig Compatibility Audit

**Date:** 2026-08-22  
**Godot:** 4.7.2  
**Scope:** Jaguareté v2 + Mixamo FBX (Without Skin) — inventory only, no Tereré animation integration.

---

## Authoritative Paths

| Asset | Path |
|-------|------|
| Jaguareté v2 | `res://assets/fighters/models/jaguarete/jaguarete_v2.glb` |
| Tereré v2 (inspect only) | `res://assets/fighters/models/terere/terere_v2.fbx` (GLB file currently missing; `.import` sidecar remains) |
| Mixamo sources | `res://assets/fighters/animations/*.fbx` |
| Static fallback v1 | `res://assets/fighters/models/jaguarete/jaguarete_glb_1.glb` |

Blender: **not found** on this machine.

---

## Jaguareté v2 Hierarchy

```
jaguarete_v2 (Node3D)
└── Armature (Node3D)
    └── Skeleton3D (Skeleton3D)
        └── [skinned MeshInstance3D]
```

| Metric | Value |
|--------|-------|
| Skeleton3D path | `Armature/Skeleton3D` |
| Bone count | **41** |
| Mesh count | **1** |
| AnimationPlayer | **none** (no embedded clips) |
| Neutral AABB height (mesh local) | ~1.00 |

### Bone list (parent index)

| Idx | Bone | Parent |
|-----|------|--------|
| 0 | Root | -1 |
| 1 | Hip | 0 |
| 2 | Pelvis | 1 |
| 3 | L_Thigh | 2 |
| 4 | L_Calf | 3 |
| 5 | L_Foot | 4 |
| 6 | L_ToeBase | 5 |
| 7–10 | L twist helpers | … |
| 11 | R_Thigh | 2 |
| 14 | R_Calf | 11 |
| 15 | R_Foot | 14 |
| 16 | R_ToeBase | 15 |
| 19 | Waist | 1 |
| 20 | Spine01 | 19 |
| 21 | Spine02 | 20 |
| 22 | NeckTwist01 | 21 |
| 23 | NeckTwist02 | 22 |
| 24 | Head | 23 |
| 25 | L_Clavicle | 21 |
| 26 | L_Upperarm | 25 |
| 27 | L_Forearm | 26 |
| 30 | L_Hand | 27 |
| 33 | R_Clavicle | 21 |
| 34 | R_Upperarm | 33 |
| 37 | R_Forearm | 34 |
| 40 | R_Hand | 37 |

**Root bone:** `Root`  
**Hip/pelvis:** `Hip` → `Pelvis`  
**Spine:** `Waist` → `Spine01` → `Spine02`  
**Head:** `NeckTwist01` → `NeckTwist02` → `Head`  
**Arms:** clavicle → upperarm → forearm → hand (+ twist bones)  
**Legs:** thigh → calf → foot → toe  
**Tail bones:** **none** in this skeleton (tail is mesh-only if present).

---

## Tereré v2 (inspect only)

```
terere_v2 (Node3D)
└── model (MeshInstance3D)
```

| Metric | Value |
|--------|-------|
| Skeleton3D | **0** |
| AnimationPlayer | **0** |
| Meshes | 1 |
| AABB height | ~1.88 |

Tereré v2 is **static mesh only** — not a candidate for skeletal Mixamo playback in this milestone.

---

## Mixamo FBX (Idle / Mutant Punch)

```
Idle / MutantPunch (Node3D)
├── Skeleton3D
└── AnimationPlayer  (clip name: "mixamo_com")
```

| Metric | Value |
|--------|-------|
| Bone count | **65** |
| Meshes | **0** (Without Skin — expected) |
| Root | `mixamorig5_Hips` |
| Spine | `Spine` → `Spine1` → `Spine2` |
| Head | `Neck` → `Head` → `HeadTop_End` |
| Limbs | Mixamo standard + full fingers |
| Legs | `LeftUpLeg` / `RightUpLeg` → Leg → Foot → ToeBase |

---

## Name Compatibility

| Role | Mixamo | Jaguareté v2 | Match? |
|------|--------|--------------|--------|
| Hips | mixamorig5_Hips | Hip | **no** (name) |
| Spine | Spine/Spine1/Spine2 | Waist/Spine01/Spine02 | **no** |
| Head | Head | Head | semantic only |
| Arms | LeftArm… | L_Upperarm… | **no** |
| Legs | LeftUpLeg… | L_Thigh… | **no** |
| Fingers | full set | **absent** | drop tracks |
| Bone count | 65 | 41 | different |

**Direct clip reuse (PATH A): NOT viable** — bone names and hierarchy labels differ.

---

## Recovery V2 — Core Bone Mapping (Idle)

Used by `jaguarete_idle_binder.gd` (`mixamo_name_remap_idle`). Rotation tracks only; position tracks stripped.

| Jaguareté v2 bone | Mixamo Idle candidate | Notes |
|-------------------|----------------------|-------|
| Root | *(none)* | Not animated from Mixamo |
| Hip | mixamorig5_Hips | Root motion stripped |
| Pelvis | *(child of Hip)* | Follows Hip hierarchy |
| Waist | mixamorig5_Spine | Spine base |
| Spine01 | mixamorig5_Spine1 | |
| Spine02 | mixamorig5_Spine2 | Chest |
| NeckTwist01 | mixamorig5_Neck | |
| NeckTwist02 | *(unmapped)* | Follows parent |
| Head | mixamorig5_Head | |
| L_Clavicle | mixamorig5_LeftShoulder | |
| L_Upperarm | mixamorig5_LeftArm | |
| L_Forearm | mixamorig5_LeftForeArm | |
| L_Hand | mixamorig5_LeftHand | |
| R_Clavicle | mixamorig5_RightShoulder | |
| R_Upperarm | mixamorig5_RightArm | |
| R_Forearm | mixamorig5_RightForeArm | |
| R_Hand | mixamorig5_RightHand | |
| L_Thigh | mixamorig5_LeftUpLeg | |
| L_Calf | mixamorig5_LeftLeg | |
| L_Foot | mixamorig5_LeftFoot | |
| L_ToeBase | mixamorig5_LeftToeBase | |
| R_Thigh | mixamorig5_RightUpLeg | |
| R_Calf | mixamorig5_RightLeg | |
| R_Foot | mixamorig5_RightFoot | |
| R_ToeBase | mixamorig5_RightToeBase | |

Finger / twist helper bones: **unmapped** (rest pose retained).

---

## Compatibility Decision

### PATH B — Runtime name remap (interim, idle only)

Recovery V2 uses rotation-only track copy via explicit `BONE_MAP`.  
**Suspect for production** — rest-pose mismatch may cause deformation.

### PATH C — Blender preprocessing (preferred)

**Blocked:** Blender not installed. Documented as BLOCKER-015.

Ideal deliverable: `jaguarete_game_ready.glb` with mesh + skeleton + AnimationLibrary already retargeted.

### Godot SkeletonProfileHumanoid / BoneMap

Not yet wired. To be attempted if runtime remap fails human idle test.

---

## Prototype Semantic Map

| Semantic | Source FBX |
|----------|------------|
| idle | Idle.fbx |
| jump | Unarmed Jump.fbx |
| attack_neutral | Mutant Punch.fbx |
| hit_light | Reaction.fbx |
| ko | Falling Back Death.fbx |

---

## Risks

1. Rest-pose mismatch may cause mild mesh deformation until Blender/BoneMap humanoid retarget.
2. No finger bones → hands stay in rest finger pose.
3. No tail bones → tail follows body skin weights only.
4. Mixamo root motion must never drive CharacterBody3D.
