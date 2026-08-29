# Los Juegos de Jeffrey — Global UI Finalization + Mode Transitions V1 Report

## Primary Verdict

```text
JEFFREY_GLOBAL_UI_TRANSITIONS_V1_READY
```

Layout, identity, shared character select, Edit Players, Mode Player Selection, and the SOCO / TRACK / ZOMBIES transition system are implemented without changing Smash gameplay. Headless pytest and the Godot validator are green.

This verdict is **functionally ready**. It is **not** a pixel-perfect graphical sign-off.

**Human Visual Review:** `HUMAN_VISUAL_REVIEW_REQUIRED`  
**Smash Human Validation:** `HUMAN_VALIDATION_REQUIRED`

---

## Baseline

Recorded before remaining UI work in this sprint:

| Gate | Result |
| --- | --- |
| Branch | `master` |
| HEAD | `f5b73e2eb39d9d30493d7f44305d0522557d4c8a` — “Initial Super Smash Kapes project” |
| Git | `project.godot` modified; most of `super-smash-kapes/` still untracked |
| Pytest | **85 passed** (`test_m0_combat` 65 + multimode 7 + shell v2 6 + global UI v1 7) |
| Godot validator | **`[JEFFREY_VALIDATE] OK`** (expected corrupt-save `push_error` on CI persist path) |
| Previous product verdict | `JEFFREY_SHELL_V2_READY` / `JEFFREY_GLOBAL_UI_V1_READY` with open human gates |

No pre-existing red pytest/validator gate. Screenshot-driven layout defects were product bugs, not test failures.

---

## Players Today Fixes

Scene: `scripts/ui/jeffrey/players_today_screen.gd`.

- Reusable `GlobalPlayerCard`: `PortraitArea` / `SelectedFrame` / `FocusFrame` / `NamePlate` / `NameLabel` / `CheckIndicator`.
- `NameLabel` is anchored inside `NamePlate` via `GlobalUiStyles` fractions. One line, ellipsis, no per-name screen coordinates.
- Cards show `PlayerProfile.display_name` (uppercased). P1/P2 are never used as identity.
- Right side is `SelectedPlayersPanel`: header `SELECCIONADOS HOY` + count badge in the same row, divider, `VBoxContainer` of `SelectedPlayerRow` (`● NAME`).
- Grid is a `GridContainer` populated from `ProfileManager` / `PlayerProfile`. `NUEVO JUGADOR` is the last cell and opens the existing create-player modal.
- Continue uses the existing logon contract (enabled with ≥1 selected). Disabled state is desaturated via `set_art_enabled`.
- Sample names (`Player`, `Capucarne`, `Max`, `Burbuja`) are not present in UI scripts.

---

## Hub Fixes

Scene: `scripts/ui/jeffrey/hub_screen.gd`.

- `ActivePlayersPanel` + `ActivePlayerRow`: avatar | name | `P#` badge. One row geometry (`GlobalUiStyles` metrics). Slot colors: P1 red, P2 blue, P3 yellow, P4 green, P5 purple, P6 orange, then wrap.
- Mode cards are `ModeSelectCard`. Status badges (`JUGAR` / `EN DESARROLLO` / `PRÓXIMAMENTE`) are children of each card from `GameModeDefinition.status_label()`.
- Options is a `GoldActionButton` (black/gold), bottom-right, no default Godot theme.
- `edit_players_button.png` is a real `GlobalImageButton` and opens **Edit Players**, not Players Today.
- TV remains background art only. No extra TV layer.

---

## Transition Architecture

**Controller:** `ModeTransitionController` (`scripts/ui/jeffrey/mode_transition_controller.gd`)  
Public call: `show_mode_transition(mode_id, context)`.

**Definitions:** `ModeTransitionDefinition` (`configure(mode_id)`). Paths live on the resource object, not scattered through UI scripts.

| mode_id | Visual | Target | Duration min | Status copy |
| --- | --- | --- | --- | --- |
| `smash` | SOCO assets | hosted Smash via `Main.begin_hosted_match` | 1.1s | `ENTRANDO A LA BATALLA...` |
| `racing` | TRACK assets | `HotseatComingSoon.tscn` after transition | 1.2s | `PREPARANDO TRACK...` |
| `zombies` | ZOMBIES assets | `ZombiesComingSoon.tscn` after transition | 1.2s | `PREPARANDO MODO...` |

**Lifecycle:**

```text
Hub
 → Mode Player Selection   (ModeParticipants ⊂ ActiveSession)
 → Shared Character Select (CharacterRegistry; RANDOM resolved here)
 → ModeTransitionController
 → SOCO: Main.begin_hosted_match
   TRACK/ZOMBIES: coming-soon placeholder
```

Duplicate confirm is blocked (`_busy` / `_load_started` on the controller, `_transition_busy` on `JeffreyApp`). Input is swallowed while the transition runs. Back/cancel is disabled once the transition starts.

---

## SOCO

- Assets: `res://assets/ui/global/transitions/soco/*` as specified (background, title, banner, header, fist, progress, controls, FX).
- Tween sequence: fade in → FX → title scale punch → banner/fist → smoothed progress fill (no numeric fake %).
- Minimum presentation ~1.1s (clamped ≥0.8s). Gold/white flash on exit.
- Target: existing Smash host. `begin_hosted_match(setup)` assigns profile ids + fighter ids and calls existing `_start_match_with_setup` → `_start_match`. Playground/combat unchanged.
- Auto-start (`SSK_AUTO_START_BATTLE` / `SSK_AUTO_SELECT_BATTLE`) still skips the shell and uses `begin_character_select()` / timer start as before.

---

## TRACK

- Assets: `res://assets/ui/global/transitions/track/*`.
- Left: title, banner, generation panel shell, status `PREPARANDO TRACK...`.
- Right/bottom: hero stays in the background image; tip panel uses honest copy (“Hotseat se arma en una próxima versión.”).
- API ready, not wired to a generator: `set_generation_stage()`, `set_generation_progress()`, `set_track_preview()`, `set_tip()`.
- Signals declared (`generation_started`, `generation_piece_added`, `generation_validation_started`, `generation_validated`, `generation_finished`) and **not emitted**.
- Does not claim a track was generated. After the transition, the existing coming-soon placeholder opens.

---

## ZOMBIES

- Assets: `res://assets/ui/global/transitions/zombies/*`.
- Status: `PREPARANDO MODO...`. Does not claim Shopping del Sol is loaded.
- Player panel is a decorative shell. Dynamic rows show profile name + `LISTO`. No fake levels / RPG.
- `set_tip(text)` is available. Placeholder tip is neutral.
- After the transition, the existing coming-soon placeholder opens.

---

## Player Identity Integrity

Confirmed and locked by tests:

```text
PlayerProfile  ≠  input slot  ≠  selected character  ≠  ModeParticipants
```

- Cards and lists render `display_name`.
- `P1`…`P6` are slot badges only (Hub / character-order panel).
- Character select stores `{ profile_id, player_slot, character_id }`.
- `MatchSetup.player_N_profile_id` is stats identity; `player_N_fighter_id` is the kape.
- Mode Player Selection reads **only** `ActiveSession`. Confirming participants does not call `apply_logon_roster`.
- Back from Mode Players / coming-soon does not rewrite who is active today.
- Edit Players Save updates `ActiveSession`; Back cancels the toggle set (new profiles created in the modal still persist — no delete).

---

## Persistence

Unchanged contract: versioned JSON, atomic write, corrupt recovery.

Validator isolated save `user://los_juegos_de_jeffrey_ui_v1` still creates and reloads `TEST_UI_PLAYER`. Production `save.json` is not used for that check. CI persist path still exercises corrupt-save quarantine (`push_error` expected).

---

## Tests

**91 passed.**

Breakdown:

| File | Count |
| --- | --- |
| `tests/test_m0_combat.py` | 65 |
| `tests/test_jeffrey_multimode_shell.py` | 7 |
| `tests/test_jeffrey_shell_v2.py` | 6 |
| `tests/test_jeffrey_global_ui_v1.py` | 7 |
| `tests/test_jeffrey_global_ui_transitions_v1.py` | 6 |

No existing tests were deleted. New locks cover selected-count/list containers, Hub roster/slots/status, Edit/Mode/Character data-driven screens, SOCO→Smash / TRACK→Hotseat / ZOMBIES→placeholder mappings, duplicate transition guard, and profile ≠ slot ≠ character.

---

## Godot Validator

```text
[JEFFREY_VALIDATE] OK
```

Command:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --rendering-method gl_compatibility --audio-driver Dummy
res://scenes/debug/ValidateJeffreyShell.tscn
```

Only expected error: CI persist corrupt-save `push_error`. No GDScript parse/compile errors. Boot, Players Today, Hub, Edit Players, Mode Players, Character Select, and ModeTransitionController instantiate.

---

## Visual Review

**Pending.** `HUMAN_VISUAL_REVIEW_REQUIRED`

Headless capture (`CaptureGlobalUi.tscn`) instantiates the screens at 1920×1080 / 1600×900 / 1366×768 but cannot read the dummy viewport (`texture_2d_get` Parameter "t" is null). No review PNGs were produced.

Mandatory owner review at 1920×1080:

1. Players Today — names in nameplates; count in header; selected rows inside the panel; no stray labels; Continue/Back aligned.
2. Hub — names and P# inside rows; status badges on cards; Options gold/black; Edit Players aligned.
3. Edit Players — names in cards; active/inactive obvious; Add Player aligned; Back/Save aligned.
4. Mode Player Selection — real names; summary count/min/max; Track 10-player grid; no floating labels.
5. Character Selection — registry-driven cards; RANDOM aligned; order panel dynamic; Continue/Back aligned.
6. SOCO / TRACK / ZOMBIES transitions — hierarchy, progress not stretched, honest placeholder copy.

Do not treat this sprint as pixel-perfect until that pass is done.

---

## Smash Human Validation

**REQUIRED** (unchanged). Keyboard 2P feel was not re-run in a windowed session. This does not block the UI/navigation work.

---

## Files Created

- `scripts/ui/jeffrey/global_ui_styles.gd`
- `scripts/ui/jeffrey/selected_player_row.gd`
- `scripts/ui/jeffrey/selected_players_panel.gd`
- `scripts/ui/jeffrey/active_player_row.gd`
- `scripts/ui/jeffrey/active_players_panel.gd`
- `scripts/ui/jeffrey/gold_action_button.gd`
- `scripts/ui/jeffrey/mode_select_card.gd`
- `scripts/ui/jeffrey/edit_player_card.gd`
- `scripts/ui/jeffrey/edit_players_screen.gd`
- `scripts/ui/jeffrey/character_card.gd`
- `scripts/ui/jeffrey/character_select_screen.gd`
- `scripts/ui/jeffrey/mode_transition_definition.gd`
- `scripts/ui/jeffrey/mode_transition_controller.gd`
- `tests/test_jeffrey_global_ui_transitions_v1.py`
- `docs/JEFFREY_GLOBAL_UI_TRANSITIONS_V1_REPORT.md`

---

## Files Modified

- `scripts/ui/jeffrey/global_ui_assets.gd`
- `scripts/ui/jeffrey/global_ui_audio.gd`
- `scripts/ui/jeffrey/global_player_card.gd`
- `scripts/ui/jeffrey/players_today_screen.gd`
- `scripts/ui/jeffrey/hub_screen.gd`
- `scripts/ui/jeffrey/mode_player_select_screen.gd`
- `scripts/core/jeffrey/character_registry.gd` (`pick_random_enabled`)
- `scripts/core/jeffrey/jeffrey_app.gd`
- `scripts/core/main.gd` (`begin_hosted_match` only; `_start_match` / playground / combat untouched)
- `scripts/debug/validate_jeffrey_shell.gd`
- `scripts/debug/capture_global_ui.gd`
- `tests/test_jeffrey_shell_v2.py`
- `tests/test_jeffrey_global_ui_v1.py`
- `tests/test_jeffrey_multimode_shell.py`
- `docs/LOS_JUEGOS_DE_JEFFREY_ARCHITECTURE_V1.md` (boot flow, ownership, mode lifecycle)

Smash gameplay authorities were not modified: `fighter.gd`, `fighter_stats.gd`, `m0_playground.gd`, `basic_attack.tres`, `Fighter.tscn`, `p1_*` / `p2_*` input map.

---

## Known Issues

- Graphical 16:9 review cannot be completed in this headless dummy renderer.
- Edit Players has no `save_button.png` / `back_button.png` in `assets/ui/global/edit_players/`. Save/Back use `GoldActionButton` (`GUARDAR` / `VOLVER`). Panel file on disk is `edit_players_info_panel.png`.
- `delete_profile_button.png` and `order_newest_button.png` exist and are unused on purpose (no delete/rename this sprint).
- `mode_players/ChatGPT Image 26 ago 2026, 00_32_38 (8).png` is leftover junk art and is not referenced.
- UI SFX assets still do not exist; hooks are no-ops (`play_soco_impact` / `play_track_whoosh` / `play_zombies_hit`).
- Track/Zombies remain placeholders after an honest transition.
- If a local save already contains profiles literally named `P1`/`P2`, cards will show those names. That is correct profile identity, not slot leakage.

---

## Deferred

- Track car physics
- procedural tracks
- fuel
- Last Dance runtime
- ghosts
- Zombies FPS
- weapons
- waves
- Shopping del Sol playable map
- final gamepad polish
- Track configuration / visible procedural build
- Zombies map/difficulty configuration
- Rename/delete profiles
- Smash 3P/4P (registry max stays 4; adapter still 2)
- Mode-specific character presentation (car / FPS identity)

---

## Recommended Next Action

```text
HOTSEAT_RACING_GREYBOX_V1
```

Do not start it until the owner has done the 16:9 visual pass if pixel alignment of this UI is the immediate priority. Functionally, the shell is ready to host a racing greybox behind the existing TRACK transition + coming-soon handoff.
