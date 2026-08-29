# Clean Rig V1 Idle Retarget Benchmark V1

## Primary Verdict

**SSK_CLEAN_RIG_IDLE_RETARGET_BENCHMARK_V1_READY_FOR_HUMAN_PLAYTEST**

Semantic Idle on Clean Rig V1 is technically healthy for **both** Tereré and Jaguareté (`STANDING_IDLE`, `volume_ratio <= 1.35`, `extreme_verts = 0`, limb-length error 0). Traditional rest-space Mixamo→CC_Base Idle is **not** technically healthy on either fighter (`DEFORMATION_INVALID` from localized extreme vertices).

This is **not** a production winner. Human visual playtest is still required. Battle, FighterCatalog, and V4 are unchanged.

## Executive Summary

Clean Rig V1 is the only target for this Idle-only benchmark. Mixamo `Idle.fbx` was inspected from scratch (`mixamorig5:`, frames 1–110, 30 FPS). Two new bake paths were built on the clean `.blend` authorities:

| Method | Tereré | Jaguareté |
| --- | --- | --- |
| Traditional rest-space CoB | FAIL — 421 extreme verts | FAIL — 1293 extreme verts |
| Semantic standing + intra-idle | PASS — STANDING_IDLE | PASS — STANDING_IDLE |

Traditional volume and limb lengths stayed inside gates; the mesh still spiked. Semantic lowered arms from T-pose, kept volume and bone lengths sane, and survived GLB roundtrip. Godot labs load only benchmark GLBs.

## Clean Rig Authority

Source of truth for this benchmark:

- `assets/fighters/processed/clean_rig_v1/terere/terere_clean_rig_v1.blend` / `.glb`
- `assets/fighters/processed/clean_rig_v1/jaguarete/jaguarete_clean_rig_v1.blend` / `.glb`

From `docs/generated/CLEAN_RIG_IDLE_BENCHMARK_BASELINE.json`:

- both skeletons: **101** bones, `CC_Base_Hip` present
- AccuRIG CC_Base parents: Hip under helper `root`; thighs under `CC_Base_Pelvis`; Head under `CC_Base_NeckTwist02`
- 1 skinned mesh, 1 material (`model_Pbr`)
- armature and mesh object transforms **normalized** (location 0, rotation 0, scale 1)
- rest upperarm from-down: Tereré **87.3°**, Jaguareté **82.1°** (valid T-pose, not Idle)
- no Idle action on the clean authorities
- textures: 2048×2048 Diffuse + Normal, fighter-specific `.fbm` paths (Blender/Python only; `source_rigged/` remains `.gdignore`d from Godot)

Not used as targets: V3/V4, `semantic_solver_v2` GLBs, `solver_v1`, `actorcore_benchmark`, raw AccuRIG FBX.

## Mixamo Idle Source

Fresh dump: `docs/generated/MIXAMO_IDLE_FOR_CLEAN_RIG_DUMP.json`

- file: `assets/fighters/animations/Idle.fbx`
- armature: `Armature`
- prefix: **`mixamorig5:`**
- 65 Mixamo bones
- action: `Armature|mixamo.com|Layer0`
- frames **1–110**, **30 FPS**
- rest is bind pose; **frame 1 is not rest** (Idle standing)
- Mixamo object: Rx **+90°**, scale **0.01** (FBX import). This is absorbed into rest-world `C`, not copied as a Godot runtime hack.
- local hip translation is large in Mixamo bone units (Y about −20 to −15). World hip Z is ~0.75. Benchmark root policy uses **world-up delta only**, scaled to the clean rig, with X/Y (Blender horizontal) zeroed.
- standing world channels (Idle, not T-pose): L/R shoulder from-down 45.3° / 36.8°, elbows 80.6° / 100.4°, knees ~50–52°

All required Mixamo suffixes from the shared map are present.

## Traditional Retarget Math

Shared map: `tools/blender/mixamo_to_cc_base_clean_v1_bone_map.json` (same 20 bones for both fighters). Prefix is discovered at bake time.

Rest is `matrix_local` after the Mixamo action is disconnected and pose is cleared — **not frame 1**.

Per mapped bone:

- `C = T_rest_world⁻¹ * S_rest_world`
- Mixamo `matrix_basis` is already rest-relative (`src_delta`)
- `target_basis_rot = C * src_delta * C⁻¹`
- location zero except hip
- hip: world **Z-up** delta only, scaled by `target_head_hip_span / mixamo_head_hip_span`; converted into hip local. No forward/side drift from Mixamo root X/Z.

No Euler copy. No raw quaternion copy. No V2/V3/V4 clip-relative / ±90 orientation path.

**Result:** bone lengths stay invariant and bbox volume stays `<= 1.35`, but **hundreds to thousands of vertices** still leave the rest envelope. Clean Rig V1 does **not** make naive rest-space Mixamo CoB Idle-safe. Likely residual local-axis / twist / wrist mismatch, not a missing bone in the 20-bone map.

## Semantic Retarget Method

Clean Rig V1 is the target. `semantic_solver_v2` output GLBs are not reused.

1. Profile native flexion axes on the **clean** rest pose (local X/Z probes; Y is twist).
2. Solve a canonical standing pose so Clean Rig world angles match Mixamo Idle **standing** (not T-pose, not Mixamo rest).
3. Add Mixamo **intra-idle** world-angle deltas (shoulder, elbow, knee, torso, head) with clamps. Invert shoulder-lowering so Mixamo from-down increase raises the arm.
4. Hip breathing from Mixamo **world Z** delta, height-scaled, horizontal translation stripped.
5. Modest shared clavicle/hand standing (8°/10°) — same numbers for both fighters, not per-character hacks.

No Mixamo matrices or quaternions are copied onto CC_Base.

## Tereré Traditional

- GLB/blend: `assets/fighters/processed/idle_benchmark_v1/terere/terere_idle_traditional_v1.*`
- `pose_classification`: **DEFORMATION_INVALID**
- max volume ratio: **1.043** (pass)
- extreme verts: **421** (fail)
- limb length error: **0**
- mid upperarm from-down: 43.9° / 40.7° (arms did leave T-pose)
- mid elbows: 81.7° / 98.5°
- root XZ: 0.128 m; foot drift: 0.391 m
- **technical_pass: false**

## Tereré Semantic

- GLB/blend: `assets/fighters/processed/idle_benchmark_v1/terere/terere_idle_semantic_clean_v1.*`
- `pose_classification`: **STANDING_IDLE**
- max volume ratio: **0.655** (bbox shrinks vs T-pose, expected)
- extreme verts: **0**
- limb length error: **0**
- mid upperarm from-down: **37.1° / 30.3°**
- mid elbows: **81.1° / 75.0°**
- mid hands from-down: 52.8° / 56.6°
- root XZ: 0.018 m; foot drift: 0.105 m; hip Z variance: 0.001 m
- **technical_pass: true**

## Jaguareté Traditional

- GLB/blend: `assets/fighters/processed/idle_benchmark_v1/jaguarete/jaguarete_idle_traditional_v1.*`
- `pose_classification`: **DEFORMATION_INVALID**
- max volume ratio: **0.682** (pass)
- extreme verts: **1293** (fail)
- limb length error: **0**
- root XZ: 0.181 m; foot drift: 0.570 m
- **technical_pass: false**

## Jaguareté Semantic

- GLB/blend: `assets/fighters/processed/idle_benchmark_v1/jaguarete/jaguarete_idle_semantic_clean_v1.*`
- `pose_classification`: **STANDING_IDLE**
- max volume ratio: **0.925**
- extreme verts: **0**
- limb length error: **0**
- mid upperarm from-down: **40.1° / 32.9°**
- mid elbows: **79.9° / 88.9°**
- mid hands from-down: **97.9° / 93.6°** — technical pass, but hands stay closer to T-pose than Tereré. Human must inspect palm/wrist.
- root XZ: 0.026 m; foot drift: **0.237 m** — possible visible plant shift from knee standing
- **technical_pass: true**

## Hand / Arm Quality

Measured at rest, first Idle frame, midpoint, last frame (see metrics JSON `rest_arm`, sample `arm`, `mid_arm`).

| Fighter | Method | Mid L/R upperarm from-down | Mid L/R elbow | Notes |
| --- | --- | --- | --- | --- |
| Tereré | Traditional | 44° / 41° | 82° / 99° | Arms lowered, but 421 extreme verts |
| Tereré | Semantic | 37° / 30° | 81° / 75° | Not T-pose; Mixamo-like elbow; hands ~53–57° |
| Jaguareté | Traditional | (deforming) | (deforming) | Rejected by extreme verts |
| Jaguareté | Semantic | 40° / 33° | 80° / 89° | Arms lowered; hands ~94–98° need visual check |

Semantic L/R asymmetry follows Mixamo Idle (source standing 45° vs 37°), not an accidental bake swap. No hyperextended-wrist detector beyond hand from-down and attachment (limb-length error 0 ⇒ hands stay on the chain). Human should reject snap-back or flipped palms if they appear in playtest.

## Grounding

- Traditional foot drift is large (0.39 m / 0.57 m) and is not a usable plant.
- Semantic Tereré foot drift 0.11 m; Jaguareté **0.24 m** — flag as possible slide from knee standing, not root walk (root XZ ≤ 0.026 m).
- Hip vertical breathing is tiny (1–3 mm world Z). Horizontal root policy held.

## Deformation Gates

Thresholds: `volume_ratio <= 1.35`, `extreme_verts = 0`, limb-length relative error ≤ 0.05, no principal-axis explosion, classification `STANDING_IDLE`.

Evaluated **every frame** 1–110 on the skinned mesh.

| Candidate | Volume | Axis | Limb | Extreme verts | Class | Pass |
| --- | --- | --- | --- | --- | --- | --- |
| Tereré traditional | 1.043 | 0.873 | 0 | 421 | DEFORMATION_INVALID | no |
| Tereré semantic | 0.655 | 0.884 | 0 | 0 | STANDING_IDLE | yes |
| Jaguareté traditional | 0.682 | 0.828 | 0 | 1293 | DEFORMATION_INVALID | no |
| Jaguareté semantic | 0.925 | 0.967 | 0 | 0 | STANDING_IDLE | yes |

## A/B Comparison

See `docs/generated/CLEAN_RIG_IDLE_AB_COMPARISON.json`.

| Topic | Traditional | Semantic |
| --- | --- | --- |
| Pose class | DEFORMATION_INVALID both | STANDING_IDLE both |
| Volume | inside gate | inside gate |
| Extreme verts | fail | 0 |
| Limb length | 0 | 0 |
| Upperarm | lowered, but mesh spikes | lowered, Mixamo-like |
| Elbow | Mixamo-scale bend | Mixamo-scale bend, clamped |
| Hands | unusable with spikes | Tereré plausible; Jaguareté T-pose-ish |
| Foot / root | 0.13–0.18 m root XZ, large foot drift | root XZ ~0.02 m |
| Amplitude | full Mixamo rest-relative motion | intra-idle only, clamped 12° |
| Per-character hacks | 0 (shared map + shared CoB) | 0 (shared solver; standing solved per rig) |
| Complexity | one CoB + hip policy | axis profile + standing scan + intra deltas |
| Future clips | map is reusable; **this CoB is not Idle-safe** | Idle-like standing clips maybe; attack/KO need new channels |

No automatic production winner. Semantic is the only **technically** playtestable Idle on Clean Rig V1 today.

## Blender Preview

Per fighter:

- `*_idle_traditional_v1.blend` — idle action active, Mixamo stripped, Space to play
- `*_idle_semantic_clean_v1.blend` — idle action active
- `*_idle_ab_preview_v1.blend` — actions `rest`, `idle_traditional`, `idle_semantic` (traditional active on open)

Human: open, press Space, switch action in the Dope Sheet / Action Editor.

## GLB Roundtrip

Each of the four GLBs was exported, imported into a fresh Blender 2.83 scene, and re-measured.

- skeleton **101** bones on all four
- semantic roundtrip keeps `STANDING_IDLE`, volume, extreme verts 0
- traditional roundtrip keeps the same failure mode (extreme verts)
- glTF resampled the clip to frames 0–88; deformation metrics match the pre-export bake

Proof: `docs/generated/TERERE_IDLE_GLB_ROUNDTRIP_V1.json` and `JAGUARETE_IDLE_GLB_ROUNDTRIP_V1.json`.

## Godot Benchmark Labs

- `scenes/debug/TerereIdleRetargetBenchmarkV1Lab.tscn`
- `scenes/debug/JaguareteIdleRetargetBenchmarkV1Lab.tscn`

Loads **only**:

1. Clean Rig V1 rest GLB
2. `idle_benchmark_v1` traditional GLB
3. `idle_benchmark_v1` semantic GLB

No FighterCatalog, no V4, no FBX, no fallback.

| Key | Action |
| --- | --- |
| 1 | CLEAN REST |
| 2 | TRADITIONAL IDLE |
| 3 | SEMANTIC IDLE |
| 4 | skeleton debug |
| 5 | bbox debug |
| 6 | reset camera |

Overlay: FIGHTER, METHOD, ASSET PATH, SKELETON BONES, ANIMATION, VOLUME RATIO, EXTREME VERTS, ROOT MOTION, POSE CLASSIFICATION.

Headless check: `scenes/debug/ValidateIdleRetargetBenchmarkV1Labs.tscn`.

Godot 4.7.2 imported all four benchmark GLBs (diffuse + normal sidecars). Lab validation:

- both labs `load_ok=true`, `fallback=false`
- 101 bones
- animation name `idle`, **21** skeletal tracks
- `runtime_retarget=false`, `proxy_idle=false`, `legacy_orientation_hack=false`
- assets only under `clean_rig_v1/` and `idle_benchmark_v1/`

Evidence: `docs/generated/CLEAN_RIG_IDLE_RETARGET_BENCHMARK_V1_GODOT.json`.

## Scalability

Traditional did **not** pass both fighters. **Do not** process the rest of the Mixamo library with this CoB:

- Reaction.fbx
- Mutant Punch.fbx
- Unarmed Jump.fbx
- Jump Attack.fbx
- Rib Hit.fbx
- Standing Melee Attack Downward.fbx
- Falling Back Death.fbx

The 20-bone map is generic. The rest-space math is generic. Skin spikes on Idle mean the same path is likely worse on punch/jump/KO.

Semantic won this Idle A/B on **gates**, not on line count. Intra-idle world channels (sway, flexion, hip breathe) can transfer to other **standing** clips with a new standing solve. Punch, jump, and death need clip-specific channels (reach, twist, airborne, collapse). Do not treat the Idle standing table as a universal pose.

## Production Safety

Unchanged:

- `scripts/fighters/fighter_catalog.gd` still `ACTORCORE_V4` + `*_game_ready_v4.glb`
- `FighterDefinition` / battle wrappers not edited
- production V4 SHA256 still  
  Tereré `D880B8E9FE03F8F0169728259A0C51F0A931AED401B4AA30A32BCED94EA0CEBE`  
  Jaguareté `460BEE0AF4CF0CE3F9550948E3E69D349A9E3C1D1EFADE786178C8E5D639553C`

## Automated Tests

Existing suite preserved. Added `tests/test_clean_rig_idle_retarget_benchmark_v1.py`:

- Clean Rig V1 is the bake target; V4 is not
- shared 20-bone map + Mixamo dump
- traditional and semantic-clean GLBs exist, 101 joints, Idle clip, no Mixamo nodes
- fighter texture SHA16 vs `.fbm` when present
- no lab ±90 orientation compensation / runtime retarget / proxy idle
- GLB roundtrip + volume/limb gates
- traditional currently **fails** extreme verts; semantic **passes** `STANDING_IDLE`
- production V4 SHA unchanged

## Human Validation Required

Technical pass ≠ visual approval. Please:

1. Open each `*_idle_ab_preview_v1.blend`, play `idle_semantic`, then `idle_traditional`.
2. Run the two Godot labs; 1/2/3 through rest / traditional / semantic.
3. Watch Jaguareté semantic **hands** (still high from-down) and **feet** (0.24 m drift).
4. Confirm textures and upright import with no manual ±90.

Do not promote semantic Idle to battle until that playtest says so.

## Files Created

- `tools/blender/clean_rig_idle_retarget_benchmark_v1.py`
- `tools/blender/mixamo_to_cc_base_clean_v1_bone_map.json`
- `assets/fighters/processed/idle_benchmark_v1/terere/*`
- `assets/fighters/processed/idle_benchmark_v1/jaguarete/*`
- `scripts/debug/idle_retarget_benchmark_lab.gd`
- `scripts/debug/terere_idle_retarget_benchmark_v1_lab.gd`
- `scripts/debug/jaguarete_idle_retarget_benchmark_v1_lab.gd`
- `scripts/debug/validate_idle_retarget_benchmark_v1_labs.gd`
- `scenes/debug/TerereIdleRetargetBenchmarkV1Lab.tscn`
- `scenes/debug/JaguareteIdleRetargetBenchmarkV1Lab.tscn`
- `scenes/debug/ValidateIdleRetargetBenchmarkV1Labs.tscn`
- `tests/test_clean_rig_idle_retarget_benchmark_v1.py`
- `docs/generated/CLEAN_RIG_IDLE_BENCHMARK_BASELINE.json`
- `docs/generated/MIXAMO_IDLE_FOR_CLEAN_RIG_DUMP.json`
- `docs/generated/MIXAMO_IDLE_SEMANTIC_CHANNELS_CLEAN_V1.json`
- `docs/generated/CLEAN_RIG_IDLE_AB_COMPARISON.json`
- `docs/generated/CLEAN_RIG_IDLE_BENCHMARK_RUN.json`
- `docs/generated/*_IDLE_TRADITIONAL_V1_METRICS.json`
- `docs/generated/*_IDLE_SEMANTIC_CLEAN_V1_METRICS.json`
- `docs/generated/*_IDLE_HAND_ARM_QUALITY_V1.json`
- `docs/generated/*_IDLE_GROUNDING_V1.json`
- `docs/generated/*_IDLE_GLB_ROUNDTRIP_V1.json`
- `docs/generated/CLEAN_RIG_IDLE_RETARGET_BENCHMARK_V1_GODOT.json`
- `docs/CLEAN_RIG_IDLE_RETARGET_BENCHMARK_V1_REPORT.md`

## Files Modified

None of: FighterCatalog, FighterDefinition, battle scenes, production V4 GLBs, Clean Rig V1 GLB authorities (opened as inputs only).

Bake script and generated docs/assets as listed above.

## Recommended Next Step

Human playtest **semantic** Idle in the two Godot labs and the A/B `.blend` files. Keep production V4. Do **not** batch the remaining Mixamo clips. If semantic Idle looks good, next work is clip-specific semantic channels or a traditional CoB that kills extreme verts — not a library bake.
