# Idle Benchmark Lab Input + HUD Recovery Report

## Primary Verdict

**SSK_IDLE_BENCHMARK_LAB_V1_READY_FOR_HUMAN_VISUAL_AB**

Both Idle retarget benchmark labs switch Rest / Traditional / Semantic at runtime, semantic `idle` time advances, number keys no longer share camera shortcuts in the running scene, and the labs do not instantiate battle HUD. HUD plate sources were valid PNGs; Godot’s lossless-WebP `.ctex` path was the failure class and has been reimported without WebP.

Human visual A/B (F6) is now the remaining authority. This is not a production winner and does not change Clean Rig, Production V4, or battle.

## Human Findings

Observed before this recovery:

1. `TerereIdleRetargetBenchmarkV1Lab.tscn` opened and the fighter was visible.
2. Numeric keys did not switch Rest / Traditional / Semantic.
3. Pressing numbers changed / moved the camera.
4. Expected: `1` rest, `2` traditional, `3` semantic, `4` skeleton, `5` bbox, `6` reset camera.
5. Godot also emitted HUD failures for `hud_p1.png` / `hud_p2.png` (cowdata, WebP decode, `.ctex` load, `kapes_player_hud.gd` preload parse, `m0_hud.gd` compile).

Those two tracks were independent. The camera behavior was editor viewport input. The HUD spam was global-class parse of battle HUD textures.

## Input Root Cause

Not a missing `_unhandled_input`. The lab already listened for `KEY_1`…`KEY_6` in `_unhandled_input` matching only `event.keycode`.

That handler **never runs in the editor 3D viewport**. The lab script is not `@tool`. Opening the `.tscn` (fighter visible) is not “Run scene”.

Godot 4.4+ enables **Emulate Numpad** by default (`editors/3d/navigation/emulate_numpad`). Top-row numbers alias numpad view shortcuts in the 3D editor:

| Key | Editor 3D action |
| --- | --- |
| `1` | Front view |
| `3` | Right view |
| `5` | Perspective / orthogonal |
| `7` | Top view |

This machine’s `editor_settings-4.7.tres` does not override that default, so it is on. Pressing `1`/`2`/`3` in the open lab scene therefore moved the **editor camera**, which matches the human report exactly.

Secondary runtime gaps (fixed anyway):

- `_unhandled_input` only, so GUI / other consumers could swallow keys.
- `event.keycode` only — no `physical_keycode`, unicode, or keypad.
- No dedicated `InputMap` actions, so lab controls were not first-class runtime input.

Editor viewport hotkeys are **not** lab controls. TRACK E is explicit: human validation authority is the running scene (F6).

## Method Switching

Contract is now enforced in `idle_retarget_benchmark_lab.gd`:

| Key / action | Visible root | Hidden | Playback |
| --- | --- | --- | --- |
| `1` `benchmark_rest` | `RestRoot` | Traditional, Semantic | none; rest pose |
| `2` `benchmark_traditional` | `TraditionalRoot` | Rest, Semantic | `idle` continuously |
| `3` `benchmark_semantic` | `SemanticRoot` | Rest, Traditional | `idle` continuously |

Exactly one candidate is visible. Method switching does **not** move the camera.

Runtime print on every switch:

```
[IDLE_BENCHMARK]
fighter=terere
method=SEMANTIC
asset=res://assets/fighters/processed/idle_benchmark_v1/terere/terere_idle_semantic_clean_v1.glb
animation=idle
playing=true
```

Same pattern for Jaguareté.

Imported GLB clip name is `idle` (not `idle_traditional` / `idle_semantic`). The player prefers those names, then any name containing `idle`. Both traditional and semantic GLBs expose `idle` at 3.667 s (110 frames @ 30 FPS).

## Animation Playback Proof

Headless validation instantiated each lab, switched methods, waited 1 s, and required `current_position` to move.

No `AnimationTree` on either candidate. `AnimationPlayer` list: `["idle"]`.

| Fighter | Method | animation_name | length | start → ~1 s | playing | advanced |
| --- | --- | --- | --- | --- | --- | --- |
| Tereré | CLEAN_REST | rest | 0 | — | false | n/a |
| Tereré | TRADITIONAL | idle | 3.667 | 0.010 → 1.007 | true | yes |
| Tereré | SEMANTIC | idle | 3.667 | 0.000 → 1.001 | true | yes |
| Jaguareté | CLEAN_REST | rest | 0 | — | false | n/a |
| Jaguareté | TRADITIONAL | idle | 3.667 | 0.010 → 1.007 | true | yes |
| Jaguareté | SEMANTIC | idle | 3.667 | 0.000 → 1.000 | true | yes |

Independent selftests (`SSK_IDLE_BENCHMARK_SELFTEST=1`):

- Tereré: `SELFTEST fighter=terere ok=true hud=false`
- Jaguareté: `SELFTEST fighter=jaguarete ok=true hud=false`

Fail path remains: if a visible animated candidate is static after 1 s, the lab prints `[IDLE_BENCHMARK] FAIL … visible but static`.

## Camera Isolation

Number keys `1`–`5` are not bound to any camera mode in the running lab.

Camera navigation (runtime only):

- Right mouse drag: orbit
- Wheel: zoom
- WASD: yaw / zoom
- `6` / `benchmark_camera_reset`: restore the same framing used for all methods

Method switch does not call camera reset. Validation recorded the same camera position across Rest / Traditional / Semantic:

- Tereré: `(0.0, 1.6, 5.5)`
- Jaguareté: `(0.0, 2.1, 7.0)`

That is the A/B comparison camera.

## HUD Asset Failure Root Cause

Sources exist and are **valid PNG**, not missing, not WebP, not truncated:

| File | Bytes | Signature | IHDR | Pillow |
| --- | --- | --- | --- | --- |
| `assets/ui/hud/hud_p1.png` | 1,201,309 | `89 50 4E 47` | 2172×724, 8-bit RGBA, IEND present | loads |
| `assets/ui/hud/hud_p2.png` | 939,333 | same | 2172×724, 8-bit RGBA, IEND present | loads |

This was **not** a bad source file and **not** “assume cache corruption” as the only story.

Import was `compress/mode=0` (Godot lossless **WebP** inside `.ctex`). The old GST2 files contained a `RIFF…WEBP VP8L` payload. That is the exact importer class that emits:

- Failed decoding WebP image
- Failed loading `res://.godot/imported/hud_p1….ctex` / `hud_p2….ctex`
- cowdata null after empty image decode

`kapes_player_hud.gd` had `const P1_PLATE := preload("res://assets/ui/hud/hud_p1.png")` (same for p2). `class_name KapesPlayerHUD` compiles on **every** project load, including Idle labs. A failed preload became a parse error; `m0_hud.gd` then failed as a dependent. The labs never instantiated HUD — they still ate the compile failure.

Pillow could decode the old WebP payload; Godot’s lossless-WebP path still failed for the editor/runtime loader. Source PNG was healthy. The WebP `.ctex` path was not.

## HUD Cache / Source Fix

Sources were not regenerated. Originals were not copied to backup (they are valid).

Targeted cache only (not a `.godot` wipe):

- deleted `hud_p1.png-4dfa7c978924ea04a55e5573945be171.ctex` / `.md5`
- deleted `hud_p2.png-320648edbdb82b610f6f7a1f97578723.ctex` / `.md5`

`.import` params for those two plates only:

- `compress/mode=3` (VRAM uncompressed, pixel-identical, no WebP)
- `detect_3d/compress_to=0` (do not re-pack as 3D/WebP)

Headless reimport touched **only** `hud_p1.png` and `hud_p2.png`. New `.ctex` size is 6,290,164 bytes each (2172×724×4 + header). No `RIFF`/`WEBP` inside.

`kapes_player_hud.gd` now `load()`s plates at `_ready` instead of `preload()` at parse time. If a plate fails later, battle HUD art can warn; GDScript still compiles. No visual redesign.

`hud_icon_sheet.png` was not in the failure list and was not changed.

## Benchmark Dependency Isolation

Lab scenes never referenced `m0_hud.gd` or `kapes_player_hud.gd`. The real coupling was global `class_name` + const `preload` of the plates.

After this recovery:

- labs instantiate a dedicated `BenchmarkOverlay` `CanvasLayer` + `Label` only
- runtime tree check `battle_hud_instanced=false`
- scene files contain no HUD scripts
- validation `hud_isolation=true`

The animation benchmark runs even if battle HUD art is broken.

## Tereré Runtime Test

Headless load of `TerereIdleRetargetBenchmarkV1Lab.tscn`: **zero blocking errors**.

| Check | Result |
| --- | --- |
| Rest (`1`) | `RestRoot` only, not playing |
| Traditional (`2`) | `idle` playing, time advanced |
| Semantic (`3`) | `idle` playing, time advanced ~1.0 s / 3.667 s |
| Camera on switch | unchanged `(0, 1.6, 5.5)` |
| HUD | none |
| InputMap actions | all six present |

## Jaguareté Runtime Test

Headless load of `JaguareteIdleRetargetBenchmarkV1Lab.tscn`: **zero blocking errors**.

Same method contract. Semantic `idle` advanced to ~1.000 s. Camera unchanged `(0, 2.1, 7.0)`. `SELFTEST … ok=true hud=false`.

## Remaining Project Errors

Classified from Godot 4.7.2 `--headless --import --quit`, `--headless --editor --quit`, and both lab runs:

| Class | What |
| --- | --- |
| **BENCHMARK_BLOCKING** | **None.** Lab run itself emitted no WebP, cowdata, `.ctex`, HUD parse, or playback errors. |
| **UNRELATED_PROJECT_ERROR** | None observed in these editor/import/lab logs. Historical AccuRIG FBX / `.fbm` WebP noise remains out of scope (already `.gdignore`d under `source_rigged/`). |

`KapesPlayerHUD` re-registered during import with no preload parse failure.

## Human Instructions

Validation authority is the **running** scene, not the editor 3D view.

1. In Godot, open `scenes/debug/TerereIdleRetargetBenchmarkV1Lab.tscn`.
2. **Run Current Scene (F6)**. Click the game window so it has focus.
3. Overlay top-left should read `TERERÉ` / `REST` and `Run scene (F6) for controls`.
4. Press **`1`** — T / rest pose, no idle motion.
5. Press **`2`** — Traditional Idle, motion, `SPACEBAR / PLAYING`, animation time advancing.
6. Press **`3`** — Semantic Idle, different standing pose, time advancing.
7. `4` skeleton, `5` bbox, `6` reset camera. RMB orbit, wheel zoom, WASD move camera. Space pauses playback.

Repeat with `JaguareteIdleRetargetBenchmarkV1Lab.tscn` (`JAGUARETÉ` in the overlay).

If numbers still orbit the viewport **without** F6, that is Godot Emulate Numpad in the editor. It is expected. Do not judge Idle A/B from the editor viewport.

If the Game workspace is in inspect/select mode rather than sending input to the game, click the running window first.

## Files Modified

- `scripts/debug/idle_retarget_benchmark_lab.gd` — runtime input, method contract, overlay, playback verify, camera isolation
- `scripts/debug/validate_idle_retarget_benchmark_v1_labs.gd` — method + 1 s playback + HUD isolation proof
- `scripts/ui/kapes_player_hud.gd` — runtime `load()` of plates (parse isolation)
- `project.godot` — `benchmark_rest` / `traditional` / `semantic` / `skeleton` / `bbox` / `camera_reset` (top-row + numpad)
- `assets/ui/hud/hud_p1.png.import`, `hud_p2.png.import` — uncompressed import, no WebP
- `tests/test_clean_rig_idle_retarget_benchmark_v1.py` — labs must not preload battle HUD
- `docs/generated/CLEAN_RIG_IDLE_RETARGET_BENCHMARK_V1_GODOT.json` — regenerated proof
- `.godot/imported/hud_p1*.ctex/.md5`, `hud_p2*.ctex/.md5` — targeted reimport only

Not modified: Clean Rig `.blend`/`.glb`, idle benchmark GLBs, Production V4, battle scenes, fighter catalog, `hud_p1.png` / `hud_p2.png` source pixels.

## Recommended Next Step

Human F6 A/B:

1. Tereré `1` vs `2` vs `3` (same camera).
2. Jaguareté `1` vs `2` vs `3` (same camera).

Decide visually whether Semantic Idle on Clean Rig V1 is acceptable as an Idle candidate. Traditional remains technically `DEFORMATION_INVALID` from the prior bake report; this lab only makes that comparison visible and controllable.
