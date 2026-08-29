# GPU Resource Audit V1

## Question: do menu / character select / victory stay referenced during battle?

**Before this migration: yes.** `Main` preloaded menu, character select, and results scripts. Those scripts `preload()`ed menu backgrounds and all victory art. `FighterCatalog` also eager-loaded raw concept PNGs, victory textures, PackedScene visuals, and fallback scripts. `DefensoresDelChacoStage` preloaded nine stage textures including unused mosaics/crowd/tifo/FX.

**After this migration: no, with one caveat.** Menu, character select, and results are `load()`ed only when those screens are shown. Their textures are instance `load()`s, not class `preload()`s, so freeing the screen drops the node references. Godot may keep a ResourceCache of previously loaded scripts; first battle from boot does not instantiate results. Character-select background is not kept as an active node after `_enter_match` `queue_free()`s `screen_root`.

Caveat: after a finished match, visiting Results loads victory art until that screen is freed. Rematch then starts a new battle without keeping Results instantiated.

## Normal battle inventory (intended resident set)

| Bucket | Asset | Notes |
|---|---|---|
| Stage hero BG | `assets/stages/defensores_del_chaco/background/defensores_bg_main.png` | One `StadiumBackgroundQuad` only |
| Platforms | `assets/stages/defensores_del_chaco/platforms/defensores_platform_kit.png` | Three platform slices + two flag sprites from one atlas |
| Fighters | `terere_game_ready_v3.glb`, `jaguarete_game_ready_v3.glb` | One visual instance each |
| HUD | `hud_p1.png`, `hud_p2.png` | High-clarity lossless |
| Portraits | `terere_portrait.png`, `jaguarete_portrait.png` | Catalog + HUD; independent 2D art |
| Battle UI | HUD labels / intro text | No extra mosaics |

Not loaded in normal battle: crowd strips/loops, mosaics, tifo, scoreboard sheet, foreground overlay, confetti FX (lazy on KO), victory screens, menu BG/logo/panel, raw ChatGPT design PNGs, 3DAI v1/v2 GLBs, `jaguarete_game_ready_idle.glb`, ActorCore benchmark GLBs, procedural fallbacks.

## Texture classification

| Class | Policy | Examples |
|---|---|---|
| A Fighter | Quality priority; not degraded blindly | GLB embedded Diffuse/Normal 2048² |
| B Stage hero | Quality, **one** hero BG; VRAM compressed + mips | `defensores_bg_main.png` |
| C HUD/UI | High clarity; no huge mip chains | `hud_p1.png`, `hud_p2.png`, portraits, logo |
| D Event-only | Must not stay resident; VRAM compressed if imported | victory, mosaics, crowd, tifo, confetti, menu BG |

## Major textures (RGBA8 uncompressed estimate)

Formula: `width * height * 4`, plus ×1.333 if mipmaps generated.

Source table: `docs/generated/GPU_TEXTURE_INVENTORY.csv`

| Path | W×H | Format (source) | Mips | RGBA8 bytes | Class | Battle resident? |
|---|---|---|---|---|---|---|
| `defensores_bg_main.png` | 1672×941 | PNG → Godot compress/mode=2 | yes | 8,391,208 | B | YES (1) |
| `defensores_platform_kit.png` | 1672×941 | PNG → compress/mode=2 | yes | 8,391,208 | B | YES |
| `hud_p1.png` | 2172×724 | PNG lossless mode=0 | no | 6,290,112 | C | YES |
| `hud_p2.png` | 2172×724 | PNG lossless mode=0 | no | 6,290,112 | C | YES |
| `terere_portrait.png` | 442×512 | PNG lossless | no | 905,216 | C | YES |
| `jaguarete_portrait.png` | 512×512 | PNG lossless | no | 1,048,576 | C | YES |
| `main_menu_bg.png` | 1672×941 | compress/mode=2 | no | 6,293,408 | D | NO |
| `local_battle_panel.png` | 1448×1086 | compress/mode=2 | no | 6,290,112 | D | NO |
| `smash_kapes_logo.png` | 1448×1086 | lossless | no | 6,290,112 | C | NO (menu only) |
| `victory_bg_defensores.png` | 1672×941 | compress/mode=2 | no | 6,293,408 | D | NO |
| `terere_victory.png` | 1122×1402 | compress/mode=2 | no | 6,292,176 | D | NO |
| `jaguarete_victory.png` | 1122×1402 | compress/mode=2 | no | 6,292,176 | D | NO |
| `mosaic_variants.png` | 1672×941 | compress/mode=2 | no | 6,293,408 | D | NO |
| `crowd_strips.png` | 1672×941 | compress/mode=2 | no | 6,293,408 | D | NO |
| `crowd_loop_variants.png` | 2172×724 | compress/mode=2 | no | 6,290,112 | D | NO |
| `tifo_atlas.png` | 1672×941 | compress/mode=2 | no | 6,293,408 | D | NO |
| `scoreboard_sheet.png` | 1448×1086 | compress/mode=2 | no | 6,290,112 | D | NO |
| `foreground_overlay.png` | 2172×724 | compress/mode=2 | no | 6,290,112 | D | NO |
| `stadium_light_confetti_overlay.png` | 2172×724 | compress/mode=2 | no | 6,290,112 | D | KO only |
| 3DAI/v2 2048² sets | 2048×2048 × many | not production | no | 16,777,216 each | archival | NO |

VRAM compressed (BC7/BPTC) footprint is typically ~¼ of RGBA8 for opaque color, plus mip chain if enabled.

## Fighter GLB inventory (production V3)

| | Tereré | Jaguareté |
|---|---|---|
| Path | `assets/fighters/processed/terere/terere_game_ready_v3.glb` | `assets/fighters/processed/jaguarete/jaguarete_game_ready_v3.glb` |
| GLB size | 14,353,408 | 14,151,708 |
| Meshes / primitives | 1 / 1 | 1 / 1 |
| Materials | 1 | 1 |
| Textures | 2 (Diffuse 2048, Normal 2048) | 2 (same) |
| Skin joints | 101 | 101 |
| Animations | `idle` | `idle` |
| Godot triangles | 87,067 | 82,268 |
| Skeleton3D count | 1 | 1 |
| Idle skeletal rotation tracks | 21 | 21 |

RGBA8 estimate for the four 2048² maps: **64 MB** uncompressed. Runtime GLTFDocument path now BPTC/S3TC-compresses ImageTextures after generate (mipmaps generated first). PackedScene import (when the editor writes it) should already be VRAM-compressed.

## Currently loaded by screen

| Screen | Typical textures |
|---|---|
| Menu | menu BG, logo, local battle panel |
| Character select | menu BG + 2 portraits (catalog) |
| Battle | 1 hero BG, 1 platform kit, 2 HUD plates, 2 portraits, 2 ActorCore GLBs |
| Results | victory BG, stats panel, buttons, winner art |
| Pause | procedural / no extra hero textures |

## 0x8007000e

`0x8007000e` is Windows `E_OUTOFMEMORY`. Project uses `rendering_device/driver.windows="d3d12"`. Follow-on `texture_create failed` / `framebuffer null` / `draw_list inactive` is D3D12 failing allocations after VRAM/resource exhaustion.

Primary pressure sources found:

1. Lossless `compress/mode=0` on 1448–2172 px generated art
2. Main preloading Results (all victory art) for the whole session
3. Stage preloading unused crowd/mosaic/tifo/FX atlases
4. Catalog loading raw design PNGs + extra fighter PackedScenes/fallbacks
5. Possible simultaneous 3DAI + v2 + baked idle + ActorCore texture sets
6. Two ~87k-triangle skinned meshes with 2048 albedo+normal

Mitigations: (1) VRAM compress class B/D, (2) lazy screen scripts, (3) unused stage textures not preloaded, (4) catalog portraits + ActorCore only, (5) one production GLB per fighter, (6) BPTC compress on GLTFDocument textures, (7) hit-flash `duplicate(false)` so albedo/normal stay shared.

Headless `RENDER_VIDEO_MEM_USED` is 0. Desktop confirmation is BLOCKER-020.

## Material / texture duplication

Hit flash uses `material.duplicate(false)` — material instances are per fighter, **texture resources stay shared**.

HUD portraits still build one cached processed `ImageTexture` via `KapesPortrait` (white-background crop). That is one extra RGBA copy per portrait, not per frame.

No per-respawn `Image.get_image` on fighter materials.

## Rematch

See `docs/generated/REMATCH_RESOURCE_STABILITY.csv`. Ten playground instantiate/free cycles: nodes 100, objects 1738–1739, resources 47. No monotonic growth. Video/texture monitors 0 in headless.
