# Tereré Production Semantic Idle V1

## Primary Verdict

**SSK_TERERE_PRODUCTION_SEMANTIC_IDLE_V1_READY_FOR_HUMAN_APPROVAL**

Tereré now has a production Semantic Idle whose standing center is the human-selected **Pose B — Game Ready**. Mixamo Idle contributes low-amplitude intra-idle motion only. Arms stay compact. Feet do not slide. Technical gates pass. The clip is **not** wired into battle.

## Human Pose Selection

Idle Pose Redesign V1 review selected:

**POSE B — GAME READY**

Rejected as standing authority: original semantic baseline, Polish V1, V2 A/B/C, Pose A, Pose C.

## Pose B Authority

Frozen as `TERERE_CANONICAL_IDLE_POSE_V1`:

| Field | Value |
| --- | --- |
| Status | `CANONICAL_IDLE_CENTER` |
| selected_by_human | true |
| Source GLB | `assets/fighters/processed/idle_pose_redesign_v1/terere/terere_idle_pose_redesign_v1_b.glb` |
| SHA256 | `358b777da47787368def13d0a8284d162f4e9bd3c52fb6aa3ce42c2a49843cf6` |
| Upperarm L/R primary | 50 / 58 |
| Upperarm L/R secondary | 26 / 20 |
| Elbow L/R | 90 / 86 |
| Clavicle | 3 / 1 |
| Spine / head | 7 / −4 |
| Knees | 40 / 40 |

Record: `docs/generated/TERERE_CANONICAL_IDLE_POSE_V1.json` (standing_ops + bone transforms).

## Semantic Motion Architecture

```
final_pose(t) = POSE_B + filtered_semantic_delta(t)
```

Not Mixamo absolute pose. Source: `assets/fighters/animations/Idle.fbx` via `MIXAMO_IDLE_SEMANTIC_CHANNELS_CLEAN_V1.json` intra-from-standing channels only.

Documented gains (`terere_idle_semantic_v1`):

| Channel | Gain | Envelope |
| --- | --- | --- |
| torso_sway_gain | 0.45 | spine ±3.5° |
| spine_gain | 0.38 | (applied with torso) |
| shoulder_gain | 0.32 | clavicle ±1.8° |
| upperarm_gain | 0.22 | ±6.5° |
| elbow_gain | 0.30 | ±6.5° |
| wrist_gain | 0.10 | ±2.0° |
| head_gain | 0.32 | ±3.0° |
| hip_vertical_gain | 0.40 | world Y only, clamp 0.04 m |
| knee_gain | 0.16 | ±2.8° |

Upperarm **secondary** (Pose B forward compact) is never driven by Mixamo. After deltas, pose-space arm safety keeps from-down ≤ 48° and elbow flex ≥ 74°.

## Arm Motion Policy

Mixamo shoulder_lowering still contains up to +19.7° toward T-pose. That is transferred at **22%**, then envelope ±6.5°, then safety clamp.

Measured vs Pose B:

- L upperarm from-down max deviation **4.98°** (mean 1.92°)
- R upperarm from-down max deviation **4.51°** (mean 2.18°)
- never near-horizontal
- hands below shoulders on every frame

## Elbow Policy

Pose B elbows (90 / 86 standing ops, ~90° / 83° measured) stay the center. Mixamo elbow intra is already small; after 0.30 gain, max deviation is **1.75° / 1.13°**. No straight-arm frames.

## Hand / Wrist Policy

Wrists use 10% of noisy Mixamo hand channels, envelope ±2°. Hand world position vs Pose B max **1.3 cm / 1.9 cm**. Hands stay at lower-rib / upper-hip height, slightly forward/lateral, compact.

## Torso Motion

Pose B torso is authority. Mixamo torso_lean source amplitude is only ±0.74°, so even at 0.45 gain the spine deviation max is **0.06°**. Head nod uses 32% of source (source ±6.9°) inside ±3°. Subtle breathing/sway, not a re-hunch or military straighten.

## Root Motion

Policy: world X = 0, world Z = 0, world Y = small pelvis breath.

Measured `max_root_xz` = **0.0**. `hip_z_variance` = 0.013 m. No gameplay translation.

## Pose Similarity

| Metric | max | mean |
| --- | --- | --- |
| L upperarm from-down | 4.98° | 1.92° |
| R upperarm from-down | 4.51° | 2.18° |
| L elbow | 1.75° | 0.23° |
| R elbow | 1.13° | 0.38° |
| Shoulder width | 0.004 m | 0.003 m |
| L hand position | 0.013 m | 0.006 m |
| R hand position | 0.019 m | 0.010 m |
| Spine | 0.06° | 0.02° |

The clip stays in Pose B silhouette. Mixamo does not invent a second stance.

## Deformation Gates

| Gate | Result |
| --- | --- |
| Bones | 101 |
| Extreme verts | 0 |
| Limb length rel error | 0.0 |
| Volume ratio | 0.597 (stable, compact vs rest T-pose) |
| Classification | STANDING_IDLE |
| Technical pass | true |
| Root X/Z | 0.0 |
| Visible foot slide (in-clip XY span) | false |
| Foot vs rest T-pose | 0.100 (same compact stance as Pose B, not walk drift) |
| Texture | packed Tereré `model_Pbr_Diffuse` |
| Legacy axis hack | false |
| Sideways / T-pose class | no |

## GLB Roundtrip

`assets/fighters/processed/production_semantic_idle_v1/terere/terere_production_semantic_idle_v1.glb` (+ `.blend`)

Animation name: **idle**. Roundtrip: 101 bones, `ok: true`, `STANDING_IDLE`.

## Godot Lab

`scenes/debug/TerereProductionSemanticIdleV1Lab.tscn`

Standalone tree (WorldEnvironment, light, frozen Camera3D, floor, ModelSlot, overlay). Does **not** extend ActorCore / production / semantic-solver labs.

```
TERERÉ IDLE FINAL

1 POSE B STATIC
2 OLD SEMANTIC IDLE
3 PRODUCTION SEMANTIC IDLE V1
```

1 holds Pose B at frame 0. 2 and 3 play looping idle and share phase when switching. Camera does not move.

Launch with `--rendering-method gl_compatibility --audio-driver Dummy` to avoid Editor+F6 Windows commit exhaustion. That is an editor-host issue, not a fighter-asset failure.

## Jaguareté Frozen Authority

Unchanged. `JAGUARETE_IDLE_APPROVED_AUTHORITY` / Polish V1 GLB sha `e5e4dd145cc454bab39c456a3fbe8f194f56ceab0e9deb8fbb4a87d1686943a4`. No rebake.

## Human Validation

Required before production wire:

1. Pose B static vs Production idle — stance should match, with only breath/sway
2. Arms must not reopen toward T-pose
3. Hands stay compact
4. Feet stay planted
5. Compare against old semantic idle (key 2) to confirm the new center is Pose B, not the old Mixamo-standing idle

## Production Safety

Not touched: battle, FighterCatalog (`ACTORCORE_V4`), production V4 hashes, Clean Rig V1, Traditional retarget, other Mixamo clips, hitboxes, hurtboxes, movement, stage, HUD, Jaguareté.

## Files Created

- `tools/blender/terere_production_semantic_idle_v1.py`
- `scripts/debug/terere_production_semantic_idle_v1_lab.gd`
- `scenes/debug/TerereProductionSemanticIdleV1Lab.tscn`
- `tests/test_terere_production_semantic_idle_v1.py`
- `docs/TERERE_PRODUCTION_SEMANTIC_IDLE_V1_REPORT.md`
- `docs/generated/TERERE_CANONICAL_IDLE_POSE_V1.json`
- `docs/generated/TERERE_PRODUCTION_SEMANTIC_IDLE_V1_{METRICS,ROUNDTRIP,RUN}.json`
- `assets/fighters/processed/production_semantic_idle_v1/terere/terere_production_semantic_idle_v1.{glb,blend}`

## Recommended Next Step

Open the lab (standalone Godot, compatibility renderer). Approve or reject the motion on Pose B. Only after human approval should this GLB be considered for catalog/battle idle replacement. Do not wire it yet.
