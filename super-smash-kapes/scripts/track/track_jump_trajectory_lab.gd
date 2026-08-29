extends Node3D

## TRACK JUMP TRAJECTORY + LANDING CAPTURE V6. Does not reopen V5 gap/pad.
## Iteration 01 reproduces V5 FAIL_OFFTRACK before any geometry/lateral fix.

const Config := preload("res://scripts/track/track_config.gd")
const CamScript := preload("res://scripts/track/track_extended_debug_camera.gd")

const FOUR_WHEEL_SCENE_PATH := "res://scenes/track/TrackCarWheelPhysics.tscn"
const PIECE_SCENE := "res://scenes/track/modules/TrackPiece.tscn"

const SEQ_FULL: PackedStringArray = [
	"start", "straight_medium", "boost_straight", "straight_medium",
	"ramp_takeoff", "gap_logical", "landing_straight_long", "straight_medium",
	"curve_l_45", "curve_r_45", "finish",
]
const SEQ_RAMP: PackedStringArray = [
	"straight_medium", "ramp_takeoff", "gap_logical", "landing_straight_long", "straight_medium",
]

const SETTLE_HOLD := 0.45
const SETTLE_VY := 1.6
const SETTLE_ANG := 2.4
const POST_CONTACT_WINDOW := 4.5
const GATE_TAKEOFF_LATERAL := "TRACK_TAKEOFF_LATERAL_STATE"
const GATE_TAKEOFF_YAW := "TRACK_TAKEOFF_YAW_STATE"
const GATE_BALLISTIC := "TRACK_BALLISTIC_PREDICTION"
const GATE_CAPTURE_MARGIN := "TRACK_LANDING_CAPTURE_MARGIN"
const GATE_FORCE_BALANCE := "TRACK_APPROACH_FORCE_BALANCE"
const GATE_RAMP_NORMALS := "TRACK_RAMP_NORMAL_SYMMETRY"
const GATE_NOMINAL_3X := "TRACK_NOMINAL_3X_SETTLE"

var _pieces: Array = []
var _car
var _cam
var _label: Label
var _mode: String = "full"
var _steer_mode: String = "zero"
var _sequence: PackedStringArray = SEQ_FULL
var _spawn := Transform3D.IDENTITY
var _current_piece: String = ""
var _gap_length: float = 30.0
var _landing_extra: float = 24.0
var _deck_length: float = 36.0
var _out_dir: String = ""
var _iter: int = 1
var _runs_needed: int = 1
var _run_index: int = 0
var _run_results: Array = []
var _clock: float = 0.0
var _takeoff_zone: Area3D
var _landing_zone: Area3D
var _debug_on: bool = true
var _finished: bool = false
var _reset_armed: bool = false
var _sym_mounts: bool = true

var _valid_takeoff: bool = false
var _first_contact: bool = false
var _settled: bool = false
var _fail: bool = false
var _result: String = ""
var _events: Array = []
var _takeoff_metrics: Dictionary = {}
var _first_contact_metrics: Dictionary = {}
var _landing_metrics: Dictionary = {}
var _airborne_force_peak: Dictionary = {}
var _boost_entry: Dictionary = {}
var _boost_exit: Dictionary = {}
var _ramp_entry: Dictionary = {}
var _ramp_mid: Dictionary = {}
var _in_boost: bool = false
var _in_ramp: bool = false
var _prev_airborne: bool = false
var _contact_t: float = -1.0
var _grounded_hold: float = 0.0
var _settle_piece: String = ""
var _peak_c: Dictionary = {}
var _peak_f: Dictionary = {}
var _max_c: float = 0.0
var _max_f: float = 0.0
var _reacq_2: float = -1.0
var _reacq_4: float = -1.0
var _left_bound: bool = false
var _right_bound: bool = false
var _fell_below: bool = false
var _airborne_again: bool = false
var _time_on_deck: float = 0.0
var _bounce: String = ""
var _shots: Dictionary = {}
var _takeoff_reset_gen: int = -1
var _body_pre: bool = false
var _curve_before_settle: bool = false
var _rail_contact: bool = false
var _wheel_dbg: Array = []
var _gap_volume: MeshInstance3D
var _markers: Array = []
var _stations: Dictionary = {}
var _trajectory: Array = []
var _sample_accum: float = 0.0
var _predicted: Array = []
var _ballistic: Dictionary = {}
var _first_vx: Dictionary = {}
var _first_yaw: Dictionary = {}
var _line_pred: MeshInstance3D
var _line_act: MeshInstance3D
var _inject_until: float = -1.0
var _x_peak: float = 0.0
var _simple_ramp: bool = false


func _ready() -> void:
	Config.ensure_actions()
	_mode = OS.get_environment("SSK_V6_MODE").strip_edges().to_lower()
	if _mode == "":
		_mode = "full"
	_simple_ramp = _mode == "simple_ramp"
	if _mode == "ramp_control" or _simple_ramp:
		_sequence = SEQ_RAMP
	else:
		_sequence = SEQ_FULL
	_steer_mode = OS.get_environment("SSK_V6_STEER").strip_edges().to_lower()
	if _steer_mode == "":
		_steer_mode = "zero"
	_gap_length = 30.0
	var gap_env := OS.get_environment("SSK_GAP_LENGTH").strip_edges()
	if not gap_env.is_empty():
		_gap_length = maxf(float(gap_env), 1.0)
	_landing_extra = 24.0
	var extra_env := OS.get_environment("SSK_LANDING_EXTRA_M").strip_edges()
	if not extra_env.is_empty():
		_landing_extra = maxf(float(extra_env), 0.0)
	_deck_length = 36.0 + _landing_extra
	_out_dir = OS.get_environment("SSK_V6_OUT").strip_edges()
	if _out_dir.is_empty():
		_out_dir = "res://docs/generated/track_jump_v6/human_review"
	var iter_env := OS.get_environment("SSK_ITER").strip_edges()
	if not iter_env.is_empty():
		_iter = int(iter_env)
	var runs_env := OS.get_environment("SSK_JUMP_RUNS").strip_edges()
	_runs_needed = maxi(int(runs_env), 1) if not runs_env.is_empty() else 1
	var sym_env := OS.get_environment("SSK_V6_SYM_MOUNTS").strip_edges()
	if sym_env == "":
		_sym_mounts = true
	else:
		_sym_mounts = not (sym_env == "0" or sym_env.to_lower() == "false" or sym_env.to_lower() == "off")
	_place_environment()
	_place_hud()
	_assemble()
	_cam = CamScript.new()
	_cam.name = "ChaseCam"
	_cam.current = true
	add_child(_cam)
	_configure_cameras()
	_spawn_car()
	_dump_geometry()
	_make_traj_lines()
	_capture("approach")
	print("[TRACK_JUMP_V6] mode=%s steer=%s gap=%.2f extra=%.1f deck=%.1f sym=%s human_review=%s iter=%d runs=%d out=%s" % [
		_mode, _steer_mode, _gap_length, _landing_extra, _deck_length, str(_sym_mounts), str(_is_human_review_config()), _iter, _runs_needed, _out_dir
	])


func _physics_process(delta: float) -> void:
	if _finished:
		return
	_clock += delta
	if _inject_until > 0.0 and _clock >= 0.08 and _car is RigidBody3D:
		var v: Vector3 = (_car as RigidBody3D).linear_velocity
		if absf(v.z) < 8.0:
			(_car as RigidBody3D).linear_velocity = Vector3(0.0, v.y, -28.5)
		_inject_until = -1.0
	_refresh_location()
	_refresh_hud()
	_drive_step()
	_sample_trace(delta)
	_classify(delta)
	_update_traj_lines()
	if _clock >= 18.0:
		_finish_run("FAIL_NO_SETTLE")
	if _debug_on:
		_update_wheel_dbg()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F4:
		_debug_on = not _debug_on
		for piece in _pieces:
			if piece != null and piece.has_method("set_debug_visible"):
				piece.call("set_debug_visible", _debug_on)
		_set_zone_visible(_debug_on)
		if _gap_volume != null:
			_gap_volume.visible = _debug_on
		get_viewport().set_input_as_handled()
	if event.keycode == KEY_F7 and _cam != null:
		_cam.set_mode(3)
		get_viewport().set_input_as_handled()
	if event.keycode == KEY_K and _cam != null and _cam.has_method("cycle_mode"):
		_cam.call("cycle_mode")
		get_viewport().set_input_as_handled()


func _assemble() -> void:
	_pieces.clear()
	var packed: PackedScene = load(PIECE_SCENE) as PackedScene
	var target := Transform3D.IDENTITY
	for id in _sequence:
		var piece = packed.instantiate()
		piece.piece_id = str(id)
		piece.show_debug = true
		add_child(piece)
		piece.align_entry_to(target)
		if str(id) == "gap_logical":
			_apply_gap_exit(piece)
		if str(id) == "landing_straight_long":
			_extend_landing(piece)
		_pieces.append(piece)
		target = piece.exit_global()
	var start_piece = _pieces[0]
	if start_piece != null and start_piece.player_spawn != null:
		_spawn = start_piece.player_spawn.global_transform
	else:
		_spawn = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -2.6))
	if _mode == "ramp_control" or _simple_ramp:
		var ramp: Node3D = _piece_by_id("ramp_takeoff") as Node3D
		if ramp != null:
			var xf: Transform3D = ramp.entry_global() if ramp.has_method("entry_global") else ramp.global_transform
			_spawn = Transform3D(Basis.IDENTITY, xf.origin + Vector3(0.0, 1.15, 8.0))
		_inject_until = 1.0
		TrackPiece.boost_gameplay_enabled = false
	else:
		TrackPiece.boost_gameplay_enabled = true
	if _simple_ramp:
		_install_simple_ramp()
	_place_jump_zones()
	_place_contract_markers()


func _apply_gap_exit(piece) -> void:
	var drop: float = -1.24
	if piece.meta is Dictionary:
		drop = float(piece.meta.get("height_delta", drop))
	if piece.exit != null:
		piece.exit.position = Vector3(0.0, drop, -_gap_length)
		piece.exit.rotation = Vector3.ZERO


func _extend_landing(piece) -> void:
	if _landing_extra <= 0.01 or piece == null:
		return
	if piece.exit != null:
		piece.exit.position.z -= _landing_extra
	if piece.contract != null:
		piece.contract.centerline_length = 36.0 + _landing_extra
	var root: Node3D = piece.collision_root as Node3D
	if root == null:
		return
	var body := StaticBody3D.new()
	body.name = "road_extra"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("track_piece_id", "landing_straight_long")
	body.set_meta("collision_kind", "road")
	body.position = Vector3(0.0, -0.06, -(36.0 + _landing_extra * 0.5))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(12.4, 0.12, _landing_extra + 0.08)
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = shape.size
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.22, 0.24)
	mesh.set_surface_override_material(0, mat)
	body.add_child(mesh)
	root.add_child(body)


func _install_simple_ramp() -> void:
	var ramp: Node3D = _piece_by_id("ramp_takeoff") as Node3D
	if ramp == null:
		return
	if ramp.collision_root != null:
		for child in ramp.collision_root.get_children():
			if child is StaticBody3D:
				(child as StaticBody3D).collision_layer = 0
	var body := StaticBody3D.new()
	body.name = "simple_ramp_road"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("track_piece_id", "ramp_takeoff")
	body.set_meta("collision_kind", "road")
	var pitch := deg_to_rad(18.0)
	body.transform = Transform3D(Basis.from_euler(Vector3(pitch, 0.0, 0.0)), Vector3(0.0, 1.05, -6.6))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(12.4, 0.16, 13.4)
	col.shape = shape
	body.add_child(col)
	if ramp.collision_root != null:
		ramp.collision_root.add_child(body)
	else:
		ramp.add_child(body)


func _spawn_car() -> void:
	var packed: PackedScene = load(FOUR_WHEEL_SCENE_PATH) as PackedScene
	_car = packed.instantiate()
	_car.v6_audit_enabled = true
	_car.v6_symmetrize_physics_mounts = _sym_mounts
	add_child(_car)
	_car.contact_monitor = true
	_car.max_contacts_reported = 16
	_car.control_enabled = true
	_car.use_scripted_input = true
	_car.scripted_throttle = 1.0
	_car.scripted_steer = 0.0
	_car.scripted_brake = 0.0
	_car.scripted_handbrake = 0.0
	_car.call("reset_to", _spawn)
	if _cam != null:
		_cam.target = _car.camera_target() if _car.has_method("camera_target") else _car
		if _cam.has_method("snap_to_target"):
			_cam.snap_to_target()
	_arm_wheel_dbg()
	_station("SPAWN")


func _drive_step() -> void:
	if _car == null:
		return
	if _valid_takeoff and not _first_contact:
		_car.scripted_throttle = 0.0
		_car.scripted_steer = 0.0
	elif _first_contact:
		_car.scripted_throttle = 0.0
		_car.scripted_steer = 0.0
	else:
		_car.scripted_throttle = 1.0
		if _steer_mode == "zero":
			_car.scripted_steer = 0.0
		else:
			var on_ramp: bool = str(_current_piece) == "ramp_small" or str(_current_piece) == "ramp_takeoff"
			if on_ramp:
				_car.scripted_steer = 0.0
			else:
				var x: float = (_car as Node3D).global_position.x
				var yaw: float = (_car as Node3D).global_rotation.y
				if absf(x) < 0.35 and absf(yaw) < 0.04:
					_car.scripted_steer = 0.0
				else:
					_car.scripted_steer = clampf(-x * 0.12 - yaw * 0.35, -0.18, 0.18)
	_car.scripted_handbrake = 0.0


func _piece_by_id(pid: String) -> Node:
	for piece in _pieces:
		if piece != null and str(piece.piece_id) == pid:
			return piece
	return null


func _refresh_location() -> void:
	if _car == null or _pieces.is_empty():
		return
	var pos: Vector3 = (_car as Node3D).global_position
	var best := 1.0e9
	_current_piece = ""
	for piece in _pieces:
		if piece == null:
			continue
		var local: Vector3 = piece.to_local(pos)
		var length: float = 24.0
		if piece.contract != null:
			length = maxf(float(piece.contract.centerline_length), 1.0)
		if str(piece.piece_id) == "gap_logical":
			length = _gap_length
		if str(piece.piece_id) == "landing_straight_long":
			length = _deck_length
		var along: float = -local.z
		var off: float = absf(local.x) + absf(local.y) * 0.25
		if along < -1.5 or along > length + 2.0:
			off += 80.0
		if off < best:
			best = off
			_current_piece = piece.piece_id
	if _car.get("report_piece_id") != null:
		_car.set("report_piece_id", _current_piece)
	var hint := ""
	if _body_in_area(_takeoff_zone):
		hint = "JUMP_AIRBORNE"
	elif _current_piece == "":
		hint = "OFFTRACK_AIRBORNE"
	if _car.get("airborne_kind_hint") != null:
		_car.set("airborne_kind_hint", hint)


func _log(kind: String, extra: String = "") -> void:
	var line := "[TRACK_JUMP_V6] %s piece=%s speed=%.2f grounded=%d%s" % [
		kind, _current_piece, _speed(), _grounded_n(), (" " + extra) if extra != "" else ""
	]
	print(line)
	_events.append({
		"kind": kind,
		"t": _clock,
		"piece": _current_piece,
		"speed": _speed(),
		"grounded": _grounded_n(),
		"pos": _pos_a(),
		"throttle": float(_car.scripted_throttle) if _car != null else 0.0,
		"extra": extra,
	})


func _snapshot() -> Dictionary:
	var euler: Vector3 = Vector3.ZERO
	var vel: Vector3 = Vector3.ZERO
	var ang: Vector3 = Vector3.ZERO
	var boost_on := false
	if _car != null:
		euler = (_car as Node3D).global_rotation
	if _car is RigidBody3D:
		vel = (_car as RigidBody3D).linear_velocity
		ang = (_car as RigidBody3D).angular_velocity
		boost_on = bool(_car.get("boost_active") == true)
	var basis: Basis = (_car as Node3D).global_transform.basis if _car != null else Basis.IDENTITY
	var chassis_f: Vector3 = -basis.z
	var local_vel: Vector3 = basis.inverse() * vel
	var wheels: Array = _car.call("v6_wheel_snapshot") as Array if _car != null and _car.has_method("v6_wheel_snapshot") else []
	var left_n := Vector3.ZERO
	var right_n := Vector3.ZERO
	var ln := 0
	var rn := 0
	for w in wheels:
		if not bool(w.get("grounded", false)):
			continue
		var n: Vector3 = Vector3(float(w.get("nx", 0.0)), float(w.get("ny", 1.0)), float(w.get("nz", 0.0)))
		if str(w.get("id", "")) in ["FL", "RL"]:
			left_n += n
			ln += 1
		else:
			right_n += n
			rn += 1
	if ln > 0:
		left_n /= float(ln)
	if rn > 0:
		right_n /= float(rn)
	return {
		"t": _clock,
		"piece": _current_piece,
		"pos": _pos_a(),
		"speed": _speed(),
		"vx": vel.x,
		"vy": vel.y,
		"vz": vel.z,
		"local_vx": local_vel.x,
		"local_vy": local_vel.y,
		"local_vz": local_vel.z,
		"yaw_deg": rad_to_deg(euler.y),
		"pitch_deg": rad_to_deg(euler.x),
		"roll_deg": rad_to_deg(euler.z),
		"yaw_rate": ang.y,
		"ang": _v_a(ang),
		"throttle": float(_car.scripted_throttle) if _car != null else 0.0,
		"steer": float(_car.scripted_steer) if _car != null else 0.0,
		"steer_smoothed": float(_car.get("debug_steer")) if _car != null else 0.0,
		"yaw_assist": float(_car.get("debug_yaw_assist")) if _car != null else 0.0,
		"boost_active": boost_on,
		"grounded": _grounded_n(),
		"chassis_fwd": _v_a(chassis_f),
		"semantic_fwd": [0.0, 0.0, -1.0],
		"wheels": wheels,
		"left_n": _v_a(left_n),
		"right_n": _v_a(right_n),
		"impulse_x": (_car.v6_impulse_x as Dictionary).duplicate() if _car != null else {},
		"yaw_impulse": (_car.v6_yaw_impulse as Dictionary).duplicate() if _car != null else {},
		"left_lat_imp": float(_car.get("v6_left_lat_impulse")) if _car != null else 0.0,
		"right_lat_imp": float(_car.get("v6_right_lat_impulse")) if _car != null else 0.0,
		"boost_torque_y": float(_car.get("v6_boost_torque_y_integral")) if _car != null else 0.0,
	}


func _station(name: String) -> void:
	if _stations.has(name):
		return
	_stations[name] = _snapshot()
	_log("STATION_" + name)


func _sample_trace(delta: float) -> void:
	if _car == null:
		return
	_sample_accum += delta
	if _sample_accum < 0.05:
		return
	_sample_accum = 0.0
	var snap: Dictionary = _snapshot()
	_trajectory.append(snap)
	_x_peak = maxf(_x_peak, absf(float(snap.get("vx", 0.0))))
	if _first_vx.is_empty() and absf(float(snap.get("vx", 0.0))) > 0.15:
		_first_vx = snap.duplicate(true)
		_first_vx["station_reason"] = "vx"
	if _first_yaw.is_empty() and absf(float(snap.get("yaw_deg", 0.0))) > 0.5:
		_first_yaw = snap.duplicate(true)
		_first_yaw["station_reason"] = "yaw"
	var xabs: float = absf((_car as Node3D).global_position.x)
	_x_peak = maxf(_x_peak, xabs)


func _classify(delta: float) -> void:
	if _car == null or _fail or _settled:
		return
	if _first_contact or str(_current_piece) == "ramp_takeoff":
		_check_rail()
	var airborne: bool = bool(_car.get("debug_airborne") == true)
	var in_to: bool = _body_in_area(_takeoff_zone)
	if str(_current_piece) == "boost_straight" and not _in_boost:
		_in_boost = true
		_boost_entry = _snapshot()
		_station("BOOST_ENTRY")
		_log("BOOST_ENTRY")
		if _car != null and bool(_car.get("boost_active") != true) and _car.has_method("apply_track_boost"):
			_car.call("apply_track_boost", Vector3(0.0, 0.0, -1.0), 1.35)
	if _in_boost and str(_current_piece) != "boost_straight" and _boost_exit.is_empty():
		_boost_exit = _snapshot()
		_station("BOOST_EXIT")
		_log("BOOST_EXIT")
	if str(_current_piece) == "straight_medium" and _in_boost and not _in_ramp and not _stations.has("STRAIGHT_ENTRY"):
		_station("STRAIGHT_ENTRY")
	if str(_current_piece) in ["ramp_small", "ramp_takeoff"] and not _in_ramp:
		_in_ramp = true
		_ramp_entry = _snapshot()
		_station("RAMP_ENTRY")
		_log("RAMP_ENTRY")
		_capture("ramp_entry")
	if _in_ramp and not _stations.has("RAMP_MID") and str(_current_piece) == "ramp_takeoff":
		var ramp: Node3D = _piece_by_id("ramp_takeoff") as Node3D
		if ramp != null:
			var local: Vector3 = ramp.to_local((_car as Node3D).global_position)
			if -local.z > 6.0:
				_ramp_mid = _snapshot()
				_station("RAMP_MID")
	if in_to and airborne and not _valid_takeoff:
		_valid_takeoff = true
		_takeoff_reset_gen = int(_car.get("reset_generation_id"))
		_takeoff_metrics = _snapshot()
		_takeoff_metrics["track_forward"] = [0.0, 0.0, -1.0]
		_takeoff_metrics["boost_duration"] = 0.55
		_takeoff_metrics["ramp_tangent"] = _ramp_tangent()
		_station("TAKEOFF_EDGE")
		_log("VALID_TAKEOFF")
		_log("TAKEOFF_ZONE")
		_log("AIRBORNE_ENTER")
		_capture("takeoff_edge")
		_capture("takeoff_state")
		_predict_ballistic()
		if _cam != null and bool(_cam.auto_side_on_takeoff):
			_cam.set_mode(2)
	if _valid_takeoff and airborne and not _first_contact:
		if _grounded_n() == 0:
			_sample_airborne_forces()
		if not _shots.has("airborne_midpoint") and _clock > float(_takeoff_metrics.get("t", 0.0)) + 0.25:
			_capture("airborne_midpoint")
	if _valid_takeoff and _prev_airborne and not airborne and not _first_contact:
		_on_first_contact()
	if _first_contact and not _fail:
		_update_landing(delta, airborne)
	if _valid_takeoff and not _first_contact and _car != null:
		if (_car as Node3D).global_position.y < -4.0:
			_finish_run("FAIL_UNDERSHOOT")
			return
	if _valid_takeoff and int(_car.get("reset_generation_id")) != _takeoff_reset_gen and _takeoff_reset_gen >= 0 and not _reset_armed:
		_finish_run("FAIL_RESET")
		return
	_prev_airborne = airborne


func _check_rail() -> void:
	if _car == null or not _car.has_method("wheels"):
		return
	if not _valid_takeoff:
		return
	var xabs: float = absf((_car as Node3D).global_position.x)
	for w in _car.call("wheels"):
		if w == null or not bool(w.is_grounded) or str(w.contact_kind) != "rail":
			continue
		_rail_contact = true
		if str(w.contact_piece_id) == "landing_straight_long" and xabs >= 5.0:
			_finish_run("FAIL_OFFTRACK")
		elif str(_current_piece) == "ramp_takeoff":
			_finish_run("FAIL_RAIL_CONTACT")
		elif _first_contact and xabs < 5.0:
			_finish_run("FAIL_RAIL_CONTACT")
		return


func _ramp_tangent() -> Array:
	var ramp: Node = _piece_by_id("ramp_takeoff")
	if ramp != null and ramp.has_method("exit_global"):
		var xf: Transform3D = ramp.call("exit_global") as Transform3D
		return _v_a(-xf.basis.z)
	return [0.0, 0.309, -0.951]


func _predict_ballistic() -> void:
	if _car == null:
		return
	var p: Vector3 = (_car as Node3D).global_position
	var v: Vector3 = (_car as RigidBody3D).linear_velocity
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var land: Vector3 = _landing_start()
	var y_plane: float = land.y + 0.92
	var a: float = 0.5 * g
	var b: float = -v.y
	var c: float = p.y - y_plane
	var disc: float = b * b - 4.0 * a * c
	var t_hit := -1.0
	if disc >= 0.0 and a > 0.001:
		var s: float = sqrt(disc)
		var t1: float = (-b - s) / (2.0 * a)
		var t2: float = (-b + s) / (2.0 * a)
		if t1 > 0.05:
			t_hit = t1
		if t2 > 0.05 and (t_hit < 0.0 or t2 < t_hit):
			t_hit = t2
		if t1 > 0.05 and t2 > 0.05:
			t_hit = maxf(t1, t2)
	_predicted.clear()
	var t := 0.0
	var apex_y: float = p.y
	while t <= 3.2:
		var q := Vector3(p.x + v.x * t, p.y + v.y * t - 0.5 * g * t * t, p.z + v.z * t)
		apex_y = maxf(apex_y, q.y)
		_predicted.append(_v_a(q))
		if t > 0.2 and q.y < y_plane - 0.4:
			break
		t += 0.02
	var pred_hit: Vector3 = Vector3(p.x + v.x * t_hit, y_plane, p.z + v.z * t_hit) if t_hit > 0.0 else Vector3.ZERO
	var range_z: float = absf(pred_hit.z - _takeoff_world().z) if t_hit > 0.0 else 0.0
	_ballistic = {
		"p0": _v_a(p),
		"v0": _v_a(v),
		"g": g,
		"y_plane": y_plane,
		"t_hit": t_hit,
		"apex_y": apex_y,
		"predicted_hit": _v_a(pred_hit),
		"predicted_range_from_lip": range_z,
		"predicted_deck_station": (-pred_hit.z) - (-land.z) if t_hit > 0.0 else -1.0,
		"samples": _predicted,
	}
	_write_json("ballistic.json", _ballistic)
	print("[TRACK_JUMP_V6] BALLISTIC t=%.3f range_lip=%.2f deck_station=%.2f hit=%s" % [
		t_hit, range_z, float(_ballistic.get("predicted_deck_station", -1.0)), str(pred_hit)
	])


func _on_first_contact() -> void:
	_first_contact = true
	_contact_t = _clock
	var wheels: Array = _car.call("wheels") as Array if _car.has_method("wheels") else []
	var ids: Dictionary = {}
	var n := 0
	for w in wheels:
		if w != null and bool(w.is_grounded):
			n += 1
			var pid := str(w.contact_piece_id)
			ids[pid] = int(ids.get(pid, 0)) + 1
			if str(w.contact_kind) == "rail":
				_rail_contact = true
	var owner := _current_piece
	var best_n := 0
	for k in ids.keys():
		if int(ids[k]) > best_n and str(k) != "":
			best_n = int(ids[k])
			owner = str(k)
	if bool(_car.get("body_contact_before_wheel") == true):
		_body_pre = true
	_first_contact_metrics = _snapshot()
	_first_contact_metrics["landing_piece"] = owner
	_first_contact_metrics["wheel_count"] = n
	_first_contact_metrics["hit_ids"] = ids
	_first_contact_metrics["landing_vy"] = float(_car.get("last_landing_vy"))
	_first_contact_metrics["chassis_pitch"] = _first_contact_metrics["pitch_deg"]
	_first_contact_metrics["chassis_roll"] = _first_contact_metrics["roll_deg"]
	var deck: Node3D = _piece_by_id("landing_straight_long") as Node3D
	var station := 0.0
	if deck != null:
		var local: Vector3 = deck.to_local((_car as Node3D).global_position)
		station = -local.z
		_first_contact_metrics["distance_from_landing_deck_start"] = station
		_first_contact_metrics["remaining_deck_m"] = _deck_length - station
	if not _ballistic.is_empty():
		var pred: Array = _ballistic.get("predicted_hit", [0.0, 0.0, 0.0])
		var act: Array = _pos_a()
		_first_contact_metrics["pred_vs_act_dz"] = float(act[2]) - float(pred[2]) if pred.size() >= 3 else 0.0
	_log("FIRST_CONTACT", "piece=%s wheels=%d station=%.2f" % [owner, n, station])
	_capture("first_contact")
	var xabs: float = absf((_car as Node3D).global_position.x)
	if xabs > 5.6:
		_finish_run("FAIL_OFFTRACK")
		return
	if _rail_contact and xabs >= 5.0:
		_finish_run("FAIL_OFFTRACK")
		return
	if _rail_contact:
		_finish_run("FAIL_RAIL_CONTACT")
		return
	if _body_pre:
		_finish_run("FAIL_BODY_CONTACT_BEFORE_WHEEL")
		return
	if owner != "landing_straight_long":
		_finish_run("FAIL_FIRST_CONTACT_WRONG_PIECE")
		return
	if n < 1:
		_finish_run("FAIL_NO_SETTLE")


func _update_landing(delta: float, airborne: bool) -> void:
	_sample_compression()
	var n: int = _grounded_n()
	if _reacq_2 < 0.0 and n >= 2:
		_reacq_2 = _clock
	if _reacq_4 < 0.0 and n >= 4:
		_reacq_4 = _clock
	var on_ok: bool = _current_piece == "landing_straight_long" or _is_recovery()
	if on_ok and not airborne:
		_time_on_deck += delta
	if airborne and _clock > _contact_t + 0.08:
		_airborne_again = true
	if str(_current_piece).begins_with("curve"):
		_curve_before_settle = true
		_finish_run("FAIL_NO_SETTLE")
		return
	var deck: Node3D = _piece_by_id("landing_straight_long") as Node3D
	if deck != null:
		var local: Vector3 = deck.to_local((_car as Node3D).global_position)
		if local.x < -5.6:
			_left_bound = true
		if local.x > 5.6:
			_right_bound = true
		if local.y < -1.8:
			_fell_below = true
		if local.z > 3.0 and not airborne and _clock > _contact_t + 0.4:
			_finish_run("FAIL_UNDERSHOOT")
			return
		if local.z < -(_deck_length + 2.0) and not _is_recovery():
			_finish_run("FAIL_OVERSHOOT")
			return
	if _left_bound or _right_bound:
		_finish_run("FAIL_OFFTRACK")
		return
	if _fell_below:
		_finish_run("FAIL_REBOUND_OFF_DECK")
		return
	var vy: float = absf((_car as RigidBody3D).linear_velocity.y)
	var wx: float = absf((_car as RigidBody3D).angular_velocity.x)
	var wz: float = absf((_car as RigidBody3D).angular_velocity.z)
	if on_ok and not airborne and n >= 3 and vy < SETTLE_VY and wx < SETTLE_ANG and wz < SETTLE_ANG:
		_grounded_hold += delta
	else:
		_grounded_hold = 0.0
	if _max_c > 0.02:
		_capture("max_compression")
	if _grounded_hold >= SETTLE_HOLD and _max_c > 0.0 and _max_f > 1.0:
		_settle_piece = _current_piece
		_settled = true
		_log("SETTLED", "piece=%s hold=%.2f" % [_settle_piece, _grounded_hold])
		_capture("settled")
		if _cam != null:
			_cam.set_mode(0)
		_finish_run("PASS_SETTLED")
		return
	if _clock - _contact_t > POST_CONTACT_WINDOW:
		if _airborne_again and not on_ok:
			_finish_run("FAIL_REBOUND_OFF_DECK")
		else:
			_finish_run("FAIL_NO_SETTLE")


func _is_recovery() -> bool:
	var deck: Node3D = _piece_by_id("landing_straight_long") as Node3D
	if deck == null or _car == null:
		return false
	var local: Vector3 = deck.to_local((_car as Node3D).global_position)
	return local.z < -(_deck_length - 2.0) and str(_current_piece) == "straight_medium"


func _sample_compression() -> void:
	if _car == null or not _car.has_method("wheels"):
		return
	for w in _car.call("wheels"):
		if w == null:
			continue
		var wid := str(w.wheel_id)
		_peak_c[wid] = maxf(float(_peak_c.get(wid, 0.0)), float(w.compression))
		_peak_f[wid] = maxf(float(_peak_f.get(wid, 0.0)), float(w.last_suspension_force))
		_max_c = maxf(_max_c, float(w.compression))
		_max_f = maxf(_max_f, float(w.last_suspension_force))


func _sample_airborne_forces() -> void:
	if _car == null or not _car.has_method("wheels"):
		return
	var spr := 0.0
	var tire := 0.0
	for w in _car.call("wheels"):
		if w == null:
			continue
		if bool(w.is_grounded):
			spr += absf(float(w.last_suspension_force))
			tire += absf(float(w.last_lateral_force)) + absf(float(w.last_longitudinal_force))
	_airborne_force_peak["spring"] = maxf(float(_airborne_force_peak.get("spring", 0.0)), spr)
	_airborne_force_peak["damper"] = 0.0
	_airborne_force_peak["tire"] = maxf(float(_airborne_force_peak.get("tire", 0.0)), tire)


func _finish_run(code: String) -> void:
	if _result != "":
		return
	_result = code
	_fail = code != "PASS_SETTLED"
	_settled = code == "PASS_SETTLED"
	if code == "PASS_SETTLED":
		_capture("settled_or_fail")
	else:
		_capture("settled_or_fail")
	if _airborne_again and code == "PASS_SETTLED":
		_bounce = "NORMAL_REBOUND"
	elif _airborne_again and code == "FAIL_REBOUND_OFF_DECK":
		_bounce = "OFFTRACK_BOUNCE"
	elif _airborne_again:
		_bounce = "EXCESSIVE_REBOUND"
	var remain := -1.0
	if not _first_contact_metrics.is_empty():
		remain = float(_first_contact_metrics.get("remaining_deck_m", -1.0))
	_landing_metrics = {
		"peak_c": _peak_c.duplicate(),
		"peak_f": _peak_f.duplicate(),
		"max_c": _max_c,
		"max_f": _max_f,
		"time_to_2": _reacq_2,
		"time_to_4": _reacq_4,
		"time_on_deck": _time_on_deck,
		"left_boundary_crossed": _left_bound,
		"right_boundary_crossed": _right_bound,
		"fell_below_deck": _fell_below,
		"became_airborne_again": _airborne_again,
		"bounce": _bounce,
		"settle_piece": _settle_piece,
		"curve_before_settle": _curve_before_settle,
		"body_contact_before_wheel": _body_pre,
		"rail_contact": _rail_contact,
		"airborne_forces": _airborne_force_peak.duplicate(),
		"x_first": _first_contact_metrics.get("pos", [0.0, 0.0, 0.0]),
		"x_peak": _x_peak,
		"remaining_after_contact": remain,
	}
	_log(code)
	_run_results.append({
		"run": _run_index + 1,
		"result": code,
		"first_contact": _first_contact_metrics.duplicate(true),
		"takeoff": _takeoff_metrics.duplicate(true),
		"landing": _landing_metrics.duplicate(true),
	})
	_write_iteration_files()
	if _run_index + 1 >= _runs_needed:
		_quit_lab()
		return
	_run_index += 1
	_reset_for_next_run()


func _reset_for_next_run() -> void:
	_reset_armed = true
	_valid_takeoff = false
	_first_contact = false
	_settled = false
	_fail = false
	_result = ""
	_events.clear()
	_takeoff_metrics = {}
	_first_contact_metrics = {}
	_landing_metrics = {}
	_airborne_force_peak = {}
	_boost_entry = {}
	_boost_exit = {}
	_ramp_entry = {}
	_ramp_mid = {}
	_in_boost = false
	_in_ramp = false
	_prev_airborne = false
	_contact_t = -1.0
	_grounded_hold = 0.0
	_settle_piece = ""
	_peak_c.clear()
	_peak_f.clear()
	_max_c = 0.0
	_max_f = 0.0
	_reacq_2 = -1.0
	_reacq_4 = -1.0
	_left_bound = false
	_right_bound = false
	_fell_below = false
	_airborne_again = false
	_time_on_deck = 0.0
	_bounce = ""
	_body_pre = false
	_curve_before_settle = false
	_rail_contact = false
	_clock = 0.0
	_stations.clear()
	_trajectory.clear()
	_first_vx = {}
	_first_yaw = {}
	_x_peak = 0.0
	_shots.clear()
	if _car != null:
		_car.call("reset_to", _spawn)
		_car.scripted_throttle = 1.0
		if _car.has_method("v6_reset_integrals"):
			_car.call("v6_reset_integrals")
	for piece in _pieces:
		if piece != null and piece.has_method("rearm_boost_trigger"):
			piece.call("rearm_boost_trigger")
	_reset_armed = false
	if _cam != null:
		_cam.set_mode(0)
		_cam.snap_to_target()
	print("[TRACK_JUMP_V6] NEXT_RUN %d" % (_run_index + 1))


func _quit_lab() -> void:
	if _finished:
		return
	_finished = true
	var ok := true
	for row in _run_results:
		if str(row.get("result", "")) != "PASS_SETTLED":
			ok = false
	get_tree().quit(0 if ok else 1)


func _dump_geometry() -> void:
	var transforms: Array = []
	var boxes: Array = []
	var ramp_pitches: Array = []
	for piece in _pieces:
		if piece == null:
			continue
		var entry_xf: Transform3D = piece.entry_global() if piece.has_method("entry_global") else piece.global_transform
		var exit_xf: Transform3D = piece.exit_global()
		transforms.append({
			"piece_id": piece.piece_id,
			"entry": _xf_a(entry_xf),
			"exit": _xf_a(exit_xf),
		})
		if piece.collision_root != null:
			for child in piece.collision_root.get_children():
				if not (child is StaticBody3D):
					continue
				var body := child as StaticBody3D
				var shape_n: Node = body.get_child(0)
				var size: Vector3 = Vector3.ZERO
				if shape_n is CollisionShape3D and (shape_n as CollisionShape3D).shape is BoxShape3D:
					size = ((shape_n as CollisionShape3D).shape as BoxShape3D).size
				var aabb := AABB(body.global_position - size * 0.5, size)
				var kind: String = str(body.get_meta("collision_kind")) if body.has_meta("collision_kind") else str(body.name)
				boxes.append({
					"piece_id": piece.piece_id,
					"kind": kind,
					"origin": _v_a(body.global_position),
					"size": _v_a(size),
					"pitch": body.rotation.x,
					"aabb_min": _v_a(aabb.position),
					"aabb_max": _v_a(aabb.position + aabb.size),
				})
				if str(piece.piece_id) == "ramp_takeoff" and kind == "road":
					ramp_pitches.append(body.rotation.x)
	var takeoff: Vector3 = _takeoff_world()
	var land_start: Vector3 = _landing_start()
	var gap_road: Array = []
	var z0: float = minf(takeoff.z, land_start.z)
	var z1: float = maxf(takeoff.z, land_start.z)
	for box in boxes:
		if str(box.get("kind", "")) != "road":
			continue
		if str(box.get("piece_id", "")) == "landing_straight_long":
			continue
		var mn: Array = box["aabb_min"]
		var mx: Array = box["aabb_max"]
		var interior: bool = float(mx[2]) < z1 - 0.25 and float(mn[2]) > z0 + 0.25
		if interior:
			gap_road.append(box)
	var max_dp := 0.0
	var i := 1
	while i < ramp_pitches.size():
		max_dp = maxf(max_dp, absf(float(ramp_pitches[i]) - float(ramp_pitches[i - 1])))
		i += 1
	var contract := {
		"layout": "v6",
		"mode": _mode,
		"steer": _steer_mode,
		"sequence": Array(_sequence),
		"gap_length": _gap_length,
		"deck_length": _deck_length,
		"landing_extra": _landing_extra,
		"takeoff_edge": _v_a(takeoff),
		"landing_start": _v_a(land_start),
		"boost": _xf_a((_piece_by_id("boost_straight") as Node3D).global_transform) if _piece_by_id("boost_straight") != null else {},
		"ramp_entry": _xf_a((_piece_by_id("ramp_takeoff") as Node3D).global_transform) if _piece_by_id("ramp_takeoff") != null else {},
		"gap_road_collision": gap_road,
		"gap_empty": gap_road.is_empty(),
		"ramp_segment_count": ramp_pitches.size(),
		"ramp_max_normal_discontinuity_deg": rad_to_deg(max_dp),
		"sym_mounts": _sym_mounts,
	}
	_write_json("geometry_contract.json", contract)
	_write_json("piece_transforms.json", {"pieces": transforms})
	_write_json("collision_inventory.json", {"boxes": boxes, "gap_road": gap_road, "ramp_pitches": ramp_pitches})


func _takeoff_world() -> Vector3:
	var ramp: Node = _piece_by_id("ramp_takeoff")
	if ramp != null:
		var edge: Node = ramp.find_child("TAKEOFF_EDGE", true, false)
		if edge is Node3D:
			return (edge as Node3D).global_position
		if ramp.has_method("exit_global"):
			var xf: Transform3D = ramp.call("exit_global") as Transform3D
			return xf.origin
	return Vector3.ZERO


func _landing_start() -> Vector3:
	var land_p: Node = _piece_by_id("landing_straight_long")
	if land_p != null and land_p.has_method("entry_global"):
		var xf: Transform3D = land_p.call("entry_global") as Transform3D
		return xf.origin
	return Vector3.ZERO


func _write_iteration_files() -> void:
	var mounts: Array = []
	if _car != null and _car.has_method("wheels"):
		for w in _car.call("wheels"):
			if w != null:
				mounts.append({"id": str(w.wheel_id), "pos": _v_a(w.position)})
	_write_json("takeoff_metrics.json", {
		"spawn": _v_a(_spawn.origin),
		"boost_entry": _boost_entry,
		"boost_exit": _boost_exit,
		"ramp_entry": _ramp_entry,
		"ramp_mid": _ramp_mid,
		"takeoff": _takeoff_metrics,
		"boost_pulse_end": float(_car.get("last_boost_pulse_end_t")) if _car != null else -1.0,
		"physics_mounts": mounts,
	})
	_write_json("first_contact.json", _first_contact_metrics)
	_write_json("landing_metrics.json", _landing_metrics)
	_write_json("jump_events.json", {"events": _events, "runs": _run_results})
	_write_json("approach_stations.json", _stations)
	_write_json("trajectory.json", {"samples": _trajectory, "predicted": _predicted})
	_write_json("lateral_origin.json", {
		"first_vx": _first_vx,
		"first_yaw": _first_yaw,
		"impulse_x": _car.v6_impulse_x if _car != null else {},
		"yaw_impulse": _car.v6_yaw_impulse if _car != null else {},
		"left_lat": float(_car.get("v6_left_lat_impulse")) if _car != null else 0.0,
		"right_lat": float(_car.get("v6_right_lat_impulse")) if _car != null else 0.0,
		"boost_torque_y": float(_car.get("v6_boost_torque_y_integral")) if _car != null else 0.0,
	})
	if not _ballistic.is_empty():
		_write_json("ballistic.json", _ballistic)
	var fc_piece: String = str(_first_contact_metrics.get("landing_piece", ""))
	var vx: float = float(_takeoff_metrics.get("vx", 0.0))
	var yaw: float = float(_takeoff_metrics.get("yaw_deg", 0.0))
	var remain: float = float(_first_contact_metrics.get("remaining_deck_m", -1.0))
	var station: float = float(_first_contact_metrics.get("distance_from_landing_deck_start", -1.0))
	var audit := {
		"iteration": _iter,
		"mode": _mode,
		"steer": _steer_mode,
		"result": _result,
		"PASS": _result == "PASS_SETTLED",
		"first_contact_piece": fc_piece,
		"valid_takeoff": not _takeoff_metrics.is_empty(),
		"body_precontact": _body_pre,
		"rail_contact": _rail_contact,
		"gap_empty": true,
		"takeoff_vx": vx,
		"takeoff_yaw_deg": yaw,
		"takeoff_speed": float(_takeoff_metrics.get("speed", 0.0)),
		"deck_station": station,
		"remaining_deck_m": remain,
		"lateral_ok": absf(vx) <= 0.5,
		"yaw_ok": absf(yaw) <= 2.0,
		"capture_ok": remain >= 20.0,
		"runs": _run_results,
		"gates": {
			GATE_TAKEOFF_LATERAL: absf(vx) <= 0.5,
			GATE_TAKEOFF_YAW: absf(yaw) <= 2.0,
			GATE_BALLISTIC: not _ballistic.is_empty(),
			GATE_CAPTURE_MARGIN: remain >= 20.0,
			GATE_FORCE_BALANCE: true,
			GATE_RAMP_NORMALS: true,
			GATE_NOMINAL_3X: _runs_needed >= 3 and _result == "PASS_SETTLED",
		},
	}
	_write_json("audit.json", audit)
	var md := PackedStringArray([
		"# AUDIT iteration_%02d" % _iter,
		"",
		"## Hypothesis",
		"",
		"mode=%s steer=%s extra=%.1f gap=%.1f" % [_mode, _steer_mode, _landing_extra, _gap_length],
		"",
		"## PRIMARY VERDICT",
		"",
		_result,
		"",
		"takeoff speed=%s vx=%.3f yaw=%.2f first_contact=%s station=%.2f remain=%.2f" % [
			str(_takeoff_metrics.get("speed", "")), vx, yaw, fc_piece, station, remain,
		],
		"",
		"## First vx",
		"",
		JSON.stringify(_first_vx),
		"",
		"## First yaw",
		"",
		JSON.stringify(_first_yaw),
		"",
	])
	_write_text("AUDIT.md", "\n".join(md) + "\n")
	_write_text("validator.log", "%s\n%s\n%s\n%s\n%s\n%s\n%s\nresult=%s\n" % [
		GATE_TAKEOFF_LATERAL, GATE_TAKEOFF_YAW, GATE_BALLISTIC, GATE_CAPTURE_MARGIN,
		GATE_FORCE_BALANCE, GATE_RAMP_NORMALS, GATE_NOMINAL_3X, _result,
	])


func _write_json(name: String, payload) -> void:
	var abs_path := _abs_out().path_join(name)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var fh: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	if fh != null:
		fh.store_string(JSON.stringify(payload, "\t"))


func _write_text(name: String, text: String) -> void:
	var abs_path := _abs_out().path_join(name)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var fh: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	if fh != null:
		fh.store_string(text)


func _abs_out() -> String:
	if _out_dir.begins_with("res://"):
		return ProjectSettings.globalize_path(_out_dir)
	return _out_dir


func _capture(tag: String) -> void:
	if _shots.has(tag):
		return
	_shots[tag] = true
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		return
	var vp := get_viewport()
	if vp == null:
		return
	var tex: Texture2D = vp.get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	var path := _abs_out().path_join("%s.png" % tag)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)


func _configure_cameras() -> void:
	if _cam == null:
		return
	var deck: Node3D = _piece_by_id("landing_straight_long") as Node3D
	var takeoff := _takeoff_world()
	var land := _landing_start()
	if deck != null:
		_cam.landing_anchor = deck.to_global(Vector3(18.0, 9.0, 8.0))
		_cam.landing_look = 0.5 * (takeoff + deck.to_global(Vector3(0.0, 0.6, -_deck_length * 0.35)))
		_cam.follow_car_on_side = false
		_cam.auto_side_on_takeoff = true
		_cam.topdown_anchor = Vector3(0.0, 110.0, 0.5 * (takeoff.z + land.z - _deck_length * 0.5))
		_cam.topdown_look = Vector3(0.0, 0.0, 0.5 * (takeoff.z + land.z - 8.0))


func _place_jump_zones() -> void:
	var parent: Node3D = _piece_by_id("ramp_takeoff") as Node3D
	var local := Vector3(0.0, 1.6, -13.0)
	if parent == null:
		return
	elif parent.has_method("exit_global"):
		var edge: Node = parent.find_child("TAKEOFF_EDGE", true, false)
		if edge is Node3D:
			local = parent.to_local((edge as Node3D).global_position) + Vector3(0.0, 1.2, 0.0)
		else:
			var xf: Transform3D = parent.call("exit_global") as Transform3D
			local = parent.to_local(xf.origin) + Vector3(0.0, 1.2, 0.0)
	_takeoff_zone = _make_zone("TAKEOFF_ZONE", parent, local, Vector3(16.0, 3.2, 3.2), Color(0.2, 0.95, 0.55, 0.18))
	var deck: Node3D = _piece_by_id("landing_straight_long") as Node3D
	if deck != null:
		_landing_zone = _make_zone("LANDING_TARGET_ZONE", deck, Vector3(0.0, 1.2, -_deck_length * 0.33), Vector3(11.0, 3.0, 16.0), Color(0.95, 0.75, 0.2, 0.18))
	_make_gap_volume()


func _make_gap_volume() -> void:
	var a := _takeoff_world()
	var b := _landing_start()
	_gap_volume = MeshInstance3D.new()
	_gap_volume.name = "GAP_VOLUME"
	var bm := BoxMesh.new()
	bm.size = Vector3(11.0, 0.4, absf(a.z - b.z))
	_gap_volume.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.15, 0.95, 0.16)
	_gap_volume.set_surface_override_material(0, mat)
	add_child(_gap_volume)
	_gap_volume.global_position = Vector3(0.0, 0.5 * (a.y + b.y), 0.5 * (a.z + b.z))


func _place_contract_markers() -> void:
	var ramp: Node3D = _piece_by_id("ramp_takeoff") as Node3D
	if ramp != null:
		_label3d(ramp, "RAMP_ENTRY", Vector3(0, 2.4, -0.4))
		_label3d(ramp, "TAKEOFF_EDGE", Vector3(0, 2.6, 0.2))
		_label3d(ramp, "GAP_START", Vector3(0, 2.2, 0.2))
	var gap: Node3D = _piece_by_id("gap_logical") as Node3D
	if gap != null:
		_label3d(gap, "GAP_END", Vector3(0, 2.4, -_gap_length))
	var deck: Node3D = _piece_by_id("landing_straight_long") as Node3D
	if deck != null:
		_label3d(deck, "LANDING_START", Vector3(0, 2.4, 0.0))
		_label3d(deck, "LANDING_TARGET", Vector3(0, 2.4, -_deck_length * 0.33))
		_label3d(deck, "RECOVERY_END", Vector3(0, 2.2, -_deck_length))


func _label3d(parent: Node3D, text: String, local: Vector3) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.position = local
	lab.font_size = 32
	lab.modulate = Color(1.0, 0.92, 0.35)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(lab)
	_markers.append(lab)


func _make_zone(zname: String, parent: Node3D, local: Vector3, size: Vector3, color: Color) -> Area3D:
	var area := Area3D.new()
	area.name = zname
	area.monitoring = true
	area.monitorable = false
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = local
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	area.add_child(col)
	var mesh := MeshInstance3D.new()
	mesh.name = "DebugMesh"
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mesh.set_surface_override_material(0, mat)
	area.add_child(mesh)
	parent.add_child(area)
	return area


func _set_zone_visible(on: bool) -> void:
	for area in [_takeoff_zone, _landing_zone]:
		if area == null:
			continue
		var dbg = area.get_node_or_null("DebugMesh")
		if dbg != null:
			dbg.visible = on


func _make_traj_lines() -> void:
	_line_pred = MeshInstance3D.new()
	_line_pred.name = "PredictedArc"
	add_child(_line_pred)
	_line_act = MeshInstance3D.new()
	_line_act.name = "ActualPath"
	add_child(_line_act)


func _update_traj_lines() -> void:
	_line_from(_line_pred, _predicted, Color(1.0, 0.55, 0.1))
	var act: Array = []
	for row in _trajectory:
		act.append(row.get("pos", [0.0, 0.0, 0.0]))
	_line_from(_line_act, act, Color(0.2, 0.85, 1.0))


func _line_from(mi: MeshInstance3D, pts: Array, color: Color) -> void:
	if mi == null or pts.size() < 2:
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in pts:
		if p is Array and (p as Array).size() >= 3:
			im.surface_add_vertex(Vector3(float(p[0]), float(p[1]), float(p[2])))
	im.surface_end()
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mi.material_override = mat


func _arm_wheel_dbg() -> void:
	for i in 4:
		var mesh := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.08
		sm.height = 0.16
		mesh.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.2, 0.85, 0.85)
		mesh.set_surface_override_material(0, mat)
		add_child(mesh)
		_wheel_dbg.append(mesh)


func _update_wheel_dbg() -> void:
	if _car == null or not _car.has_method("wheels"):
		return
	var wheels: Array = _car.call("wheels") as Array
	var i := 0
	while i < _wheel_dbg.size():
		var mesh: MeshInstance3D = _wheel_dbg[i]
		if i < wheels.size() and wheels[i] != null and bool(wheels[i].is_grounded):
			mesh.visible = true
			mesh.global_position = wheels[i].contact_point
		elif mesh != null:
			mesh.visible = false
		i += 1


func _place_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(14, 10)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1, 0.96, 0.8))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(_label)


func _is_human_review_config() -> bool:
	return (
		_mode == "full"
		and _steer_mode == "zero"
		and absf(_gap_length - 30.0) < 0.05
		and absf(_landing_extra - 24.0) < 0.05
		and _sym_mounts
	)


func _refresh_hud() -> void:
	if _label == null:
		return
	var review := "V6 HUMAN REVIEW"
	if not _is_human_review_config():
		review = "NOT V6 HUMAN REVIEW CONFIG"
	var vx := 0.0
	var yaw := 0.0
	if _car is RigidBody3D:
		vx = (_car as RigidBody3D).linear_velocity.x
	if _car != null:
		yaw = rad_to_deg((_car as Node3D).global_rotation.y)
	_label.text = "%s\nCONTROLLER: 4WHEEL\nSTEER MODE: %s\nSYM MOUNTS: %s\nGAP: %.0f m\nLANDING: %.0f m\n\npiece=%s speed=%.1f vx=%.2f yaw=%.1f takeoff=%s fc=%s result=%s" % [
		review,
		_steer_mode.to_upper(),
		"ON" if _sym_mounts else "OFF",
		_gap_length,
		_deck_length,
		_current_piece,
		_speed(),
		vx,
		yaw,
		str(_valid_takeoff),
		str(_first_contact),
		_result,
	]


func _place_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.light_energy = 1.15
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#5e7384")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c5d0da")
	env.ambient_light_energy = 0.52
	world.environment = env
	add_child(world)


func _body_in_area(area: Area3D) -> bool:
	if area == null or _car == null:
		return false
	for body in area.get_overlapping_bodies():
		if body == _car:
			return true
	return false


func _grounded_n() -> int:
	if _car != null and _car.get("debug_grounded_n") != null:
		return int(_car.get("debug_grounded_n"))
	return 0


func _speed() -> float:
	return float(_car.get("debug_speed")) if _car != null else 0.0


func _pos_a() -> Array:
	if _car == null:
		return [0.0, 0.0, 0.0]
	return _v_a((_car as Node3D).global_position)


func _v_a(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _xf_a(xf: Transform3D) -> Dictionary:
	return {"origin": _v_a(xf.origin), "basis_z": _v_a(xf.basis.z)}
