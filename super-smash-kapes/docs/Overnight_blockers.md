# Overnight Presentation Blockers

## BLOCKER-001 — Headless screenshot capture unavailable

### Objective
Capture runtime screenshots for menu/battle/pause/results validation.

### Exact Failure
No reliable headless screenshot pipeline configured in this environment without invasive dependencies.

### Evidence
Godot headless run completes without image output path configured.

### Files Involved
N/A

### Attempts
Skipped optional screenshot capture per task instructions when unreliable.

### Current Understanding
Human visual validation remains required for presentation acceptance.

### Recommended Resolution
User captures screenshots during morning playtest; optionally add `--write-movie` or custom capture hook later.

### Can Other Work Continue?
YES

---

## BLOCKER-002 — Dynamic scoreboard alignment deferred

### Objective
Overlay dynamic scoreboard atlas onto baked hero background scoreboard.

### Exact Failure
Precise UV/screen alignment not reliable without manual art calibration in-editor.

### Evidence
V3 composition intentionally disabled separate scoreboard overlay.

### Files Involved
`scripts/stages/defensores_stage.gd`

### Attempts
`set_scoreboard_state()` retained as no-op; baked hero scoreboard used.

### Current Understanding
Static coherent stadium preferred over floating duplicate scoreboard.

### Recommended Resolution
Future milestone: align scoreboard regions with hero art using editor markers.

### Can Other Work Continue?
YES

---

## BLOCKER-003 — Mosaic/crowd event presentation deferred

### Objective
Event-only mosaic/crowd crossfade in stand region.

### Exact Failure
Alignment quality uncertain; normal gameplay must remain clean.

### Evidence
API hooks added (`show_mosaic`, `hide_mosaic`, `cycle_match_intro_mosaic`) without visual activation.

### Files Involved
`scripts/stages/defensores_stage.gd`

### Attempts
Deferred implementation; assets remain preloaded for future events.

### Current Understanding
Hero background already contains crowd imagery for normal play.

### Recommended Resolution
### Can Other Work Continue?
YES

---

## BLOCKER-010 — Fighter V2 visual acceptance requires human screenshots — SUPERSEDED BY V3

See BLOCKER-013.

---

## BLOCKER-011 — Baked transparent portrait PNGs deferred — RESOLVED

Baked to `assets/ui/portraits/terere_portrait.png` and `jaguarete_portrait.png`.

---

## BLOCKER-012 — 3D SubViewport victory portrait deferred — ACCEPTED

Superseded by dedicated 2D victory art assets under `assets/ui/victory/`.

---

## BLOCKER-013 — V3 visual acceptance requires human screenshots

### Objective
Confirm SHORT vs TALL relationship, HUD containment, and Defensores victory composition on screen.

### Exact Failure
Headless cannot capture viewport screenshots.

### Evidence
`MODEL_AUDIT` shows Tereré body_h=2.40, Jaguareté body_h=3.15 (ratio 1.31). Tests 60/60.

### Recommended Resolution
Human checklist in `docs/CANONICAL_FIGHTER_SIZE_HUD_VICTORY_V3_REPORT.md`.

### Can Other Work Continue?
YES

---

## BLOCKER-014 — CAMBIAR KAPES button art missing

### Objective
Dedicated graphical button asset for CAMBIAR KAPES on victory screen.

### Current State
V4 uses a themed navy/gold/tricolor programmatic art panel + transparent hotspot
matching REVANCHA / MENÚ family (not default Godot chrome).

### Recommended Resolution
Add `victory_btn_change_kapes.png` under `assets/ui/victory/common/` when available.

### Can Other Work Continue?
YES

---

## BLOCKER-015 — Blender unavailable for Mixamo→Jaguareté humanoid bake — RESOLVED

### Objective
Produce baked retargeted idle animation for Jaguareté v2.

### Resolution
Blender 2.83.1 operational. Offline bake at `assets/fighters/processed/jaguarete/jaguarete_game_ready_idle.glb`.
ActorCore benchmark now uses same Blender toolchain.

### Can Other Work Continue?
YES

### Can Other Work Continue?
YES

---

## BLOCKER-018 — glTF export clamps skin weights to 4 influences

### ID
BLOCKER-018

### Subsystem
ActorCore benchmark / GLB export

### Description
Blender 2.83 glTF export warns that some vertices have more than 4 joint influences and keeps only the 4 highest weights (normalized). This can cause local mesh collapse on dense AccuRig skins (poncho, sash, tail, bombilla) until weights are rebuilt.

### Evidence
Export log: `WARNING: There are more than 4 joint vertex influences.The 4 with highest weight will be used (and normalized).`

### Impact
Idle articulation is present; deformation quality on accessories is HUMAN-REQUIRED. Not a pipeline stop.

### Can Other Work Continue?
YES

### Recommended Resolution
During human playtest, inspect poncho/sash/tail/bombilla. If tearing appears, rebuild weights to 4 influences in Blender before production migration.

---

## BLOCKER-017 — ActorCore FBX has no imported shape keys / blendshapes

### ID
BLOCKER-017

### Subsystem
ActorCore facial / AccuRig export

### Description
Both ActorCore FBX imports expose jaw, eye, tongue, and teeth bones, but Blender 2.83 FBX import reports 0 shape keys. Hurt/KO/victory/taunt faces are technically possible via facial bones, not via blendshapes in this package.

### Evidence
`docs/generated/TERERE_ACTORCORE_RIG.json` and `JAGUARETE_ACTORCORE_RIG.json` `shape_keys: []`. `autorig_actor.json` lists facial bones only.

### Impact
Facial expressions deferred. Idle body retarget is unaffected.

### Can Other Work Continue?
YES

### Recommended Resolution
If blendshape expressions are required, re-export AccuRig with morphs enabled or use CC4 facial profile; otherwise drive jaw/eyes/tongue bones in a later milestone.

---

## BLOCKER-016 — ActorCore benchmark GLBs lack Godot import sidecars in headless CI

### ID
BLOCKER-016

### Subsystem
ActorCore benchmark / Godot import

### Description
Benchmark GLBs under `processed/actorcore_benchmark/` may not receive `.import` sidecars during headless `--import`, so `ResourceLoader.load()` can fail.

### Evidence
Headless log: `No loader found for resource: ...terere_actorcore_idle.glb`

### Impact
Labs and track dump use `GLTFDocument` fallback until editor import runs once.

### Can Other Work Continue?
YES — benchmark pipeline, Blender bake, and motion audits continue.

### Recommended Resolution
Open project once in Godot editor or run editor quit-after scan; commit `.import` sidecars if desired for CI ResourceLoader path.

---

## BLOCKER-004 — Raw design PNGs required Godot import — RESOLVED

### Objective
Load portrait textures and reference images for HUD / Character Select / catalog.

### Exact Problem
Fighter raw design PNGs had no `.import` sidecars; runtime `load()` failed.

### Evidence
Headless log: `No loader found for resource: res://assets/fighters/raw_design/...`

### Attempts
Ran `Godot --headless --import`; all terere/jaguarete PNGs imported.

### Recommended Resolution
Run Godot import after adding new reference PNGs.

### Can Other Work Continue?
YES

---

## BLOCKER-005 — GDScript class_name load order — RESOLVED

### Objective
Parse fighter catalog and visuals without circular dependency errors.

### Exact Problem
`class_name` cross-references failed on first parse in Godot 4.7 headless.

### Attempts
Preload constants, lazy visual `load()`, string-path `extends` for character visuals.

### Can Other Work Continue?
YES

---

### Can Other Work Continue?
YES

---

## BLOCKER-007 — Character Select keyboard input not received — RESOLVED

### Objective
P1/P2 could not move selection or confirm ready on ELIGÍ TU KAPE screen.

### Exact Problem
Character Select relied on `_unhandled_input` on a nested CanvasLayer Control; keyboard events did not reach the handler in the desktop build.

### Evidence
Human playtest: A/D, F, SPACE, arrows, N produced no LISTO state or battle transition.

### Attempts
Added Main `_input` forwarding, Character Select `_input` + physical key fallbacks, transition guard, focus release, `SSK_SELECT_AUDIT`, `SSK_AUTO_SELECT_BATTLE`.

### Can Other Work Continue?
YES

---

## BLOCKER-008 — GLB filename differs from brief — RESOLVED

### Objective
Integrate user GLB models at expected paths.

### Exact Problem
Brief specified `terere_v1.glb` / `jaguarete_v1.glb`; on-disk files are `terere_glb_1.glb` / `jaguarete_glb_1.glb`.

### Resolution
Integrated using actual filenames.

### Can Other Work Continue?
YES

---

## BLOCKER-009 — Static GLB has no skeleton/animation — SUPERSEDED

### Objective
Skeletal combat animation.

### Impact
Archival 3DAI/v2 meshes remain static. Production ActorCore V3 now owns skeletal Idle.
Run/jump/attack/hit/KO still use restrained root proxy until the shared animation library milestone.

### Can Other Work Continue?
YES

---

## BLOCKER-021 — Mixamo standing idle cannot be copied onto AccuRIG without explosion

### Objective
True Mixamo standing idle on ActorCore bind.

### Exact Failure
Rest-relative and constraint retargets explode the skin (~10× volume). Clip-relative repair keeps AccuRIG T-pose + intra-clip breathing.

### Evidence
`docs/generated/ACTORCORE_RETARGET_MATH_AUDIT.md`, V4 bbox JSON (volume_ratio ≈ 1.06 / 1.01).

### Impact
Idle is skeletal and structurally valid, but will look like T-pose sway until a rest-axis solver exists.

### Can Other Work Continue?
YES

### Safe Fallback
Clip-relative V4 (current production).

### Recommended Resolution
Solve Mixamo↔AccuRIG rest-axis mapping without copying T→stand; then re-bake standing idle with bbox gate.

---

## BLOCKER-022 — No run locomotion Mixamo clip

Subsystem: animation library  
Severity: medium  
Description: `assets/fighters/animations/` has no run/walk FBX. Run is not mapped from an attack.  
Evidence: `MIXAMO_CLIP_POSE_AUDIT.json` inventory.  
Impact: Grounded movement keeps motion-proxy bob when `run` clip missing.  
Can Other Work Continue: YES  
Safe Fallback: Existing `glb_fighter_visual` RUN bob.  
Recommended Resolution: Add a Mixamo in-place run FBX and bake clip-relative.

---

## BLOCKER-023 — No victory celebration clip

Subsystem: animation library  
Severity: low  
Description: No celebration FBX. KO/death not used as victory.  
Evidence: semantic skip list in `export_actorcore_animation_library.py`.  
Impact: Results winner uses idle (T-pose sway) plus victory screen 2D art.  
Can Other Work Continue: YES  
Safe Fallback: Victory screen composition + idle.  
Recommended Resolution: Add a loopable victory Mixamo clip.

---

## BLOCKER-019 — Headless Godot does not write PackedScene imports for production GLBs


### Objective
Import `terere_game_ready_v3.glb` / `jaguarete_game_ready_v3.glb` as Godot PackedScenes with VRAM-compressed textures.

### Exact Failure
`Godot --import --headless` scans the GLBs but does not emit `.import` sidecars or `.scn` dest files. `ResourceLoader.exists(..., "PackedScene")` is false.

### Evidence
Validation and battle load via `GLTFDocument.append_from_file` (same family as BLOCKER-016). Fake `.import` stubs caused `Cannot open file ...scn` errors and were removed.

### Files Involved
`assets/fighters/processed/terere/terere_game_ready_v3.glb`
`assets/fighters/processed/jaguarete/jaguarete_game_ready_v3.glb`
`scripts/fighters/glb_fighter_visual.gd`

### Attempts
Copied working scene-import templates; headless still did not produce `.godot/imported/*.scn`. Runtime BPTC/S3TC compress applied after GLTFDocument generate.

### Current Understanding
Desktop editor open may import the GLBs for real. Headless battle remains correct through GLTFDocument + load-time texture compress.

### Recommended Resolution
Open the project once in Godot 4.7 editor so scene import can write PackedScenes; keep GLTFDocument fallback.

### Can Other Work Continue?
YES

---

## BLOCKER-020 — 0x8007000e desktop GPU reproduction still required

### Objective
Confirm D3D12 `CreateResource failed with error 0x8007000e` is gone on the human desktop GPU.

### Exact Failure
This environment is headless. `Performance.RENDER_VIDEO_MEM_USED` / `RENDER_TEXTURE_MEM_USED` report 0. Cannot prove the desktop OOM is fully gone.

### Evidence
Cause identified: lossless huge UI/stage PNGs + eager menu/select/victory/fallback preloads + multiple fighter texture sets. Mitigations implemented (lazy screens, unused stage textures not preloaded, VRAM compress class B/D, one ActorCore GLB per fighter, BPTC compress on runtime GLTF textures).

### Recommended Resolution
Human playtest: Menu → Select → Battle → Rematch on the same desktop that logged 0x8007000e. Watch F3 overlay VRAM/TEX and Output for CreateResource.

### Can Other Work Continue?
YES

