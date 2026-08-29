# ActorCore Production Migration V1 Report

## Primary Verdict

**SSK_ACTORCORE_PRODUCTION_MIGRATION_V1_READY_FOR_HUMAN_PLAYTEST**

`0x8007000e` is **not claimed fully resolved** on the desktop GPU. Cause is identified and mitigations are in production (verdict path **B**). Headless cannot measure D3D12 VRAM. Human playtest must confirm the Output log no longer shows `CreateResource failed with error 0x8007000e`.

## Executive Summary

ActorCore V3 is now the only production visual pipeline for Tereré and Jaguareté. Normal battle instantiates one imported/runtime-loaded game-ready GLB per fighter, plays baked skeletal `idle`, and does not runtime-retarget. Old 3DAI/v2/baked-idle paths remain on disk but are not catalog-loaded. Menu, character select, and victory are no longer preloaded for the whole session. Unused Defensores mosaics/crowd/tifo/FX are not preloaded. Automated tests: **90 passed**. Headless auto-select battle printed `pipeline=ACTORCORE_V3` for both fighters (101 bones, idle, `proxy_idle=false`, `fallback=false`, sizes 2.40 / 3.15). Gameplay systems were not modified.

## Previous Production Pipeline

| Fighter | Old authority | Idle |
|---|---|---|
| Tereré | `terere_glb_visual.gd` → `terere_glb_1.glb` | VisualMotionRoot bob/breath/lean proxy |
| Jaguareté | `jaguarete_rigged_visual.gd` → `jaguarete_game_ready_idle.glb` or **static v2** | Baked idle if GLB present; else `[JAG_RIG] Baked GLB missing — showing static v2 mesh without idle` |

Catalog also eager-loaded PackedScene wrappers, fallback scripts, raw design PNGs, and victory textures. That is the pipeline the human log observed.

## ActorCore Promotion

Production hierarchy:

```
Fighter CharacterBody3D
  └── VisualRoot
       └── ActorCoreFighterVisual
            ├── VisualMotionRoot
            │    └── PresentationScaleRoot
            │         └── ModelRoot
            │              └── ImportedModel (game-ready V3 GLB)
            └── BlobShadow
```

One `character_visual` child. Catalog `pipeline_id = ACTORCORE_V3`. Benchmark folder is research-only.

## Tereré Production Model

- `assets/fighters/processed/terere/terere_game_ready_v3.glb` (14.4 MB)
- Copied from validated ActorCore idle benchmark (mesh + skin + 101-bone CC_Base skeleton + `idle`)
- No Mixamo armature nodes; root X/Z policy already baked
- Config: `terere_actorcore_visual.gd`, target height **2.40**, IGNORE_TOP 0.18
- Godot: 1 Skeleton3D, 101 bones, AnimationPlayer clip `idle`, 67 tracks / 21 skeletal rotation bones, 87,067 triangles

## Jaguareté Production Model

- `assets/fighters/processed/jaguarete/jaguarete_game_ready_v3.glb` (14.2 MB)
- Same skeleton contract as Tereré
- Config: `jaguarete_actorcore_visual.gd`, target height **3.15**, BODY_FRACTION 0.95
- Godot: 1 Skeleton3D, 101 bones, `idle`, 87 tracks / 21 skeletal rotation bones, 82,268 triangles

## Idle Playback

When fighter visual state is `IDLE` (grounded, `|vx| ≤ 0.5`, not attack/hit/KO): `play_animation("idle")` loops the baked clip.

While skeletal idle is bound, VisualMotionRoot idle bob, breath scale, and tilt are forced to identity. No whole-model Y sine.

Missing clips (`run`, `jump`, `attack_neutral`, `hit_light`, `ko`, `victory`) stop the player and keep restrained root-level proxy motion. API already exists for the next shared library milestone. Do not fake missing skeletal clips.

## Visual Instance Audit

`fighter.gd` adds exactly one `character_visual`. Pipeline audit prints `visual_instances=1`. Stage attaches one `StadiumBackgroundQuad` (guard if already present). No duplicate hero BG node.

## Old Pipeline Retirement

Removed from **runtime loading** (files kept on disk):

- `terere_glb_visual.gd` / `TerereGLBVisual.tscn` / `terere_glb_1.glb`
- `jaguarete_rigged_visual.gd` / `JaguareteRiggedVisual.tscn` / `jaguarete_game_ready_idle.glb` / v2 GLB
- Catalog PackedScene + fallback Script preloads
- Raw `assets/fighters/raw_design/**` references

Fallback chain is lazy: ActorCore GLB → `load(fallback_visual_path)` emergency visual → capsule. Failures emit `[FIGHTER_PIPELINE][ERROR] ActorCore production asset failed.` The old `[JAG_RIG] Baked GLB missing` line is gone from production scripts and did not appear in the healthy headless battle log.

## Runtime Resource Inventory

See `docs/GPU_RESOURCE_AUDIT_V1.md`. Battle should hold 1 hero BG, 1 platform atlas, 2 fighter GLBs, 2 HUD plates, 2 portraits, minimal HUD.

## 0x8007000e Investigation

Windows D3D12 `CreateResource` / `E_OUTOFMEMORY`, then `texture_create failed` and null framebuffers.

Identified stacking: lossless 1448–2172 px UI/stage atlases + Main preloading results/select + nine stage `preload`s + catalog extra models/raw PNGs + possible multi-pipeline fighter textures.

Mitigations shipped (path B). Desktop GPU log still required (BLOCKER-020).

## GPU Texture Estimate

Largest battle-resident RGBA8-equivalent items: two HUD plates (~12.6 MB lossless), hero BG + platform kit (~8.4 MB each with mips before GPU compress), four 2048² fighter maps (~64 MB uncompressed, BPTC after runtime compress). Class D event textures are not battle-resident. Import: class B/D `compress/mode=2`; HUD/portraits/logo remain lossless.

## Resource Lifetime

`Main._enter_match` frees `screen_root` (menu or select). Results script is not a const PackedScene/preload. Victory textures load in `KapesResultsScreen.setup`. FX overlay instantiates on first KO. Catalog does not hold victory Texture2D or fallback Script instances.

## Material / Texture Duplication

Hit flash: `duplicate(false)` — shared albedo/normal. Runtime GLTF path compresses ImageTextures once at load. HUD portrait cache still makes one processed copy per character (crop), not per spawn.

## Rematch Stability

`docs/generated/REMATCH_RESOURCE_STABILITY.csv` — 10 cycles, nodes 100, objects ~1738, resources 47. No runaway growth. Headless video/texture mem monitors are 0.

## Performance

F3 overlay (`m0_hud.gd`) shows FPS, frame ms, nodes, objects, `OBJECT_RESOURCE_COUNT`, `RENDER_VIDEO_MEM_USED`, `RENDER_TEXTURE_MEM_USED` (Godot 4.7 monitors; bytes shown as MB).

## Gameplay Freeze Confirmation

No edits to movement, jump, gravity, fast fall, attack timing, hitboxes, hurtboxes, damage, knockback, hitstun, stocks, respawn, blast zones, camera follow, stage collision, or match rules. `Fighter.tscn` collider remains height 2.4 / radius 0.65. Presentation targets remain 2.40 / 3.15.

## Automated Tests

90 passed (`tests/test_m0_combat.py`, `tests/test_actorcore_idle_benchmark.py`, `tests/test_actorcore_production_migration.py`). Prior suite preserved and updated for production authority; new regressions cover V3 GLBs, catalog, idle/skeleton, retarget off, proxy idle off, sizes, lazy fallback, menu/results lifetime, rematch hooks.

## Godot Validation

`Godot --import --headless` completed (nonfatal Blender-path warning for `.blend` files).

`validate_actorcore_production.gd`: **PASS** — both fighters `pipeline=ACTORCORE_V3`, 101 bones, `idle` present.

Headless `SSK_AUTO_SELECT_BATTLE=1` + `SSK_FIGHTER_PIPELINE_AUDIT=1`:

```
pipeline=ACTORCORE_V3
model=terere_game_ready_v3.glb
skeleton_bones=101
animation=idle
skeletal_tracks=21
runtime_retarget=false
proxy_idle=false
fallback=false
visual_instances=1
target_height=2.40
```

and Jaguareté equivalent at **3.15**.

Healthy production log contains no `[JAG_RIG] Baked GLB missing`.

## Human Validation Required

1. Desktop battle: both fighters idle with real skeletal motion (not bobbing capsules).
2. Canonical sizes still read as Tereré shorter (2.40) / Jaguareté taller (3.15).
3. Character select portraits, HUD portraits, and winner art unchanged.
4. Output: no `0x8007000e`, no `texture_create failed`, no pipeline ERROR.
5. F3: VRAM/TEX not climbing across rematch.
6. Optional: open project in editor once so PackedScene imports can be generated (BLOCKER-019).

## Blockers

- BLOCKER-019: headless does not write V3 PackedScene imports; GLTFDocument + BPTC used
- BLOCKER-020: desktop 0x8007000e reproduction still required
- BLOCKER-016 family still true for benchmark GLBs
- Run/jump/attack/hit/KO skeletal clips **not** in this milestone

## Files Created

- `assets/fighters/processed/terere/terere_game_ready_v3.glb`
- `assets/fighters/processed/jaguarete/jaguarete_game_ready_v3.glb`
- `scripts/fighters/actorcore_fighter_visual.gd`
- `fighters/terere/terere_actorcore_visual.gd`
- `fighters/jaguarete/jaguarete_actorcore_visual.gd`
- `scripts/debug/validate_actorcore_production.gd`
- `scripts/debug/rematch_resource_stability.gd`
- `scripts/debug/check_actorcore_scripts.gd`
- `tools/audit_gpu_resources.py`
- `tests/test_actorcore_production_migration.py`
- `docs/GPU_RESOURCE_AUDIT_V1.md`
- `docs/ACTORCORE_PRODUCTION_MIGRATION_V1_REPORT.md`
- `docs/generated/GPU_TEXTURE_INVENTORY.csv`
- `docs/generated/REMATCH_RESOURCE_STABILITY.csv`
- `docs/generated/ACTORCORE_PRODUCTION_GODOT_VALIDATION.txt`

## Files Modified

- `scripts/fighters/fighter_catalog.gd`
- `scripts/fighters/fighter_definition.gd`
- `scripts/fighters/fighter.gd`
- `scripts/fighters/glb_fighter_visual.gd`
- `scripts/fighters/glb_fighter_config.gd`
- `scripts/core/main.gd`
- `scripts/stages/defensores_stage.gd`
- `scripts/ui/kapes_menu_screen.gd`
- `scripts/ui/kapes_character_select.gd`
- `scripts/ui/kapes_results_screen.gd`
- `scripts/ui/m0_hud.gd`
- `tests/test_m0_combat.py`
- `tests/test_actorcore_idle_benchmark.py`
- `docs/Overnight_blockers.md`
- Class B/D `*.png.import` `compress/mode=2` (hero BG + platform mips on)

## Recommended Next Step

Human playtest of production Idle on desktop. After approval, execute **SSK_SHARED_ACTORCORE_ANIMATION_LIBRARY_V1** (Idle, Run, Jump, Attack, Air Attack, Hit, Heavy Hit, KO, Victory) on this same generic ActorCore pipeline — not now.
