# JEFFREY RENDER RESOURCE STABILITY GATE V1

## Primary Verdict

**JEFFREY_RENDER_RESOURCE_STABILITY_V1_READY**

Interactive D3D12 / Forward+ matrix A–L produced **0** `CreateResource` / `0x8007000e` lines, **0** texture RID cascades, **0** parser errors, **0** broken required preloads.

A/B human *feel* is still unjudged. This gate only unblocks that review.

## Baseline

| Item | Value |
|---|---|
| Branch | `master` |
| HEAD | `f5b73e2eb39d9d30493d7f44305d0522557d4c8a` |
| Git | `project.godot` modified; most of `super-smash-kapes/` still untracked |
| Pytest before | **253 passed** |
| Pytest after | **258 passed** (see Tests) |
| Godot | 4.7.2.stable.official |
| Renderer | Forward+ |
| Windows driver | `rendering_device/driver.windows="d3d12"` |
| GPU | NVIDIA GeForce RTX 2060 SUPER (driver 32.0.15.6094); WMI also lists Meta Virtual Monitor |
| Viewport project | 1920×1080, window mode 3 (fullscreen) |
| Harness | windowed 1280×720 standalone (not editor Play) |
| Physics | Jolt |
| Canonical controller | `CONTROLLER_MODE := "BASELINE"` (unchanged) |
| 4WHEEL | parallel R&D only |

Headless pytest / previous validators were **not** treated as proof of interactive GPU correctness.

## Interactive Failure Reproduction

Human-reported failure class:

1. `CreateResource failed with error 0x8007000e` (`E_OUTOFMEMORY`)
2. Cascade: invalid RID, invalid texture, null uniform set
3. Separate parser: `Could not preload res://assets/stages/defensores_del_chaco/platforms/defensores_platform_kit.png`

On this machine, **standalone D3D12 windowed runs did not reproduce CreateResource**, even before the fix, in 90-frame cases. The parser error also did **not** reproduce: the PNG is present (2.2 MB) and loads.

What **did** reproduce, and matches the OOM class:

| Evidence | Before fix | After fix |
|---|---|---|
| CASE A texture mem | 140 MB; `source_loaded=true` from `class_name` preload | 50 MB; neither GLB resident |
| CASE C/H texture mem | 207 MB | 61 MB |
| CASE H video mem | 531 MB | 284 MB |
| Articulated `.scn` | 27.2 MB (embedded uncompressed image) | 0.62 MB (meshes only) |
| Atlas import | lossless RGB8, `vram_texture=false`, D3D12 `RGB8→RGBA8` | VRAM compressed S3TC/BPTC, `vram_texture=true` |
| CASE H RGB8 warning | present | gone |
| Atlas RID | captured from whichever GLB mounted first | one canonical JPEG, same RID for source/articulated/ghost |

## First Failing Case

`FIRST_REPRODUCIBLE_FAILURE_CASE` for the **GPU defect** (not a hard crash in our window):

**CASE A already loaded the source 4K GLB** because `TrackCarVisual` is `class_name` and used `preload(source.glb)`.

**CASE C/F/H added a second uncompressed 4K** from `track_car_base_v2_articulated.glb` import `gltf/embedded_image_handling=3` (Embed as Uncompressed). D3D12 logged `Image format RGB8 not supported by hardware, converting to RGBA8` (~67 MB extra with mips).

A/B lab (CASE H) starts in 4WHEEL, so it paid source preload + articulated uncompressed from the first frame.

CreateResource itself was **not** the first crashing case here. The first *wrong residency* is CASE A; the first *duplicate uncompressed atlas* is CASE C.

## Root Cause

Three stacked issues, not a missing file:

1. **Articulated GLB imported uncompressed.** `embedded_image_handling=3` baked a ~27 MB `.scn` with RGB8 4K. D3D12 cannot sample RGB8 and converts to RGBA8 at upload time.
2. **Source 4K always resident.** `const CAR_VISUAL_SCENE := preload(source glb)` on a `class_name` script uploaded the extracted JPEG as lossless RGB8 on every project run, including empty 3D and Smash boot.
3. **A/B lab preloaded both PackedScenes** at class parse. F5 `queue_free` does not unload ResourceCache. Two GLBs with two independent 4K images stayed GPU-resident.

Material sharing from the previous sprint was **kept** (`_shared_atlas`, no `duplicate()` of imported materials, cached road colors). It was not sufficient while both GLBs still owned their own 4K uploads.

4K→2K fallback was **not** applied. VRAM compression + single atlas was enough.

## Texture Residency

Canonical atlas:

`res://assets/vehicles/track/source/track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg`

- 4096×4096
- extracted from immutable source GLB (source file untouched)
- now `compress/mode=2`, `vram_texture=true`

Validator / CASE G logs: **same `atlas_id` and same RID** for fused, articulated, player, and ghost. Player materials remain unique lightweight `StandardMaterial3D`. Ghosts share one transparent material.

## Source vs Articulated GLB

| | Source | Articulated |
|---|---|---|
| Path | `assets/vehicles/track/source/track_car_base_v1.glb` | `assets/vehicles/track/processed/track_car_base_v2_articulated.glb` |
| Role | immutable authoring | runtime visual when `use_articulated` |
| Disk | 4.27 MB (untouched) | 4.18 MB |
| Import image handling | extract (1) | **discard (0)** after fix |
| Imported `.scn` | 0.65 MB | 0.62 MB (was 27.2 MB) |
| Embedded atlas | same JPEG bytes historically | discarded; runtime binds shared atlas |

They are **not** the same PackedScene. They **must not** both upload 4K GPU images. Ordinary gameplay loads only the selected authority. Ingest lab may still load both meshes; they share one atlas.

## A/B Lab Residency

Before: `TrackWheelPhysicsLab` (`class_name`) preloaded `TrackCar.tscn` + `TrackCarWheelPhysics.tscn`. Combined with `TrackCarVisual.preload(source)`, every project start loaded source 4K. Instantiating 4WHEEL also loaded the uncompressed articulated atlas. F5 hid/freed instances only.

After: lab `load()`s the active PackedScene in `_spawn_car`. Visual script `load()`s only the selected GLB. Shared atlas is independent. After an F5 toggle both PackedScenes may stay cached (smooth switch) but they share one VRAM texture.

## Material Sharing

Unchanged policy, now actually true at GPU level:

- player: unique material, shared albedo
- ghost: one `_shared_ghost_mat`
- road/lab boxes: color cache (`_mat_cache`)
- no `material.duplicate()` of imported 4K

## D3D12

| Case | Result | Notes |
|---|---|---|
| A empty 3D | PASS | no car GLB resident |
| B fused visual | PASS | source authority |
| C articulated visual | PASS | source GLB not loaded |
| D BASELINE wrapper | PASS | |
| E 4WHEEL chassis, no car visual | PASS | |
| F 4WHEEL + articulated | PASS | |
| G both authorities in memory | PASS | one atlas RID |
| H A/B lab | PASS | 3600 frames, tex 61 MB stable |
| I TrackMain 0 ghosts | PASS | |
| J TrackMain + 1 ghost | PASS | |
| K TrackMain + 4 ghosts | PASS | |
| L JeffreyBoot shell | PASS | mode scenes lazy-loaded |

Logs: `docs/generated/STABILITY_forward_plus_d3d12_*.log`

CASE L still emits one `RGB8 not supported` warning from some boot/UI image. It did not cascade into RID failures.

## GL Compatibility

CASE H `gl_compatibility` / `opengl3`: **PASS**, no CreateResource.

Canonical renderer remains D3D12 Forward+. This was diagnostic only.

## Defensores Broken Preload

| | |
|---|---|
| Path | `res://assets/stages/defensores_del_chaco/platforms/defensores_platform_kit.png` |
| Calling script | `scripts/stages/defensores_stage.gd` line 4 `const PLATFORM_TEXTURE := preload(...)` |
| File | **exists** (1672×941, ~2.2 MB) |
| `.import` | present, VRAM compressed `path.s3tc` |
| Stale cache | extra non-`s3tc` `.ctex` removed (targeted; not a `.godot` wipe) |

Root cause of the human parser error was **not** a renamed/moved asset. The intended file is the authority; preload kept. This run: **0 parser errors**.

Smash gameplay unchanged.

## Global Resource Path Scan

`tools/scan_resource_paths.py`: **175 unique refs, 0 missing, 0 required missing.**

`jeffrey_app.gd` no longer `preload()`s Track + Zombies + Smash `Main.tscn` together. Those scenes `load()` when the mode is actually hosted.

## Tests

| | |
|---|---|
| Before | 253 passed |
| After | 258 passed |
| New | `tests/test_render_resource_stability_v1.py` |

Locks: Defensores PNG present, no source-GLB preload, articulated import discard, atlas VRAM compress, BASELINE canonical, road 11.0, kit spec 22 pieces, no generated pilot GLBs.

## Validator

`scenes/debug/ValidateJeffreyShell.tscn` → `[JEFFREY_VALIDATE] OK`

Atlas share check: one path, one RID, 4096×4096, source and articulated same `atlas_id`. Ghost ACTIVE/YA contract still checked. `CONTROLLER_MODE` BASELINE.

## Interactive Runtime

- Standalone D3D12 window, RTX 2060 SUPER
- CASE H: 3600 frames, texture mem 61 464 576 bytes from frame 2 through end
- No F5/WASD injection in automation (cannot certify handling feel)
- Editor Play was **not** the execution mode; editor thumbnails may still add GPU cost on a human machine

## Remaining Risks

- Godot **editor** Play (second viewport + import previews) was not the harness
- Fullscreen 1920×1080 + MSAA/shadows not re-tuned; harness used 1280×720 windowed
- CASE L leftover RGB8 warning on some UI image
- Ingest lab still instantiates raw source + runtime + articulated **meshes** (shared atlas; debug only)
- After F5, both car PackedScenes may remain in ResourceCache by design
- Human must still drive to judge 4WHEEL vs BASELINE

## A/B Review Status

**TRACK_4WHEEL_A_B_REVIEW_UNBLOCKED**

Not claimed better. BASELINE remains TrackMain production controller. Human decides feel in `TrackWheelPhysicsLab` (F5).
