# Track Asunción urban scenery V2

## Primary Verdict

**TRACK_ASUNCION_URBAN_SCENERY_V2_READY_FOR_HUMAN_REVIEW**

One theme: `ASUNCION_URBAN`. Does not modify road collision / generator.

## Kit

`TrackSceneryGenerator` sockets: LEFT/RIGHT near trees, lamps, far walls. MultiMesh instancing for trunks/crowns/lamps/walls. Distant skyline boxes, no collision. Landmarks: JEFFREY / TORRE / GRADA (2–4 per track). Optional PSX container from **processed** pack only.

`TrackSignage`: 45°, 90°, chicane IZQ→DER / DER→IZQ, BOOST. Start/finish gantries live with checkpoints.

## Assets

Did not load `assets/raw_models` at runtime. market-al-danube remains reference-only (FBX / branding).

## Performance

Shared materials. MultiMesh. Not thousands of unique BoxMesh resources.

Human still has to decide if this sells speed vs Trackmania Turbo. It is denser than four box trees; it is not a authored city.
