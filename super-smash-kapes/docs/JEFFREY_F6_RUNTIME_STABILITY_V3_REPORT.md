# Jeffrey F6 runtime stability V3

## Primary Verdict

**JEFFREY_F6_RUNTIME_STABILITY_V3_PARTIAL**

Windowed 10-launch Track ↔ Zombies harness **PASS**. No `0x8007000e`, `mem=null`, `std::bad_alloc`, signal 11, or invalid RID cascade. Memory plateau matches the human Zombies reference. Permanent “never again” is not claimed: leftover editor processes on ~16 GB RAM remain the human F6 risk.

## HUD crash

Root cause: BASELINE car had no `debug_grounded_n`. Godot `int(null)` → `Invalid call. Nonexistent 'int' constructor` at `track_generator_v2_lab.gd:370`.

Fix: `TrackDebugTelemetry` defaults optional debug fields. BASELINE now also publishes `debug_grounded_n` (0/4). Lab HUD never converts null telemetry.

Measured gate:

- 95 controller/difficulty/rebuild cycles
- 114 s logged, HUD on, 4WHEEL ↔ F2 BASELINE
- no Invalid call
- `os_static_memory` peak flat at 91 481 031 bytes (~87 MB)

## 10-launch windowed harness (pid 26112)

Host at start: 15.9 GB RAM, **4.5 GB free**, **6 leftover Godot processes**.

Alternation: `TrackTurboV7Showcase` (generate SHORT/PICANTE) ↔ `ZombiesMain`, hold 3.2 s, 10 launches.

Zombies plateau (exits 1/3/5/7/9):

| | this harness | human F6-like reference |
|---|---|---|
| static | 142–147 MB (peak 156.0) | ~156 MB |
| tex | 70.7–74.7 MB | ~70.1 MB |
| video | 469.1–473.1 MB | ~469–473 MB |
| buffers | 30.7 MB | ~30.8 MB |
| meshes (Zombies ready) | 1129 | 1129 |
| materials | 92 | 92 |
| textures | 5 | 5 |

Non-runaway: video returns to ~309–348 MB on Track launches, then back to ~473 MB on Zombies. Static peak 156.0 MB, not climbing across launches 6–10.

## WASAPI

Dummy audio in automation. `GetBufferSize` / output_device invalidated was not reproduced here. Treat as Windows device invalidation, not D3D12 allocator.

## Residual

Real editor-style repeated F6 remains the human gate. Close leftover Godot processes before long F6 sessions.
