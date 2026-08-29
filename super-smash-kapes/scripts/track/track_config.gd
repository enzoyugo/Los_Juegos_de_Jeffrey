class_name TrackConfig
extends RefCounted

## Arcade tuning. Same car for every character. Cosmetic identity only.
## BASELINE_* = overnight soap-bar greybox.
## V1_* = planted grip pass (rollback).
## Live constants = TRACK_HANDLING_V2.

const TRACK_HANDLING_PRESET := "v2"

## TRACK_HANDLING_BASELINE
const BASELINE_ACCEL := 48.0
const BASELINE_MAX_SPEED := 36.0
const BASELINE_BRAKE := 55.0
const BASELINE_REVERSE_ACCEL := 22.0
const BASELINE_REVERSE_MAX := 10.0
const BASELINE_STEER_LOW := 2.15
const BASELINE_STEER_HIGH := 0.72
const BASELINE_STEER_SPEED_REF := 28.0
const BASELINE_LATERAL_GRIP := 9.8
const BASELINE_COAST_FRICTION := 5.5
const BASELINE_GRAVITY := 32.0
const BASELINE_CAM_DISTANCE := 8.6
const BASELINE_CAM_HEIGHT := 3.15
const BASELINE_CAM_LOOK_AHEAD := 11.0
const BASELINE_CAM_FOLLOW := 11.0

## TRACK_HANDLING_V1 (rollback)
const V1_ACCEL := 58.0
const V1_MAX_SPEED := 38.0
const V1_HIGH_SPEED_ACCEL_SCALE := 0.38
const V1_BRAKE := 72.0
const V1_LATERAL_GRIP := 16.5
const V1_DRIFT_GRIP := 6.2
const V1_STEER_LOW := 2.55
const V1_STEER_HIGH := 0.88
const V1_CAM_DISTANCE := 8.2
const V1_CAM_FOV_MIN := 68.0
const V1_CAM_FOV_MAX := 78.0
## Keep the V1 literal discoverable for rollback tests.
const LATERAL_GRIP_V1 := 16.5

## TRACK_HANDLING_V2 (active)
const ACCEL := 94.0
const MAX_SPEED := 54.0
const HIGH_SPEED_ACCEL_SCALE := 0.40
const BRAKE := 90.0
const REVERSE_ACCEL := 20.0
const REVERSE_MAX := 11.0
const REVERSE_ENTER_SPEED := 1.8
const STEER_LOW := 2.70
const STEER_HIGH := 0.95
const STEER_SPEED_REF := 42.0
const STEER_RESPONSE := 14.0
const LATERAL_GRIP := 18.0
const VELOCITY_ALIGN := 10.5
const YAW_DAMPING := 3.8
const LINEAR_DRAG := 0.48
const COAST_FRICTION := 4.2
const DOWNFORCE := 7.0
const COLLISION_LATERAL_DAMP := 24.0
const GRAVITY := 32.0

const DRIFT_GRIP := 3.4
const DRIFT_YAW_MULTIPLIER := 1.9
const DRIFT_ENTRY_SPEED := 14.0
const DRIFT_STEER_THRESHOLD := 0.28
const DRIFT_RECOVERY_RATE := 4.2
const DRIFT_ENTRY_RATE := 10.0
const DRIFT_MAX_SLIP_ANGLE := 0.72
const DRIFT_ALIGN_SCALE := 0.12
const DRIFT_COUNTERSTEER_GRIP := 9.5

const CAM_DISTANCE := 7.9
const CAM_HEIGHT := 2.15
const CAM_LOOK_AHEAD := 13.5
const CAM_FOLLOW := 18.0
const CAM_YAW_LAG := 10.0
const CAM_FOV_MIN := 66.0
const CAM_FOV_MAX := 80.0
const CAM_LOOK_Y := 0.42

## Arcade boost (BASELINE). Overspeed is capped; not unlimited.
const BOOST_DURATION := 0.85
const BOOST_ACCEL_SCALE := 0.85
const BOOST_OVERSPEED := 1.22
const BOOST_RETRIGGER_LOCK := 0.08
const BOOST_MIN_FORWARD_DOT := 0.25

const GHOST_HZ := 20.0
const FUEL_ATTEMPT_MULT := 2.75
const FUEL_MULTIPLIER := 2.75
const COUNTDOWN_SECONDS := 3.0

## Production TrackMain stays BASELINE. FOUR_WHEEL_V1 is lab / SSK_TRACK_CONTROLLER only.
const CONTROLLER_MODE := "FOUR_WHEEL_V1"
const CONTROLLER_FOUR_WHEEL_V1 := "FOUR_WHEEL_V1"
const CONTROLLER_BASELINE := "BASELINE"

const ROAD_WIDTH_V1 := 8.0
const ROAD_WIDTH := 11.0
## Lab candidate. 15 m kit lives in processed/kit_v8_15m/. 11 m kit remains rollback.
const ROAD_WIDTH_CANDIDATE := 15.0
const ROAD_WIDTH_LAB_14 := 14.0
const ROAD_WIDTH_LAB_15 := 15.0
const ROAD_WIDTH_LAB_16 := 16.0
const ROAD_SHOULDER := 0.7
const GUARDRAIL_HEIGHT := 0.9
const GUARDRAIL_THICKNESS := 0.22
const STRAIGHT_LENGTH := 12.0

const LENGTH_CORTA := "corta"
const LENGTH_MEDIA := "media"
const LENGTH_LARGA := "larga"
const DIFF_TRANQUI := "tranqui"
const DIFF_PICANTE := "picante"
const DIFF_DEMENTE := "demente"

const LENGTH_PIECES := {
	LENGTH_CORTA: 10,
	LENGTH_MEDIA: 16,
	LENGTH_LARGA: 24,
}

const PIECE_TIME := {
	"start": 0.35,
	"straight": 0.45,
	"gentle_left": 0.70,
	"gentle_right": 0.70,
	"medium_left": 0.90,
	"medium_right": 0.90,
	"hairpin_left": 1.35,
	"hairpin_right": 1.35,
	"chicane": 1.05,
	"hill": 0.85,
	"jump": 1.05,
	"finish_approach": 0.55,
	"finish": 0.40,
}

const DIFF_TIME_MULT := {
	DIFF_TRANQUI: 0.95,
	DIFF_PICANTE: 1.0,
	DIFF_DEMENTE: 1.12,
}


static func ensure_actions() -> void:
	_bind("track_accel", [KEY_W, KEY_UP])
	_bind("track_brake", [KEY_S, KEY_DOWN])
	_bind("track_left", [KEY_A, KEY_LEFT])
	_bind("track_right", [KEY_D, KEY_RIGHT])
	_bind("track_reset", [KEY_C])
	_bind("track_restart", [KEY_BACKSPACE])
	_bind("track_drift", [KEY_SHIFT])


static func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)


static func initial_fuel(expected_time: float) -> float:
	return maxf(expected_time * FUEL_MULTIPLIER, 8.0)


static func fresh_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return int(rng.randi())
