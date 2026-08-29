class_name TrackDynamicChaseCamera
extends Camera3D

## Dedicated arcade chase camera. Not buried in TrackWheelCar.
## VISUAL_REVIEW_PENDING — not TrackMain canonical.

const Config := preload("res://scripts/track/track_config.gd")
const Telemetry := preload("res://scripts/track/track_debug_telemetry.gd")

var target: Node3D
var _yaw_basis: Basis = Basis.IDENTITY
var _locked: bool = false
var _boost_fov_kick: float = 0.0
var _boost_fov_timer: float = 0.0
var _boost_fov_span: float = 0.28
var _pitch_impulse: float = 0.0
var _shake: float = 0.0
var _reset_blend: float = 0.0
var last_fov: float = 70.0
var last_distance: float = 8.4
var road_look_dir: Vector3 = Vector3.ZERO


func _ready() -> void:
	fov = Config.CAM_FOV_MIN
	last_fov = fov


func snap_to_target() -> void:
	_locked = false
	_reset_blend = 1.0
	_pitch_impulse = 0.0
	_shake = 0.0


func boost_punch(seconds: float) -> void:
	_boost_fov_kick = 6.0
	_boost_fov_span = maxf(seconds, 0.12)
	_boost_fov_timer = _boost_fov_span


func landing_impulse(vy: float) -> void:
	var mag := clampf(absf(vy) * 0.035, 0.0, 0.18)
	_pitch_impulse = mag
	_shake = mag * 0.45


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var car_node: Node = _car_body()
	if car_node == null:
		car_node = target
	var car_basis: Basis = (car_node as Node3D).global_transform.basis if car_node is Node3D else target.global_transform.basis
	if not _locked:
		_yaw_basis = car_basis
		_locked = true
	var speed := _speed(car_node)
	var t := clampf(speed / maxf(Config.MAX_SPEED, 0.001), 0.0, 1.0)
	var drift_state := Telemetry.debug_string(car_node, "drift_state", "")
	var drift_active := drift_state == "drift"
	var airborne := Telemetry.debug_bool(car_node, "debug_airborne", false)
	var lag := Config.CAM_YAW_LAG
	if Telemetry.debug_bool(car_node, "boost_active", false):
		lag *= 0.72
	if drift_active:
		lag *= 0.82
	var yaw_alpha: float = 1.0 - exp(-lag * delta)
	var follow_basis := car_basis
	if drift_active:
		var vel_yaw := _velocity_basis(car_node, car_basis)
		follow_basis = car_basis.slerp(vel_yaw, 0.48)
	_yaw_basis = _yaw_basis.slerp(follow_basis, yaw_alpha)
	var look_ahead := lerpf(Config.CAM_LOOK_AHEAD * 0.85, Config.CAM_LOOK_AHEAD * 1.32, t)
	if airborne:
		look_ahead *= 1.12
	if road_look_dir.length() > 0.2:
		look_ahead *= 1.08
	var height := Config.CAM_HEIGHT
	if airborne:
		height += 0.45
	var dist := Config.CAM_DISTANCE + t * 0.8
	last_distance = dist
	var rear: Vector3 = target.global_position
	if car_node.has_method("rear_axle_midpoint_global"):
		rear = car_node.call("rear_axle_midpoint_global")
	var back: Vector3 = _yaw_basis.z * dist
	var desired: Vector3 = rear + Vector3(0, height, 0) + back
	if _shake > 0.001:
		desired += Vector3(sin(_shake * 40.0) * _shake, cos(_shake * 33.0) * _shake * 0.4, 0)
		_shake = move_toward(_shake, 0.0, delta * 1.8)
	var follow := Config.CAM_FOLLOW
	if _reset_blend > 0.0:
		follow = lerpf(follow, 28.0, _reset_blend)
		_reset_blend = move_toward(_reset_blend, 0.0, delta * 2.4)
	var alpha: float = 1.0 - exp(-follow * delta)
	desired = _shorten_for_collision(rear + Vector3(0, height * 0.45, 0), desired, car_node)
	global_position = global_position.lerp(desired, alpha)
	var look: Vector3 = target.global_position + (-car_basis.z) * look_ahead + Vector3(0, 1.05 + _pitch_impulse, 0)
	if car_node.has_method("front_axle_midpoint_global"):
		look = car_node.call("front_axle_midpoint_global") + (-car_basis.z) * look_ahead + Vector3(0, 1.05 + _pitch_impulse, 0)
	if road_look_dir.length() > 0.2:
		look += road_look_dir.normalized() * (look_ahead * 0.35)
	_pitch_impulse = move_toward(_pitch_impulse, 0.0, delta * 2.2)
	if look.distance_to(global_position) > 0.05:
		look_at(look, Vector3.UP)
	var fov_hi := Config.CAM_FOV_MAX
	fov = lerpf(Config.CAM_FOV_MIN, fov_hi, t)
	if _boost_fov_timer > 0.0:
		_boost_fov_timer = maxf(_boost_fov_timer - delta, 0.0)
		var u := 0.0
		if _boost_fov_span > 0.001:
			u = clampf(_boost_fov_timer / _boost_fov_span, 0.0, 1.0)
		fov += _boost_fov_kick * u * u
	fov = clampf(fov, 60.0, 92.0)
	if not is_finite(fov):
		fov = Config.CAM_FOV_MIN
	if not is_finite(global_position.x):
		global_position = desired
	last_fov = fov


func _shorten_for_collision(from: Vector3, to: Vector3, car_node: Node) -> Vector3:
	var world := get_world_3d()
	if world == null:
		return to
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1 | 128
	q.exclude = _exclude_rids(car_node)
	var hit := world.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return to
	var p: Vector3 = hit.get("position", to)
	var n: Vector3 = hit.get("normal", Vector3.UP)
	return p + n * 0.45


func _exclude_rids(car_node: Node) -> Array:
	var out: Array = []
	if car_node is CollisionObject3D:
		out.append((car_node as CollisionObject3D).get_rid())
	return out


func _car_body() -> Node:
	if target == null:
		return null
	var parent = target.get_parent()
	if parent is CharacterBody3D or parent is RigidBody3D:
		return parent
	return target


func _speed(car_node: Node) -> float:
	if car_node is CharacterBody3D:
		var p := Vector3(car_node.velocity.x, 0.0, car_node.velocity.z)
		return p.length()
	if car_node is RigidBody3D:
		var lv: Vector3 = (car_node as RigidBody3D).linear_velocity
		return Vector3(lv.x, 0.0, lv.z).length()
	return Telemetry.debug_float(car_node, "debug_speed", 0.0)


func _velocity_basis(car_node: Node, fallback: Basis) -> Basis:
	var vel := Vector3.ZERO
	if car_node is RigidBody3D:
		vel = (car_node as RigidBody3D).linear_velocity
	elif car_node is CharacterBody3D:
		vel = (car_node as CharacterBody3D).velocity
	vel.y = 0.0
	if vel.length() < 2.0:
		return fallback
	var f := -vel.normalized()
	var r := Vector3.UP.cross(f)
	if r.length() < 0.001:
		return fallback
	r = r.normalized()
	return Basis(r, Vector3.UP, f).orthonormalized()
