# ActorCore Semantic Idle V2 — Arm Chain Pass

## Primary verdict

**SSK_ACTORCORE_SEMANTIC_V2_ARM_CHAIN_READY_FOR_HUMAN_PLAYTEST**

Canonical standing and Idle now export a lowered arm chain for both fighters. Production V4 is not swapped. Battle, catalog, HUD, victory, and canonical sizes are untouched.

This is **not** a production-ready claim. Human preview of REST vs CANONICAL STANDING vs IDLE is still required.

## Root cause

The arm pose was computed correctly in Blender, then **thrown away while keying `canonical_standing`**.

Broken order:

1. Apply native standing on the pose bones (arms lower).
2. Assign a new empty action named `canonical_standing`.
3. Blender evaluates that empty action as **rest / T-pose**.
4. Key the current pose → **T-pose is baked**.

Idle did not hit this bug: it posed **after** assigning the action, then keyed. GLB before the fix:

| clip | L_Upperarm node quat angle |
| --- | --- |
| rest | 27.3° (bind) |
| canonical_standing | 27.3° (**identical to rest**) |
| idle | 84.4° (bind + lowering) |

Godot key 2 therefore showed T-pose arms. Clavicles and hands were also never keyed.

## Fix

- Assign the action **before** posing, then key (`new_action` → pose → key).
- Drive the deform arm chain only: clavicle, upperarm, forearm, hand.
- Do **not** key twist/helper bones.
- Compose primary lowering + secondary forward on clavicle/upperarm.
- Shared `CC_Base` axes; amplitude table only:
  - Tereré: upperarm 62° + 14° forward, elbow 12°, clavicle 8°
  - Jaguareté: upperarm 55° + 18° forward, elbow 16°, clavicle 10°
- Mixamo intra-idle deltas still add only to primary, after standing.

GLB after the fix (L_Upperarm node quat angle):

| fighter | rest | canonical_standing | idle |
| --- | --- | --- | --- |
| Tereré | 27.3° | **89.6°** | 89.6° |
| Jaguareté | 10.4° | **59.6°** | 59.6° |

Bake-time world “from down” (T-pose ≈ 87°/82°):

| fighter | REST | STANDING | IDLE mid |
| --- | --- | --- | --- |
| Tereré | 87.3° | **17.2°** | 18.0° |
| Jaguareté | 82.1° | **27.4°** | 27.7° |

## Validation metrics

| gate | Tereré | Jaguareté |
| --- | --- | --- |
| pose class | `STANDING_IDLE` | `STANDING_IDLE` |
| max volume_ratio | **0.577** | **0.822** |
| volume limit 1.35 | PASS | PASS |
| extreme verts | 0 | 0 |
| limb length error | 0.0 | 0.0 |
| isolation A/B/C/D | all STANDING_IDLE | all STANDING_IDLE |
| pytest | 134 passed | 134 passed |
| Godot lab load | PASS | PASS |
| production V4 | unchanged | unchanged |

## Playtest artifacts

Blender (Space plays Idle). Switch NLA: `rest` / `canonical_standing` / `idle`.

- `E:\SuperSmashKapes\super-smash-kapes\assets\fighters\processed\semantic_solver_v2\terere\terere_idle_semantic_v2_preview.blend`
- `E:\SuperSmashKapes\super-smash-kapes\assets\fighters\processed\semantic_solver_v2\jaguarete\jaguarete_idle_semantic_v2_preview.blend`

Experimental GLBs:

- `E:\SuperSmashKapes\super-smash-kapes\assets\fighters\processed\semantic_solver_v2\terere\terere_idle_semantic_v2.glb`
- `E:\SuperSmashKapes\super-smash-kapes\assets\fighters\processed\semantic_solver_v2\jaguarete\jaguarete_idle_semantic_v2.glb`

Godot labs (1 REST · 2 CANONICAL STANDING · 3 IDLE · 4 SKELETON · 5 BBOX):

- `scenes/debug/TerereSemanticSolverV2Lab.tscn`
- `scenes/debug/JaguareteSemanticSolverV2Lab.tscn`

Audit: `docs/generated/SEMANTIC_V2_ARM_CHAIN_AUDIT.json`

## What to look at

1. Key 1 REST: arms in T-pose (expected).
2. Key 2 CANONICAL STANDING: arms **must leave T-pose**, hang/guard beside the torso, slight elbow bend, wrists not twisted.
3. Key 3 IDLE: same standing silhouette with small breathing/sway. Not a second T-pose.

If standing still reads as T-pose in the viewport, say which clip is playing. The exported standing clip is no longer identical to rest.

## Files created / modified

Created:

- `docs/ACTORCORE_SEMANTIC_V2_ARM_CHAIN_REPORT.md`
- `docs/generated/SEMANTIC_V2_ARM_CHAIN_AUDIT.json`

Modified:

- `tools/blender/semantic_idle_solver_v2.py`
- `tests/test_semantic_idle_solver_v2.py`
- experimental GLB/blend under `assets/fighters/processed/semantic_solver_v2/`
- generated standing pose + metrics JSON

Not modified: production V4 GLBs, catalog, fighter visuals, gameplay, HUD, victory.

## Recommended next step

Human playtest of keys 1/2/3 in the isolated labs. If the guard reads well, keep V2 experimental. Do not replace V4 yet.
