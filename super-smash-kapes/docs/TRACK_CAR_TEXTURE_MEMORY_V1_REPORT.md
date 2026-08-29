# TRACK CAR TEXTURE MEMORY V1

## Root cause

`TrackCarVisual._mount_source()` loaded the imported GLB and then called `material.duplicate()` on every surface of every instance (player car, ghosts, ingest lab preview).

The atlas is a **GLB-embedded** 4096×4096 JPEG, stored as a material subresource. Duplicating that imported `StandardMaterial3D` was cloning GPU texture resources (or unique pipeline bindings that still uploaded the 4K map). Combined with:

- `load(SOURCE_GLB)` per instance instead of one `preload` PackedScene
- a ghost `.tres` that ignored the atlas **or** duplicated the imported mat as fallback
- debug pivot materials always spawned
- one unique `StandardMaterial3D` per procedural road box

this produced D3D12 `CreateResource failed 0x8007000e` (E_OUTOFMEMORY) at `_mount_source`, then RID/texture cascade (`texture_create`, `texture_set_size_override`, `texture_free`).

It was not a missing file. It was resource ownership.

## Fix

| Rule | Implementation |
|---|---|
| One PackedScene | `const CAR_VISUAL_SCENE := preload(source glb)` |
| One atlas | static `_shared_atlas` captured once from the imported material |
| Player accent | `StandardMaterial3D.new()` + **same** `albedo_texture` reference |
| Ghosts | one static `_shared_ghost_mat`, same atlas, alpha tint |
| No `duplicate()` of imported materials | removed |
| Road boxes | color material cache on TrackRace / PhysicsLab |

Logs (once per mount, not per frame):

```
[TRACK_CAR_VISUAL] source_instances=… ghost_visuals=… atlas_id=… player_mat_id=… ghost_mat_id=…
```

Expected: `atlas_id` identical across player and ghost instances. `player_mat_id` may differ (lightweight unique mats). `ghost_mat_id` shared.

## Fallback not applied

4K → 2K processed texture was **not** created. Sharing is the first-line fix. If D3D12 still fails after human GPU review, store a 2K under `assets/vehicles/track/processed/` without touching source.

## Renderer

- D3D12 / Forward Plus headless (IngestLab, PhysicsLab, TrackMain): **PASS** — no `CreateResource 0x8007000e`.
- gl_compatibility validator: **PASS**.

A visible D3D12 editor window is still **HUMAN_REVIEW**. 4K→2K fallback was not applied.
