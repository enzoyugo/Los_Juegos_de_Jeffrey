# Fighter Reference Breakdown

Authoritative source: `res://assets/fighters/raw_design/` (user-provided, do not move or overwrite).

Reference hierarchy: raw design → established SSK identity → gameplay readability → technical feasibility → interpretation.

---

## TERERÉ

### Source Images

- `res://assets/fighters/raw_design/terere/ChatGPT Image 22 ago 2026, 04_19_46 (1).png` — primary front hero pose (canonical)
- `res://assets/fighters/raw_design/terere/ChatGPT Image 22 ago 2026, 04_19_46 (2).png` — alternate front
- `res://assets/fighters/raw_design/terere/ChatGPT Image 22 ago 2026, 04_19_47 (3).png` — expression/angle variant
- `res://assets/fighters/raw_design/terere/ChatGPT Image 22 ago 2026, 04_19_47 (4).png` — expression/angle variant
- `res://assets/fighters/raw_design/terere/ChatGPT Image 22 ago 2026, 04_19_47 (5).png` — expression/angle variant

### Canonical Silhouette

Anthropomorphic wooden guampa (mate cup) torso with muscular orange-tan limbs, yerba-filled rim, diagonal silver bombilla, and a red/white/blue poncho fringe. Wide grounded stance; cup body dominates vertical mass.

### Canonical Proportions

- Cup body ≈ 55–60% of total height
- Limbs thick and heroic; legs shorter than arms but powerful
- Face sits on upper cup front, not above the vessel
- Bombilla exits yerba at ~45° toward character's left (viewer right)

### Face

Large white oval eyes, black pupils, thick angled black brows (determined/aggressive), wide grin with white upper teeth and pink tongue. Expression is confident and battle-ready.

### Body

Polished light-to-medium brown wood grain guampa. Yerba mate fills the top as coarse green texture. Torso is the cup itself — not a separate cylinder costume.

### Limbs

Orange-tan skin, smooth and muscular. Three-toed broad feet in navy flip-flops. Right arm often forward (finger-gun / strike gesture in reference); left fist on hip in hero pose.

### Accessories

- Silver metallic bombilla with curved neck and flat mouthpiece
- Woven poncho/sash: red, white, blue horizontal stripes with diamond fringe
- Navy flip-flops with dark sole

### Materials / Colors

| Element | Color |
|---------|-------|
| Wood cup | `#9a5a2d` / `#6f3f1f` |
| Yerba | `#4f8f3d` |
| Skin/limbs | `#e7a05a` |
| Bombilla | `#c8d2dc` metallic |
| Poncho red/white/blue | `#d93b35` / `#f5f0df` / `#2875b9` |
| Sandals | `#1b2f66` navy |

### Personality

Cocky, energetic, Paraguayan pride. "Frío, firme y picante." Confident grin, finger-gun gesture, wide stance.

### Required Recognizable Features

1. Wooden guampa body (not generic mug/cylinder)
2. Face on cup front
3. Green yerba rim
4. Diagonal silver bombilla
5. Red/white/blue poncho
6. Orange-tan muscular limbs
7. Navy flip-flops

### Ambiguous / Missing Views

No dedicated rear view in references. Rear interpretation: wood cup back, poncho drape continued, bombilla still exits from cup top at fixed anatomical side.

### Safe 3D Interpretation Decisions

- Added modest depth to 2D cup face without bloating side profile
- Bombilla remains fixed on character's right side (does not mirror with facing)
- Poncho simplified to readable box/stripe mesh; fringe implied by color blocks
- Procedural limb motion; no skeleton

### Things That Must NOT Be Changed

- Cup-as-torso identity
- Yerba + bombilla signature
- Paraguayan tricolor poncho
- Orange-tan limb palette
- Confident face language

---

## JAGUARETÉ

### Source Images

- `res://assets/fighters/raw_design/jaguarete/ChatGPT Image 22 ago 2026, 04_19_47 (6).png` — primary front hero pose (canonical)
- `res://assets/fighters/raw_design/jaguarete/ChatGPT Image 22 ago 2026, 04_19_47 (7).png` — alternate front
- `res://assets/fighters/raw_design/jaguarete/ChatGPT Image 22 ago 2026, 04_19_48 (8).png` — angle variant
- `res://assets/fighters/raw_design/jaguarete/ChatGPT Image 22 ago 2026, 04_19_48 (9).png` — angle variant
- `res://assets/fighters/raw_design/jaguarete/ChatGPT Image 22 ago 2026, 04_19_48 (10).png` — angle variant

### Canonical Silhouette

Bipedal anthropomorphic jaguar: large head with ears and spiky hair tuft, muscular golden torso, oversized paws/claws, long spotted tail curving upward. Diagonal chest sash and waist belt with flag-colored buckle.

### Canonical Proportions

- Head ≈ 30% of height; prominent muzzle
- Torso compact and muscular
- Arms thick ending in large paws
- Tail long, ~40% height, key silhouette anchor

### Face

Amber eyes, black nose, whiskers, cream muzzle, wide grin with fangs and red tongue. Spiky black hair tuft between ears. Expression: heroic, aggressive confidence.

### Body

Golden-orange fur (`#d89a2d`) with black rosette spots. Cream belly and inner muzzle. Athletic build, broad shoulders.

### Limbs

Large paws with cream claws. Legs powerful, slightly bent fighting stance. Wristbands with tricolor geometric pattern.

### Accessories

- Diagonal chest sash (red/white/blue geometric weave)
- Waist belt with circular Paraguay-flag buckle
- Matching wristbands
- Belt fringe on left hip

### Materials / Colors

| Element | Color |
|---------|-------|
| Fur base | `#d89a2d` |
| Spots | `#1b1b1b` rosettes |
| Cream muzzle/belly | `#f5e8c8` |
| Claws | `#efe2c8` |
| Sash/belt | `#d93b35` / `#f5f0df` / `#2875b9` |

### Personality

"Garra, salto y bandera." Heroic fighter energy, wide grin, raised strike paw.

### Required Recognizable Features

1. Jaguar species (rosettes, not tiger stripes)
2. Golden fur + black spots
3. Cream muzzle with fangs
4. Spiky hair tuft
5. Long spotted tail
6. Paraguayan sash/belt/wristbands
7. Large clawed paws

### Ambiguous / Missing Views

No rear reference. Rear: continued spot pattern, tail centerline, sash crosses back diagonally.

### Safe 3D Interpretation Decisions

- Spots as limited mesh spheres (14 on torso) for performance — not hundreds of meshes
- Tail built as 3 segments with sinusoidal idle motion
- Bipedal upright preserved for fighter gameplay readability
- Facing mirrors body; sash buckle remains centered

### Things That Must NOT Be Changed

- Jaguar rosette identity (not generic cat/tiger)
- Golden/cream palette
- Tail as silhouette feature
- Paraguayan accessory set
- Heroic grin + fangs expression
