# Shopping del Sol Blender environment V2

**Verdict: SHOPPING_DEL_SOL_BLENDER_V2_READY_FOR_HUMAN_REVIEW**

**Recognition: SHOPPING_SDS_VISUAL_MATCH_HUMAN_REVIEW_REQUIRED**

Do not auto-declare MATCH.

## What changed vs V1

V1 was a readable parking lot made of procedural primitives (426 meshes, 0 textures in the Godot lab). V2:

- Hero facade: columns, window frames, parapet, recess, canopy depth, mullion grid, sign mount
- Entrance lighting empties + warm glow materials
- Interior threshold + first plaza (~28 m) so the door is not an instant greybox shock
- Parking stall/crosswalk/island upgrade
- Bollards + bins
- **Processed Hilux + VAZ** instanced in stalls (wreck GLB kept processed but skipped in-lot: 26 MB too heavy)
- Custom mid-poly palms (11 fronds, crown)

Measured export (Blender 5.2.1):

`objects=433 meshes=411 vertices=426616 triangles=287710 materials=70 textures=2 file_bytes=13331748`

Tris sit in the 100k–500k hero-exterior band. One 4K VAZ albedo remains; downsize if VRAM complains.

Source: `shopping_del_sol_zombies_environment_v2.blend`  
Export: `.../processed/shopping_del_sol_zombies_environment_v2.glb`

Lab: `scenes/debug/ShoppingBlenderEnvironmentV2Lab.tscn` (no zombies). Falls back to V1 GLB if V2 is missing.

Gameplay door remains **1500**. Collision stays Godot proxies. No trimesh. No Street View in Godot.

## Authority frames

`docs/generated/sds_v2_authority_frames.txt`

Beauty cameras: SDS_BEAUTY_SPAWN / ENTRANCE / PARKING / SIDE.

Renders: Godot D3D12 stills in `docs/generated/v9_visual_review/shopping/` (Blender EEVEE stills skipped — GPU crash). Authority contact sheets in `.../shopping/authority/`.

## Human question

Does this finally read as Shopping del Sol, not a generic mall parking lot?
