class_name TrackCarVisualConfig
extends RefCounted

## Visual-only Track car presentation. Handling stays on TrackCarController.
## SOURCE remains immutable. 4WHEEL articulated visual candidate is V3 clean.
## V2 is forensic/debug only. BASELINE still uses SOURCE_GLB.

const SOURCE_GLB := "res://assets/vehicles/track/source/track_car_base_v1.glb"
const PROCESSED_ARTICULATED_V2_GLB := "res://assets/vehicles/track/processed/track_car_base_v2_articulated.glb"
const PROCESSED_ARTICULATED_GLB := "res://assets/vehicles/track/processed/track_car_base_v3_articulated_clean.glb"
const SOURCE_SHA256 := "b1dd649b39b0c701ccb5b11062b7087579702caa930d8a0b436dd4d581e725af"
## Canonical 4K albedo. Godot extracted this from SOURCE_GLB. Runtime materials
## must share this imported Texture2D. Never reconstruct, decompress, or
## reference hashed import-cache filenames from gameplay code.
const SHARED_ATLAS := "res://assets/vehicles/track/source/track_car_base_v1_Modelo+3D+de+coche+de+carreras_basecolor.jpg"
const SHARED_ATLAS_AUTHORITY := "res://assets/vehicles/track/materials/track_car_atlas.tres"
const RUNTIME_SCENE := "res://scenes/track/TrackCar.tscn"
const FOUR_WHEEL_RUNTIME_SCENE := "res://scenes/track/TrackCarWheelPhysics.tscn"
const BODY_MATERIAL := "res://assets/vehicles/track/materials/track_car_body_v1.tres"
const PLAYER_MATERIAL := "res://assets/vehicles/track/materials/track_car_player_v1.tres"
const GHOST_MATERIAL := "res://assets/vehicles/track/materials/track_car_ghost_v1.tres"

## glTF native AABB (Y-up, meters-if-normalized): 0.486 x 0.322 x 0.998
const SOURCE_LENGTH := 0.998046875
const SOURCE_WIDTH := 0.486328125
const SOURCE_HEIGHT := 0.322265625
const TARGET_LENGTH := 4.4
## One authoritative scale layer on VisualRoot.
const VISUAL_SCALE := TARGET_LENGTH / SOURCE_LENGTH
## SOURCE fused GLB: model +Z is nose. Track forward is -Z.
const SOURCE_VISUAL_YAW_DEGREES := 180.0
const VISUAL_ROTATION_DEGREES := Vector3(0.0, SOURCE_VISUAL_YAW_DEGREES, 0.0)
const VISUAL_OFFSET := Vector3(0.0, 0.05, 0.0)

const WHEEL_STRUCTURE := "FUSED_BODY_MESH"
const WHEEL_ARTICULATION := "WHEEL_ARTICULATION_BLOCKED_BY_SOURCE_MESH"
const WHEEL_STEERING := "VISUAL_WHEEL_STEERING_DEFERRED"
const ARTICULATED_WHEEL_STRUCTURE := "SEPARATE_NODES"
const ARTICULATED_WHEEL_ARTICULATION := "WHEEL_VISUAL_ARTICULATION_V3"
## Articulated VisualRoot yaw. V3 is authored in -Z-forward chassis space.
## Do not reuse SOURCE_VISUAL_YAW here — that would double-flip wheel mounts vs physics.
const ARTICULATED_VISUAL_YAW_DEGREES := 0.0
const ARTICULATED_VISUAL_ROTATION_DEGREES := Vector3(0.0, ARTICULATED_VISUAL_YAW_DEGREES, 0.0)
## V3 Body is authored -Z-nose (NOSE_MARKER vs REAR_MARKER). No runtime Body yaw.
const ARTICULATED_BODY_YAW_DEGREES := 0.0
## V3 authored axle translations (glTF Y-up, -Z nose), before VisualRoot scale/offset.
const WHEEL_FL_PROCESSED := Vector3(-0.204, 0.085, -0.285)
const WHEEL_FR_PROCESSED := Vector3(0.201, 0.085, -0.285)
const WHEEL_RL_PROCESSED := Vector3(-0.203, 0.085, 0.298)
const WHEEL_RR_PROCESSED := Vector3(0.202, 0.085, 0.298)

## Source-local wheel cluster centers (glTF, before VisualRoot yaw/scale).
const WHEEL_FL_SOURCE := Vector3(-0.201, 0.085, 0.285)
const WHEEL_FR_SOURCE := Vector3(0.204, 0.085, 0.285)
const WHEEL_RL_SOURCE := Vector3(-0.202, 0.085, -0.298)
const WHEEL_RR_SOURCE := Vector3(0.203, 0.085, -0.298)
const WHEEL_RADIUS := 0.35
const MAX_VISUAL_STEER_DEGREES := 28.0

const COLLIDER_SIZE := Vector3(1.80, 0.82, 3.55)
const COLLIDER_OFFSET := Vector3(0.0, 0.48, 0.0)

const CAMERA_ANCHOR_OFFSET := Vector3(0.0, 0.85, 0.0)
const DRIVER_ANCHOR_OFFSET := Vector3(0.0, 1.15, 0.35)
const CHARACTER_MOUNT_OFFSET := Vector3(0.0, 0.95, 0.35)

## One conversion authority. VisualRoot scale is the only visual scale layer.
static func physics_meters_to_visual_local(meters: float) -> float:
	return meters / maxf(VISUAL_SCALE, 0.001)


static func visual_local_to_physics_meters(local: float) -> float:
	return local * VISUAL_SCALE
