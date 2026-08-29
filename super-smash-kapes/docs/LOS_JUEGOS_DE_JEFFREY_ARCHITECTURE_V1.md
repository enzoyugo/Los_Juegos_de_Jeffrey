# Los Juegos de Jeffrey — Architecture V1

Product identity: a local-only Paraguay gathering game. Not an esport. Not an online platform.

```text
LOS JUEGOS DE JEFFREY
│
├── CORE          scripts/core/jeffrey/*
├── SHARED        CharacterRegistry + persistence/session
├── CHARACTERS    seeded from FighterCatalog (Tereré, Jaguareté)
├── UI            scripts/ui/jeffrey/*  + existing Smash UI
└── MODES
    ├── SMASH     existing M0Playground (unmoved)
    ├── RACING    Track greybox (TrackMain.tscn)
    └── ZOMBIES   FPS greybox (ZombiesMain.tscn)
```

Smash gameplay folders were **not** mass-moved. That would have been a high-risk path rewrite. The conceptual split is ownership, not a forced `res://modes/smash` relocation.

---

## Boot flow

```text
Godot
 │
 ▼
Autoload JeffreyCore
  persistence load → profiles
  registries
 │
 ▼
JeffreyBoot.tscn  (jeffrey_app.gd)
 │
 ├── BOOT            PRESIONÁ ENTER
 │
 ▼
 ├── PLAYER LOGON     ¿QUIÉNES ESTÁN HOY?
 │
 ▼
 ├── HUB              LOS JUEGOS DE JEFFREY
 │     ├── SOCO (Smash)       → mode players → character select → ModeTransitionController → hosted Smash
 │     ├── TRACK (Hotseat)    → mode players → character select → transition → Track greybox
 │     ├── ZOMBIES            → mode players → character select → transition → Zombies greybox
 │     ├── EDITAR JUGADORES   → Edit Players (save updates ActiveSession)
 │     └── OPCIONES           → stub → back
 │
 ▼
MODE PLAYER SELECT   ModeParticipants ⊂ ActiveSession (does not rewrite who is active today)
 │
 ▼
SHARED CHARACTER SELECT     CharacterRegistry (RANDOM resolved before transition)
 │
 ▼
ModeTransitionController    SOCO / TRACK / ZOMBIES definitions
 │
 ▼
SOCO → Main.tscn hosted_by_shell + begin_hosted_match (skips Kapes select)
TRACK → TrackMain.tscn greybox (coming-soon kept on disk)
ZOMBIES → ZombiesMain.tscn greybox (coming-soon kept on disk)
 │
 ▼
RESULTS / PAUSE      existing Smash screens
 │
 ▼
GAME SELECTION       ActiveSession + profiles survive
```

Dev shortcuts still work from the new boot scene:

- `SSK_AUTO_START_BATTLE=1` — dummy roster, host Main, start match
- `SSK_AUTO_SELECT_BATTLE=1` — dummy roster, host Main, auto character select

`Main.tscn` remains playable if opened directly (legacy Smash shell with title screen).

---

## Managers / ownership

| Object | Type | Lifetime | Owns |
| --- | --- | --- | --- |
| `JeffreyCore` | Autoload Node | entire process | all core services |
| `JeffreyPersistence` | RefCounted | core | JSON save/load |
| `PlayerProfileStore` | RefCounted | core | permanent people |
| `LJActiveSession` | RefCounted | core, reset on boot | who is here today |
| `GameModeRegistry` | RefCounted | core | smash / racing / zombies metadata |
| `CharacterRegistry` | RefCounted | core | shared characters |
| `StatsEventBus` | RefCounted | core | mode → stats events |
| `JeffreyApp` | main scene | entire process | shell screens, smash host child, mode transitions |
| `ModeTransitionController` | Control | mode entry only | SOCO/TRACK/ZOMBIES presentation, then handoff |
| `Main` | Smash session host | while Smash is open | title-or-select, playground, results, pause |
| `M0Playground` | match | one bout | fighters, KO, HUD, stage |

Autoload is the persistence boundary. Changing shell screens never `change_scene_to_file` the whole tree, so session/profiles are not destroyed.

---

## Registries

### GameModeRegistry

Ids: `smash`, `racing`, `zombies`.

| id | display_name | availability | badge | min | max | scene |
| --- | --- | --- | --- | --- | --- | --- |
| smash | Smash Kapes | playable | JUGAR | 2 | 4 | `M0Playground.tscn` |
| racing | Hotseat | development | EN DESARROLLO | 2 | 10 | `TrackMain.tscn` |
| zombies | Zombies | development | EN DESARROLLO | 1 | 2 | `ZombiesMain.tscn` |

UI badges come from `GameModeDefinition.status_label()`, not hardcoded per button. `enabled` is still `false` for Track/Zombies (greybox, not production). Coming-soon scenes remain on disk as fallbacks.

Missing `scene_path` on a **playable** mode shows an error on Game Selection; it does not crash. Development modes now enter their greybox scenes from the shell.

### CharacterRegistry

Single catalog for all modes. V1 seeds from `FighterCatalog`:

- `terere`
- `jaguarete`

Each entry has identity fields plus optional `smash_fighter_id` / racing / zombies resource paths. Racing and zombies slots are empty. Adding a character later is `register_character()` — do not fork per-mode catalogs.

Smash battle still resolves visuals through **FighterCatalog**. The shell catalog must stay in sync (currently seeded from it).

---

## Persistence

Path: `user://los_juegos_de_jeffrey/save.json`

```text
save_version = 1
profiles[]
global_stats
settings
```

Write: temp file → replace, with `.bak` of the previous good file. Corrupt JSON is copied to `save.corrupt.<unix>.json` and replaced with a clean payload.

Profiles persist across boots. **ActiveSession does not.** Every launch starts at logon. That is intentional: “quiénes están hoy” is a gathering question, not a login cookie.

---

## Profile model vs session vs character

```text
LJPlayerProfile     real person (Enzo)
LJActiveSession     people present at this juntada
SharedCharacter     Tereré / Jaguareté
MatchSetup          fighter ids + optional profile ids
Fighter             in-match pawn using p1_* / p2_*
```

Never store stats under the character name. `MatchSetup.player_N_profile_id` is stats identity. `player_N_fighter_id` is the kape.

---

## Mode lifecycle

1. User picks a mode
2. Mode player select clamps to registry min/max. Candidates come only from ActiveSession. Confirmed ModeParticipants are temporary and do **not** rewrite ActiveSession.
3. **Smash V1 adapter:** still requires exactly 2 players because `M0Playground` is 2-slot. Registry max stays 4 so 3P/4P is not designed out.
4. Shared character select (all modes) uses CharacterRegistry. RANDOM is resolved to a concrete `character_id` before the transition. Identity stays `profile_id` + `player_slot` + `character_id`.
5. `ModeTransitionController.show_mode_transition(mode_id, context)` presents the mode entry. SOCO then `Main.begin_hosted_match(setup)` and skips Kapes character select. Auto-start still uses `begin_character_select()`.
6. Racing/Zombies: greybox gameplay (`TrackMain.tscn` / `ZombiesMain.tscn`). Registry keeps `enabled = false` and `availability = development` (badge **EN DESARROLLO**). Coming-soon scenes remain on disk as fallbacks. Generator/FPS are greybox, not production.
7. Match end: results → rematch / change kapes / menu. Change kapes inside Smash still uses the existing Kapes selector.
8. Hosted menu / pause MENÚ returns to **game selection**, not process restart

---

## Character lifecycle (Smash)

Unchanged after select:

```text
MatchSetup fighter ids
  → M0Playground._spawn_fighter
  → FighterCatalog.get_by_id
  → Fighter.tscn + visual bind
```

Shell does not inject a new controller.

---

## Scene transitions

Shell screens swap under `JeffreyBoot/ShellUI`. Smash is a **child instance** of `Main.tscn`, not a root scene change.

Smash internal transitions (flag wipe, results, pause) stay inside `Main.gd`.

---

## Event flow

```text
M0Playground.match_finished
  → Main._on_match_finished
  → JeffreyCore.record_smash_match   (hosted only)
  → StatsEventBus.record
  → profile smash_stats + save
  → existing results screen
```

HUD is not subscribed to the stats bus.

Future racing/zombies events are named on `StatsEventBus` but not emitted yet.

---

## Input

Smash input map is unchanged (`p1_*`, `p2_*`, R, Esc).

New shell UI uses focusable `ShellButton` / `ShellModeCard` / `ShellPlayerCard`. Escape (`pause_match`) is Back on shell screens only. Smash input map is unchanged.

---

## Visual ownership (Shell V2)

```text
GlobalShellTheme + ShellAssets     → Jeffrey shell (neutral placeholder)
SmashShellTheme + KapesVisual      → Smash menus, HUD, Defensores, character select art
```

Swap later by replacing files listed in `scripts/ui/jeffrey/global_ui_assets.gd`:

```text
res://assets/ui/global/boot/*
res://assets/ui/global/players_today/*
res://assets/ui/global/hub/*
res://assets/ui/global/edit_players/*
res://assets/ui/global/mode_players/*
res://assets/ui/global/character_select/*
res://assets/ui/global/transitions/{soco,track,zombies}/*
```

SOCO is the visual label for internal mode `smash`. TRACK maps to `racing`. Zombies stays `zombies`.

Do not point the global shell at `assets/ui/menu/main_menu_bg.png`.

---

## Extension points

- Register extra modes on `GameModeRegistry`
- Register extra characters on `CharacterRegistry` without editing `JeffreyCore`
- Stats events by string id
- `MatchSetup` extra fields for items / timer / teams later — not implemented
- Smash 3–4 players: new playground slots + HUD + input actions; adapter constant `SMASH_ADAPTER_PLAYERS = 2` is the current gate

---

## Dependencies

```text
JeffreyApp → JeffreyCore
JeffreyApp → Main.tscn (Smash adapter)
Main → M0Playground → Fighter → FighterCatalog
CharacterRegistry → FighterCatalog (seed only)
M0Playground does not reference JeffreyCore
fighter.gd does not reference JeffreyCore
```
