# JEFFREY_OVERNIGHT_TOTAL_REPAIR_V1 Worklog

## Baseline
- HEAD: `9f84a82` (synced with origin/main)
- Godot: 4.7.2.stable
- Blender: 5.2.1 LTS
- Dirty: untracked `.import`/`.uid` noise + `docs/art_refs/` (preserved)

## Manual smoke failures (authoritative)
- Costanera `h` type inference
- Smash `show_ko` invalid call
- Track menu `portrait_texture` on SharedCharacterDefinition
- Track `articulated_wheel_binds=0`
- Zombies stuck on env V3; duplicate ready/load
- Shell placeholders / layout issues

## Phase log

### P0 hard errors
- Costanera `var h: float` + `absi` — Godot headless stage load OK
- M0Playground KO: `has_method("show_ko")` guard
- Track menu: `def.portrait` / `def.icon` (never `portrait_texture`)

### Track vehicle authority
- **Root cause:** TrackMain spawned fused `TrackCar.tscn` (`use_articulated=false`) → `articulated_wheel_binds=0`
- **Fix:** default `TrackCarWheelPhysics.tscn`; opt-out `SSK_TRACK_CONTROLLER=BASELINE`
- **Validated:** headless smoke → `controller=FOUR_WHEEL_V1`, `articulated_wheel_binds=4`

### Zombies lifecycle
- **Root cause:** Copa rematch called `ZombiesMain._restart` which instantiated a fresh host while `zombies_host` still pointed at the freeing node → orphan hosts / repeated ready / VRAM growth
- **Fix:** rematch clears via `_clear_mode_hosts` then `_host_zombies`; group sweep `jeffrey_mode_host`
- Env: production remains **V3** (V4.x candidates firewall-lab only)

### Shell
- Track + Zombies → `AVAIL_PLAYABLE` / enabled / Hub badge JUGAR
- Mode player select: selection authority = card.pressed (not session∩pressed mismatch)
- Track menu slots rebuilt (mask baked demo names); pause restyled

### Tests
- New: `tests/test_jeffrey_overnight_total_repair_v1.py`
- Updated BASELINE→FOUR_WHEEL assertions across Track lock tests
- Full suite target: 484+ green after firewall fix

### Remaining (PARTIAL)
- Full 1920 screenshot automation package incomplete
- Track procedural world dressing still thin vs brief
- Human Fort/Cartes remain INTERIM
- Options visual pass light
- Smash fighter animation Blender pass deferred (policy)
