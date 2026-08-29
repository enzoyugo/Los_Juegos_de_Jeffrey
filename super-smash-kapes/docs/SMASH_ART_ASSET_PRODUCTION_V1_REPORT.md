# SMASH_ART_ASSET_PRODUCTION_V1 Report

**Verdict:** `SMASH_ART_ASSET_PRODUCTION_V1_PARTIAL`

Hybrid Blender → Godot pipeline is live for three stylized fighters + two stage visuals. Assets pass an **interim (B)** production gate: clearly better than pure procedural capsules for silhouette/identity, not final painted production polish.

## Blender capability audit

| Check | Result |
|-------|--------|
| Blender executable | `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` |
| Version | **5.2.1 LTS** (`9e2066aef7ef`) |
| bpy / background Python | OK |
| Existing Jeffrey Blender tooling | `tools/blender/` (ActorCore/Track/Zombies + new `tools/blender/smash/`) |
| Tereré / Jaguareté | Still ActorCore GLB path (unchanged) |
| Review outputs | `E:\JeffreyAIResearch\outputs\runtime-review\smash_art_asset_production_v1\` |
| Godot GLB import | Production GLBs committed under `assets/`; load via `PackedScene` |

Blender was **not** assumed unavailable — local install was used successfully.

## Visual target

Stylized 3D party game · caricature · low/mid poly · readable silhouettes · strong colors · exaggerated proportions. **Not** photoreal / ActorCore reconstruction.

## Fort pilot

| Dimension | Status |
|-----------|--------|
| Model | Primitive-built white/gold glam, dark hair, gold sunglasses, star, open-arm slap pose |
| Tris | ~2020 |
| Rig / animation | Named parts + existing procedural motion (no full skeleton) |
| Godot | `jeffrey_stylized_glb_visual.gd` + catalog `production_glb_path` |
| Fallback | Procedural `jeffrey_stylized_fighter_visual.gd` |
| **Grade** | **B — INTERIM-WORTHY** |

Rationale: stronger identity cues than capsules; still blocky / material-sensitive under EEVEE portrait lighting. Good enough to proceed with Cartes / Pájaro same pipeline.

## Cartes

- Navy suit + sash tricolor cue, compact heavy silhouette
- Tris ~548
- Grade **B**
- Gameplay profile unchanged

## Pájaro Campana

- Bird silhouette, crest, beak, wings (`ArmL`/`ArmR` for flap motion)
- Tris ~1298
- Grade **B+** (best silhouette fit for this pipeline)

## Palacio

- Visual GLB: towers + windows (emissive) + flag colors + plaza
- Tris ~168
- Loaded under `ArtRoot`; **collision unchanged**
- Grade **B** (recognizable landmark vs flat sky only)

## Costanera

- River, walkway, skyline, lamps, trees
- Tris ~2368
- Grade **B**

## Portrait pipeline

Reusable path in the same Blender script: standardized camera, transparent film, select 512² + victory 512×640, plus review angles outside the repo.

## KO presentation

Godot-driven: existing KO flash + stage accent wash + expanding KO burst rect. No combat logic changes.

## Performance / triangle counts

| Asset | Tris (approx) |
|-------|----------------|
| fort | 2020 |
| cartes | 548 |
| pajaro_campana | 1298 |
| palacio visual | 168 |
| costanera visual | 2368 |

All well under dense-mesh risk; GLBs are small (~50–200 KB).

## Fallback behavior

Missing GLB → procedural stylized mesh. Missing stage GLB → camera silhouette props. Env `SSK_DISABLE_STAGE_VISUALS=1` disables stage art.

## Remaining gaps

- No authored idle/attack/KO AnimationPlayer clips
- Portrait framing/materials still sensitive to EEVEE lighting
- Stage GLB world placement may need camera-distance tuning after interactive playtest
- Defensores still uses prior stadium camera BG path (out of scope)

## Recommended next sprint

**SMASH_BLENDER_ART_POLISH_V1** — silhouette/material pass on Fort, simple AnimationPlayer clips, stage placement smoke, optional HUD portrait crops.
