# Los Juegos de Jeffrey — Game Production Pipeline V1

Engineering agent READY is never canonical. Human approval is the last gate.

## Agent development lifecycle

```
SPEC
  → ISOLATED IMPLEMENTATION
  → STATIC VALIDATION
  → AUTOMATED TEST
  → RUNTIME LAB
  → RENDERED REVIEW
  → HUMAN APPROVAL
  → CANONICAL
```

Never: `AGENT SAYS READY = CANONICAL`.

Lab states: `AUTOMATED_PASS` → `RUNTIME_PASS` → `VISUAL_REVIEW_PENDING` → (human) `CANONICAL`.

## Asset pipeline

```
REFERENCE → SOURCE ASSET → CLEANUP → OPTIMIZATION → MATERIAL NORMALIZATION
  → ENGINE IMPORT → ASSET LAB → HUMAN APPROVAL → CANONICAL
```

Street View / photo references stay on disk under `assets/reference/` with `.gdignore`. They are not runtime textures.

Raw downloads stay under `assets/raw_models/` (`.gdignore`). Runtime copies live under `assets/environments/**/processed/` or `assets/track/**`.

## Character pipeline

```
CONCEPT → MESH → TOPOLOGY → UV → MATERIAL → RIG → WEIGHTS
  → ANIMATION → GODOT LAB → GAMEPLAY TEST → CANONICAL
```

## Environment pipeline

```
REFERENCE SET → REFERENCE BREAKDOWN → MODULAR ASSET KIT
  → BLENDER ASSEMBLY → VISUAL REVIEW → OPTIMIZED EXPORT
  → GODOT VISUAL INTEGRATION → GAMEPLAY COLLISION PROXIES
  → HUMAN REVIEW → CANONICAL
```

Godot owns gameplay collision, nav, triggers. Blender owns the visual world.

Do not rebuild Shopping del Sol from `BoxMesh` in GDScript.

## Authority split

| Role | Owns |
|---|---|
| Engineering agent | code, systems, automation, tests, integration, export tooling |
| Art pipeline | Tripo, downloaded assets, Blender, textures, materials, environment assembly |
| Human | art direction, fun, visual approval, canonical promotion |

## Track firewalls

- TrackMain stays `CONTROLLER_MODE = BASELINE`.
- Generator V4 architecture is frozen unless a proven regression.
- 4WHEEL lives in labs / `TrackTurboV7Showcase`.
- Width candidate (15 m) is lab-measured; kit modules remain 11 m until human width review.

## Zombies firewalls

- Do not replace round / door / nav / wall-buy / MAX AMMO.
- Do not import Street View into Godot.
- Do not load `assets/raw_models` at runtime.

## D3D12 / memory

Treat the first `0x8007000e` / `Can't create buffer` as the symptom. Cascade RID/pipeline errors are downstream.

Repeated rendered scene transitions (not headless-only) are the stability gate. Leftover Godot processes on a 16 GB host remain a human F6 risk.
