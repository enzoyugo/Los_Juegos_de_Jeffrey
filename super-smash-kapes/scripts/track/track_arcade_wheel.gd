class_name TrackArcadeWheel
extends Node3D

## Contact / force sensor. Not a RigidBody. Chassis remains the only rigid body.

const WheelConfig := preload("res://scripts/track/track_wheel_physics_config.gd")

@export var wheel_id: String = "FL"
@export var is_front: bool = true
@export var is_steering: bool = true
@export var is_driven: bool = true
@export var debug_enabled: bool = false

var radius: float = WheelConfig.WHEEL_RADIUS
var rest_length: float = WheelConfig.SUSPENSION_REST_LENGTH
var suspension_travel: float = WheelConfig.SUSPENSION_TRAVEL
var spring_strength: float = WheelConfig.SPRING_STRENGTH
var damper_compression: float = WheelConfig.COMPRESSION_DAMPING
var damper_rebound: float = WheelConfig.REBOUND_DAMPING
var longitudinal_grip: float = WheelConfig.LONGITUDINAL_GRIP
var lateral_grip: float = WheelConfig.FRONT_LATERAL_GRIP
var drift_grip_multiplier: float = 1.0
var max_longitudinal_force: float = WheelConfig.MAX_LONGITUDINAL_FORCE
var max_lateral_force: float = WheelConfig.MAX_LATERAL_FORCE
var contact_cast_length: float = WheelConfig.SUSPENSION_REST_LENGTH + WheelConfig.SUSPENSION_TRAVEL + WheelConfig.CONTACT_CAST_LENGTH_EXTRA

var is_grounded: bool = false
var contact_point: Vector3 = Vector3.ZERO
var contact_normal: Vector3 = Vector3.UP
var suspension_length: float = WheelConfig.SUSPENSION_REST_LENGTH
var compression: float = 0.0
var compression_velocity: float = 0.0
var wheel_load: float = 0.0
var forward_velocity: float = 0.0
var lateral_velocity: float = 0.0
var slip_angle: float = 0.0
var steer_angle: float = 0.0
var spin_angle: float = 0.0
var last_suspension_force: float = 0.0
var last_lateral_force: float = 0.0
var last_longitudinal_force: float = 0.0
var contact_piece_id: String = ""
var contact_collider_name: String = ""
var contact_kind: String = ""
var last_contact_kind: String = ""
var last_contact_piece_id: String = ""
var last_contact_collider_name: String = ""
var rejected_normal: bool = false
var last_world_susp: Vector3 = Vector3.ZERO
var last_world_lat: Vector3 = Vector3.ZERO
var last_world_long: Vector3 = Vector3.ZERO

var _ray: RayCast3D
var _prev_length: float = WheelConfig.SUSPENSION_REST_LENGTH
var _chassis: RigidBody3D


static func compression_m(rest_m: float, contact_length: float, travel: float) -> float:
	return clampf(rest_m - contact_length, 0.0, travel)


func setup_on_chassis(chassis: RigidBody3D) -> void:
	_chassis = chassis
	if _ray == null:
		_ray = RayCast3D.new()
		_ray.name = "GroundCast"
		_ray.enabled = true
		_ray.collide_with_areas = false
		_ray.collide_with_bodies = true
		_ray.collision_mask = 1
		_ray.hit_from_inside = true
		add_child(_ray)
	_ray.add_exception(chassis)
	_ray.target_position = Vector3(0.0, -(contact_cast_length + radius), 0.0)


func reset_contact_state() -> void:
	is_grounded = false
	compression = 0.0
	compression_velocity = 0.0
	suspension_length = rest_length
	_prev_length = rest_length
	last_suspension_force = 0.0
	last_lateral_force = 0.0
	last_longitudinal_force = 0.0
	wheel_load = 0.0
	contact_piece_id = ""
	contact_collider_name = ""
	contact_kind = ""
	rejected_normal = false
	last_world_susp = Vector3.ZERO
	last_world_lat = Vector3.ZERO
	last_world_long = Vector3.ZERO
	steer_angle = 0.0


func step(state: PhysicsDirectBodyState3D, delta: float, throttle: float, brake: float, engine_share: float) -> void:
	is_grounded = false
	last_suspension_force = 0.0
	last_lateral_force = 0.0
	last_longitudinal_force = 0.0
	wheel_load = 0.0
	contact_piece_id = ""
	contact_collider_name = ""
	contact_kind = ""
	rejected_normal = false
	last_world_susp = Vector3.ZERO
	last_world_lat = Vector3.ZERO
	last_world_long = Vector3.ZERO
	if _ray == null or state == null:
		return
	_ray.target_position = Vector3(0.0, -(contact_cast_length + radius), 0.0)
	_ray.force_raycast_update()
	if not _ray.is_colliding():
		suspension_length = rest_length + suspension_travel
		compression = 0.0
		compression_velocity = 0.0
		_prev_length = suspension_length
		_spin_from_speed(0.0, delta)
		return
	var normal := _ray.get_collision_normal()
	if normal.y < WheelConfig.MIN_GROUND_NORMAL_Y:
		rejected_normal = true
		suspension_length = rest_length + suspension_travel
		compression = 0.0
		_prev_length = suspension_length
		_spin_from_speed(0.0, delta)
		return
	is_grounded = true
	contact_point = _ray.get_collision_point()
	contact_normal = normal.normalized()
	var collider := _ray.get_collider()
	contact_collider_name = str(collider.name) if collider != null and collider is Node else ""
	contact_piece_id = _piece_id_from_collider(collider)
	if collider is Node and (collider as Node).has_meta("collision_kind"):
		contact_kind = str((collider as Node).get_meta("collision_kind"))
	last_contact_kind = contact_kind
	last_contact_piece_id = contact_piece_id
	last_contact_collider_name = contact_collider_name
	var origin := global_position
	var hit_dist: float = origin.distance_to(contact_point)
	suspension_length = clampf(hit_dist - radius, rest_length - suspension_travel, rest_length + suspension_travel)
	compression = compression_m(rest_length, suspension_length, suspension_travel)
	compression_velocity = (suspension_length - _prev_length) / maxf(delta, 0.0001)
	_prev_length = suspension_length
	var spring_f := compression * spring_strength
	var damp_f := 0.0
	if compression_velocity < 0.0:
		damp_f = -compression_velocity * damper_compression
	else:
		damp_f = -compression_velocity * damper_rebound
	var susp := clampf(spring_f + damp_f, 0.0, WheelConfig.MAX_SUSPENSION_FORCE)
	last_suspension_force = susp
	wheel_load = susp
	last_world_susp = contact_normal * susp
	_apply_at(state, last_world_susp, contact_point)
	var com_world: Vector3 = state.transform * state.center_of_mass
	var vel: Vector3 = state.linear_velocity + state.angular_velocity.cross(contact_point - com_world)
	var up := state.transform.basis.y.normalized()
	var steer_basis := state.transform.basis.rotated(up, steer_angle)
	var wheel_forward := -steer_basis.z
	wheel_forward.y = 0.0
	if wheel_forward.length() < 0.001:
		wheel_forward = Vector3(0, 0, -1)
	else:
		wheel_forward = wheel_forward.normalized()
	var wheel_right := up.cross(wheel_forward)
	if wheel_right.length() < 0.001:
		wheel_right = steer_basis.x
	else:
		wheel_right = wheel_right.normalized()
	forward_velocity = vel.dot(wheel_forward)
	lateral_velocity = vel.dot(wheel_right)
	slip_angle = atan2(lateral_velocity, maxf(absf(forward_velocity), 1.0))
	var grip := lateral_grip * drift_grip_multiplier
	var surf := 1.0
	if contact_kind == "shoulder":
		surf = 0.58
	elif contact_kind == "offtrack":
		surf = 0.24
	grip *= surf
	var lat: float = WheelConfig.lateral_tire_force(lateral_velocity, forward_velocity, wheel_load, grip)
	lat = clampf(lat, -max_lateral_force, max_lateral_force)
	last_lateral_force = lat
	last_world_lat = wheel_right * lat
	_apply_at(state, last_world_lat, contact_point)
	var long_f := 0.0
	var drive_cap: float = WheelConfig.MAX_SPEED
	if _chassis != null and bool(_chassis.get("boost_active")):
		drive_cap = WheelConfig.MAX_SPEED * 1.22
	if is_driven:
		long_f += WheelConfig.drive_force(throttle, forward_velocity, WheelConfig.ENGINE_FORCE * engine_share, drive_cap, WheelConfig.HIGH_SPEED_FORCE_SCALE)
	long_f += WheelConfig.brake_or_reverse_force(forward_velocity, brake, WheelConfig.BRAKE_FORCE * engine_share, WheelConfig.REVERSE_FORCE * engine_share, WheelConfig.REVERSE_ENTER_SPEED)
	var long_cap := minf(max_longitudinal_force, longitudinal_grip * clampf(wheel_load / 1100.0, 0.2, 1.6))
	long_f = clampf(long_f, -long_cap, long_cap)
	long_f *= surf
	if contact_kind == "offtrack":
		long_f -= forward_velocity * 420.0
	elif contact_kind == "shoulder":
		long_f -= forward_velocity * 90.0
	last_longitudinal_force = long_f
	last_world_long = wheel_forward * long_f
	_apply_at(state, last_world_long, contact_point)
	_spin_from_speed(forward_velocity, delta)


func debug_line() -> String:
	return "%s g=%s c=%.2f load=%.0f slip=%.2f lat=%.0f long=%.0f st=%.2f" % [
		wheel_id,
		"Y" if is_grounded else "N",
		compression,
		wheel_load,
		slip_angle,
		last_lateral_force,
		last_longitudinal_force,
		steer_angle,
	]


func _apply_at(state: PhysicsDirectBodyState3D, force: Vector3, world_point: Vector3) -> void:
	if force.length() < 0.001:
		return
	state.apply_force(force, world_point - state.transform.origin)


func _spin_from_speed(forward_speed: float, delta: float) -> void:
	spin_angle += (forward_speed / maxf(radius, 0.05)) * delta
	spin_angle = fmod(spin_angle, TAU)


static func _piece_id_from_collider(obj: Object) -> String:
	if obj == null:
		return ""
	if obj.has_meta("track_piece_id"):
		return str(obj.get_meta("track_piece_id"))
	var n := obj as Node
	while n != null:
		var raw: Variant = n.get("piece_id")
		if raw != null and str(raw) != "":
			return str(raw)
		n = n.get_parent()
	return ""
