# TRACK CAR ARTICULATED V3 ASSET INTEGRITY REPORT

## Primary Verdict

**TRACK_CAR_ARTICULATED_V3_READY_FOR_RUNTIME**

4WHEEL visual candidate is `track_car_base_v3_articulated_clean.glb`. BASELINE remains canonical. 4WHEEL is not promoted.

## Source Authority

- Path: `assets/vehicles/track/source/track_car_base_v1.glb`
- SHA256: `b1dd649b39b0c701ccb5b11062b7087579702caa930d8a0b436dd4d581e725af`
- Size: 4269248 bytes (unchanged)
- Source is immutable. V3 is built from source, not from V2.

## Human Defects

Frame-by-frame F6 of V2 showed:

1. Car visually backwards vs source-after-180°.
2. Wheel meshes with stray sheets/triangles.
3. Spin produced huge rotating black planes.
4. Center-delta tests still passed (dirty geo rotates around axle).
5. AIRBORNE_ENTER speed=0 spam.
6. Landing `max_f=18000` with `max_c=0`.
7. Chase camera lost landing context.
8. V2 leftover split verts (`r_max` ~0.47–0.49 local).

## Semantic Orientation

Authority is source visual after the known fused runtime yaw (180° Y), plus morphology (rear wing = high-Y +Z after canonical transform), plus authored `NOSE_MARKER` / `REAR_MARKER`.

Centroid-Z and FL/FR labels are **not** used.

After 180° Y:

- Source FRONT camera = bumper / headlights.
- V2 FRONT camera = wing / exhaust (FAIL).
- V3 FRONT camera = bumper / headlights (match).

`semantic_forward = NOSE_MARKER - REAR_MARKER ≈ (0, 0, -1)`.

## Why V2 Was Wrong

1. Blender `select_linked` after a loose torus capture stole body faces. Face vertices were not required to all sit in the wheel envelope.
2. Leftover split verts at ~0.47 m local (~2.1 m after VisualRoot scale 4.4086) became rotating sheets.
3. Z-flip vs true 180° Y plus centroid “nose” put the **wing** on −Z. Numeric `visual_fwd=(0,0,-1)` agreed with a backwards body.

## Source Topology

See iteration folders. Source fused mesh: 24633 verts imported in the V2 log; V3 face-owned 18169 triangles with 0 discarded.

## Split Algorithm V3

`scripts/blender/build_track_car_articulated_v3.py`

1. Parse source GLB.
2. Apply 180° Y: `(x,y,z) → (−x, y, −z)`, relabel wheels so FL stays −X/−Z.
3. Face-level ownership: a triangle is a wheel iff **all three** vertices lie in that axle envelope.
4. Connected-component reassignment only if centroid/max-r/AABB exceed the envelope (iteration 03 dropped the over-tight 0.72× radius steal).
5. Axle-centered wheel origins in export.
6. `NOSE_MARKER` / `REAR_MARKER` from bumper min-Z vs wing max-Z.
7. Geometry-only GLB (no images).
8. Hard fail on radius / AABB / long-face / spin-sweep gates.

## Face Ownership

See `docs/generated/TRACK_CAR_V3_MESH_OWNERSHIP.json`.

Source faces 18169 = Body 7655 + FL 2636 + FR 2568 + RL 2674 + RR 2636 + discarded 0.

## Body Integrity

Body retains nose, wing, cockpit, shell. FRONT body-only render shows the front of the car. Wheel wells are holes (articulation), not stolen body panels.

## FL / FR / RL / RR Integrity

| Wheel | faces | max_r (source) | AABB size | components | outliers | sweep |
| --- | --- | --- | --- | --- | --- | --- |
| FL | 2636 | 0.09491 | 0.057 × 0.168 × 0.186 | in-envelope islands | 0 | pass |
| FR | 2568 | ≤ 0.095 | compact | in-envelope | 0 | pass |
| RL | 2674 | ≤ 0.095 | compact | in-envelope | 0 | pass |
| RR | 2636 | ≤ 0.095 | compact | in-envelope | 0 | pass |

Runtime max radius ≤ 0.45 m after VisualRoot scale.

## Max Radius / AABBs / Components / Outliers

V2: FL max_r 0.472, AABB Z 0.65, stray components, long/thin faces, spin-sweep fail.

V3: all four under `MAX_WHEEL_RADIUS_SOURCE` ≈ 0.0953, no long faces, spin Δr = 0.

## Node Axes / Origins

+Y up, −Z semantic forward, +X wheel axle. Wheel node translation = axle. Mesh local origin ≈ axle. Node scale (1,1,1). No runtime Body 180°.

## Source vs V3 Visual Comparison

Iteration 03:

- `source_front` and `v3_front`: both front of car.
- `source_rear` and `v3_rear`: both rear of car.
- Isolated wheels rendered **along the axle** (LEFT view): circular tire/rim. Low-poly faceting is source quality.

## Spin Stress Test

24-sample spin sweep: radius invariant. Isolated 0/90/180/270° axle views remain compact. No V2-style sheet.

## Atlas / D3D12

V3 GLB has no embedded images. Import `gltf/embedded_image_handling=0`. Runtime still uses canonical shared JPEG atlas. Atlas architecture not changed.

Headless evidence: `loaded=true`, `4096x4096`, `unique=1`, `fallback=false`. No `0x8007000e`.

## Tests / Validator

New `tests/test_track_car_articulated_v3.py` (10 passed). Validator gates added: V3 path, semantic markers, compact radius, landing window, airborne reasons, jump zones, KEY_K.

`[JEFFREY_VALIDATE] OK`

## Iteration Count

1. V2 baseline — FAIL (harness + visual sheets + backwards body).
2. V3 first split — geometry gates pass; auditor FAIL (hub islands over-reassigned; wheel camera along Z).
3. Keep in-envelope islands; axle-view renders — PASS.

## Remaining Risks

- Source mesh is low-poly; tire silhouette is faceted, not a CAD circle.
- Inner fender verts near the envelope can sit on Body (correct).
- Human F6 of IntegrityLab + ExtendedPhysicsLab is still required.
- 4WHEEL is still parallel R&D. Do not promote.
