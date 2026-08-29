# SSK_M0_PLAYGROUND

## Run

Open `super-smash-kapes/project.godot` in Godot 4.x and press Play. The project main scene is now `scenes/core/Main.tscn`, which launches the title screen. Choose **PLAY LOCAL BATTLE** or press `F`/`Space`. The original gameplay scene remains directly available at `scenes/core/M0Playground.tscn` for development.

## Controls

```text
Player 1: A / D move, W or Space jump, S fast-fall, F attack
Player 2: Left / Right move, Up jump, Down fast-fall, N or Numpad 0 attack
R: restart the match
Escape: pause/resume during battle
Backtick: toggle a lightweight debug log flag
```

## Implemented

Two colored capsule fighters share one reusable scene and script. They walk, short-hop/full-hop, double jump, fast-fall, stay on the X/Y gameplay plane, perform one data-driven startup/active/recovery attack, apply real hitbox-to-hurtbox damage, launch targets with damage and weight scaling, and enter hitstun. A wide neutral platform, raised one-way platforms, invisible blast zones, three stocks, delayed respawn, reset damage, invulnerability, winner messaging, impact VFX, reactive camera, and a functional HUD are included.

## Deliberately not implemented

M0/overnight still has no real characters, character/stage select, online/rollback, items, specials, shields, grabs, ledges, AI, music system, controller assignment UI, or advanced platform-fighter mechanics. Those are future milestones.

## Known limitations

The camera is now lightly dynamic, but there is no hitlag yet. Controller bindings are not included in this keyboard-stable pass, platform drop-through is not wired even though raised platforms are one-way upward, and the debug toggle currently logs its state rather than drawing custom gizmos. Placeholder animation is procedural and intentionally minimal.

## Acceptance criteria

The critical proof is repeatable hits: Player 1 hits Player 2, the displayed percentage rises, equal attacks launch Player 2 farther as damage increases, and a blast-zone crossing consumes one stock and respawns at 0%. A match ends with a winner message after three KOs.
