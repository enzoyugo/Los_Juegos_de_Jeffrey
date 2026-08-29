# Fighter Scale + HUD + Results V2 Report

**Verdict:** `SSK_FIGHTER_SCALE_HUD_RESULTS_V2_READY_FOR_HUMAN_PLAYTEST`

**Date:** 2026-08-22  
**Godot:** 4.7.2 stable  
**Automated tests:** 55/55 passing (baseline was 48/48)  
**Headless validation:** Menu → auto-select → battle — clean (no parse/runtime errors)

> Visual acceptance requires human screenshots. Headless validation confirms structure and lifecycle only.

---

## Primary Verdict

Presentation-scale rebuild, HUD zone layout, and Victory/Results V2 are implemented. Gameplay colliders, movement, attacks, and knockback are unchanged. Automated regression and Godot headless startup pass. **Human playtest with screenshots is required before declaring visual acceptance.**

---

## Executive Summary

Fighters were visually too small (~5–8% viewport height). This milestone adds a separate **PresentationScaleRoot** multiplier per fighter, recomputed grounding, restrained camera framing, normalized HUD regions aligned to plate art, runtime portrait cleanup, and a rebuilt Results screen with winner hero art and staged intro. Combat authority remains on the unchanged CharacterBody3D capsule.

---

## Before / After Fighter Scale

| Metric | Before (V1 GLB) | After (V2 presentation) |
|--------|-----------------|-------------------------|
| Tereré effective presentation scale | ~1.09 (fit only) | **1.884** (fit × 1.72) |
| Jaguareté effective presentation scale | ~1.00 (fit only) | **1.580** (fit × 1.58) |
| Tereré visual body height vs collider | ~0.73× | **~1.25×** |
| Jaguareté visual body height vs collider | ~0.79× | **~1.12×** |
| Gameplay capsule height | 2.4 | **2.4 (unchanged)** |

Headless `SSK_MODEL_AUDIT=1` sample:

```text
[MODEL_AUDIT] fighter=terere ... presentation=1.8838 body_h=2.997 ground_y=1.7921 width=2.234 collider_h=2.40 ratio=1.25
[MODEL_AUDIT] fighter=jaguarete ... presentation=1.5800 body_h=2.694 ground_y=1.4927 width=1.960 collider_h=2.40 ratio=1.12
```

Target screen-space height (~12–17% viewport) must be confirmed by human screenshot at 1920×1080.

---

## Tereré Presentation Metrics

- `presentation_scale_multiplier`: **1.72**
- `body_height_fraction`: **0.84** (bombilla excluded from body-height fit, not cropped)
- `fit_ignore_top_ratio`: **0.08** (bombilla top ignored for vertical fit)
- `body_anchor_y_fraction`: **0.44**
- `shadow_width / depth`: **1.25 / 0.62**
- Ground offset recomputed from scaled AABB min Y
- Bombilla remains visible in silhouette

---

## Jaguareté Presentation Metrics

- `presentation_scale_multiplier`: **1.58**
- `body_height_fraction`: **0.90** (tail does not dominate vertical sizing)
- `body_anchor_y_fraction`: **0.46**
- `horizontal_anchor_fraction`: **0.48** (chest/hip bias vs tail AABB)
- `shadow_width / depth`: **1.35 / 0.68**
- Full jaguar silhouette (head, ears, spots, tail, sash) preserved

---

## Grounding Strategy

Reusable logic in `glb_fighter_visual.gd`:

1. Compute full mesh AABB in model space
2. Derive body bounds via `body_height_fraction` / `fit_ignore_top_ratio`
3. Apply fit scale, then `presentation_scale_multiplier` on **PresentationScaleRoot only**
4. Recompute `_ground_offset = -scaled_min_y` so feet sit on fighter ground anchor
5. Horizontal anchor via `horizontal_anchor_fraction` + `body_anchor_y_fraction` (torso-centered, not raw AABB center)

Hierarchy:

```text
VisualRoot
└── GlbFighterVisual
    ├── BlobShadow
    └── VisualMotionRoot
        └── PresentationScaleRoot   ← display scale only
            └── ModelRoot
                └── GLB instance
```

---

## Visual vs Gameplay Collider

| Collider | Value | Changed |
|----------|-------|---------|
| Body capsule radius | 0.65 | No |
| Body capsule height | 2.4 | No |
| Hurtbox | 0.78 / 2.6 | No |
| Attack hitbox | 1.55 × 1.15 × 1.0 | No |

Visual/collider ratio after scale:

- Tereré: **~1.25×** body height vs collider (acceptable — poncho/bombilla extend)
- Jaguareté: **~1.12×** (acceptable — tail/ears extend)

Feet align to platform collision. Torso does not appear twice collider width. No silent collider resize.

Diagnostics: `SSK_SHOW_FIGHTER_COLLIDERS=1` (env), **F4** toggles visual bounds wireframe (debug only).

---

## Camera Composition

Restrained framing adjustment after visual enlargement:

- `minimum_distance`: 30 → **26**
- `maximum_distance`: 40 → **36**

Blast zones, separation zoom logic, and follow smoothing unchanged. Goal: fighters read before platform/stadium.

---

## HUD Problems Found

1. P1/P2 tag labels floated outside plate artwork
2. Portraits showed white rectangular backgrounds
3. Damage % not consistently contained in plate damage zone
4. Stock pips detached from baked socket circles
5. P1 vs P2 spacing inconsistent (pixel offsets)

---

## HUD Layout Rebuild

New `KapesHudLayout` defines normalized regions relative to HUD card size:

| Zone | P1 ratio (x, y, w, h) |
|------|-------------------------|
| Portrait | 0.03, 0.14, 0.20, 0.62 |
| Damage | 0.56, 0.22, 0.38, 0.52 |
| Stock | 0.22, 0.76, 0.28, 0.18 |

P2 mirrors horizontally. `KapesPlayerHUD` uses zone rects — no magic 1920×1080 offsets. Floating `tag_label` removed (plate art carries P1/P2).

Shared tokens: `KapesVisual.HUD_WIDTH_RATIO`, `HUD_HEIGHT_RATIO`, `SAFE_MARGIN_X/Y`.

---

## Portrait Cleanup

`KapesPortrait` runtime processor:

- Strips near-white background (RGB > 0.92 → alpha 0)
- Crops HUD portraits to content bounds
- Cached once per source path (no per-frame allocation)

Dedicated on-disk assets under `assets/ui/portraits/` deferred; runtime derivation from catalog `reference_texture` is stable.

---

## Damage Layout

- Right-aligned damage label inside damage region
- Tier coloring preserved via `KapesVisual.damage_color()`
- Font scales with card height; 0% / 16% / 89% / 147% should fit without shifting composition (verify at 1366×768 in playtest)

---

## Stock Layout

Single authority: `_draw_stock_sockets()` fills baked plate socket positions via `stock_socket_offsets`. Active lives bright; lost lives dimmed. No duplicate decorative + dynamic pip sets.

---

## Victory Screen Rebuild

`KapesResultsScreen` hierarchy:

```text
Background (menu city, darkened)
VictoryWash (P1 warm / P2 cool gradient)
ResultsContent
├── WinnerHero (~40% viewport width hero art)
├── GANADOR (small)
├── ¡VICTORIA! (accent, player color)
├── WinnerName (large fighter name)
├── StatsRow (compact dual cards ~24% width each)
└── ActionsRow (REVANCHA / CAMBIAR KAPES / MENÚ)
```

Intro tween (~0.8s): darken → hero in → name punch → stats fade → buttons.

---

## Winner Hero Presentation

**Option A implemented:** processed reference concept art via `KapesPortrait.get_hero_portrait()`. Option B (SubViewport GLB render) deferred — static meshes + no victory rig makes 3D render fragile for this milestone.

Character art = fighter identity. Accent wash = player color (P1 red/orange, P2 blue/cyan).

---

## Results Layout

Viewport-relative via `KapesUILayout.safe_rect()` and `KapesVisual.RESULTS_HERO_RATIO` (0.40) / `RESULTS_STATS_RATIO` (0.24). Stats secondary to winner hero.

---

## Results Navigation

| Button | Flow |
|--------|------|
| REVANCHA | Same characters, same stage, battle |
| CAMBIAR KAPES | Character Select (`change_kapes_pressed` → `_show_character_select`) |
| MENÚ | Main Menu |

Rematch and menu flows preserved in automated tests.

---

## Resolution Validation

Layout uses ratios + safe margins (not fixed pixels). Recommended human checks:

| Resolution | Checks |
|------------|--------|
| 1920×1080 | HUD corners, hero art, winner name |
| 1600×900 | Damage % clipping, button accessibility |
| 1366×768 | Stats cards, hero scale, HUD overlap |

---

## Performance Impact

- No per-frame GLB `load()`
- No per-frame material duplication loop (flash materials duplicated once at spawn)
- Portrait processing cached in static dictionary
- Results hero texture created once per results screen setup
- Combined fighters ~157k tris (unchanged mesh data)

### GLB Performance Audit (unchanged geometry)

| Fighter | Tris (approx) | Meshes | Materials | File size |
|---------|---------------|--------|-----------|-----------|
| Tereré | ~81k | 1 | 1 PBR | ~14.8 MB |
| Jaguareté | ~76k | 1 | 1 PBR | ~13.9 MB |

**Future LOD recommendation:** LOD0 current mesh; LOD1 ~50% tris billboard-tail/bombilla simplified; LOD2 ~15% tris impostor for distant camera — do not modify source GLBs in this milestone.

---

## Automated Tests

**55/55** passing. New regression coverage:

- Presentation scale separate from collider
- Independent Tereré / Jaguareté scale configs
- Collider dimensions unchanged
- HUD normalized regions, no floating tag labels
- Portrait cleanup utility
- Victory hero + CAMBIAR KAPES + responsive results
- Model audit + F4 bounds debug hooks
- No `_process` GLB reload

---

## Godot Validation

```powershell
& "E:\Godot_v4.7.2-stable_win64_console.exe" --path "E:\SuperSmashKapes\super-smash-kapes" --import
$env:SSK_AUTO_SELECT_BATTLE="1"; $env:SSK_MODEL_AUDIT="1"
& "E:\Godot_v4.7.2-stable_win64_console.exe" --headless --path "E:\SuperSmashKapes\super-smash-kapes" --quit-after 8
```

Result: clean startup, MODEL_AUDIT logs, battle spawn, no parser errors.

---

## Files Created

- `scripts/ui/kapes_hud_layout.gd`
- `scripts/ui/kapes_portrait.gd`
- `docs/FIGHTER_SCALE_HUD_RESULTS_V2_REPORT.md`

## Files Modified

- `scripts/fighters/glb_fighter_config.gd` — presentation/body anchor fields
- `scripts/fighters/glb_fighter_visual.gd` — PresentationScaleRoot, grounding, audit, F4 bounds debug
- `fighters/terere/terere_glb_visual.gd` — Tereré presentation config
- `fighters/jaguarete/jaguarete_glb_visual.gd` — Jaguareté presentation config
- `scripts/core/m0_camera.gd` — restrained zoom distances
- `scripts/ui/kapes_player_hud.gd` — zone-based HUD rebuild
- `scripts/ui/kapes_visual.gd` — RESULTS_HERO_RATIO, RESULTS_STATS_RATIO
- `scripts/ui/kapes_results_screen.gd` — Victory V2 rebuild
- `scripts/core/main.gd` — change_kapes flow
- `scripts/core/m0_playground.gd` — F4 visual bounds toggle
- `tests/test_m0_combat.py` — expanded regression suite
- `CHANGELOG.md`, `docs/Overnight_blockers.md`

---

## Remaining Risks

1. **Screen-space scale** — multipliers tuned from AABB math; human may want ±10% adjustment
2. **Portrait white-key** — extreme off-white fur/poncho edges may need hand-tuned threshold or baked PNGs
3. **1366×768** — compact stats cards need screenshot confirmation
4. **Jaguareté vs yellow stadium** — rim/contrast may still need material pass at distance
5. **3D victory portrait** — deferred; 2D hero art is intentional fallback

---

## Human Playtest Checklist

Please capture screenshots for:

- [ ] Gameplay close range — fighters next to each other
- [ ] Gameplay separated — camera zoomed out
- [ ] Tereré P1 — normal HUD
- [ ] Jaguareté P2 — normal HUD
- [ ] 100%+ damage — damage layout
- [ ] Stock lost — stock visualization
- [ ] Tereré victory screen
- [ ] Jaguareté victory screen
- [ ] 1366×768 results layout
- [ ] F4 visual bounds debug (optional)

Confirm: fighters feel like protagonists (~12–17% viewport height), feet grounded, HUD embedded in plate, results reads "TERERÉ WON" / "JAGUARETÉ WON" before stats.

---

## Recommended Next Milestone

1. Human scale/orientation pass from screenshots
2. Bake transparent portraits to `assets/ui/portraits/`
3. Optional SubViewport victory GLB render once rigged models exist
4. LOD exports if performance feedback requires
