# Los Juegos de Jeffrey — Shell V2 Report

## Primary Verdict

```text
JEFFREY_SHELL_V2_READY
```

The global shell is a product hub with three mode cards, a persistent roster, and swap-ready art slots. Smash Kapes is still hosted, not rewritten. Headless spawn/physics and static combat locks remain green.

This verdict does **not** include a human 2P feel pass or a graphical 16:9 review. Those stay open as:

- `HUMAN_VALIDATION_REQUIRED`
- `HUMAN_VISUAL_REVIEW_REQUIRED`

---

## Smash Regression

### Automated

| Check | Result |
| --- | --- |
| `pytest tests/test_m0_combat.py tests/test_jeffrey_multimode_shell.py tests/test_jeffrey_shell_v2.py` | **78 passed** (65 combat + 7 multimode + 6 shell V2) |
| Movement / jump / stocks / attack tres numbers | unchanged |
| Input map `p1_*` / `p2_*` / R / Esc | unchanged |
| `fighter.gd` / `m0_playground.gd` do not reference JeffreyCore | pass |

### Headless

| Check | Result |
| --- | --- |
| `ValidateJeffreyShell.tscn` | **`[JEFFREY_VALIDATE] OK`** |
| Persistence corrupt-save path | expected `push_error`, then clean recovery |
| `SSK_AUTO_START_BATTLE=1` from `JeffreyBoot.tscn` after the mode-card parse fix | fighters spawned, match active, **first physics tick** |

Godot: 4.7.2, `--headless --rendering-method gl_compatibility --audio-driver Dummy`.

### Human status

**`HUMAN_VALIDATION_REQUIRED`**

This environment cannot inject real P1/P2 keyboard gameplay against a visible window. Headless spawn is not a feel pass. Checklist: `docs/SMASH_PRE_MIGRATION_BEHAVIOR_BASELINE.md` and `docs/SMASH_POST_MIGRATION_REGRESSION.md`.

### Host pause (migration bug, not a feel change)

`Main._toggle_pause` previously returned when `screen_root` was null. During an active match `screen_root` is cleared, so Esc did nothing in battle. V2 requires `active_match != null` instead. Overlay still lives on `Main.ui`. **Gameplay numbers were not changed.**

---

## Shell

Boot is unchanged in sequence:

```text
JeffreyBoot → ¿QUIÉNES ESTÁN HOY? → LOS JUEGOS DE JEFFREY
  → Smash / Hotseat / Zombies
  → mode players
  → Smash character select / coming soon
```

### Boot

`scenes/core/JeffreyBoot.tscn` + `jeffrey_app.gd`. Headless logon path (auto-start env cleared) compiled with no SCRIPT ERROR.

### Game selection

Three mode cards are the main event. Roster bar (`HOY` + EDITAR) and OPCIONES sit in the footer. Options is a secondary button, not a fourth mode.

### Cards

`ShellModeCard` reads `GameModeDefinition`: title, description, accent, thumbnail slot, `status_label()`.

| id | availability | badge |
| --- | --- | --- |
| smash | playable | JUGAR |
| racing | development | EN DESARROLLO |
| zombies | locked | PRÓXIMAMENTE |

Missing playable `scene_path` shows an on-screen error; it does not crash.

### Roster

`ShellRosterBar` lists **profile display names** from `LJActiveSession`. EDITAR reopens logon without resetting Godot.

### Edit players

Same card grid as logon (`EDITAR JUGADORES` / `GUARDAR ROSTER`). Cancel returns to game selection. Unchecking a person does not delete the profile.

### Mode player selection

Shared grid, columns scale with count, scroll for up to 10 Hotseat names. Continue is **disabled** until min/max is valid. Smash adapter still clamps to **exactly 2**. Selected Smash cards show `Teclado 1` / `Teclado 2` as controller captions; the card title is the profile name. Errors only appear if confirm is pressed while invalid.

### Placeholders

Coming soon is the same shell frame + disabled mode card + participant names + VOLVER. No racing physics, no FPS, no “DEV PLACEHOLDER”.

---

## Architecture

### Global theme separation

`GlobalShellTheme` owns placeholder colors/type. `ShellBackground` draws a neutral gradient and optionally `res://assets/ui/global/shell_background.png`. It does **not** load `main_menu_bg.png`.

### Smash visual separation

`SmashShellTheme` documents Smash-owned paths (Asunción title art, HUD panels, logo). Character select, Defensores, HUD, and Smash pause/results stay Smash.

### Reusable components

`shell_frame`, `shell_background`, `shell_button` (primary/secondary), `shell_player_card`, `shell_mode_card`, `shell_status_badge`, `shell_roster_bar`, `shell_labels`. `JeffreyShellChrome` is a thin wrapper for leftover callers.

### Mode art slots

Central swap table: `scripts/ui/jeffrey/shell_assets.gd`

```text
res://assets/ui/global/shell_background.png
res://assets/ui/global/logo.png
res://assets/ui/global/mode_cards/smash.png
res://assets/ui/global/mode_cards/hotseat.png
res://assets/ui/global/mode_cards/zombies.png
```

Folders exist with `.gitkeep`. **No final art is checked in.** Screens already tolerate missing textures.

---

## Persistence

JSON `user://los_juegos_de_jeffrey/save.json`, `save_version = 1`. Temp → replace, previous file copied to `.bak`. Corrupt payload quarantined and replaced (validator confirmed).

Reload restores profiles. **`LJActiveSession` is in-memory only** and resets every boot.

Duplicate display names are rejected **on create**, case-insensitive (`normalize_display_name`). Historical load still uses `add()` so old saves are not blocked.

---

## Navigation

| From | Back / cancel | After finish |
| --- | --- | --- |
| Options | game selection | — |
| Edit players (cancel) | game selection | — |
| Mode players | game selection | — |
| Coming soon | **mode players** (one step) | — |
| Smash character select (Esc, hosted) | mode players | — |
| Smash MENÚ / pause MENÚ (hosted) | **game selection** | session + profiles survive |

Escape (`pause_match`) is Back on shell screens. Smash input map is unchanged.

Logs: `[SESSION]`, `[MODE] Selected/Participants`, `[CHARACTER] name -> fighter_id`.

---

## Tests

**78 passed** in 0.60s.

- `tests/test_m0_combat.py` — 65
- `tests/test_jeffrey_multimode_shell.py` — 7
- `tests/test_jeffrey_shell_v2.py` — 6 (theme split, mode badges, duplicate names, min/max continue, back paths, pause host fix)

Expected pytest cache warnings on this machine (`WinError 5` on `.pytest_cache`).

---

## Godot Validation

```text
[JEFFREY_VALIDATE] OK
```

Registries (playable / development / locked + status labels), duplicate-name store, session add/remove, save/load, corrupt recovery, playground 2 fighters / stocks 3 / Tereré–Jaguareté / spawn `(-4, 1.7, 0)` / `(4, 1.7, 0)`.

---

## Visual Review

**`HUMAN_VISUAL_REVIEW_REQUIRED`**

No graphical Godot window was exercised in this environment. Do not treat layout code as a 16:9 look sign-off. Review on Windows: boot, logon, game menu, roster, edit players, Smash/Hotseat/Zombies player grids, placeholders, back paths.

---

## Known Issues

- Human 2P keyboard feel: `HUMAN_VALIDATION_REQUIRED`.
- 16:9 graphical pass: `HUMAN_VISUAL_REVIEW_REQUIRED`.
- Global shell art files are empty slots; procedural gradient is the placeholder.
- Smash V1 adapter is still 2-slot (`SMASH_ADAPTER_PLAYERS = 2`) even though the registry max is 4.
- Character select still uses Smash art and P1/P2 input contract; hosted shell overlays profile names.
- `Godot --import --quit` previously crashed with signal 4 on this machine; compatibility headless play/validate works.
- `shell_mode_card.gd` had a mixed-indent / `Color(Color, alpha)` parse error during this sprint; it blocked `jeffrey_app.gd` preload until fixed. Re-verified after the fix.

---

## Files Created

### Docs

- `docs/SHELL_V1_UI_AUDIT.md`
- `docs/LOS_JUEGOS_DE_JEFFREY_SHELL_V2_REPORT.md`

### Theme / widgets

- `scripts/ui/jeffrey/global_shell_theme.gd`
- `scripts/ui/jeffrey/smash_shell_theme.gd`
- `scripts/ui/jeffrey/shell_assets.gd`
- `scripts/ui/jeffrey/shell_background.gd`
- `scripts/ui/jeffrey/shell_frame.gd`
- `scripts/ui/jeffrey/shell_button.gd`
- `scripts/ui/jeffrey/shell_player_card.gd`
- `scripts/ui/jeffrey/shell_mode_card.gd`
- `scripts/ui/jeffrey/shell_status_badge.gd`
- `scripts/ui/jeffrey/shell_roster_bar.gd`
- `scripts/ui/jeffrey/shell_labels.gd`

### Tests / slots

- `tests/test_jeffrey_shell_v2.py`
- `assets/ui/global/.gitkeep`
- `assets/ui/global/mode_cards/.gitkeep`

---

## Files Modified

- `docs/LOS_JUEGOS_DE_JEFFREY_ARCHITECTURE_V1.md` — availability badges, visual ownership, back paths
- `docs/SMASH_POST_MIGRATION_REGRESSION.md` — human status, pause host note, pytest count
- `scripts/core/jeffrey/jeffrey_core.gd` — session log
- `scripts/core/jeffrey/jeffrey_app.gd` — coming soon → mode players; character-select cancel
- `scripts/core/jeffrey/game_mode_definition.gd` — availability + `status_label()`
- `scripts/core/jeffrey/game_mode_registry.gd` — playable / development / locked
- `scripts/core/jeffrey/player_profile_store.gd` — case-insensitive duplicate create
- `scripts/core/jeffrey/active_session.gd` — `add_player` / `remove_player`
- `scripts/core/main.gd` — pause host fix; participant names; character logs
- `scripts/ui/jeffrey/logon_screen.gd`
- `scripts/ui/jeffrey/game_selection_screen.gd`
- `scripts/ui/jeffrey/mode_player_select_screen.gd`
- `scripts/ui/jeffrey/coming_soon_screen.gd`
- `scripts/ui/jeffrey/options_screen.gd`
- `scripts/ui/jeffrey/jeffrey_shell_chrome.gd` — wrapper over Frame
- `scripts/debug/validate_jeffrey_shell.gd` — V2 registry/duplicate checks
- `tests/test_jeffrey_multimode_shell.py` — as needed for new metadata

Not modified (on purpose): `fighter.gd`, `fighter_stats.gd`, `m0_playground.gd`, `basic_attack.tres`, `Fighter.tscn`, input action bindings.

---

## Deferred

- Final Los Juegos de Jeffrey branding
- Final global shell art (background, logo, mode illustrations)
- Racing art
- Zombies art
- Racing gameplay
- Zombies gameplay
- Gamepad implementation
- Smash 3–4 player matches
- Options contents beyond the stub
- Session restore across boots

---

## Recommended Next Action

```text
HOTSEAT_RACING_GREYBOX_V1
```

Do not start it in this sprint. Use `docs/RACING_MODE_CONTRACT_V1.md` as the rules bible.

Before that greybox, optionally run the human Smash baseline checklist and a 16:9 graphical walk of the shell on fullscreen Windows.
