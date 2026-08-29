# Victory Composition V4 Report

## Primary Verdict

**SSK_VICTORY_COMPOSITION_V4_READY_FOR_HUMAN_PLAYTEST**

Composition rebuilt around supplied art: full-bleed Defensores BG, dominant
winner character, unified title cluster (placeholder masked), larger stats
panel, coherent three-button action row. No mega empty panel. No floating
title stack. No default Godot button chrome for CAMBIAR KAPES.

## Previous Composition Problems

1. Giant dark mega panel duplicated framing  
2. Panel-inside-panel feel  
3. Floating GANADOR / ¡VICTORIA! / name  
4. Tiny stats card  
5. Undersized winner art  
6. Inconsistent button styles  
7. Dead space on the right  
8. Title banner misused  
9. Stats labels escaping artwork  
10. Unclear hierarchy  

## Asset Inventory

| Asset | Path | Use |
|-------|------|-----|
| BG | `victory_bg_defensores.png` | Full viewport COVERED |
| Title banner | `victory_title_banner.png` | Right title frame (placeholder masked) |
| Stats | `victory_stats_panel.png` | Stats frame |
| Rematch | `victory_btn_rematch.png` | Primary action art |
| Menu | `victory_btn_menu.png` | Tertiary action art |
| Tereré | `terere_victory.png` | Winner art |
| Jaguareté | `jaguarete_victory.png` | Winner art |
| Main panel | `victory_main_panel.png` | **Omitted from V4 composition** |

## Final Composition

Five layers only: BACKGROUND → WINNER → TITLE → STATS → ACTIONS.  
Asymmetric: left ~42% hero, right ~47% title/stats/actions. ~5% safe margins via `UILayout.safe_rect`.

## Winner Character Scale

~55% viewport height (`RESULTS_WINNER_HEIGHT_RATIO`), feet near 88% viewport Y.  
Entrance: 90% scale + left offset + fade → overshoot 1.03 → 1.0.

## Winner Title

Single `TitleZone`: banner + masked placeholder region + GANADOR / dominant name / ¡VICTORIA!.  
Baked placeholder name never visible (`PlaceholderMask`).

## Stats Panel

~42% width × ~20% height under title. Two halves P1/P2 inside panel bounds.

## Buttons

REVANCHA (art) | CAMBIAR KAPES (themed navy/gold/tricolor fallback)  
MENÚ (art) below. Transparent hotspots; gold focus scale — no Godot blue focus rect.  
BLOCKER-014 documents missing dedicated CAMBIAR art.

## Responsive Layout

`UILayout.safe_rect` + scale factor. Targets 1920×1080 / 1600×900 / 1366×768.

## Motion

Wash → hero (0.08) → title (0.20) → stats (0.32) → actions (0.46). Ready &lt; 0.75s.

## Performance

Textures preloaded; layout only on resize; no per-frame rebuilds.

## Tests

Victory V4 assertions: no MAIN_PANEL wiring, no placeholder string, PlaceholderMask,
ChangeKapesArt, WinnerHero, rematch/change/menu signals, safe_rect.

## Human Visual Checklist

1. Tereré Victory  
2. Jaguareté Victory  
3. Victory at 1366×768  
Confirm: no mega panel, winner dominant, title unified, stats inside panel, buttons coherent.

## Remaining Asset Gaps

- BLOCKER-014: dedicated `victory_btn_change_kapes.png`  
- Optional: crop title banner asset to remove baked placeholder permanently
