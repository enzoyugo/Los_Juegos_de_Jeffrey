# V5 Rig Ingest and Native Articulation Report

## Primary Verdict

**SSK_V5_RIG_INGEST_READY_FOR_HUMAN_PLAYTEST**

Both V5 fighters imported, passed native articulation, preserved bind space without the old AccuRIG Rx-90 reconstruction, exported clean `.blend` / `.glb` authorities, survived GLB roundtrip, and loaded in isolated Godot labs with no `source_rigged_v5` import noise.

V5 is **not** canonical. Human visual inspection is still required. Do **not** auto-promote over Clean Rig V1.

Automated gates (both fighters):

| Gate | Jaguareté | Tereré |
|---|---|---|
| Source import | pass | pass |
| Hierarchy sane | pass | pass |
| Native articulation | pass | pass |
| Fingers present and follow | pass | pass (no ring) |
| No cross-side deformation | pass | pass |
| Clean `.blend` | pass | pass |
| GLB roundtrip | pass | pass |
| Godot lab load | pass | pass |
| Source import noise | none | none |

## Source Inventory

`.gdignore` now exists at `assets/fighters/source_rigged_v5/.gdignore`. Raw V5 FBX was not moved. Godot imported only `clean_rig_v5/*.glb`.

Authoring textures are **missing on disk**. JSON `Textures` / `Resource Textures` are empty. `.fbm` folders and `textures/` trees exist but contain **zero files**. Materials are untextured PBR (Tripo node names).

| | Jaguareté | Tereré |
|---|---|---|
| FBX | `assets/fighters/source_rigged_v5/Jaguarete/jaguarete_rigged_v5.fbx` | `assets/fighters/source_rigged_v5/terere/terere_rigged_v5.fbx` |
| JSON | `jaguarete_rigged_v5.json` | `terere_rigged_v5.json` |
| FBX size | 22,926,672 | 14,611,920 |
| SHA256 | `730263d6…e2804b0b` | `a219c9b0…e44387b` |
| Vertices | 22,492 | 26,352 |
| Materials | 1 | 1 |
| Skeletons | 1 | 1 |
| Collision bones (JSON) | 118 | 102 |
| Texture files | 0 | 0 |

Full dump: `docs/generated/V5_SOURCE_INVENTORY.json`.

## Jaguareté V5 Structure

- Objects: `Armature` + `meshes_0_`
- 1 mesh, 1 armature, **118 bones**, all `use_deform=true`
- 61 vertex groups (IK / facial bones have no weights)
- Max influences **6**, unweighted verts **0**
- 1 untextured PBR material (`tripo_node_fb7d2ebd_…`)
- Facial shapekeys present (expression set); rest values forced to 0
- Native world height ≈ **1.02 m** (catalog target 3.15 is not applied)

Dump: `docs/generated/V5_JAGUARETE_RIG_AUDIT.json`.

## Tereré V5 Structure

- Objects: `Armature` + `meshes_0_`
- 1 mesh, 1 armature, **102 bones**, all deform
- 52 vertex groups
- Max influences **6**, unweighted verts **0**
- 1 untextured PBR material (`tripo_node_c9f1418c_…`)
- Same facial shapekey set
- Native world height ≈ **1.00 m** (catalog target 2.40 is not applied)

Dump: `docs/generated/V5_TERERE_RIG_AUDIT.json`.

## Orientation / Bind Space

**V5_BIND_SPACE_CLEAN** for both.

Unlike Clean Rig V1, V5 does **not** land as Armature Rx+90 * 0.01 with mesh Rx-90. After FBX import:

- Armature: location 0, rotation 0, uniform scale **0.01**
- Mesh: parented to Armature, local identity, parent inverse identity
- `A^-1 * M` is identity (mesh and bones share object space)
- Head above hips, feet below hips, character upright in Blender Z-up
- Rest armature-modifier error **0.0** before and after clean bake

Classification is **not** the old compensated AccuRIG bind.

## Semantic Bone Map

Primary controls are UE-style names. Twist / share / IK / `CC_Base_*` helpers were **not** used as main test bones.

| Semantic | Jaguareté | Tereré |
|---|---|---|
| PELVIS | `pelvis` | `pelvis` |
| SPINE / CHEST | `spine_01` / `spine_03` | `spine_01` / `spine_03` |
| NECK / HEAD | `neck_01` / `head` | `neck_01` / `head` |
| LEFT_UPPERARM | `upperarm_l` | `upperarm_l` |
| LEFT_FOREARM | `lowerarm_l` | `lowerarm_l` |
| LEFT_HAND | `hand_l` | `hand_l` |
| LEFT_THIGH / CALF / FOOT | `thigh_l` / `calf_l` / `foot_l` | same |
| LEFT_BALL | `ball_l` | `ball_l` |
| LEFT_INDEX_01 | `index_01_l` | `index_01_l` |
| LEFT_RING_01 | `ring_01_l` | **missing** |
| LEFT_THUMB_01 | `thumb_01_l` | `thumb_01_l` |

Dump: `docs/generated/V5_SEMANTIC_BONE_MAP.json`.

## Main Hierarchy

Connected flag is **not** required. Parenting with offset is used and accepted.

Jaguareté:

```
root → pelvis → spine_01 → spine_02 → spine_03 → spine_04 → spine_05
  spine_05 → clavicle_l → upperarm_l → lowerarm_l → hand_l
  spine_05 → neck_01 → neck_02 → head
  pelvis → thigh_l → calf_l → foot_l → ball_l
```

Tereré:

```
root → pelvis → spine_01 → spine_02 → spine_03
  spine_03 → clavicle_l → upperarm_l → lowerarm_l → hand_l
  spine_03 → neck_01 → head
  pelvis → thigh_l → calf_l → foot_l → ball_l
```

`head` rest length is ~0.0001 (AccuRIG leaf). Position is still above the neck.

Dump: `docs/generated/V5_BONE_HIERARCHY.json`.

## Finger Hierarchy

Jaguareté is the more complete hand:

- Metacarpals + index / middle / ring / pinky / thumb 01–03
- `index_01_l` parent = `index_metacarpal_l`

Tereré:

- Index / middle / pinky / thumb 01–03
- **No ring chain**
- **No metacarpals** (`index_01_l` parent = `hand_l`)

This is the largest structural gap versus Clean Rig V1 (V1 had ring 1–3 on both fighters).

## Native Arm Articulation

Copies only. No Mixamo.

| Test | Jaguareté | Tereré |
|---|---|---|
| upperarm 30° / 60° | forearm, hand, fingers follow | same |
| forearm 45° / 90° | hand, fingers follow | same |
| wrist mild | index follows | same |
| Opposite hand | 0 travel | 0 travel |
| Mesh explosion | none | none |

## Native Hand Articulation

| Test | Jaguareté | Tereré |
|---|---|---|
| index bend | 02/03 follow; middle unaffected | same |
| middle bend | 02/03 follow; index unaffected | same |
| thumb bend | 02/03 follow | same |
| all-fingers mild curl | pass | pass |

## Native Leg Articulation

| Test | Jaguareté | Tereré |
|---|---|---|
| thigh 30° / 45° | calf, foot follow | same |
| calf 60° / 90° | foot follows | same |
| foot mild | ball follows | same |
| Opposite foot | 0 travel | 0 travel |

This is an improvement vs V1, where posing `CC_Base_*_Calf` often did nothing because weights lived on twist bones.

## Torso / Head Articulation

Spine pitch / yaw and head yaw / pitch passed on both. Head follows spine. No mesh explosion.

## Weight Quality

Major reweighting was **not** required. No zero-weight gaps. No genuine left/right group inversion.

Observed AccuRIG helper pattern (informational, not a stop):

- Shoulder / hip neighborhoods often list twist bones (`cc_base_l_upperarmtwist01`, `upperarm_twist_01_l`, `cc_base_l_thightwist01`) ahead of `upperarm_l` / `thigh_l`
- Wrist / ankle / fingers have usable primary groups (`hand_l`, `foot_l`, `index_01_l`, …)
- Elbow / knee bone-head samples can be sparse because weights sit along the shaft / twist bones; posing `lowerarm_l` / `calf_l` still deforms the limb

No weights were repainted.

## Left / Right Validation

Anatomical left is **+X** in this bind (same convention as Clean Rig V1).

Bone world X and weighted-vertex centroids keep the same order for upperarm, hand, thigh, foot, and index. No genuine L/R inversion.

Godot (Y-up) confirms: `hand_l.x > 0`, `hand_r.x < 0`.

## Deformation Metrics

Guardrails only. Visual still wins.

Native + post-clean suites: **18/18 pass** both fighters after the shapekey-safe bake.

GLB subset (upperarm 45°, forearm 90°, thigh 30°, calf 90°): pass, no material volume divergence vs `.blend`.

Blender 2.83 glTF warning on both exports:

> There are more than 4 joint vertex influences. The 4 with highest weight will be used (and normalized).

| | Blend max influences | GLB max influences |
|---|---|---|
| Both fighters | 6 | **4 (clamped)** |

`.blend` weights were **not** edited to match GLB.

Dump: `docs/generated/V5_NATIVE_ARTICULATION_METRICS.json`.

## Normalization Decision

**V5_NATIVE_BIND_PRESERVED**

V1 Rx-90 bind reconstruction was **not** applied. V5 already had mesh and skeleton in the same object space.

Only a uniform FBX 0.01 scale bake into mesh/armature **data** was used, including shapekeys, so object bases are identity. Skipping shapekeys in that bake previously produced rest error ~100 (cm keys vs meter verts). After the fix, rest error is **0.0**.

Feet were already at Z≈0. No extra floor reconstruction.

## Clean Blender Authorities

| Fighter | Blend | GLB |
|---|---|---|
| Jaguareté | `assets/fighters/processed/clean_rig_v5/jaguarete/jaguarete_clean_rig_v5.blend` (29,309,236) | `.glb` 51,041,956 SHA256 `92793792…79967337` |
| Tereré | `assets/fighters/processed/clean_rig_v5/terere/terere_clean_rig_v5.blend` (34,110,368) | `.glb` 59,865,508 SHA256 `aab76c1e…b93bedc` |

Requirements met:

- Upright, mesh + skeleton aligned
- Identity object transforms after scale bake
- Original V5 weights preserved
- No animation clips, no Mixamo, no V1 pose data
- GLB size is large because facial shapekeys were kept (not stripped)

## GLB Roundtrip

Fresh Blender scene, `import_scene.gltf`:

| | Jaguareté | Tereré |
|---|---|---|
| Skeleton | yes, 118 bones | yes, 102 bones |
| Mesh | yes | yes |
| Upright | yes | yes |
| Hierarchy | preserved | preserved |
| Articulation subset | pass | pass |
| Deformation vs blend | no material diff | no material diff |
| Influences | clamped to 4 | clamped to 4 |

Materials exist as the same untextured PBR. There were no maps to lose.

## V5 vs Clean Rig V1

Rig quality only. No animation comparison.

| | Clean Rig V1 | Clean Rig V5 |
|---|---|---|
| Bind space | compensated Rx90 * 0.01 | **clean**, same object space |
| Normalization | required (strategy C) | **not required** (preserve native) |
| Jaguareté bones | 101 | **118** |
| Tereré bones | 101 | 102 |
| Finger names | `CC_Base_*` | UE `index_01_l` … |
| Jaguareté fingers | I/M/R/P/T 1–3 | I/M/R/P/T 1–3 **+ metacarpals** |
| Tereré fingers | I/M/R/P/T 1–3 | I/M/P/T 1–3, **no ring** |
| Calf posing | often dead (twist weights) | **calf_l follows** |
| Max influences | 6 → GLB 4 | 6 → GLB 4 |
| Textures | packed AccuRIG PBR | **none in source** |
| Native height | AccuRIG meters | AccuRIG meters (~1 m) |
| GLB roundtrip | pass | pass |

V5 is cleaner to ingest. It is not automatically a better production fighter until Idle/Reaction retarget is tested, textures are restored, and Tereré’s missing ring is accepted or fixed.

Dump: `docs/generated/V5_VS_CLEAN_RIG_V1_COMPARISON.json`.

## Godot V5 Labs

Standalone scripts. They do **not** inherit production / semantic / battle / HUD labs.

| | Scene | Script | GLB |
|---|---|---|---|
| Jaguareté | `scenes/debug/JaguareteCleanRigV5Lab.tscn` | `scripts/debug/jaguarete_clean_rig_v5_lab.gd` | `clean_rig_v5/jaguarete/jaguarete_clean_rig_v5.glb` |
| Tereré | `scenes/debug/TerereCleanRigV5Lab.tscn` | `scripts/debug/terere_clean_rig_v5_lab.gd` | `clean_rig_v5/terere/terere_clean_rig_v5.glb` |

Root: WorldEnvironment, DirectionalLight3D, Camera3D, Floor, ModelRoot (instanced GLB), Overlay.

Controls: **1** mesh, **2** skeleton, **3** bbox, **4** reset camera, RMB orbit, wheel zoom.

Overlay: `fighter | pipeline=V5 | bone_count | mesh_count | animation_count=0 | GLB | fallback=false`.

Launcher: `tools/launch_clean_rig_v5.ps1 -Fighter jaguarete|terere`.

Headless validator: `scenes/debug/ValidateCleanRigV5Labs.tscn` → `all_ok=true`.

## Runtime Validation

Standalone: `--rendering-method gl_compatibility --audio-driver Dummy`.

| | Jaguareté | Tereré |
|---|---|---|
| Window alive ≥62 s | yes | yes |
| Renderer | OpenGL 3.3 / RTX 2060 SUPER | same |
| load_ok | true | true |
| fallback | false | false |
| SCRIPT ERROR | none | none |
| Per-frame errors | none | none |
| Visible / upright | yes (head.y > hip.y, feet below) | yes |
| Scale | native ~0.78 m head height | native ~0.47 m head height |
| animation_count | 0 | 0 |

Dump: `docs/generated/CLEAN_RIG_V5_GODOT_LAB_VALIDATION.json`, `docs/generated/V5_GODOT_RUNTIME_VALIDATION.json`.

## Human Validation Required

Do not mark V5 canonical from this report. Inspect in the labs:

Jaguareté

- Skeleton physically inside the mesh
- Fingers segmented (incl. ring + metacarpals)
- Wrist / elbow / knee / foot alignment

Tereré

- Same checks
- Confirm missing ring is acceptable
- Confirm short native proportions vs catalog 2.40

Both: untextured gray PBR is expected until maps exist.

## Production Safety

Untouched:

- Clean Rig V1
- `source_rigged` (old AccuRIG)
- Approved Tereré / Jaguareté idle
- Reaction V1 / V1.1
- Battle
- FighterCatalog
- Production V4
- Mixamo / animation retarget

V5 is an isolated candidate under `processed/clean_rig_v5/` and `scenes/debug/*CleanRigV5Lab.tscn`.

## Files Created

- `assets/fighters/source_rigged_v5/.gdignore`
- `tools/blender/v5_rig_ingest.py`
- `tools/launch_clean_rig_v5.ps1`
- `scripts/debug/clean_rig_v5_lab.gd` (+ fighter wrappers + validator)
- `scenes/debug/JaguareteCleanRigV5Lab.tscn`
- `scenes/debug/TerereCleanRigV5Lab.tscn`
- `scenes/debug/ValidateCleanRigV5Labs.tscn`
- `assets/fighters/processed/clean_rig_v5/jaguarete/jaguarete_clean_rig_v5.blend`
- `assets/fighters/processed/clean_rig_v5/jaguarete/jaguarete_clean_rig_v5.glb`
- `assets/fighters/processed/clean_rig_v5/terere/terere_clean_rig_v5.blend`
- `assets/fighters/processed/clean_rig_v5/terere/terere_clean_rig_v5.glb`
- `docs/generated/V5_SOURCE_INVENTORY.json`
- `docs/generated/V5_JAGUARETE_RIG_AUDIT.json`
- `docs/generated/V5_TERERE_RIG_AUDIT.json`
- `docs/generated/V5_BONE_HIERARCHY.json`
- `docs/generated/V5_SEMANTIC_BONE_MAP.json`
- `docs/generated/V5_NATIVE_ARTICULATION_METRICS.json`
- `docs/generated/V5_VS_CLEAN_RIG_V1_COMPARISON.json`
- `docs/generated/CLEAN_RIG_V5_GODOT_LAB_VALIDATION.json`
- `docs/generated/V5_GODOT_RUNTIME_VALIDATION.json`
- this report

## Files Modified

None of the protected production / V1 / catalog / battle paths.

Godot wrote `.import` / `.uid` sidecars for the new V5 labs and GLBs only.

## Recommended Next Step

1. Human visual gate in the two V5 labs (`1/2/3/4`, skeleton-inside-mesh, fingers, joints).
2. Decide later: **KEEP CLEAN RIG V1** or **PROMOTE CLEAN RIG V5**.
3. If V5 is chosen, next milestone is **SSK_V5_ANIMATION_COMPATIBILITY_BENCHMARK** (approved Idle / Reaction against the V5 rig). Do not start Mixamo retarget in this milestone.
4. Restore or author PBR maps before any production promote. Treat Tereré’s missing ring as an explicit accept/reject item.
