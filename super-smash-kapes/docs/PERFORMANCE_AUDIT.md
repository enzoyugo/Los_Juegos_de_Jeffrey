# Super Smash Kapes — Visual Composition and Performance Audit

## Scope

This audit addresses the visual integration freeze/stall report without
changing gameplay mechanics or adding assets.

## Findings

The highest-risk combination was avoidable runtime churn plus transparent
overdraw:

- Defensores crowd and mosaic changes created new `AtlasTexture` resources at
  runtime.
- The HUD was rebuilt/redrawn from `_physics_process()` on every physics tick.
- Crowd, mosaic, atmosphere, confetti, foreground, scoreboard, HUD, and
  transition layers could overlap simultaneously.
- The intro used a large full-screen slash texture in addition to the HUD and
  stage layers.
- The intro message tween had no explicit cancellation/reference protection.

No infinite loop or unbounded signal connection was found. The freeze is best
treated as a rendering/resource-pressure risk during scene startup and intro
composition, not as a proven gameplay deadlock.

## Runtime systems after the audit

### `scripts/stages/defensores_stage.gd`

- No `_process()` or `_physics_process()` loop remains.
- Crowd and mosaic changes are timer-driven.
- Atlas regions are cached once during `_ready()`.
- Only one crowd layer is visible during normal play.
- Mosaic and celebration FX are hidden until an event.
- Scoreboard regions are cached once.
- Event tweens are killed before replacement.

### `scripts/ui/m0_hud.gd`

- A small `_process()` runs only while F3 performance mode is enabled.
- HUD fighter values update from damage/respawn signals.
- Intro tween is stored and killed before replacement.
- The full-screen intro slash was removed from the HUD.

### `scripts/ui/kapes_player_hud.gd`

- No `_process()` or `_physics_process()` loop.
- Plate textures are preloaded once.
- Damage text changes only when the fighter signal arrives.
- Generated stock-dot drawing was removed because the supplied plate already
  contains the authoritative stock indicators.

## Texture inventory

Project PNGs are generally 1448–2172 pixels wide and imported as
`CompressedTexture2D` with mipmaps disabled, appropriate for UI and 2D
composition. The largest runtime assets are roughly 3.3 MB on disk:

- Mosaic variants: 1672×941, approximately 3.2 MB.
- Crowd strips: 1672×941, approximately 3.1 MB.
- Crowd loop variants: 2172×724, approximately 2.9 MB.
- Football prop pack: 1672×941, approximately 3.0 MB.
- Celebration overlays: approximately 2.1 MB.

Source-raw images are not referenced by gameplay scripts and should remain
outside the runtime visual path.

## Overdraw changes

Normal battle now targets:

1. One opaque full-screen stadium background.
2. One low-opacity crowd strip.
3. Small scoreboard overlay.
4. World-space platform art and props.
5. Reduced bottom foreground strip.
6. HUD.

Mosaic, confetti, and large atmosphere overlays are event-only.

## Debug profiling

During a match, press `F3` to toggle a disabled-by-default performance overlay.
It reports FPS, frame time, scene node count, and Godot object count. Use it
while zooming the camera and during KO/intro transitions.

## Remaining uncertainty

Headless validation cannot measure GPU frame time or confirm subjective visual
composition. The original human freeze was not reproducible in headless mode;
the mitigations remove the identified high-risk churn and overdraw, but a
bounded Windows playtest remains required.
