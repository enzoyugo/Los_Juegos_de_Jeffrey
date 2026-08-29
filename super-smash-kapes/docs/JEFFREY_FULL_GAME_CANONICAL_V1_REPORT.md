# JEFFREY_FULL_GAME_CANONICAL_V1 Report

**Verdict:** `JEFFREY_FULL_GAME_CANONICAL_V1_PARTIAL`

Playable default routes consolidated + Track Menu V1 shipped. Human Blender fighter art remains INTERIM (acknowledged, not a P0 blocker). Full interactive Hub→all-modes screenshot package still needs human pass.

**Tests:** 475 pytest passed · JeffreyFullGameCanonicalV1Lab PASS

## Primary verdict

Canonical shell routes Smash / Track / Zombies to latest verified stable hosts. Track gains approved Costanera configuration menu (no pista picker). Fort V2 stays experimental.

## Canonical authority

See `docs/CANONICAL_RUNTIME_AUTHORITY.md`.

### Shell
Boot → roster → Hub → mode menus → transitions → mode hosts.

### Smash
FighterCatalog + StageCatalog production wiring. Human stylized GLBs labeled **INTERIM**. Fort V2 candidate gated by env.

### Track
New menu → procedural TrackMain with length/difficulty from menu. Costanera image is **UI only**.

### Zombies
Existing Zombies menu + ZombiesMain host unchanged as production.

## Track Menu V1

| Item | Status |
|------|--------|
| Assets | `assets/ui/track/menu_v1/` |
| Script | `track_menu_screen.gd` |
| Active players | Dynamic from `pending_participants` / profiles |
| Length | corta/media/larga → TrackConfig |
| Difficulty | FÁCIL/NORMAL/DIFÍCIL → tranqui/picante/demente |
| Start | launches transition → TrackMain auto-start |
| Back | character select |
| Audio | GlobalUiAudio navigate/confirm/back/whoosh |

## Experimental / non-final art excluded

- Fort V2 candidate
- Cartes/Fort human Blender as FINAL
- Labs / semantic candidates

## Tests

See shipping notes in final response.

## Remaining gaps

- Manual Hub interactive smoke + screenshot package
- Difficulty maps to generator time/piece pools (not a separate AI opponent system)
- Track players panel overlays baked demo art (dynamic names/cars on top)
