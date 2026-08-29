# Canonical Fighter Size + HUD Final + Victory V3 Report

**Verdict:** `SSK_CANONICAL_SIZE_HUD_VICTORY_V3_READY_FOR_HUMAN_PLAYTEST`

**Date:** 2026-08-22  
**Godot:** 4.7.2 stable  
**Automated tests:** 60/60 passing (baseline was 55/55)  
**Headless validation:** Menu → auto-select → battle — clean

> Visual acceptance still requires human screenshots. Headless confirms lifecycle, sizing math, and asset wiring only.

---

## Primary Verdict

Canonical per-character visual sizing, HUD final alignment (scale + clip + transparent portraits), and universal Defensores victory asset integration are implemented. Gameplay colliders remain unchanged. Ready for human playtest screenshots.

---

## Canonical Size Architecture

Replaced arbitrary `presentation_scale_multiplier` with:

| Field | Role |
|-------|------|
| `size_class` | TINY / SHORT / MEDIUM / TALL / HUGE |
| `target_visual_height` | Authoritative body height in world units |
| `body_measure_mode` | FULL / IGNORE_TOP / BODY_FRACTION |
| `fit_ignore_top_ratio` | Bombilla / top extras exclusion |
| `body_height_fraction` | Bottom fraction of AABB for body measure |
| `ground_anchor` | Extra foot grounding bias |

**Formula:**

```text
measured_body_height = measure(AABB, mode)
presentation_scale = target_visual_height / measured_body_height
```

Applied only on `PresentationScaleRoot`. Gameplay `CharacterBody3D` never inherits it.

Shared helpers: `fighter_size_class.gd`, metadata on `FighterDefinition` + `GlbFighterConfig`.

---

## Tereré Size

| Property | Value |
|----------|-------|
| size_class | **SHORT** |
| target_visual_height | **2.40** |
| body_measure_mode | IGNORE_TOP (bombilla ~18%) |
| Headless audit | measured=1.553 → presentation=1.5453 → body_h=**2.400** |
| visual/collider ratio | 1.00 |

Bombilla remains visible above the canonical body height. Not cropped.

---

## Jaguareté Size

| Property | Value |
|----------|-------|
| size_class | **TALL** |
| target_visual_height | **3.15** |
| body_measure_mode | BODY_FRACTION (0.95) |
| Headless audit | measured=1.799 → presentation=1.7505 → body_h=**3.150** |
| visual/collider ratio | 1.31 |

Tail does not drive vertical sizing. Clearly taller than Tereré:

**3.15 / 2.40 ≈ 1.31×** (matches ~1.30 target relationship)

---

## Grounding

After scale, ground offset recomputed from scaled AABB min Y + `ground_anchor`.

Headless:

- Tereré ground_y=1.4701
- Jaguareté ground_y=1.6537

Feet/paws sit on platform collision. No floating/sinking intended.

---

## Visual / Collider Relationship

| Collider | Value | Changed |
|----------|-------|---------|
| Capsule radius | 0.65 | No |
| Capsule height | 2.4 | No |
| Hurtbox / hitbox | unchanged | No |

Visual may exceed collider for bombilla, poncho, ears, tail. Torso width remains believable. No silent collider resize.

---

## HUD Final Layout

- Card scale increased ~23%: `HUD_WIDTH_RATIO` 0.22 → **0.27**, height 0.12 → **0.148**
- P1/P2 mirrored normalized zones (identical vertical baselines)
- Portrait clipped via `PortraitMask.clip_contents = true`
- Floating P1/P2 tags remain removed
- Single stock socket authority
- Damage right/left aligned inside damage region

---

## Portrait Fix

Dedicated transparent assets (baked once, not per-frame):

- `assets/ui/portraits/terere_portrait.png`
- `assets/ui/portraits/jaguarete_portrait.png`

Catalog points HUD portraits here. Runtime `KapesPortrait` remains as safe cache fallback.

---

## Victory Assets

Universal Defensores celebration (any stage):

- `victory_bg_defensores.png`
- `victory_main_panel.png` / `victory_stats_panel.png` / `victory_title_banner.png`
- `victory_btn_rematch.png` / `victory_btn_menu.png`
- `terere/terere_victory.png` / `jaguarete/jaguarete_victory.png`

---

## Victory Composition

```text
VictoryBackground (COVER — national fireworks stadium)
VictoryWash (player-color accent)
ResultsContent
├── WinnerHero (left, ~38% width / ~42% height)
├── MainPanel + TitleBanner
├── GANADOR / ¡VICTORIA! / WinnerName
├── StatsPanel + compact P1/P2 cards
└── Actions (REVANCHA art / CAMBIAR KAPES / MENÚ art)
```

Intro < 0.8s. Decorative TextureRects use `mouse_filter=IGNORE`. Hotspots are invisible buttons over art.

---

## Results Navigation

| Action | Flow |
|--------|------|
| REVANCHA | same characters/stage → battle |
| CAMBIAR KAPES | Character Select |
| MENÚ | Main Menu |

---

## Performance

- No per-frame texture load / image process / material alloc
- Portraits cached; victory textures preloaded once
- GLB geometry unchanged (~157k tris combined)

---

## Tests

**60/60** passing. New coverage:

- canonical size metadata
- Tereré SHORT / Jaguareté TALL
- Jaguareté taller than Tereré
- auto presentation scale (no multiplier authority)
- collider unchanged
- HUD clip + scale
- transparent portrait assets
- victory assets + universal BG + actions

---

## Godot Validation

```text
[MODEL_AUDIT] fighter=terere class=SHORT target=2.40 body_h=2.400 ratio=1.00
[MODEL_AUDIT] fighter=jaguarete class=TALL target=3.15 body_h=3.150 ratio=1.31
```

No parser errors. Battle spawn clean.

---

## Human Playtest Checklist

Please capture:

1. Tereré next to Jaguareté (height relationship)
2. Tereré close-up gameplay
3. Jaguareté close-up gameplay
4. Both HUDs at 0%
5. Both HUDs at 100%+
6. Tereré victory
7. Jaguareté victory
8. Optional: 1366×768 results

Confirm: SHORT vs TALL reads immediately; HUD portraits stay inside plates with no white squares; victory feels like a Paraguayan celebration, not a stats dashboard.

---

## Remaining Limitations

1. Screen-space % of viewport still needs human eye confirmation
2. CAMBIAR KAPES uses themed Button (no dedicated art asset yet)
3. Static GLBs — motion proxy only; no skeletal animation
4. Portrait bake threshold may need hand tune if fur edges clip
5. Visual/collider mismatch documented; per-fighter gameplay hurtboxes deferred

---

## Files Created / Modified

**Created:** `fighter_size_class.gd`, portrait PNGs, `CANONICAL_FIGHTER_SIZE_HUD_VICTORY_V3_REPORT.md`

**Modified:** `glb_fighter_config.gd`, `glb_fighter_visual.gd`, `fighter_definition.gd`, `fighter_catalog.gd`, Tereré/Jaguareté GLB visuals, HUD layout/player HUD/visual ratios, results screen, tests, CHANGELOG, Overnight_blockers
