class_name TrackWheelCar
extends RigidBody3D

## FOUR_WHEEL_TRACK_CONTROLLER_V1. Parallel R&D chassis. Not canonical.

const Config := preload("res://scripts/track/track_config.gd")
const WheelConfig := preload("res://scripts/track/track_wheel_physics_config.gd")
const Handling := preload("res://scripts/track/track_handling.gd")
const WheelScript := preload("res://scripts/track/track_arcade_wheel.gd")

const STATE_GRIP := "grip"
const STATE_DRIFT_ARMED := "drift_armed"
const STATE_DRIFT_ENTRY := "drift_entry"
const STATE_DRIFT := "drift"
const STATE_DRIFT_RECOVERY := "drift_recover"
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
var debug_slip_angle: float = 0.0
var debug_handbrake: float = 0.0
## Read-only MCP snapshot. Does not change physics.
var jeffrey_debug_state: Dictionary = {}
var debug_controller: String = "4WHEEL_V1"
var debug_yaw_assist: float = 0.0
var boost_active: bool = false
var debug_airborne: bool = false
var last_airborne_duration: float = 0.0
var last_landing_vy: float = 0.0
var last_landing_max_compression: float = 0.0
var last_landing_max_susp_force: float = 0.0
var last_landing_peak_angvel: float = 0.0
var last_airborne_reason: String = ""
var last_takeoff_piece: String = ""
var last_landing_piece: String = ""
var report_piece_id: String = ""
var report_piece_prev: String = ""
var report_piece_next: String = ""
var airborne_kind_hint: String = ""
var post_finish: bool = false
var _drift_peak_slip: float = 0.0
var _drift_hold: float = 0.0
var last_boost_dot_chassis: float = 1.0
var last_boost_dot_semantic: float = 1.0
var reset_generation_id: int = 0
var boost_generation: int = 0
var boost_apply_count: int = 0
var _boost_timer: float = 0.0
var _boost_dir: Vector3 = Vector3(0, 0, -1)
var _boost_mag: float = 1.0
var _was_airborne: bool = false
var _air_time: float = 0.0
var _air_frames: int = 0
var _gnd_frames: int = 0
var _spawn_settle_s: float = 1.25
var _reset_settle_s: float = 0.0
var _reset_context_open: bool = true
var _landing_window_s: float = -1.0
var _rest_active: bool = false
var _peak_c: Dictionary = {}
var _peak_f: Dictionary = {}
var _peak_pitch: float = 0.0
var _peak_roll: float = 0.0
var _land_vy_latch: float = 0.0
const AIR_DEBOUNCE_FRAMES := 3
const LANDING_WINDOW := 0.40

var _steer_smoothed: float = 0.0
var _wheels: Array = []
var _visual: Node = null
var _collider_debug: MeshInstance3D = null
var _throttle: float = 0.0
var _brake: float = 0.0
var _handbrake: float = 0.0
var use_scripted_input: bool = false
var scripted_throttle: float = 0.0
var scripted_steer: float = 0.0
var scripted_brake: float = 0.0
var scripted_handbrake: float = 0.0
var last_body_contact_piece: String = ""
var body_contact_before_wheel: bool = false
var last_boost_pulse_end_t: float = -1.0
var _boost_clock: float = 0.0
var v6_audit_enabled: bool = false
var v6_symmetrize_physics_mounts: bool = true
var v6_impulse_x: Dictionary = {}
var v6_yaw_impulse: Dictionary = {}
var v6_left_lat_impulse: float = 0.0
var v6_right_lat_impulse: float = 0.0
var v6_boost_torque_y_integral: float = 0.0
var last_body_contact_kind: String = ""


func _ready() -> void:
	Config.ensure_actions()
	add_to_group("track_runtime_car")
	mass = WheelConfig.MASS
	gravity_scale = 1.0
	linear_damp = WheelConfig.LINEAR_DAMP
	angular_damp = WheelConfig.ANGULAR_DAMP
	can_sleep = false
	continuous_cd = true
	collision_layer = 2
	collision_mask = 1
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = WheelConfig.CENTER_OF_MASS_OFFSET
	_visual = get_node_or_null("VisualRoot")
	_collider_debug = get_node_or_null("ColliderDebug") as MeshInstance3D
	_ensure_wheels()
	_ensure_collider_debug()
	if _visual != null:
		_visual.set("use_articulated", true)
		_visual.set("show_debug_pivots", false)
	v6_reset_integrals()


func camera_target() -> Node3D:
	var anchor := get_node_or_null("CameraAnchor")
	if anchor is Node3D:
		return anchor as Node3D
	return self


func rear_axle_midpoint_global() -> Vector3:
	if _visual != null and _visual.has_method("rear_axle_midpoint_global"):
		return _visual.call("rear_axle_midpoint_global")
	return global_position + global_transform.basis.z * 1.2


func front_axle_midpoint_global() -> Vector3:
	if _visual != null and _visual.has_method("front_axle_midpoint_global"):
		return _visual.call("front_axle_midpoint_global")
	return global_position + (-global_transform.basis.z) * 1.2


func set_character_visual(character_id: String) -> void:
	if _visual != null and _visual.has_method("set_character_visual"):
		_visual.call("set_character_visual", character_id)


func set_player_accent(color: Color) -> void:
	if _visual != null and _visual.has_method("set_player_accent"):
		_visual.call("set_player_accent", color)


func set_collider_visible(on: bool) -> void:
	if _collider_debug != null:
		_collider_debug.visible = on


func reset_to(xform: Transform3D) -> void:
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xform)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	global_transform = xform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_steer_smoothed = 0.0
	slip_amount = 0.0
	drift_amount = 0.0
	drift_state = STATE_GRIP
	for w in _wheels:
		if w != null and w.has_method("reset_contact_state"):
			w.call("reset_contact_state")
	sleeping = false
	boost_active = false
	_boost_timer = 0.0
	boost_generation += 1
	debug_airborne = false
	_was_airborne = false
	post_finish = false
	_drift_peak_slip = 0.0
	_drift_hold = 0.0
	_air_time = 0.0
	last_airborne_duration = 0.0
	last_landing_vy = 0.0
	last_landing_max_compression = 0.0
	last_landing_max_susp_force = 0.0
	last_landing_peak_angvel = 0.0
	last_airborne_reason = "RESET_SETTLE"
	reset_generation_id += 1
	_reset_settle_s = 2.0
	_reset_context_open = true
	_spawn_settle_s = 0.0
	_air_frames = 0
	_gnd_frames = 0
	_landing_window_s = -1.0
	_rest_active = false
	_peak_c.clear()
	_peak_f.clear()
	body_contact_before_wheel = false
	last_body_contact_piece = ""
	last_body_contact_kind = ""
	v6_reset_integrals()
	print("[TRACK_RESET] generation=%d reason=debug_reset from_piece=%s target_piece=%s position=%s" % [
		reset_generation_id, report_piece_id, report_piece_id, str(xform.origin)
	])
	if _visual != null and _visual.has_method("reset_motion"):
		_visual.call("reset_motion")


func boost_time_left() -> float:
	return _boost_timer


func apply_track_boost(direction: Vector3, magnitude: float) -> void:
	## Time-bounded extra drive force at chassis COM. Piece-forward, planarized.
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
	var planar := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var dot_velocity := 1.0
	if planar.length() > 0.8:
		dot_velocity = d.dot(planar.normalized())
	last_boost_dot_chassis = dot_forward
	last_boost_dot_semantic = dot_forward
	if _visual != null and _visual.has_method("semantic_forward"):
		var sem: Vector3 = _visual.call("semantic_forward")
		sem.y = 0.0
		if sem.length() > 0.001:
			last_boost_dot_semantic = d.dot(sem.normalized())
	if dot_forward < Config.BOOST_MIN_FORWARD_DOT:
		print("[TRACK_BOOST] SKIP_WRONG_WAY controller=4WHEEL dot_forward=%.3f dot_velocity=%.3f" % [
			dot_forward, dot_velocity
		])
		return
	_boost_dir = d
	_boost_mag = clampf(magnitude, 0.2, 2.5)
	_boost_timer = Config.BOOST_DURATION
	boost_active = true
	boost_apply_count += 1
	print("[TRACK_BOOST] APPLY controller=4WHEEL mag=%.2f speed=%.2f" % [_boost_mag, planar.length()])
	print("[TRACK_4WHEEL] BOOST dir=%s mag=%.2f dot_chassis=%.3f dot_semantic=%.3f" % [
		str(_boost_dir), _boost_mag, last_boost_dot_chassis, last_boost_dot_semantic
	])


func speed_kph() -> float:
	var planar := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	return planar.length() * 3.6


func v6_reset_integrals() -> void:
	v6_impulse_x = {
		"tire": 0.0, "susp": 0.0, "lat": 0.0, "long": 0.0,
		"boost": 0.0, "antiroll": 0.0, "downforce": 0.0, "rest": 0.0,
	}
	v6_yaw_impulse = {
		"tire": 0.0, "yaw_assist": 0.0, "boost": 0.0, "antiroll": 0.0,
		"air_control": 0.0, "collision": 0.0,
	}
	v6_left_lat_impulse = 0.0
	v6_right_lat_impulse = 0.0
	v6_boost_torque_y_integral = 0.0


func v6_wheel_snapshot() -> Array:
	var rows: Array = []
	for w in _wheels:
		if w == null:
			continue
		rows.append({
			"id": str(w.wheel_id),
			"x": w.position.x,
			"grounded": bool(w.is_grounded),
			"nx": w.contact_normal.x,
			"ny": w.contact_normal.y,
			"nz": w.contact_normal.z,
			"c": float(w.compression),
			"lat": float(w.last_lateral_force),
			"long": float(w.last_longitudinal_force),
			"susp": float(w.last_suspension_force),
			"steer": float(w.steer_angle),
			"piece": str(w.contact_piece_id),
			"kind": str(w.contact_kind),
			"fx": (w.last_world_susp + w.last_world_lat + w.last_world_long).x,
		})
	return rows


func wheels() -> Array:
	return _wheels


func _v6_acc(d: Dictionary, key: String, value: float) -> void:
	d[key] = float(d.get(key, 0.0)) + value


func _v6_acc_wheels(state: PhysicsDirectBodyState3D, delta: float) -> void:
	var com: Vector3 = state.transform * state.center_of_mass
	for w in _wheels:
		if w == null:
			continue
		var f: Vector3 = w.last_world_susp + w.last_world_lat + w.last_world_long
		_v6_acc(v6_impulse_x, "tire", f.x * delta)
		_v6_acc(v6_impulse_x, "susp", w.last_world_susp.x * delta)
		_v6_acc(v6_impulse_x, "lat", w.last_world_lat.x * delta)
		_v6_acc(v6_impulse_x, "long", w.last_world_long.x * delta)
		var tau: float = (w.contact_point - com).cross(f).y
		_v6_acc(v6_yaw_impulse, "tire", tau * delta)
		var wid := str(w.wheel_id)
		if wid == "FL" or wid == "RL":
			v6_left_lat_impulse += w.last_world_lat.x * delta
		else:
			v6_right_lat_impulse += w.last_world_lat.x * delta


func debug_hud_lines() -> PackedStringArray:
	var grounded_n := 0
	for w in _wheels:
		if w != null and w.is_grounded:
			grounded_n += 1
	var lines := PackedStringArray([
		"CONTROLLER  4WHEEL_V1  (F5 A/B · not canonical)",
		"VISUAL_AUTHORITY articulated",
		"VISUAL_MODE %s" % (_visual.articulation_mode_name() if _visual != null and _visual.has_method("articulation_mode_name") else "n/a"),
		"BODY_YAW %.1f" % 0.0,
		"CHASSIS_FWD %s" % str(-global_transform.basis.z.normalized()),
		"GEOMETRIC_FWD %s" % str(_visual.geometric_forward() if _visual != null and _visual.has_method("geometric_forward") else Vector3.ZERO),
		"VISUAL_FWD %s" % str(_visual.visual_forward() if _visual != null and _visual.has_method("visual_forward") else Vector3.ZERO),
		"speed     %.1f m/s  (%.0f kph)" % [debug_speed, debug_speed * 3.6],
		"yaw rate  %.2f   body slip %.2f   grounded %d/4" % [debug_yaw_rate, debug_slip_angle, grounded_n],
		"steer %.2f  thr %.2f  brk %.2f  drift %s %.2f" % [debug_steer, debug_throttle, debug_brake, drift_state, drift_amount],
		"boost %s  airborne %s  land_vy %.2f air_dt %.2f" % [
			"ACTIVE" if boost_active else "OFF",
			"YES" if debug_airborne else "NO",
			last_landing_vy,
			last_airborne_duration,
		],
		"yaw assist %.0f Nm (secondary)" % debug_yaw_assist,
	])
	if _visual != null and _visual.has_method("wheel_center_delta"):
		var deltas := PackedStringArray()
		for wid in ["FL", "FR", "RL", "RR"]:
			deltas.append("%s d=%.4f" % [wid, float(_visual.call("wheel_center_delta", wid))])
		lines.append("WHEEL_CENTER %s" % " ".join(deltas))
	for w in _wheels:
		if w != null:
			lines.append(w.debug_line())
	lines.append("WASD · Shift drift · F3 HUD · F4 collider · V visual · B boost")
	return lines


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var delta := state.step
	var throttle := 0.0
	var brake := 0.0
	var handbrake := 0.0
	var steer_target := 0.0
	if use_scripted_input:
		steer_target = scripted_steer
		throttle = scripted_throttle
		brake = scripted_brake
		handbrake = scripted_handbrake
	elif control_enabled:
		steer_target = Input.get_axis("track_left", "track_right")
		throttle = Input.get_action_strength("track_accel")
		brake = Input.get_action_strength("track_brake")
		handbrake = Input.get_action_strength("track_drift")
	_throttle = throttle
	_brake = brake
	_handbrake = handbrake
	_steer_smoothed = Handling.smooth_axis(_steer_smoothed, steer_target, WheelConfig.STEER_RESPONSE, delta)
	var forward := -state.transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.001:
		forward = Vector3(0, 0, -1)
	else:
		forward = forward.normalized()
	var right := state.transform.basis.x
	right.y = 0.0
	if right.length() < 0.001:
		right = Vector3(1, 0, 0)
	else:
		right = right.normalized()
	var planar := Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z)
	var along := planar.dot(forward)
	var lateral := planar.dot(right)
	var speed := planar.length()
	var max_steer := WheelConfig.max_steer_angle(speed)
	var steer_rad := -_steer_smoothed * max_steer
	var grounded_n := 0
	for w in _wheels:
		if w != null and w.is_grounded:
			grounded_n += 1
	_update_drift(speed, grounded_n, delta)
	var driven_n := 0
	for w in _wheels:
		if w != null and w.is_driven:
			driven_n += 1
	var engine_share := 1.0 / float(maxi(driven_n, 1))
	for w in _wheels:
		if w == null:
			continue
		w.steer_angle = steer_rad if w.is_steering else 0.0
		if w.is_front:
			w.lateral_grip = WheelConfig.FRONT_LATERAL_GRIP
			w.drift_grip_multiplier = 1.0
		else:
			w.lateral_grip = WheelConfig.REAR_LATERAL_GRIP
			w.drift_grip_multiplier = lerpf(1.0, WheelConfig.DRIFT_REAR_GRIP, drift_amount)
			if drift_amount > 0.2 and Handling.is_countersteer(_steer_smoothed, lateral):
				w.drift_grip_multiplier = lerpf(w.drift_grip_multiplier, WheelConfig.DRIFT_COUNTERSTEER_REAR_GRIP, drift_amount)
		w.step(state, delta, throttle, brake, engine_share)
	if v6_audit_enabled:
		_v6_acc_wheels(state, delta)
	_apply_antiroll(state)
	var grounded_after := 0
	for w in _wheels:
		if w != null and w.is_grounded:
			grounded_after += 1
	if grounded_after > 0:
		_apply_downforce(state, speed)
	_apply_rest_stabilization(state, speed, grounded_after)
	_scan_body_contacts(state, grounded_after)
	var yaw_assist := 0.0
	if grounded_n > 0 and control_enabled:
		var assist := WheelConfig.YAW_ASSIST_TORQUE + WheelConfig.YAW_ASSIST_DRIFT * drift_amount
		yaw_assist = -_steer_smoothed * assist * clampf(speed / 12.0, 0.0, 1.0)
		state.apply_torque(state.transform.basis.y * yaw_assist)
		if v6_audit_enabled:
			_v6_acc(v6_yaw_impulse, "yaw_assist", yaw_assist * delta)
	debug_yaw_assist = yaw_assist
	if absf(state.angular_velocity.y) > WheelConfig.MAX_YAW_RATE:
		var av := state.angular_velocity
		av.y = clampf(av.y, -WheelConfig.MAX_YAW_RATE, WheelConfig.MAX_YAW_RATE)
		state.angular_velocity = av
	if grounded_n == 0 and control_enabled:
		var air_t: float = -_steer_smoothed * WheelConfig.AIR_CONTROL * 80.0
		state.apply_torque(state.transform.basis.y * air_t)
		if v6_audit_enabled:
			_v6_acc(v6_yaw_impulse, "air_control", air_t * delta)
	if _boost_timer > 0.0:
		var boost_f: Vector3 = _boost_dir * WheelConfig.ENGINE_FORCE * 0.85 * _boost_mag
		state.apply_central_force(boost_f)
		if v6_audit_enabled:
			_v6_acc(v6_impulse_x, "boost", boost_f.x * delta)
			## Central force: no yaw torque by construction.
			v6_boost_torque_y_integral += 0.0
			_v6_acc(v6_yaw_impulse, "boost", 0.0)
		_boost_timer -= delta
		if _boost_timer <= 0.0:
			boost_active = false
			_boost_timer = 0.0
			_boost_clock += 0.0
			last_boost_pulse_end_t = _boost_clock
			print("[TRACK_4WHEEL] BOOST_PULSE_END t=%.3f" % _boost_clock)
			print("[TRACK_BOOST] END")
	grounded_n = 0
	var max_c := 0.0
	var max_f := 0.0
	for w in _wheels:
		if w != null and w.is_grounded:
			grounded_n += 1
		if w != null:
			max_c = maxf(max_c, float(w.compression))
			max_f = maxf(max_f, float(w.last_suspension_force))
	_update_airborne_reporting(state, delta, speed, grounded_n)
	debug_speed = speed
	debug_along = along
	debug_lateral = lateral
	debug_steer = _steer_smoothed
	debug_throttle = throttle
	debug_brake = brake
	debug_handbrake = handbrake
	debug_grounded = grounded_n > 0
	debug_grounded_n = grounded_n
	debug_yaw_rate = state.angular_velocity.y
	debug_slip_angle = Handling.slip_angle(along, lateral)
	slip_amount = Handling.slip_ratio(along, lateral)
	debug_grip = lerpf(WheelConfig.REAR_LATERAL_GRIP, WheelConfig.REAR_LATERAL_GRIP * WheelConfig.DRIFT_REAR_GRIP, drift_amount)
	_boost_clock += delta
	_refresh_jeffrey_debug_state()
	_apply_visuals(delta)


func _refresh_jeffrey_debug_state() -> void:
	var gp := global_position
	var vel := linear_velocity
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
		"yaw_rate": debug_yaw_rate,
		"drift_state": drift_state,
		"mutating": false,
	}


func _update_airborne_reporting(state: PhysicsDirectBodyState3D, delta: float, speed: float, grounded_n: int) -> void:
	## Event/state reporting only. Tire forces already used exact contacts this step.
	if _spawn_settle_s > 0.0:
		_spawn_settle_s -= delta
	if _reset_settle_s > 0.0:
		_reset_settle_s -= delta
	if _reset_context_open and grounded_n >= 4 and speed < 0.45 and _gnd_frames >= 8:
		_reset_context_open = false
	if _reset_context_open and _reset_settle_s <= 0.0 and _spawn_settle_s <= 0.0:
		_reset_context_open = false
	var raw_air := grounded_n == 0
	if raw_air:
		_air_frames += 1
		_gnd_frames = 0
	else:
		_gnd_frames += 1
		_air_frames = 0
	var want_air := _air_frames >= AIR_DEBOUNCE_FRAMES
	var want_gnd := _gnd_frames >= AIR_DEBOUNCE_FRAMES
	## Hard invariant: never AIRBORNE_ENTER while already airborne unless reset_to() cleared _was_airborne.
	if want_air and not _was_airborne:
		var reason := "TRACK_AIRBORNE"
		if _reset_context_open and _reset_settle_s > 0.0:
			reason = "RESET_SETTLE"
		elif _reset_context_open and _spawn_settle_s > 0.0:
			reason = "SPAWN_SETTLE"
		elif post_finish:
			reason = "POST_FINISH_RUNOFF"
		elif airborne_kind_hint != "":
			reason = airborne_kind_hint
		last_airborne_reason = reason
		last_takeoff_piece = report_piece_id
		_air_time = 0.0
		_peak_c.clear()
		_peak_f.clear()
		_peak_pitch = 0.0
		_peak_roll = 0.0
		_was_airborne = true
		debug_airborne = true
		print("[TRACK_4WHEEL] AIRBORNE_ENTER reason=%s source_piece=%s prev=%s next=%s pos=%s speed=%.1f grounded_previous=%d generation=%d" % [
			reason, report_piece_id, report_piece_prev, report_piece_next, str(global_position), speed, grounded_n, reset_generation_id
		])
		if reason == "TRACK_AIRBORNE":
			_log_airborne_geometry()
	if _was_airborne:
		_air_time += delta
		debug_airborne = true
	if want_gnd and _was_airborne:
		last_airborne_duration = _air_time
		last_landing_vy = state.linear_velocity.y
		_land_vy_latch = last_landing_vy
		last_landing_piece = report_piece_id
		_landing_window_s = LANDING_WINDOW
		_was_airborne = false
		debug_airborne = false
		print("[TRACK_4WHEEL] AIRBORNE_EXIT reason=%s landing_piece=%s pos=%s airtime=%.3f landing_vy=%.2f" % [
			last_airborne_reason, report_piece_id, str(global_position), last_airborne_duration, last_landing_vy
		])
	if not _was_airborne and not want_air:
		debug_airborne = false
	if _landing_window_s >= 0.0 or _was_airborne:
		_sample_landing_peaks(state)
	if _landing_window_s >= 0.0:
		_landing_window_s -= delta
		if _landing_window_s < 0.0:
			_emit_landing_summary()


func _log_airborne_geometry() -> void:
	print("[TRACK_AIRBORNE_GEO] piece=%s prev=%s next=%s world=%s local_hint=%s" % [
		report_piece_id, report_piece_prev, report_piece_next, str(global_position), str(to_local(global_position))
	])
	for w in _wheels:
		if w == null:
			continue
		print("[TRACK_AIRBORNE_WHEEL] id=%s grounded=%s hit=%s n=%s kind=%s piece=%s collider=%s last_kind=%s last_piece=%s last_collider=%s compression=%.3f" % [
			str(w.wheel_id),
			str(w.is_grounded),
			str(w.contact_point),
			str(w.contact_normal),
			str(w.contact_kind),
			str(w.contact_piece_id),
			str(w.contact_collider_name),
			str(w.last_contact_kind),
			str(w.last_contact_piece_id),
			str(w.last_contact_collider_name),
			float(w.compression),
		])


func _sample_landing_peaks(state: PhysicsDirectBodyState3D) -> void:
	_peak_pitch = maxf(_peak_pitch, absf(state.angular_velocity.x))
	_peak_roll = maxf(_peak_roll, absf(state.angular_velocity.z))
	for w in _wheels:
		if w == null:
			continue
		var wid := str(w.wheel_id)
		_peak_c[wid] = maxf(float(_peak_c.get(wid, 0.0)), float(w.compression))
		_peak_f[wid] = maxf(float(_peak_f.get(wid, 0.0)), float(w.last_suspension_force))
	var mc := 0.0
	var mf := 0.0
	for k in _peak_c.keys():
		mc = maxf(mc, float(_peak_c[k]))
	for k in _peak_f.keys():
		mf = maxf(mf, float(_peak_f[k]))
	last_landing_max_compression = mc
	last_landing_max_susp_force = mf
	last_landing_peak_angvel = maxf(_peak_pitch, _peak_roll)


func _emit_landing_summary() -> void:
	var peak_c: float = last_landing_max_compression
	var peak_f: float = last_landing_max_susp_force
	var settle_reason: bool = last_airborne_reason == "RESET_SETTLE" or last_airborne_reason == "SPAWN_SETTLE"
	if settle_reason:
		print("[TRACK_4WHEEL_LANDING] SKIP reason=%s generation=%d" % [last_airborne_reason, reset_generation_id])
		return
	if peak_c <= 0.001 or peak_f <= 1.0:
		print("[TRACK_4WHEEL_LANDING] NO_VALID_CONTACT takeoff_piece=%s landing_piece=%s airtime=%.3f peak_c=%.3f peak_f=%.0f" % [
			last_takeoff_piece, last_landing_piece, last_airborne_duration, peak_c, peak_f
		])
		return
	print("[TRACK_4WHEEL_LANDING] takeoff_piece=%s landing_piece=%s airtime=%.3f landing_vy=%.2f peak_c_FL=%.3f peak_c_FR=%.3f peak_c_RL=%.3f peak_c_RR=%.3f peak_f_FL=%.0f peak_f_FR=%.0f peak_f_RL=%.0f peak_f_RR=%.0f pitch_rate=%.2f roll_rate=%.2f settle_time=%.2f" % [
		last_takeoff_piece,
		last_landing_piece,
		last_airborne_duration,
		_land_vy_latch,
		float(_peak_c.get("FL", 0.0)),
		float(_peak_c.get("FR", 0.0)),
		float(_peak_c.get("RL", 0.0)),
		float(_peak_c.get("RR", 0.0)),
		float(_peak_f.get("FL", 0.0)),
		float(_peak_f.get("FR", 0.0)),
		float(_peak_f.get("RL", 0.0)),
		float(_peak_f.get("RR", 0.0)),
		_peak_pitch,
		_peak_roll,
		LANDING_WINDOW,
	])


func _scan_body_contacts(state: PhysicsDirectBodyState3D, grounded_n: int) -> void:
	var n: int = state.get_contact_count()
	if n <= 0:
		return
	for i in n:
		var obj: Object = state.get_contact_collider_object(i)
		var pid := TrackArcadeWheel._piece_id_from_collider(obj)
		if pid != "":
			last_body_contact_piece = pid
		if obj is Node and (obj as Node).has_meta("collision_kind"):
			last_body_contact_kind = str((obj as Node).get_meta("collision_kind"))
		if grounded_n == 0 and (_was_airborne or debug_airborne):
			if not body_contact_before_wheel:
				body_contact_before_wheel = true
				print("[TRACK_4WHEEL] BODY_CONTACT_BEFORE_WHEEL piece=%s collider=%s" % [
					pid, str(obj) if obj != null else ""
				])
			return


func _apply_rest_stabilization(state: PhysicsDirectBodyState3D, speed: float, grounded_n: int) -> void:
	var input_drive: bool = absf(_throttle) > WheelConfig.REST_EXIT_INPUT or absf(_brake) > WheelConfig.REST_EXIT_INPUT or _handbrake > WheelConfig.REST_EXIT_INPUT
	if input_drive or grounded_n < 4 or debug_airborne or _boost_timer > 0.0:
		_rest_active = false
		return
	var slope: bool = false
	for w in _wheels:
		if w == null or not w.is_grounded:
			continue
		if float(w.contact_normal.y) < WheelConfig.REST_SLOPE_NY_MIN:
			slope = true
			break
	if slope:
		_rest_active = false
		return
	var yaw_rate: float = state.angular_velocity.y
	if speed > WheelConfig.REST_ENTER_SPEED or absf(yaw_rate) > WheelConfig.REST_ENTER_YAW:
		_rest_active = false
		return
	_rest_active = true
	var planar := Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z)
	if planar.length() > 0.0001:
		state.apply_central_force(-planar * WheelConfig.REST_LATERAL_DAMP)
	if absf(yaw_rate) > 0.0001:
		state.apply_torque(-state.transform.basis.y * yaw_rate * WheelConfig.REST_YAW_DAMP)


func _update_drift(speed: float, grounded_n: int, delta: float) -> void:
	if grounded_n <= 0:
		drift_state = STATE_AIRBORNE
		drift_amount = move_toward(drift_amount, 0.0, delta / maxf(WheelConfig.DRIFT_RECOVERY_TIME, 0.05))
		return
	var want := Handling.wants_drift(speed, _steer_smoothed, _brake, _handbrake, WheelConfig.DRIFT_MIN_SPEED, WheelConfig.DRIFT_STEER_THRESHOLD)
	var slip := absf(debug_slip_angle)
	var yaw := absf(debug_yaw_rate)
	if want:
		_drift_hold += delta
		if slip >= WheelConfig.DRIFT_ACTIVE_SLIP or yaw >= WheelConfig.DRIFT_ACTIVE_YAW:
			if drift_state != STATE_DRIFT:
				print("[TRACK_DRIFT] DRIFT_ACTIVE speed=%.1f slip=%.2f yaw=%.2f hold=%.2f" % [speed, debug_slip_angle, debug_yaw_rate, _drift_hold])
			var entry := delta / maxf(WheelConfig.DRIFT_ENTRY_TIME, 0.05)
			drift_amount = move_toward(drift_amount, 1.0, entry)
			drift_state = STATE_DRIFT
			_drift_peak_slip = maxf(_drift_peak_slip, slip)
		else:
			if drift_state == STATE_GRIP or drift_state == STATE_DRIFT_RECOVERY:
				print("[TRACK_DRIFT] ENTER speed=%.1f slip=%.2f" % [speed, debug_slip_angle])
				print("[TRACK_DRIFT] DRIFT_ARM speed=%.1f slip=%.2f yaw=%.2f" % [speed, debug_slip_angle, debug_yaw_rate])
			drift_state = STATE_DRIFT_ARMED
			drift_amount = move_toward(drift_amount, 0.22, delta * 4.0)
	else:
		if drift_state == STATE_DRIFT or drift_state == STATE_DRIFT_ARMED:
			if _drift_peak_slip > 0.01:
				print("[TRACK_DRIFT] DRIFT_PEAK slip=%.2f duration=%.2f" % [_drift_peak_slip, _drift_hold])
			print("[TRACK_DRIFT] DRIFT_EXIT speed=%.1f slip=%.2f duration=%.2f" % [speed, debug_slip_angle, _drift_hold])
			_drift_peak_slip = 0.0
			_drift_hold = 0.0
		var rec := delta / maxf(WheelConfig.DRIFT_RECOVERY_TIME, 0.05)
		drift_amount = move_toward(drift_amount, 0.0, rec)
		if drift_amount > 0.08:
			drift_state = STATE_DRIFT_RECOVERY
		else:
			drift_state = STATE_GRIP


func _apply_antiroll(state: PhysicsDirectBodyState3D) -> void:
	if _wheels.size() < 4:
		return
	_antiroll_pair(state, _wheels[0], _wheels[1], WheelConfig.FRONT_ANTIROLL)
	_antiroll_pair(state, _wheels[2], _wheels[3], WheelConfig.REAR_ANTIROLL)


func _antiroll_pair(state: PhysicsDirectBodyState3D, left, right, stiffness: float) -> void:
	if left == null or right == null:
		return
	if not left.is_grounded or not right.is_grounded:
		return
	var diff: float = left.compression - right.compression
	var force: float = diff * stiffness
	var f_l: Vector3 = left.contact_normal * -force
	var f_r: Vector3 = right.contact_normal * force
	state.apply_force(f_l, left.contact_point - state.transform.origin)
	state.apply_force(f_r, right.contact_point - state.transform.origin)
	if v6_audit_enabled:
		var com: Vector3 = state.transform * state.center_of_mass
		_v6_acc(v6_impulse_x, "antiroll", (f_l.x + f_r.x) * state.step)
		var tau: float = (left.contact_point - com).cross(f_l).y + (right.contact_point - com).cross(f_r).y
		_v6_acc(v6_yaw_impulse, "antiroll", tau * state.step)


func _apply_downforce(state: PhysicsDirectBodyState3D, speed: float) -> void:
	var mag := WheelConfig.DOWNFORCE * speed * speed
	var f: Vector3 = -state.transform.basis.y * mag
	state.apply_central_force(f)
	if v6_audit_enabled:
		_v6_acc(v6_impulse_x, "downforce", f.x * state.step)


func _apply_visuals(delta: float) -> void:
	if _visual == null:
		return
	var states: Array = []
	for w in _wheels:
		if w == null:
			continue
		states.append({
			"id": w.wheel_id,
			"steer": w.steer_angle,
			"spin": w.spin_angle,
			"compression": w.compression,
			"length": w.suspension_length,
			"rest": w.rest_length,
			"grounded": w.is_grounded,
		})
	if _visual.has_method("apply_wheel_states"):
		_visual.call("apply_wheel_states", states, delta)
	elif _visual.has_method("apply_motion"):
		_visual.call("apply_motion", _steer_smoothed, debug_along, delta)


func _ensure_wheels() -> void:
	_wheels.clear()
	var specs := [
		{"name": "WheelPhysicsFL", "id": "FL", "front": true, "pos": WheelConfig.mount_fl()},
		{"name": "WheelPhysicsFR", "id": "FR", "front": true, "pos": WheelConfig.mount_fr()},
		{"name": "WheelPhysicsRL", "id": "RL", "front": false, "pos": WheelConfig.mount_rl()},
		{"name": "WheelPhysicsRR", "id": "RR", "front": false, "pos": WheelConfig.mount_rr()},
	]
	for spec in specs:
		var node := get_node_or_null(str(spec["name"]))
		if node == null:
			node = Node3D.new()
			node.set_script(WheelScript)
			node.name = str(spec["name"])
			add_child(node)
		var wheel = node
		if wheel == null or not wheel.has_method("setup_on_chassis"):
			continue
		wheel.wheel_id = str(spec["id"])
		wheel.is_front = bool(spec["front"])
		wheel.is_steering = bool(spec["front"])
		wheel.is_driven = WheelConfig.is_driven(WheelConfig.DRIVE_TYPE, bool(spec["front"]))
		wheel.position = spec["pos"]
		if v6_symmetrize_physics_mounts:
			var ax: float = 0.5 * (absf(WheelConfig.mount_fl().x) + absf(WheelConfig.mount_fr().x))
			var az_f: float = 0.5 * (WheelConfig.mount_fl().z + WheelConfig.mount_fr().z)
			var ax_r: float = 0.5 * (absf(WheelConfig.mount_rl().x) + absf(WheelConfig.mount_rr().x))
			var az_r: float = 0.5 * (WheelConfig.mount_rl().z + WheelConfig.mount_rr().z)
			var y: float = WheelConfig.mount_fl().y
			if str(spec["id"]) == "FL":
				wheel.position = Vector3(-ax, y, az_f)
			elif str(spec["id"]) == "FR":
				wheel.position = Vector3(ax, y, az_f)
			elif str(spec["id"]) == "RL":
				wheel.position = Vector3(-ax_r, y, az_r)
			elif str(spec["id"]) == "RR":
				wheel.position = Vector3(ax_r, y, az_r)
		if wheel.is_front:
			wheel.lateral_grip = WheelConfig.FRONT_LATERAL_GRIP
		else:
			wheel.lateral_grip = WheelConfig.REAR_LATERAL_GRIP
		wheel.setup_on_chassis(self)
		_wheels.append(wheel)


func _ensure_collider_debug() -> void:
	if _collider_debug == null:
		return
	if _collider_debug.mesh != null:
		return
	var box := BoxMesh.new()
	box.size = WheelConfig.COLLIDER_SIZE
	_collider_debug.mesh = box
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.75, 1.0, 0.28)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_collider_debug.set_surface_override_material(0, mat)
	_collider_debug.position = WheelConfig.COLLIDER_OFFSET
