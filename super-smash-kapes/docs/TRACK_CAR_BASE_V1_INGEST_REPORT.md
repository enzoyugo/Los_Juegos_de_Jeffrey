# TRACK CAR BASE V1 INGEST REPORT

## Primary Verdict

TRACK_CAR_BASE_V1_INGEST_READY_FOR_HUMAN_REVIEW

Not: FINAL_CAR_APPROVED.

TRACK_CAR_BASE_V1_INGEST_IMPLEMENTED
HUMAN_VISUAL_REVIEW_REQUIRED

## Source

| Field | Value |
|---|---|
| path | `res://assets/vehicles/track/source/track_car_base_v1.glb` |
| format | glTF 2.0 binary (GLB) |
| generator | Tripo |
| size | 4,269,248 bytes |
| sha256 | `b1dd649b39b0c701ccb5b11062b7087579702caa930d8a0b436dd4d581e725af` |
| mutated this sprint | **no** |

Source is treated as immutable. No overwrite, no Blender round-trip, no processed clean GLB.

## Geometry

Parsed from the GLB JSON/BIN (not guessed from names):

| Metric | Count |
|---|---|
| root nodes | 1 (`tripo_node_c2bb5c22-98c6-4f70-a0ad-66c0b3f39c24`) |
| meshes | 1 (`meshes[0]`, one TRIANGLES primitive) |
| vertices | 24,633 |
| indices | 54,507 |
| triangles | 18,169 |
| materials | 1 (PBR, metallic 0, roughness 0.5, double-sided) |
| textures / images | 1 JPEG atlas, 4096×4096, ~3.26 MB, name `Modelo+3D+de+coche+de+carreras_basecolor.jpg` |
| skins / skeleton | 0 |
| animations | 0 |
| extras / helpers | none |
| extensions used | `KHR_materials_volume`, `FB_ngon_encoding` |

Connected-component analysis of the triangle soup found **3818** vertex islands (largest 272 verts). This is a fused Tripo bake, not a named vehicle hierarchy.

## Scale

| | X (width) | Y (height) | Z (length) |
|---|---|---|---|
| source AABB | 0.486 m | 0.322 m | 0.998 m |
| source origin | X/Z centered, Y=0 at ground | | |
| runtime (× VISUAL_SCALE) | ~2.14 m | ~1.42 m | **4.40 m** |

`VISUAL_SCALE = 4.4 / 0.998046875 ≈ 4.4086`

Target arcade window was length 4.0–4.8, width 1.8–2.2, height 1.2–1.6. Proportions fit after a single uniform scale. No extra nested mesh scales.

**Scale authority:** `TrackCarVisualConfig.VISUAL_SCALE` applied only on `VisualRoot`. Import `nodes/root_scale=1.0`.

Estimated wheelbase after scale ≈ 2.61 m. Estimated wheel radius ≈ 0.35 m.

## Orientation

glTF / Godot Y-up.

| Axis | Source model | Track controller |
|---|---|---|
| up | +Y | +Y |
| right | +X | +X |
| nose / forward | **+Z** (low nose, high wing at −Z) | **−Z** (`forward := -basis.z`) |

Mirrored: no evidence of a negative-scale import.

**Correction:** one `VisualRoot` yaw of **180°** so the nose faces gameplay forward. No hidden per-mesh rotations.

W + throttle → car moves along controller −Z, nose faces that direction.

## Hierarchy

Imported instance (after Godot scene import; names may be shortened):

```
ImportedCar (Node3D, glTF root)
 └── tripo_node_… (MeshInstance3D)
```

Runtime wrapper:

```
TrackCar (CharacterBody3D, TrackCarController)
 ├── CollisionShape3D          BoxShape3D 1.80 × 0.82 × 3.55 at (0, 0.48, 0)
 ├── VisualRoot (TrackCarVisual)
 │    ├── ImportedCar          source GLB instance
 │    └── WheelPivot*          debug markers only
 ├── CameraAnchor              (0, 0.85, 0)
 ├── DriverHeadAnchor          (0, 1.15, 0.35)
 ├── CharacterMount            (0, 0.95, 0.35)
 └── ColliderDebug             hidden box overlay
```

## Wheels

**WHEEL_STRUCTURE = FUSED_BODY_MESH**

Not separate nodes. Not separate surfaces (single primitive / single material).

Wheel-like vertex clusters exist near the ground at four corners, but they are not topologically separable without a manual Blender isolation. Automatic split was rejected as unsafe (thousands of disconnected islands, shared atlas UVs).

**WHEEL_ARTICULATION_BLOCKED_BY_SOURCE_MESH**
**VISUAL_WHEEL_STEERING_DEFERRED**

Documented mapping in source-local units (before VisualRoot yaw/scale):

| Wheel | Source local center |
|---|---|
| FL | (-0.201, 0.085, 0.285) |
| FR | ( 0.204, 0.085, 0.285) |
| RL | (-0.202, 0.085, -0.298) |
| RR | ( 0.203, 0.085, -0.298) |

Debug sphere markers are created at those points. They do not drive mesh deformation.

## Pivots

Source object origin is ground-center of the footprint (Y=0, X/Z centered) — usable as a vehicle COM reference.

Wheel mesh pivots cannot be validated as independent objects because wheels are fused. Debug `WheelPivot*` nodes sit at estimated wheel centers for a future clean GLB.

## Collider

| Field | Value |
|---|---|
| type | `BoxShape3D` only |
| size | 1.80 × 0.82 × 3.55 m |
| placement | (0, 0.48, 0) on the controller |
| visual mesh as collider | **no** |
| trimesh / convex decomp of body | **no** |

The box sits inside the visual chassis: not spoiler, not mirrors, not tire shells. Ingest lab F1 shows the preview. Physics lab F4 toggles `ColliderDebug`.

CharacterBody3D is kinematic (no RigidBody COM). Gameplay COM was not changed.

## Runtime Wrapper

`res://scenes/track/TrackCar.tscn` is the runtime authority.

Gameplay scenes instantiate this packed scene. They do not instance the raw `.glb` as a physics body.

## Controller Integration

Existing `TrackCarController` handling is unchanged (accel, steer, grip, drift, brake, yaw).

The controller now:

- instantiates via `TrackCar.tscn` from TrackMain and TrackPhysicsLab
- skips greybox mesh construction when `VisualRoot` / `CollisionShape3D` are present
- drives `TrackCarVisual.apply_motion` for future wheel nodes only
- exposes `camera_target()`, `set_character_visual()`, `set_player_accent()`
- resets visual motion on checkpoint/start reset

Greybox procedural mesh remains as a fallback if the scene is missing.

## Wheel Steering

Deferred. Front-wheel yaw would require `SEPARATE_NODES`. Steering input still affects the controller; it is not applied to the fused body mesh.

## Wheel Spin

Deferred for the same reason. Spin angle is accumulated internally (`forward_speed / wheel_radius`) so a future clean GLB can consume it. The body mesh is never spun.

## Center of Mass / Visual Offset

`VISUAL_OFFSET = (0, 0.05, 0)` — slight lift so scaled wheel bottoms sit near the box collider floor.

Visual chassis is centered on the controller origin in XZ. Highest geometry (wing) is at the tail (−Z in source, +Z after the 180° yaw, which is behind the driver in Godot). Turns still rotate about the CharacterBody origin; that origin was not moved.

Human drive review should check: too high / too low / nose-heavy / spoiler-in-camera.

## Camera

Chase camera still uses Track V2 follow, with framing tweaks for the larger visual volume:

| | previous V2 | this ingest |
|---|---|---|
| CAM_DISTANCE | 7.0 | 8.4 |
| CAM_HEIGHT | 2.35 | 2.55 |
| CAM_LOOK_AHEAD | 15.0 | 16.5 |
| FOV | 70–86 | unchanged |

Target is `CameraAnchor` (controller child), not an imported mesh. Speed/FOV still reads the parent `CharacterBody3D` velocity.

Acceptance (needs human eyes at speed): car in lower-center frame, road ahead visible, spoiler not blocking LOS, camera not clipping cabin.

## Driver Anchor

`DriverHeadAnchor` at (0, 1.15, 0.35) — cabin, slightly rearward of origin, head height.

`CharacterMount` at (0, 0.95, 0.35) for future upper-torso.

`set_character_visual(character_id)` stores the id and does not spawn a head this sprint.

Chase-camera visibility of a future head: likely a small silhouette in the cabin; not verified with a character mesh.

## Materials

One atlas, one material. Body paint, glass, rubber, and metal share the 4096 JPEG.

**Customization feasibility:** not separable by slot. Future body/accent/number/branding/damage cannot be independent materials without a processed mesh or atlas masks.

Hooks prepared (no final livery):

- `assets/vehicles/track/materials/track_car_body_v1.tres` — tint template
- `assets/vehicles/track/materials/track_car_ghost_v1.tres` — transparent/emissive ghost
- runtime `set_player_accent(Color)` duplicates the imported material and multiplies `albedo_color`

Source materials were not edited.

## Ghost Compatibility

`TrackGhostPlayer` remains a `Node3D`. It instances `TrackCarVisual` with `ghost_mode=true`:

- transform playback only
- no CharacterBody
- imported collision stripped / disabled
- ghost material override applied

Alive-player ghosts in Hotseat still spawn from `TrackMain._spawn_ghosts` as before.

## Performance

| Item | Value |
|---|---|
| verts / tris | 24,633 / 18,169 |
| materials | 1 |
| texture | 4096² JPEG |
| LOD | none (not required for 1 car + few ghosts) |
| draw calls | one mesh per car/ghost instance |

No premature decimate. FPS impact is for human lab review; headless cannot certify frame time.

## Processed Asset

**Not created.**

A `processed/` folder exists as a placeholder only. Wheel separation was not topologically safe. Orientation and scale are runtime VisualRoot transforms, which is the single authority layer.

## Tests

**108 passed** (pytest suite: Smash combat, Jeffrey shell/UI, Track greybox, Track game-feel, Track car ingest, Zombies greybox).

New file: `tests/test_track_car_base_v1_ingest.py` (5 tests). Existing tests were not deleted.

Generator diversity (validator): **20 unique signatures / 20 seeds**.

## Validator

`[JEFFREY_VALIDATE] OK`

Godot 4.7.2 headless, `--rendering-method gl_compatibility --audio-driver Dummy`.

Expected CI `push_error` for corrupt-save recovery remains (`save corrupt — backup written… starting clean`).

Headless boots (2s, no script errors):

- `res://scenes/debug/TrackCarIngestLab.tscn`
- `res://scenes/debug/TrackPhysicsLab.tscn`
- `res://scenes/track/TrackMain.tscn`

Smash hosted playground still instantiates 2 fighters, stocks 3, spawn positions unchanged. `ZombiesMain.tscn` still present (not instantiated; mouse capture).

## Known Issues

- Front-wheel steering and wheel spin are blocked by fused source mesh.
- Paint customization is blocked by a single atlas.
- Camera / COM / spoiler framing need a human at speed.
- D3D12 `0x8007000e` from a prior Track session is not attributed to this ingest; validator still uses `gl_compatibility`.

## Human Review Required

Drive TrackPhysicsLab then a procedural TrackMain run:

1. Nose faces W / reverse faces S.
2. Car scale vs greybox road.
3. Collider vs visual overlap (F4 in lab).
4. Chase camera: road ahead, spoiler, clip.
5. Ghosts look like the car, no extra physics.
6. Reset / checkpoint does not leave a stale visual.

Do not treat this as final car approval.

## Recommended Next Action

After human approval: **TRACK_CAR_VISUAL_POLISH_V1**

Suggested polish order:

1. Optional Blender `track_car_base_v1_clean.glb` with named body + four wheels and centered wheel pivots.
2. Then visual steer/spin.
3. Then material splits or atlas masks for accent paint.
4. Then character head on `DriverHeadAnchor`.
