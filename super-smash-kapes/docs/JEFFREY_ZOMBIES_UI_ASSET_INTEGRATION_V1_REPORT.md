# JEFFREY_ZOMBIES_UI_ASSET_INTEGRATION_V1 Report

## Final verdict

```text
JEFFREY_ZOMBIES_UI_ASSET_INTEGRATION_V1_READY
```

Presentation-only Zombies menu and loading screen now use the supplied PNG art. Existing Zombies start flow, Smash, Track, and gameplay scripts were not rewritten.

This is a **functional + visual capture** sign-off for the 1920×1080 composition and 1280×720 safe-area check. It is not a live controller-on-TV session.

---

## Scenes modified / added

| Scene | Role |
| --- | --- |
| `scenes/ui/zombies/ZombiesMenu.tscn` | Zombies mode menu root |
| `scenes/ui/zombies/ZombiesLoading.tscn` | Zombies loading root |
| `scenes/debug/CaptureZombiesUiV1.tscn` | Screenshot harness (debug only) |

Runtime still instantiates scripts from `JeffreyApp` (same pattern as Hub / Character Select). The `.tscn` files point at those scripts.

---

## Scripts modified / added

| Script | Change |
| --- | --- |
| `scripts/ui/jeffrey/zombies_menu_screen.gd` | **Added.** Fullscreen covered background, title PNG, five texture buttons, focus cycle, Back/Escape. |
| `scripts/ui/jeffrey/zombies_menu_button.gd` | **Added.** `Button` + art `TextureRect`. Hover and focus share scale (~1.05) and green modulate. No extra label. |
| `scripts/ui/jeffrey/zombies_loading_screen.gd` | **Added.** Covered loading background, title PNG, `CARGANDO...`, flavor line, clipped `loading_bar.png`. |
| `scripts/ui/jeffrey/zombies_ui_assets.gd` | **Added.** Path table for the finalized 2D pack. |
| `scripts/core/jeffrey/jeffrey_app.gd` | Hub → **Zombies menu** when Zombies is chosen. PLAY continues the existing player → character → load flow. CHARACTERS opens existing character select (clamped to mode max players). OPTIONS returns to this menu. BACK returns to Hub. Smash/Track still skip this menu. |
| `scripts/ui/jeffrey/mode_transition_controller.gd` | Zombies branch embeds the new loading screen instead of the old transition panels. Smash/Track layouts unchanged. |
| `scripts/ui/jeffrey/global_ui_assets.gd` | New Zombies UI paths added to `expected_paths()`. |
| `scripts/debug/validate_jeffrey_shell.gd` | Instantiates the new menu/loading scripts in `_check_global_ui`. |
| `scripts/debug/capture_zombies_ui_v1.gd` | **Added.** Capture at 1920×1080 and 1280×720. |

**Not modified:** `zombies_main.gd`, `zombies_player.gd`, `zombies_enemy.gd`, `zombies_map.gd`, Shopping del Sol 3D, Track, Smash combat/controllers.

---

## Assets used

All files kept their supplied names under `res://assets/ui/zombies/`:

| Asset | Use |
| --- | --- |
| `backgrounds/zombies_menu_bg.png` (1672×941, 16:9) | Menu fullscreen cover |
| `backgrounds/zombies_loading_bg.png` (1672×941, 16:9) | Loading fullscreen cover |
| `branding/zombies_title.png` | Upper-left title (no Label recreation) |
| `buttons/btn_play.png` | PLAY / JUGAR |
| `buttons/btn_characters.png` | CHARACTERS / PERSONAJES |
| `buttons/btn_map.png` | MAP / MAPA |
| `buttons/btn_options.png` | OPTIONS / OPCIONES |
| `buttons/btn_back.png` | BACK / VOLVER |
| `loading/loading_bar.png` | Bottom loading bar |

Import: lossless (`compress/mode=0`), mipmaps off, `detect_3d/compress_to=0`. Transparent UI PNGs use `fix_alpha_border=false` so slime/glow edges stay intact. Backgrounds keep default alpha-border fix. No runtime atlas.

Backgrounds are native 16:9, so `STRETCH_KEEP_ASPECT_COVERED` fills 1920×1080 and 1280×720 without non-uniform stretch.

---

## Screenshots produced

Written by `CaptureZombiesUiV1.tscn` (Godot 4.7.2, `gl_compatibility`):

| File | Resolution |
| --- | --- |
| `docs/generated/zombies_ui_v1/zombies_menu_1920x1080.png` | 1920×1080 |
| `docs/generated/zombies_ui_v1/zombies_loading_1920x1080.png` | 1920×1080 |
| `docs/generated/zombies_ui_v1/zombies_menu_1280x720.png` | 1280×720 |
| `docs/generated/zombies_ui_v1/zombies_loading_1280x720.png` | 1280×720 |

Capture token: `JEFFREY_ZOMBIES_UI_ASSET_INTEGRATION_V1_CAPTURE_OK`

---

## Resolution tests

Primary authority **1920×1080**:

- Title sits in the upper-left (LOS JUEGOS DE / JEFFREY / MODO ZOMBIES).
- All five buttons are on the left stack. Default focus is PLAY (`JUGAR`, highlighted asset).
- Shopping del Sol arch and sun logo are readable in the center.
- Zombies walk toward the camera from the mall.
- Crashed EL GALLO stays clear on the right. Buttons do not cover it.
- Loading: `CARGANDO...`, flavor line, and bar sit in the lower center. EL GALLO remains visible.

**1280×720:** title, five buttons, horde, mall, EL GALLO, loading copy, and bar all remain on-screen. No control clipped off the edges.

---

## Controller / keyboard navigation

| Requirement | Result |
| --- | --- |
| First focus defaults to PLAY | Pass (capture shows JUGAR highlighted) |
| Up / Down cycles buttons | Pass (wraps; also W/S like Hub) |
| Accept activates focused button | Pass (`ui_accept` / Enter / gamepad A) |
| Back / Escape returns to Hub | Pass (`pause_match`, `ui_cancel`, Escape) |
| Mouse hover matches focus feedback | Pass (hover grabs focus; same scale/modulate) |
| Input map / multiplayer bindings | Unchanged |

CHARACTERS reuses existing character select. PLAY reuses existing mode-player select → character select → loading → `ZombiesMain`. OPTIONS reuses `JeffreyOptionsScreen` and returns to the Zombies menu.

**MAP:** there is no Zombies map-select screen in the project (only Shopping del Sol). The button stays functional and shows `MAPA ACTUAL: SHOPPING DEL SOL` on the same menu. No new gameplay screen was invented.

---

## Gameplay regression result

| Area | Result |
| --- | --- |
| Zombies AI / combat / player controllers | Untouched |
| Shopping del Sol 3D | Untouched |
| Track mode | Untouched (still Hub → players → characters → Track transition) |
| Smash mode | Untouched (still Hub → players → characters → SOCO transition) |
| Shared gameplay rules | Untouched |

Pytest locks: `tests/test_jeffrey_zombies_ui_asset_integration_v1.py` plus existing shell/transition tests.

```text
18 passed  (zombies UI v1 + global UI transitions v1 + multimode shell)
```

Godot capture loaded the new menu/loading scripts with no parser errors after renaming a `MenuButton` const that shadowed the engine class.

---

## Loading bar

The supplied bar already has a baked green fill. Implementation is a left-to-right clip of that PNG, driven by the existing ~1.2s transition timer (`set_progress` / `present()`). No new loading framework. Smash/Track progress widgets are unchanged.

---

## Visual identity beats

From the 1920×1080 captures:

1. Shopping del Sol is immediately recognizable (arch, sun logo, storefronts).
2. Zombies are walking toward the players from the mall.
3. EL GALLO is crashed and visible on the right, not covered by UI.

Left-side shade is a light gradient only (max alpha 0.28). Background is not globally darkened.

---

## Gates

| # | Check | Result |
| --- | --- | --- |
| 1 | Zombies menu opens without parser/runtime errors | Pass |
| 2 | Background correct at 1920×1080 | Pass |
| 3 | Title in upper-left | Pass |
| 4 | All five buttons appear | Pass |
| 5 | Button focus (keyboard / default PLAY) | Pass |
| 6 | PLAY still enters existing Zombies start flow | Pass (wired) |
| 7 | BACK returns to Hub | Pass (wired) |
| 8 | Zombies approaching, clearly visible | Pass |
| 9 | Crashed EL GALLO visible on the right | Pass |
| 10 | Loading screen displays correctly | Pass |
| 11 | No gameplay behavior changes | Pass |
| 12 | No Smash / Track regressions | Pass |
