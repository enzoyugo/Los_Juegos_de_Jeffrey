# Smash Kapes — Pre-Migration Behavior Baseline

Use this checklist **after** the multimode shell lands. If any item fails, the migration is **not done**.

Source of truth: production code as of the 2026-08-25 audit (`f5b73e2` + working tree). This is architecture-only: **gameplay numbers must remain identical**.

---

## Play scene

| Item | Expected |
| --- | --- |
| Gameplay scene | `res://scenes/core/M0Playground.tscn` |
| Host (menus/results/pause) | `res://scenes/core/Main.tscn` / `scripts/core/main.gd` |
| Stage | Defensores del Chaco |
| Camera | `scripts/core/m0_camera.gd` on playground `Camera3D` |
| Intro callout | `¡DALE!` |

How to enter battle after migration: shell → Smash Kapes → pick 2 session players → existing character select → same playground instance path as `Main._enter_match()`.

Legacy: `Main.tscn` still playable directly; `M0Playground.tscn` still playable directly for labs.

---

## Controls (must not change)

### Player 1

- Left: **A** (`p1_left`)
- Right: **D** (`p1_right`)
- Jump: **Space** or **W** (`p1_jump`)
- Fast fall: **S** (`p1_down`)
- Attack: **F** (`p1_attack`)

### Player 2

- Left: **Left arrow** (`p2_left`)
- Right: **Right arrow** (`p2_right`)
- Jump: **Up arrow** (`p2_jump`)
- Fast fall: **Down arrow** (`p2_down`)
- Attack: **N** or **Numpad 0** (`p2_attack`)

### Match

- Pause: **Escape**
- Restart: **R** (emits `restart_requested` when playground is parented under Main; reloads scene only if playground is current scene root)

Character select (Smash roster screen):

- P1: A/D + F/Space
- P2: ←/→ + N

---

## Spawn / stocks / identities

| Slot | Spawn | Default fighter | Stocks |
| --- | --- | --- | --- |
| P1 | `(-4.0, 1.7, 0.0)` | Tereré | 3 |
| P2 | `(4.0, 1.7, 0.0)` | Jaguareté | 3 |

Z is clamped to `0` every physics tick (`PLANE_Z`).

HUD names are **fighter display names** (TERERÉ / JAGUARETÉ), not real-person profile names.

---

## Movement / jump (FighterStats defaults)

Both fighters use the same stats object defaults:

```text
walk_speed            = 10.0
ground_acceleration   = 75.0
ground_deceleration   = 95.0
air_control           = 42.0
jump_velocity         = 16.0
short_hop_velocity    = 11.0
double_jump_velocity  = 15.0
gravity               = 42.0
max_fall_speed        = 28.0
fast_fall_speed       = 42.0
weight                = 100.0
max_air_jumps         = 1
starting_stocks       = 3
```

Feel checks:

1. Grounded walk reaches the same speed as before
2. Releasing jump early still short-hops
3. One air jump, then no more until landing
4. Holding down while falling still fast-falls
5. During attack, steering is reduced (ground 0.55 / air 0.70) but gravity still applies

---

## Attack

Resource: `res://data/attacks/basic_attack.tres`

```text
startup_seconds     = 0.10
active_seconds      = 0.12
recovery_seconds    = 0.24
damage              = 8.0
base_knockback      = 7.0
knockback_growth    = 0.105
angle_degrees       = 42.0
ground_steering     = 0.55
air_steering        = 0.70
hitstun_scale       = 0.018
```

Knockback formula (unchanged):

```text
force = (base_knockback + damage_percent * growth) * (100 / weight)
vx = cos(angle) * force * facing
vy = sin(angle) * force
hitstun = clamp(force * hitstun_scale, 0.12, 0.55)
```

Invulnerable fighters (respawn i-frames) take no hit (`receive_attack` returns 0).

---

## KO / respawn / match end

1. Leaving blast zone (`x` outside ±19, `y < -10` or `y > 18`) calls `fighter.ko()`
2. Stock decrements by 1
3. If stocks remain: respawn after **1.15s** at original spawn, damage **0%**, i-frames **1.5s**
4. If stocks hit 0: fighter `eliminate()`, match locks, opponent wins, HUD `%s GANA`, results screen
5. First final KO ends the match (2-player only)

---

## Restart

- In-match **R** → Main `_restart_match()` (free playground, start again with same `MatchSetup`)
- Pause → REINICIAR → same
- Results → REMATCH → same `MatchSetup`
- Results → CAMBIAR KAPES → character select (Smash host)
- Results / Pause → MENÚ → title today; after migration, **game selection shell** when hosted

---

## HUD

- Two plates, P1 left / P2 right
- Damage as integer percent
- Stock pips decrease on KO
- Intro `¡DALE!`
- F3 performance overlay remains opt-in

---

## Automated locks (must stay green)

Run from `super-smash-kapes/`:

```text
python -m pytest tests/test_m0_combat.py -q
```

These tests lock formulas, input map keys, KO signal ownership, attack locomotion, and Main restart functions. They are **not** a full playtest.

After boot scene change, `test_frontend_and_restart_flow_are_wired` must still prove:

- Smash host `main.gd` still wires `restart_requested`, `_on_match_finished`, `_show_results`
- `Main.tscn` still exists
- New boot scene is intentional and documented

---

## Human / runtime smoke (required)

Play a real 2P bout (keyboard) after migration:

1. P1 moves left/right, jumps, short-hops, double-jumps, fast-falls, attacks
2. P2 does the same on arrow cluster + N
3. Hit confirms: +8% per connect, visible knockback, hitstun
4. Blast KO reduces stocks; respawn at spawn with 0% and blink i-frames
5. Last stock KO goes to results; rematch feels identical
6. R restart mid-match restores 3 stocks
7. Pause Escape still works; HUD still shows fighter names

If **any** of these feel different, verdict is `MULTIMODE_MIGRATION_BLOCKED`.
