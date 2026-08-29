# Los Juegos de Jeffrey — Migration Report V1

## Primary Verdict

```text
MULTIMODE_SHELL_READY
```

Smash gameplay scripts that own movement, combat, stocks, KO, and the Defensores match were not rewritten. The new shell hosts the existing Smash session (`Main.tscn` → `M0Playground.tscn`). Static combat locks and a headless playground/boot check passed.

---

## Changes

- New persistent core: modes, characters, profiles, active session, JSON save, stats event bus
- New boot flow: logon → game selection → mode players → Smash character select / placeholders
- Smash launched through a **hosted adapter** of the existing Main shell (no playground rewrite)
- Racing and Zombies registered as disabled placeholders
- Project name and main scene point at the umbrella game
- One autoload: `JeffreyCore`
- Smash folders were **not** mass-moved

---

## Files created

### Docs

- `docs/LOS_JUEGOS_DE_JEFFREY_PRE_MIGRATION_AUDIT.md`
- `docs/LOS_JUEGOS_DE_JEFFREY_ARCHITECTURE_V1.md`
- `docs/SMASH_PRE_MIGRATION_BEHAVIOR_BASELINE.md`
- `docs/SMASH_POST_MIGRATION_REGRESSION.md`
- `docs/RACING_MODE_CONTRACT_V1.md`
- `docs/ZOMBIES_MODE_CONTRACT_V1.md`
- `docs/PLAYER_PROFILE_AND_SESSION_CONTRACT_V1.md`
- `docs/MIGRATION_REPORT_V1.md`

### Core / UI / scenes / tests

- `scripts/core/jeffrey/jeffrey_core.gd`
- `scripts/core/jeffrey/jeffrey_app.gd`
- `scripts/core/jeffrey/jeffrey_persistence.gd`
- `scripts/core/jeffrey/game_mode_definition.gd`
- `scripts/core/jeffrey/game_mode_registry.gd`
- `scripts/core/jeffrey/shared_character_definition.gd`
- `scripts/core/jeffrey/character_registry.gd`
- `scripts/core/jeffrey/player_profile.gd`
- `scripts/core/jeffrey/player_profile_store.gd`
- `scripts/core/jeffrey/active_session.gd`
- `scripts/core/jeffrey/stats_event_bus.gd`
- `scripts/ui/jeffrey/jeffrey_shell_chrome.gd`
- `scripts/ui/jeffrey/logon_screen.gd`
- `scripts/ui/jeffrey/game_selection_screen.gd`
- `scripts/ui/jeffrey/mode_player_select_screen.gd`
- `scripts/ui/jeffrey/coming_soon_screen.gd`
- `scripts/ui/jeffrey/options_screen.gd`
- `scripts/debug/validate_jeffrey_shell.gd`
- `scenes/core/JeffreyBoot.tscn`
- `scenes/modes/racing/HotseatComingSoon.tscn`
- `scenes/modes/zombies/ZombiesComingSoon.tscn`
- `scenes/debug/ValidateJeffreyShell.tscn`
- `tests/test_jeffrey_multimode_shell.py`

---

## Files moved

None. Smash production paths stay where they were.

---

## Files modified

- `project.godot` — name, main scene, JeffreyCore autoload
- `scripts/core/main.gd` — hosted-shell adapter (`hosted_by_shell`, profile ids, return-to-shell, stats hook)
- `scripts/core/match_setup.gd` — optional `player_1_profile_id` / `player_2_profile_id`
- `tests/test_m0_combat.py` — main_scene assertion updated; Main host wiring still required

Not modified (on purpose): `fighter.gd`, `fighter_stats.gd`, `m0_playground.gd`, `basic_attack.tres`, `Fighter.tscn`, stage, HUD, input action bindings, character select confirm keys.

---

## Smash regression

See `docs/SMASH_POST_MIGRATION_REGRESSION.md`.

- 72 pytest locks green
- Headless playground: 2 fighters, 3 stocks, Tereré/Jaguareté, spawn positions
- `SSK_AUTO_START_BATTLE=1` from JeffreyBoot: match active, first physics tick

---

## Persistence

JSON `user://los_juegos_de_jeffrey/save.json`, `save_version = 1`.

Temp → replace, previous file copied to `.bak`. Corrupt payload quarantined to `save.corrupt.<unix>.json` and replaced with a clean store (validator confirmed this path).

---

## Player session

`LJActiveSession` is in-memory only. It resets every boot. Profiles persist.

Logon: ¿QUIÉNES ESTÁN HOY? — create by display_name, check who is present, continue.

EDITAR JUGADORES reopens the same selector without restarting Godot and without deleting profiles.

---

## Game Mode Registry

| id | name | enabled | min | max |
| --- | --- | --- | --- | --- |
| smash | Smash Kapes | true | 2 | 4 |
| racing | Hotseat | false | 2 | 10 |
| zombies | Zombies | false | 1 | 2 |

Smash V1 launch adapter still requires **exactly 2** participants because `M0Playground` is 2-slot. Registry max 4 is the future contract, not the current match.

---

## Character Registry

Shared catalog seeded from `FighterCatalog`: **Tereré**, **Jaguareté**. Racing/zombies resource slots empty. Smash battle still uses FighterCatalog for visuals.

---

## Racing placeholder

`HotseatComingSoon.tscn` / in-app coming-soon screen. Opens from game selection after player pick. Back returns to game selection. No physics.

---

## Zombies placeholder

`ZombiesComingSoon.tscn` / same coming-soon pattern. No FPS, waves, or Shopping del Sol.

---

## Known issues

- Full human 2P feel pass was not run in this session (headless only). No known gameplay diffs in code.
- Smash character select still labels slots P1/P2 (input contract). Profile names are chosen one screen earlier.
- `Godot --import --quit` crashed with signal 4 on this machine (engine/renderer). Compatibility headless play/validate works.
- Pause-in-battle still goes through pre-existing `Main._toggle_pause` which returns if `screen_root` is null during an active match. Not introduced here; not “fixed” because that would be Smash shell behavior change outside the adapter’s mandate.
- Adding characters still requires registering Smash visuals in `FighterCatalog` until that catalog is data-driven.

---

## Deferred (intentional)

### Racing

Car physics, procedural generator, fuel runtime, Last Dance runtime, ghosts, tracks, racing UI/art.

### Zombies

FPS controller, guns, zombies, waves, Shopping del Sol, split-screen, economy, powers.

### Smash

New attacks, new characters, items, new stages, 3–4 player matches, balance, gamepad bindings.

### Product

Options contents, custom avatars, session restore across boots, results umbrella screen, online anything.

---

## Recommended next action

**HOTSEAT RACING GREYBOX V1**

Do not start it in this sprint. Use `docs/RACING_MODE_CONTRACT_V1.md` as the rules bible when that greybox begins.

Before that greybox, optionally run the human Smash baseline checklist once on fullscreen Windows so feel is signed off by a person, not only by headless spawn checks.
