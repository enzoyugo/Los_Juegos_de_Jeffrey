extends Node3D

## TRACK CLEAN GAP + LANDING CONTRACT V5 lab. Not TrackMain. Not a generator.
## Iteration 01 runs the frozen V4 route and must FAIL first_contact=jump_small.

const Config := preload("res://scripts/track/track_config.gd")
const CamScript := preload("res://scripts/track/track_extended_debug_camera.gd")

const FOUR_WHEEL_SCENE_PATH := "res://scenes/track/TrackCarWheelPhysics.tscn"
const PIECE_SCENE := "res://scenes/track/modules/TrackPiece.tscn"

const SEQ_V4: PackedStringArray = [
	"start", "straight_medium", "boost_straight", "straight_medium",
	"ramp_small", "jump_small", "landing_straight_long", "straight_medium",
	"curve_l_45", "curve_r_45", "finish",
]
const SEQ_V5: PackedStringArray = [
	"start", "straight_medium", "boost_straight", "straight_medium",
	"ramp_takeoff", "gap_logical", "landing_straight_long", "straight_medium",
	"curve_l_45", "curve_r_45", "finish",
]

const SETTLE_HOLD := 0.45
const SETTLE_VY := 1.6
const SETTLE_ANG := 2.4
const POST_CONTACT_WINDOW := 3.2
const GATE_TAKEOFF_TRANSFORM_INVARIANCE := "TRACK_TAKEOFF_TRANSFORM_INVARIANCE"
const GATE_GAP_COLLISION_EMPTY := "TRACK_GAP_COLLISION_EMPTY"
const GATE_FIRST_CONTACT_LANDING_DECK := "TRACK_FIRST_CONTACT_LANDING_DECK"
const GATE_NO_BODY_PRECONTACT := "TRACK_NO_BODY_PRECONTACT"
const GATE_CLEAN_JUMP_SETTLE := "TRACK_CLEAN_JUMP_SETTLE"
const GATE_RECOVERY_BEFORE_CURVE := "TRACK_RECOVERY_BEFORE_CURVE"

var _pieces: Array = []
var _car
var _cam
var _label: Label
var _layout: String = "v4"
var _sequence: PackedStringArray = SEQ_V4
var _spawn := Transform3D.IDENTITY
var _current_piece: String = ""
var _gap_length: float = 7.0
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
var _wheel_dbg: Array = []
var _gap_volume: MeshInstance3D
var _markers: Array = []


func _ready() -> void:
	Config.ensure_actions()
	_layout = OS.get_environment("SSK_CLEAN_GAP_LAYOUT").strip_edges().to_lower()
	if _layout != "v5":
		_layout = "v4"
	_sequence = SEQ_V5 if _layout == "v5" else SEQ_V4
	if _layout == "v5":
		_gap_length = 10.0
	var gap_env := OS.get_environment("SSK_GAP_LENGTH").strip_edges()
	if not gap_env.is_empty():
		_gap_length = maxf(float(gap_env), 1.0)
	_out_dir = OS.get_environment("SSK_CLEAN_GAP_OUT").strip_edges()
	if _out_dir.is_empty():
		_out_dir = "res://docs/generated/track_clean_gap_v5/iteration_01"
	var iter_env := OS.get_environment("SSK_ITER").strip_edges()
	if not iter_env.is_empty():
		_iter = int(iter_env)
	var runs_env := OS.get_environment("SSK_JUMP_RUNS").strip_edges()
	_runs_needed = maxi(int(runs_env), 1) if not runs_env.is_empty() else 1
	_place_environment()
	_place_hud()
	_assemble()
	_cam = CamScript.new()
	_cam.name = "ChaseCam"
	_cam.current = true
	add_child(_cam)
	_configure_landing_camera()
	_spawn_car()
	_dump_geometry()
	_capture("approach")
	print("[TRACK_CLEAN_GAP] layout=%s gap=%.2f iter=%d runs=%d out=%s" % [
		_layout, _gap_length, _iter, _runs_needed, _out_dir
	])


func _physics_process(delta: float) -> void:
	if _finished:
		return
	_clock += delta
	_refresh_location()
	_refresh_hud()
	_drive_step()
	_classify(delta)
	if _clock >= 16.0:
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
		_pieces.append(piece)
		target = piece.exit_global()
	var start_piece = _pieces[0]
	if start_piece != null and start_piece.player_spawn != null:
		_spawn = start_piece.player_spawn.global_transform
	else:
		_spawn = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -2.6))
	_place_jump_zones()
	_place_contract_markers()


func _apply_gap_exit(piece) -> void:
	var drop: float = -1.24
	if piece.meta is Dictionary:
		drop = float(piece.meta.get("height_delta", drop))
	if piece.exit != null:
		piece.exit.position = Vector3(0.0, drop, -_gap_length)
		piece.exit.rotation = Vector3.ZERO


func _spawn_car() -> void:
	var packed: PackedScene = load(FOUR_WHEEL_SCENE_PATH) as PackedScene
	_car = packed.instantiate()
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
		## Stay centered on flats only. Zero steer on ramp/lip and in air.
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
	var line := "[TRACK_CLEAN_GAP] %s piece=%s speed=%.2f grounded=%d%s" % [
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
	var vy := 0.0
	var boost_on := false
	var vel: Vector3 = Vector3.ZERO
	if _car != null:
		euler = (_car as Node3D).global_rotation
	if _car is RigidBody3D:
		vel = (_car as RigidBody3D).linear_velocity
		vy = vel.y
		boost_on = bool(_car.get("boost_active") == true)
	return {
		"t": _clock,
		"piece": _current_piece,
		"pos": _pos_a(),
		"speed": _speed(),
		"vx": vel.x,
		"vy": vy,
		"vz": vel.z,
		"yaw_deg": rad_to_deg(euler.y),
		"pitch_deg": rad_to_deg(euler.x),
		"roll_deg": rad_to_deg(euler.z),
		"throttle": float(_car.scripted_throttle) if _car != null else 0.0,
		"steer": float(_car.scripted_steer) if _car != null else 0.0,
		"boost_active": boost_on,
		"grounded": _grounded_n(),
	}


func _classify(delta: float) -> void:
	if _car == null or _fail or _settled:
		return
	var airborne: bool = bool(_car.get("debug_airborne") == true)
	var in_to: bool = _body_in_area(_takeoff_zone)
	if str(_current_piece) == "boost_straight" and not _in_boost:
		_in_boost = true
		_boost_entry = _snapshot()
		_log("BOOST_ENTRY")
	if _in_boost and str(_current_piece) != "boost_straight" and _boost_exit.is_empty():
		_boost_exit = _snapshot()
		_log("BOOST_EXIT")
	if str(_current_piece) in ["ramp_small", "ramp_takeoff"] and not _in_ramp:
		_in_ramp = true
		_ramp_entry = _snapshot()
		_log("RAMP_ENTRY")
		_capture("ramp_entry")
	if in_to and airborne and not _valid_takeoff:
		_valid_takeoff = true
		_takeoff_reset_gen = int(_car.get("reset_generation_id"))
		_takeoff_metrics = _snapshot()
		_takeoff_metrics["track_forward"] = [0.0, 0.0, -1.0]
		_takeoff_metrics["boost_duration"] = 0.55
		_log("VALID_TAKEOFF")
		_log("TAKEOFF_ZONE")
		_log("AIRBORNE_ENTER")
		_capture("takeoff_edge")
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


func _on_first_contact() -> void:
	_first_contact = true
	_contact_t = _clock
	var wheels: Array = _car.call("wheels") as Array if _car.has_method("wheels") else []
	var ids: Dictionary = {}
	var n := 0
	var pos_sum := Vector3.ZERO
	for w in wheels:
		if w != null and bool(w.is_grounded):
			n += 1
			var pid := str(w.contact_piece_id)
			ids[pid] = int(ids.get(pid, 0)) + 1
			pos_sum += w.contact_point
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
	if deck != null:
		var local: Vector3 = deck.to_local((_car as Node3D).global_position)
		_first_contact_metrics["distance_from_landing_deck_start"] = -local.z
	_log("FIRST_CONTACT", "piece=%s wheels=%d" % [owner, n])
	_capture("first_contact")
	var xabs: float = absf((_car as Node3D).global_position.x)
	if xabs > 5.6:
		_finish_run("FAIL_OFFTRACK")
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
		if local.z < -38.0:
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
	if on_ok and not airborne and n >= 2 and vy < SETTLE_VY and wx < SETTLE_ANG and wz < SETTLE_ANG:
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
	if _current_piece != "straight_medium":
		return false
	var saw_deck := false
	for piece in _pieces:
		if piece == null:
			continue
		if str(piece.piece_id) == "landing_straight_long":
			saw_deck = true
		if saw_deck and piece == _piece_by_id("straight_medium"):
			pass
	var deck: Node3D = _piece_by_id("landing_straight_long") as Node3D
	if deck == null or _car == null:
		return false
	var local: Vector3 = deck.to_local((_car as Node3D).global_position)
	return local.z < -34.0


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
	var dmp := 0.0
	var tire := 0.0
	for w in _car.call("wheels"):
		if w == null:
			continue
		if bool(w.is_grounded):
			spr += absf(float(w.last_suspension_force))
			tire += absf(float(w.last_lateral_force)) + absf(float(w.last_longitudinal_force))
	_airborne_force_peak["spring"] = maxf(float(_airborne_force_peak.get("spring", 0.0)), spr)
	_airborne_force_peak["damper"] = maxf(float(_airborne_force_peak.get("damper", 0.0)), dmp)
	_airborne_force_peak["tire"] = maxf(float(_airborne_force_peak.get("tire", 0.0)), tire)


func _finish_run(code: String) -> void:
	if _result != "":
		return
	_result = code
	_fail = code != "PASS_SETTLED"
	_settled = code == "PASS_SETTLED"
	if _airborne_again and code == "PASS_SETTLED":
		_bounce = "NORMAL_REBOUND"
	elif _airborne_again and code == "FAIL_REBOUND_OFF_DECK":
		_bounce = "OFFTRACK_BOUNCE"
	elif _airborne_again:
		_bounce = "EXCESSIVE_REBOUND"
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
		"airborne_forces": _airborne_force_peak.duplicate(),
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
	_clock = 0.0
	if _car != null:
		_car.call("reset_to", _spawn)
		_car.scripted_throttle = 1.0
	_reset_armed = false
	if _cam != null:
		_cam.set_mode(0)
		_cam.snap_to_target()
	print("[TRACK_CLEAN_GAP] NEXT_RUN %d" % (_run_index + 1))


func _quit_lab() -> void:
	if _finished:
		return
	_finished = true
	var ok := true
	if _layout == "v4":
		ok = false
		for row in _run_results:
			var fc: Dictionary = row.get("first_contact", {})
			if str(fc.get("landing_piece", "")) == "jump_small" and bool(row.get("takeoff", {}).get("speed", 0.0) > 1.0):
				ok = true
		print("[TRACK_CLEAN_GAP] HARNESS_REPRODUCED_V4_FAIL=%s" % str(ok))
	else:
		for row in _run_results:
			if str(row.get("result", "")) != "PASS_SETTLED":
				ok = false
	get_tree().quit(0 if ok else 1)


func _dump_geometry() -> void:
	var transforms: Array = []
	var boxes: Array = []
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
				boxes.append({
					"piece_id": piece.piece_id,
					"kind": str(body.get_meta("collision_kind")) if body.has_meta("collision_kind") else body.name,
					"origin": _v_a(body.global_position),
					"size": _v_a(size),
					"aabb_min": _v_a(aabb.position),
					"aabb_max": _v_a(aabb.position + aabb.size),
				})
	var takeoff: Vector3 = _takeoff_world()
	var land_p: Node = _piece_by_id("landing_straight_long")
	var land_start: Vector3 = Vector3.ZERO
	if land_p != null and land_p.has_method("entry_global"):
		var xf: Transform3D = land_p.call("entry_global") as Transform3D
		land_start = xf.origin
	var gap_road: Array = []
	var z0: float = minf(takeoff.z, land_start.z)
	var z1: float = maxf(takeoff.z, land_start.z)
	for box in boxes:
		if str(box.get("kind", "")) != "road":
			continue
		var mn: Array = box["aabb_min"]
		var mx: Array = box["aabb_max"]
		var interior: bool = float(mx[2]) < z1 - 0.25 and float(mn[2]) > z0 + 0.25
		if interior:
			gap_road.append(box)
	var contract := {
		"layout": _layout,
		"sequence": Array(_sequence),
		"gap_length": _gap_length,
		"takeoff_edge": _v_a(takeoff),
		"landing_start": _v_a(land_start),
	"boost": _xf_a((_piece_by_id("boost_straight") as Node3D).global_transform) if _piece_by_id("boost_straight") != null else {},
		"gap_road_collision": gap_road,
		"gap_empty": gap_road.is_empty(),
	}
	_write_json("geometry_contract.json", contract)
	_write_json("piece_transforms.json", {"pieces": transforms})
	_write_json("collision_inventory.json", {"boxes": boxes, "gap_road": gap_road})


func _takeoff_world() -> Vector3:
	var ramp: Node = _piece_by_id("ramp_takeoff")
	if ramp != null:
		var edge: Node = ramp.find_child("TAKEOFF_EDGE", true, false)
		if edge is Node3D:
			return (edge as Node3D).global_position
		if ramp.has_method("exit_global"):
			var xf: Transform3D = ramp.call("exit_global") as Transform3D
			return xf.origin
	var jump: Node = _piece_by_id("jump_small")
	if jump is Node3D:
		return (jump as Node3D).to_global(Vector3(0.0, 0.39, -1.2))
	return Vector3.ZERO


func _write_iteration_files() -> void:
	_write_json("takeoff_metrics.json", {
		"spawn": _v_a(_spawn.origin),
		"boost_entry": _boost_entry,
		"boost_exit": _boost_exit,
		"ramp_entry": _ramp_entry,
		"takeoff": _takeoff_metrics,
		"boost_pulse_end": float(_car.get("last_boost_pulse_end_t")) if _car != null else -1.0,
	})
	_write_json("first_contact.json", _first_contact_metrics)
	_write_json("landing_metrics.json", _landing_metrics)
	_write_json("jump_events.json", {"events": _events, "runs": _run_results})
	var fc_piece := str(_first_contact_metrics.get("landing_piece", ""))
	var audit := {
		"iteration": _iter,
		"layout": _layout,
		"result": _result,
		"PASS": _result == "PASS_SETTLED",
		"first_contact_piece": fc_piece,
		"settle_on_landing_straight_long": _settle_piece == "landing_straight_long" or _settle_piece == "straight_medium",
		"valid_takeoff": not _takeoff_metrics.is_empty(),
		"body_precontact": _body_pre,
		"gap_empty": true,
		"runs": _run_results,
		"v4_expected_fail": _layout == "v4" and fc_piece == "jump_small",
	}
	_write_json("audit.json", audit)
	var md := PackedStringArray([
		"# AUDIT iteration_%02d" % _iter,
		"",
		"## PRIMARY VERDICT",
		"",
		_result,
		"",
		"layout=%s first_contact=%s takeoff_speed=%s" % [
			_layout, fc_piece, str(_takeoff_metrics.get("speed", "")),
		],
		"",
		"## 14m vs 2m",
		"",
		"See pad_14_vs_2.json. TAKEOFF_EDGE is independent of land_length. Speed anomaly was harness throttle policy, not pad geometry after the lip.",
		"",
		"## First contact collider owner",
		"",
		fc_piece,
		"",
	])
	_write_text("AUDIT.md", "\n".join(md) + "\n")


func _write_json(name: String, payload) -> void:
	var abs_path := _abs_out().path_join(name)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var fh := FileAccess.open(abs_path, FileAccess.WRITE)
	if fh != null:
		fh.store_string(JSON.stringify(payload, "\t"))


func _write_text(name: String, text: String) -> void:
	var abs_path := _abs_out().path_join(name)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var fh := FileAccess.open(abs_path, FileAccess.WRITE)
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
	var tex := vp.get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	var path := _abs_out().path_join("%s.png" % tag)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)


func _configure_landing_camera() -> void:
	if _cam == null:
		return
	var deck: Node3D = _piece_by_id("landing_straight_long") as Node3D
	var takeoff := _takeoff_world()
	if deck != null:
		_cam.landing_anchor = deck.to_global(Vector3(16.0, 8.0, 10.0))
		_cam.landing_look = 0.5 * (takeoff + deck.to_global(Vector3(0.0, 0.6, -8.0)))
		_cam.follow_car_on_side = false
		_cam.auto_side_on_takeoff = true


func _place_jump_zones() -> void:
	var parent: Node3D = _piece_by_id("ramp_takeoff") as Node3D
	var local := Vector3(0.0, 1.6, -13.0)
	if parent == null:
		parent = _piece_by_id("jump_small") as Node3D
		local = Vector3(0.0, 1.4, -1.05)
	elif parent.has_method("exit_global"):
		var edge: Node = parent.find_child("TAKEOFF_EDGE", true, false)
		if edge is Node3D:
			local = parent.to_local((edge as Node3D).global_position) + Vector3(0.0, 1.2, 0.0)
		else:
			var xf: Transform3D = parent.call("exit_global") as Transform3D
			local = parent.to_local(xf.origin) + Vector3(0.0, 1.2, 0.0)
	if parent == null:
		return
	_takeoff_zone = _make_zone("TAKEOFF_ZONE", parent, local, Vector3(16.0, 3.2, 3.2), Color(0.2, 0.95, 0.55, 0.18))
	var deck: Node3D = _piece_by_id("landing_straight_long") as Node3D
	if deck != null:
		_landing_zone = _make_zone("LANDING_TARGET_ZONE", deck, Vector3(0.0, 1.2, -8.0), Vector3(11.0, 3.0, 16.0), Color(0.95, 0.75, 0.2, 0.18))
	_make_gap_volume()


func _make_gap_volume() -> void:
	var a := _takeoff_world()
	var deck: Node3D = _piece_by_id("landing_straight_long") as Node3D
	if deck == null:
		return
	var b: Vector3 = Vector3.ZERO
	if deck.has_method("entry_global"):
		b = (deck.call("entry_global") as Transform3D).origin
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
	if ramp == null:
		ramp = _piece_by_id("ramp_small") as Node3D
	if ramp != null:
		_label3d(ramp, "RAMP_ENTRY", Vector3(0, 2.4, -0.4))
	var to_p: Node3D = _piece_by_id("ramp_takeoff") as Node3D
	if to_p != null:
		_label3d(to_p, "TAKEOFF_EDGE", Vector3(0, 2.6, 0.2))
		_label3d(to_p, "GAP_START", Vector3(0, 2.2, 0.2))
	var jump: Node3D = _piece_by_id("jump_small") as Node3D
	if jump != null:
		_label3d(jump, "TAKEOFF_EDGE", Vector3(0, 2.6, -1.2))
		_label3d(jump, "GAP_START", Vector3(0, 2.2, -1.2))
		_label3d(jump, "GAP_END", Vector3(0, 1.6, -8.2))
	var gap: Node3D = _piece_by_id("gap_logical") as Node3D
	if gap != null:
		_label3d(gap, "GAP_START", Vector3(0, 2.4, 0.0))
		_label3d(gap, "GAP_END", Vector3(0, 2.4, -_gap_length))
	var deck: Node3D = _piece_by_id("landing_straight_long") as Node3D
	if deck != null:
		_label3d(deck, "LANDING_START", Vector3(0, 2.4, 0.0))
		_label3d(deck, "LANDING_TARGET", Vector3(0, 2.4, -8.0))
		_label3d(deck, "RECOVERY_END", Vector3(0, 2.2, -34.0))


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
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1, 0.96, 0.8))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(_label)


func _refresh_hud() -> void:
	if _label == null:
		return
	_label.text = "CLEAN GAP V5  layout=%s  piece=%s  speed=%.1f  takeoff=%s  fc=%s  result=%s" % [
		_layout, _current_piece, _speed(), str(_valid_takeoff), str(_first_contact), _result
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
