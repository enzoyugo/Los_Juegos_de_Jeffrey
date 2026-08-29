# Los Juegos de Jeffrey — Global UI V1 Report

## Primary Verdict

```text
JEFFREY_GLOBAL_UI_V1_READY
```

Boot, Players Today, and Hub now compose the final global art as separate layers (background, logo, buttons, cards, panels, dynamic text). Smash is still hosted and untouched. Headless spawn/physics and the pytest suite stay green.

This verdict does **not** include a graphical 16:9 look sign-off.

**Human Visual Review:** `HUMAN_VISUAL_REVIEW_REQUIRED`

---

## Boot

Implemented as `scripts/ui/jeffrey/boot_screen.gd`.

- Cover-centered `boot_background.png` (room, TV, ceiling car, pool table stay in frame).
- `boot_ambience_overlay.png` above the photo, under chrome; light alpha pulse.
- Logo PNG top-left, keep-aspect. No Label recreation of the mark.
- `boot_press_enter.png` is a real `GlobalImageButton`. Enter (and the CTA) advance.
- `boot_controls_strip.png` is visual-only in the footer.
- Logo fade/scale 0.98→1.0 (~0.4s). CTA alpha pulse. Background does not move.
- Esc quits (`SALIR` on the strip).
- `SSK_AUTO_START_BATTLE=1` still skips the shell and hosts Smash.

---

## Players Today

Implemented as `scripts/ui/jeffrey/players_today_screen.gd`.

- Room photo + dim overlay; title PNG; card grid; selected panel; Continue/Back; footer strip.
- Cards use `player_card_selected.png` / `player_card_unselected.png` as frames. Display names are Labels. Portraits only if `PlayerProfile.portrait_path` is set.
- Focus (white pulse) is distinct from selected (gold frame + check in the art).
- Arrows / WASD move focus. Space toggles. Enter continues. Click toggles.
- `new_player_card.png` opens a modal (not a new full screen): NUEVO JUGADOR / Nombre / CREAR / CANCELAR.
- Right panel frame is `selected_players_panel.png`; count and names come from the current selection. Never hardcoded `4`.
- Continue disabled with desaturated modulate until at least one player is selected (existing contract).
- Same screen for boot context and Hub **EDITAR JUGADORES**.

---

## Hub

Implemented as `scripts/ui/jeffrey/hub_screen.gd`.

- Cover-centered `hub_background.png` (center crop). TV stays in the photo; no extra TV overlay.
- Logo PNG top-left.
- Left stack: SOCO / TRACK / ZOMBIES as image buttons. Up/Down + Enter. Click works. Focus scale/brightness 1.02 / 1.1.
- Small dynamic badges from `status_label()` (JUGAR / EN DESARROLLO / PRÓXIMAMENTE). Not burned into the mode art.
- `active_players_panel.png` is the frame. Rows are profile name + session slot `P1…` with shell slot colors. Names are not in the texture.
- `edit_players_button.png` reopens Players Today in edit context.
- `hub_controls_strip.png` footer. OPCIONES is a small secondary control (no asset provided).

---

## Dynamic Data

- Profiles and ActiveSession are unchanged in role: people persist, session is in-memory.
- Create-player still uses `PlayerProfileStore.create` (duplicate names rejected).
- Optional `portrait_path` on `LJPlayerProfile` (empty in old saves).
- Hub P1/P2 labels are session order, not profile identity and not Smash HUD colors.

Isolated validator save `user://los_juegos_de_jeffrey_ui_v1` created `TEST_UI_PLAYER` and reloaded it. Production `save.json` is not used for that check.

---

## Asset Mapping

| Role | Path |
| --- | --- |
| Boot background | `res://assets/ui/global/boot/boot_background.png` |
| Boot logo | `res://assets/ui/global/boot/los_juegos_de_jeffrey_logo.png` |
| Boot CTA | `res://assets/ui/global/boot/boot_press_enter.png` |
| Boot controls | `res://assets/ui/global/boot/boot_controls_strip.png` |
| Boot ambience | `res://assets/ui/global/boot/boot_ambience_overlay.png` |
| Players background | `res://assets/ui/global/players_today/players_today_background.png` |
| Players title | `res://assets/ui/global/players_today/players_today_title.png` |
| Card selected | `res://assets/ui/global/players_today/player_card_selected.png` |
| Card unselected | `res://assets/ui/global/players_today/player_card_unselected.png` |
| New player | `res://assets/ui/global/players_today/new_player_card.png` |
| Selected panel | `res://assets/ui/global/players_today/selected_players_panel.png` |
| Continue | `res://assets/ui/global/players_today/continue_button.png` |
| Back | `res://assets/ui/global/players_today/back_button.png` |
| Players controls | `res://assets/ui/global/players_today/players_today_controls_strip.png` |
| Hub background | `res://assets/ui/global/hub/hub_background.png` |
| Hub logo | `res://assets/ui/global/hub/los_juegos_de_jeffrey_logo.png` |
| SOCO | `res://assets/ui/global/hub/mode_soco.png` |
| TRACK | `res://assets/ui/global/hub/mode_track.png` |
| ZOMBIES | `res://assets/ui/global/hub/mode_zombies.png` |
| Edit players | `res://assets/ui/global/hub/edit_players_button.png` |
| Active panel | `res://assets/ui/global/hub/active_players_panel.png` |
| Hub controls | `res://assets/ui/global/hub/hub_controls_strip.png` |

Loader: `scripts/ui/jeffrey/global_ui_assets.gd`. Missing files log `MISSING_FINAL_ASSET` once and show a neutral panel + label.

SOCO → internal `smash`. TRACK → `racing`. ZOMBIES → `zombies`.

---

## Navigation

```text
Boot  --Enter-->  Players Today (BOOT)  --Continue-->  Hub
Hub   --EDITAR-->  Players Today (EDIT) --Continue/Back--> Hub
Hub   --SOCO-->    mode players → character select → Smash
Hub   --TRACK/ZOMBIES--> mode players → coming soon → mode players
Hosted Smash MENÚ → Hub
Character select Esc → mode players
Boot Esc → quit
```

Profiles persist. ActiveSession is rewritten on Continue from Players Today and resets on process restart.

Crossfade between shell screens: ~0.28s.

---

## Resolution Validation

Design space is 1920×1080 with fractional anchors (`GlobalUiLayout.apply_frac`). Project viewport remains 1920×1080, `canvas_items` stretch.

| Size | Code layout | Graphical capture |
| --- | --- | --- |
| 1920×1080 | fractional anchors | not captured (headless dummy renderer) |
| 1600×900 | same 16:9 scale | not captured |
| 1366×768 | same 16:9 scale | not captured |

`CaptureGlobalUi.tscn` ran at those sizes; `viewport.get_texture()` is null under `--headless` dummy storage. Do not treat this as a look pass.

---

## Tests

**85 passed** in 0.99s.

- `tests/test_m0_combat.py` — 65
- `tests/test_jeffrey_multimode_shell.py` — 7
- `tests/test_jeffrey_shell_v2.py` — 6
- `tests/test_jeffrey_global_ui_v1.py` — 7

---

## Godot Validator

```text
[JEFFREY_VALIDATE] OK
```

Includes registries, duplicate names, isolated persist, Smash playground (2 fighters, stocks 3, Tereré/Jaguareté, spawn baseline), global asset presence, `TEST_UI_PLAYER` isolated save, and instantiate of Boot / Players Today / Hub.

`SSK_AUTO_START_BATTLE=1` from JeffreyBoot: fighters spawned, match active, first physics tick.

Boot path without auto-start: no SCRIPT ERROR.

---

## Human Visual Review

**REQUIRED**

No graphical Godot window in this environment. Headless screenshot path failed (`texture_2d_get` dummy). Compare Boot / Players Today / Hub against the art at 1920×1080, then 1600×900 and 1366×768.

---

## Missing Assets

None of the listed final PNGs are missing on disk.

Godot `.import` sidecars were not committed: `--import --quit` has crashed on this machine before, and hand-written dest hashes broke `ResourceLoader.load`. UI textures use lossless `Image.load` → `ImageTexture` (no mipmaps, alpha preserved, linear filter on the control). Opening the project in the editor will generate `.import` files; set those to lossless / no mipmaps if Godot’s default differs.

---

## Known Issues

- Human visual review still required.
- Mode player select, coming soon, and Options still use Shell V2 chrome (out of this sprint’s three screens).
- Hub `active_players_panel.png` bakes six empty P-slots; live names overlay that area. More than six players scroll in the overlay.
- No UI SFX files exist; `GlobalUiAudio` is a no-op hook.
- Fallback font is Godot default with outline/shadow, not a packaged display face.
- Headless cannot prove pool table / ceiling car / TV framing.

---

## Files Created

- `scripts/ui/jeffrey/global_ui_assets.gd`
- `scripts/ui/jeffrey/global_ui_layout.gd`
- `scripts/ui/jeffrey/global_ui_audio.gd`
- `scripts/ui/jeffrey/global_screen_frame.gd`
- `scripts/ui/jeffrey/global_image_button.gd`
- `scripts/ui/jeffrey/global_player_card.gd`
- `scripts/ui/jeffrey/create_player_modal.gd`
- `scripts/ui/jeffrey/boot_screen.gd`
- `scripts/ui/jeffrey/players_today_screen.gd`
- `scripts/ui/jeffrey/hub_screen.gd`
- `scenes/ui/jeffrey/GlobalScreenFrame.tscn`
- `scripts/debug/capture_global_ui.gd`
- `scenes/debug/CaptureGlobalUi.tscn`
- `tests/test_jeffrey_global_ui_v1.py`
- `docs/LOS_JUEGOS_DE_JEFFREY_GLOBAL_UI_V1_REPORT.md`

---

## Files Modified

- `scripts/core/jeffrey/jeffrey_app.gd` — Boot → Players Today → Hub; crossfade; auto-start preserved
- `scripts/core/jeffrey/player_profile.gd` — optional `portrait_path`
- `scripts/ui/jeffrey/global_shell_theme.gd` — gold + P1–P10 slot colors
- `scripts/debug/validate_jeffrey_shell.gd` — global UI + isolated TEST_UI_PLAYER
- `tests/test_jeffrey_shell_v2.py` — hub screen locks
- `docs/LOS_JUEGOS_DE_JEFFREY_ARCHITECTURE_V1.md` — boot + SOCO mapping

Not modified: `fighter.gd`, `fighter_stats.gd`, `m0_playground.gd`, `basic_attack.tres`, `Fighter.tscn`, input map.

---

## Deferred

- Final player portraits
- Controller support polish
- Racing implementation
- Zombies implementation
- Additional global screens (mode players, options, coming soon restyle)
- UI sound assets
- Editor `.import` pass for the new PNGs

## Recommended next action

Run the three screens fullscreen on Windows at 1920×1080 and tick the visual checklist in the sprint prompt, then `HOTSEAT_RACING_GREYBOX_V1` when ready to start Track.
