# Real GLB Fighter Integration Report

**Verdict:** `SSK_REAL_GLB_FIGHTERS_V1_READY_FOR_HUMAN_PLAYTEST`

**Date:** 2026-08-22  
**Godot:** 4.7.2 stable  
**Tests:** 48/48 passing (baseline was 43/43)

---

## Starting Baseline

- Milestone: `SSK_FIGHTER_PIPELINE_V2_READY_FOR_HUMAN_PLAYTEST`
- Tests: **43/43** before GLB integration
- Character Select, match flow, procedural Tereré/Jaguareté visuals working

## GLB Asset Validation

| Expected path (brief) | Actual path on disk | Status |
|-----------------------|---------------------|--------|
| `terere_v1.glb` | `terere_glb_1.glb` | Present, imported |
| `jaguarete_v1.glb` | `jaguarete_glb_1.glb` | Present, imported |

Both GLBs imported via `Godot --import`. Texture sidecars present (diffuse, normal, metallic-roughness). No missing resource errors at runtime.

## Tereré GLB Metrics

- File size: ~14.8 MB
- Meshes: 1 (`model`)
- Materials: 1 (PBR with duplicated per-instance flash cache)
- Native AABB: ~1.19 × 1.89 × 0.78 units
- Native Y range: ~-0.95 to +0.94 (centered near origin)
- Applied scale: **0.920** (fit height 2.35, 8% top ignored for bombilla)
- Ground offset Y: **0.875**

## Jaguareté GLB Metrics

- File size: ~13.9 MB
- Meshes: 1 (`model`)
- Materials: 1
- Native AABB: ~1.24 × 1.89 × 1.40 units
- Native Y range: ~-0.94 to +0.95
- Applied scale: **1.241** (fit height 2.35)
- Ground offset Y: **1.172**

## Imported Scene Structure

Each GLB instantiates as:

```text
model (Node3D root from import)
└── model (MeshInstance3D)
```

No skeleton, no animations, no skins (static mesh confirmed).

## Fighter Visual Architecture

```text
Fighter (CharacterBody3D — gameplay authority, unchanged)
├── BodyCollision / Hurtbox / AttackHitbox
├── Visual (hidden capsule)
└── VisualRoot
    └── CharacterVisual (glb_fighter_visual.gd)
        ├── BlobShadow (optional quad)
        └── VisualMotionRoot
            └── ModelRoot
                └── [GLB instance]
```

Procedural fallback spawns as child `ProceduralFallback` if GLB load fails.

## Tereré Scale / Offset / Orientation

- `model_yaw_offset = -90°` (GLB forward aligned to gameplay +X right)
- Facing via `ModelRoot.rotation.y` (0 / π), not negative scale
- Feet grounded via computed `_ground_offset` from mesh AABB min Y
- Bombilla height partially excluded from fit via `fit_ignore_top_ratio = 0.08`

## Jaguareté Scale / Offset / Orientation

- Same yaw correction (-90°)
- Full body height used for scale fit (tail excluded from fit ratio by using body height only — tail extends beyond hurtbox)
- Feet grounded via AABB min Y offset

## Facing Integration

`set_facing()` rotates `ModelRoot` on Y axis. Gameplay collider unchanged. No scale mirroring (avoids normal/material flip).

## Static-Mesh Motion Proxy

Whole-body motion on `VisualMotionRoot`:

| State | Motion |
|-------|--------|
| IDLE | Bob, breath scale, subtle sway |
| RUN | Lean, bounce, roll rhythm |
| AIR | Slight stretch |
| ATTACK | Forward lunge, squash, Tereré/Jaguareté accents |
| HITSTUN | Recoil; tumble rotation above speed threshold |
| LAND | Squash punch |
| RESPAWN | Visibility flicker (inherited) |
| VICTORY | Hero lean |

Motion resets via lerp — no permanent VisualRoot drift.

## Material / Lighting Review

- Imported PBR materials preserved
- Per-surface material duplicated once at spawn for hit flash (emission ~80ms)
- No runtime texture loading
- Blob shadow under feet for grounding readability

## Character Select Integration

Unchanged UI. Catalog `visual_script` now points to GLB wrappers. Selection spawns correct GLB per fighter ID.

## HUD Integration

Portraits remain raw design concept images (unchanged).

## Results Compatibility

Winner flow unchanged. Fighter display names from catalog unaffected.

## Performance

~81k / ~76k triangles per fighter (2 players ~157k tris total). Acceptable for RTX 2060 SUPER @ 1080p target. F3 perf overlay available. No per-frame mesh/material allocation.

Headless validation: clean spawn, no errors.

## Automated Tests

**48/48** passing (+5 GLB integration tests).

## Gameplay Regression Check

Unchanged (verified by tests + scene grep):

- Capsule body: radius 0.65, height 2.4
- Hurtbox: radius 0.78, height 2.6
- Hitbox: 1.55 × 1.15 × 1.0
- No edits to `fighter_stats.gd`, movement, attacks, knockback

## Overnight Blockers

- **BLOCKER-008** — User-specified filenames (`*_v1.glb`) differ from on-disk (`*_glb_1.glb`); integrated using actual paths. Rename aliases optional.
- Rigging/animation deferred (static mesh by design).

## Human Playtest Checklist

1. Boot → Batalla Local → select Tereré + Jaguareté
2. Confirm real GLB models in Defensores (not procedural/capsule)
3. Feet on platform, readable size, correct facing
4. Move, jump, fast fall, attack, hit, KO, respawn, rematch
5. F3 performance check

## Known Limitations

- No skeletal animation (static mesh motion proxy only)
- Orientation may need fine-tuning after human side-by-side with references
- Portrait still 2D concept art
- Results screen has no 3D victory model viewport yet (`victory_model_scene` hook reserved)

## Recommended Next Milestone

Human scale/orientation pass at gameplay camera distance, then optional rigged GLB v2 or reduced-poly export if performance feedback requires it.
