# Overnight Presentation Report — Master Pass V1

**Status:** SSK_OVERNIGHT_PRESENTATION_V1_READY_FOR_HUMAN_PLAYTEST  
**Date:** 2026-08-22  
**Godot:** 4.7.2 stable  
**Gameplay:** UNCHANGED (tuning protected)

---

## Executive Summary

This pass rebuilt player-facing presentation from first principles while preserving all validated gameplay. The largest wins:

1. **Responsive main menu** — replaced fixed 1920×1080 pixel collage with safe-area, aspect-aware layout.
2. **UI design system** — centralized tokens (`KapesVisual`) and layout utilities (`KapesUILayout`).
3. **HUD polish** — viewport-relative sizing, stock pips, damage tier colors, intro on dedicated layer.
4. **Pause/results screens** — dedicated responsive components with consistent motion language.
5. **Defensores platform depth** — underside/rim sprites for main deck integration without collision changes.

Combined-mode input/focus fixes from prior session were preserved.

---

## Starting Baseline

- Tests: 24/24 passing before pass
- Gameplay: human-validated as "incredible"
- Known presentation issues: menu crop/overlap, HUD fixed sizing, stage collage (partially fixed in V3)

---

## Architecture — Before / After

### Menu (before)
```
ScreenRoot
├── TextureRect bg @ (0,0,1920,1080) COVER
├── TextureRect logo @ (72,150,700,475)
├── TextureRect panel @ (1130,315,650,488)  ← clips on smaller windows
├── Button overlay
└── debug microcopy labels
```

### Menu (after)
```
KapesMenuScreen (full rect)
├── MenuBackground (COVER, full rect)
├── TricolorAccent (entrance only)
├── GameLogo (CONTAIN, left column ~42% safe width)
├── LocalBattlePanel (CONTAIN, right column ~36% safe width)
├── LocalBattleArtworkButton (transparent, aligned to panel)
└── PlayHint ("F / SPACE — JUGAR")
```

### HUD (after)
```
CanvasLayer +10 HUD
├── KapesPlayerHUD P1 (bottom-left, 22%×12% safe area)
├── KapesPlayerHUD P2 (bottom-right, mirrored)
└── performance_label (F3 opt-in)

CanvasLayer +20 MATCH_INTRO (child of HUD root)
├── intro_accent (tricolor flash)
└── message_label (¡DALE!)
```

---

## Responsive Layout Rules

| Rule | Value |
|------|-------|
| Design resolution | 1920×1080 |
| Safe margin X | 5.5% |
| Safe margin Y | 5.0% |
| Logo max width | 42% safe area |
| Battle panel max width | 36% safe area |
| HUD card size | 22% × 12% viewport |
| Background stretch | COVER |
| Logo/panel stretch | CONTAIN (centered) |

Implemented in `scripts/ui/kapes_ui_layout.gd`.

---

## Visual Tokens (`KapesVisual`)

- `KAPES_RED`, `KAPES_BLUE`, `KAPES_WHITE`, `KAPES_GOLD`, `KAPES_NAVY`, `KAPES_MUTED`
- `P1_COLOR`, `P2_COLOR` (+ P3/P4 reserved)
- `SAFE_MARGIN_X/Y`, `HUD_WIDTH_RATIO`, `HUD_HEIGHT_RATIO`
- `FAST_MOTION` (0.12s), `NORMAL_MOTION` (0.22s), `SCREEN_TRANSITION` (0.34s)
- `damage_color(percent)` — tiered 0–49 / 50–99 / 100–149 / 150+

---

## Canvas Layer Contract (preserved)

| Layer | Purpose |
|-------|---------|
| WORLD 3D | stage, fighters |
| +5 | event FX only |
| +10 | HUD |
| +20 | match intro |
| +30 | menu / pause / results |
| +40 | transitions |

---

## Asset Inventory (authoritative paths)

### UI
| Asset | Size | Usage |
|-------|------|-------|
| `ui/menu/main_menu_bg.png` | 1672×941 | Menu + results backdrop (COVER) |
| `ui/menu/smash_kapes_logo.png` | 1448×1086 | Logo (CONTAIN) |
| `ui/menu/local_battle_panel.png` | 1448×1086 | Local battle hero (CONTAIN) |
| `ui/hud/hud_p1.png` | 2172×724 | P1 plate |
| `ui/hud/hud_p2.png` | 2172×724 | P2 plate |
| `ui/transitions/paraguay_slash.png` | 2172×724 | (procedural wipe used) |

### Stage
| Asset | Size | Normal play |
|-------|------|-------------|
| `defensores_bg_main.png` | 1672×941 | Hero camera background |
| `defensores_platform_kit.png` | 1672×941 | Platform deck + rim + underside |
| `stadium_light_confetti_overlay.png` | 2172×724 | KO event only |
| crowd/mosaic/tifo/scoreboard | various | Deferred / hooks only |

---

## Scene Lifecycle

Audited paths:
- menu → transition → battle (focus released, transition layer freed)
- battle → pause overlay on UI layer +30 (not duplicate HUD)
- pause → resume / restart / menu (overlay freed)
- battle → results → rematch / menu

No duplicate HUD or transition layers after single cycle (headless validated).

---

## Tests

**27/27 passing** after presentation pass.

New regressions:
- responsive menu layout authority
- HUD viewport-relative layout + stock pips
- single clean play hint
- mosaic API hooks retained

---

## Godot Validation

```
Main.tscn auto-start battle: ✅ no parser/runtime errors
Focus at battle start: null
Heartbeat: ~145 FPS after startup
```

---

## Human Playtest Checklist (all HUMAN_REQUIRED)

1. Boot game
2. Inspect menu at 1920×1080 — logo + panel fully visible, no crop
3. Resize window (1600×900, 1366×768) — layout adapts
4. Select JUGAR (mouse or F/Space)
5. Watch flag transition (~340ms)
6. Watch ¡DALE! intro — centered, fades, no HUD overlap
7. Fight — movement, jump, attack
8. Land hits — damage pulse, stock pips update
9. Reach 100%+ — danger color tier
10. Lose stock — pip fades
11. Pause (ESC) — readable overlay
12. Resume
13. Finish match — results entrance
14. Rematch
15. Return to menu
16. Repeat 3× rematch cycle — no duplicate UI

---

## Recommended Next Milestone

1. Human visual acceptance of menu + stage integration
2. Replace capsule portraits with first real character art
3. Optional scoreboard screen-content overlay (if alignment calibrated)
4. Event mosaic presentation (stand-region anchors)
5. Audio hooks (menu confirm, hit tiers, KO)

---

## Files Created

- `scripts/ui/kapes_ui_layout.gd`
- `scripts/ui/kapes_menu_screen.gd`
- `scripts/ui/kapes_pause_overlay.gd`
- `scripts/ui/kapes_results_screen.gd`
- `docs/OVERNIGHT_PRESENTATION_REPORT.md`
- `docs/Overnight_blockers.md`

## Files Modified

- `scripts/ui/kapes_visual.gd`
- `scripts/core/main.gd`
- `scripts/ui/m0_hud.gd`
- `scripts/ui/kapes_player_hud.gd`
- `scripts/stages/defensores_stage.gd`
- `tests/test_m0_combat.py`
- `CHANGELOG.md`
- `docs/VISUAL_IDENTITY.md`
- `docs/UI_FLOW.md`
