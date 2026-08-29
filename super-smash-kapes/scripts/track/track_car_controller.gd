class_name TrackCarController
extends CharacterBody3D

## BASELINE_TRACK_CONTROLLER — canonical TrackMain car. Do not replace with 4-wheel.

const Config := preload("res://scripts/track/track_config.gd")
const Handling := preload("res://scripts/track/track_handling.gd")
const VisualConfig := preload("res://scripts/track/track_car_visual_config.gd")
const CarScenePath := "res://scenes/track/TrackCar.tscn"

const STATE_GRIP := "grip"
const STATE_DRIFT := "drift"
const STATE_AIRBORNE := "airborne"

var control_enabled: bool = false
var slip_amount: float = 0.0
var drift_amount: float = 0.0
var drift_state: String = STATE_GRIP
var debug_enabled: bool = false
var debug_speed: float = 0.0
var debug_along: float = 0.0
var debug_lateral: float = 0.0
var debug_steer: float = 0.0
var debug_throttle: float = 0.0
var debug_brake: float = 0.0
var debug_grip: float = 0.0
var debug_yaw_rate: float = 0.0
var debug_grounded: bool = false
var debug_grounded_n: int = 0
var debug_airborne: bool = false
var debug_slip_angle: float = 0.0
var debug_handbrake: float = 0.0
## Read-only MCP snapshot. Does not change physics.
var jeffrey_debug_state: Dictionary = {}

var _steer_smoothed: float = 0.0
var _front_wheels: Array[Node3D] = []
var _wheel_spin: float = 0.0
var _body_mesh: MeshInstance3D
var _visual: Node = null
var _collider_debug: MeshInstance3D = null
var boost_active: bool = false
var boost_apply_count: int = 0
var use_scripted_input: bool = false
var scripted_throttle: float = 0.0
var scripted_steer: float = 0.0
var scripted_brake: float = 0.0
var _boost_timer: float = 0.0
var _boost_dir: Vector3 = Vector3(0, 0, -1)
var _boost_mag: float = 1.0


static func instantiate_runtime() -> TrackCarController:
	if ResourceLoader.exists(CarScenePath):
		var packed: PackedScene = load(CarScenePath) as PackedScene
		if packed != null:
			var node = packed.instantiate()
			if node is TrackCarController:
				return node as TrackCarController
	return TrackCarController.new()


func _ready() -> void:
	Config.ensure_actions()
	add_to_group("track_runtime_car")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.45
	_visual = get_node_or_null("VisualRoot")
	_collider_debug = get_node_or_null("ColliderDebug") as MeshInstance3D
	if get_node_or_null("CollisionShape3D") == null:
		_build_visual()
	else:
		_ensure_collider_debug()


func camera_target() -> Node3D:
	var anchor := get_node_or_null("CameraAnchor")
	if anchor is Node3D:
		return anchor as Node3D
	return self


func set_character_visual(character_id: String) -> void:
	if _visual != null and _visual.has_method("set_character_visual"):
		_visual.call("set_character_visual", character_id)


func set_player_accent(color: Color) -> void:
	if _visual != null and _visual.has_method("set_player_accent"):
		_visual.call("set_player_accent", color)


func set_collider_visible(on: bool) -> void:
	if _collider_debug != null:
		_collider_debug.visible = on


func _ensure_collider_debug() -> void:
	if _collider_debug == null:
		return
	if _collider_debug.mesh != null:
		return
	var box := BoxMesh.new()
	box.size = VisualConfig.COLLIDER_SIZE
	_collider_debug.mesh = box
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.45, 0.12, 0.28)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_collider_debug.set_surface_override_material(0, mat)


func reset_to(xform: Transform3D) -> void:
	global_transform = xform
	velocity = Vector3.ZERO
	_steer_smoothed = 0.0
	slip_amount = 0.0
	drift_amount = 0.0
	drift_state = STATE_GRIP
	_wheel_spin = 0.0
	boost_active = false
	_boost_timer = 0.0
	if _visual != null and _visual.has_method("reset_motion"):
		_visual.call("reset_motion")


func boost_time_left() -> float:
	return _boost_timer


func planar_speed() -> float:
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	return planar.length()


func apply_track_boost(direction: Vector3, magnitude: float) -> void:
	## Time-bounded extra along-track accel. Piece-forward, planarized.
	## Re-entry while the pulse is active is ignored (no stacking).
	## Wrong-way / reverse entry never accelerates against facing.
	if _boost_timer > Config.BOOST_RETRIGGER_LOCK:
		return
	var d := direction
	d.y = 0.0
	if d.length() < 0.001:
		d = -global_transform.basis.z
		d.y = 0.0
	d = d.normalized()
	var chassis_f := -global_transform.basis.z
	chassis_f.y = 0.0
	if chassis_f.length() > 0.001:
		chassis_f = chassis_f.normalized()
	var dot_forward: float = d.dot(chassis_f)
	if dot_forward < Config.BOOST_MIN_FORWARD_DOT:
		print("[TRACK_BOOST] SKIP_WRONG_WAY controller=BASELINE dot_forward=%.3f" % dot_forward)
		return
	_boost_dir = d
	_boost_mag = clampf(magnitude, 0.2, 2.5)
	_boost_timer = Config.BOOST_DURATION
	boost_active = true
	boost_apply_count += 1
	print("[TRACK_BOOST] APPLY controller=BASELINE mag=%.2f speed=%.2f" % [_boost_mag, planar_speed()])


func speed_kph() -> float:
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	return planar.length() * 3.6


func _physics_process(delta: float) -> void:
	if not control_enabled:
		if not is_on_floor():
			velocity.y -= Config.GRAVITY * delta
		move_and_slide()
		if _visual != null and _visual.has_method("apply_motion"):
			_visual.call("apply_motion", 0.0, 0.0, delta)
		else:
			_update_visuals(delta, 0.0)
		return
	var steer_target := Input.get_axis("track_left", "track_right")
	var throttle := Input.get_action_strength("track_accel")
	var brake := Input.get_action_strength("track_brake")
	var handbrake := Input.get_action_strength("track_drift")
	if use_scripted_input:
		steer_target = scripted_steer
		throttle = scripted_throttle
		brake = scripted_brake
		handbrake = 0.0
	_steer_smoothed = Handling.smooth_axis(_steer_smoothed, steer_target, Config.STEER_RESPONSE, delta)
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.001:
		forward = Vector3(0, 0, -1)
	else:
		forward = forward.normalized()
	var right := global_transform.basis.x
	right.y = 0.0
	if right.length() < 0.001:
		right = Vector3(1, 0, 0)
	else:
		right = right.normalized()
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var along := planar.dot(forward)
	var lateral := planar.dot(right)
	var speed := planar.length()
	var grounded := is_on_floor()
	if not grounded:
		drift_state = STATE_AIRBORNE
		drift_amount = move_toward(drift_amount, 0.0, delta * Config.DRIFT_RECOVERY_RATE)
	else:
		var want := Handling.wants_drift(speed, _steer_smoothed, brake, handbrake, Config.DRIFT_ENTRY_SPEED, Config.DRIFT_STEER_THRESHOLD)
		if want:
			drift_amount = move_toward(drift_amount, 1.0, delta * Config.DRIFT_ENTRY_RATE)
		else:
			drift_amount = move_toward(drift_amount, 0.0, delta * Config.DRIFT_RECOVERY_RATE)
		drift_state = STATE_DRIFT if drift_amount > 0.25 else STATE_GRIP
	var grip := lerpf(Config.LATERAL_GRIP, Config.DRIFT_GRIP, drift_amount)
	if grounded and Handling.is_countersteer(_steer_smoothed, lateral):
		grip = lerpf(grip, Config.DRIFT_COUNTERSTEER_GRIP, clampf(drift_amount, 0.0, 1.0))
	if not grounded:
		grip = 0.0
	var yaw := 0.0
	if grounded and absf(along) > 0.2:
		var authority := Handling.steer_authority(along, Config.STEER_LOW, Config.STEER_HIGH, Config.STEER_SPEED_REF)
		authority *= lerpf(1.0, Config.DRIFT_YAW_MULTIPLIER, drift_amount)
		yaw = -_steer_smoothed * authority * signf(along)
	if grounded and drift_amount < 0.15 and absf(_steer_smoothed) < 0.08 and speed > 1.0:
		var vel_yaw := atan2(planar.x, planar.z) - atan2(forward.x, forward.z)
		while vel_yaw > PI:
			vel_yaw -= TAU
		while vel_yaw < -PI:
			vel_yaw += TAU
		yaw += clampf(-vel_yaw * Config.YAW_DAMPING, -2.2, 2.2)
	rotate_y(yaw * delta)
	forward = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	right = global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	planar = Vector3(velocity.x, 0.0, velocity.z)
	along = planar.dot(forward)
	lateral = planar.dot(right)
	if grounded:
		lateral = Handling.damp_lateral(lateral, grip, delta)
		var aligned := forward * along
		var mix := 1.0 - exp(-Config.VELOCITY_ALIGN * delta)
		mix *= lerpf(1.0, Config.DRIFT_ALIGN_SCALE, drift_amount)
		var redirected: Vector3 = planar.lerp(aligned, mix)
		along = redirected.dot(forward)
		lateral = redirected.dot(right)
		lateral = Handling.damp_lateral(lateral, grip, delta)
		lateral = Handling.clamp_slip_lateral(along, lateral, Config.DRIFT_MAX_SLIP_ANGLE)
	along += Handling.accel_delta(along, throttle, Config.ACCEL, Config.MAX_SPEED, Config.HIGH_SPEED_ACCEL_SCALE, delta)
	if _boost_timer > 0.0:
		along += Config.ACCEL * Config.BOOST_ACCEL_SCALE * _boost_mag * delta
		_boost_timer -= delta
		if _boost_timer <= 0.0:
			boost_active = false
			_boost_timer = 0.0
			print("[TRACK_BOOST] END")
	var brake_for_stop := brake
	if drift_amount > 0.4:
		brake_for_stop *= 0.35
	along += Handling.brake_or_reverse_delta(along, brake_for_stop, Config.BRAKE, Config.REVERSE_ACCEL, Config.REVERSE_ENTER_SPEED, delta)
	if throttle <= 0.0 and brake <= 0.0 and drift_amount < 0.2:
		along = move_toward(along, 0.0, Config.COAST_FRICTION * delta)
	along = move_toward(along, 0.0, Config.LINEAR_DRAG * absf(along) * delta)
	var speed_cap := Config.MAX_SPEED
	if boost_active:
		speed_cap = Config.MAX_SPEED * Config.BOOST_OVERSPEED
	along = clampf(along, -Config.REVERSE_MAX, speed_cap)
	var next := forward * along + right * lateral
	velocity.x = next.x
	velocity.z = next.z
	if not grounded:
		velocity.y -= Config.GRAVITY * delta
	else:
		floor_snap_length = 0.45 + clampf(speed / Config.MAX_SPEED, 0.0, 1.0) * Config.DOWNFORCE * 0.06
		if velocity.y < 0.0:
			velocity.y = 0.0
	move_and_slide()
	if get_slide_collision_count() > 0:
		var after := Vector3(velocity.x, 0.0, velocity.z)
		var f2 := -global_transform.basis.z
		f2.y = 0.0
		f2 = f2.normalized()
		var r2 := global_transform.basis.x
		r2.y = 0.0
		r2 = r2.normalized()
		var lat2 := after.dot(r2)
		lat2 = Handling.damp_lateral(lat2, Config.COLLISION_LATERAL_DAMP, delta)
		var along2 := after.dot(f2)
		var recovered := f2 * along2 + r2 * lat2
		velocity.x = recovered.x
		velocity.z = recovered.z
	slip_amount = Handling.slip_ratio(along, lateral)
	debug_slip_angle = Handling.slip_angle(along, lateral)
	debug_speed = speed
	debug_along = along
	debug_lateral = lateral
	debug_steer = _steer_smoothed
	debug_throttle = throttle
	debug_brake = brake
	debug_handbrake = handbrake
	debug_grip = grip
	debug_yaw_rate = yaw
	debug_grounded = grounded
	debug_grounded_n = 4 if grounded else 0
	debug_airborne = not grounded
	_refresh_jeffrey_debug_state()
	if _visual != null and _visual.has_method("apply_motion"):
		_visual.call("apply_motion", _steer_smoothed, along, delta)
	else:
		_update_visuals(delta, _steer_smoothed)


func _refresh_jeffrey_debug_state() -> void:
	var gp := global_position
	var vel := velocity
	jeffrey_debug_state = {
		"speed": debug_speed,
		"velocity": [vel.x, vel.y, vel.z],
		"RPM": "UNAVAILABLE",
		"steering": debug_steer,
		"throttle": debug_throttle,
		"brake": debug_brake,
		"grounded": debug_grounded,
		"slip_angle": debug_slip_angle,
		"fuel": "UNAVAILABLE",
		"position": [gp.x, gp.y, gp.z],
		"basis_forward": [-global_transform.basis.z.x, -global_transform.basis.z.y, -global_transform.basis.z.z],
		"yaw_rate": debug_yaw_rate if "debug_yaw_rate" in self else "UNAVAILABLE",
		"mutating": false,
	}


func _update_visuals(delta: float, steer: float) -> void:
	_wheel_spin += debug_along * delta * 1.8
	for wheel in _front_wheels:
		if wheel == null:
			continue
		wheel.rotation.y = -steer * 0.42
		wheel.rotation.x = _wheel_spin
	if _body_mesh != null:
		var roll := -steer * (0.08 + drift_amount * 0.12)
		_body_mesh.rotation.z = lerp_angle(_body_mesh.rotation.z, roll, clampf(delta * 8.0, 0.0, 1.0))


func _build_visual() -> void:
	_body_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.7, 0.55, 3.2)
	_body_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#c45a2e")
	_body_mesh.set_surface_override_material(0, mat)
	_body_mesh.position = Vector3(0, 0.45, 0)
	add_child(_body_mesh)
	var cabin := MeshInstance3D.new()
	var cab := BoxMesh.new()
	cab.size = Vector3(1.3, 0.45, 1.4)
	cabin.mesh = cab
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("#1a1e24")
	cabin.set_surface_override_material(0, glass)
	cabin.position = Vector3(0, 0.85, 0.2)
	add_child(cabin)
	_add_wheel(Vector3(-0.78, 0.28, -1.05), true)
	_add_wheel(Vector3(0.78, 0.28, -1.05), true)
	_add_wheel(Vector3(-0.78, 0.28, 1.05), false)
	_add_wheel(Vector3(0.78, 0.28, 1.05), false)
	var shape := CollisionShape3D.new()
	var cap := BoxShape3D.new()
	cap.size = Vector3(1.7, 0.8, 3.2)
	shape.shape = cap
	shape.position = Vector3(0, 0.5, 0)
	add_child(shape)


func _add_wheel(pos: Vector3, front: bool) -> void:
	var wheel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.28
	cyl.height = 0.22
	cyl.radial_segments = 10
	wheel.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#1a1a1a")
	wheel.set_surface_override_material(0, mat)
	wheel.position = pos
	wheel.rotation_degrees.z = 90.0
	add_child(wheel)
	if front:
		_front_wheels.append(wheel)
