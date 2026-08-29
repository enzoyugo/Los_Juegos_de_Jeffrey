# SMASH_STYLIZED_CHARACTER_PIPELINE_V2 Report

**Verdict:** `SMASH_STYLIZED_CHARACTER_PIPELINE_V2_REVIEW_READY`

**Internal visual grade (Fort V2 candidate):** **B+** — strong interim improvement, **not** production-canonical.

**Human visual approval required before any production catalog swap.**

## Primary verdict

Reusable Jeffrey stylized humanoid V2 generator exists. Fort V2 candidate GLB/blend/portraits are frozen beside V1 (V1 untouched). Production catalog still points at `fort_stylized_v1.glb`. Cartes/Pájaro V2 candidates were **not** mass-produced.

## Why V1 looked interim

| Failure | Observation |
|---------|-------------|
| Overall form | Head sphere + torso cube + limb cylinders with no designed silhouette |
| Proportions | Head/body not party-game caricature; torso reads as a slab |
| Shoulders | Missing / flat box corners |
| Limb attachment | Gaps; slap pose relocated hands into floating props |
| Hands/feet | Spheres / boxes without mitten/shoe readability |
| Neck | Absent or needle-thin |
| Face | Minimal cues; glasses floated as a single cylinder |
| Hair | Cap blob without volume |
| Costume | Gold rectangles pasted on torso, not garment-following |
| Materials | Lighting-sensitive; white crushed; gold blew yellow |
| Density | ~2k tris spent on disconnected primitives, not silhouette |

## Humanoid V2 architecture

```
tools/blender/smash/humanoid_v2/
  bpy_scene.py
  materials_v2.py
  stylized_humanoid_base.py
  fort_v2.py
  portrait_scene_v2.py
  rig_v2.py
  validation_v2.py
  build_fort_v2_candidate.py
```

Build:

```bat
blender --background --python tools/blender/smash/humanoid_v2/build_fort_v2_candidate.py
```

## Fort V2

| Item | Path |
|------|------|
| Candidate GLB | `assets/fighters/processed/fort/fort_stylized_v2_candidate.glb` |
| Editable blend | `assets/fighters/sources/fort/fort_stylized_v2_candidate.blend` |
| Candidate portraits | `fort_v2_candidate_portrait.png` / `fort_v2_candidate_victory.png` |
| Production V1 (frozen) | `fort_stylized_v1.glb` |

## V1 vs V2

Review package:

`E:\JeffreyAIResearch\outputs\runtime-review\smash_stylized_character_pipeline_v2\fort_comparison\`

Pairs: `V1_FRONT`/`V2_FRONT`, `V1_3Q`/`V2_3Q`, `V1_SIDE`/`V2_SIDE`, `V1_GAMEPLAY`/`V2_GAMEPLAY`, `V1_SELECT`/`V2_SELECT`, `V1_VICTORY`/`V2_VICTORY`

| Metric | V1 | V2 candidate |
|--------|----|--------------|
| Tris | ~2020 | ~9408 |
| GLB size | ~159 KB | ~324 KB |
| Materials | ad-hoc | SKIN/HAIR/WHITE/GOLD/DARK/GLASSES pack |
| Costume | pasted gold slabs | lapels/cuffs/collar/chest accent |
| Face | minimal | jaw/cheeks/brow/nose/mouth/hair volume/integrated glasses |

## Silhouette evaluation

Silhouette stills: `...\smash_stylized_character_pipeline_v2\fort_silhouette\`

Improved vs V1: larger head ratio (~30%), broader shoulders, tapered limbs, shoe mass, neck present.

**Not yet A:** still reads as constructed toy-parts more than a single sculpted caricature. Further silhouette iteration recommended before Cartes.

## Face / hair / costume

Caricature face block-in with sunglasses as defining trait; dark hair volume; white jacket + gold lapels/cuffs/star. Still low-poly caricature — not likeness.

## Materials

`JeffreyMaterialsV2`: SKIN, HAIR, WHITE_FABRIC (slight emit), GOLD (metal 0.55 + mild emit), DARK_FABRIC, GLASSES + frame. Standard view transform in portrait scene.

## Rig

Minimal armature (`root`→hips→spine→chest→head + limbs). Animations authored: IDLE, ATTACK, HIT, JUMP, KO.

**Skinning:** parent-only (no AUTO weights) after AUTO weights corrupted mesh export. Mesh does **not** deform with bones in GLB yet; clips exist on armature in `.blend` for next polish sprint.

## Animations

Present in blend/action set; GLB export includes armature + actions where exporter allows. Runtime still uses procedural limb motion hooks (`ArmL`/`ArmR`/`LegL`/`LegR`/`Star`) when loaded via stylized visual.

## Portraits

Three-point portrait scene; SELECT + VICTORY + angle set. Transparent film for UI-friendly crops.

## Triangle / runtime cost

~9.4k tris — within 5k–15k guideline. Fine for RTX 2060 class.

## Godot integration

- Production catalog **unchanged** (`fort_stylized_v1.glb`)
- Debug: `SSK_FORT_V2_CANDIDATE=1` loads candidate via `jeffrey_stylized_glb_visual.gd`
- Lab: `scenes/debug/SmashFortV2CandidateLab.tscn`
- Combat / collision unaffected

## Tests

See pytest module `tests/test_smash_stylized_character_pipeline_v2.py` + full suite / Godot lab in shipping notes.

## Review package

`E:\JeffreyAIResearch\outputs\runtime-review\smash_stylized_character_pipeline_v2\`

## Cartes status

**Not built.** Fort V2 is B+, not a clear reusable-base A. Cartes deferred.

## Pájaro status

**Untouched** (V1 remains strongest silhouette).

## Remaining gaps

- Silhouette still block-leaning; needs another form pass (joined torso sculpt / fewer hard cubes)
- True skinned deformation not stable yet
- Feet slightly below z=0 in validator (`feet_below_floor` warning)
- No human visual sign-off

## Human approval required

Open `fort_comparison\` and compare V1 vs V2 pairs.

Approve only if V2 is clearly more “designed toy caricature” and readable as Fort at gameplay distance.

Until then: keep V1 in production.
