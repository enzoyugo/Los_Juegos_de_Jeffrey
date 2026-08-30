# Jeffrey Asset Fidelity and Scale Correction V1

Reference layout: 1920x1080. Raster masters are never stretched. Runtime `TextureRect` art uses `STRETCH_KEEP_ASPECT_CENTERED`; stage `Sprite3D` art uses a single `pixel_size` per authored family.

## Native-size audit

| Asset family | Native master(s) | Runtime display / region | Uniform scale | Aspect error |
| --- | --- | --- | ---: | ---: |
| Track position, timer, fuel, speed | 1448x1086 | 360x270 / timer 400x300 | 0.249 / 0.276 | 0.00% |
| Track pause panel | 1448x1086 | 768x576 | 0.530 | 0.00% |
| Track pause title | 2172x724 | 596x199 | 0.274 | 0.35% |
| Track pause button sprite | 1024x1536, 4 authored 1024x384 regions | 320x120 per region | 0.313 | 0.00% |
| Copa background | 788x472 | 1800x1080 centered inside 1920x1080 | 1.370 | 0.00% |
| Copa title | 654x222 | 654x222 | 1.000 | 0.00% |
| Copa Jeffrey logo | 350x248 | 210x149 | 0.600 | 0.04% |
| Copa logo | 338x274 | 218x177 | 0.645 | 0.19% |
| Copa player row | 580x106 | 580x106 | 1.000 | 0.00% |
| Copa points gained | 273x107 | 273x107 | 1.000 | 0.00% |
| Copa total points | 484x106 | 484x106 | 1.000 | 0.00% |
| Copa action buttons | 457/465x104/105 | 278x64, centered texture | ~0.606 | <0.50% |
| Zombies points / round | 2172x724 | 420x140 | 0.193 | 0.00% |
| Zombies health / weapon | 2172x724 | 520x173 | 0.239 | <0.20% |
| Smash HUD P1/P2 | 2172x724 | 3:1 card; height ratio corrected to 0.172 | uniform | 0.00% |
| El Cuarto background | 1672x941 | Sprite3D pixel_size 0.055 | uniform | 0.00% |
| El Cuarto platforms | 1448x1086 | Sprite3D pixel_size 0.018 | uniform | 0.00% |
| El Cuarto props (audited) | 1254x1254 / 1448x1086 | not currently runtime-wired; no scale claim | N/A | N/A |
| Colegio background | 1672x941 | Sprite3D pixel_size 0.055 | uniform | 0.00% |
| Colegio platforms | 1448x1086 | Sprite3D pixel_size 0.018 | uniform | 0.00% |

Display sizes are authored control sizes or, for the Copa background, the actual centered content rectangle. The four-button pause PNG is intentionally cropped by atlas region because the source is a sprite sheet; no source artwork is resized non-uniformly.

## Corrections

- Track HUD masters now retain their 4:3 ratio and use larger couch-readable artboards.
- Track pause uses a large centered 4:3 panel and the actual pause-button sprite regions.
- Copa results are a full-screen layered presentation rather than a compressed modal card.
- Zombies HUD masters now retain their 3:1 ratio at larger display sizes.
- Smash HUD card height matches the 2172:724 master ratio.
- El Cuarto and Colegio authored stage sprites remain source-ratio Sprite3D artwork.
