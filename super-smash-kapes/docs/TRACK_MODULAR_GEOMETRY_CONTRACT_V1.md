# TRACK MODULAR GEOMETRY CONTRACT V1

Long-term authoring authority for generated Track modules. Product dimensions live in `data/track/modules/track_kit_v1.json`. This document is the math.

Pilot implementation: `scripts/blender/generate_track_kit_v1.py`  
Runtime wrapper: `scripts/track/track_piece.gd`  
Piece metadata class: `scripts/track/track_piece_geometry_contract_v1.gd`

## Coordinate convention

| Axis | Meaning |
|---|---|
| +Y | up / road normal on flat pieces |
| −Z | forward along the road at ENTRY |
| X | lateral; road centerline X = 0; +X is right when looking forward |

ENTRY is the local origin with identity basis.

Godot space **is** the authoring space. GLB nodes use the same numbers.

## Road cross-section

From centerline, every normal piece:

```
X = - (5.5 + 0.7 + 0.22)   right-rail outer
    - (5.5 + 0.7)          left rail inner face  = −6.2
    - 5.5                  left asphalt edge
      0                    centerline
    + 5.5                  right asphalt edge
    + 6.2                  right rail inner face
```

| Band | Width | Top Y |
|---|---|---|
| Asphalt | 11.0 m | 0.0 |
| Shoulder L / R | 0.7 m each | 0.0 (no physical lip) |
| Guardrail | thickness 0.22 m, height 0.9 m | 0.0 … 0.9 |
| Slab thickness | 0.12 m | top 0.0, bottom −0.12 |

Do not give a piece its own width. Banked pieces may change +Y later; pilot is flat.

## Connector math

ENTRY local transform `E` is identity.

EXIT stores origin + yaw + pitch (roll unused). Flat yaw:

- forward_exit = (−sin(yaw), 0, −cos(yaw))
- up_exit = (0, 1, 0)

Assembly with **no offsets**:

```
G_next = G_prev_exit * inverse(E_next_local)
```

If `E_next_local` is identity, `G_next = G_prev_exit`.

Seam metric after assembly:

- position: `distance(prev.EXIT.origin, next.ENTRY.origin)`
- yaw: angle between EXIT −Z and ENTRY −Z
- up: angle between EXIT +Y and ENTRY +Y

Engineering tolerance: **≤ 0.0005 m** position, **≤ 0.05°** rotation. Pilot measured **0.0**.

## Curve math

Shared function, direction sign `s`:

- left: `s = +1` → EXIT yaw **+angle**
- right: `s = −1` → EXIT yaw **−angle**

Parameter `θ = angle * t`, `t ∈ [0, 1]`:

```
pos = ( s * R * (cos(θ) − 1),  0,  −R * sin(θ) )
fwd = ( −s * sin(θ),           0,  −cos(θ) )
right = ( cos(θ),              0,  −s * sin(θ) )
```

Centerline length = `R * angle_rad`.

Lane edges: `pos + right * lateral`. Asphalt edges at `lateral = ±5.5`. Width at every sample is 11.0 m. This is a true arc ribbon, not a rotated slab.

Tessellation: `ceil(length / curve_step_m)` with `curve_step_m = 1.5`, minimum 8 segments.

Pilot: `R = 30 m`, `angle = 45°`, length ≈ 23.562 m.

## UV scale

`u = lateral / width + 0.5`  
`v = along` (metres along centerline)

Straight and curve use the same metre repeat so asphalt will not stretch differently when textures arrive. No unique baked atlas per piece.

## Collision construction

Visual mesh is **not** the collider.

Road boxes:

- width = asphalt + both shoulders = 12.4 m (wheels on shoulder stay grounded)
- height = 0.12 m, center Y = −0.06 so **top = 0**
- length = segment length + 0.04 m overlap
- origin on the centerline sample; yaw = frame yaw

Curves: one box per arc step, not one giant AABB.

Rails: box thickness 0.22, height 0.9, center at `±(5.5 + 0.7 + 0.11)`, same yaw as the road segment. Layer 1. Wheel `RayCast3D` mask 1 with `MIN_GROUND_NORMAL_Y = 0.42` rejects vertical rail faces as ground.

## Seam tolerance

| Kind | Limit | Pilot |
|---|---|---|
| Connector position | 0.0005 m | 0.0 m |
| Yaw / up | 0.05° | 0.0° |
| Visual / collision top Y | same authority (0.0) | spawn ray Y=0.0 |
| Manual Y fudge | forbidden | none |

If a seam is wrong, fix `frame_at` / EXIT, then regenerate only the affected pieces. Do not patch in the assembler.

## Functional markers

| Name | Piece | Local |
|---|---|---|
| ENTRY | all | origin |
| EXIT | all | end frame |
| START_MARKER | start | `(0, 0.02, -1.2)` |
| PLAYER_SPAWN | start | `(0, 1.15, -2.6)` |
| FINISH_TRIGGER_ANCHOR | finish | `(0, 0.5, -(length-1.5))` |

Finish trigger is an Area3D spanning road width. It must not block the car.

## Boost semantics (Track-only, shared)

`apply_track_boost(direction, magnitude)`:

- **on Area3D enter** of `boost_straight` (not per physics frame)
- ignores re-entry while a pulse is already active (`timer > 0.08 s`)
- pulse lasts **0.55 s**
- direction = assembled piece −Z, **Y planarized** so boost cannot launch vertically
- BASELINE: extra along-track accel (`ACCEL * 0.55 * mag * delta`)
- 4WHEEL: bounded central force (`ENGINE_FORCE * 0.85 * mag`) at chassis COM

`B` toggles `TrackPiece.boost_gameplay_enabled` without removing the Area3D.

## Pitch / elevation connectors

EXIT stores origin + yaw + **pitch** + up. Do not pretend a pitched exit is flat.

```
G_next = G_prev_exit * inverse(E_next_local)
```

If `E_next.pitch == prev.EXIT.pitch`, the next piece sits so its local geometry continues the slope. A gap module may have ENTRY on the takeoff side and EXIT on the landing side with **no continuous road** between. Metadata `has_gap=true` means missing mid-span collision is intentional, not a broken seam.

## Ramp profile (`ramp_small`)

Not a sudden wedge. Cubic Hermite with tangent continuity at entry:

```
y(0)=0,  y'(0)=0
y(1)=H,  y'(1)=tan(launch_angle) * L
y(t) = (−2t³ + 3t²) H + (t³ − t²) m1
m1 = tan(launch_angle) * L
pitch(t) = atan((dy/dt) / L)
fwd = (0, sin(pitch), −cos(pitch))
up  = (0, cos(pitch),  sin(pitch))
```

Collision: one pitched BoxShape3D per sample (same overlap as curves). Top of each box matches the visual surface. Rails follow the profile. `MIN_GROUND_NORMAL_Y` still rejects vertical rail faces.

## Jump semantics (`jump_small`)

- short pitched **lip** (takeoff), ENTRY pitch matches preceding ramp EXIT
- **gap** with `solid = false` and `has_gap=true` — no road/rail collision, no invisible floor
- **landing** deck slightly below takeoff (`landing_drop_m`), wide, flat, no vertical lip

Airborne is a natural ray miss, not a forced state.

## Originality

Geometry is parametric from this contract. Archive previews were taxonomy only. Do not copy Trackmania meshes, textures, logos, or decorative layouts.
