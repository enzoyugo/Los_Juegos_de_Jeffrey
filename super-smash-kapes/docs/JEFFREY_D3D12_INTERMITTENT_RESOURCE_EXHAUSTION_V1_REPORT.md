# JEFFREY D3D12 intermittent resource exhaustion V1

## Primary Verdict

**JEFFREY_D3D12_RESOURCE_EXHAUSTION_RESOLVED**

The first-failure class is **CPU/GPU allocation `0x8007000e` (E_OUTOFMEMORY)**, not uniform-set / pipeline / framebuffer cascade. Those remain downstream.

Project-owned cause: **Godot was importing the Shopping del Sol Street View set** (260 PNG @ 1920×900, ~517 MB source). Combined with the 4K track atlas, shared `NoiseTexture2D` 256² (exactly **262144** bytes RGBA), leftover editor processes, and ~16 GB host RAM, this matches the intermittent editor F6 signature.

A windowed D3D12 Forward+ 3-cycle repeat-launch now **passes** on this machine: no `0x8007000e`, no invalid RID cascade, no crash.

## Reproduction

Human: TrackGeneratorV2Lab and ZombiesMain both sometimes failed with `Can't create buffer of size: 262144` and separately `21542400`, then RID/pipeline cascade. A later clean run could succeed. Isolated CLI smokes often missed it.

Lab analogue: `scenes/debug/D3D12RepeatLaunchLab.tscn` via `tools/run_d3d12_repeat_rendered.py` (windowed D3D12 Forward+, Dummy audio). Sequence ZombiesMain → TrackGeneratorV2Lab → ZombiesMain → TrackGeneratorV2Lab → TrackMain → ZombiesMain, **3 cycles**, ~5.2 s rendered hold each.

## First Allocation Failure

Treat the **first** `Can't create buffer of size: N` as the symptom.

| Size | Interpretation |
|---|---|
| **262144** | 256×256 RGBA8. Matches `track_asphalt_v1.tres` / shoulder / rail `NoiseTexture2D` (256). Shared `.tres` — one RID per material. Fatal when the process is already near commit limit. |
| **21542400** | ~20.5 MB. Consistent with a large CPU image / unpacked texture (Street View 1920×900 padded, or a 4K JPEG decode working buffer). |

`mem is null` / `mem_new is null` in older atlas logs were `Memory::alloc_static` failures (CPU), then D3D12 PSO `0x8007000e` as cascade.

## Track Reproduction

TrackGeneratorV2Lab: 4WHEEL + generated kit + shared asphalt NoiseTexture2D + 4K car atlas. Isolated CLI often passed. Editor F6 with leftover Godot processes + freshly imported references did not.

## Zombies Reproduction

ZombiesMain: Shopping GLB is small (~351 KB, 5088 tris). Failure is not “the mall mesh is huge.” Street View imports were the large new residency. Shell + parking + atlas + editor = intermittent.

## Repeat-Run Behavior

The bug is **process-lifetime**, not a single scene. ResourceCache survives F5. Import on first editor open after adding `assets/reference/shopping del sol/` is a one-time storm.

Harness cycles 2–3 hold **flat** static peak (140.4 MB) and the same Zombies video-mem plateau (~517 MB). No per-launch leak in this process.

## Resource Counts

Instrument: `scripts/debug/jeffrey_resource_probe.gd` (`[JEFFREY_MEM]`). Autoload boot from `JeffreyCore`. Scene ready dumps from ZombiesMain and TrackGeneratorV2Lab.

Unique texture/material counts are walked from the live scene tree.

## Unique Textures

Track: one 4K atlas RID when 4WHEEL mounts. Asphalt/shoulder/rail: three NoiseTexture2D on shared `.tres`.

Zombies V4: shared kit materials. Unique albedo textures walked from the live tree: **5** on ZombiesMain. Street View / photos do **not** appear as Texture2D (`.gdignore` on `assets/reference/`).

## Unique Materials

Parking/facade/cars/lamps share kit materials. Interior boxes share `ZombiesMallProps.color_material`. Per-zombie: 1 skin + 1 cloth.

ZombiesMain ~92 unique mats at ready, ~138 after 5 s (spawned gameplay). TrackGeneratorV2Lab ~228 mats (piece kit, shared `.tres`).

## Suspected Root Cause

Stacked, not a single missing file:

1. **Reference import storm:** 260 high-res PNGs imported into the Godot project.
2. **Host commit pressure:** 16 GB class machine, leftover Godot editor + player processes.
3. **Large one-shot allocs:** 4K atlas load, NoiseTexture2D 256², ~20 MB image buffers.
4. **RGB8 ImageTexture** (secondary): Godot converted RGB8 → RGBA8 on every ZombiesMain. Fixed to `FORMAT_RGBA8`.

Not proven: a gameplay leak that allocates a new 256² noise per track piece. Pieces `load()` shared `.tres`. Harness memory is stable across cycles.

## Fix

- `assets/reference/.gdignore` (`*`) — stop importing Street View/photos.
- Shared material caches (parking kit, mall props, viewmodel).
- Memory probe + windowed repeat harness.
- Asphalt/plaza ImageTexture created as RGBA8 (no RGB8 hardware convert).
- Existing atlas fallback (4×4) unchanged.

Did **not** switch renderer off D3D12. Did **not** downscale the atlas.

## Before/After Memory

Before: editor could import ~517 MB PNG (uncompressed GPU/CPU much larger). After: references invisible to importer. No Street View `.ctex` remains under `.godot/imported`.

Live `[JEFFREY_MEM]` from `docs/generated/D3D12_REPEAT_RENDERED_V4.log` (RTX 2060 SUPER, windowed D3D12 Forward+):

| Tag | static | peak | tex | video | unique tex |
|---|---|---|---|---|---|
| boot | 80.8 MB | 86.4 MB | 0 | 0 | — |
| ZombiesMain t5 (c1) | 135.0 MB | 135.0 MB | 68.1 MB | 470.5 MB | 5 |
| TrackGeneratorV2Lab t5 (c1) | 132.1 MB | 138.8 MB | 77.9 MB | 364.3 MB | 4 |
| ZombiesMain t5 (c3 last) | 140.4 MB | 140.4 MB | 80.4 MB | 516.8 MB | 5 |

Peak static across the whole 3-cycle run: **140.4 MB**. Video mem plateaus; it does not climb cycle-to-cycle.

## Rendered Repeat Test

**PASS.** `[D3D12_REPEAT] PASS cycles=3 fatal=false`. `first_fatal=none`. exit 0.

Gate: 3 cycles, no `0x8007000e`, no invalid RID cascade, no signal 11/4.

This is a **standalone windowed process**, not editor F6. It is the closest automation the sprint asked for.

## Remaining Risk

- Multiple leftover Godot processes can still OOM a 16 GB host. Close extra editors/players before F6.
- Editor F6 is still the human authority if the machine is already committed.
- Track 4K atlas remains a large one-shot alloc; it is shared, not leaked.
