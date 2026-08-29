# Track Turbo V8 human closure

**Verdict: TRACK_TURBO_V8_READY_FOR_HUMAN_PLAYTEST**

Party loop is still the V7 architecture (generate → summary → DALE/OTRA → countdown → race → CP → fuel → ranking → última → finish → handoff). Not redesigned.

## What V8 adds

- 15 m candidate visual kit (11 m preserved)
- Checkpoint split HUD
- `free()` visual lifetime
- Reveal V3: generating banner, piece build, camera pullback, **CanvasLayer summary panel** (no giant world text)
- Hotseat handoff full-screen panel with player color
- Qualification chip `TODOS MARCAN TIEMPO` → `EL ÚLTIMO SIGUE`
- Última banner then compact fuel label
- Blender urban scenery (palms/trees/lamps/buildings/landmarks) via MultiMesh-equivalent instancing
- Start/finish gantries from Blender
- Camera look-ahead + shortening vs world/camera-blocker layer
- Stronger drift smoke / skid marks (Godot VFX, not Blender)

## Scene

`scenes/debug/TrackTurboV8Showcase.tscn`

F3 debug off by default. F8 skips reveal. 1/2/3 length, T difficulty.

## F6 analogue

10 launches TrackTurboV8 ↔ ZombiesMain: **PASS**, `fatal=false`. Generator V4 ACCEPTED every Track launch (8–13 pieces, SHORT/PICANTE). Peak video 533 MB on the densest 15 m scenery set; Zombies teardown returns video to 427 MB.

## Not done / human

- Visual success is not claimed from screenshots
- Airborne coordinate needs a human pass at speed (geometry thickened; springs untouched)
- Audio hooks kept; placeholder sounds not a blocker
- TrackMain stays BASELINE / 11 m
