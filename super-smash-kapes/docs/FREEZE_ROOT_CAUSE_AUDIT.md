# Runtime Freeze Root-Cause Audit

## Observed reproduction

Human testing reported that the battle scene rendered Defensores art, HUD,
scoreboard, and fighters, then appeared stuck a few frames later.

## Diagnostic method

Diagnostics are opt-in through the environment variable:

```powershell
$env:SSK_FREEZE_AUDIT='1'
```

Run the direct battle scene:

```powershell
& 'E:\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\SuperSmashKapes\super-smash-kapes' --quit-after 1200 'res://scenes/core/M0Playground.tscn'
```

To exercise menu-to-battle transition automatically:

```powershell
$env:SSK_AUTO_START_BATTLE='1'
& 'E:\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'E:\SuperSmashKapes\super-smash-kapes' --quit-after 1200
```

For gameplay-only comparison:

```powershell
$env:SSK_DISABLE_STAGE_VISUALS='1'
$env:SSK_DISABLE_HUD='1'
```

## Evidence

Both gameplay-only and full visual runs reached:

- First physics tick.
- Intro tween completion.
- Heartbeats from one through at least eight seconds.
- `paused=false`.
- `match_over=false`.
- P1 and P2 in `NORMAL` state.
- P1 and P2 `locked=false`.
- Scoreboard transition from hype to neutral.

The menu-to-battle run additionally confirmed:

- Flag wipe started.
- Battle transition callback executed.
- Flag wipe completed.
- HUD and fighters initialized.
- Intro completed.
- Heartbeats continued afterward.

The first heartbeat reported a temporary low FPS value during startup, then
stabilized around the headless renderer's normal rate. This is a startup hitch,
not a persistent simulation lock.

## Exact root cause status

No exact engine freeze or gameplay-lock code path was reproduced in Godot 4.7.2
headless. The tested path does not leave the tree paused, does not leave either
fighter match-locked, and does not depend on an unbounded await or visual tween.

The original Windows-only stall therefore remains HUMAN_REQUIRED for final
correlation. The most plausible remaining class is renderer/window-specific
startup behavior or an input/focus condition not observable in headless mode,
but this is explicitly an inference, not a confirmed root cause.

## Systems ruled out by the bounded trace

- Stuck intro tween.
- Stuck flag-wipe tween.
- Stale `get_tree().paused` state.
- `MATCH_LOCKED` fighter state during startup.
- Recursive crowd/mosaic timer behavior.
- Persistent fullscreen transition Control after battle entry.
- Visual-only stage layers preventing physics updates.
- Runtime image loading or pixel-processing loops.

## Fixes applied

- Added opt-in startup and heartbeat diagnostics.
- Added minimal visual launch switches.
- Added explicit intro completion logging.
- Added transition callback and wipe completion logging.
- Kept visual diagnostics disabled by default.
- Preserved the existing gameplay and visual composition behavior.

No gameplay mechanic or tuning was changed.
