# Overnight Fighter Pipeline Report

**Verdict:** `SSK_FIGHTER_PIPELINE_V2_READY_FOR_HUMAN_PLAYTEST`

**Date:** 2026-08-22  
**Godot:** 4.7.2 stable  
**Tests:** 35/35 passing (baseline was 27/27)

---

## Starting Baseline

- Presentation milestone `SSK_OVERNIGHT_PRESENTATION_V1_READY_FOR_HUMAN_PLAYTEST` complete
- 27/27 tests passing before fighter work
- Gameplay human-approved; red/blue capsule placeholders in battle

## Raw Design Assets Discovered

| Character | Directory | Files |
|-----------|-----------|-------|
| TERERÉ | `assets/fighters/raw_design/terere/` | 5 PNGs |
| JAGUARETÉ | `assets/fighters/raw_design/jaguarete/` | 5 PNGs |

Additional JPEG references detected and imported by Godot scan (not moved).

## File → Character Mapping

- **Tereré canonical:** `terere/ChatGPT Image 22 ago 2026, 04_19_46 (1).png`
- **Jaguareté canonical:** `jaguarete/ChatGPT Image 22 ago 2026, 04_19_47 (6).png`

Full breakdown: `docs/FIGHTER_REFERENCE_BREAKDOWN.md`

## Architecture Before / After

**Before:** Single `Fighter.tscn` with visible capsule mesh; P1 red / P2 blue color only.

**After:**

```text
Fighter
├── GameplayBody (collision unchanged)
├── Visual (hidden placeholder)
└── VisualRoot → TerereVisual | JaguareteVisual

FighterCatalog → FighterDefinition → visual script
MatchSetup → main → M0Playground spawn
KapesCharacterSelectScreen → ELIGÍ TU KAPE
```

## Tereré Reference vs Implementation

| Feature | Reference | Implementation |
|---------|-----------|----------------|
| Guampa body | ✓ | Cylinder + torus rim, wood materials |
| Yerba top | ✓ | Green cylinder cap |
| Bombilla | ✓ | Metallic cylinder, procedural sway |
| Face on cup | ✓ | Eyes, brows, mouth on front |
| Poncho tricolor | ✓ | Red/white/blue box mesh |
| Orange limbs | ✓ | Capsule limbs + navy sandals |
| Attack gesture | Forward arm punch | Right arm extends on ATTACK state |

**Known deviations:** Simplified poncho fringe; 3D depth added to 2D cup face; bombilla fixed side (documented).

## Jaguareté Reference vs Implementation

| Feature | Reference | Implementation |
|---------|-----------|----------------|
| Golden jaguar fur | ✓ | Fur material + cream belly |
| Rosette spots | ✓ | 14 dark sphere decals (performance cap) |
| Muzzle/fangs | ✓ | Cream sphere muzzle, cylinder fangs |
| Spiky hair | ✓ | Dark box tuft |
| Tail silhouette | ✓ | 3-segment tail with sway |
| Sash/belt/wristbands | ✓ | Tricolor box meshes |
| Large paws | ✓ | Sphere hands/feet + claw mesh |

**Known deviations:** Spots are mesh blobs not painted rosettes; rear view inferred.

## Model Construction

Godot primitive composition (cylinder, capsule, sphere, box) with tuned materials. No Blender dependency. No external downloads.

## Animation Approach

Procedural transforms in `FighterVisual.sync_from_fighter()`:

- States: IDLE, RUN, AIR, ATTACK, HITSTUN, RESPAWN, KO, VICTORY
- Idle bob, run limb swing, attack arm extension, hit lean, respawn flicker visibility
- Tereré bombilla sway; Jaguareté tail segment sine motion

## Character Select

- Title → **BATALLA LOCAL** → **ELIGÍ TU KAPE**
- P1: A/D + F/Space; P2: arrows + N
- Independent selection + LISTO confirmation
- Mirror match supported (same fighter both players)
- Cards use raw design portrait textures

## MatchSetup

`MatchSetup` holds `player_1_fighter_id` / `player_2_fighter_id`. Defaults: terere vs jaguarete. Rematch preserves selection.

## HUD Portrait Pipeline

`KapesPlayerHUD` displays `fighter.definition.portrait_texture` in plate cutout region. Damage/stocks unchanged.

## Results Integration

`KapesResultsScreen.setup(winner_id, summary, match_setup)` shows **TERERÉ GANA** / **JAGUARETÉ GANA** with per-player fighter names in stats panel.

## Spawn / Respawn Presentation

- Spawn: visual binds at fighter `_ready`; intro remains `¡DALE!`
- Respawn: visual visibility flicker during invulnerability (timing unchanged)

## Combat Visual Integration

Attack/hit/knockback gameplay untouched. Visual arm extension (Tereré) / body lean (both) on ATTACK/HITSTUN. Hit flash via cached material emission (~80ms).

## Performance

- No per-frame mesh generation
- ≤14 spot meshes per Jaguareté
- Materials cached in visual `_ready`
- No runtime texture loading in `_process`

## Automated Tests

Added 8 fighter pipeline tests (35 total). See `tests/test_m0_combat.py`.

## Godot 4.7.2 Validation

- `--import` completed for raw design PNGs
- Headless `SSK_AUTO_START_BATTLE=1`: menu → transition → battle, fighters spawn, no parse errors
- Focus null at battle start (freeze audit)

## Blockers

See `docs/Overnight_blockers.md` — BLOCKER-004 (asset import required once) **RESOLVED** via `--import`.

## Human Playtest Checklist

Prepared in final report section below.

## Future Fighter Workflow

Documented in `docs/FIGHTER_PIPELINE.md` — ~7 steps to add Fighter #3.

## Files Created (key)

- `scripts/fighters/fighter_definition.gd`
- `scripts/fighters/fighter_catalog.gd`
- `scripts/fighters/fighter_visual.gd`
- `scripts/core/match_setup.gd`
- `scripts/ui/kapes_character_select.gd`
- `fighters/terere/terere_visual.gd`
- `fighters/jaguarete/jaguarete_visual.gd`
- `docs/FIGHTER_REFERENCE_BREAKDOWN.md`
- `docs/FIGHTER_PIPELINE.md`

## Files Modified (key)

- `scripts/fighters/fighter.gd` — visual integration
- `scripts/core/m0_playground.gd` — catalog spawn, fighter names in win
- `scripts/core/main.gd` — character select flow, match setup
- `scripts/ui/kapes_player_hud.gd` — portrait textures
- `scripts/ui/kapes_results_screen.gd` — fighter identity
- `scenes/fighters/Fighter.tscn` — VisualRoot, hidden capsule
- `tests/test_m0_combat.py` — +8 tests

## Git Status

Substantial uncommitted work under `super-smash-kapes/`. No commits made per instructions.

## Known Limitations

- Debug fighter viewer not built (bonus deferred)
- Spawn VFX shimmer minimal (identity via model, not particles)
- Jaguareté spots are simplified mesh decals
- Rear views inferred where references lack them
- Audio hooks not added

## Recommended Next Milestone

Human playtest fidelity pass: compare in-engine silhouettes side-by-side with raw references at gameplay camera distance; tune proportions/materials based on feedback without touching collision or combat numbers.
