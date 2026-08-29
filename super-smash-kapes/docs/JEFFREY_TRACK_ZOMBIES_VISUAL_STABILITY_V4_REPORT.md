# Los Juegos de Jeffrey — Track + Zombies visual + stability V4

## MASTER VERDICT

**JEFFREY_TRACK_ZOMBIES_VISUAL_STABILITY_V4_PARTIAL**

| Stream | Verdict |
|---|---|
| D3D12 | `JEFFREY_D3D12_RESOURCE_EXHAUSTION_RESOLVED` |
| Track | `TRACK_4WHEEL_V5_READY_FOR_HUMAN_REVIEW` |
| Zombies | `ZOMBIES_SHOPPING_VISUAL_V4_PARTIAL` |
| Visual pipeline | `ZOMBIES_VISUAL_PIPELINE_LIMITATION_DETECTED` |

Not a content dump. Generator V4 frozen. TrackMain BASELINE. Zombies loop unchanged (parking spawn, 1500 SHOPPING, interior authority). Visual READY was **not** awarded.

## What closed

- **D3D12 RCA:** first buffer sizes 262144 (NoiseTexture2D 256²) and ~20.5 MB (large image). Street View import storm identified and `.gdignore`’d. Windowed 3-cycle harness **PASS** (`fatal=false`, no `0x8007000e`). Peak static 140.4 MB, no cycle-to-cycle leak.
- **Boost:** wrong-way / reverse is `SKIP_WRONG_WAY`, not `push_error` reverse launch. Smoke PASS.
- **Crest:** two-box ridge replaced with C1 haversine segments. `crest_air=0`. No suspension retune.
- **Shopping exterior:** reference-inventoried and rebuilt (aisle, stalls, islands, palms, lamps, kit cars, glass entrance, skyline, night lighting). GLB loaded then **hidden** — it is a volume, not a facade.

## What did not close

- Exterior does **not** read as Shopping del Sol. References were sufficient; the code-built + kit + unusable-GLB pipeline is the limit. Next: Blender assembly or an environment artist.
- 4WHEEL lateral floaty deferred.
- Door cost still 1500 pending `[ZOMBIES_PACING]` data.
- TrackMain not promoted.

## Reports

- `docs/JEFFREY_D3D12_INTERMITTENT_RESOURCE_EXHAUSTION_V1_REPORT.md`
- `docs/TRACK_4WHEEL_HUMAN_CLOSURE_V5_REPORT.md`
- `docs/ZOMBIES_SHOPPING_VISUAL_REFERENCE_RECONSTRUCTION_V4_REPORT.md`
- `docs/SHOPPING_REFERENCE_COVERAGE_AND_VISUAL_AUTHORITY_V1.md`
- `docs/SHOPPING_RAW_ASSET_INVENTORY_V1.md`

Captures: `docs/generated/zombies_visual_v4/`, `docs/generated/track_visual_v5/`. D3D12 log: `docs/generated/D3D12_REPEAT_RENDERED_V4.log`.

## Tests

- pytest **343 passed**
- path scan (render-resource test in that suite) clean
- `[JEFFREY_VALIDATE] OK`
- ZombiesSystemsLab `ALL_PASS`
- Shopping integration `shell=true spawn=(0, 0.05, 28.5) parking=9 plaza=3`
- Boost / elevation smokes PASS
- D3D12 rendered 3-cycle PASS

## Human morning

**Track:** F6 `TrackGeneratorV2Lab.tscn` — 4WHEEL default — SHORT/MEDIUM/LONG — boost forward — reverse over boost — gentle elevation — offtrack — reset — F2 BASELINE.

**Zombies:** F6 `ZombiesMain.tscn` — first view must answer the identity question without debug text. Do not expect photoreal SDS. Expect a night parking prototype with a glowing SHOPPING door.
