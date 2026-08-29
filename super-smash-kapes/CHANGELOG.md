# Changelog

## Overnight Production Hardening + Animation V1

- Root-caused exploded ActorCore meshes: Mixamo T-pose→stand (50–100°) copied onto AccuRIG local axes (~90° rest mismatch). First broken stage is retarget bake (C), ~10× skinned volume.
- Production V4 uses **clip-relative** Mixamo deltas vs clip frame 1. Idle bbox volume_ratio Tereré 1.06 / Jaguareté 1.01 (not exploded). V3 GLBs kept on disk.
- Shared clip-relative library (idle/jump/attacks/hits/KO). No run or victory source. Gameplay timing unchanged.
- HUD socket pass (portrait/name/damage/stock) + Victory V6 two mini-cards. Final-KO event FX stronger than stock KO.
- Future fighter validator + `tools/build_fighter.ps1`. Tests **104 passed**.
- Report: `docs/OVERNIGHT_PRODUCTION_HARDENING_V1_REPORT.md`.

## Canonical Fighter Size + HUD Final + Victory V3

- Replaced presentation multipliers with canonical `size_class` + `target_visual_height` (Tereré SHORT 2.40, Jaguareté TALL 3.15).
- Auto scale: `presentation_scale = target / measured_body_height` (bombilla/tail-aware measure modes).
- HUD +20–25% card scale, mirrored zones, portrait clip mask, baked transparent portraits.
- Victory screen rebuilt with universal Defensores fireworks assets + winner hero art + graphic buttons.
- Tests expanded to **60/60**. Report: `CANONICAL_FIGHTER_SIZE_HUD_VICTORY_V3_REPORT.md`.

## Fighter Scale + HUD + Results V2

- Added **PresentationScaleRoot** with per-fighter multipliers (Tereré 1.72×, Jaguareté 1.58×) — gameplay colliders unchanged.
- Recomputed AABB grounding, body-height fractions (Tereré bombilla, Jaguareté tail), proportional blob shadows.
- Restrained camera framing (min distance 26, max 36).
- Rebuilt HUD with `KapesHudLayout` normalized zones; removed floating P1/P2 labels; stock sockets aligned to plate art.
- Added `KapesPortrait` runtime white-background removal + crop (cached).
- Rebuilt Results/Victory screen: winner hero art, staged intro, compact stats, REVANCHA / CAMBIAR KAPES / MENÚ.
- Diagnostics: extended `SSK_MODEL_AUDIT`, F4 visual bounds debug toggle.
- Tests expanded to **55/55**. Report: `FIGHTER_SCALE_HUD_RESULTS_V2_REPORT.md`.

## Real GLB Fighter Integration V1

- Integrated `terere_glb_1.glb` and `jaguarete_glb_1.glb` as primary in-game visuals.
- Added `glb_fighter_visual.gd` with AABB-based scale/grounding, yaw facing, motion proxy, hit flash, blob shadow.
- Procedural visuals retained as fallback; catalog updated with GLB wrapper scenes.
- Diagnostics: `SSK_MODEL_AUDIT`, `SSK_SHOW_FIGHTER_COLLIDERS`.
- Gameplay collision and tuning unchanged. Tests expanded to 49.

## Overnight Fighter Pipeline V2

- Added `FighterDefinition`, `FighterCatalog`, `MatchSetup`, and `FighterVisual` base API.
- Built reference-faithful `TerereVisual` and `JaguareteVisual` procedural models.
- Added **ELIGÍ TU KAPE** character select; battle spawns catalog fighters instead of capsules.
- HUD portraits and results screen use fighter display names and raw design portraits.
- Gameplay collision, movement, attacks, and knockback unchanged.
- Expanded regression tests to 35 checks.
- Documentation: `FIGHTER_REFERENCE_BREAKDOWN.md`, `FIGHTER_PIPELINE.md`, `OVERNIGHT_FIGHTER_PIPELINE_REPORT.md`.

## Overnight Presentation Master Pass V1

- Rebuilt main menu with responsive safe-area layout (`KapesMenuScreen`, `KapesUILayout`).
- Centralized UI design tokens in `KapesVisual` (colors, margins, motion, damage tiers).
- Polished battle HUD: viewport-relative sizing, stock pips, damage punch tweens, intro on layer +20.
- Added dedicated responsive pause (`KapesPauseOverlay`) and results (`KapesResultsScreen`) screens.
- Improved Defensores platform presentation with underside/rim depth sprites (collision unchanged).
- Preserved combined-mode focus/layer contract and all gameplay tuning.
- Expanded regression tests to 27 checks.

## Overnight Surprise Build V1

- Added title screen and local battle launch flow.
- Added pause overlay, match results, match statistics, rematch, and main-menu return.
- Moved the M0 attack timing and knockback values into `AttackDefinition` data.
- Added short hop/full hop behavior and deliberate fast-fall controls.
- Added raised one-way platforms and procedural city/stadium backdrop dressing.
- Added smooth fighter-follow camera framing.
- Added procedural impact bursts scaled by knockback strength.
- Preserved the validated two-player combat, stocks, respawn, and KO foundation.
- Expanded lightweight regression tests from 7 to 8 checks.

Known gaps are tracked in `docs/Overnight_blockers.md` and the overnight report.

## Visual Identity Overhaul V1

- Replaced the dashboard-like title layout with an asymmetrical fighting-game splash screen.
- Added centralized Kapes visual tokens and angular panel primitives.
- Added Paraguay red/white/blue flag motion and a procedural Asunción/Palacio-inspired night backdrop.
- Redesigned battle HUD with massive damage typography and graphical stock pips.
- Redesigned pause and results screens in Spanish/Paraguayan-flavored player language.
- Added reusable flag wipe transitions and focus feedback.
- Added visual identity and UI flow documentation.
