# Shopping del Sol — reference coverage and visual authority V1

Source root: `assets/reference/shopping del sol/`

Godot must **not** import this tree. `assets/reference/.gdignore` contains `*`.
The files remain on disk as human/AI visual authority. They are not runtime textures.

## Directory structure

```
assets/reference/shopping del sol/
  photos/references/     JPG / WebP stills
  streetview/
    EXTERIOR/            30 stations (named)
    INTERIOR/            13 stations
    _CALIBRATION/        rotation_360
```

Each Street View station typically has:

- `angle_000.png` … `angle_300.png` (6 yaw steps)
- `contact_sheet.jpg`

## Counts

| Set | Count |
|---|---|
| Exterior Street View stations | **30** |
| Interior Street View stations | **13** |
| Street View PNG frames | **260** (~517 MB) |
| Photo stills (jpg/jpeg/webp, excluding .import) | **32** |
| Contact sheets | **43** |

Sample Street View frame: **1920×900** PNG (~1.5–1.9 MB).

## Classification (authority frames)

| Class | Best stations / stills | Use |
|---|---|---|
| A MAIN_FACADE | EXTERIOR_016–022 OUTSIDE_FRONT, EXTERIOR_033 sphere, photos `unnamed.webp` night plaza | terracotta/beige mass, horizontal signage, glass |
| B MAIN_ENTRANCE | EXTERIOR_007/008 ENTRADA_PARKING, EXTERIOR_034 NIGHT angle_000, photo looking through glass sunburst | arched glass atrium, circular sun disc, brightest night landmark |
| C PARKING_CENTER | EXTERIOR_001–006 ESTACIONAMIENTO_MEDIO | two-lane aisle, dashed line, stalls both sides |
| D PARKING_LEFT | EXTERIOR_009–011, angle_240/300 of 001 | outer rows, islands, Coca-Cola pole (not copied as brand) |
| E PARKING_RIGHT | EXTERIOR_012–014, 001 angle_060/120 | SUVs, pickup in foreground, towers behind trees |
| F PARKING_ISLANDS | 001 contact sheet all angles | curbed grass strips, palms + leafy trees, not a forest |
| G LIGHT_POLES | 001 angle_000, 034 night | tall grey poles, **double-arm / Y head**, warm sodium at night |
| H VEHICLE_SCALE | 001 close pickup/SUV, 034 parked SUV at doors | mostly white/silver SUV + sedan + pickup; lot is busy not full-grid |
| I STREET_ACCESS | EXTERIOR_040/041 FRONT_STREET, 016 Av. Aviadores | multi-lane avenue, bus shelters, motorcycles at curb |
| J SIDE_FACADE | EXTERIOR_023–025 OUTSIDE_SIDE | long low commercial frontage |
| K SKYLINE | 001 angle_180, unnamed.webp, 016 060/120 | Byspania-like white towers, blue-strip tower, Sudameris red vertical, ibis |
| L INTERIOR_MAIN_HALL | INTERIOR_032/035–038 HALL, photos wooden vault | pointed timber vault, skylight — **not this sprint's rebuild** |
| M INTERIOR_CORRIDORS | INTERIOR_027–031 | two-level glass rail, stone floor |
| N INTERIOR_STORE_FRONTS | INTERIOR_026, 028–031 | glass shopfronts — keep existing TERERÉ / CHIPÁ gameplay names |
| O CINEMA / SPECIAL | INTERIOR_043 CINE, 042 INTERIOR_PARKING | out of exterior scope |
| P NIGHT_LIGHTING | EXTERIOR_034, unnamed.webp | warm lamps, glowing entrance, dark-blue sky not black void |

## Reconstruction plan (concise)

1. **Stop generic pad.** Combat nav stays ~48×34 m. Visual asphalt, cars, islands, street edge extend beyond.
2. **Center aisle** toward the doors, dashed line, stalls left/right, **not** a single yellow racing stripe.
3. **Green islands + palms** on a regular rhythm along the aisle and outer rows.
4. **Double-arm lamps** on that same grid; strong warm pools.
5. **Cars:** SUV / sedan / pickup silhouettes, mixed whites/silvers/darks, ~24 instances, aisle kept clear.
6. **Entrance landmark:** glass, cream arch, gold sun disc, SHOPPING del SOL, canopy, tan plaza tiles + crosswalk.
7. **Facade:** code-built terracotta wings + thin Shopping GLB slab (depth crushed so it does not swallow the plaza). Height ~mall, not a 6 m house.
8. **Skyline cheap boxes** with window emission; ibis / Byspania-like labels as location cues, no tenant trademarks from asset packs.
9. **Night operating mall:** ambient 0.78, exposure 1.18, sky `#1a2740`. Black-crush forbidden.
10. **Interior gameplay authority unchanged** (plaza, GALERÍA 1000, wall-buy, rounds).

## What the references are not

- Not a license to import 517 MB of PNG into VRAM.
- Not millimeter BIM.
- Not a copy of Forever 21 / Sprite / Coca-Cola / H&M art.
