# TRACK SHARED ATLAS D3D12 OOM ROOT CAUSE V2

## Primary Verdict

**TRACK_SHARED_ATLAS_LOAD_MEMORY_FAILURE_BLOCKED**

Not: `TRACK_4WHEEL_ARTICULATED_V1_READY_FOR_HUMAN_REVIEW`.  
Not: `TRACK_4WHEEL_EXTENDED_ATLAS_MEMORY_FIXED_READY_FOR_HUMAN_REVIEW`.

CLI_ISOLATED D3D12 / Forward+ loads of the canonical 4K atlas, MinimalAtlasLab, PilotLab, and ExtendedLab all succeeded after the fix. EDITOR_F6 was **not** run in this session, so the human-invalidated editor gate stays ungated.

## Human Failure Evidence

Authoritative editor/F6 chain (not CLI):

1. Godot starts D3D12 / Forward+.
2. `_ensure_shared_atlas()` is invoked from `track_car_visual.gd` (then line 302).
3. `Parameter "mem" is null`
4. `Parameter "mem_new" is null`
5. `Expected Image data size of 4096x4096x1 (DXT1 RGB8 with 12 mipmaps) = 11184824 bytes, got 0 bytes instead.`
6. Imported texture fails: `res://.godot/imported/track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg-4ebf91ec52d9a986b1bd6a86b83c994a.s3tc.ctex`
7. Source JPEG also fails: `res://assets/vehicles/track/source/track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg`
8. Scene continues: articulated body, four wheel binds, live visual, nine track pieces, seam validation.
9. `Out of memory`
10. D3D12 `Create(Graphics)PipelineState failed with error 0x8007000e`
11. `CrashHandlerException: Program crashed with signal 4`

Logged leftover state from that run: `source_instances=1, ghost_visuals=0, atlas_id=0, atlas_path=, atlas_rid=, atlas_px=0x0, source_resident=false, articulated_resident=true`.

Framebuffer / invalid texture RID / uniform set / draw-list / pipeline errors after step 5 are treated as cascade until proven otherwise.

## First Authoritative Failure

**First failure:** GDScript `load()` of the canonical albedo inside `_ensure_shared_atlas()`.

Exact call (pre-fix line 302):

```gdscript
_shared_atlas = load(VisualConfig.SHARED_ATLAS) as Texture2D
```

- API: GDScript `load()` → `ResourceLoader.load()`.
- Path: `res://assets/vehicles/track/source/track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg`
- Type requested: imported `CompressedTexture2D` (via `.import` remap), cast to `Texture2D`.
- Not used: `Image.load()`, `ImageTexture.create_from_image()` of the 4K, `get_image()`, `duplicate()` of image data, `decompress()`, `convert()`, `resize()`, `blit_rect`.
- Indirect `.godot/imported` access: **yes**, through Godot’s import remap to the `.s3tc.ctex`. Gameplay code did not hardcode the hashed filename.
- CPU 4K Image copies in this function: **none** on the success path. On the failure path Godot’s loader itself allocated (and failed to allocate) buffers.

`mem is null` / `mem_new is null` are Godot `Memory::alloc_static` / `realloc` failures. After those, Image construction still advertised DXT1 4096×4096 + 12 mipmaps but the `PackedByteArray` was empty → `got 0 bytes instead`. ResourceLoader then fell back to the source JPEG; that decode also failed. `load()` returned null, so `_shared_atlas` stayed null (`atlas_id=0`, `atlas_px=0x0`). Mounting continued anyway, then D3D12 PSO creation hit `0x8007000e`.

This is **CPU process allocation failure first**, then GPU pipeline OOM as cascade. It is not proven to be a zero-byte file on disk.

## `_ensure_shared_atlas()` Audit

Call graph (ExtendedLab, 4WHEEL):

```
Track4WheelExtendedPhysicsLab._ready
  → _spawn_car("4WHEEL_V1")
    → load("res://scenes/track/TrackCarWheelPhysics.tscn")
    → add_child(car)  # VisualRoot is TrackCarVisual, use_articulated=true
      → TrackCarVisual._ready
        → _mount_source
          → _ensure_shared_atlas
          → _packed_for_mode  # articulated GLB
          → packed.instantiate
          → _bind_instance_materials
          → _bind_articulated_wheels
```

Pre-fix `_ensure_shared_atlas()`:

| Question | Answer |
|---|---|
| Exact API | `load(VisualConfig.SHARED_ATLAS) as Texture2D` |
| Path | source JPEG listed above |
| `Image.load` / `get_image` / decompress / blit | **no** |
| Reloads already-imported texture | **yes** — `load()` of the imported `CompressedTexture2D` |
| Accesses `.godot/imported` directly | **no** (remap only) |
| Holds temporary 4096×4096 CPU images | **not in GDScript**; Godot C++ loader may buffer the 11 184 824-byte DXT1 payload |
| Second GPU texture | **not in this function**; `_make_player_material` creates new `StandardMaterial3D` objects that **share** `albedo_texture` |

Articulated GLB import uses `gltf/embedded_image_handling=0` (discard textures). Body / FL / FR / RL / RR therefore have no albedo until runtime assignment. `_ensure_shared_atlas()` is **required** in articulated mode. It must assign the canonical imported Texture2D, not rebuild an atlas.

Post-fix: same `ResourceLoader.load(path, "Texture2D", CACHE_MODE_REUSE)` once; validate width/RID; on failure log `[TRACK_ATLAS] LOAD_FAILED` and install a **4×4** fallback `ImageTexture`. Never retry the 4K path. Never `get_image()` the atlas.

## Source JPG Validation

| Field | Value |
|---|---|
| Exists | yes |
| Path | `assets/vehicles/track/source/track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg` |
| Bytes | 3 261 217 |
| SHA256 | `9a6da40900f00829cd4ec5f996d5270a70edfd07f2c7aeebd07fa3a705ab8bca` |
| MD5 | `f5fff8a37bf77a68ed3c927f3144995e` (matches `.md5` `source_md5`) |
| Header | JPEG SOI `FFD8`, JFIF APP0, EOI `FFD9` |
| SOF0 | 8-bit, 4096×4096, 3 components (YCbCr/RGB) |
| PIL | `JPEG` `4096×4096` `RGB`, `load()` succeeded |
| Corruption | **not detected** |

Extension matches contents. The file is a real 4K JPEG, not an empty placeholder.

## Import Metadata

File: `track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg.import`

| Field | Value |
|---|---|
| importer | `texture` |
| type | `CompressedTexture2D` |
| uid | `uid://c5cf5cw3ckr6g` |
| `path.s3tc` | `res://.godot/imported/...jpg-4ebf91ec52d9a986b1bd6a86b83c994a.s3tc.ctex` |
| `imported_formats` | `s3tc_bptc` |
| `vram_texture` | true |
| `compress/mode` | 2 (VRAM compressed) |
| `compress/high_quality` | false |
| mipmaps | `generate=true`, `limit=-1` |
| `detect_3d/compress_to` | 1 |
| dest_files | the `.s3tc.ctex` above |
| generator md5 (import block) | `bcf92ae0166a5a62a9a5d7c402986aca` |
| sidecar `source_md5` | `f5fff8a37bf77a68ed3c927f3144995e` (matches JPEG MD5) |
| sidecar `dest_md5` | `2e483b49a979eaf52b9deb4274c71145` (matches CTEX MD5) |

One s3tc artifact. No extra hashed copies of this albedo in `.godot/imported`. Sidecar hashes are consistent with the files on disk (not a stale hash mismatch). `generator_parameters.md5` is a different field from `source_md5`; that difference is expected.

Referenced `.s3tc.ctex` **exists**. Independent Godot load of the source path (CLI) returned a valid `CompressedTexture2D` 4096×4096.

## CTEX Validation

| Field | Value |
|---|---|
| Exists | yes (not zero bytes, not truncated) |
| Bytes | 11 184 876 |
| Header | 52 bytes `GST2` |
| Payload | 11 184 824 (exactly DXT1 4096×4096 + 12 mipmaps) |
| Magic | `GST2` |
| Width / height | 4096 / 4096 |
| Mipmaps | 12 |
| Format id | 17 = DXT1 |
| SHA256 | `f1761c4791510dc74af6eb6dbe3ee32a9528ddee9276a442f018c512b9d6d9a6` |
| MD5 | `2e483b49a979eaf52b9deb4274c71145` |
| Conflicting hashes | none found |

The on-disk artifact is a complete DXT1 texture. **Do not treat “got 0 bytes” as a truncated file.** That message is the in-memory Image after a failed alloc.

`.godot/imported` remains disposable cache. Gameplay code never names the hashed `.ctex`.

## Selective Reimport Result

Evidence preserved under `docs/generated/atlas_evidence_v2/` (import sidecar, md5, ctex copy, `PRE_REIMPORT_MANIFEST.json`) before deleting **only** this albedo’s `.ctex` + `.md5`.

Godot 4.7.2 `--headless --import --quit` regenerated the same dest path.

| | Before | After |
|---|---|---|
| size | 11 184 876 | 11 184 876 |
| SHA256 | `f1761c47…` | `f1761c47…` (identical) |
| dest_md5 | `2e483b49…` | `2e483b49…` |
| mtime | 2026-08-26 18:01:59 | 2026-08-26 19:54:55 |

**Reimport did not change the bytes.** The old import artifact was not an invalid/stale CTEX. Reimport “fixing it” is **not** the story. The invalid 0-byte image was a **runtime allocation failure** while reading a valid 11 MB file (then JPEG fallback), under tight host RAM and multiple Godot processes.

## Runtime Texture Architecture

Desired and implemented:

```
TRACK_CAR_ATLAS_TEXTURE
  = imported CompressedTexture2D at SHARED_ATLAS (source JPEG path)

track_car_atlas.tres
  = authority Resource whose `texture` ExtResources that JPEG

track_car_player_v1.tres
  = StandardMaterial3D albedo_texture = same JPEG

BODY / FL / FR / RL / RR
  = unique lightweight StandardMaterial3D, same albedo_texture RID
```

For **one car, articulated**:

| Object | Count |
|---|---|
| Canonical Texture2D | 1 |
| CPU Image of 4K | 0 |
| ImageTexture of 4K | 0 |
| Player materials | 5 (`material_users=5`) |
| Unique atlas resource IDs | 1 |
| GPU copies of the 4K atlas | 1 |

Fused SOURCE mode (TrackMain / BASELINE visual): `material_users=1`, same atlas RID.

CLI proof (MinimalAtlasLab D3D12):

```
[TRACK_ATLAS] source_path=res://assets/vehicles/track/source/track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg
[TRACK_ATLAS] loaded=true
[TRACK_ATLAS] size=4096x4096
[TRACK_ATLAS] format=CompressedTexture2D
[TRACK_ATLAS] material_users=5
[TRACK_ATLAS] unique_texture_resources=1
[TRACK_ATLAS] fallback=false rid_valid=true
```

ExtendedLab F5 toggle BASELINE → 4WHEEL kept the **same** `atlas_rid`.

## CPU Memory

Host during investigation (16 GB machine):

| Metric | Typical observed |
|---|---|
| Total physical | 17 125 650 432 bytes (~16.3 GiB) |
| Free physical | ~2.6–2.8 GiB |
| Free virtual / commit headroom | ~3.3–3.6 GiB |
| Leftover `Godot_v4.7.2-stable_win64` processes | 6 (private bytes from ~70 MB to ~766 MB each) |

Godot `OS.get_static_memory_usage()`:

| Moment | Bytes |
|---|---|
| Texture-load-only before `load()` | 84 468 671 |
| Texture-load-only after `load()` | 84 471 735 (**+3 064**) |
| MinimalAtlasLab after visual | ~88 191 753 |
| ExtendedLab peak static | 106 549 271 |

No 67 MB jump at atlas load. That is the measurement that **rules out** GDScript-side RGBA8 decompression in `_ensure_shared_atlas()`.

Human F6 still ran with ~2.6 GiB free plus editor overhead plus leftover Godot processes. A failed 11 MB (or JPEG-decode ~50–67 MB) alloc in that environment is plausible. `0x8007000e` is `E_OUTOFMEMORY` and can be **system commit**, not only VRAM.

## GPU Memory

| Item | Value |
|---|---|
| GPU | NVIDIA GeForce RTX 2060 SUPER, driver 32.0.15.6094 |
| WMI AdapterRAM | 4 293 918 720 (32-bit truncation; card is 8 GB class) |
| Also enumerated | Meta Virtual Monitor |
| D3D12 note | Device does NOT support GPU UPLOAD heap; ReBAR not enabled |
| CLI ExtendedLab `texture_mem` | 61 595 648 (61.6 MB) |
| CLI ExtendedLab `video_mem` | 342 482 944 (~327 MB) |
| CLI Compatibility texture-load-only `texture_mem` | 30 381 559 |
| D3D12 texture-load-only `texture_mem` at `_ready` | 0 (counter not populated before first frame) |

Dedicated/shared GPU counters from the OS were not available as a reliable per-process split in this session. D3D12 `Create(Graphics)PipelineState 0x8007000e` after a CPU `mem=null` is **not** taken as proof of VRAM exhaustion as the first cause.

## Peak Allocation Analysis

True cost of this 4K texture:

| State | Bytes | Notes |
|---|---|---|
| SOURCE JPG disk | 3 261 217 | JPEG |
| IMPORTED CTEX disk | 11 184 876 | GST2 + DXT1 payload |
| COMPRESSED GPU residency (estimated) | 11 184 824 | DXT1 4096² + 12 mipmaps |
| CPU IMAGE IF DECOMPRESSED RGBA8 | 67 108 864 | 4096×4096×4, no mips |
| Same with mip chain (~4/3) | ~89.5 MB | if fully decompressed with mips |

**61.6 MB discrepancy:** `docs/generated/TRACK_PILOT_RUNTIME.json` and ExtendedLab smoke print `tex=61595648`. That is Godot Performance **scene-wide** `RENDERING_INFO_TEXTURE_MEM_USED`, not one uncompressed 4K. It matches previous Pilot/Extended D3D12 logs after VRAM compression was already on. It is **not** DXT1 residency of this atlas (~10.7 MiB) and **not** a proven extra RGBA8 copy of this atlas.

If `_ensure_shared_atlas()` decompressed to RGBA8, CLI static memory would have jumped by tens of megabytes. It jumped by **3 KB**. **It does not decompress in the current GDScript path.**

## Runtime Image Copies

Track scripts Grep: no `.get_image()`, `decompress()`, `blit_rect`, `load_image`, or 4K `Image.create` in `track_car_visual.gd`.

The only `Image.create` / `ImageTexture.create_from_image` is the **4×4** fallback.

Peak transient RAM attributable to GDScript atlas assembly: **none** (no atlas bake). Godot’s CompressedTexture2D loader may hold ~11 MB compressed CPU buffer during upload.

## Atlas Sharing

| Mode | unique_texture_resources | material_users | same RID across body/wheels |
|---|---|---|---|
| Articulated (Minimal / Pilot / Extended 4WHEEL) | 1 | 5 | yes |
| SOURCE fused (TrackMain / BASELINE visual) | 1 | 1 | n/a (one mesh) |
| Player + ghost (ValidateJeffreyShell share_check) | 1 atlas_id | — | path = canonical JPEG |

Ghost uses one static `StandardMaterial3D` with the same atlas.

## MinimalAtlasLab

Created:

- `scenes/debug/TrackCarMinimalAtlasLab.tscn` — Camera, DirectionalLight, one `TrackCarVisual` (`use_articulated=true`). No track. No physics.
- `scenes/debug/TrackCarTextureLoadOnly.tscn` — **only** `ResourceLoader.load` of the source JPEG. No atlas composition.

### CLI_ISOLATED

| Run | Result |
|---|---|
| TextureLoadOnly D3D12/Forward+ | valid CompressedTexture2D 4096×4096, RID valid, path = source JPEG |
| TextureLoadOnly gl_compatibility | same, `texture_mem=30381559` |
| MinimalAtlasLab D3D12 ×3 | `loaded=true`, 4096×4096, users=5, unique=1, SMOKE END, no `mem=null`, no `0x8007000e`, no crash |
| MinimalAtlasLab Compatibility | same atlas diagnostics; `texture_mem=30381559` |

`_ensure_shared_atlas()` does **not** require ExtendedLab complexity to succeed or fail. Texture-load-only already exercises the same `load()` as line 302.

### EDITOR_F6

**UNGATED.** Not run.

## PilotLab

### CLI_ISOLATED

`TrackModularKitPilotLab` D3D12/Forward+, `SSK_TRACK_CONTROLLER=4WHEEL`, 90 frames:

`[TRACK_PILOT] SMOKE END controller=4WHEEL_V1 grounded=4/4 max_seam=0.000000 tex=61595648`

Atlas: 4096×4096, unique=1, users=5, fallback=false. No OOM / `0x8007000e` / crash.

### EDITOR_F6

**UNGATED.** Not run (required ×5 if editor available).

## ExtendedLab

### CLI_ISOLATED

`Track4WheelExtendedPhysicsLab` D3D12/Forward+, 4WHEEL, two smokes (90 and 60 frames):

- Nine pieces, seams 0, live_track_car_count=1
- Atlas 4096×4096, unique=1, RID stable across F5 BASELINE ↔ 4WHEEL
- `[TRACK_EXTENDED] SMOKE END … tex=61595648`
- No `mem=null`, no zero-byte image, no `0x8007000e`, no crash

### EDITOR_F6

**UNGATED.** Human evidence is still an editor/F6 crash. This session did not open the Godot editor GUI or press F6. Required ×5 plus Pilot → Extended → TrackMain → Extended without restart: **not executed**.

## D3D12

Project: `rendering_device/driver.windows="d3d12"`, features Forward Plus.

CLI D3D12/Forward+ standalone (not editor): TextureLoadOnly, MinimalAtlasLab ×3, Pilot, Extended ×2, TrackMain, Smash (`M0Playground`), Zombies — **no** `0x8007000e`, **no** `got 0 bytes`, **no** CrashHandler in those logs.

A CLI pass **does not override** an editor F6 crash.

## Compatibility Control

Same source JPEG / same CTEX, `--rendering-driver opengl3 --rendering-method gl_compatibility`:

TextureLoadOnly and MinimalAtlasLab both loaded `CompressedTexture2D` 4096×4096 with valid RID.

**Not recorded:** `D3D12_TEXTURE_IMPORT_OR_RESIDENCY_PATH_SPECIFIC` for the import file itself. Both renderers load the resource in CLI. Compatibility is diagnostic only. The project renderer was **not** switched.

Editor F6 D3D12 vs Compatibility was **not** compared (no editor).

## Root Cause

1. **First failure** is `_ensure_shared_atlas()` → `load(SHARED_ATLAS)` of the imported 4K `CompressedTexture2D`.
2. That `load()` is **not** a GDScript 4K Image rebuild. There is no `get_image()` / decompress / `ImageTexture` bake of 4096² in Track visual code.
3. The 0-byte DXT1 Image is Godot reporting an Image whose **payload alloc failed** (`mem` / `mem_new` null) while the header still said 4096×4096 DXT1 + 12 mipmaps. The `.ctex` on disk is a full 11 184 876-byte GST2; selective reimport was **byte-identical**.
4. Loader then failed the source JPEG too (second alloc), so `_shared_atlas` stayed **null**. Materials rendered with empty atlas RID state. Physics/track init continued. Later `Out of memory` / PSO `0x8007000e` / signal 4 are **cascade**.
5. Host pressure: ~16 GB RAM, ~2.6 GiB free, multiple leftover Godot processes, D3D12 Forward+ editor overhead. CPU commit failure is sufficient; VRAM-only is not proven as first cause.
6. Articulated mode must still assign the canonical texture because the processed GLB **discards** embedded images.

## Fix Implemented

- Canonical authority: `assets/vehicles/track/materials/track_car_atlas.tres` + `track_car_player_v1.tres` ExtResource the **source JPEG** (not `.godot/imported`).
- `_ensure_shared_atlas()`: one `ResourceLoader.load(..., CACHE_MODE_REUSE)`; RID/size check; **no** 4K Image reconstruction.
- Defensive 4×4 magenta `ImageTexture` if load fails; log `[TRACK_ATLAS] LOAD_FAILED path=... fallback=true`; do not retry the 4K load; do not keep a 0×0 / invalid RID atlas.
- `[TRACK_ATLAS]` diagnostics: path, loaded, size, format/class, material_users, unique_texture_resources, fallback, RID, static/texture/video memory.
- Diagnostic scenes: `TrackCarTextureLoadOnly`, `TrackCarMinimalAtlasLab`.
- Path scan updated; pytest coverage for no 4K rebuild and no hashed import paths in gameplay code.

Physics, steering, suspension, grip, mass, damping, boost, wheel contact, BASELINE controller: **unchanged**.

## Defensive Fallback

If canonical load fails:

- `push_error` + print `[TRACK_ATLAS] LOAD_FAILED path=... fallback=true`
- Assign 4×4 RGBA8 `ImageTexture` (magenta)
- Continue mounting with a **valid** tiny RID so the renderer is not fed a null/0-byte 4K texture

This is robustness against the cascade, **not** a claim that editor F6 OOM is gone. If Godot crashes inside `load()` before GDScript resumes, fallback never runs.

## Physics Changes

**NONE**

## Regression

| Gate | Result |
|---|---|
| Pytest | **282 passed** (was 277; +5 atlas tests) |
| Path scan | `required_missing=0`, `missing=0` |
| `[JEFFREY_VALIDATE]` | Atlas share_check **passed** (canonical JPEG path, non-zero atlas_id). Validator then **FAIL** on existing 4WHEEL visual checks `STEER_ONLY/SPIN_ONLY moved wheel center` for FL/FR/RL/RR. **Not** an atlas load failure. Bind/pose code was not modified in this track. Not treated as atlas READY. |
| TrackMain CLI D3D12 | atlas loaded 4096×4096, unique=1, no `0x8007000e` |
| Smash `M0Playground` CLI D3D12 | exit 0, no `0x8007000e` |
| ZombiesMain CLI D3D12 | exit 0, no `0x8007000e` |

### CLI_ISOLATED vs EDITOR_F6

| | CLI_ISOLATED | EDITOR_F6 |
|---|---|---|
| Texture source 4096, non-zero payload | PASS (standalone Godot 4.7.2) | **UNGATED** |
| MinimalAtlasLab | PASS ×3 D3D12 | **UNGATED** (required ×10) |
| PilotLab | PASS ×1 D3D12 | **UNGATED** (required ×5) |
| ExtendedLab | PASS ×2 D3D12 | **UNGATED** (required ×5 + chain) |
| `mem=null` / 0-byte DXT1 | not observed | still the human failure |
| `0x8007000e` / crash | not observed | still the human failure |

Do not merge these gates.

## Human Review Gate

Remain **TRACK_SHARED_ATLAS_LOAD_MEMORY_FAILURE_BLOCKED** until a human (or this environment with the real editor) runs ExtendedLab F6 on D3D12/Forward+ repeatedly without `mem=null`, zero-byte image, `0x8007000e`, or crash.

Suggested human pass:

1. Close leftover Godot processes; confirm several GB free RAM.
2. F6 `TrackCarTextureLoadOnly.tscn` — expect `[TRACK_TEXTURE_LOAD_ONLY] valid=true width=4096`.
3. F6 `TrackCarMinimalAtlasLab.tscn` ×10.
4. F6 PilotLab ×5, ExtendedLab ×5, then Pilot → Extended → TrackMain → Extended without restart.
5. Confirm `[TRACK_ATLAS] loaded=true size=4096x4096 unique_texture_resources=1 fallback=false`.

4WHEEL is **not** promoted. BASELINE remains canonical.
