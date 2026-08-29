# Track car articulated V2

Source remains immutable. This is a processed split only.

## Source

- `res://assets/vehicles/track/source/track_car_base_v1.glb`
- SHA256 `b1dd649b39b0c701ccb5b11062b7087579702caa930d8a0b436dd4d581e725af`
- 4,269,248 bytes
- Not overwritten

## Processed

- `res://assets/vehicles/track/processed/track_car_base_v2_articulated.glb`
- ~4,177,552 bytes
- 5 mesh nodes, 1 material, 1 embedded 4K atlas (JPEG), 1 texture
- Nodes: `Body`, `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR`

## Wheel separation

Blender 2.83, non-destructive working copy of the source GLB.

glTF import is Z-up in Blender: `(x, y, z)_glTF → (x, z, y)_blender`.

Spatial torus capture around measured axle centers (not blind island split):

| Wheel | Blender capture center (X, Y, Z) |
| --- | --- |
| FL | (-0.201, 0.285, 0.085) |
| FR | (0.204, 0.285, 0.085) |
| RL | (-0.202, -0.298, 0.085) |
| RR | (0.203, -0.298, 0.085) |

Tire torus: major radius 0.070 m, tube 0.018 m, half-width 0.034 m, then `select_linked` and keep verts within 0.105 m of the axle.

A looser sphere overlapped the body (select_linked exploded). The tight torus stayed on tire islands (~1650 → ~2300 verts after linked rim/hub).

Vert counts after split (sum 24633, same as source):

| Object | Verts |
| --- | --- |
| Body | 15153 |
| Wheel_FL | 2425 |
| Wheel_FR | 2288 |
| Wheel_RL | 2427 |
| Wheel_RR | 2340 |

## UV / material

- No UV rebuild
- Single shared material / atlas kept
- Export warning: some zero-length tangents (pre-existing density, not a new atlas)

## Origins / axes

Each wheel origin is the axle center.

After Blender glTF round-trip the processed file is **Y-up, −Z nose** (source was +Z nose). VisualRoot must **not** apply the source 180° yaw on this file.

Processed node translations (glTF Y-up):

| Wheel | Translation |
| --- | --- |
| FL | (-0.201, 0.085, -0.285) |
| FR | (0.204, 0.085, -0.285) |
| RL | (-0.202, 0.085, 0.298) |
| RR | (0.203, 0.085, 0.298) |

Local axes (processed / Godot chassis):

- **Steer:** +Y (up)
- **Spin:** +X (axle)
- **Forward:** −Z

Godot visual hierarchy after ingest:

`WheelMount / SteerPivot / SuspensionPivot / SpinPivot / WheelMesh`

Godot import: `track_car_base_v2_articulated.glb.import` with `gltf/embedded_image_handling=3` (embed uncompressed). Do not extract a second 4K JPEG sidecar.

## Chassis mounts (VisualRoot scale + offset, no extra yaw)

`VISUAL_SCALE = 4.4 / 0.998046875 ≈ 4.4086`, offset `(0, 0.05, 0)`

| Wheel | Chassis position (m) |
| --- | --- |
| FL | (-0.886, 0.425, -1.256) |
| FR | (0.899, 0.425, -1.256) |
| RL | (-0.891, 0.425, 1.314) |
| RR | (0.895, 0.425, 1.314) |

Radius ≈ 0.35 m after scale.

## Ingest lab

Key 1 = raw source, 2 = fused runtime, 3 = articulated processed.

Keys 6 / 7 / 8 = visual-only steer / spin / suspension on the articulated preview.
