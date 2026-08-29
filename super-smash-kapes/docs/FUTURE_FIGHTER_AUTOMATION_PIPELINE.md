# Future Fighter Automation Pipeline

Super Smash Kapes onboarding for a new Kape should be a **gated pipeline**, not a paid-API dependency and not an automatic overwrite of production.

## Desired flow

```
TURNAROUND IMAGES
        ↓
   3D MODEL (local or artist)
        ↓
   AUTO RIG ATTEMPT (AccuRIG / local auto-rigger)
        ↓
   RIG VALIDATION  →  tools/blender/validate_future_rig.py
        ↓
   IF AUTO_ACCEPT → generic ActorCore bake
   IF MANUAL_REVIEW → AccuRIG / bone-map repair
   IF REJECT → stop, do not bake
        ↓
   CANONICAL ACTORCORE-COMPATIBLE SKELETON (101 CC_Base_* if possible)
        ↓
   BATCH ANIMATION BAKE  (clip-relative Mixamo → ActorCore)
        ↓
   BBOX / VOLUME GATE  (idle volume_ratio ≤ 1.35)
        ↓
   GODOT IMPORT + LABS
        ↓
   TESTS
```

## Authorities

- Gameplay stats stay frozen. Only presentation/rig/animation assets change.
- Canonical sizes stay per character (`size_class` + `target_visual_height`). Do not normalize heights.
- Original AccuRIG FBX is never mutated. Game copies live under `assets/fighters/processed/<id>/`.
- Production overwrite requires an explicit `-Promote` flag.

## Validator verdicts

`tools/blender/validate_future_rig.py` emits:

| Verdict | Meaning |
| --- | --- |
| AUTO_ACCEPT | Humanoid + skin + rest bbox look safe to bake |
| MANUAL_REVIEW | Usable mesh/skin but not canonical ActorCore names, or >4 influences, or weight-sum drift |
| REJECT | No armature/skin, unweighted mesh, degenerate bbox, negative scale |

Current production fighters (Tereré / Jaguareté AccuRIG) are the calibration set: 101 bones, 0 unweighted, ~15% verts with >4 influences (MANUAL_REVIEW for influence clamp, not REJECT).

## One-command proposal

```
.\tools\build_fighter.ps1 -Character "jaguarete"
```

Steps the script is allowed to run today:

1. Inspect source FBX path
2. Run the offline rig validator
3. If not REJECT, bake clip-relative animation library
4. Export `*_game_ready_vN.glb` next to existing versions (never silent overwrite of last human-accepted file)
5. Godot `--import --headless` + isolated validators
6. Pytest

Promotion to catalog (`fighter_catalog.gd`) is **not** automatic.

## What this repo will not do automatically

- Call paid meshing/rigging APIs unless credentials already exist in the environment
- Mute bbox failures and ship exploded meshes
- Map a random attack clip to `run`
- Change movement, hitboxes, or stocks

## Clip-relative bake (current math authority)

AccuRIG rest axes differ ~60–93° from Mixamo. Copying Mixamo T-pose→stand (50–100°) explodes the skin (~10× volume). Production bake copies **intra-clip deltas versus Mixamo frame 1** onto the AccuRIG bind pose. Idle therefore reads as T-pose + breathing until a true rest-axis retarget is solved. That limitation is documented, not hidden.
