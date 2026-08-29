# Shopping del Sol Exterior — Model Report

**Asset root:** `res://assets/environments/shopping_del_sol/`  
**Engine target:** Godot 4.7  
**Generator:** Blender 2.83.1 (`bpy`, background)  
**Date:** 2026-08-26

## Primary Verdict

The exterior was generated (not AI-sculpted) from a parametric Blender Python script and is **recognizable as Shopping del Sol**: crescent terracotta wings, rhythmic square clerestory, twin end pavilions with tiled conical roofs, cream stepped portal, sun disc in the glass, patterned plaza axis, drop-off stripes, and parking shade canopies.

It is a **stylized-realistic game massing** (~70–80% silhouette identity, 20–30% simplification), not a survey model. Interior is not modeled. No unrelated game systems were touched.

Front comparison (`reports/comparisons/cam_front.png`) now reads the iconic portal (cream frame + glass + sun). Aerial/3Q views read the C-curve, pavilions, and parking bowl.

## References Used

Full per-image notes: `reports/REFERENCE_AUDIT.md`.

| Role | Files |
|------|--------|
| Portal identity | `Front_Ground_level.jpg`, `FrontAerial.webp` |
| Massing / curve / pavilions | all four aerials |
| Façade layering | `FrontAerial2.jpg` |
| Roof vault / clerestory evidence only | interiors (not modeled) |

**Renovation choice:** aerial terracotta + curve + pavilions for the complex; ground-photo cream arch + sun for the entrance. Tenant graphics and the left-side construction zone were excluded.

## Architectural Interpretation

```
SHOPPING_ROOT
  SDS_MainBuilding          set back behind the portal
  SDS_Wing_L/R_##           faceted arc segments
  SDS_Pavilion_L/R          cylindrical end rotundas
  SDS_RearVolume            simple rear continuation (LOW)
  SDS_EntranceFrame(+_R)    cream portal pillars
  SDS_EntranceHeader/Cap    stepped square top
  SDS_EntranceArchSeg_##    thin front arch trim
  SDS_EntranceGlass(+Arch)  dark glass + circular glass
  SDS_EntranceDoors         grade doors
  SDS_EntranceCanopy        metal canopy
  SDS_EntranceColumn_##     square cream colonnade (instanced)
  SDS_LobbyProxy            dark interior stand-in (no interior)
  SDS_FacadePanel_A_##      terracotta bays (shared mesh)
  SDS_FacadeWindow_A_##     square clerestory (shared)
  SDS_GlassBay_A_##         storefront glass (shared)
  SDS_CanopyModule_A_##     colonnade canopy (shared)
  SDS_GalleryModule_A_##    upper glass strip (shared)
  SDS_RoofPavilion_L/R      conical tile roofs
  SDS_RoofEntrance(+_B)     gabled tile over portal
  SDS_RoofCupola            glass cupola
  SDS_RoofSkylightSpine     simplified vault counterpart
  SDS_Sign_Main + rays      replaceable sun (not letter mesh)
  SDS_Sign_WordmarkPlane    decal plane for “SHOPPING del SOL”
  SDS_ParkingLot / walkway / drop-off / canopies
  COL_SDS_*                 box collision
```

## Approximate Dimensions

1 Blender unit = 1 meter. No survey; relative scale from doors (~2.4 m), retail storeys, parking bays (2.5×5 m), and cars (~4.5 m).

| Element | Meters | Confidence |
|---------|--------|------------|
| Arc radius | 180 | MEDIUM (gameplay-compressed vs a ~200 m+ real frontage) |
| Arc half-angle | 28° | MEDIUM |
| Chord width | ~169 | MEDIUM |
| Wing height | 13.0 (5.0 + 6.0 + 2.0) | MEDIUM |
| Portal | 24 W × 20 H × 8 D | MEDIUM |
| Inner glass / arch | ~17 W, sun r ≈ 2.55 | MEDIUM |
| Building depth | 42 | LOW |
| Pavilion diameter / wall / roof | 28 / 11.5 / 6.5 | MEDIUM |
| Parking bowl | 156 × 64 | MEDIUM |
| Colonnade canopy | 4.2 deep @ z=3.7 | MEDIUM |
| Square windows | 1.2, bay 5.6 | MEDIUM |
| Columns | 1.15 × 1.15 × 8.8 | MEDIUM |

Slight plan compression vs the real mall keeps Zombies traversal readable without turning the site into a generic arena.

## High Confidence Geometry

- Central cream portal on the parking axis
- Sun disc in the glass (separate sign object)
- Terracotta upper band + repeating square openings
- Ground-floor glass under a dark canopy (walkable colonnade)
- Gentle C-curve wrapping a parking bowl
- Twin end pavilions with terracotta conical roofs
- Patterned pedestrian axis + yellow drop-off
- Parking shade canopies as cover lanes

## Medium Confidence Geometry

- Exact storey split (5 / 6 / 2 m)
- Gable + cupola over the portal
- Upper gallery glass strip
- Skylight spine (from interiors, simplified)
- Column count/spacing at the portal
- Pavilion exact diameter and roof pitch
- Planter / pole placement (gameplay landmarks, not surveyed)

## Low Confidence / Inferred Geometry

- True rear façade (simple extruded `SDS_RearVolume`)
- True orthographic left/right walls
- Service yards / loading (not in photos — not invented)
- Roof HVAC (omitted)
- Interior (proxy wall only)
- Left termination (construction in one aerial — finished pavilion used)

## Mesh Statistics

From `reports/mesh_stats.json` (Blender 2.83.1):

| | Blockout | Final visual | Collision |
|--|----------|--------------|-----------|
| Triangles | **2368** | **5088** | 96 |
| Vertices | 1476 | 3316 | 64 |
| Objects | 174 | 386 | 8 |

- **Materials:** 16 reusable names (`MAT_WALL_LIGHT`, `MAT_WALL_DARK`, `MAT_CONCRETE`, `MAT_GLASS`, `MAT_METAL`, `MAT_ACCENT`, `MAT_SIGN_PLACEHOLDER`, `MAT_ROOF`, plus asphalt/pavers/foliage/interior proxy/collision)
- **Textures:** 8 solid 64×64 PNG placeholders in `textures/` (not baked photos)
- Final visual is **under** the 15–30k LOD0 band on purpose: silhouette and modules first. Room remains for a denser façade pass.

Object count is high because the plaza checker is many tiles (easy to merge later).

## Blender Source

`source/blender/shopping_del_sol_v01.blend` (~2.3 MB)

Collections: `SHOPPING_DEL_SOL` / `ARCHITECTURE` / `FACADE` / `ENTRANCE` / `ROOF` / `SIGNAGE` / `DETAILS` / `GROUND` / `COLLISION` / `REFERENCE_CAMERAS` / `REFERENCE_LIGHTS`

Cameras and preview lights live in the `.blend` only. They are **not** in the gameplay GLB.

## Blender Python Scripts

`scripts/blender/build_shopping_del_sol_blockout.py`

```
"C:\Program Files\Blender Foundation\Blender 2.83\blender.exe" --background --python build_shopping_del_sol_blockout.py
```

Rebuilds collections, blockout GLB, detail, collision, comparison PNGs, final GLB, blend, and `mesh_stats.json`.

## GLB Outputs

| File | Role |
|------|------|
| `models/blockout/shopping_del_sol_blockout.glb` | boxes/planes/cylinders only (~279 KB) |
| `models/final/shopping_del_sol_exterior_v01.glb` | visual + `COL_SDS_*` (~351 KB) |

Collision names: `COL_SDS_MainBuilding`, `COL_SDS_LeftWing`, `COL_SDS_RightWing`, `COL_SDS_Entrance` (+ pillar/header splits), `COL_SDS_Canopy` (overhead only — colonnade is walkable). Magenta `MAT_COLLISION`, hidden from renders.

## Godot Compatibility

- glTF 2.0 GLB, Y-up from the 2.83 exporter
- Metric, applied-safe node transforms on instanced modules (`export_apply=False` because of shared meshes)
- Named materials, simple UVs, no cameras/lights in the final GLB
- Collision is **not** the visual mesh
- `project.godot` has `import/blender/enabled=false` — import the **GLB**, not the `.blend`
- Object split supports later LOD0/1/2 without a full remodel

Zombies hooks present in the mesh, **not** implemented as gameplay:

- parking bowl = wave field
- canopy grid = cover / lanes
- colonnade = linear route
- arch alcove = choke / future interior door
- rear corners / canopy shade = spawn volumes
- storefront bays = barricade / interact sockets

## Known Limitations

- No rear/side elevations — those faces are simple
- Arch is faceted trim + circular glass, not concentric steel ribs
- Wordmark is a yellow plane (texture later)
- Sun rays are boxes, not a filigree logo
- Terracotta is a solid material, not brick photogrammetry
- Walkway is many tiles, not one atlas
- Triangle count is lean vs the 15–30k LOD0 guideline
- Tangent warnings on a few thin instances at export (harmless for this shading)
- Comparison cameras are authoring-only; lighting is EEVEE preview, not in-game

## Recommended Next Pass

1. Replace `SDS_Sign_WordmarkPlane` with a real SDS wordmark + sun decal
2. Merge plaza tiles; optional lightmap/UV2
3. Add LOD1 (drop windows/canopies) and LOD2 (masses only)
4. Author Godot `StaticBody3D` from `COL_SDS_*` (or `-col` suffixes if the importer pipeline wants them)
5. NavigationRegion3D on parking + colonnade + plaza; spawn volumes at rear/canopy shade
6. If a later era must be exclusive: either full aerial terracotta **or** full ground-photo brick colonnade — do not mix further
7. Optional: modest extra façade relief (window recesses, parapet caps) toward 15k tris if close-ups need it
8. Interior remains a separate task

## Files created / copied (nothing deleted)

- Created `assets/environments/shopping_del_sol/**` as specified
- **Copied** (never deleted) photos from `assets/environments/shopping del sol/references/` into the underscored tree, both at `references/exterior/` and into `front/`, `aerial/`, `left/`, `right/`, plus interiors
- Original spaced-path files remain on disk
- Empty: `references/exterior/rear/`, `details/`, `maps/` (no source images)

Unrelated fighters, Track cars, stages, and gameplay scripts were not modified.
