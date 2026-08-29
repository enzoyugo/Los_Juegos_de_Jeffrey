# Fighter Animation Pipeline V3 Proposal

> **Status:** BENCHMARK ONLY — do not migrate production without human approval.

## Proposed Standard (if ActorCore benchmark passes)

```
REFERENCE IMAGES
        ↓
3D GENERATION
        ↓
ACTORCORE / ACCURIG
        ↓
CANONICAL CC_Base_* SKELETON
        ↓
BLENDER OFFLINE RETARGET + BAKE (Mixamo → ActorCore)
        ↓
game_ready.glb (per fighter / per animation set)
        ↓
GODOT (embedded AnimationPlayer, no runtime retarget)
```

## Shared Pipeline Components

- `tools/blender/mixamo_to_actorcore_bone_map.json`
- `tools/blender/retarget_mixamo_to_actorcore.py`
- `tools/build_actorcore_idle_benchmark.ps1`

## Canonical Sizing (unchanged)

- Tereré: SHORT, 2.40
- Jaguareté: TALL, 3.15

## Shared retarget viable: **True**

## Next milestone (NOT this task)

SSK_ACTORCORE_CANONICAL_RIG_MIGRATION_V1

Bake full library: idle, run, jump, attack_neutral, hit_light, hit_heavy, ko, victory