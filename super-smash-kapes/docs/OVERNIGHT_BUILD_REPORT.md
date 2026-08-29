# SUPER SMASH KAPES — Overnight Build Report

## Starting baseline

The sprint started from the human-validated M0 playground: two local keyboard players, reusable 3D capsule fighters, movement/jump/double jump, one real hitbox attack, damage-scaled and weight-scaled knockback, hitstun, blast-zone KOs, stocks, respawn, winner flow, HUD, and attack steering. The baseline had 7 passing lightweight tests.

Repository root: `E:\SuperSmashKapes`  
Godot project root: `E:\SuperSmashKapes\super-smash-kapes`

## Major systems added

### Front end and match flow

`Main.tscn` is now the configured project main scene. `main.gd` creates an original high-contrast title screen, starts the existing two-player battle, pauses/resumes it, shows a result screen with match-local statistics, and supports rematch or return to the main menu. The M0 playground remains a separate scene and can still be run directly.

### Data-driven combat

`AttackDefinition` and `data/attacks/basic_attack.tres` own the existing attack's startup, active, recovery, damage, angle, knockback, hitstun scaling, and attack steering. The values are unchanged from the validated M0 model. `fighter.gd` falls back to a generated definition when instantiated without a resource, preserving standalone scene use.

### Movement

Fighter stats now include short-hop velocity and fast-fall speed. Holding jump produces the full jump; releasing during ascent cuts the jump to the short-hop ceiling. Down input only fast-falls once descending. Hitstun remains protected from player steering and fast-fall input.

### Stage and camera

The stage retains its main platform and now has two raised one-way platforms. Procedural background towers and a warm rim provide depth without external assets. The camera follows the active fighters and increases distance smoothly as they separate.

### Presentation

Fighters have small procedural idle/movement/attack/hit squash and lean responses. Confirmed hits spawn lightweight radial impact bursts with color and size based on knockback. These effects are isolated from collision and gameplay timing.

## What was deliberately not added

No shields, grabs, dodges, ledges, aerial moveset, specials, items, CPU, online play, controller assignment, audio system, hitlag, four-player combat, character select, stage select, or real character content were added. These remain future milestones; they are not hidden behind fake menu buttons.

## Automated checks

The lightweight test suite passes with 9 tests. `git diff --check` passes. Static path checks cover the new main scene, attack resource, scripts, and stage dependencies. Godot 4.7.2 headless editor scanning completed with no project parser errors, and a 3-second headless project run completed without project GDScript/runtime errors. The process emitted only environment-level certificate-store and user-log-write warnings.

## Human-required morning playtest

The highest-risk checks are the new main-scene boot, title-button/input launch, result/rematch transition, pause overlay, short/full hop, fast-fall, raised-platform landing, camera framing, and impact VFX. Existing M0 combat must also be replayed to confirm its manually validated behavior remains unchanged.

## Recommended next milestone

Run the morning playtest first. If the vertical slice is stable, M1 should focus on a controlled defensive layer (shield or dodge), controller routing, and a small explicit moveset expansion only after deciding the desired couch controls.
