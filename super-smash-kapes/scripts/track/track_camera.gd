class_name TrackCamera
extends Camera3D

const Config := preload("res://scripts/track/track_config.gd")

var target: Node3D
var _yaw_basis: Basis = Basis.IDENTITY
var _locked: bool = false
var _boost_fov_kick: float = 0.0
var _boost_fov_timer: float = 0.0
var _boost_fov_span: float = 0.28


func _ready() -> void:
	fov = Config.CAM_FOV_MIN


func snap_to_target() -> void:
	_locked = false


func boost_punch(seconds: float) -> void:
	_boost_fov_kick = 9.0
	_boost_fov_span = maxf(seconds, 0.12)
	_boost_fov_timer = _boost_fov_span


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var car_basis: Basis = target.global_transform.basis
	var parent = target.get_parent()
	if parent is CharacterBody3D or parent is RigidBody3D:
		car_basis = (parent as Node3D).global_transform.basis
	## Chase framing follows heading, not transient chassis pitch/roll. The
	## articulated controller can settle or land while the camera remains a
	## stable horizon-facing spectator view.
	var forward := -car_basis.z
	forward.y = 0.0
	if forward.length() < 0.001:
		forward = Vector3(0, 0, -1)
	else:
		forward = forward.normalized()
	var yaw_basis := Basis.looking_at(forward, Vector3.UP)
	if not _locked:
		_yaw_basis = yaw_basis
		_locked = true
	var yaw_alpha: float = 1.0 - exp(-Config.CAM_YAW_LAG * delta)
	_yaw_basis = _yaw_basis.slerp(yaw_basis, yaw_alpha)
	var car_node: Node = target
	if parent is CharacterBody3D or parent is RigidBody3D:
		car_node = parent
	var rear: Vector3 = target.global_position
	if car_node.has_method("rear_axle_midpoint_global"):
		rear = car_node.call("rear_axle_midpoint_global")
	## Chassis +Z is rear (forward is -Z). Never a source-mesh +Z offset.
	var camera_distance := Config.CAM_DISTANCE
	var camera_height := Config.CAM_HEIGHT
	if car_node is RigidBody3D:
		## The articulated chassis is physically wider/taller in frame than the
		## legacy CharacterBody3D car. Give the road and dressed world room to read
		## at arcade speed while retaining a confident car silhouette.
		camera_distance = 12.6
		camera_height = 3.15
	var back: Vector3 = _yaw_basis.z * camera_distance
	var desired: Vector3 = rear + Vector3(0, camera_height, 0) + back
	var alpha: float = 1.0 - exp(-Config.CAM_FOLLOW * delta)
	global_position = global_position.lerp(desired, alpha)
	var look: Vector3 = target.global_position + forward * Config.CAM_LOOK_AHEAD + Vector3(0, Config.CAM_LOOK_Y, 0)
	if car_node.has_method("front_axle_midpoint_global"):
		look = car_node.call("front_axle_midpoint_global") + forward * Config.CAM_LOOK_AHEAD + Vector3(0, Config.CAM_LOOK_Y, 0)
	if look.distance_to(global_position) > 0.05:
		look_at(look, Vector3.UP)
	var speed := 0.0
	var body: Node = target
	if not (body is CharacterBody3D) and not (body is RigidBody3D) and (parent is CharacterBody3D or parent is RigidBody3D):
		body = parent
	if body is CharacterBody3D:
		var planar := Vector3(body.velocity.x, 0.0, body.velocity.z)
		speed = planar.length()
	elif body is RigidBody3D:
		var lv: Vector3 = (body as RigidBody3D).linear_velocity
		var planar := Vector3(lv.x, 0.0, lv.z)
		speed = planar.length()
	var t := clampf(speed / maxf(Config.MAX_SPEED, 0.001), 0.0, 1.0)
	fov = lerpf(Config.CAM_FOV_MIN, Config.CAM_FOV_MAX, t)
	if _boost_fov_timer > 0.0:
		_boost_fov_timer = maxf(_boost_fov_timer - delta, 0.0)
		var u := 0.0
		if _boost_fov_span > 0.001:
			u = clampf(_boost_fov_timer / _boost_fov_span, 0.0, 1.0)
		fov += _boost_fov_kick * u * u
		if _boost_fov_timer <= 0.0:
			_boost_fov_kick = 0.0
