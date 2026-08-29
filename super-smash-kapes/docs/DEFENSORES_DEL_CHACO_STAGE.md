# Defensores del Chaco Stage

The playable collision layout remains the proven `M0Stage.tscn`. The dedicated
`DefensoresDelChacoStage.tscn` wraps that scene with an art root, so stage art
can evolve without changing fighter spacing, soft-platform behavior, or blast
zones.

## Layer order

1. `FarBackground` — `defensores_bg_main.png`
2. `SkyOverlay` — procedural night wash while the supplied `sky_overlay.png` is unavailable
3. `CrowdLayerBase` / `CrowdLayerAnimated` — crowd strips and loop variants
4. `MosaicLayer` — rotating mosaic strip variants
5. `ScoreboardLayer` — scoreboard atlas states
6. `DecorativeProps` — tifo atlas and football-event prop atlas
7. `PlatformArtLayer` — visual-only platform kit overlays
8. `FXLayer` — stadium lights and restrained confetti
9. `ForegroundOverlay` — foreground rail/pitch-edge depth layer

Large environment art is viewport-anchored through CanvasLayer and TextureRect
so camera zoom cannot expose a rectangular texture edge. Platform art remains
Sprite3D-based so it tracks the authoritative collision geometry. The greybox
visual meshes are hidden only when the Defensores wrapper is active; their
collision bodies remain unchanged.

## Runtime behavior

`scripts/stages/defensores_stage.gd` cycles crowd and mosaic rows at a slow
idle cadence. The scoreboard starts in hype mode, settles to neutral after the
intro, and briefly switches to the KO atlas panel when the match controller
reports a KO. The same controller is intentionally reusable for future stadium
variants by swapping textures and layer configuration.

## Asset notes

The supplied assets are used from `assets/stages/defensores_del_chaco/` without
external downloads. The older manifest names `background/sky_overlay.png` and
`fx/fx_celebration_pack.png` are not present; the current composition uses a
procedural sky wash, `stadium_light_confetti_overlay.png`, and the supplied
football/KO atlases instead. This reconciliation is recorded in
`docs/Overnight_blockers.md`.
