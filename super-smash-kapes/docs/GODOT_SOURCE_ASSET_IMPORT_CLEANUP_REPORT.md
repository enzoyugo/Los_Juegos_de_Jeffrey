# Godot Source Asset Import Cleanup

## Verdict

The two Tereré AccuRIG `.fbm` PNGs are **valid source files**. Godot was failing because it **should not import them**. They live next to `autorig_actor.fbx` under `res://`, so the editor scanned the FBX, resolved generic `model_Pbr_*.png` names, and ran the lossless-WebP / `.ctex` path.

**Fix applied (no file move, no Clean Rig V1 change):**

- Added `assets/fighters/source_rigged/.gdignore` so Godot skips the whole AccuRIG source tree.
- Deleted only the matching `.godot/imported/` cache for those `model_Pbr_*.ctex` files and `autorig_actor.fbx-*.scn`.
- Did **not** wipe `.godot/` and did **not** re-export Clean Rig V1.

Headless reimport + Clean Rig lab validation: **no** WebP / `size <= 0` / `source_rigged` / `autorig_actor.fbm` errors. Labs still load the clean GLBs (`load_ok=true`, `fallback=false`, 101 bones).

## Human-visible errors

Reported on:

- `assets/fighters/source_rigged/terere/actorcore/autorig_actor.fbm/model_Pbr_Diffuse.png`
- `assets/fighters/source_rigged/terere/actorcore/autorig_actor.fbm/model_Pbr_Normal.png`

Typical Output lines (historical, same family):

- WebP packing failed
- Failed loading `.ctex`
- `size <= 0`
- Missing `res://assets/fighters/model_Pbr_Diffuse.png` / `model_Pbr_Normal.png` (those files **never existed**; FBX used a bare filename)

## Diagnosis

| Hypothesis | Result |
|---|---|
| Zero / corrupt source PNG | **No.** Both Tereré maps are valid PNG-24, 2048×2048, RGB (color type 2), `IEND` present. Diffuse 4 230 582 bytes, normal 4 707 910 bytes. |
| Stale / wrong `.godot` import cache | **Contributing.** Lossless `.ctex` existed (`GST2`, 2048×2048, 2.9–4.4 MB, not zero). Import mode was `compress/mode=0` (lossless WebP) with `detect_3d/compress_to=1`. FBX 3D use can re-encode that path and emit WebP / empty-buffer errors even when the PNG is healthy. |
| Invalid generated `.ctex` as the *root* | **No as sole cause.** Cache files were non-empty GST2. Failures show up when Godot **reimports** or when the FBX importer asks for a sibling/bare `model_Pbr_*.png`. |
| Obsolete source scanned under `res://` | **Yes — primary.** Clean Rig V1 GLBs embed their own PNGs. No gameplay scene loads these `.fbm` maps. Godot was importing AccuRIG authoring files as if they were game textures. |

Jaguareté `.fbm` maps are the same pattern (valid 2048 PNG, same lossless import). They were not named in the latest Output spam but would fail the same way on a full FBX reimport.

## What was not the problem

- Clean Rig V1 GLBs (embedded `model_Pbr_Diffuse` / `model_Pbr_Normal`, Godot materials `…glb::StandardMaterial3D_*`).
- SHA256 unchanged after this cleanup:
  - Tereré `terere_clean_rig_v1.glb` `2e5fa018e55852052e3f595b8b6cf2756ed136d755cfe22b198c50136ef768ed`
  - Jaguareté `jaguarete_clean_rig_v1.glb` `cafa9f55dafcc2229c6f48ca17635a1febb4b26f1f53baae3dd3591b30549742`
- Production V4 paths were not touched.

## Fix details

### 1. Stop the scan (authoritative)

`assets/fighters/source_rigged/.gdignore`

Presence of this file makes Godot ignore the directory and all children. AccuRIG FBX, `.fbm` PNGs, and `.json` stay on disk for Blender/Python. They are no longer `res://` import targets.

This is **not** a move. Filesystem paths used by tools still work.

### 2. Targeted cache only

Removed from `.godot/imported/` (not a full `.godot` wipe):

- `model_Pbr_Diffuse.png-a2d8f611e5fa7a54c87d110413694cea.ctex` (Tereré)
- `model_Pbr_Normal.png-86c76ab06ee405ea05c871fd56c814dd.ctex` (Tereré)
- matching Jaguareté `model_Pbr_*.ctex` / `.md5`
- `autorig_actor.fbx-*.scn` / `.md5` for both fighters

After `--headless --import`, editor `filesystem_cache10` has **zero** `source_rigged` / `autorig_actor` entries.

Leftover `*.png.import` next to the source PNGs are inert while `.gdignore` is present.

## Validation

```
E:\Godot_v4.7.2-stable_win64_console.exe --path E:\SuperSmashKapes\super-smash-kapes --headless --import --quit
E:\Godot_v4.7.2-stable_win64_console.exe --path E:\SuperSmashKapes\super-smash-kapes --headless res://scenes/debug/ValidateCleanRigV1Labs.tscn
```

| Check | Result |
|---|---|
| WebP / `size <= 0` / failed `.ctex` | **0** |
| `source_rigged` / `autorig_actor.fbm` in Output | **0** |
| Tereré lab | `load_ok=true`, `fallback=false`, 101 bones, clean GLB only |
| Jaguareté lab | same |
| Source PNGs still on disk | yes |

If the editor was already open, close it and reopen so it rebuilds the file map (the headless import already did that for a fresh process).

## `source_rigged/` dependencies (do not move yet)

Nothing in Godot **runtime** loads these as `res://` resources. `scripts/debug/clean_rig_lab.gd` **rejects** any path containing `source_rigged`.

**Must keep current filesystem paths** until a coordinated retarget:

| Consumer | How it uses the path |
|---|---|
| `tools/blender/actorcore_paths.py` | `CHARACTERS[*].fbx` / `.json` / `fbm_dir` |
| `tools/blender/normalize_accurig_game_rig.py` and related Blender scripts | import AccuRIG FBX + rebind `.fbm` textures |
| `tools/build_fighter.ps1` | `assets\fighters\source_rigged\$Character\actorcore\autorig_actor.fbx` |
| `tests/test_actorcore_idle_benchmark.py` | `Path.is_file()` on fbx/json/fbm |
| `tests/test_m0_combat.py` | asserts `autorig_actor.fbx` exists |
| `docs/generated/*` | recorded `source_fbx` / `source_fbm` absolute paths |

`.gdignore` does **not** break those: they use OS paths, not `ResourceLoader`.

**Godot scenes / gameplay:** no `.tscn` instances `autorig_actor.fbx`. Catalog still points at V4 GLBs.

## Future: move outside `res://`?

**Yes, recommended later.** AccuRIG FBX/`.fbm` are Blender authorities, not Godot runtime assets.

Suggested layout (not done):

```
E:\SuperSmashKapes\source\fighters\terere\actorcore\...
E:\SuperSmashKapes\source\fighters\jaguarete\actorcore\...
```

or a sibling folder next to the Godot project. Then update `actorcore_paths.py`, `build_fighter.ps1`, and the two tests.

**Do not move now.** `.gdignore` already stops Godot import. Moving without updating the table above would break Blender bakes and pytest existence checks.

`.gdignore` vs move:

- `.gdignore` — keep tree in-repo, hide from Godot. Good default.
- Move outside project — stronger isolation; requires path edits + documenting the new root.

Also still imported by Godot (out of scope here): `processed/actorcore_benchmark`, `solver_v1`, `semantic_solver_v2`, `game_ready_v3`, V4 sidecars. Those are `DEBUG_ONLY` / `PRODUCTION` / `DEPRECATED_EXPERIMENT` in `docs/generated/GODOT_FIGHTER_IMPORT_SURFACE.json`. Do not `.gdignore` V4.

## Production / Clean Rig safety

- No gameplay scripts changed.
- No Clean Rig V1 `.glb` / `.blend` rewritten.
- No V4 overwrite.
- No commit / push.

## Files touched

| Path | Action |
|---|---|
| `assets/fighters/source_rigged/.gdignore` | **added** |
| `.godot/imported/model_Pbr_*.ctex` (+ `.md5`) | **deleted** (AccuRIG hashes only) |
| `.godot/imported/autorig_actor.fbx-*.scn` (+ `.md5`) | **deleted** |
| `docs/GODOT_SOURCE_ASSET_IMPORT_CLEANUP_REPORT.md` | **added** |
| `docs/generated/GODOT_IMPORT_AFTER_SOURCE_GDIGNORE.log` | import log |
| `docs/generated/GODOT_CLEAN_LAB_AFTER_GDIGNORE.log` | lab validation log |

Source PNGs, FBX, and Clean Rig V1 binaries: **unchanged**.

## Recommended next step

Keep `.gdignore`. Human: reopen the editor (or ignore leftover Output from an old session). Idle retarget still belongs on Clean Rig V1 only — not on these FBX files.

When ready to relocate AccuRIG off `res://`, change the dependency table in one pass; do not scatter-move.
