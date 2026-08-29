# V9 visual review package

**Verdict: READY_FOR_HUMAN_REVIEW** — not VISUAL_MATCH.

Blender EEVEE stills were **not** rendered on this machine (`nvoglv64.dll` access violation). Godot D3D12 stills from `CaptureV9VisualReview.tscn` are the review images.

## shopping/

Godot captures (named after SDS beauty cameras):

- `sds_beauty_spawn.png`
- `sds_beauty_parking.png`
- `sds_beauty_entrance.png`
- `sds_beauty_facade.png`
- `sds_beauty_side.png`
- `sds_beauty_night.png`

`authority/` holds five Street View **contact sheets copied from reference** (not imported into Godot). Compare by eye. Do not auto-score MATCH.

## track/

- `track_straight_urban.png`
- `track_90_curve.png`
- `track_landmark.png`
- `track_finish.png`
- `track_wide_overview.png`

## asset_manifests/

Copies of `docs/generated/asset_usage_v9/`.

Human F6: `ShoppingBlenderEnvironmentV2Lab.tscn` then `ZombiesMain.tscn`. Track: `TrackTurboV8Showcase.tscn`.
