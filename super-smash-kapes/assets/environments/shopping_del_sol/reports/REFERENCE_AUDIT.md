# Shopping del Sol — Reference Audit

**Location:** Shopping del Sol, Asunción, Paraguay  
**Asset:** exterior only, Zombies-mode playable map  
**Audit date:** 2026-08-26  
**Source folder inspected first:** `assets/environments/shopping del sol/references/` (spaces in path, original files **not deleted**)  
**Working copies:** `assets/environments/shopping_del_sol/references/`

## Version / renovation choice

The supplied photographs do **not** all describe the same renovation finish.

| Set | Character | Decision |
|-----|-----------|----------|
| Aerials (`FrontAerial.webp`, `FrontAerial2.jpg`, `FrontLeftAerial.jpg`, `FrontRightAerial.jpg`) | Long gently curved two-storey body, terracotta upper wall, rhythmic square clerestory windows, circular end pavilions with tiled roofs, large parking bowl, shade canopies | **Primary massing source** — internally consistent, reads as the current/large-complex identity |
| Ground (`Front_Ground_level.jpg`) | Iconic cream arched portal, sun logo, brick/cream colonnade, tenant storefronts, yellow drop-off stripes | **Primary entrance-identity source** — this is the recognizable “Shopping del Sol” face |
| Interiors | Barrel-vault skylight spine, star atrium roof, upper square windows | **Roof silhouette only** — not used to invent exterior ornament |

**Choice (not a silent mix):**
- Overall footprint, curve, terracotta wing rhythm, pavilions, parking, and roof masses follow the **aerial set**.
- The central portal (stepped cream arch, glass, sun disc, flanking square columns) follows the **ground photo + twilight aerial**.
- Tenant graphics (Victoria’s Secret, Gucci, Havanna, peace-sign mural) are **not modeled** — they are time-specific and conflict with later aerials.
- The **construction zone** visible on the far left of `FrontLeftAerial.jpg` is **not modeled** (temporary).
- Ground-level brick immediately beside the arch is treated as a **local entrance material**, not as the full-length wing material. Wings use terracotta panels as in the aerials.

If a later pass must pick one era only: prefer this hybrid (current massing + iconic portal). Combining the ground photo’s entire classical brick envelope with the aerial terracotta curve would be an incompatible façade mash-up.

---

## Exterior photographs

### Front_Ground_level.jpg

- **Working copies:** `references/exterior/Front_Ground_level.jpg`, `references/exterior/front/Front_Ground_level.jpg`
- **Approximate viewpoint:** Ground, on axis with the main portal, wide lens, ~1.6–2.0 m eye height, ~25–40 m back
- **Category:** front / detail (entrance)
- **Architectural information visible:**
  - Monumental cream/beige stepped arch frame with a smaller arched niche at the top
  - Semi-circular glass curtain with dark grid (verticals + concentric arcs)
  - Glowing yellow/gold sun logo centered in the glass
  - Rectangular sliding-door band at grade
  - Square cream columns (two visible per side) supporting a flat entablature
  - Red brick wall behind the colonnade (this photo)
  - Mid-level planter ledges with shrubs
  - Ground-floor storefronts; right: Victoria’s Secret (tenant, ignored)
  - Yellow diagonal-striped drop-off crossing immediately in front of the doors
- **Perspective distortion:** Strong wide-angle; verticals reasonably upright; depth compressed at the wings
- **Trust for proportions:** **MEDIUM** for the portal (arch vs wing height, column spacing). **LOW** for overall mall width (lens + crop).
- **Unique features:** Sun-in-arch logo; stepped cream portal; square colonnade; drop-off stripes
- **Conflicts:** Brick + classical colonnade vs continuous terracotta aerial wings; tenants vs later aerials; drop-off asphalt vs aerial patterned plaza (both can coexist: porte-cochère then plaza)
- **Confidence:** **HIGH** for portal identity; **MEDIUM** for column rhythm; **LOW** for wing length

### FrontAerial.webp

- **Working copies:** `references/exterior/FrontAerial.webp`, `references/exterior/aerial/FrontAerial.webp`
- **Approximate viewpoint:** High front aerial, dusk/twilight, looking down at the entrance and parking
- **Category:** aerial / front
- **Architectural information visible:**
  - Long horizontal mass, roughly symmetrical about the portal
  - Central arched glass entry with yellow circular logo
  - Gabled / vaulted tiled roof over the portal with a small glass cupola at the peak
  - Two circular pavilions with tiered conical terracotta-tile roofs and warm eave lighting
  - Tan/terracotta body; upper row of small square lit openings
  - Ground-floor glass under dark awnings; outdoor seating
  - Flat roofs between pavilions with mechanical clutter (do not model in detail)
  - Huge parking lot; central pedestrian walkway with light/dark geometric pavers
  - Palm rows; warm street lamps; Asunción skyline beyond
- **Perspective distortion:** Aerial foreshortening; usable for plan and silhouette
- **Trust for proportions:** **HIGH** for silhouette (three tiled roof masses + central arch). **MEDIUM** for absolute meters (no survey scale).
- **Unique features:** Twin conical pavilion roofs; cupola; sun disc; patterned cross-walkway
- **Conflicts:** Stronger “circular pavilion” reading than the more faceted domes in the left/right aerials — treated as the same end rotundas, simplified to conical/faceted low-poly roofs
- **Confidence:** **HIGH** for overall composition

### FrontAerial2.jpg

- **Working copies:** `references/exterior/FrontAerial2.jpg`, `references/exterior/aerial/FrontAerial2.jpg`
- **Approximate viewpoint:** High front aerial, dusk, slightly closer than `FrontAerial.webp`
- **Category:** aerial / front
- **Architectural information visible:**
  - Cream/stone arch with full-height glass
  - “SHOPPING del SOL” lettering above the doors (use a replaceable sign plane, not modeled letters)
  - Star-like fixture in the upper arch (secondary to the sun disc; do not stack both — **sun disc wins** as the more unique SDS mark)
  - Terracotta mid-band with recessed square windows
  - Upper gallery glowing cool white/blue (set-back glass strip)
  - Storefronts + dark canopies
  - Patterned pedestrian mall; parking; palms; streetlights
  - Circular / faceted roof elements toward the right end
- **Perspective distortion:** Aerial; moderate
- **Trust for proportions:** **HIGH** for vertical layering (storefront / terracotta / gallery). **MEDIUM** for width.
- **Unique features:** Three-band façade; wordmark location; patterned walkway
- **Conflicts:** Star vs sun in the arch — **prefer sun disc** (`FrontAerial.webp` + ground photo). Wordmark kept as a separate decal plane.
- **Confidence:** **HIGH** for façade layering

### FrontLeftAerial.jpg

- **Working copies:** `references/exterior/FrontLeftAerial.jpg`, `references/exterior/aerial/FrontLeftAerial.jpg`, `references/exterior/left/FrontLeftAerial.jpg`
- **Approximate viewpoint:** High 3/4 left, daylight, looking along the curve and parking
- **Category:** aerial / left (not a true orthographic left elevation)
- **Architectural information visible:**
  - Gentle crescent / C-shape wrapping a surface parking lot
  - Continuous terracotta upper wall + square window rhythm
  - Ground glass under dark canopies
  - Beige rectangular portal breaking the terracotta curve; large dark arched opening
  - Multiple faceted/octagonal tiled domes along the roof
  - Cylindrical drum mass left of the portal
  - Long parking shade canopies in parallel rows
  - **Left side under construction** (steel, red earth) — **excluded**
  - Palms and perimeter trees; city backdrop
- **Perspective distortion:** Strong aerial 3/4; good for curve and parking layout, weak for true left-façade design
- **Trust for proportions:** **HIGH** for plan curve and parking-canopy rhythm. **LOW** for the left end wall (construction).
- **Unique features:** C-curve; shade canopies; beige portal vs terracotta body
- **Conflicts:** Construction vs finished left pavilion in other aerials — **finished pavilion used**
- **Confidence:** **HIGH** for plan; **MEDIUM** for roof drums; **LOW** for left termination

### FrontRightAerial.jpg

- **Working copies:** `references/exterior/FrontRightAerial.jpg`, `references/exterior/aerial/FrontRightAerial.jpg`, `references/exterior/right/FrontRightAerial.jpg`
- **Approximate viewpoint:** High 3/4 right, golden hour
- **Category:** aerial / right (not a true right elevation)
- **Architectural information visible:**
  - Same curved two-storey body
  - Terracotta + square recesses; cream trim near portal and left rotunda
  - Central white-framed arched glass
  - Several terracotta domes / rounded roof sections; long pale skylight strips
  - HVAC on rear roof (simplify away)
  - Parking grid, small trees, perimeter vegetation
  - Small kiosk / guard-like structure at a parking access (optional, low priority)
- **Perspective distortion:** Aerial 3/4
- **Trust for proportions:** **HIGH** for right-hand massing and parking. **LOW** for true right/rear elevations.
- **Unique features:** Skylight spine; right-end rotunda
- **Conflicts:** Dome count/shape varies slightly vs other aerials — **two end pavilions + one entrance tiled roof** (do not invent extra domes)
- **Confidence:** **HIGH** for right massing; **MEDIUM** for skylight strips

### Rear / maps / orthophotos

- **No rear, no true left/right elevations, no site survey, no maps.**
- Rear and far sides are **inferred** as simple extruded continuations of visible masses.
- Folders `references/exterior/rear/`, `details/`, `maps/` are empty on purpose.

---

## Interior photographs (exterior implications only)

Interior is **not modeled**. These shots only inform roof masses that would be seen from aerial cameras.

### Interior_Dome.jpg

- **Viewpoint:** Interior upper walkway toward a circular atrium
- **Category:** interior (roof/atrium evidence)
- **Visible for exterior:** Star-shaped radial ceiling; barrel-vault glass corridor; ring of small square clerestory windows
- **Perspective distortion:** Wide interior lens
- **Trust for exterior:** **MEDIUM** for “there is a central raised roof / skylight hub”; **LOW** for exterior ornament
- **Conflicts:** Star ceiling vs exterior sun disc — different objects (interior ceiling vs façade logo)
- **Confidence:** **MEDIUM** (skylight hub + square clerestory)

### Interior_Hallway.jpg

- **Viewpoint:** Upper corridor, vaulted skylight, CH Carolina Herrera storefront
- **Category:** interior
- **Visible for exterior:** Long arched skylight vault; people for scale (~5–6 m corridor)
- **Trust for exterior:** **MEDIUM** for a longitudinal roof vault/spine
- **Confidence:** **MEDIUM**

### Interior2ndfloor.jpeg

- **Viewpoint:** Atrium, stacked balconies, barrel-vault glass roof, stylized palm columns
- **Category:** interior
- **Visible for exterior:** Tall vaulted glass roof; at least three interior levels (exterior remains ~2 storeys + tall portal)
- **Trust for exterior:** **MEDIUM** for vault height; **LOW** for exterior language (palm columns are interior)
- **Confidence:** **MEDIUM** for roof height only

---

## Scale notes used for modeling

No surveyed drawings. Relative scale from:

| Cue | Assumed size | Use |
|-----|----------------|-----|
| Commercial door | 2.2–2.4 m | Ground floor ~5.0 m |
| Retail storey | ~5 m | Wing height stack |
| Cars / parking bays | 4.5 m / 2.5×5.0 m | Parking lot and canopy spacing |
| People in interiors | ~1.7 m | Vault is large; not extruded to 3+ exterior storeys |
| Square clerestory | ~1.1–1.3 m | Window module |

See `SHOPPING_DEL_SOL_MODEL_REPORT.md` for the numeric table actually built.

---

## Gameplay reading (from references, not a logic implementation)

- **Open wave field:** front parking bowl (cars would be cover later; not part of this building mesh).
- **Cover lanes:** parking shade canopies; colonnade under storefront canopies; square portal columns; planters.
- **Choke:** main arch / shallow lobby alcove (opening left for future interior; dark proxy wall, no interior).
- **Flank routes:** curved sidewalk along both wings; side parking aisles.
- **Landmarks:** sun-arch portal, twin pavilion roofs, patterned walkway axis.
- **Hidden spawn pockets (volumes later):** rear corners, canopy shadows, planter niches, parking-entry kiosk zone — geometry kept simple so volumes can be placed without fighting ornate walls.
- **Barricade / interactable hooks:** storefront bays, door plane, canopy posts.

---

## Images not trusted for proportions

- Any ground-level width reading of the full mall (wide lens).
- Left termination in `FrontLeftAerial.jpg` (construction).
- Exact dome tessellation / HVAC layouts.
- Interior palm columns and store décor.
- Tenant signage.

## Missing coverage (do not invent)

- True rear façade
- True orthographic left/right
- Service yards / loading docks (may exist; **not shown**)
- Roof plant beyond “flat + skylight strip”
- Night lighting fixtures in catalog detail
