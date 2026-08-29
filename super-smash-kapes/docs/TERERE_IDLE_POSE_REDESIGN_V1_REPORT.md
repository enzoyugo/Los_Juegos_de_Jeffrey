# Tereré Idle Pose Redesign V1

## Primary Verdict

**SSK_TERERE_IDLE_POSE_REDESIGN_V1_READY_FOR_HUMAN_SELECTION**

Three new static canonical Tereré standing poses were authored on Clean Rig V1 semantic bones. They are technically healthy, visibly distinct from each other and from the frozen semantic baseline, and ready for human silhouette selection. No candidate is auto-picked. Mixamo idle motion was not baked. Jaguareté remains frozen.

This is not a production wire. Battle, catalog, Clean Rig, Traditional Idle, Production V4, and Jaguareté idle were not touched.

## Why V2 Was Not Selected

V2 restored the frozen semantic baseline and applied tiny standing-only deltas (clavicle/upperarm/elbow within a few degrees). All of original baseline, rejected Polish V1, and V2_A / V2_B / V2_C were technically healthy. None produced a convincing human silhouette.

V2 failed because it was still the same constructed standing pose. Micro-tuning elbow and clavicle around that pose cannot convert a lowered T-pose into a compact fighting idle. The missing degree of freedom was **upperarm secondary (forward / inward)**, not another ±2° primary sweep.

## Human Visual Problem

Tereré still read as a **rig / lowered T-pose**:

- upper arms too far from the torso
- arms too lateral
- hands too far outward
- shoulder silhouette too wide
- pose felt constructed rather than relaxed

The target is a short, compact, charismatic, ready, slightly cartoon fighting-game idle — not T-pose, A-pose, military attention, or generic humanoid.

## Design Philosophy

This pass authors a **character-specific canonical standing pose**, then later (not now) lets Mixamo intra-idle motion animate **around** that pose.

Rules used:

- stop numerical sweeps around the old standing pose
- design three genuinely different silhouettes, not ±2° clones
- upper arms must point down, not out
- elbows bent so hands come forward / inward
- hands at lower-rib / upper-hip height, closer to the body
- small fighting-game asymmetry, not a boxing caricature
- keep the existing compact legs
- metrics support review; they do not rank or pick a winner

A forward-compact probe chose upperarm secondary sign `+1.0` because it improved left-hand forward reach and reduced lateral width versus the opposite sign.

## Baseline

Original semantic standing pose (Idle Benchmark V1 / frozen Polish V1 baseline):

`assets/fighters/processed/idle_benchmark_v1/terere/terere_idle_semantic_clean_v1.glb`

Key silhouette (static, no Mixamo motion):

| Metric | Value |
| --- | --- |
| Spine from up | 12.0° |
| Upperarm from down L/R | 35.5° / 28.0° |
| Upperarm down from horizontal L/R | 54.5° / 62.0° |
| Elbow flex L/R | 79.8° / 76.6° |
| Hand lateral L/R | 0.521 / 0.383 |
| Hand forward L/R | 0.109 / −0.071 |
| Shoulder width | 0.857 |
| Knee flex L/R | 20.4° / 42.1° |

Front view still reads wide / constructed. This is the 1-key comparison in the lab.

## Pose A — Relaxed Compact

Philosophy: arms fairly low, hands near hips/ribs, relaxed elbows, minimal fight stance.

Authored standing (not a baseline ±2°):

- spine 8, head −6
- clavicle 4 / 2
- upperarm L 62 + 16 forward, R 66 + 14 forward
- elbow 86 / 84
- hands quiet (6 / 2)
- knees unchanged at 40

Measured:

| Metric | Value |
| --- | --- |
| Upperarm from down L/R | 21.2° / 16.9° |
| Upperarm down from horizontal L/R | 68.8° / 73.1° |
| Elbow flex L/R | 85.8° / 80.6° |
| Hand lateral L/R | 0.457 / 0.327 |
| Hand height L/R | 0.741 / 0.658 |
| Volume ratio | 0.574 |

This is the most “arms down” candidate. Side view shows the new hang-and-bend clearly. Front view is narrower than baseline, but the gourd + poncho still set a wide torso.

## Pose B — Game Ready

Philosophy: hands slightly more forward/up, elbows bent, compact fighting-game stance, small lead/rear asymmetry.

Authored:

- spine 7, head −4
- clavicle 3 / 1
- upperarm L 50 + 26 forward, R 58 + 20 forward
- elbow 90 / 86 (SAFE max on lead)
- small hand asymmetry
- knees unchanged

Measured:

| Metric | Value |
| --- | --- |
| Upperarm from down L/R | 36.1° / 27.1° |
| Upperarm down from horizontal L/R | 53.9° / 62.9° |
| Elbow flex L/R | 89.8° / 82.6° |
| Hand lateral L/R | 0.455 / 0.355 |
| Hand forward L/R | 0.162 / −0.012 |
| Hand height L/R | 0.796 / 0.657 |
| Volume ratio | 0.591 |

Lead arm is higher / more forward. Rear arm stays lower. Upperarm down-angle stays inside the requested visual band.

## Pose C — Cartoon Fighter

Philosophy: stronger readable readiness, still natural, not a boxing caricature.

Authored:

- spine 10, head −8
- clavicle 2 / 1
- upperarm L 54 + 30 forward, R 62 + 22 forward
- elbow 90 / 82
- quieter wrists
- knees unchanged

Measured:

| Metric | Value |
| --- | --- |
| Upperarm from down L/R | 34.7° / 24.8° |
| Upperarm down from horizontal L/R | 55.3° / 65.2° |
| Elbow flex L/R | 89.8° / 78.6° |
| Hand lateral L/R | 0.443 / 0.346 |
| Hand forward L/R | 0.167 / −0.006 |
| Hand height L/R | 0.800 / 0.657 |
| Volume ratio | 0.589 |

Most readable forward left-hand pose. Asymmetry is still small. Not a boxing guard.

## Arm / Hand Silhouette

Primary redesign was upperarm direction + hand location.

Compared with baseline:

- A drops the upper arms furthest (from-down 35° → 21°)
- B / C keep down-from-horizontal in the 35–60° visual band and add forward secondary
- all three increase elbow bend
- all three reduce hand lateral vs baseline (L 0.521 → 0.443–0.457)
- wrists stay small / neutral
- no candidate was optimized toward volume

Right-hand forward remains near zero or slightly negative. That is reported for human review, not “fixed” by another micro-sweep. The gourd body is wide; arms attach at the sides, so a front silhouette will never become a stick-figure guard.

Front concept target remains: hands in a compact `O / ( ) BODY ( )` reading rather than `( ) ---- BODY ---- ( )`. Side and 3/4 views show the change more clearly than front.

## Torso

Nearly upright with slight forward readiness. Spine was **not** driven toward 0°.

| Pose | Spine from up |
| --- | --- |
| Baseline | 12.0° |
| A | 12.8° |
| B | 13.0° |
| C | 12.4° |

Clavicles were lowered / despread versus baseline 8/5 (A 4/2, B 3/1, C 2/1). No shrug. Chest still faces the opponent. Hips stay centered (`com_xz` 0,0).

## Legs

Unchanged on purpose. Calf primary remains 40 / 40. Knee flex is still 20.4° / 42.1°. Feet stay planted on the compact stance that already worked. Legs were not unsquatted to chase volume.

## Technical Gates

Every pose passed:

| Gate | A | B | C |
| --- | --- | --- | --- |
| 101 bones (roundtrip) | 101 | 101 | 101 |
| Skin / texture | Tereré `model_Pbr_Diffuse` 2048 packed | same | same |
| Extreme verts | 0 | 0 | 0 |
| Limb length rel error | 0.0 | 0.0 | 0.0 |
| Classification | STANDING_IDLE | STANDING_IDLE | STANDING_IDLE |
| Technical pass | true | true | true |
| Legacy axis hack | false | false | false |
| Mixamo quaternion copy | false | false | false |
| Hand/body intersection heuristic | false | false | false |
| Upright / grounded | yes | yes | yes |

Clean Rig V1 authority hashes are unchanged. GLTF still warns about >4 joint influences (existing AccuRIG skin, not a new explosion).

## Contact Sheet

`docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_CONTACT_SHEET.png`

Rows: Baseline, Pose A, Pose B, Pose C  
Columns: Front, 3/4 Front, Side

Stills were rendered from the exported GLBs, then composed with Pillow (Blender pixel-loop stitching is not used).

## Godot Human Lab

`scenes/debug/TerereIdlePoseRedesignV1Lab.tscn`

Run the scene (F6). Overlay:

```
TERERÉ IDLE POSE REDESIGN

1 BASELINE
2 RELAXED COMPACT
3 GAME READY
4 CARTOON FIGHTER
```

Standalone scene tree: WorldEnvironment, DirectionalLight3D, Camera3D, Floor, ModelSlot, CanvasLayer/Overlay. Dedicated script only — does **not** extend `actorcore_animation_lab.gd`, `production_animation_lab.gd`, or `semantic_solver_v2_lab.gd`.

Keys 1–4 instantiate **one** candidate at a time into `ModelSlot`. Camera transform is scene-authored and frozen (no orbit, no `look_at` in this lab). Frame 0 of the 1-frame pose clip is applied, then paused at `speed_scale = 0`.

Godot 4.7.2 imported the three new GLBs. Headless switch check printed `POSE_LAB_SWITCH_OK`. Standalone compatibility-window launch stayed open with no `Node not inside tree`.

## Jaguareté Frozen Authority

`docs/generated/JAGUARETE_IDLE_APPROVED_AUTHORITY.json`

| Field | Value |
| --- | --- |
| Status | HUMAN_APPROVED_PENDING_PRODUCTION_INTEGRATION |
| GLB | `assets/fighters/processed/semantic_idle_polish_v1/jaguarete/jaguarete_idle_semantic_polished_v1.glb` |
| Blend | same stem `.blend` |
| GLB SHA256 | `e5e4dd145cc454bab39c456a3fbe8f194f56ceab0e9deb8fbb4a87d1686943a4` |
| Blend SHA256 | `dcecb1673ddf52dc41a8719ab61091e0b660e35de022928f4cfad19590eeebec` |
| Animation | `idle` |
| Bones | 101 |
| Rebaked | no |

Byte-identical to the previously frozen Polish V1 Jaguareté file. Standing pose, semantic idle, GLB, and parameters were not modified.

## Production Safety

Not touched:

- Clean Rig V1
- Traditional retarget
- Jaguareté approved idle
- Production V4 (`terere_game_ready_v4.glb` / `jaguarete_game_ready_v4.glb` hashes unchanged)
- `FighterCatalog` remains `ACTORCORE_V4`
- battle, hitboxes, hurtboxes, movement, stage, UI
- other Mixamo clips

Outputs live only under `idle_pose_redesign_v1/` plus debug lab / docs / tests.

## Human Selection Required

**STOP.** Do not animate Pose A/B/C yet. Do not assume Mixamo Idle will sit on them automatically.

Human must choose:

- BASELINE
- A RELAXED COMPACT
- B GAME READY
- C CARTOON FIGHTER
- or NONE

Only after that choice does the selected pose become **Canonical Tereré Standing Pose V1**.

Future architecture (prepared, **not executed**):

```
Selected Canonical Pose
+ semantic intra-idle deltas
= Tereré Production Semantic Idle
```

Mixamo must provide breathing, sway, head, and subtle shoulder/elbow/hand motion. Mixamo must **not** redefine the base stance.

## Files Created

- `tools/blender/terere_idle_pose_redesign_v1.py`
- `tools/compose_terere_idle_pose_redesign_v1_contact_sheet.py`
- `scripts/debug/terere_idle_pose_redesign_v1_lab.gd`
- `scenes/debug/TerereIdlePoseRedesignV1Lab.tscn`
- `tests/test_terere_idle_pose_redesign_v1.py`
- `docs/TERERE_IDLE_POSE_REDESIGN_V1_REPORT.md`
- `docs/generated/JAGUARETE_IDLE_APPROVED_AUTHORITY.json`
- `docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_METRICS.json`
- `docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_RUN.json`
- `docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_{A,B,C}_METRICS.json`
- `docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_{A,B,C}_ROUNDTRIP.json`
- `docs/generated/TERERE_IDLE_POSE_REDESIGN_V1_CONTACT_SHEET.png`
- `docs/generated/terere_idle_pose_redesign_v1_screenshots/*.png`
- `assets/fighters/processed/idle_pose_redesign_v1/terere/terere_idle_pose_redesign_v1_{a,b,c}.{glb,blend}`

## Files Modified

None of the forbidden production / Jaguareté / Clean Rig / catalog / battle files.

Godot import added `.import` sidecars for the new GLBs and contact-sheet PNGs.

## Recommended Next Step

Open `scenes/debug/TerereIdlePoseRedesignV1Lab.tscn` (F6) or launch it standalone. Compare 1/2/3/4. Use the contact sheet for front / 3/4 / side. Camera in this lab is frozen.

Pick BASELINE, A, B, C, or NONE. After that selection, bake Mixamo intra-idle **around** the chosen canonical pose. Do not start from V2 deltas. Do not integrate into battle until the human silhouette is approved.

## Godot 4.7 Tree Fix

**SSK_TERERE_IDLE_POSE_REDESIGN_LAB_RUNTIME_READY**

Immediate crash:

```
ERROR: Node not inside tree. Use look_at_from_position() instead.
at actorcore_animation_lab.gd:40
```

Cause: `Camera3D.look_at()` ran **before** `add_child(cam)` in `_build_environment()`. That lab is the base of `production_animation_lab.gd` and `semantic_solver_v2_lab.gd`, so opening those historical labs (or an editor layout that still had them) produced the stack the human saw.

Fix (visual intent unchanged):

```
add_child(cam)
cam.position = ...
cam.look_at(...)
```

Same one-line order fix in `jaguarete_animation_lab.gd` (identical camera construction). `clean_rig_lab.gd` already `look_at`s a camera that is in the tree; left alone.

Pose redesign lab changes:

- no inheritance of the ActorCore / production / semantic-solver stack
- instantiate one GLB at a time into `ModelSlot`
- no orbit / WASD camera mutation
- no `look_at` in this script
- 1/2/3/4 only
- static pose: seek frame 0, pause, `speed_scale = 0`

Verification:

| Check | Result |
| --- | --- |
| Headless pose lab | exit 0, `POSE_LAB_SWITCH_OK`, no tree error |
| Windowed pose lab (`gl_compatibility`, Dummy audio) | process stayed running, OpenGL 3.3, no tree error |
| `TerereActorCoreAnimationLab.tscn` | exit 0, no tree error |
| `TerereProductionAnimationLab.tscn` | exit 0, no tree error |
| `TerereSemanticSolverV2Lab.tscn` | exit 0, no tree error |
| pytest `test_terere_idle_pose_redesign_v1.py` | 11 passed |

Files modified this pass: `scripts/debug/actorcore_animation_lab.gd`, `scripts/debug/jaguarete_animation_lab.gd`, `scripts/debug/terere_idle_pose_redesign_v1_lab.gd`, `scenes/debug/TerereIdlePoseRedesignV1Lab.tscn`, `tests/test_terere_idle_pose_redesign_v1.py`.
