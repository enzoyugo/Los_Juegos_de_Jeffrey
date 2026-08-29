# Victory Composition V5 Report

## Primary Verdict

**SSK_VICTORY_COMPOSITION_V5_READY_FOR_HUMAN_PLAYTEST**

V4 rejected by human playtest. V5 rebuilt from scratch — no mega backplate,
no title banner asset, no placeholder masking. Compact broadcast-style right column.

**Not visually approved** until human screenshots confirm.

## V4 Human Rejection

Status: **SSK_VICTORY_COMPOSITION_V4_HUMAN_REJECTED**

Observed: giant right slab, masked placeholder still visible, duplicate GANADOR,
tiny stats/buttons, disconnected winner art, debug-overlay feel.

## Removed V4 Elements

- `TitleBanner` / `victory_title_banner.png` usage
- `PlaceholderMask` overlay
- `TitleZone` mega cluster
- `MainPanel` (was already absent in code)
- Scattered manual label positions
- V4 button row geometry

## V5 Layout

Five layers only:

1. **BACKGROUND** — `victory_bg_defensores.png` full bleed COVERED
2. **WINNER** — left ~44% width, ~60% height, feet ~91% viewport
3. **TITLE** — right stack: tricolor accent + GANADOR + name + ¡VICTORIA!
4. **STATS** — stats plate + 2-column GridContainer inside frame
5. **ACTIONS** — wide REVANCHA, then CAMBIAR KAPES + MENÚ row

Right safe zone: x 51%–94%, y 12%–88%. Single `RightStack` VBox alignment.

## Winner Art

`RESULTS_WINNER_HEIGHT_RATIO = 0.60`, hero width `0.44`.  
Entrance: slide + scale 0.90 → 1.02 → 1.0.

## Title Hierarchy

Dynamic typography only — **one** GANADOR label.  
No baked placeholder text. Small tricolor slash accent above title block.

## Stats

`RESULTS_STATS_RATIO = 0.21`, width ~43% viewport.  
`StatsGrid` columns=2 with `StatsP1` / `StatsP2` VBox columns.  
Labels + values in HBox rows inside panel bounds.

## Actions

- **REVANCHA**: primary, ~68% right column width, art-backed
- **CAMBIAR KAPES**: themed navy/gold panel (BLOCKER-014)
- **MENÚ**: art-backed, equal secondary width

Transparent hotspots, focus scale 1.04, no default StyleBox on CAMBIAR.

## Responsive Behavior

`UILayout.safe_rect` + scale factor. Targets 1920×1080, 1600×900, 1366×768.

## Tests

63/63 — asserts no TitleBanner, no PlaceholderMask, RightStack, StatsGrid,
single GANADOR, ChangeKapesArt present.

## Human Screenshots Required

1. Tereré victory @ 1920×1080
2. Jaguareté victory @ 1920×1080
3. Victory @ 1366×768
4. Confirm: no placeholder text, stats inside panel, buttons readable

## Remaining Asset Gaps

- **BLOCKER-014**: `victory_btn_change_kapes.png` dedicated art
