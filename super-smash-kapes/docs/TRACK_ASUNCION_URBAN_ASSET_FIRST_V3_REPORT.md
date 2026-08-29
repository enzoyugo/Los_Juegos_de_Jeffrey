# Track Asunción urban asset-first V3

**Verdict: TRACK_ASUNCION_URBAN_ASSET_FIRST_V3_READY_FOR_HUMAN_REVIEW**

`TrackSceneryGenerator` architecture kept.

## Replacements

- Palms/trees: prefer `processed/vegetation/*_v2_*.glb` (mid-poly fronds / ico crowns), fallback V1 kit
- Parked cars: VAZ / Hilux / wreck processed GLBs when present
- Jeffrey landmark: `jeffrey_arch_v2` gold/black arch + island block
- Ground: large olive/urban plane instead of a red tiled read
- Sky: warmer afternoon in Turbo V8
- Buildings V2 (window grids) exported under `processed/architecture/` for later density; V1 modules still instance if V2 paths are missing

Most scenery: no gameplay collision. Camera blockers stay layer 128.

Party loop unchanged.
