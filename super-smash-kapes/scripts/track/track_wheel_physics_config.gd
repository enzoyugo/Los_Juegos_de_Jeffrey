class_name TrackWheelPhysicsConfig
extends RefCounted

## FOUR_WHEEL_TRACK_CONTROLLER_V1 tunables. Parallel to TrackConfig / TrackCarController.
## Arcade, not Pacejka. TrackMain production path stays BASELINE.

const CONTROLLER_ID := "FOUR_WHEEL_TRACK_CONTROLLER_V1"
const DRIVE_AWD := "AWD"
const DRIVE_RWD := "RWD"
const DRIVE_FWD := "FWD"

const MASS := 420.0
const CENTER_OF_MASS_OFFSET := Vector3(0.0, -0.12, 0.06)
const LINEAR_DAMP := 0.10
const ANGULAR_DAMP := 1.55

const WHEEL_RADIUS := 0.35
const SUSPENSION_REST_LENGTH := 0.12
const SUSPENSION_TRAVEL := 0.14
const SPRING_STRENGTH := 32000.0
const COMPRESSION_DAMPING := 3100.0
const REBOUND_DAMPING := 2400.0
const MAX_SUSPENSION_FORCE := 18000.0

const FRONT_LATERAL_GRIP := 9200.0
const REAR_LATERAL_GRIP := 8600.0
const LONGITUDINAL_GRIP := 7800.0
const MAX_LATERAL_FORCE := 12000.0
const MAX_LONGITUDINAL_FORCE := 9000.0
const MIN_GROUND_NORMAL_Y := 0.42
const CONTACT_CAST_LENGTH_EXTRA := 0.08

const ENGINE_FORCE := 6200.0
const MAX_SPEED := 54.0
const HIGH_SPEED_FORCE_SCALE := 0.38
const BRAKE_FORCE := 7800.0
const REVERSE_FORCE := 2400.0
const REVERSE_ENTER_SPEED := 1.8
const DRIVE_TYPE := DRIVE_AWD

const MAX_STEER_LOW_SPEED := 0.55
const MAX_STEER_HIGH_SPEED := 0.18
const STEER_SPEED_REF := 42.0
const STEER_RESPONSE := 12.0

const DRIFT_MIN_SPEED := 14.0
const DRIFT_STEER_THRESHOLD := 0.28
const DRIFT_REAR_GRIP := 0.38
const DRIFT_ENTRY_TIME := 0.18
const DRIFT_RECOVERY_TIME := 0.42
const DRIFT_COUNTERSTEER_REAR_GRIP := 0.72
const DRIFT_ACTIVE_SLIP := 0.10
const DRIFT_ACTIVE_YAW := 0.85

## Secondary arcade assist only. Primary yaw comes from tire forces.
const YAW_ASSIST_TORQUE := 420.0
const YAW_ASSIST_DRIFT := 280.0
const MAX_YAW_RATE := 3.4

## Low-speed structural stabilization only. Does not change 10/20/30 m/s slip.
const LOW_SPEED_STABILITY_BEGIN_MPS := 0.45
const LOW_SPEED_STABILITY_FULL_MPS := 2.40
const LOW_SPEED_LATERAL_DAMP := 1100.0
const REST_ENTER_SPEED := 0.12
const REST_ENTER_YAW := 0.15
const REST_EXIT_INPUT := 0.04
const REST_LATERAL_DAMP := 2600.0
const REST_YAW_DAMP := 180.0
const REST_SLOPE_NY_MIN := 0.999

const FRONT_ANTIROLL := 5200.0
const REAR_ANTIROLL := 4600.0
const DOWNFORCE := 3.8
const AIR_CONTROL := 0.35

const COLLIDER_SIZE := Vector3(1.80, 0.82, 3.55)
const COLLIDER_OFFSET := Vector3(0.0, 0.48, 0.0)


static func chassis_mount(processed_local: Vector3) -> Vector3:
	var vis = load("res://scripts/track/track_car_visual_config.gd")
	return processed_local * vis.VISUAL_SCALE + vis.VISUAL_OFFSET


static func mount_fl() -> Vector3:
	var vis = load("res://scripts/track/track_car_visual_config.gd")
	return chassis_mount(vis.WHEEL_FL_PROCESSED)


static func mount_fr() -> Vector3:
	var vis = load("res://scripts/track/track_car_visual_config.gd")
	return chassis_mount(vis.WHEEL_FR_PROCESSED)


static func mount_rl() -> Vector3:
	var vis = load("res://scripts/track/track_car_visual_config.gd")
	return chassis_mount(vis.WHEEL_RL_PROCESSED)


static func mount_rr() -> Vector3:
	var vis = load("res://scripts/track/track_car_visual_config.gd")
	return chassis_mount(vis.WHEEL_RR_PROCESSED)


static func is_driven(drive_type: String, is_front: bool) -> bool:
	match drive_type:
		DRIVE_FWD:
			return is_front
		DRIVE_RWD:
			return not is_front
		_:
			return true


static func slip_curve_sample(slip_angle_rad: float) -> float:
	## Arcade slip: build → peak → fall. Angles in degrees conceptually.
	var deg := absf(rad_to_deg(slip_angle_rad))
	if deg <= 2.0:
		return lerpf(0.0, 0.6, deg / 2.0)
	if deg <= 5.0:
		return lerpf(0.6, 1.0, (deg - 2.0) / 3.0)
	if deg <= 10.0:
		return lerpf(1.0, 0.9, (deg - 5.0) / 5.0)
	if deg <= 20.0:
		return lerpf(0.9, 0.65, (deg - 10.0) / 10.0)
	if deg <= 30.0:
		return lerpf(0.65, 0.45, (deg - 20.0) / 10.0)
	return 0.45


static func lateral_tire_force_slip(lateral_speed: float, forward_speed: float, load_n: float, grip: float) -> float:
	if load_n <= 1.0:
		return 0.0
	var slip := atan2(lateral_speed, maxf(absf(forward_speed), 1.0))
	var response := slip_curve_sample(slip)
	var load_factor := clampf(load_n / 1100.0, 0.15, 1.65)
	var mag := response * grip * load_factor
	if lateral_speed > 0.0:
		return -mag
	if lateral_speed < 0.0:
		return mag
	return 0.0


static func lateral_tire_force(lateral_speed: float, forward_speed: float, load_n: float, grip: float) -> float:
	if load_n <= 1.0:
		return 0.0
	var slip_f: float = lateral_tire_force_slip(lateral_speed, forward_speed, load_n, grip)
	var planar: float = sqrt(lateral_speed * lateral_speed + forward_speed * forward_speed)
	if planar >= LOW_SPEED_STABILITY_FULL_MPS:
		return slip_f
	var load_factor: float = clampf(load_n / 1100.0, 0.15, 1.65)
	var damp_f: float = -lateral_speed * LOW_SPEED_LATERAL_DAMP * load_factor
	damp_f = clampf(damp_f, -MAX_LATERAL_FORCE, MAX_LATERAL_FORCE)
	if planar <= LOW_SPEED_STABILITY_BEGIN_MPS:
		return damp_f
	var t: float = (planar - LOW_SPEED_STABILITY_BEGIN_MPS) / maxf(LOW_SPEED_STABILITY_FULL_MPS - LOW_SPEED_STABILITY_BEGIN_MPS, 0.001)
	t = clampf(t, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return lerpf(damp_f, slip_f, t)


static func drive_force(throttle: float, forward_speed: float, engine_force: float, max_speed: float, high_scale: float) -> float:
	if throttle <= 0.0:
		return 0.0
	var t := clampf(absf(forward_speed) / maxf(max_speed, 0.001), 0.0, 1.0)
	var scale := lerpf(1.0, high_scale, t * t)
	return engine_force * throttle * scale


static func brake_or_reverse_force(forward_speed: float, brake: float, brake_force: float, reverse_force: float, reverse_enter: float) -> float:
	if brake <= 0.0:
		return 0.0
	if forward_speed > reverse_enter:
		return -brake_force * brake * signf(forward_speed)
	return -reverse_force * brake


static func max_steer_angle(speed: float) -> float:
	var t := clampf(absf(speed) / maxf(STEER_SPEED_REF, 0.001), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return lerpf(MAX_STEER_LOW_SPEED, MAX_STEER_HIGH_SPEED, t)
