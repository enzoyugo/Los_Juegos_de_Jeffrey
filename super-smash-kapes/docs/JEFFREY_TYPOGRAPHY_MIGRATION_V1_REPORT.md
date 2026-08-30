# Jeffrey Typography Migration V1

## Scope

This migration changes player-facing Godot typography only. Gameplay, physics, controls, save data, progression, and balance were not changed.

## Canonical font mapping

| Surface | Canonical face | Runtime path |
|---|---|---|
| LJDJ/global shell | Borsok | `res://assets/fonts/global/boorsok.ttf` |
| Track | Veter | `res://assets/fonts/track/Veter.ttf` |
| Zombies | Super Midnight | `res://assets/fonts/zombies/Super Midnight.ttf` |
| Soco/Smash primary | Jumbotron | `res://assets/fonts/soco/JUMBOTRON.otf` |
| Soco alternate | Super Crawler | `res://assets/fonts/soco/Super Crawler.ttf` |

The source packages under `res://assets/fonts/_incoming/` are preserved. The five canonical runtime files are copied from those packages without editing the font binaries.

## Architecture

`scripts/ui/jeffrey/system/jeffrey_typography.gd` is the single code-built theme authority. It exposes `font_for()` and `theme_for()` plus helpers for `Label`, `Button`, `LineEdit`, and `Label3D`. The application shell supplies Borsok; Track and Zombies roots override that inherited theme; legacy Smash controls receive the Soco face directly where their CanvasLayer ancestry bypasses Control theme inheritance. Runtime-created controls inherit the active mode root theme.

## Audit classification

- `GLOBAL_LJDJ`: shell screens and shared reusable Jeffrey UI under `JeffreyApp._present()`.
- `TRACK`: Track menus, HUD, results, checkpoint labels, and speed-readable signage.
- `ZOMBIES`: Zombies menus, loading, HUD, mall signage, interactable prompts, and power-up/world labels.
- `SOCO`: legacy Smash character select, results, player HUD, pause overlay, match HUD, and shared Smash buttons.
- `NOT_PLAYER_FACING`: editor/debug/lab scenes and engineering overlays remain intentionally outside the migration.
- `BAKED_IN_ART`: text embedded in raster art or imported 3D textures remains unchanged and is not a runtime font reference.

No legacy runtime `res://` font path was retained in the migrated production scripts. Explicit debug/lab overlays are intentionally excluded from player-facing typography validation.

## Glyph support

The headless validator checks the canonical resources and the Spanish gameplay glyph set: `ÁÉÍÓÚÑÜáéíóúñü¿¡` for every active mode face. It also checks the required global/Track/Zombies/Soco root bindings.

## Validation command

```text
godot --headless --path . --script res://scripts/validation/validate_jeffrey_typography_v1.gd
```

The migration is complete when this validator, project parse/import, existing tests, and representative rendered smoke captures pass.
