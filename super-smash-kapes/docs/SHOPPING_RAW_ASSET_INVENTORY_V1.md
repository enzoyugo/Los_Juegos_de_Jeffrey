# Shopping raw asset inventory V1

Source directory: `assets/raw_models/` (RAW SOURCE AUTHORITY — not edited destructively).  
Extracted archives: `assets/raw_models/_extracted/<asset_id>/` (Godot-ignored).  
Processed runtime copies: `assets/environments/shopping_del_sol/processed/`.

No license/readme/provenance files were present in the downloads. License fields below are **unknown** (not fabricated).

Shopping del Sol exterior already in-tree (`assets/environments/shopping_del_sol/models/final/shopping_del_sol_exterior_v01.glb`, ~351 KB, 5088 tris) is the visual shell candidate.

| Asset | Source | Type | Size | Meshes | Mats | Textures | AABB / dims | Orientation / scale | Anims | Collision | Visual | Runtime | Memory | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cement_bags_low-poly | `assets/raw_models/cement_bags_low-poly.glb` | glb | 13.7 MB | 1 | 1 | 3 | ~2.0 × 2.0 × 2.0 m | Sketchfab Y-up, human scale | 0 | box proxy OK | construction clutter | texture-heavy for 1 mesh | HIGH | **REFERENCE_ONLY** |
| ice_scream_3_shopping_center_map | `assets/raw_models/ice_scream_3_shopping_center_map.glb` | glb | 19.7 MB | 2821 | 26 | 1 | ~47 × 74 × 30 m | Ice Scream 3 mall, not SDS | 0 | unusable as gameplay | unrelated IP / style | 5811 nodes | HIGH | **REJECT** |
| market-al-danube | `assets/raw_models/market-al-danube.zip` | zip → FBX + jpg/png | 59.7 MB | n/a (FBX) | n/a | 22 | unknown until FBX | commercial lot + mall frontage | 0 | n/a | parking/curb/lamp/signage **reference** | Blender import disabled; includes `H&M-Logo.svg.png` | HIGH if imported whole | **USED_REFERENCE** |
| portal-gate-sci-fi | `assets/raw_models/portal-gate-sci-fi.zip` | zip → FBX + PBR | 94.9 MB | n/a | n/a | 22 | unknown | sci-fi gate | 0 | n/a | wrong visual language | huge textures | HIGH | **REJECTED** |
| psx_industrial_pack | `assets/raw_models/psx_industrial_pack.glb` → processed copy | glb | 1.36 MB | 44 | 2 | 2 | pack ~12.7 × 10.5 × 3.7 m | named Barrel/Crate/Dumpster/Cargo | 0 | box proxy per instance | PSX-leaning but small | selective instance | LOW | **USED_RUNTIME** `assets/environments/shopping_del_sol/processed/psx_industrial_pack.glb` |
| vaz_2104_-_raw_scan | `assets/raw_models/vaz_2104_-_raw_scan.glb` | glb | 24.9 MB | 6 | 1 | 1 | ~34.7 × 15.1 × 12.1 m | raw scan, ~7–8× too large | 0 | not car-shaped cleanly | sedan silhouette reference | 25 MB + huge bounds | HIGH | **USED_REFERENCE** |
| wrecked-car | `assets/raw_models/wrecked-car.zip` → `_extracted/wrecked-car/source/export_002.glb` | glb + 60 png | 62.7 MB zip / 37.7 MB glb | 139 | 23 | 69 | ~471 × 10 × 90 m (scattered BeamNG parts) | Pessima wreck, not a single prop | 0 | triangle disaster | wrecked-cover **reference** | 244 nodes + many maps | HIGH | **REJECTED** |
| toyota-hilux-revo-prerunner-2021 | `assets/raw_models/toyota-hilux-revo-prerunner-2021.zip` | zip → FBX + many PNG | 64.4 MB | n/a | n/a | 30+ | unknown | full interior Hilux, FBX | 0 | n/a | pickup silhouette **reference** | Godot Blender import disabled; interior AO maps | HIGH | **USED_REFERENCE** (not runtime) |

## market-al-danube analysis (V4)

Extracted to `_extracted/market-al-danube/`:

- `source/Market AL_DANUBE.fbx` (57.5 MB)
- textures including asphalt/grass/cobble **and trademark tenant art (`H&M-Logo.svg.png`)**

Godot `import/blender/enabled=false`. FBX is not a runtime source. Individual props were **not** extracted this sprint (no Blender GLB export pipeline that stays inside memory budget without pulling H&M art).

Layout ideas taken (not cloned): parking lanes parallel to a commercial frontage, curb islands, lamp grid, painted stalls, crosswalk at entrance.

**Not copied:** whole scene, tenant logos, raw asphalt JPG.

## Selected parking assets (V4 final)

| Decision | Asset | Runtime path |
|---|---|---|
| **USED_RUNTIME** | psx industrial crate/barrel/dumpster/container | `assets/environments/shopping_del_sol/processed/psx_industrial_pack.glb` |
| **LOADED_HIDDEN** | Shopping exterior GLB (markers / `shell_loaded`; **visual off**) | `assets/environments/shopping_del_sol/models/final/shopping_del_sol_exterior_v01.glb` |
| **USED_RUNTIME / PROCESSED** | sedan / SUV / pickup kit, palms, double-arm lamps, skyline | `scripts/zombies/zombies_visual_kit.gd` (shared materials/meshes; no extra GLB) |
| **USED_REFERENCE** | market-al-danube, vaz scan, hilux FBX, Street View + photos | `assets/reference/shopping del sol/` + `assets/raw_models/` |
| **REJECTED** | Ice Scream map, sci-fi portal, BeamNG wreck GLB | not instanced |

Hilux was inspected (FBX + interior/decal textures). It is a full vehicle interior scan, not a parking prop. Runtime import would fight the D3D12 budget. Pickup silhouette was rebuilt in the shared kit instead.

## Asset processing

- Archives extracted only under `assets/raw_models/_extracted/`.
- `assets/raw_models/.gdignore` prevents Godot importing raw packs.
- `assets/reference/.gdignore` prevents Godot importing 260 Street View PNGs (~517 MB) — that import set was a D3D12 risk.
- Runtime copy: `assets/environments/shopping_del_sol/processed/psx_industrial_pack.glb`.
- Gameplay never depends on `_extracted/` or zip internals.
