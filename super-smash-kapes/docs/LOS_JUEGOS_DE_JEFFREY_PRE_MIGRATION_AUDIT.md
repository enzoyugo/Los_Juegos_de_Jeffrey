# Los Juegos de Jeffrey — Pre-Migration Audit

**Date:** 2026-08-25  
**Auditor:** architecture migration pass (read-only of Smash gameplay)  
**Git repo:** `E:/SuperSmashKapes`  
**Godot project:** `E:/SuperSmashKapes/super-smash-kapes`

This document records the **actual** repository state before any multimode shell work. Existing docs (`ARCHITECTURE.md`, `UI_FLOW.md`, `M0_PLAYGROUND.md`) were treated as hints only and verified against source.

---

## Git snapshot (before migration edits)

```text
branch:  master
HEAD:    f5b73e2eb39d9d30493d7f44305d0522557d4c8a
message: Initial Super Smash Kapes project
```

Working tree at audit time:

- `super-smash-kapes/project.godot` — already modified (unstaged)
- Almost the entire Godot tree is **untracked** (`assets/`, `data/`, `docs/`, `fighters/`, `scenes/`, `scripts/`, `tests/`, `tools/`, README, CHANGELOG)
- No destructive git operations will be used
- No force-push, no hard reset, no history rewrite

---

## Godot version

| Source | Value |
| --- | --- |
| `project.godot` `config/features` | `4.7`, `Forward Plus` |
| Local editor used for this machine | Godot **4.7.2** (`E:\Godot_v4.7.2-stable_win64_console.exe`) |
| Physics | Jolt (`3d/physics_engine="Jolt Physics"`) |
| Windows renderer | D3D12 (`rendering_device/driver.windows="d3d12"`) |
| Viewport | 1920×1080, fullscreen (`window/size/mode=3`), `canvas_items` + `expand` |
| Blender import | **disabled** |

Headless/lab convention already in this repo: `--rendering-method gl_compatibility --audio-driver Dummy`.

---

## Real project structure

```text
super-smash-kapes/
├── project.godot
├── icon.svg
├── assets/          # fighters, UI, stage art, portraits
├── data/attacks/    # basic_attack.tres (only combat .tres)
├── docs/            # reports + architecture notes
├── fighters/        # terere / jaguarete visual scripts
├── scenes/
│   ├── core/        # Main.tscn, M0Playground.tscn
│   ├── debug/       # animation / rig labs (isolated)
│   ├── fighters/    # Fighter.tscn
│   └── stages/      # DefensoresDelChacoStage.tscn, M0Stage.tscn
├── scripts/
│   ├── combat/
│   ├── core/        # main, playground, match_setup, camera
│   ├── debug/       # labs — do not inherit into production Smash
│   ├── fighters/
│   ├── stages/
│   ├── ui/
│   └── vfx/
├── tests/           # mostly Python static / animation checks
└── tools/
```

Conceptual target (`core/ shared/ characters/ modes/ ui/ data/`) is **not** the current layout. Smash gameplay lives under `scripts/core`, `scripts/fighters`, `scenes/core`. Mass-moving those folders would be high-risk because of `ext_resource`, `preload()`, and `load()` paths.

---

## Boot / initial scene

- **Main scene:** `res://scenes/core/Main.tscn`
- **Script:** `res://scripts/core/main.gd`
- **Window title / project name:** `Super Smash Kapes`
- **Autoloads:** **none** (`project.godot` has no `[autoload]` section)

Boot flow today:

```text
Main.tscn
  → KapesMenuScreen (title)
  → KapesCharacterSelectScreen
  → M0Playground.tscn (embedded child, not a scene change)
  → KapesResultsScreen
  → rematch / change kapes / menu
```

`M0Playground.tscn` remains a standalone playable scene for development.

Dev env hooks on `Main._ready()`:

- `SSK_AUTO_START_BATTLE=1` — skip menus, start match after 0.5s
- `SSK_AUTO_SELECT_BATTLE=1` — open character select and auto-confirm default roster

---

## Autoloads

**None.** All Smash state is scene-local:

- `Main` owns `match_setup`, `active_match`, UI screens
- `M0Playground` owns fighters, KO/respawn, HUD
- `FighterCatalog` is a static `RefCounted` class, not an autoload

---

## Menu scenes

There are **no packed menu `.tscn` files**. Menus are constructed in GDScript and parented under `Main/UI`:

| Screen | Script | Role |
| --- | --- | --- |
| Title | `scripts/ui/kapes_menu_screen.gd` | “Local Battle” art button; F / Space to play |
| Character select | `scripts/ui/kapes_character_select.gd` | ELIGÍ TU KAPE — P1/P2 confirm |
| Results | `scripts/ui/kapes_results_screen.gd` | rematch / change kapes / menu |
| Pause | `scripts/ui/kapes_pause_overlay.gd` | continuar / reiniciar / menú |
| Transition | `scripts/ui/flag_wipe.gd` | tricolor wipe |

Assets: `assets/ui/menu/main_menu_bg.png`, `smash_kapes_logo.png`, `local_battle_panel.png`.

---

## Gameplay scenes

| Scene | Path | Role |
| --- | --- | --- |
| Playground | `scenes/core/M0Playground.tscn` | **authoritative Smash match** |
| Fighter | `scenes/fighters/Fighter.tscn` | reusable CharacterBody3D |
| Stage | `scenes/stages/DefensoresDelChacoStage.tscn` | current production stage |
| Legacy greybox | `scenes/stages/M0Stage.tscn` | not used by current playground |

Playground children: `WorldEnvironment`, `DirectionalLight3D`, `Camera3D` (`m0_camera.gd`), `FighterManager`, `HUD` (`m0_hud.gd`).

---

## Smash scripts (production)

| Script | Path |
| --- | --- |
| App shell | `scripts/core/main.gd` |
| Match | `scripts/core/m0_playground.gd` |
| Camera | `scripts/core/m0_camera.gd` |
| MatchSetup | `scripts/core/match_setup.gd` |
| Fighter | `scripts/fighters/fighter.gd` |
| Stats | `scripts/fighters/fighter_stats.gd` |
| Catalog | `scripts/fighters/fighter_catalog.gd` |
| Definition | `scripts/fighters/fighter_definition.gd` |
| Attack resource | `scripts/combat/attack_definition.gd` |
| Stage | `scripts/stages/defensores_stage.gd` |
| HUD | `scripts/ui/m0_hud.gd`, `kapes_player_hud.gd` |

`scripts/debug/**` and `scenes/debug/**` are isolated labs. They must not become production Smash dependencies.

---

## Fighters

Catalog is **hardcoded** in `FighterCatalog._ensure_loaded()`:

| id | display_name | pipeline | production GLB |
| --- | --- | --- | --- |
| `terere` | TERERÉ | ACTORCORE_V4 | `assets/fighters/processed/terere/terere_game_ready_v4.glb` |
| `jaguarete` | JAGUARETÉ | ACTORCORE_V4 | `assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb` |

Default `MatchSetup`: P1 = terere, P2 = jaguarete.

Visual scripts live under `fighters/terere/` and `fighters/jaguarete/`. Size/HUD presentation is visual-only (`FighterDefinition` comments: not gameplay collider).

There is **no shared CharacterRegistry** yet. Smash identity == fighter id.

---

## Stage

Production stage: **Defensores del Chaco** (`DefensoresDelChacoStage.tscn` + `defensores_stage.gd`).

Blast zone is **not** on the stage script. It is hardcoded in `M0Playground._outside_blast_zone()`:

```text
x < -19.0 or x > 19.0 or y < -10.0 or y > 18.0
```

---

## HUD

- `m0_hud.gd` — two `KapesPlayerHUD` cards (P1/P2), intro message `¡DALE!`, winner callout `%s GANA`
- Plates: `assets/ui/hud/hud_p1.png`, `hud_p2.png`
- Shows fighter display name, damage %, stocks
- F3 toggles performance overlay; HUD `_process` only runs when that debug flag is on

---

## Input actions (`project.godot`)

Keyboard-only. **No gamepad `InputEventJoypad*` bindings.**

### P1

| Action | Keys |
| --- | --- |
| `p1_left` | A |
| `p1_right` | D |
| `p1_jump` | Space, W |
| `p1_down` | S |
| `p1_attack` | F |

### P2

| Action | Keys |
| --- | --- |
| `p2_left` | Left arrow |
| `p2_right` | Right arrow |
| `p2_jump` | Up arrow |
| `p2_down` | Down arrow |
| `p2_attack` | N, Numpad 0 |

### Match / debug

| Action | Key |
| --- | --- |
| `restart_match` | R |
| `pause_match` | Escape |
| `toggle_debug` | backtick |
| `benchmark_*` | 1–6 (animation labs) |

Fighter input is **not** hardcoded WASD inside `fighter.gd`. It uses `p%d_%s` % `[player_id, name]`. Character select **also** has physical keycode fallbacks (`KEY_A`, `KEY_F`, etc.).

There are **no** `p3_*` / `p4_*` actions.

---

## Save system

**None.** No `user://` save, no `ConfigFile` game save, no profile store.

`user://` appears only in debug/lab contexts if at all; Smash does not persist players or stats.

---

## Shared assets

- `assets/ui/` — menu, HUD, portraits, victory
- `assets/fighters/processed/` — production GLBs
- `assets/stages/defensores_del_chaco/` — stage art
- `data/attacks/basic_attack.tres` — only gameplay `.tres`

---

## Resources `.tres`

Combat:

- `data/attacks/basic_attack.tres` → `AttackDefinition`

Fighter stats are **code defaults** on `FighterStats` (`scripts/fighters/fighter_stats.gd`), not per-character `.tres`. `M0Playground._make_stats()` creates a fresh `FighterStats` and only sets `fighter_name`. **Tereré and Jaguareté share the same movement/combat numbers.**

---

## Scene / script dependencies (Smash production)

```text
Main.tscn
  └─ main.gd
       ├─ preload M0Playground.tscn
       ├─ load kapes_menu_screen.gd
       ├─ load kapes_character_select.gd
       ├─ load kapes_results_screen.gd
       ├─ preload kapes_pause_overlay.gd
       ├─ preload match_setup.gd
       └─ preload fighter_catalog.gd

M0Playground.tscn
  └─ m0_playground.gd
       ├─ preload Fighter.tscn
       ├─ preload DefensoresDelChacoStage.tscn
       ├─ preload basic_attack.tres
       ├─ preload match_setup.gd
       └─ preload fighter_catalog.gd

Fighter.tscn
  └─ fighter.gd
       ├─ FighterStats
       ├─ AttackDefinition
       └─ FighterCatalog.get_by_id(fighter_id) → visual
```

Critical path references: almost all `res://scripts/...` and `res://scenes/...` via `preload` / `load` / `ext_resource`. Moving folders without rewriting those strings will break boot.

---

## Smash Behavior Authorities

Do **not** modify these for the migration except path/DI wrappers that preserve observable behavior.

| Concern | Authority | Notes |
| --- | --- | --- |
| Movement | `fighter.gd` `_process_movement` + `FighterStats` | walk 10, accel 75, decel 95, air control 42 |
| Jump / short hop / double jump | `fighter.gd` `_try_jump` + stats | jump 16, short hop 11, double 15, max_air_jumps 1 |
| Fast fall | `fighter.gd` + `pN_down` | fast_fall 42 while descending |
| Attack timing | `data/attacks/basic_attack.tres` + `fighter.gd` `_process_attack` | startup 0.10 / active 0.12 / recovery 0.24 |
| Attack steering | same tres + movement during attack | ground 0.55 / air 0.70 |
| Hitbox | `Fighter.tscn` `AttackHitbox` + `_process_attack` | layer 8, mask 4 |
| Hurtbox | `Fighter.tscn` `Hurtbox` | layer 4, mask 8 |
| Damage | `receive_attack` + tres `damage = 8` | |
| Knockback | `receive_attack` formula | `(base + damage * growth) * (100/weight)` |
| Hitstun | `receive_attack` | `clamp(force * 0.018, 0.12, 0.55)` |
| Stocks | `FighterStats.starting_stocks = 3` applied in `Fighter._ready` | |
| KO | `fighter.ko()` + `M0Playground._handle_ko` + blast check | |
| Respawn | `M0Playground` timer `1.15s` + `fighter.respawn()` | i-frames 1.5s, damage reset 0 |
| HUD | `m0_hud.gd` / `kapes_player_hud.gd` | |
| Match state | `M0Playground.match_over` + `Fighter.lock_match` | first 0-stock KO ends match |
| Stage presentation | `defensores_stage.gd` | KO FX only; not physics |
| Roster IDs | `MatchSetup` + `FighterCatalog` | 2 slots only |

---

## P1 / P2 current state

| | P1 | P2 |
| --- | --- | --- |
| Spawn | `(-4.0, 1.7, 0.0)` | `(4.0, 1.7, 0.0)` |
| Color | `KapesVisual.P1_COLOR` | `KapesVisual.P2_COLOR` |
| Default fighter | terere | jaguarete |
| Input actions | `p1_*` | `p2_*` |
| Stocks | 3 | 3 |
| Gameplay stats | identical `FighterStats` defaults | identical |

Architecture is **2-player only**. HUD, playground `match_stats`, results, and character select are all hardcoded to slots 1 and 2. Registry metadata may advertise max 4 later; **runtime Smash cannot launch 3–4 without new gameplay work** (out of scope).

---

## Controllers / gamepads

**Not bound.** Input map contains only keyboard events. `fighter.gd` would accept joypad if actions were mapped to `p1_*` / `p2_*`, but nothing does that today.

Character select extra hardcodes physical keys, so a future pad-only player would still need that screen updated.

---

## Tests / automation

`tests/` is mostly:

- Python static assertions (`test_m0_combat.py` locks formulas, input map, `main_scene`, Main restart wiring)
- Animation / rig lab tests

There is **no** Godot runtime test that plays a Smash match and asserts knockback feel. Regression after migration must use:

1. The Python locks (must not change combat numbers)
2. A documented human/headless smoke checklist
3. Optional headless instantiate of `M0Playground` (spawn/stocks only)

`test_frontend_and_restart_flow_are_wired` currently **requires** `run/main_scene="res://scenes/core/Main.tscn"`. Changing boot **must** update that test or CI will fail.

---

## Warnings / known issues (pre-migration)

- HUD warns and skips plate art if `hud_p1.png` / `hud_p2.png` fail to load; scripts still compile
- ActorCore visual failure falls back to capsule / fallback visual with `push_error`
- Freeze was previously a real bug; remaining audit is opt-in via `SSK_FREEZE_AUDIT=1`
- `scripts/debug/**` labs must stay isolated
- Git: almost all content untracked — easy to lose if someone force-cleans; do not delete assets
- No profile/session model — player identity is currently “P1/P2” plus fighter name on HUD

No blocking parse errors were observed in the production Smash scripts during this audit. Runtime smash play was not re-run as a full human match during the audit itself (baseline checklist is the post-audit verification tool).

---

## Potential breakage points during migration

1. Changing `run/main_scene` without a host that can still embed `M0Playground` the same way `Main` does
2. Moving `scenes/core`, `scripts/fighters`, `Fighter.tscn`, or `basic_attack.tres`
3. Editing `fighter.gd` / `FighterStats` / attack tres “while we are here”
4. Replacing `p1_*` / `p2_*` with a new input API
5. Making `Main` skip title in a way that breaks `SSK_AUTO_START_BATTLE`
6. Adding autoloads that `_process` every frame or pause the tree
7. Character select rewrite that changes confirm keys
8. HUD showing profile names instead of fighter names (observable Smash UI change — avoid)
9. Instantiating a second physics world / changing Jolt settings
10. `change_scene_to_file` that destroys session if we later add autoloads incorrectly — prefer one persistent root

---

## Migration constraint (from this audit)

**Do not mass-move Smash folders.** Add a new shell beside the working Smash host:

- Keep `M0Playground.tscn`, `fighter.gd`, stats, hitboxes, stage, HUD, input map
- Keep `Main.gd` as the Smash session host (title + match + results + pause)
- Add a new boot scene that owns logon / mode select / session, then **hosts** `Main.tscn` for Smash

That is the lowest-risk architecture-only path.
