# Jeffrey Blender × Track × Zombies V8 master

**Master verdict: JEFFREY_BLENDER_TRACK_ZOMBIES_V8_READY_FOR_HUMAN_REVIEW**

Agent READY ≠ canonical. Human visual authority is mandatory.

## Sub-verdicts

| Area | Verdict |
|---|---|
| Blender pipeline | `JEFFREY_BLENDER_PIPELINE_V1_READY` |
| Track 15 m kit | `TRACK_15M_KIT_V1_READY_FOR_HUMAN_REVIEW` |
| Track airborne | `TRACK_AIRBORNE_SEAM_V2_PARTIAL` |
| Track splits | `TRACK_CHECKPOINT_SPLITS_V1_RESOLVED` |
| Track visual lifetime | `TRACK_VISUAL_LIFETIME_V1_BOUNDED` |
| Track Turbo V8 | `TRACK_TURBO_V8_READY_FOR_HUMAN_PLAYTEST` |
| Shopping Blender env | `SHOPPING_BLENDER_ENVIRONMENT_V1_READY_FOR_HUMAN_REVIEW` |
| Shopping Godot integration | `SHOPPING_BLENDER_GODOT_INTEGRATION_V1_READY_FOR_HUMAN_REVIEW` |

## Firewalls honored

- Generator V4 not rewritten
- 11 m kit not destroyed
- TrackMain stays BASELINE / 11 m
- 4WHEEL springs/COM not retuned
- Shopping not rebuilt from BoxMesh as the visual authority
- `raw_models` not loaded at runtime
- Street View not imported into Godot
- Gameplay collision not derived from detailed Blender meshes
- Zombies systems (rounds, door 1500, wall-buy, MAX AMMO) unchanged

## What to open (human)

**Track:** F6 `scenes/debug/TrackTurboV8Showcase.tscn`  
Judge: 15 m width, camera, drift, **checkpoint splits**, scenery, reveal panel, Hotseat handoff.

Also: `Track15mKitShowcase.tscn`, `TrackAsuncionUrbanV1Showcase.tscn`.

**Zombies:** F6 `scenes/debug/ShoppingBlenderEnvironmentV1Lab.tscn` **first**.

Question: “Does this finally look like a believable Shopping del Sol exterior?”

Only after that: `ZombiesMain.tscn`.

## F6 / memory (measured 2026-08-27)

Harness `F6RepeatStabilityLab.tscn` alternated `TrackTurboV8Showcase` ↔ `ZombiesMain`, 10 launches, hold 3.2 s.

`[F6_STABILITY] PASS launches=10 fatal=false`

No OOM, `mem=null`, `bad_alloc`, or signal 11.

| Probe | static | video | buffers |
|---|---|---|---|
| boot | 80.7 MB | 0 | 0 |
| Track V8 first exit (10 pieces) | 126.4 MB | 434.4 MB | 29.0 MB |
| Zombies exits (steady) | ~147 MB | **427.2 MB** | 28.4 MB |
| Track V8 densest (13 pieces) | 156.5 MB | 533.0 MB | 29.2 MB |
| peak this run | 164.0 MB | 533.0 MB | 29.2 MB |

Video on Track scales with generated piece/scenery count (926–1300 meshes), then returns to 427 MB after every Zombies teardown. Not a 1→2→3 leak across mode switches.

SDS lab after import: `loaded=...glb HUMAN_REVIEW_PENDING` meshes=426 mats=22 static=90.5 MB.

Read-only process diagnostic: `GodotStaleProcessDiagnostic.tscn`. Never auto-kills the editor.

## Stop

No canonical promotion. 15 m remains the **selected candidate** until human playtest.
