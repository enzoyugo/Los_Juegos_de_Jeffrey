# ActorCore Rig Benchmark V1 Report

## Primary Verdict

**SSK_ACTORCORE_RIG_BENCHMARK_V1_READY_FOR_HUMAN_PLAYTEST**

This is a **benchmark** verdict, not a production migration.

## Executive Summary

Isolated Mixamo Idle retarget/bake onto ActorCore AccuRig exports for Tereré and Jaguareté.
Production fighter catalog, combat, and canonical sizes were not modified.
Shared pipeline viable: **True**.
Generic rest-basis viable: **True**.

## Source Assets

| Character | FBX bytes | JSON | Textures |
|-----------|-----------|------|----------|
| Tereré | 4625952 | autorig_actor.json | 2 |
| Jaguareté | 4324160 | autorig_actor.json | 2 |

Inventory: `docs/generated/ACTORCORE_ASSET_INVENTORY.json`

## Blender Authority

Blender 2.83.1 @ `C:\Program Files\Blender Foundation\Blender 2.83\blender.exe`

## Tereré Rig

- Bones: 101
- Mesh / armature / weights: see inventory `fbx_content`
- Dump: `docs/generated/TERERE_ACTORCORE_RIG.json`

## Jaguareté Rig

- Bones: 101
- Dump: `docs/generated/JAGUARETE_ACTORCORE_RIG.json`

## Cross-Rig Equivalence

| Metric | Value |
|--------|-------|
| TOTAL_TERERE_BONES | 101 |
| TOTAL_JAGUARETE_BONES | 101 |
| COMMON_BONES | 101 |
| ONLY_TERERE | [] |
| ONLY_JAGUARETE | [] |
| PARENT_MISMATCHES | [] |
| CAN_ONE_SHARED_PIPELINE | **True** |

## Mixamo Source

`assets/fighters/animations/Idle.fbx` — dump `docs/generated/MIXAMO_IDLE_RIG_DUMP.txt`
Actual Mixamo prefix discovered from inspection (not guessed).

## Shared Bone Map

`tools/blender/mixamo_to_actorcore_bone_map.json`
- required mappings: **22**
- prefix: `mixamorig5:`
- shared_by: ['terere', 'jaguarete']

## Rest Basis Analysis

Mixamo vs ActorCore rest axes can differ; the engine transfers rest-relative rotation, not raw Euler.
Cross-character ActorCore rest match is the gate for one generic implementation.

| | Tereré | Jaguareté |
|--|--------|-----------|
| Mixamo mean rest delta | 58.8144° | 61.7465° |

- Cross-character max rest delta: **40.0947°**
- both_generic_viable: **True**

## Tereré Idle Bake

- Preview: `assets/fighters/processed/actorcore_benchmark/terere/terere_actorcore_idle_preview.blend`
- GLB: `assets/fighters/processed/actorcore_benchmark/terere/terere_actorcore_idle.glb` (14353408 bytes)
- keyed bones: 22
- hip Y max: 0.020550301298499107
- hip X max: 0.0
- hip Z max: 0.0
- motion accepted: **True** (18 branches)

## Jaguareté Idle Bake

- Preview: `assets/fighters/processed/actorcore_benchmark/jaguarete/jaguarete_actorcore_idle_preview.blend`
- GLB: `assets/fighters/processed/actorcore_benchmark/jaguarete/jaguarete_actorcore_idle.glb` (14151708 bytes)
- keyed bones: 22
- motion accepted: **True** (18 branches)

## Motion Audit

Metric is **intra-clip local rotation from first frame**, not rest-pose offset.
A bake is rejected if fewer than 6 body branches move.

Tereré Hip/Spine/Head deltas: Hip=5.8555 Spine=5.1133 Head=5.8818
Jaguareté Hip/Spine/Head deltas: Hip=5.8554 Spine=5.1133 Head=5.8817

## GLB Roundtrip

- Tereré accepted: **True**
- Jaguareté accepted: **True**

## Godot Import

- Labs: `scenes/debug/TerereActorCoreAnimationLab.tscn`, `JaguareteActorCoreAnimationLab.tscn`
- Tereré bone tracks: **67**
- Jaguareté bone tracks: **87**
- Runtime retarget: **OFF**

## Facial Capability

See `docs/generated/ACTORCORE_FACIAL_CAPABILITY_AUDIT.md`.
Jaw / eye / tongue / teeth bones present. This FBX import has **0 shape keys**;
expressions are technically possible via facial bones, not via blendshapes in this export.

## Performance Metrics

| | Tereré | Jaguareté |
|--|--------|-----------|
| vertices | 50382 | 47292 |
| polygons | 87067 | 82268 |
| bones | 101 | 101 |
| source FBX | 4625952 | 4324160 |
| exported GLB | 14353408 | 14151708 |

## ActorCore vs 3DAI

See `docs/generated/ACTORCORE_VS_3DAI_RIG_COMPARISON.md`.

## Production Migration Recommendation

**Do not migrate production.** Await human playtest of both preview blends and Godot labs.
Canonical sizes remain Tereré 2.40 SHORT and Jaguareté 3.15 TALL.

## Human Validation Required

1. Open `terere_actorcore_idle_preview.blend` → Space
2. Open `jaguarete_actorcore_idle_preview.blend` → Space
3. Run Godot labs — **1** rest, **2** idle
4. Tereré: bombilla, guampa, poncho, short silhouette
5. Jaguareté: tail, muzzle, paws, sash, tall silhouette

## Blockers

See `docs/Overnight_blockers.md` (BLOCKER-016 Godot `.import` sidecars; BLOCKER-017 no FBX shape keys; BLOCKER-018 glTF 4-influence weight clamp).

## Files Created

- ActorCore inspect/retarget/audit scripts under `tools/blender/`
- Benchmark GLB/blend under `assets/fighters/processed/actorcore_benchmark/`
- Isolated Godot labs under `scenes/debug/`
- Generated dumps under `docs/generated/`

## Files Modified

- `tests/test_m0_combat.py` (existing ActorCore assertions retained)
- `tests/test_actorcore_idle_benchmark.py` (focused benchmark tests)
- `docs/Overnight_blockers.md`

## Tests

Existing combat/UI tests preserved. Focused ActorCore benchmark tests added.

## Recommended Next Step

Human playtest. If both characters pass visual criteria → `SSK_ACTORCORE_CANONICAL_RIG_MIGRATION_V1`
(full shared library: idle, run, jump, attack_neutral, air_attack, hit_light, hit_heavy, ko, victory).

Generated: 2026-08-22T20:13:28.405082+00:00