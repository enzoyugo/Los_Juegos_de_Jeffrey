# Clean Rig V1 Godot Lab Recovery

## Primary Verdict

**SSK_CLEAN_RIG_V1_GODOT_LABS_READY_FOR_HUMAN_PLAYTEST**

Both labs now load only their Clean Rig V1 GLBs. Inspector metadata is stored on the scene (not wiped by V4 export defaults). The GLB is instanced in the `.tscn`, so the editor viewport shows the fighter without pressing Play. Mixamo retarget was not started.

## Human Finding

Opening `res://scenes/debug/JaguareteCleanRigV1Lab.tscn` showed an empty viewport. Inspector listed:

- Fighter ID = `terere`
- Pipeline ID = `ACTORCORE_V4`
- Target Height = `2.4`
- Production GLB = empty
- Benchmark GLB = empty

Godot output also showed AccuRIG FBX imports resolving `res://assets/fighters/model_Pbr_Diffuse.png` / `model_Pbr_Normal.png` and WebP/`ctex` failures under `source_rigged/.../autorig_actor.fbm`.

## Wrong Lab Configuration

The old labs **extended** `production_animation_lab.gd`, which exports:

- `fighter_id = "terere"`
- `pipeline_id = "ACTORCORE_V4"`
- `production_glb = ""`
- `benchmark_glb = ""` (from `actorcore_animation_lab.gd`)

Child `_init()` set Jaguareté / Clean Rig values, then Godot applied parent `@export` defaults onto the node. The `.tscn` stored no overrides, so the Inspector showed V4 Tereré. At runtime `benchmark_glb` stayed empty, `_load_benchmark_model()` returned, and the viewport stayed empty.

There was **no** ModelRoot GLB instance in the scene, so the editor had nothing to draw.

## Correct Asset Authority

| Fighter | `fighter_id` | `pipeline_id` | `target_height` | Asset |
|---|---|---|---|---|
| Tereré | `terere` | `CLEAN_RIG_V1` | **2.40** | `res://assets/fighters/processed/clean_rig_v1/terere/terere_clean_rig_v1.glb` |
| Jaguareté | `jaguarete` | `CLEAN_RIG_V1` | **3.15** | `res://assets/fighters/processed/clean_rig_v1/jaguarete/jaguarete_clean_rig_v1.glb` |

Labs use `scripts/debug/clean_rig_lab.gd`. They do **not** extend `production_animation_lab.gd`. There is no Production GLB field, no Benchmark GLB field, no catalog, no fallback load.

## Tereré Lab

- Scene: `res://scenes/debug/TerereCleanRigV1Lab.tscn`
- Instanced child: `ModelRoot/TerereCleanRigV1` → clean GLB
- Headless dump: `load_ok=true`, `fallback=false`, **101 bones**, 1 skeleton, 1 mesh, 0 animations
- Material: `.../terere_clean_rig_v1.glb::StandardMaterial3D_*`
- Bones (Godot Y-up): hip y=0.516, head y=0.895, feet y=0.141, hands x=±0.73
- `head.y > hip.y`, `feet.y < hip.y`

## Jaguareté Lab

- Scene: `res://scenes/debug/JaguareteCleanRigV1Lab.tscn`
- Instanced child: `ModelRoot/JaguareteCleanRigV1` → clean GLB
- Headless dump: `load_ok=true`, `fallback=false`, **101 bones**, 1 skeleton, 1 mesh, 0 animations
- Material: `.../jaguarete_clean_rig_v1.glb::StandardMaterial3D_*`
- Bones: hip y=0.757, head y=1.301, feet y=0.110, hands x≈+0.695 / −0.682
- `head.y > hip.y`, `feet.y < hip.y`

Catalog height metadata is 2.40 / 3.15; native GLB mesh height is AccuRIG meters (not those catalog numbers). No extra ModelRoot pitch/yaw is applied.

## Clean GLB Structure

Both GLBs (binary glTF):

- 1 mesh, 1 skin, 1 material, 0 animations, 103 nodes
- 2 embedded PNG images (`model_Pbr_Diffuse`, `model_Pbr_Normal`)
- Godot import: 1× Skeleton3D, 101 bones, T-pose rest

SHA256:

- Tereré GLB `2E5FA018…768ED`
- Jaguareté GLB `CAFA9F55…549742`

## Texture Authority

Textures are **embedded in the GLB** (no URI to `res://assets/fighters/model_Pbr_*.png`). Godot also extracted sidecars:

- `assets/fighters/processed/clean_rig_v1/terere/terere_clean_rig_v1_model_Pbr_Diffuse.png`
- `assets/fighters/processed/clean_rig_v1/jaguarete/jaguarete_clean_rig_v1_model_Pbr_Diffuse.png`

Diffuse SHA256 differs (`29AEDD81…` vs `65417902…`) — characters do **not** share texture bytes.

`res://assets/fighters/model_Pbr_Diffuse.png` and `model_Pbr_Normal.png` **do not exist**. Those paths come from **FBX** imports under `source_rigged/`, not from the clean labs.

Runtime materials on the labs resolve to `res://assets/fighters/processed/clean_rig_v1/<fighter>/<fighter>_clean_rig_v1.glb::StandardMaterial3D_*`.

## WebP Errors

Godot Output WebP packing / `size <= 0` / failed `.ctex` lines are **historical AccuRIG FBX + `.fbm` import noise**.

Cause: `autorig_actor.fbx.import` still exists for both source rigs. The FBX importer looks up generic `model_Pbr_Diffuse.png` names and can hit empty/wrong import cache entries. That is **not** the clean GLB path.

A targeted `--import` after this recovery printed **no** WebP/ctex errors. If they reappear when the editor reimports FBX, they remain **UNRELATED_HISTORICAL_ASSET_NOISE**.

Do not wipe `.godot/` blindly. Future fix: `.gdignore` on `assets/fighters/source_rigged` (recommended, not done here).

## Raw FBX Import Noise

Godot still scans:

- `source_rigged/**/autorig_actor.fbx`
- `actorcore_benchmark`, `native_skin_audit`, `solver_v1`, `semantic_solver_v2`, `game_ready_v3`, `game_ready_v4`

Classification: `docs/generated/GODOT_FIGHTER_IMPORT_SURFACE.json`

Clean labs reference **none** of those paths.

## Remaining Relevant Errors

**CLEAN_RIG_BLOCKING:** none in headless lab load.

**UNRELATED_HISTORICAL_ASSET_NOISE:** FBX/`.fbm` texture lookup, possible WebP/`ctex` when those sources reimport.

## Human Playtest Instructions

1. Open `res://scenes/debug/JaguareteCleanRigV1Lab.tscn` in the editor. The jaguar mesh should already be in the 3D viewport (instanced GLB). Inspector must show `fighter_id=jaguarete`, `pipeline_id=CLEAN_RIG_V1`, `target_height=3.15`, `asset_glb=.../jaguarete_clean_rig_v1.glb`.
2. Open `res://scenes/debug/TerereCleanRigV1Lab.tscn`. Same for Tereré, height **2.4**, matching GLB.
3. Press Play. HUD: `CLEAN RIG V1 | fighter=... | pipeline=CLEAN_RIG_V1`.
4. Keys: `1` rest, `2` skeleton dots, `3` mesh on/off, `4` reset camera.
5. Confirm capybara vs jaguar textures are different, T-pose, no idle, no V4.

Godot: `E:\Godot_v4.7.2-stable_win64_console.exe`

```
& "E:\Godot_v4.7.2-stable_win64_console.exe" --path "E:\SuperSmashKapes\super-smash-kapes" res://scenes/debug/JaguareteCleanRigV1Lab.tscn
```

## Files Modified

- `scripts/debug/clean_rig_lab.gd` (new dedicated lab; no V4 parent)
- `scripts/debug/terere_clean_rig_v1_lab.gd`
- `scripts/debug/jaguarete_clean_rig_v1_lab.gd`
- `scripts/debug/clean_rig_v1_lab.gd` (no longer extends production lab)
- `scenes/debug/TerereCleanRigV1Lab.tscn`
- `scenes/debug/JaguareteCleanRigV1Lab.tscn`
- `scripts/debug/validate_clean_rig_v1_labs.gd`
- `scenes/debug/ValidateCleanRigV1Labs.tscn`
- `docs/generated/GODOT_FIGHTER_IMPORT_SURFACE.json`
- `docs/generated/CLEAN_RIG_V1_GODOT_LAB_VALIDATION.json`
- `docs/CLEAN_RIG_V1_GODOT_LAB_RECOVERY_REPORT.md`

Not modified: battle, catalog, V4 GLBs, source FBX, Mixamo.

## Recommended Next Step

Human visual confirm of both editor scenes. After that, Mixamo Idle onto these **same** clean GLBs in an isolated experiment folder — still not wired to battle.
