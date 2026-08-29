# TRACK MODULAR KIT REFERENCE ANALYSIS V1

Reference zip: `references/track/block_previews/Block Previews.zip`  
Inventory: `docs/references/track/block_preview_inventory.csv`  
Originality: `docs/TRACK_MODULAR_KIT_ORIGINALITY_GUIDELINES.md`

Previews were **not** copied into `res://assets/`. `.gdignore` keeps the zip and inventory out of Godot import.

## Archive Summary

| | |
|---|---|
| Files | **1057** PNG previews |
| Top folders | Stadium (464), Valley (593) |
| Naming | Stadium pieces are `Stadium` + CamelCase tokens. Valley pieces live in `Valley/` but filenames are environment tokens (`Arena`, `Cliff`, `Forest`, `Road`, …) without a `Valley` prefix |

Dominant filename tokens (not unique pieces): Road 517, Slope 241, GT 163, Curve 157, Border 108, Dirt 108, Straight 106, Cliff 104, Arena 101, Circuit 95, Deco 83, Tunnel 72, Checkpoint 51, Start 53, Turbo 41.

## Taxonomy

| Class | Archive families | V1 stance |
|---|---|---|
| CORE GEOMETRY | straight, curve/GTCurve, start/finish, checkpoint | keep, parameterized |
| ELEVATION | slope, tilt, bump, hill, platform, ramp | compact set |
| TECHNICAL | hairpin, chicane, circuit in/out | two chicanes + two hairpins |
| SPECIAL | turbo/boost, jump, drop, pipe/loop, wallride | boost + small jump/drop only |
| BORDER / SAFETY | border, rail, fence | metadata + our 0.9 m rails, not unique meshes |
| DECORATIVE / THEME | deco, signs, tributes, dirt/cliff cosmetics | **defer** |

## Frequency

Filename-inferred counts (one preview ≠ one unique geometry):

| Family | Count |
|---|---|
| curve | 187 |
| other (theme leftovers) | 170 |
| elevation | 166 |
| special | 99 |
| straight | 77 |
| checkpoint | 74 |
| bridge | 66 |
| decorative | 63 |
| tunnel | 61 |
| start_finish | 59 |
| border | 24 |
| ramp | 11 |

Curves and slopes dominate. Hundreds of GTCurve/radius cosmetics are **not** V1 mesh IDs.

## V1 Selected Piece List

22 generator-first IDs in `data/track/modules/track_kit_v1.json`:

`start` `finish`  
`straight_short` `straight_medium` `straight_long`  
`curve_l_45` `curve_r_45` `curve_l_90` `curve_r_90`  
`hairpin_l` `hairpin_r`  
`chicane_lr` `chicane_rl`  
`slope_up` `slope_down` `crest` `dip`  
`ramp_small` `jump_small` `drop_small`  
`checkpoint` `boost_straight`

Angles 30°/60° are **parameters** on `CurveBuilder`, not extra authored assets.

## Deferred Pieces

Tunnel, loop/pipe, wallride, bridge/viaduct, GTCurve cosmetic radii, Stadium circuit decorations, Valley dirt/cliff/arena theme kits, airship/platforms as scenery.

## Parametric Opportunities

| Builder | Specs |
|---|---|
| StraightBuilder | length, boost flag, start/finish/checkpoint gates |
| CurveBuilder | direction, angle_deg, radius_m |
| ElevationBuilder | height_delta / peak (crest, dip, slope, ramp, drop) |
| SpecialBuilder | chicane offset, jump gap |
| GuardrailBuilder | left/right flags |
| ConnectorBuilder | ENTRY / EXIT empties |
| UVBuilder | tile by centerline metres |

## Dimensions

Mapped to **our** contract, not traced screenshots:

- road 11.0 m
- shoulder 0.7 m each side (not part of asphalt)
- guardrail 0.9 m × 0.22 m
- car visual width ~2.14 m → ~5.1 car-widths of asphalt

## Connector Standard

- Piece ENTRY at local `(0,0,0)`
- Forward: Godot **−Z**
- Up: **+Y**
- Road centered on **X = 0**
- EXIT empty stores translation + yaw/pitch so `previous.EXIT` can match `next.ENTRY` with no gap, step, or rotation discontinuity
- Godot import: keep empties as `Marker3D` / Node3D

`TrackPieceGeometryContractV1` (`scripts/track/track_piece_geometry_contract_v1.gd`) holds metadata.

## Metadata Contract

Minimum fields: `piece_id`, `piece_family`, entry/exit basis, `road_width`, `shoulder_width`, `centerline_length`, `height_delta`, `yaw_delta` / `pitch_delta` / `roll_delta`, `left_guardrail` / `right_guardrail`, `estimated_traversal_time`, `difficulty`, `recommended_speed`, `tags`. Boost adds `boost_strength` (gameplay later; not implemented this sprint).

Collision: simple road box + rail boxes. Never visual trimesh as canonical collider.

## Difficulty Mapping

| Tag | Examples |
|---|---|
| TRANQUI | straights, start/finish, checkpoint, large-radius 45° |
| PICANTE | 90° , hairpin, chicane, slopes, crest/dip, ramp, boost |
| DEMENTE | jump gap, drop |

Length targets (existing generator times, kit must feed the same idea):

- CORTA ~8–12 s
- MEDIA ~17–23 s
- LARGA ~30–40 s

`estimated_traversal_time` on each spec is the seed for expected-time, not a rewrite of `TrackGenerator`.

## Length / expected-time relevance

Do not replace `TrackGenerator` this sprint. Adapter path:

existing logical segment (`gentle_left`, radius, angle, seed, fuel, ghosts, Hotseat)  
→ lookup / instance a `TrackPiece` module with matching family + params.

Logical IDs stay gameplay. Filenames of generated GLBs are not the ruleset.

## Material Strategy

Future shared `.tres` under `res://assets/track/materials/`:

`asphalt` `shoulder` `guardrail` `hazard` `boost` `checkpoint`

No unique baked atlas per module. Themes (ASUNCION_NIGHT, COSTANERA, SAN_BERNARDINO, STADIUM, RAIN_CITY) swap materials, not meshes.

UV: longitudinal world metres on road/rails. Optional later: triplanar for shoulders.

## Originality Rules

See `docs/TRACK_MODULAR_KIT_ORIGINALITY_GUIDELINES.md`. Archive = taxonomy only. No proprietary mesh/texture/logo copy.

## Recommended Blender Generator Architecture

`scripts/blender/generate_track_kit_v1.py`

`TrackKitConfig` → `TrackPieceBuilder` → `StraightBuilder` / `CurveBuilder` / `ElevationBuilder` / `SpecialBuilder` + `GuardrailBuilder` + `ConnectorBuilder` + `UVBuilder` + `Exporter`

Config: `data/track/modules/track_kit_v1.json`  
Future GLBs: `res://assets/track/modules/generated/{core,elevation,special}/`  
**Not generated this sprint** (stability first; no runtime import of a pilot kit).

Pilot IDs when Phase A stays clean and we choose to run Blender:

`start` `straight_medium` `curve_l_45` `curve_r_45` `finish`

Seam test: START → STRAIGHT → CURVE_L → CURVE_R → FINISH, ENTRY/EXIT aligned, 4WHEEL ray contact continuity (no vertical lip).
