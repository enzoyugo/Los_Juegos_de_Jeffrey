extends Node3D

## Procedural kit generator lab. Default 4WHEEL for human review. Does not replace TrackMain.
## GENERATOR_LAB_BASELINE_REASON=C+I
## Lab historically hardcoded TrackCar.tscn and never instantiated 4WHEEL.
## Not a 4WHEEL physics/module blocker. TrackMain stays BASELINE (canonical firewall).

const Config := preload("res://scripts/track/track_config.gd")
const GenScript := preload("res://scripts/track/track_generator_v2.gd")
const CamScript := preload("res://scripts/track/track_camera.gd")
const FeedbackScript := preload("res://scripts/track/track_boost_feedback.gd")
const Surface := preload("res://scripts/track/track_surface.gd")
const Telemetry := preload("res://scripts/track/track_debug_telemetry.gd")

const BASELINE_SCENE_PATH := "res://scenes/track/TrackCar.tscn"
const FOUR_WHEEL_SCENE_PATH := "res://scenes/track/TrackCarWheelPhysics.tscn"
const MODE_BASELINE := "BASELINE"
const MODE_FOUR_WHEEL := "4WHEEL"
const PIECE_SCENE := "res://scenes/track/modules/TrackPiece.tscn"
const SHOWCASES_PATH := "res://data/track/generator_v2_showcases.json"
const SMOKE_PATH := "res://docs/generated/track_generator_v2/smoke.json"
const GEN_BOOST_PATH := "res://docs/generated/track_boost_v3/generated_3x.json"
const SEAM_POS_LIMIT := 0.0005
const BOOST_GEN_SEQ: PackedStringArray = ["start", "straight_medium", "boost_straight", "straight_medium", "finish"]

var _gen
var _pieces: Array = []
var _car
var _cam
var _label: Label
var _hud_on: bool = true
var _debug_on: bool = false
var _seed: int = 1
var _length: String = "SHORT"
var _difficulty: String = "PICANTE"
var _result: Dictionary = {}
var _spawn := Transform3D.IDENTITY
var _showcases: Dictionary = {}
var _fail_text: String = ""
var _smoke: bool = false
var _boost_gen_smoke: bool = false
var _feedback: Node
var _boost_gen_runs: int = 0
var _boost_gen_clock: float = 0.0
var _boost_gen_hits: int = 0
var _boost_gen_waiting: bool = false
var _ground: MeshInstance3D
var _ground_body: StaticBody3D
var _scenery: Node3D
var _mode: String = MODE_FOUR_WHEEL
var _elapsed: float = 0.0
var _last_safe := Transform3D.IDENTITY
var _surface_state: String = "ROAD"
var _offtrack_t: float = 0.0


func _ready() -> void:
	Config.ensure_actions()
	_gen = GenScript.new()
	_smoke = OS.get_environment("SSK_GEN_SMOKE").strip_edges() == "1"
	_boost_gen_smoke = OS.get_environment("SSK_BOOST_GEN_SMOKE").strip_edges() == "1"
	_load_showcases()
	_place_environment()
	_place_hud()
	_cam = CamScript.new()
	_cam.name = "ChaseCam"
	_cam.current = true
	add_child(_cam)
	if _smoke:
		_run_smoke()
		return
	if _boost_gen_smoke:
		_run_boost_gen_smoke()
		return
	_apply_showcase("SHORT_SHOWCASE")
	_rebuild()
	_spawn_car()
	var Probe := load("res://scripts/debug/jeffrey_resource_probe.gd")
	if Probe != null:
		Probe.dump("TrackGeneratorV2Lab.ready", self)
	print("[TRACK_GENERATOR_V2] LAB 1 SHORT  2 MEDIUM  3 LONG  T difficulty  R new seed  G next seed  F2 controller  F4 collision  C reset")


func _unhandled_input(event: InputEvent) -> void:
	if _smoke or _boost_gen_smoke:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_apply_showcase("SHORT_SHOWCASE")
			_rebuild()
			_reset_car()
			get_viewport().set_input_as_handled()
		KEY_2:
			_apply_showcase("MEDIUM_SHOWCASE")
			_rebuild()
			_reset_car()
			get_viewport().set_input_as_handled()
		KEY_3:
			_apply_showcase("LONG_SHOWCASE")
			_rebuild()
			_reset_car()
			get_viewport().set_input_as_handled()
		KEY_T:
			_cycle_difficulty()
			_rebuild()
			_reset_car()
			get_viewport().set_input_as_handled()
		KEY_R:
			_seed = Config.fresh_seed()
			_rebuild()
			_reset_car()
			get_viewport().set_input_as_handled()
		KEY_G:
			_seed += 1
			_rebuild()
			_reset_car()
			get_viewport().set_input_as_handled()
		KEY_F2:
			_toggle_controller()
			get_viewport().set_input_as_handled()
		KEY_F4:
			_debug_on = not _debug_on
			for piece in _pieces:
				if piece != null and piece.has_method("set_debug_visible"):
					piece.call("set_debug_visible", _debug_on)
			get_viewport().set_input_as_handled()
		KEY_F3:
			_hud_on = not _hud_on
			if _label != null:
				_label.visible = _hud_on
			get_viewport().set_input_as_handled()
		KEY_C:
			_reset_car()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _smoke and not _boost_gen_smoke:
		_elapsed += delta
		_tick_offtrack(delta)
	_refresh_hud()


func _physics_process(delta: float) -> void:
	if not _boost_gen_smoke or _car == null:
		return
	_boost_gen_clock += delta
	if not _boost_gen_waiting and Telemetry.debug_bool(_car, "boost_active", false):
		_boost_gen_hits += 1
		_boost_gen_waiting = true
		print("[TRACK_BOOST_GEN] HIT %d apply_count=%d" % [
			_boost_gen_hits, Telemetry.debug_int(_car, "boost_apply_count", 0)
		])
	if _boost_gen_waiting and _boost_gen_clock > 1.15:
		_boost_gen_next_or_finish()
		return
	if not _boost_gen_waiting and _boost_gen_clock > 10.0:
		print("[TRACK_BOOST_GEN] TIMEOUT run=%d" % (_boost_gen_runs + 1))
		_boost_gen_next_or_finish()


func _load_showcases() -> void:
	_showcases = {}
	if not FileAccess.file_exists(SHOWCASES_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SHOWCASES_PATH))
	if parsed is Dictionary:
		_showcases = parsed


func _apply_showcase(key: String) -> void:
	var row_raw = _showcases.get(key, {})
	var row: Dictionary = {}
	if row_raw is Dictionary:
		row = row_raw
	var seed_raw = row.get("seed", 1)
	_seed = int(seed_raw)
	_length = str(row.get("length", "SHORT"))
	_difficulty = str(row.get("difficulty", "PICANTE"))


func _cycle_difficulty() -> void:
	if _difficulty == "TRANQUI":
		_difficulty = "PICANTE"
	elif _difficulty == "PICANTE":
		_difficulty = "DEMENTE"
	else:
		_difficulty = "TRANQUI"


func _rebuild() -> void:
	_clear_pieces()
	_result = _gen.generate(_seed, _length, _difficulty)
	var accepted := bool(_result.get("accepted", false))
	if not accepted:
		_fail_text = _format_fail()
		print("[TRACK_GENERATOR_V2] LAB_FAIL %s" % _fail_text.replace("\n", " | "))
		_spawn = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -2.6))
		return
	_fail_text = ""
	_assemble(_result)
	_measure_instanced_seams()
	_place_scenery()


func _format_fail() -> String:
	var reasons_raw = _result.get("rejection_reasons", [])
	var joined := ""
	if reasons_raw is PackedStringArray:
		joined = ",".join(reasons_raw)
	elif reasons_raw is Array:
		var parts: PackedStringArray = PackedStringArray()
		for item in reasons_raw:
			parts.append(str(item))
		joined = ",".join(parts)
	return "VALIDATION FAIL seed=%d length=%s difficulty=%s reasons=%s" % [
		_seed, _length, _difficulty, joined
	]


func _clear_pieces() -> void:
	for piece in _pieces:
		if piece != null and is_instance_valid(piece):
			remove_child(piece)
			piece.free()
	_pieces.clear()
	var markers := get_node_or_null("SeamMarkers")
	if markers != null:
		remove_child(markers)
		markers.free()


func _assemble(result: Dictionary) -> void:
	var seq_raw = result.get("piece_sequence", [])
	var seq: Array = []
	if seq_raw is Array:
		seq = seq_raw
	var packed: PackedScene = load(PIECE_SCENE) as PackedScene
	if packed == null:
		push_error("[TRACK_GENERATOR_V2] missing TrackPiece.tscn")
		return
	var target := Transform3D.IDENTITY
	for raw_id in seq:
		var piece = packed.instantiate()
		piece.piece_id = str(raw_id)
		add_child(piece)
		piece.align_entry_to(target)
		_pieces.append(piece)
		target = piece.exit_global()
		if piece.finish_area != null and not piece.finish_area.body_entered.is_connected(_on_finish):
			piece.finish_area.body_entered.connect(_on_finish)
	var start_piece = _pieces[0] if _pieces.size() > 0 else null
	if start_piece != null and start_piece.player_spawn != null:
		_spawn = start_piece.player_spawn.global_transform
	else:
		_spawn = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -2.6))


func _measure_instanced_seams() -> void:
	for i in range(1, _pieces.size()):
		var prev = _pieces[i - 1]
		var nxt = _pieces[i]
		var a: Transform3D = prev.exit_global()
		var b: Transform3D = nxt.entry_global()
		var pos: float = a.origin.distance_to(b.origin)
		var fwd_a: Vector3 = -a.basis.z
		var fwd_b: Vector3 = -b.basis.z
		var yaw := 0.0
		if fwd_a.length() > 0.0001 and fwd_b.length() > 0.0001:
			yaw = rad_to_deg(fwd_a.normalized().angle_to(fwd_b.normalized()))
		if pos > SEAM_POS_LIMIT or absf(yaw) > 0.05:
			print("[TRACK_GENERATOR_V2] SEAM_POS/SEAM_ROT %s->%s pos=%.6f yaw=%.4f" % [
				prev.piece_id, nxt.piece_id, pos, yaw
			])


func _spawn_car() -> void:
	if _car != null:
		var old = _car
		_car = null
		if old.get_parent() == self:
			remove_child(old)
		old.free()
	var path := FOUR_WHEEL_SCENE_PATH if _mode == MODE_FOUR_WHEEL else BASELINE_SCENE_PATH
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("[TRACK_GENERATOR_V2] failed to load %s" % path)
		return
	_car = packed.instantiate()
	add_child(_car)
	_reset_car()
	_car.control_enabled = true
	if _feedback == null:
		_feedback = FeedbackScript.new()
		add_child(_feedback)
	if _feedback.has_method("setup"):
		_feedback.call("setup", _car, _cam)
	if _cam != null:
		_cam.target = _car.camera_target() if _car.has_method("camera_target") else _car
		if _cam.has_method("snap_to_target"):
			_cam.snap_to_target()
	print("[TRACK_GENERATOR_V2] CONTROLLER=%s (TrackMain remains BASELINE)" % _mode)


func _toggle_controller() -> void:
	_mode = MODE_BASELINE if _mode == MODE_FOUR_WHEEL else MODE_FOUR_WHEEL
	_spawn_car()
	_elapsed = 0.0
	print("[TRACK_GENERATOR_V2] CONTROLLER=%s same seed=%d sequence preserved" % [_mode, _seed])


func _reset_car() -> void:
	_elapsed = 0.0
	_surface_state = "ROAD"
	_offtrack_t = 0.0
	_last_safe = _spawn
	if _car != null and _car.has_method("reset_to"):
		_car.call("reset_to", _spawn)
	elif _car is Node3D:
		(_car as Node3D).global_transform = _spawn
	if _cam != null and _cam.has_method("snap_to_target"):
		_cam.snap_to_target()
	for piece in _pieces:
		if piece != null and piece.has_method("rearm_boost_trigger"):
			piece.call("rearm_boost_trigger")


func _on_finish(body: Node) -> void:
	if body != _car:
		return
	print("[TRACK_GENERATOR_V2] FINISH seed=%d length=%s difficulty=%s" % [_seed, _length, _difficulty])


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
	if _label == null or not _hud_on:
		return
	var accepted := bool(_result.get("accepted", false))
	var lines := PackedStringArray([
		"TRACK GENERATOR V2",
		"CONTROLLER %s" % _mode,
		"seed %d   length %s   difficulty %s   pieces %d   path %.0fm" % [
			_seed,
			_length,
			_difficulty,
			Telemetry.dict_int(_result, "piece_count", 0),
			Telemetry.dict_float(_result, "path_m", 0.0),
		],
		"accepted %s   turns %d   t %.1fs" % [
			"YES" if accepted else "NO",
			Telemetry.dict_int(_result, "turns", 0),
			_elapsed,
		],
	])
	if not _fail_text.is_empty():
		lines.append(_fail_text)
	if _car != null:
		lines.append("speed %.1f" % Telemetry.debug_float(_car, "debug_speed", 0.0))
		var gnd_n := Telemetry.debug_int(_car, "debug_grounded_n", -1)
		if gnd_n < 0:
			gnd_n = 1 if Telemetry.debug_bool(_car, "debug_grounded", false) else 0
		lines.append("grounded wheels %d/4" % gnd_n)
		var piece_id := Telemetry.debug_string(_car, "report_piece_id", "-")
		if piece_id.is_empty():
			piece_id = "-"
		lines.append("piece %s" % piece_id)
		if _feedback != null and _feedback.has_method("hud_line"):
			lines.append(str(_feedback.call("hud_line")))
		elif Telemetry.debug_bool(_car, "boost_active", false):
			lines.append("BOOST ACTIVE")
		else:
			lines.append("BOOST READY")
		var drift := Telemetry.debug_string(_car, "drift_state", "")
		if not drift.is_empty():
			lines.append("DRIFT %s slip %.2f yaw %.2f" % [
				drift,
				Telemetry.debug_float(_car, "debug_slip_angle", 0.0),
				Telemetry.debug_float(_car, "debug_yaw_rate", 0.0),
			])
		lines.append("OFFTRACK %s" % _surface_state)
		if Telemetry.debug_bool(_car, "debug_airborne", false):
			lines.append("AIRBORNE")
	lines.append("1 SHORT  2 MEDIUM  3 LONG  T difficulty  R new seed  G next seed")
	lines.append("F2 controller  F3 HUD  F4 collision  C reset  WASD  Shift drift")
	_label.text = "\n".join(lines)


func _place_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.light_energy = 1.15
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#6a7d8c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c5d0da")
	env.ambient_light_energy = 0.52
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.70, 0.76)
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.35
	world.environment = env
	add_child(world)
	_ground = MeshInstance3D.new()
	_ground.name = "GroundPlane"
	var plane := PlaneMesh.new()
	plane.size = Vector2(420.0, 420.0)
	_ground.mesh = plane
	_ground.position = Vector3(0.0, -0.42, -80.0)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.28, 0.36, 0.30)
	gmat.roughness = 0.92
	_ground.set_surface_override_material(0, gmat)
	add_child(_ground)
	_ground_body = StaticBody3D.new()
	_ground_body.name = "OfftrackGround"
	_ground_body.collision_layer = 1
	_ground_body.collision_mask = 0
	_ground_body.set_meta("collision_kind", Surface.KIND_OFFTRACK)
	_ground_body.position = Vector3(0.0, -0.48, -80.0)
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(420.0, 0.2, 420.0)
	gcol.shape = gshape
	_ground_body.add_child(gcol)
	add_child(_ground_body)


func _place_scenery() -> void:
	if _scenery != null and is_instance_valid(_scenery):
		remove_child(_scenery)
		_scenery.free()
	_scenery = Node3D.new()
	_scenery.name = "CheapScenery"
	add_child(_scenery)
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.22, 0.18, 0.14)
	var crown_mat := StandardMaterial3D.new()
	crown_mat.albedo_color = Color(0.18, 0.32, 0.16)
	var n: int = mini(_pieces.size(), 4)
	for i in n:
		var piece = _pieces[i]
		if piece == null:
			continue
		var entry_xf: Transform3D = piece.entry_global()
		for side in [-1.0, 1.0]:
			var pole := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.28, 3.2, 0.28)
			pole.mesh = box
			pole.set_surface_override_material(0, pole_mat)
			var pos: Vector3 = entry_xf.origin + entry_xf.basis.x * (side * 9.2) + Vector3(0.0, 1.4, 0.0)
			pos += -entry_xf.basis.z * 4.0
			_scenery.add_child(pole)
			pole.global_position = pos
			var crown := MeshInstance3D.new()
			var cap := BoxMesh.new()
			cap.size = Vector3(1.4, 1.6, 1.4)
			crown.mesh = cap
			crown.set_surface_override_material(0, crown_mat)
			_scenery.add_child(crown)
			crown.global_position = pos + Vector3(0.0, 2.2, 0.0)


func _run_smoke() -> void:
	var payload := {
		"showcases": {},
		"accepted": true,
	}
	var keys: PackedStringArray = ["SHORT_SHOWCASE", "MEDIUM_SHOWCASE", "LONG_SHOWCASE"]
	var all_ok := true
	for key in keys:
		_apply_showcase(key)
		var row: Dictionary = _gen.generate(_seed, _length, _difficulty)
		var ok := bool(row.get("accepted", false))
		if not ok:
			all_ok = false
		payload["showcases"][key] = _plain_result(row)
		if ok:
			print("[TRACK_GENERATOR_V2] ACCEPTED")
	payload["accepted"] = all_ok
	_write_json(SMOKE_PATH, payload)
	if all_ok:
		print("[TRACK_GENERATOR_V2] ACCEPTED")
		get_tree().quit(0)
	else:
		print("[TRACK_GENERATOR_V2] SMOKE_FAIL")
		get_tree().quit(1)


func _plain_result(row: Dictionary) -> Dictionary:
	var seq_raw = row.get("piece_sequence", [])
	var seq: Array = []
	if seq_raw is Array:
		for item in seq_raw:
			seq.append(str(item))
	var reasons_raw = row.get("rejection_reasons", [])
	var reasons: Array = []
	if reasons_raw is PackedStringArray or reasons_raw is Array:
		for item in reasons_raw:
			reasons.append(str(item))
	return {
		"seed": int(row.get("seed", 0)),
		"length": str(row.get("length", "")),
		"difficulty": str(row.get("difficulty", "")),
		"accepted": bool(row.get("accepted", false)),
		"piece_count": int(row.get("piece_count", 0)),
		"path_m": float(row.get("path_m", 0.0)),
		"turns": int(row.get("turns", 0)),
		"attempt": int(row.get("attempt", 0)),
		"piece_sequence": seq,
		"rejection_reasons": reasons,
	}


func _write_json(path: String, payload: Dictionary) -> void:
	var dir_path := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "  "))


func _run_boost_gen_smoke() -> void:
	TrackPiece.boost_gameplay_enabled = true
	_clear_pieces()
	var packed: PackedScene = load(PIECE_SCENE) as PackedScene
	var target := Transform3D.IDENTITY
	for id in BOOST_GEN_SEQ:
		var piece = packed.instantiate()
		piece.piece_id = str(id)
		add_child(piece)
		piece.align_entry_to(target)
		_pieces.append(piece)
		target = piece.exit_global()
	var start_piece = _pieces[0]
	if start_piece != null and start_piece.player_spawn != null:
		_spawn = start_piece.player_spawn.global_transform
	_spawn_car()
	_car.use_scripted_input = true
	_car.scripted_throttle = 1.0
	_car.scripted_steer = 0.0
	_boost_gen_runs = 0
	_boost_gen_hits = 0
	_boost_gen_clock = 0.0
	_boost_gen_waiting = false
	print("[TRACK_BOOST_GEN] START seq includes boost_straight")


func _boost_gen_next_or_finish() -> void:
	_boost_gen_runs += 1
	if _boost_gen_runs >= 3:
		var apply_n := 0
		if _car != null:
			apply_n = Telemetry.debug_int(_car, "boost_apply_count", 0)
		var ok: bool = apply_n == 3 and _boost_gen_hits == 3
		var payload := {
			"runs": 3,
			"hits": _boost_gen_hits,
			"apply_count": apply_n,
			"ok": ok,
			"sequence": Array(BOOST_GEN_SEQ),
		}
		_write_json(GEN_BOOST_PATH, payload)
		if ok:
			print("[TRACK_BOOST_GEN] PASS apply=%d hits=%d" % [apply_n, _boost_gen_hits])
			get_tree().quit(0)
		else:
			print("[TRACK_BOOST_GEN] FAIL apply=%d hits=%d" % [apply_n, _boost_gen_hits])
			get_tree().quit(1)
		return
	_boost_gen_clock = 0.0
	_boost_gen_waiting = false
	_reset_car()
	_car.use_scripted_input = true
	_car.scripted_throttle = 1.0
	_car.scripted_steer = 0.0
	print("[TRACK_BOOST_GEN] NEXT_RUN %d" % (_boost_gen_runs + 1))


func _tick_offtrack(delta: float) -> void:
	if _car == null or not (_car is Node3D):
		return
	var car3 := _car as Node3D
	_surface_state = _query_surface(car3)
	if _surface_state == "ROAD" and _is_safe_checkpoint(car3):
		_last_safe = car3.global_transform
		_offtrack_t = 0.0
	elif _surface_state == "SHOULDER":
		_offtrack_t += delta * 0.25
		_apply_baseline_penalty(0.55, delta)
	else:
		_offtrack_t += delta
		_apply_baseline_penalty(0.22, delta)
	var far := _distance_to_track(car3.global_position) > Surface.FAR_M
	var fallen := car3.global_position.y < Surface.FALL_Y
	if fallen or far or (_surface_state == "OFFTRACK" and _offtrack_t > 2.8):
		_reset_to_safe()


func _query_surface(car3: Node3D) -> String:
	if _car.has_method("wheels"):
		var kinds := PackedStringArray()
		var gnd := 0
		var rows = _car.call("wheels")
		if rows is Array:
			for w in rows:
				if w != null and bool(w.get("is_grounded")):
					gnd += 1
					kinds.append(str(w.get("contact_kind")))
		var maj := Surface.majority_kind(kinds, gnd)
		if maj == Surface.KIND_OFFTRACK:
			return "OFFTRACK"
		if maj == Surface.KIND_SHOULDER:
			return "SHOULDER"
		return "ROAD"
	var from := car3.global_position + Vector3(0, 0.6, 0)
	var to := from + Vector3(0, -2.4, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.exclude = [car3.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return "AIR"
	var col = hit.get("collider")
	if col is Node and (col as Node).has_meta("collision_kind"):
		var kind := str((col as Node).get_meta("collision_kind"))
		if kind == Surface.KIND_OFFTRACK:
			return "OFFTRACK"
		if kind == Surface.KIND_SHOULDER:
			return "SHOULDER"
		if kind == Surface.KIND_RAIL:
			return "SHOULDER"
	return "ROAD"


func _is_safe_checkpoint(car3: Node3D) -> bool:
	if _surface_state != "ROAD":
		return false
	var speed := Telemetry.debug_float(_car, "debug_speed", 0.0)
	if speed > Surface.CHECKPOINT_MAX_SPEED:
		return false
	if _car.has_method("wheels"):
		var gnd := 0
		var rows = _car.call("wheels")
		if rows is Array:
			for w in rows:
				if w != null and bool(w.get("is_grounded")):
					gnd += 1
		return gnd >= 4
	if car3 is CharacterBody3D:
		return (car3 as CharacterBody3D).is_on_floor()
	return true


func _apply_baseline_penalty(scale: float, delta: float) -> void:
	if _mode != MODE_BASELINE or not (_car is CharacterBody3D):
		return
	var cb := _car as CharacterBody3D
	var planar := Vector3(cb.velocity.x, 0.0, cb.velocity.z)
	var drag: float = Surface.OFFTRACK_DRAG if scale < 0.3 else Surface.SHOULDER_DRAG
	planar = planar.move_toward(Vector3.ZERO, drag * delta)
	cb.velocity.x = planar.x
	cb.velocity.z = planar.z


func _distance_to_track(pos: Vector3) -> float:
	var best := 9999.0
	for piece in _pieces:
		if piece == null or not (piece is Node3D):
			continue
		var d: float = (piece as Node3D).global_position.distance_to(pos)
		if d < best:
			best = d
	return best


func _reset_to_safe() -> void:
	var target := _last_safe
	if target.origin == Vector3.ZERO:
		target = _spawn
	_offtrack_t = 0.0
	_surface_state = "ROAD"
	if _car != null and _car.has_method("reset_to"):
		_car.call("reset_to", target)
	elif _car is Node3D:
		(_car as Node3D).global_transform = target
	if _cam != null and _cam.has_method("snap_to_target"):
		_cam.snap_to_target()
	print("[TRACK_GENERATOR_V2] OFFTRACK_RESET")
