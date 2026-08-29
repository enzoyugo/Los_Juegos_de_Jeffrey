# Los Juegos de Jeffrey — Overnight UI + Track + Zombies Report

## Primary Verdict

```text
JEFFREY_OVERNIGHT_MAX_PROGRESS_PARTIAL
```

Smash gameplay was not rewritten. Global UI layout was tightened (especially character cards and panel text). Track is a **real drivable greybox** with a seeded segment assembler, hotseat turns, fuel budget, Last Dance, and ghost replay. Zombies is a **real 1P FPS greybox** with hitscan pistol, chasing enemies, and waves. Neither mode is production-complete. Human visual/feel gates remain open.

---

## Baseline

| Gate | Result |
| --- | --- |
| Branch | `master` |
| HEAD | `f5b73e2eb39d9d30493d7f44305d0522557d4c8a` |
| Git | `project.godot` modified; most of `super-smash-kapes/` still untracked |
| Pytest | **91 passed** |
| Godot validator | **`[JEFFREY_VALIDATE] OK`** (expected CI corrupt-save `push_error`) |

No pre-existing red suite. Open from prior sprint: `HUMAN_VISUAL_REVIEW_REQUIRED`, `HUMAN_VALIDATION_REQUIRED`.

**Doc conflict (recorded, existing contract preferred):** the overnight prompt asked for `res://scripts/ui/global/jeffrey_*.gd`. Runtime already lives in `res://scripts/ui/jeffrey/` and tests lock those paths. Scripts were **not** mass-moved. Packed scene wrappers were added at `res://scenes/ui/global/`. Track/Zombies use the requested `scripts/track`, `scenes/track`, `scripts/zombies`, `scenes/zombies` roots.

---

## Global UI Fixes

### Players Today

- Nameplate fractions tightened (`0.10–0.90` × `0.80–0.96`) in `GlobalUiStyles` so names sit in the card plate, not as floaters.
- `SelectedPlayersPanel` margins increased; count stays in the header row; names are `SelectedPlayerRow` inside a `VBoxContainer`.
- Identity remains `PlayerProfile.display_name`. P1/P2 are not used as names.

### Hub

- Active player row height/padding increased (`64px` rows, more name/slot breathing room).
- Mode status still comes from `status_label()` as a child of each `ModeSelectCard`.
- TRACK and ZOMBIES badges are now **EN DESARROLLO** (greybox), Smash remains **JUGAR**.
- Options `GoldActionButton` uses a darker black fill, thicker bottom gold edge, and drop shadow.

### Edit Players

- Cards gained a portrait safe zone + `NameLabel` in the nameplate.
- Right info panel is data-driven: name, created date, active-today, sessions. Updates on focus/toggle.
- No rename. No delete. Helper copy still says profiles are not erased.
- Back/Save remain gold/black (no `save_button.png` / `back_button.png` in the edit_players folder).

### Mode Player Selection

- Summary list uses `SelectedPlayerRow` (no duplicate free-floating name labels).
- Limits still come from `GameModeRegistry` (Smash adapter still clamps to 2).
- Track grid still scales toward 10. Candidates still come only from `ActiveSession`.

### Character Select

- Cards are much larger (`300×420`, larger portrait + nameplate fractions).
- Layout is a centered `HBoxContainer` of registry-driven cards plus RANDOM (not a tiny 3-column icon grid).
- Right panel uses `CharacterOrderRow`: slot badge, profile name, arrow, character. Current turn highlighted.
- Continue still requires a resolved character per participant. RANDOM is resolved before transition.

### Transitions

- SOCO unchanged: ~1.1s punch, then hosted Smash via `begin_hosted_match`.
- TRACK copy stays `PREPARANDO TRACK...` (no fake generator stages). After the transition the **real greybox** loads.
- ZOMBIES copy stays `PREPARANDO MODO...` (no fake levels / loaded Shopping del Sol). After the transition the **real FPS greybox** loads.

---

## Track Progress

### Architecture

Dedicated stack under `scripts/track/` + `scenes/track/TrackMain.tscn`:

`track_main` → `track_race` + car + camera + HUD + turn manager + ghost recorder/player.

Shell: Hub → mode players → character select → TRACK transition → `TrackMain.setup(participants)`.

Registry: `enabled = false`, `availability = development`, `scene_path = TrackMain.tscn`. Coming-soon scene kept on disk as `RACING_PLACEHOLDER`.

### Car Controller

Arcade `CharacterBody3D` (`track_car_controller.gd`). Same stats for every character.

Tuning (documented in `TrackConfig`):

| Constant | Value |
| --- | --- |
| ACCEL | 48 |
| MAX_SPEED | 36 |
| BRAKE | 55 |
| REVERSE_ACCEL / REVERSE_MAX | 22 / 10 |
| STEER_LOW / STEER_HIGH | 2.15 / 0.72 |
| LATERAL_GRIP | 9.8 |
| GRAVITY | 32 |

W accelerate, S brake/reverse, A/D steer. Feel is Trackmania-adjacent greybox, not a sim. **Not human-driven overnight** — handling still needs a windowed pass.

### Camera

Single third-person chase (`track_camera.gd`): distance 8.6, height 3.15, look-ahead 11, exponential follow 11. No camera selector.

### Track Generation

Real seeded assembler (`TrackGenerator`): deterministic `RandomNumberGenerator.seed`, piece library (straight, gentle/medium/hairpin L/R, chicane, hill, jump, finish approach, finish). Length `corta/media/larga` (8/14/22 pieces). Difficulty `tranqui/picante/demente` changes pool + time multiplier.

Output includes `piece_sequence`, `estimated_time`, `validation_result = pass`, checkpoint marks.

Visuals are **greybox boxes**, not authored Trackmania pieces. No loops. No fake “generator finished” unless `generate()` actually ran (it does, then you press Generar y correr).

Setup overlay lets the player pick length + difficulty before generate. Default seed is unix time.

### Checkpoints / Finish

`TrackCheckpoint` Area3D gates. Must hit in order. Finish ignored if index skipped. **C** resets to last reached checkpoint (timer and fuel continue). **Backspace** restarts from START (timer 0, fuel unchanged); during Last Dance that is rendición.

### Turn Manager

Generic over N participants (architecture supports 10; overnight not playtested at 10). Tracks alive/eliminated, current driver, round, best times.

### Fuel System

Fuel is **seconds of remaining turn budget**, not liters.

```text
initial_fuel = max(expected_time * 2.75, 8.0)
```

Consumes 1:1 while driving. Does not consume during Last Dance. Does not refill on survive.

### Last Dance

When a turn starts with fuel ≤ 0: LAST DANCE HUD, one definitive run. Beat any living player's best time → survive at fuel 0. Fail or restart-from-start → eliminated. Consecutive clutches allowed. No gifted fuel.

### Ghosts

Records 20 Hz transforms of completed attempts. Stores per-profile best sample set. Replays transparent ghost cars for **other living** players at turn start. No collision. Not stress-tested with 10 ghosts.

### HUD

Driver name + character, timer, fuel/Last Dance, checkpoint progress, rank list, prompts, setup overlay, pause (Seguir / Hub / Siguiente turno).

### Shell Integration

Wired. `JeffreyApp._host_track`. Esc from setup returns to Hub. Pause during race. Smash auto-start path unchanged.

### Known Limitations

- Greybox geometry only; jumps/hills are crude boxes.
- No visible clack-clack build animation after internal generate.
- No OTRA reseeds from a flyover screen (re-enter setup via Hub).
- Handling/camera not human-tuned in a window.
- Close-finish events not presented.
- Cosmetic character-in-car not implemented (identity is HUD-only).
- 10-player session untested.

---

## Zombies Progress

### Architecture

`scripts/zombies/` + `scenes/zombies/ZombiesMain.tscn`.

Registry: `enabled = false`, `availability = development` (badge **EN DESARROLLO**, was PRÓXIMAMENTE), `scene_path = ZombiesMain.tscn`. Coming-soon kept as `ZOMBIES_PLACEHOLDER`.

### FPS Controller

`ZombiesPlayer`: walk, sprint (Shift), jump, mouse look, capsule collision. Mouse captured in play, released on pause/death/exit.

### Weapon

Hitscan pistol. Fire gap 0.22s, damage 34. **Infinite ammo, no reload** (HUD says so). No second weapon.

### Zombie Enemy

Capsule mover toward the player. Melee in range (12 dmg / 0.9s). 80 HP. No NavigationAgent (direct chase). No animation.

### Waves

`ZombiesWaves.next_count() = min(4 + wave*2, 16)`. All dead → next wave. Player death → lose overlay. No downed/revive. No 2P.

### HUD

HP, wave, zombies remaining, infinite-ammo note, crosshair, pause.

### Shell Integration

Wired. `JeffreyApp._host_zombies`. Esc pause / Hub. Does **not** claim Shopping del Sol loaded.

### Known Limitations

- Flat 60×60 box arena, not a map.
- 1P only. Split-screen / revive deferred.
- No navmesh, doors, points, or buyable guns.
- Headless validator does not instantiate the FPS scene (mouse capture). Wave logic is checked.

---

## Player Identity Integrity

Still separate:

| Concept | Owner |
| --- | --- |
| Person | `PlayerProfile.display_name` |
| Slot | `player_slot` / P# badges |
| Character | `character_id` from CharacterRegistry |
| Who is here today | `ActiveSession` |
| Who plays this mode | `ModeParticipants` (`pending_participants`) |

Track/Zombies receive `{profile_id, player_slot, character_id}`. Character does not change car stats. Zombies HUD is participant-agnostic beyond the shared FPS pawn in this greybox.

---

## Persistence

No save-format migration. `SAVE_VERSION` still 1. Validator isolated `TEST_UI_PLAYER` still round-trips. Corrupt CI save still quarantined.

---

## Tests

**Before:** 91 passed  
**After:** **98 passed**

| File | Count |
| --- | --- |
| `test_m0_combat.py` | 65 |
| `test_jeffrey_multimode_shell.py` | 7 |
| `test_jeffrey_shell_v2.py` | 6 |
| `test_jeffrey_global_ui_v1.py` | 7 |
| `test_jeffrey_global_ui_transitions_v1.py` | 6 |
| `test_track_greybox_v1.py` | 4 |
| `test_zombies_greybox_v1.py` | 3 |

No tests deleted.

---

## Godot Validator

```text
[JEFFREY_VALIDATE] OK
```

Includes TrackGenerator seed determinism (seed 42 twice) and ZombiesWaves first-wave count. Expected only: CI persist corrupt-save `push_error`. No GDScript parse errors in the final run.

---

## Human Validation Still Required

- `HUMAN_VISUAL_REVIEW_REQUIRED` — dummy renderer still cannot capture 16:9 PNGs (`texture_2d_get` null).
- `HUMAN_VALIDATION_REQUIRED` — 2P Smash feel not re-run.
- Track handling/camera and Zombies mouse-look also need a windowed session.

---

## Files Created

**UI:** `character_order_row.gd`; `scenes/ui/global/Jeffrey{Boot,PlayersToday,Hub,EditPlayers,ModePlayerSelection,CharacterSelect,ModeTransition}.tscn`

**Track:** `scripts/track/track_{config,car_controller,camera,generator,checkpoint,turn_manager,fuel_system,last_dance,ghost_recorder,ghost_player,hud,race,results,main}.gd`; `scenes/track/TrackMain.tscn`; `tests/test_track_greybox_v1.py`

**Zombies:** `scripts/zombies/zombies_{config,player,weapon,enemy,waves,hud,main}.gd`; `scenes/zombies/ZombiesMain.tscn`; `tests/test_zombies_greybox_v1.py`

**Report:** `docs/JEFFREY_OVERNIGHT_UI_TRACK_ZOMBIES_REPORT.md`

---

## Files Modified

- `scripts/ui/jeffrey/global_ui_styles.gd`, `character_card.gd`, `character_select_screen.gd`, `selected_players_panel.gd`, `active_players_panel.gd`, `gold_action_button.gd`, `edit_player_card.gd`, `edit_players_screen.gd`, `mode_player_select_screen.gd`
- `scripts/core/jeffrey/jeffrey_app.gd`, `game_mode_registry.gd`
- `scripts/debug/validate_jeffrey_shell.gd`
- `tests/test_jeffrey_global_ui_transitions_v1.py`, `tests/test_jeffrey_shell_v2.py` (via registry comment)
- `docs/LOS_JUEGOS_DE_JEFFREY_ARCHITECTURE_V1.md`
- `docs/RACING_MODE_CONTRACT_V1.md` (status banner: greybox now exists; full contract still incomplete)

Smash authorities untouched: `fighter.gd`, `fighter_stats.gd`, `m0_playground.gd`, `basic_attack.tres`, `p1_*`/`p2_*` input map. `main.gd` not changed this overnight (hosted match adapter already existed).

---

## Deferred

- Pixel-perfect 16:9 visual pass
- Smash 2P human feel
- Track authored art / clack build / OTRA flyover
- Track character cockpit cosmetics
- Track 10-player playtest
- Fuel pacing balance
- Ghost cost at high player counts
- Zombies map (Shopping del Sol), navmesh, 2P, downed/revive, ammo/reload, buyables
- Moving `scripts/ui/jeffrey` → `scripts/ui/global` (would break existing test path locks)

---

## Recommended Next Action

Windowed pass in this order:

1. Visual review of Players Today / Hub / Character Select at 1920×1080.
2. Drive Track greybox; tune `TrackConfig` accel/steer/camera.
3. Play Zombies wave 1–3; decide whether to keep EN DESARROLLO badges.
4. Then either Track art/generator expansion or Zombies navmesh + 2P.
