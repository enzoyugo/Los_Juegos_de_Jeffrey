# Smash Fighter Pipeline V1

Authority for adding Smash fighters to Los Juegos de Jeffrey.

## Source of truth

`scripts/fighters/fighter_catalog.gd` (`FighterCatalog`)

Shared Jeffrey roster auto-imports via `CharacterRegistry.register_builtin()`.

## Production fighters

| ID | Visual | Portrait | Victory |
|----|--------|----------|---------|
| terere | ActorCore V4 GLB + procedural fallback | portraits/terere | victory/terere |
| jaguarete | ActorCore V4 GLB + procedural fallback | portraits/jaguarete | victory/jaguarete |
| cartes | Jeffrey stylized procedural | portraits/cartes | victory/cartes |
| fort | Jeffrey stylized procedural | portraits/fort | victory/fort |
| pajaro_campana | Jeffrey stylized procedural | portraits/pajaro_campana | victory/pajaro_campana |

## Shared combat scene

`scenes/fighters/Fighter.tscn` + `scripts/fighters/fighter.gd`

Stats/attacks applied at spawn in `M0Playground` via `FighterCatalog.gameplay_profile(id)`.

## Minimum production contract

IDENTITY · PORTRAIT · IN-GAME VISUAL · IDLE/MOVE/JUMP · ATTACK · HIT · KO/RESPAWN · HUD · SELECT · RESULTS · COPA PROFILE SEPARATION · TESTS

## How to add another fighter

1. Portrait + victory PNG under `assets/ui/`
2. Visual script (stylized or ActorCore)
3. `_make_*` + register in `_ensure_loaded`
4. Optional `gameplay_profile` entry
5. No CharacterRegistry edit required

## Hardcoded risks fixed / mitigated

- Results victory fallback no longer forces Tereré for unknown IDs
- Stage + fighter IDs travel on `MatchSetup`
- Copa remains profile-based (`profile_id`), never fighter-based
