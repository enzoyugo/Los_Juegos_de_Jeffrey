# TRACK MODULAR KIT PILOT V1

## Primary Verdict

**TRACK_MODULAR_KIT_PILOT_V1_READY_FOR_HUMAN_REVIEW**

Five original pilot pieces generate, import, assemble on exact ENTRY/EXIT, and stay planted at spawn and across the first modular seams under both BASELINE and 4WHEEL_V1. Render-resource stability did not regress. BASELINE remains canonical. The remaining 17 V1 modules were **not** generated.

Owner still drives `TrackModularKitPilotLab` for scale, curve fun, and visible-seam feel. This report does not answer those questions.

## Baseline

| Item | Value |
|---|---|
| Branch | `master` |
| HEAD | `f5b73e2` |
| Godot | 4.7.2.stable.official |
| GPU | NVIDIA GeForce RTX 2060 SUPER |
| Renderer | Forward+ / D3D12 |
| Pytest | **266 passed** (was 258) |
| Validator | `[JEFFREY_VALIDATE] OK` |
| Path scan | 176 refs, `required_missing=0` |
| Prior gate | `JEFFREY_RENDER_RESOURCE_STABILITY_V1_READY` preserved |
| Canonical controller | `CONTROLLER_MODE := "BASELINE"` |
| 4WHEEL | parallel only; A/B still **unblocked, not passed** |

## Generated Pieces

Exactly five. Authority: `data/track/modules/track_kit_v1.json`. Output: `res://assets/track/modules/generated/core/`

| piece_id | GLB | Spec | EXIT (local) |
|---|---|---|---|
| `start` | `track_start_v1.glb` | straight 8.0 m + START_MARKER + PLAYER_SPAWN | `(0,0,-8)` yaw 0 |
| `straight_medium` | `track_straight_medium_v1.glb` | **24.0 m** (20–35 m band) | `(0,0,-24)` yaw 0 |
| `curve_l_45` | `track_curve_l_45_v1.glb` | R=30 m, 45°, left | yaw **+45°** |
| `curve_r_45` | `track_curve_r_45_v1.glb` | R=30 m, 45°, right | yaw **−45°** |
| `finish` | `track_finish_v1.glb` | straight 8.0 m + FINISH_TRIGGER_ANCHOR | `(0,0,-8)` yaw 0 |

No other generated modules. `--all` exits 2.

## Blender Generator

Path: `scripts/blender/generate_track_kit_v1.py`

Authoring space is Godot (+Y up, −Z forward). Deterministic pure-Python GLB writer (bpy optional). Default is **pilot-only**.

| Class | Pilot role |
|---|---|
| `TrackKitConfig` | JSON contract |
| `TrackPieceBuilder` | dispatch |
| `StraightBuilder` | start / straight_medium / finish |
| `CurveBuilder` | true arc via shared `frame_at(..., direction)` |
| `ElevationBuilder` | stub, not implemented |
| `SpecialBuilder` | stub, not implemented |
| `GuardrailBuilder` | inner/center X from width+shoulder |
| `ConnectorBuilder` | ENTRY / EXIT / spawn / finish anchors |
| `UVBuilder` | V = centerline metres |
| `Exporter` | GLB + sidecar JSON |

Command:

```
python scripts/blender/generate_track_kit_v1.py --pilot
```

Optional: `--pieces start,straight_medium,curve_l_45,curve_r_45,finish`

Determinism: same config → same vertex counts, connector transforms, sidecar metadata. GLB binary may differ only if exporter metadata changes; topology is procedural from parameters. No embedded images.

## Dimensions

| Quantity | Value |
|---|---|
| Asphalt | 11.0 m |
| Shoulder | 0.7 m each side |
| Guardrail height | 0.9 m |
| Guardrail thickness | 0.22 m |
| Road thickness | 0.12 m (down from top Y=0) |
| Curve step | ~1.5 m |
| Collision overlap | 0.04 m |
| Seam tolerance | 0.0005 m (0.5 mm) |
| `straight_medium` | **24.0 m** (single canonical pilot length) |

Cross-section is identical on every pilot piece. Curve width is 11.0 m at every arc sample via perpendicular offset from centerline tangent.

## Connectors

ENTRY: local origin, forward −Z, up +Y, road X=0.

EXIT: centerline end + outgoing tangent. Next piece:

`next.global = prev.EXIT_global * inverse(next.ENTRY_local)`

No fudge offsets.

| Seam | Python math | Godot runtime | Validator |
|---|---|---|---|
| start → straight_medium | 0.0 m / 0° | 0.0 m / 0° | 0.0 m / 0° |
| straight_medium → curve_l_45 | 0.0 m / 0° | 0.0 m / 0° | 0.0 m / 0° |
| curve_l_45 → curve_r_45 | 0.0 m / 0° | 0.0 m / 0° | 0.0 m / 0° |
| curve_r_45 → finish | 0.0 m / 0° | 0.0 m / 0° | 0.0 m / 0° |

Measured error is floating-point exact 0.0 m (far below 0.5 mm). Spawn road ray hit **Y=0.0**.

## Materials

Shared greybox only. No new 4K. No per-piece atlas.

- `res://assets/track/materials/track_asphalt_v1.tres`
- `res://assets/track/materials/track_shoulder_v1.tres`
- `res://assets/track/materials/track_guardrail_v1.tres`
- `res://assets/track/materials/track_marker_v1.tres`

GLB slots: ROAD / SHOULDER / GUARDRAIL (+ START_FINISH on markers). Wrapper overrides to the shared `.tres`. Import: `gltf/embedded_image_handling=0`.

## Collision

Not visual trimesh.

- Straight / start / finish: one road BoxShape (width 12.4 m = 11.0 + 2×0.7 so shoulder contact stays ground) + two rail boxes.
- Curves: short boxes along the arc, overlap 0.04 m, aligned to local tangent.
- Rail boxes stay outside asphalt. Wheel ground casts use mask 1 and `MIN_GROUND_NORMAL_Y = 0.42`, so vertical rail faces are not ground.
- Road collision top = visual top = Y=0.

## Pilot Circuit

Scene: `res://scenes/debug/TrackModularKitPilotLab.tscn`

START → STRAIGHT_MEDIUM → CURVE_L_45 → CURVE_R_45 → FINISH

Wrapper: `res://scenes/track/modules/TrackPiece.tscn` + `scripts/track/track_piece.gd`  
Registry: `scripts/track/track_piece_registry.gd` (no scattered GLB paths)

Controls: WASD, Shift drift, C reset, F3 HUD, F4 collision/seam debug, F5 BASELINE ↔ 4WHEEL_V1.

Finish: Area3D across road width, no physics block. Optional timer vs sum of `estimated_traversal_time` = **2.85 s**.

PLAYER_SPAWN on start: `(0, 1.15, -2.6)` local.

## BASELINE Test

D3D12 autodrove smoke (`SSK_PILOT_SMOKE=1`, throttle held):

- Controller BASELINE
- Seams 0.0 m
- On floor at end (`grounded=1`)
- Reached `curve_r_45` (crossed start→straight, straight→L45, L45→R45)
- `[TRACK_SEAM_SPIKE]` count **0**
- Contact-loss events **0**
- `CreateResource` **0**

Did not reach FINISH in the short smoke window. Human lap still required.

## 4WHEEL Test

Same circuit, `SSK_TRACK_CONTROLLER=4WHEEL`:

- Spawn ray hit road at Y=0
- After settle: **4/4 wheels grounded**, chassis Y=0.014 m
- Autodrove reached `curve_l_45` (includes STRAIGHT→CURVE_L seam)
- End: **4/4 grounded**, spikes **0**, loss **0**
- Texture mem identical to BASELINE (61,595,648 B)
- Physics tunables **not** changed

## Wheel Contact Continuity

| Event | Automated result |
|---|---|
| Contact loss (all wheels ungrounded at seam) | none logged |
| Suspension compression spike at seam | none logged |
| Chassis vertical impulse flag | none logged |
| Spawn contact | 4/4 |

False airborne / seam spike while a human is driving is still a review item.

## Guardrail Behavior

Rails generated as original horizontal barriers outside shoulders. Collision is simple boxes following the same frames. Wheel-ground mask ignores steep rail normals. Automated smoke did not scrape rails. Human rail-scrape still required.

Start/finish: side rails only; center path open. No staging gap.

## Render Stability

| Check | Result |
|---|---|
| PilotLab BASELINE D3D12 | PASS, 0 CreateResource, 0 0x8007000e |
| PilotLab 4WHEEL D3D12 | PASS, same |
| TrackMain D3D12 | PASS |
| ZombiesMain D3D12 | PASS |
| JeffreyBoot (Smash host) D3D12 | PASS |
| Texture mem (pilot) | 61,595,648 B (~58.7 MiB) |
| Prior CASE H | ~61 MB; no new 4K |

Geometry added some video memory; texture residency did not jump.

## Tests

**266 passed.**

New: `tests/test_track_modular_kit_pilot_v1.py` (spec, 5 GLBs only, connectors, no images, true-arc + mirror, `--all` refused, shared materials, collision boxes, seam math, import discard).

Updated: `tests/test_render_resource_stability_v1.py` now requires the five named GLBs instead of forbidding generation.

## Validator

`validate_jeffrey_shell.gd` `_check_modular_kit_pilot`:

- kit contract 11.0 / 0.7 / 0.9
- five assets + shared materials + TrackPiece + lab
- assembled seams ≤ 0.5 mm
- collision nodes, shared material overrides
- PLAYER_SPAWN / FINISH_TRIGGER_ANCHOR / Area3D
- spawn ray + 4WHEEL 4/4 after settle
- `CONTROLLER_MODE` still BASELINE

Old gates kept. Output: `[JEFFREY_VALIDATE] OK`

## Human Review Required

Do **not** auto-answer:

1. Does road scale feel right?
2. Are curves wide enough?
3. Do rails feel safe?
4. Can you see/feel seams?
5. Does 4WHEEL stay planted across seams?
6. Does BASELINE behave differently?
7. Does curve radius feel fun?
8. Does the road already look like intended Track?

Lab: `res://scenes/debug/TrackModularKitPilotLab.tscn`  
Start BASELINE. F5 for 4WHEEL. F4 seam/collision overlays.

## Known Issues

- Autodrive smoke did not reach FINISH (process-frame budget vs high FPS). Contact logs cover spawn plus early seams, not a full timed lap.
- Estimated traversal sum 2.85 s is metadata only; no balance pass.
- `ElevationBuilder` / `SpecialBuilder` are stubs by design.
- Pre-existing Jeffrey persistence `user://` corrupt-save quarantine in CI still prints; not caused by this pilot.
- Windows pytest cache permission warning unchanged.

## Recommended Next Action

1. Human drive the 5-piece lab (BASELINE then 4WHEEL) and answer the eight questions.
2. If seams/contact/scale are approved, expand the remaining 17 V1 pieces from the same generator/config.
3. Do **not** promote 4WHEEL. Do not add themes. Do not copy archive geometry.

If any seam or rail defect appears in human drive: fix generator math, regenerate **only** the five pilot pieces, re-run this gate.
