# Blender asset usage and provenance V2

**Verdict: JEFFREY_BLENDER_ASSET_FIRST_V2_PARTIAL**

V8 treated Blender as a primitive factory. V9 inventories `assets/raw_models/` and processes usable sources into `assets/environments/shared/urban/processed/`.

Raw files are never loaded at Godot runtime (`.gdignore`).

## RAW ASSET | DECISION | WHY | PROCESSED OUTPUT | USED WHERE

| RAW ASSET | DECISION | WHY | PROCESSED OUTPUT | USED WHERE |
|---|---|---|---|---|
| `vaz_2104_-_raw_scan.glb` | USE_BOTH | Real wagon scan, Paraguay-adjacent | `urban/processed/vehicles/vaz_parked.glb` (~22k tris, albedo kept) | SDS parking + Track roadside |
| `toyota-hilux-revo-prerunner-2021.zip` | USE_BOTH | Hilux/pickup is locally appropriate | `urban/processed/vehicles/hilux_parked.glb` if FBX import succeeds | SDS + Track |
| `wrecked-car.zip` / `export_002.glb` | USE_SHOPPING | Atmosphere, not a full lot | `urban/processed/vehicles/wreck_parked.glb` | SDS, **one** slot |
| `psx_industrial_pack.glb` | USE_BOTH | Already in SDS processed | copy under urban/processed/industrial | Track industrial + SDS service |
| `cement_bags_low-poly.glb` | USE_BOTH | Service clutter | `urban/processed/industrial/cement_bags.glb` | SDS/Track props |
| `market-al-danube.zip` | USE_BOTH / REFERENCE_ONLY | Children inspected in Blender; extract lamps/cars/trees if named | `street_props/market_extracted_cluster.glb` or documented skip | SDS/Track if extract hits |
| `ice_scream_3_shopping_center_map.glb` | REJECT | Unrelated branded map | — | — |
| `portal-gate-sci-fi.zip` | REJECT | Sci-fi, not SDS/Track urban | — | — |
| Palm/tree/lamp in raw | none found | Library has no vegetation/lamp meshes | Custom mid-poly in `urban_kit_v2` | Track + SDS |
| Pistol / zombie meshes in raw | none found | No character/weapon GLB | Blender foundation GLBs (not canonical gameplay yet) | review only |

Machine manifests: `docs/generated/asset_usage_v9/`.

## KPI (target vs this sprint)

For SDS exterior **visible non-architectural props** (cars, lamps, palms, bollards, bins):

- REAL_PROCESSED_ASSET_INSTANCES: parked cars from VAZ/Hilux/wreck when GLBs exist
- BLENDER_CUSTOM_MODELED_ASSET_INSTANCES: palms, lamps, bollards, facade (purpose-built, not one-off cubes-as-hero)
- PLACEHOLDER_PRIMITIVE_INSTANCES: stall lines, curbs, massing, fallback cars if import fails

Target ≥70% real-or-purpose-built: **PARTIAL until human counts instances in the V2 lab**. Agent does not auto-declare MATCH.

## One-off primitives still allowed

Hidden blockout, collision proxies, distant tower massing, measurement empties.
