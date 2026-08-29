# M0 Architecture

## Runtime shape

`M0Playground` owns the stage instance, the reusable fighter instances, blast-zone checks, stock/respawn flow, and the HUD. `Fighter.tscn` is a single reusable `CharacterBody3D`; Player 1 and Player 2 differ only by player ID, color, and a `FighterStats` resource.

The application shell is `Main.tscn`. It owns the title screen, embedded match instance, pause overlay, result screen, and rematch/menu transitions. The playground remains a standalone scene for development.

## Fighter and state handling

`fighter.gd` uses four intentionally small states: `NORMAL`, `ATTACKING`, `HITSTUN`, and `DEAD`. Grounded/airborne behavior comes from `CharacterBody3D.is_on_floor()`. Dead and hitstun fighters cannot perform normal movement or attacks.

Movement is X/Y gameplay movement. Every physics tick clamps Z to zero. The capsule's body collision is separate from its `Hurtbox` Area3D and `AttackHitbox` Area3D.

Movement now supports a held-input full hop, a released-input short hop, deliberate fast-fall while descending, and reduced steering during attack. These are small extensions of the original movement loop, not a new physics architecture.

## Collision layers

```text
1  Stage       Static platform collision
2  Fighter     CharacterBody3D movement collision
4  Hurtbox     Damageable fighter Area3D
8  Hitbox      Temporary attack Area3D
```

The fighter body collides with stage. Hitboxes query only hurtboxes, and each attack activation keeps a set of victim instance IDs so one activation cannot repeatedly damage one victim.

## Movement

Stats contain walk speed, acceleration/deceleration, air control, jump velocities, gravity, fall speed, weight, and air-jump count. The movement code reads those values rather than embedding fighter-specific constants. Landing restores the configured air jumps.

## Damage, attack, and knockback

`AttackDefinition` in `scripts/combat/attack_definition.gd` and `data/attacks/basic_attack.tres` own the basic attack's timing, damage, angle, knockback, hitstun scale, and attack steering. During active frames the temporary hitbox applies damage once per victim. Damage is numeric and displayed as a rounded percentage. Knockback is a deliberately transparent model:

```text
force = (base_knockback + current_target_damage * growth)
        * (100 / target_weight)
vx = cos(angle) * force
vy = sin(angle) * force
```

This is not an attempt to reproduce proprietary internals. It exists to make the M0 proof obvious: the same hit launches higher-damage and lighter targets farther.

## Stocks, blast zones, and respawn

The playground checks invisible rectangular blast bounds independently of the camera. Crossing any bound calls `ko()` once, subtracts exactly one stock, and either schedules a respawn or eliminates the fighter. Respawn restores the spawn point, velocity, damage, air jumps, and a short invulnerability window. The match announces the remaining player's win at zero stocks.

## HUD and input

The HUD is a small `CanvasLayer` script that displays each player's damage and stocks. Input is defined centrally in `project.godot` using player-prefixed actions (`p1_*`, `p2_*`), leaving a clear path to four players and gamepad bindings without scattering key checks through gameplay.

The current overnight input expansion adds down actions for fast-fall and Escape pause. Gamepad assignment and analog routing remain future work; the keyboard fallback is still authoritative.

## Data-driven direction

`FighterStats` is a custom Resource. Future fighters can provide different resources for movement, weight, attack values, and stocks while continuing to use the same fighter/combat runtime.

The attack definition is intentionally separate from fighter stats so future movesets can be represented as resources without growing conditional branches in `fighter.gd`.

## Fighter visual pipeline (V2)

Gameplay remains on `Fighter.tscn` collision/hurtbox/hitbox. Visual identity is a separate shell:

```text
Fighter
├── BodyCollision / Hurtbox / AttackHitbox   (unchanged)
├── Visual                                   (hidden capsule fallback)
└── VisualRoot → FighterVisual subclass
```

`FighterCatalog` registers `FighterDefinition` entries (id, portrait, visual script, GLB wrapper scene, procedural fallback). `MatchSetup` passes selected IDs from Character Select to `M0Playground`, which sets `fighter.fighter_id` before `_ready` builds the visual.

GLB path (V1): `glb_fighter_visual.gd` loads static mesh, fits to hurtbox height via AABB, applies whole-body motion proxy on `VisualMotionRoot`.

See `docs/FIGHTER_PIPELINE.md`, `docs/FIGHTER_REFERENCE_BREAKDOWN.md`, `docs/REAL_GLB_FIGHTER_INTEGRATION_REPORT.md`.

## Presentation ownership

`m0_camera.gd` frames living fighters and smoothly adjusts distance. `impact_vfx.gd` creates lightweight procedural hit bursts on confirmed attacks. `stage.gd` creates restrained backdrop geometry and the stage scene contains raised one-way platform collision separate from its visual mesh. Presentation does not decide gameplay timing.
## Defensores del Chaco stage art

`scenes/stages/DefensoresDelChacoStage.tscn` is a visual wrapper around the
existing `M0Stage.tscn` gameplay scene. `StageGameplayRoot` owns the original
floor, soft-platform, and collision geometry. `ArtRoot` owns the layered
Sprite3D stadium presentation and can be replaced or extended for future
Paraguayan locations without rewriting gameplay. See
`docs/DEFENSORES_DEL_CHACO_STAGE.md` for layer order, asset mapping, crowd and
scoreboard behavior.
