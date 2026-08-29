# Track Turbo driving feel V7

## Primary Verdict

**TRACK_TURBO_DRIVING_FEEL_V7_READY_FOR_HUMAN_REVIEW**

Width, chase camera, and intentional drift are in isolated labs plus `TrackTurboV7Showcase`. Nothing here is TrackMain-canonical.

## Width

Kit modules remain **11.0 m** (`ROAD_WIDTH`, geometry contract, JSON). Lab candidate **15.0 m** is measured in `TrackWidthCameraDriftLab.tscn` (14 / 15 / 16 lanes via local-X scale). Naive whole-scene X-scale is not applied to Generator V4.

Difficulty must not equal “narrower road.” TRANQUI/PICANTE/DEMENTE width bands wait on human review.

## Camera

`TrackDynamicChaseCamera`: FOV 70→86 with speed, yaw lag, drift velocity blend, crest/air height, boost FOV punch, landing pitch/shake, reset re-anchor. FOV clamped 60–92. NaN position snaps back.

Not buried in `TrackWheelCar`. TrackMain still uses `TrackCamera`.

## Drift

Existing 4WHEEL drift state is the system. Entry remains speed + steer + brake/handbrake (`TrackHandling.wants_drift`). Logs `[TRACK_DRIFT] ENTER`. Skid marks persist (`TrackSkidMarks`, cap 420). Rear smoke particles. No SPRING / TRAVEL / COM / MAX_FORCE retune.

## Labs

`TrackWidthCameraDriftLab` · `TrackCameraLab` · `TrackDriftLab` — `VISUAL_REVIEW_PENDING`.
