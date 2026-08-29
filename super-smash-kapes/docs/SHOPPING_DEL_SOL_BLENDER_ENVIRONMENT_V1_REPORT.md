# Shopping del Sol Blender environment V1

**Verdict: SHOPPING_BLENDER_ENVIRONMENT_V1_READY_FOR_HUMAN_REVIEW**

New visual authority. Existing Godot map is gameplay blockout / collision / nav only.

## Scope (V1)

Parking lot, main facade, main entrance, outdoor urban context, entrance threshold. **No full interior.** Open parking sky (no giant outdoor ceiling).

## Files

- `assets/environments/shopping_del_sol/blender/shopping_del_sol_zombies_environment_v1.blend`
- `.../blender/exports/shopping_del_sol_zombies_environment_v1.glb`
- processed copy for Godot load

Collections: `00_REFERENCE` … `08_MARKERS`, `EXPORT_GODOT`.

Named empties: `PLAYER_SPAWN_VISUAL`, `SHOPPING_MAIN_ENTRANCE`, `PARKING_CENTER`, `INTERIOR_THRESHOLD`, `ZOMBIE_APPROACH_*`, `LIGHT_PARKING_*`, `LIGHT_ENTRANCE_*`.

Export stats (Blender 5.2.1): **426 meshes, 4332 verts, 6960 tris, 747 KB**, AABB roughly parking-scale. Materials are a small shared library (asphalt, terracotta, cream, glass, vegetation, car paints). No 4K unique textures.

Street View / photos are **reference only**. Never imported into Godot runtime.

Original `shopping_del_sol_exterior_v01.glb` may be linked hidden in `00_REFERENCE` if import succeeds; it is not the runtime mesh.

**HUMAN_REVIEW_PENDING:** “Does this finally look like a believable Shopping del Sol exterior?”
