# Semantic V2 Battle Candidate Integration V1

## Primary Verdict

**SSK_SEMANTIC_V2_BATTLE_CANDIDATE_READY_FOR_HUMAN_PLAYTEST**

Hand chain is keyed. Blender semantic V2 metrics pass. Godot isolated lab passes. Default battle is still production V4. Opt-in `SSK_USE_SEMANTIC_V2_CANDIDATE=1` loads the semantic V2 GLBs through dedicated candidate scripts. Runtime hip–head samples show both production V4 and the candidate standing on Y after the candidate-only Z-up import pitch.

## Human Screenshot Failure

The screenshot where fighters look rotated / flattened / lying sideways is **not** the Blender semantic V2 preview.

Proven runtime facts:

1. Default spawn still loads **production V4** (`terere_game_ready_v4.glb` / `jaguarete_game_ready_v4.glb`) via `FighterCatalog` → `FighterDefinition.create_visual()` → `*_actorcore_visual.gd`.
2. Semantic V2 GLBs are **Blender Z-up**. Direct Godot lab load (no battle wrapper) has hip→head on **Z**.
3. Production V4 is **Y-up**. Its historical fix is **yaw -90° on ModelRoot**, which keeps V4 upright and facing gameplay +X.
4. Applying that **same yaw-only** wrapper to semantic V2 maps height Z onto **X**. Hip→head becomes X-dominant: the character lies on its side. That is exactly the “sideways fighter” look.
5. Bind-pose mesh AABBs stay pancake-thin on Y even when the **skeleton** is upright. Mesh `get_aabb()` is not skinned. Upright proof is hip/head bone world positions, not raw mesh AABB.

After the candidate-only import pitch (`Rx -90°` + `Ry -90°`), candidate hip→head is Y-dominant:

| Fighter | Hip Y | Head Y | Dominant | Class |
|---|---|---|---|---|
| Tereré candidate | 1.61 | 2.78 | Y | UPRIGHT |
| Jaguareté candidate | 1.84 | 3.17 | Y | UPRIGHT |
| Tereré V4 | ~0.91 | ~1.58 | Y | UPRIGHT |
| Jaguareté V4 | ~1.44 | ~2.47 | Y | UPRIGHT |

## Actual Battle Asset Authority Before Fix

Traced, not inferred. Spawn path:

`Fighter._setup_visual` → `FighterDefinition.create_visual()` → catalog `visual_script` → `ActorCoreFighterVisual._ready` → `GlbFighterVisual` GLB load.

Default (env off):

```json
{
  "terere": {
    "pipeline": "ACTORCORE_V4",
    "glb": "res://assets/fighters/processed/terere/terere_game_ready_v4.glb",
    "visual_script": "res://fighters/terere/terere_actorcore_visual.gd",
    "animation": "idle",
    "experimental_semantic_v2": false
  },
  "jaguarete": {
    "pipeline": "ACTORCORE_V4",
    "glb": "res://assets/fighters/processed/jaguarete/jaguarete_game_ready_v4.glb",
    "visual_script": "res://fighters/jaguarete/jaguarete_actorcore_visual.gd",
    "animation": "idle",
    "experimental_semantic_v2": false
  }
}
```

Catalog is **not** swapped. Full dump: `docs/generated/BATTLE_FIGHTER_VISUAL_AUTHORITY.json`.

Opt-in audit `SSK_FIGHTER_VISUAL_AUDIT=1` prints `[FIGHTER_VISUAL]` once per spawn (pipeline, asset, bones, animation, root rotations, fallback).

## Blender vs Battle Discrepancy

| Surface | Asset | Up axis | Wrapper |
|---|---|---|---|
| Blender preview | semantic V2 `.blend` / GLB | Z-up (Blender) | none |
| Godot semantic lab | semantic V2 GLB | Z-up in Godot world | none (looks “standing” in a Z-up sense, not gameplay Y-up) |
| Default battle | production V4 GLB | Y-up | ModelRoot yaw -90° |
| Candidate battle | semantic V2 GLB | converted to Y-up | ModelRoot pitch -90° **and** yaw -90°; FacingRoot yaw 0/180 |

They were never the same visual authority. Battle was V4 Mixamo-retargeted idle. Blender was semantic V2 standing/idle.

## Hand Chain Root Cause

Arm lowering worked because clavicle / upperarm / forearm were keyed on `canonical_standing`. Hands were still rest quaternions (`0,0,0,1`). Fingers and twist helpers were correctly **not** driven.

Keying order bug class (same family as the earlier arm bug): pose must be applied **after** the action exists, then the full chain including `CC_Base_*_Hand` must be keyed. An empty action must not snap back to rest before hand keys.

## Hand Chain Fix

Solver keys `CC_Base_L_Hand` and `CC_Base_R_Hand` with primary / secondary / palm degrees. Twist helpers and fingers stay unkeyed.

Bake evidence (`docs/generated/SEMANTIC_V2_HAND_CHAIN_AUDIT.json`):

- Tereré standing hand angle **18.60°** vs rest **0°**
- Jaguareté L **22.12°** / R **20.87°** vs rest **0°**
- `standing_hand_differs_from_rest: true`
- Idle stays near standing (quat dot > 0.90)

## Transform Stack Audit

Dumps:

- `docs/generated/TERERE_BATTLE_TRANSFORM_STACK.json`
- `docs/generated/JAGUARETE_BATTLE_TRANSFORM_STACK.json`

Battle tree (identity except as noted):

`Fighter.VisualRoot` → visual → `VisualMotionRoot` → `PresentationScaleRoot` → `FacingRoot` (Y 0 or 180) → `ModelRoot` (import pitch/yaw) → `ImportedModel` / Armature / `Skeleton3D` / mesh.

IDLE→AIR→IDLE snaps motion roots to identity (`snap_motion_roots_neutral`).

## Orientation / Facing Authority

One facing authority: **FacingRoot** yaw only (0 or π).

Import orientation lives on **ModelRoot** only:

- V4: pitch 0, yaw -90°
- Semantic V2 candidate: pitch -90° (Z-up → Y-up), yaw -90° (face +X)

No scale.x flip. No second yaw on ModelRoot for facing. Production V4 pitch stays 0.

## Proxy Motion Audit

When skeletal idle binds, `_idle_uses_skeletal()` is true. Whole-body idle bob / lean / breath rotation is skipped. Motion roots stay neutral on IDLE.

## Candidate Integration

Env: `SSK_USE_SEMANTIC_V2_CANDIDATE=1` in `FighterDefinition.create_visual()` only. Catalog unchanged.

| | Path |
|---|---|
| Tereré GLB | `res://assets/fighters/processed/semantic_solver_v2/terere/terere_idle_semantic_v2.glb` |
| Jaguareté GLB | `res://assets/fighters/processed/semantic_solver_v2/jaguarete/jaguarete_idle_semantic_v2.glb` |
| Scripts | `fighters/*/ *semantic_v2_battle_candidate.gd` |
| Scenes | `scenes/debug/TerereSemanticV2BattleCandidate.tscn`, `JaguareteSemanticV2BattleCandidate.tscn` |
| Heights | 2.40 / 3.15 |

## Pose Parity

`docs/generated/TERERE_POSE_PARITY.json`  
`docs/generated/JAGUARETE_POSE_PARITY.json`

Compares Blender arm/hand audit quats, Godot direct GLB samples, production idle, candidate rest/standing/idle. Battle wrapper does not retarget bones; it only changes root import/facing.

## Tereré Metrics

- Pose class: STANDING_IDLE
- Volume ratio: 0.658 max (limit 1.35)
- Extreme verts: 0
- Limb length error: 0
- Arms lowered; hands standing ≠ rest
- Candidate hip–head Y-up; target height 2.40

## Jaguareté Metrics

- Pose class: STANDING_IDLE
- Volume ratio: 0.972 max (limit 1.35)
- Extreme verts: 0
- Limb length error: 0
- Hands standing ≠ rest
- Candidate head Y ≈ 3.17 vs target 3.15

## Texture Isolation

Unchanged. Tereré `.fbm` maps vs Jaguareté `.fbm` maps. Runtime duplicates materials per fighter id. V4 SHA256 unchanged. Existing texture-authority tests still pass.

## Performance / VRAM

Catalog does not preload V2+V3+V4+static+procedural GLBs. Candidate env instantiates candidate scripts only; V4 GLB is not loaded on that path. Fallback remains lazy.

## Automated Tests

142 passed.

Coverage includes: production default V4, env switch not in catalog, candidate paths/sizes, hand standing ≠ rest, FacingRoot-only facing, candidate Z-up pitch, authority JSON, pose-parity structure, V4 SHA, material isolation tests already in suite.

## Exact Human Playtest Command

```powershell
$env:SSK_USE_SEMANTIC_V2_CANDIDATE="1"
$env:SSK_FIGHTER_VISUAL_AUDIT="1"

& "E:\Godot_v4.7.2-stable_win64_console.exe" --path "E:\SuperSmashKapes\super-smash-kapes"
```

Default (no env): production V4, unchanged.

Expected: both upright, different textures, Tereré shorter, Jaguareté taller, arms down, hands attached, skeletal idle, no sideways body, both facings, feet grounded.

## Production Safety

- Catalog still `ACTORCORE_V4` + `*_game_ready_v4.glb`
- V4 binaries not overwritten
- Candidate is env-gated
- No commit / no push

## Active Blockers

None for this playtest gate.

Notes (not blockers): bind-pose mesh AABB dumps remain pancake-shaped; ignore them. Tereré candidate head sits a bit above 2.40 because height fit uses skeleton span + IGNORE_TOP. Next clip work (jump/attack/hit) is out of scope.

## Files Created

- `fighters/terere/terere_semantic_v2_battle_candidate.gd`
- `fighters/jaguarete/jaguarete_semantic_v2_battle_candidate.gd`
- `scenes/debug/TerereSemanticV2BattleCandidate.tscn`
- `scenes/debug/JaguareteSemanticV2BattleCandidate.tscn`
- `scenes/debug/AuditBattleVisualAuthority.tscn`
- `scripts/debug/audit_battle_visual_authority.gd`
- `docs/generated/BATTLE_FIGHTER_VISUAL_AUTHORITY.json`
- `docs/generated/TERERE_BATTLE_TRANSFORM_STACK.json`
- `docs/generated/JAGUARETE_BATTLE_TRANSFORM_STACK.json`
- `docs/generated/TERERE_POSE_PARITY.json`
- `docs/generated/JAGUARETE_POSE_PARITY.json`
- `docs/SEMANTIC_V2_BATTLE_CANDIDATE_INTEGRATION_V1_REPORT.md`

## Files Modified

- `tools/blender/semantic_idle_solver_v2.py` (hand chain)
- `scripts/fighters/glb_fighter_visual.gd` (FacingRoot, transform dump, import pitch, skeleton height for pitched assets)
- `scripts/fighters/glb_fighter_config.gd` (`model_pitch_offset`)
- `scripts/fighters/actorcore_fighter_visual.gd` (idle snap, visual audit)
- `scripts/fighters/fighter_definition.gd` (env switch)
- `tests/test_semantic_idle_solver_v2.py`
- `tests/test_semantic_v2_battle_candidate.py`
- Semantic V2 experimental GLBs (hand rebake; not V4)

## Recommended Next Step

Human playtest with the env vars above. If upright idle is accepted, bake jump / attack / hit clips onto the **same** semantic V2 candidate pipeline without touching V4.
