# Los Juegos de Jeffrey — UI Surgical Fixes + Track Game Feel V1

## Primary Verdict

```text
JEFFREY_UI_TRACK_GAME_FEEL_V1_PARTIAL
```

UI names/lists are now anchored to **visible art**, not letterboxed control bounds. Character cards are larger. Track handling no longer uses the soap-bar lateral model. Smash was not rewritten. Human visual review and a human drive pass are still required, so this is not READY.

Track handling status:

```text
TRACK_GAME_FEEL_V1_IMPLEMENTED
HUMAN_DRIVE_REVIEW_REQUIRED
```

---

## Baseline Gates

| Gate | Result |
| --- | --- |
| Branch | `master` |
| HEAD | `f5b73e2eb39d9d30493d7f44305d0522557d4c8a` |
| Pytest | **98 passed** |
| Godot validator | **`[JEFFREY_VALIDATE] OK`** |
| Smash rewrite | none |
| Pre-existing failures | none (expected CI corrupt-save `push_error` only) |

---

## UI

Root cause: textures used `KEEP_ASPECT_CENTERED` while labels used the full control. Edit/Mode cards are **1983×793 banners**, but they were using **portrait** nameplate fractions, so names sat in transparent padding.

Fix: `TextureFitHost` (panels) + `AspectRatioContainer` (cards). Labels live on `ArtRoot` / `art_space`.

### Players Today

- Portrait cards keep 1122×1402 ratio. NameLabel is a child of NamePlate at the painted plate (`y ≈ 0.888–0.948`).
- Selected panel content is inside the displayed panel texture. Count is in the header. Rows use a VBox + scroll. No duplicate name list.

### Hub

- Active rows overlay the six painted slots. Names sit in NameSafeZone.
- Painted P1–P6 badges are not redrawn (SlotBadge exists, hidden).
- Mode status still comes from `status_label()` on each ModeSelectCard.
- Options remains a black/gold `GoldActionButton`.

### Edit Players

- Banner cards. Name is in the metal nameplate, not below the art.
- Active/inactive is the secondary bar (`HOY ACTIVO / INACTIVO`).
- Info panel is data-driven inside the fitted panel: name, created, active today, sessions. No delete/rename.

### Mode Player Selection

- Candidates are banner `GlobalPlayerCard`s from ActiveSession only.
- Limits still come from GameModeRegistry (Smash adapter still clamps to 2).
- Summary uses TextureFitHost. Baked CONTINUAR/CANCELAR on the panel art are covered; real Back/Continue stay on the screen chrome.

### Character Select

- Cards `430×538` (was `300×420`). Portrait uses most of the card; name sits in the hex plate.
- Centered HBox of registry characters + RANDOM at the same scale.
- Order panel is TextureFitHost + `CharacterOrderRow` from real participants. No “TU NOMBRE AQUÍ”.

---

## Track Game Feel

Details: `docs/TRACK_GAME_FEEL_BASELINE_V1.md`, `docs/TRACK_GAME_FEEL_V1_REPORT.md`.

### Baseline

Yaw rotated the mesh; velocity stayed a puck. `LATERAL_GRIP = 9.8` took ~1.8s to kill 18 m/s of side speed.

### Physics

Still `CharacterBody3D`. Forward/lateral split every frame. Helpers in `track_handling.gd`.

### Grip

Exponential lateral damp, `LATERAL_GRIP = 16.5`, plus velocity-align. Airborne = no grip.

### Steering

Smoothed digital input. Speed-sensitive authority (2.55 → 0.88). Release-steer yaw damping.

### Acceleration

58 with high-speed scale 0.38. Max 38.

### Braking

72 while forward speed > 1.6. Reverse only after that. No instant invert.

### Drift

Brake + steer + speed > 10 lowers grip. Not a dedicated button. Unverified.

### Recovery

Extra lateral damp after collisions. No teleports.

### Camera

Tighter follow, yaw lag toward the car, FOV 68–78. Look-ahead on heading.

### Config

`TRACK_HANDLING_BASELINE` kept as `BASELINE_*`. Live set is `TRACK_HANDLING_V1`. Fuel still `expected_time * 2.75` (provisional).

### Physics Lab

`res://scenes/debug/TrackPhysicsLab.tscn` — fixed course, WASD, F3 HUD. No generator.

Generator / checkpoints / turns / fuel / ghosts were not expanded.

---

## Last Dance Verification

Validator logic:

- fuel 0 at turn start → `last_dance`
- beat a living best → `survived`
- miss → `eliminated`
- restart-from-start / surrender → `eliminated`

Matches the product contract. Not playtested in a window.

## Ghost Verification

Recorder/player files unchanged. Samples still 20 Hz transforms. Not re-driven after handling change.

## Zombies Changes

None. Higher-priority UI + Track work consumed the sprint. Greybox path preserved.

---

## Tests

**Before:** 98 passed  
**After:** **103 passed**

+5 in `tests/test_ui_track_game_feel_v1.py`. Existing Track test updated to lock baseline + V1 (not deleted).

## Validator

```text
[JEFFREY_VALIDATE] OK
```

Includes handling math, Last Dance contract, TrackPhysicsLab exists, Smash playground spawn/stocks, TrackGenerator seed 42. Expected only: CI persist corrupt-save `push_error`.

Headless boot `--quit-after 4`: exit 0.

## Smash Integrity

Not modified: `fighter.gd`, `fighter_stats.gd`, `m0_playground.gd`, `basic_attack.tres`, `p1_*` / `p2_*` input map. Hosted Smash path unchanged.

---

## Human Gates

- `HUMAN_VISUAL_REVIEW_REQUIRED` — no 1920×1080 capture (dummy renderer).
- `HUMAN_DRIVE_REVIEW_REQUIRED` — handling implemented, not driven.
- `HUMAN_VALIDATION_REQUIRED` — 2P Smash feel still unverified.

---

## Known Issues

- UI is structurally fixed; pixel alignment of Hub rows vs painted art still needs a windowed pass.
- Mode summary art still contains baked “NOMBRE JUGADOR” / 0/4; runtime covers buttons and overlays real data, but a visual pass should confirm coverage.
- Track feel is a model change, not a claim that it “feels great”.
- Wheels are cylinders.
- Physics lab is boxes.
- No Zombies polish this sprint.

---

## Files Created

- `scripts/ui/jeffrey/texture_fit_host.gd`
- `scripts/track/track_handling.gd`
- `scripts/track/track_physics_lab.gd`
- `scripts/track/track_debug_hud.gd`
- `scenes/debug/TrackPhysicsLab.tscn`
- `tests/test_ui_track_game_feel_v1.py`
- `docs/TRACK_GAME_FEEL_BASELINE_V1.md`
- `docs/TRACK_GAME_FEEL_V1_REPORT.md`
- `docs/JEFFREY_UI_TRACK_GAME_FEEL_V1_REPORT.md`

## Files Modified

- `scripts/ui/jeffrey/global_ui_layout.gd`, `global_ui_styles.gd`, `global_player_card.gd`, `selected_players_panel.gd`, `selected_player_row.gd`, `active_player_row.gd`, `active_players_panel.gd`, `edit_player_card.gd`, `edit_players_screen.gd`, `mode_player_select_screen.gd`, `character_card.gd`, `character_select_screen.gd`, `character_order_row.gd`, `players_today_screen.gd`
- `scripts/track/track_config.gd`, `track_car_controller.gd`, `track_camera.gd`
- `scripts/debug/validate_jeffrey_shell.gd`
- `tests/test_track_greybox_v1.py`

---

## Recommended Next Action

**TRACK_HUMAN_TUNING_PASS** in this order:

1. Windowed 1920×1080 visual pass of Players Today / Hub / Edit / Mode / Character Select.
2. Drive `TrackPhysicsLab.tscn`. Tune only `TrackConfig` V1 constants.
3. Then, and only then, **PROCEDURAL_GENERATOR_V2**.

Do not expand generator content before a human drive pass.
