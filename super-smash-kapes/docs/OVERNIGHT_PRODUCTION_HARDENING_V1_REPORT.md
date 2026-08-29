# Overnight Production Hardening V1 Report

Date: 2026-08-22  
Project: Super Smash Kapes (`super-smash-kapes`)  
Godot: 4.7.2  
Blender: 2.83.1  

## Primary verdict

**SSK_ACTORCORE_RIG_REPAIRED_ANIMATION_LIBRARY_PARTIAL**

Meshes no longer fail the idle volume gate (~10× explosion is gone). Production is ActorCore V4 with clip-relative bake, rebound per-character textures, and a shared clip library. The library is partial: no run, no victory, and idle is T-pose + Mixamo intra-clip sway rather than Mixamo standing. Human visual approval is still required.

## Executive summary

Human playtest rejected V3 because both fighters exploded. Forensics placed the first break at Mixamo→ActorCore retarget (stage C), not at Godot import. Mixamo Idle frame 1 is a 50–100° T-pose→stand pose; AccuRIG rest axes differ ~90°. Copying that delta onto AccuRIG inflates skinned volume ~10×.

V4 copies **clip-relative deltas versus Mixamo frame 1** onto the AccuRIG bind pose. Idle volume_ratio is 1.06 (Tereré) and 1.01 (Jaguareté). A second bug was real: V3 GLBs embedded Jaguareté PNG bytes in **both** fighters because AccuRIG names every map `model_Pbr_Diffuse.png`. Export now rebinds each character’s `.fbm` files by path.

Gameplay freeze held: no retune of movement, attacks, hitboxes, stocks, or camera.

## Baseline

See `docs/generated/OVERNIGHT_BASELINE_V1.json`. Tests at start: 90. Tests at end: **103**. Production at start: exploded V3 GLBs. Canonical sizes unchanged: Tereré SHORT 2.40, Jaguareté TALL 3.15.

## Catastrophic deformation root cause

Mixamo rest is T-pose. Mixamo Idle frame 1 already holds standing (hips ~50°, arms ~60–80°). AccuRIG `CC_Base_*` rest quats differ ~60–93° from Mixamo (hip ~92°). `apply_rest_relative_rotation` correctly implements change-of-basis of Mixamo `matrix_basis` into AccuRIG local axes (`expected_vs_applied_angle_deg` = 0). That formula still explodes the skin because the source “delta” is T→stand, not idle sway.

Constraint Copy Rotation brute force never got volume_ratio below 2.29.

## First broken pipeline stage

| Stage | Tereré | Jaguareté |
| --- | --- | --- |
| A source FBX rest | HEALTHY | HEALTHY |
| B source pose | HEALTHY | HEALTHY |
| **C retarget bake** | **BROKEN** (vol ~10×) | **BROKEN** (vol 9.68×) |
| E/F V3 GLB | BROKEN (inherits C) | BROKEN |
| G/H Godot/runtime | BROKEN (plays C) | BROKEN |
| V4 clip-relative idle | HEALTHY technical | HEALTHY technical |

`FIRST_BROKEN_STAGE_TERERE = C_target_rig_after_retarget`  
`FIRST_BROKEN_STAGE_JAGUARETE = C_after_retarget_one_frame`

The original bbox classifier used `max(axis)` as height/width and a 2.4× gate, so 10× volume was labelled HEALTHY. Volume is now the gate.

## Tereré rig / skin

101 bones, 0 unweighted verts, max 6 influences, 15% verts >4 influences (clamped to 4 on the game copy). Suspicious influence samples: 0. Source FBX armature RotX 90°, scale 0.01. Rest AABB coherent.

## Jaguareté rig / skin

101 bones, 0 unweighted, max 6 influences, 22.8% verts >4 influences (clamped to 4). Same AccuRIG hierarchy. First broken stage matches Tereré (shared retarget).

## Rest pose / bind pose

Source rest vs default pose is HEALTHY. Explosion is not “posed mesh + rest skeleton.” Armature non-unit scale 0.01 is present at healthy rest and is not the 10× failure. Bind preservation beat blind `apply transforms`.

## Retarget mathematics

Documented in `docs/generated/ACTORCORE_RETARGET_MATH_AUDIT.md`.

Production V4:

```
delta = Q_mixamo_frame1.inverted() @ Q_mixamo_frame
AccuRIG.rotation_quaternion = delta
Hip Y: (src.y - y_frame1) * 0.001
```

Honest limitation: AccuRIG stays on bind/T-pose. Idle reads as breathing T-pose, not Mixamo standing.

## Clean export pipeline

`tools/blender/export_actorcore_game_ready.py` and `export_actorcore_animation_library.py`.

- Clip-relative bake  
- Influence clamp to 4  
- Strip Mixamo / cameras  
- Rebind `.fbm` textures by character  
- NLA tracks so Blender 2.83 glTF emits every clip (active action only was exporting idle)  
- Bbox gate idle ≤ 1.35 volume  

Outputs:

- `assets/fighters/processed/terere/terere_game_ready_v4.glb`  
- `assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb`  
- Idle-only backups `*_v4_idle_only.glb`  
- V3 kept on disk  

## Blender roundtrip

V3 reimport matched exploded idle (volume ~10×). V4 idle bbox passes in Blender before export. GLB now contains idle, jump, air_attack, attack_neutral, attack_heavy, hit_light, hit_heavy, ko, plus leftover AccuRIG `T-Pose` (ignored at runtime).

## Godot skeletal import

Headless `GLTFDocument` (PackedScene import still missing — BLOCKER-019).

| | Bones | Idle tracks | Clips |
| --- | --- | --- | --- |
| Tereré | 101 | 21 skeletal | idle, jump, attacks, hits, ko |
| Jaguareté | 101 | 21 skeletal | same |

`runtime_retarget=false`, `proxy_idle=false`, `fallback=false` in rematch lifecycle logs. Godot `Mesh.get_aabb()` is rest mesh, not skinned; deformation authority remains Blender evaluated mesh.

## Material / texture isolation

V3: both GLBs contained Jaguareté PNG SHA256 `654179021409871a` / `d21a232eda6d9a1a`. That is the human “Jaguareté on Tereré” bug.

V4 after `rebind_actorcore_textures`: Tereré matches `autorig_actor.fbm` `29aedd817e4fbf69` / `e07a78960e4e29af`; Jaguareté matches its own maps. Filenames remain `model_Pbr_*` (AccuRIG convention). Runtime `_isolate_fighter_textures` duplicates maps per fighter so hit flash cannot mutate the other character.

Hit flash still sets emission on `duplicate(false)` materials; it does not reassign albedo.

## Idle status

`ACTORCORE_IDLE_TECHNICALLY_CERTIFIED=true` in `docs/generated/ACTORCORE_IDLE_CERTIFICATION_V4.json`.

Human visual approval: **false**. Expect T-pose silhouette with small sway.

Labs: `TerereProductionAnimationLab.tscn`, `JaguareteProductionAnimationLab.tscn` (1 REST, 2 IDLE, 3 skeleton, 4 material, 5 bbox).

## Shared animation library

| Semantic | Source | Both characters | Notes |
| --- | --- | --- | --- |
| idle | Idle.fbx | yes | loop; vol ~1.06 / 1.01 |
| jump | Unarmed Jump.fbx | yes | Jaguareté vol 5.0, axis 1.76 — watch in playtest |
| air_attack | Jump Attack.fbx | yes | |
| attack_neutral | Mutant Punch.fbx | yes | playback ~2.2–2.35× to match 0.46s attack |
| attack_heavy | Standing Melee Attack Downward.fbx | yes | Jaguareté vol 6.09, axis 1.79 — watch |
| hit_light | Reaction.fbx | yes | |
| hit_heavy | Rib Hit.fbx | yes | |
| ko | Falling Back Death.fbx | yes | |
| run | — | **no** | BLOCKER-022 |
| victory | — | **no** | BLOCKER-023 |

Root X/Z not keyed (hip Y clip-relative only).

## Animation state integration

`ActorCoreFighterVisual` maps IDLE/RUN/AIR/ATTACK/HITSTUN/KO/VICTORY to semantic clips. Missing run/victory fall back to stop-keep-pose or idle. Short blends. Presentation-only speed scales (Tereré snappier, Jaguareté slightly slower). Gameplay frames unchanged.

## Character-specific animation polish

Playback speed dictionaries only. Accessories not re-skinned; if bombilla/tail explode in a clip, screenshot and treat as BLOCKER. No gameplay stat changes.

## HUD polish

Normalized sockets: portrait, **name**, damage, stock. P1 outer-left / P2 outer-right. Damage `%d%%` (no leading zeros), punch scale uses centered pivot. Cards slightly larger (`HUD_WIDTH_RATIO` 0.29, height 0.162).

## Victory screen V6

Left hero ~46% × 63% viewport. Right: GANADOR / name / ¡VICTORIA! / two mini-cards (KOs, CAÍDAS, DAÑO, GOLPES) / REVANCHA, CAMBIAR KAPES (procedural), MENÚ. No mega empty panel.

## Defensores stage

Unchanged V3 composition. KO uses brief confetti overlay; final KO uses a stronger pulse. Mosaics still deferred.

## GPU / memory audit

Headless rematch VRAM monitors report 0. Desktop `0x8007000e` remains BLOCKER-020. Architecture still: lazy menu/select/results, one production GLB per fighter, BPTC compress on runtime GLTF textures, unused stage atlases not preloaded.

Fighter GLB disk: Tereré V4 ~15.2 MB, Jaguareté V4 ~16.5 MB. ~87k / ~82k triangles. 101 bones. 2 embedded PNGs each (~4–5 MB).

## Rematch stress test

20 cycles in `docs/generated/OVERNIGHT_REMATCH_STABILITY.csv`. Nodes 100, objects 1745–1746, resources 47. No monotonic growth.

## Future fighter automation

`docs/FUTURE_FIGHTER_AUTOMATION_PIPELINE.md`  
`tools/blender/validate_future_rig.py` (AUTO_ACCEPT / MANUAL_REVIEW / REJECT)  
`tools/build_fighter.ps1` (no automatic catalog overwrite without `-Promote`, and even then catalog is not auto-edited)

## Automated tests

**104 passed** (`pytest tests -q`): existing suite plus `tests/test_overnight_hardening.py`.

## Godot validation

`--import --headless` completed (Blender path warning in editor importer only).  
`validate_actorcore_production.gd` = PASS.  
No parser errors in the isolated validators run here.

## Human validation required

Exact screenshot list is in the chat response. Labs and `SSK_FIGHTER_PIPELINE_AUDIT=1` / F3 / F4 help.

## Active blockers

021 Mixamo standing idle cannot be copied without explosion (T-pose idle is the safe bake)  
022 No run FBX  
023 No victory FBX  
019 Headless PackedScene import  
020 Desktop D3D12 0x8007000e not reproducible here  
001 Headless screenshots  

## Resolved this overnight

Exploded V3 idle root-caused and gated. V4 idle volume sane. Cross-character texture bytes separated. NLA multi-clip export. HUD name sockets. Victory mini-cards. 20-cycle rematch flat.

## Files created / modified

See git status in the chat response. No commit, no push.

## Recommended next milestone

Human playtest V4 idle/jump/attack. If T-pose idle is rejected, the next engineering job is a true rest-axis Mixamo→AccuRIG solver that still passes the volume gate — not more clips on the old rest-relative path.
