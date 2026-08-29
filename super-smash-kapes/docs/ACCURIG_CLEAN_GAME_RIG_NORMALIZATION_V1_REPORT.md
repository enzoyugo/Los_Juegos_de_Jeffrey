# AccuRIG Clean Game Rig Normalization V1

## Verdict

**SSK_ACCURIG_CLEAN_RIG_V1_READY_FOR_HUMAN_PLAYTEST**

Both fighters now have a clean T-pose authority where:

- mesh and deform skeleton occupy the same world space
- object transforms are identity (location 0, rotation 0, scale 1)
- CC_Base names and 101-bone hierarchy are preserved
- original AccuRIG FBX files were not overwritten
- production V4 was not touched
- GLB round-trip keeps bones inside the mesh
- native arm / thigh / spine / head posing deforms without explosion

Mixamo / semantic retarget was **not** run. This milestone stops at a clean static rig. Human playtest of the isolated labs is the next gate before any animation authority is reconnected.

---

## What the source FBX actually contained

Untouched authorities (not modified):

- `assets/fighters/source_rigged/terere/actorcore/autorig_actor.fbx`
- `assets/fighters/source_rigged/jaguarete/actorcore/autorig_actor.fbx`

Blender 2.83 import of both files is the same layout:

| Object | Rotation | Scale | Parent |
|---|---|---|---|
| Armature | Rx **+90°** | **0.01** | none |
| Mesh `model` | Rx **−90°** (local) | 1 | Armature |

Mesh **world** is uniform 0.01 with identity rotation. Armature **world** is Rx+90 × 0.01.

Bones therefore draw along **−Y** (hip world ≈ `(0, −0.53, 0)` on Tereré). Weighted vertices live on a **+Z** standing body (head centroid ≈ `(0.04, 0.12, 1.28)`). World separation of bbox centers was **0.87 m** (Tereré) / similar on Jaguareté.

Rotating those far-away bones still deforms the correct mesh because the Armature modifier evaluates in bind space:

```
world_vertex = M * v_mesh
world_bone   = A * bone_armature
v_bind       = A⁻¹ * M * v_mesh
```

At rest, pose = bind, so the modifier returns the authored mesh. Viewport bones are drawn at `A * bone`. If `A ≠ M`, bones **look** displaced while skin still hits the right vertices.

Measured converter:

```
T = A⁻¹ * M  =  Rx −90°
```

That is the entire visual offset. It is **not** a broken bind, not a Mixamo problem, and not a Godot yaw hack.

FBX is binary FBX 7.2 from FBX SDK 2012.1. Combined with object scale 0.01, this matches Reallusion’s **Unity centimeter / Y-up** preset. Blender 2.83 then applies its Y-up → Z-up conversion as Armature Rx+90, and leaves the inverse on the mesh child.

**Primary factor: F — combination of D (FBX axis conversion), B (armature object), A/C (mesh child Rx−90), E (bind inverse keeps rest identity).**

---

## Why previous Mixamo / semantic work was misleading

Retarget assumed “bones in the viewport = anatomical locations.” On this source they are not. Solvers, Mixamo mapping, and Godot orientation were compensating for a **rest-space axis leftover**, so every downstream pose looked plausible in bind space and wrong in world space.

That work is paused. V4 and experimental Idle candidates stay as they are.

---

## Strategies tested (copies only)

| ID | What it does | Result |
|---|---|---|
| **A** | Leave object/parent matrices, only keep the modifier | Bones stay visually displaced. Rejected. |
| **B** | Bake `matrix_world` into mesh + armature data, objects → identity | Objects become clean. Bones **stay** at old world locations. Alignment 2/20. |
| **C** | After B, apply `T = M * A⁻¹` (Rx−90) to **armature data only** | Bones jump into the mesh. Rest deform error **0.0**. Winner. |
| **D** | Rebind by vertex-group name | Not required. Weights already valid. |

Winning machine choice on both fighters: **rotation_only** Rx−90, pair error **0.127 m** (Tereré) / **0.075 m** (Jaguareté) on Hip/Head/Hands/Feet/Clavicles. Then a shared floor translate so mesh min Z = 0.

Rest identity after C: posing nothing, evaluated verts match authored verts (max error 0). That is the proof we moved bones without changing bind deformation.

---

## Tereré clean rig

| Gate | Value |
|---|---|
| Alignment before | 2 / 20 inside, worst 1.59 m |
| Alignment after | **18 / 20** inside, worst 0.52 m |
| Skin | 50382 verts, 59 groups, 0 unweighted, max influences **6**, unchanged |
| Armature / mesh objects | identity |
| Bones | 101 |
| Rest deform error | 0.0 |
| L/R | +X = anatomical left. **No genuine inversion.** |
| GLB round-trip | aligned, 101 bones, identity objects |
| Native pose | Upperarm 30/60, Forearm 45/90, Thigh 30/45, Spine, Head: pass, no explosion |

The two “DISPLACED” rows are **NeckTwist01** (and the same metric on GLB reimport). The neck bone sits at the skull base; the Head vertex group centroid is in the skull volume (~0.52 m along +Z). That is a measurement alias (neck vs cranium), not a skeleton floating beside the body. Head, clavicles, hands, hips, feet, thighs are inside.

---

## Jaguareté clean rig

| Gate | Value |
|---|---|
| Alignment before | 2 / 20 inside, worst 1.92 m |
| Alignment after | **20 / 20** inside, worst 0.28 m |
| Skin | 47292 verts, 61 groups, preserved |
| Bones | 101 |
| Rest deform error | 0.0 |
| L/R | same CC convention, no inversion |
| GLB | 13.6 MB, round-trip aligned |

---

## Skin / influences

Original vertex groups and weights were **not rebound**. Strategy C only transforms rest bone matrices.

Blender 2.83’s glTF exporter **always** writes at most 4 influences per vertex (warning on both exports). The `.blend` still has up to 6. Four-influence reduction remains a later game pass, as requested. Do not treat the GLB as the weight-authority file; the blend is.

Textures: rebound to each fighter’s `.fbm` (`model_Pbr_Diffuse` / `model_Pbr_Normal`) and packed. Round-trip reimports rebound the same maps (AccuRIG uses identical filenames across characters).

---

## Native articulation

Posing **CC_Base_L_Upperarm / Forearm / Thigh / Spine01 / Head** on the normalized rig moves the mesh, volume ratio stays in ~0.84–1.22, no explosion.

**CC_Base_*_Calf** does not move the mesh. AccuRIG stores calf/knee paint on twist/share groups. That is true of the source style, not introduced by normalization. Recorded as informational, not a fail.

---

## Godot labs (isolated, not wired to battle)

- `scenes/debug/TerereCleanRigV1Lab.tscn`
- `scenes/debug/JaguareteCleanRigV1Lab.tscn`

Rest T-pose only. Keys: `[1]` rest, `[3]` skeleton overlay, `[4]` material debug, `[5]` bbox. No Idle, no Mixamo, no facing/battle hookup.

Run:

```
E:\Godot_v4.7.2-stable_win64_console.exe --path E:\SuperSmashKapes\super-smash-kapes res://scenes/debug/TerereCleanRigV1Lab.tscn
E:\Godot_v4.7.2-stable_win64_console.exe --path E:\SuperSmashKapes\super-smash-kapes res://scenes/debug/JaguareteCleanRigV1Lab.tscn
```

---

## Future fighter automation

One method worked for both characters:

```
tools/blender/normalize_accurig_game_rig.py
tools/normalize_fighter_rig.ps1
```

```
.\tools\normalize_fighter_rig.ps1 -Character both
```

Pipeline: AccuRIG FBX → this script → `*_clean_rig_v1.blend` + `.glb` + validation JSON → (later) semantic animation.

No per-character yaw/pitch hacks.

---

## Production safety

| Item | Status |
|---|---|
| Original AccuRIG FBX | untouched |
| Production V4 GLB | untouched |
| Mixamo Idle on clean V1 | **not applied** |
| Battle / HUD / Victory | untouched |
| Git | not committed, not pushed |

---

## Mixamo / semantic solver

**Unblocked as the next authority, not executed.**

Clean V1 is now the static T-pose those pipelines should consume. Do not retarget onto V4 or onto the raw FBX. Human playtest of the labs comes first.

---

## Known leftover limitations

1. Blender 2.83 glTF export clamps influences to 4. Blend file does not.
2. Tereré NeckTwist01 vs Head-weight centroid fails a strict “bone in painted region” test; visually the neck bone is at the neck.
3. Calf deform bones are twist-weighted; pose `CC_Base_*_Calf` itself is a poor smoke test.
4. Godot labs were not interactively playtested in this pass.

---

## Files created

- `assets/fighters/processed/clean_rig_v1/terere/terere_clean_rig_v1.blend`
- `assets/fighters/processed/clean_rig_v1/terere/terere_clean_rig_v1.glb`
- `assets/fighters/processed/clean_rig_v1/jaguarete/jaguarete_clean_rig_v1.blend`
- `assets/fighters/processed/clean_rig_v1/jaguarete/jaguarete_clean_rig_v1.glb`
- `docs/generated/ACCURIG_CLEAN_RIG_V1_TERERE.json`
- `docs/generated/ACCURIG_CLEAN_RIG_V1_JAGUARETE.json`
- `docs/ACCURIG_CLEAN_GAME_RIG_NORMALIZATION_V1_REPORT.md`
- `tools/blender/normalize_accurig_game_rig.py`
- `tools/normalize_fighter_rig.ps1`
- `scripts/debug/clean_rig_v1_lab.gd`
- `scripts/debug/terere_clean_rig_v1_lab.gd`
- `scripts/debug/jaguarete_clean_rig_v1_lab.gd`
- `scenes/debug/TerereCleanRigV1Lab.tscn`
- `scenes/debug/JaguareteCleanRigV1Lab.tscn`

## Files modified

None in production gameplay, V4, or source FBX.

---

## Recommended next step

1. Human playtest both clean-rig labs (mesh upright, bones inside, textures, overlay).
2. Only after approval: point the semantic solver at these GLBs and retarget Mixamo Idle — still off the battle path until that also passes.
