# Fighter Content Pipeline

## Overview

Fighters are data-driven visual shells around the existing `Fighter` gameplay controller. Gameplay collision, movement, attacks, and knockback are unchanged.

```text
Fighter (CharacterBody3D — gameplay authority)
├── BodyCollision / Hurtbox / AttackHitbox   ← unchanged
├── Visual (capsule placeholder, hidden)
└── VisualRoot
    └── GlbFighterVisual (or procedural fallback)
        └── VisualMotionRoot → ModelRoot → GLB instance
```

## GLB integration (V1)

Primary in-game models:

- `assets/fighters/models/terere/terere_glb_1.glb`
- `assets/fighters/models/jaguarete/jaguarete_glb_1.glb`

Wrappers:

- `fighters/terere/TerereGLBVisual.tscn` + `terere_glb_visual.gd`
- `fighters/jaguarete/JaguareteGLBVisual.tscn` + `jaguarete_glb_visual.gd`

Base: `scripts/fighters/glb_fighter_visual.gd` — AABB fit, facing, motion proxy, material flash, procedural fallback.

Diagnostics: `SSK_MODEL_AUDIT=1`, `SSK_SHOW_FIGHTER_COLLIDERS=1`

## Core types

| Type | Path | Role |
|------|------|------|
| `FighterDefinition` | `scripts/fighters/fighter_definition.gd` | id, names, colors, portrait, visual script |
| `FighterCatalog` | `scripts/fighters/fighter_catalog.gd` | registry + default match setup |
| `MatchSetup` | `scripts/core/match_setup.gd` | selected fighter IDs per player |
| `FighterVisual` | `scripts/fighters/fighter_visual.gd` | visual API (facing, states, hooks) |

## Adding Fighter #3 (repeatable workflow)

1. Place raw design references in `assets/fighters/raw_design/<fighter_id>/`
2. Study references → add section to `docs/FIGHTER_REFERENCE_BREAKDOWN.md`
3. Place GLB in `assets/fighters/models/<fighter_id>/` and run Godot `--import`
4. Create `<fighter_id>_glb_visual.gd` + `GlbFighterVisual` wrapper scene
5. Register in `FighterCatalog` with `fallback_visual_script` pointing to procedural visual
6. Add regression checks to `tests/test_m0_combat.py`
7. Fighter appears automatically in Character Select via catalog

## Recommended raw design naming (future)

```text
assets/fighters/raw_design/<fighter_id>/
  front.png
  side.png
  back.png
  expression.png
  colors.png
```

Current user files are preserved with original filenames.

## Visual API

Gameplay calls (visual-only):

- `bind(fighter, definition)`
- `sync_from_fighter(delta)` — idle/run/air/attack/hit states
- `on_attack_started()`, `on_hit()`, `on_jump()`, `on_respawn()`, `on_eliminated()`, `on_victory()`

## Match flow

```text
Title → ELIGÍ TU KAPE → MatchSetup → M0Playground spawns catalog fighters → Results → Revancha (same setup)
```

## Portraits

HUD and Character Select use `FighterDefinition.portrait_texture` sourced from raw design hero images.

## Performance rules

- Pre-create materials in visual `_ready`
- No runtime mesh regeneration per frame
- Limited spot meshes (Jaguareté)
- Hit flash toggles cached material emission — no new resources per hit
