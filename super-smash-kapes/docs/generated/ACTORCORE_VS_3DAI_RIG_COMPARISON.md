# ActorCore vs 3DAI Rig Comparison

**Automated verdict:** ACTORCORE BETTER (pending human visual confirmation)

## Skeleton Consistency
- ActorCore Tereré bones: 101
- ActorCore Jaguareté bones: 101
- Common bones: 101
- Shared pipeline viable: **True**

## Bone Naming
- ActorCore: `CC_Base_*` AccuRig standard
- 3DAI v2 Jaguareté: custom (`Hip`, `L_Thigh`, …)
- 3DAI Tereré: static mesh / no shared skeleton

## Bone Count
- ActorCore: ~100+ with fingers/facial
- 3DAI Jaguareté v2: 41

## Hierarchy Consistency
- Parent mismatches between Tereré/Jaguareté ActorCore: 0

## T-Pose Quality
- Human validation required in preview `.blend` files

## Mixamo Retarget Complexity
- ActorCore: one shared `mixamo_to_actorcore_bone_map.json`
- 3DAI: per-character bone names + custom maps

## Need For Per-Character Hacks
- ActorCore: generic retarget script, same map
- 3DAI Jaguareté: custom `jaguarete_mixamo_bone_map.json`

## Bone Basis Compatibility
- Tereré mean rest delta: 58.8144°
- Jaguareté mean rest delta: 61.7465°

## Facial Rig Potential
- ActorCore includes jaw/eye/tongue/teeth bones; this FBX has 0 shape keys
- 3DAI v2: no facial rig

## Godot Import
- Benchmark GLBs under `processed/actorcore_benchmark/`
- Isolated debug labs only — production unchanged

## Animation Track Quality
- See `*_ACTORCORE_GODOT_TRACKS.txt`

## Mesh Deformation
- Human validation required

## Pipeline Reusability
- ActorCore: HIGH if shared pipeline = true
- 3DAI: LOW — per-character retarget

## Future Fighter Scalability
- ActorCore AccuRig export → shared offline bake is scalable
- 3DAI requires bespoke skeleton mapping per fighter

## Explicit Answer

ACTORCORE BETTER (pending human visual confirmation)