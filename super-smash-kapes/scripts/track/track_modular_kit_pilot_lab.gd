extends Node3D

## Fixed 5-piece modular kit pipeline lab. Not TrackMain. Not a generator.

const Config := preload("res://scripts/track/track_config.gd")
const Registry := preload("res://scripts/track/track_piece_registry.gd")
const CamScript := preload("res://scripts/track/track_camera.gd")

const BASELINE_SCENE_PATH := "res://scenes/track/TrackCar.tscn"
const FOUR_WHEEL_SCENE_PATH := "res://scenes/track/TrackCarWheelPhysics.tscn"
const PIECE_SCENE := "res://scenes/track/modules/TrackPiece.tscn"
const RUNTIME_REPORT := "res://docs/generated/TRACK_PILOT_RUNTIME.json"

const MODE_BASELINE := "BASELINE"
const MODE_FOUR_WHEEL := "4WHEEL_V1"
const SEAM_POS_LIMIT := 0.0005
const SPIKE_COMPRESSION := 0.07
const SPIKE_VY := 2.4
const SEAM_WINDOW_M := 2.8

var _pieces: Array = []
var _seams: Array = []
var _car
var _cam
var _label: Label
var _hud_on: bool = true
var _debug_on: bool = false
var _mode: String = MODE_BASELINE
var _spawn := Transform3D.IDENTITY
var _timer_on: bool = false
var _elapsed: float = 0.0
var _finished: bool = false
var _estimated: float = 0.0
var _finish_time: float = -1.0
var _current_piece: String = ""
var _nearest_seam: String = ""
var _prev_comp: Dictionary = {}
var _prev_vy: float = 0.0
var _spike_logs: PackedStringArray = PackedStringArray()
var _contact_loss: PackedStringArray = PackedStringArray()
var _frame: int = 0
var _smoke: bool = false
var _smoke_frames: int = 90
var _first_tex: float = 0.0


func _ready() -> void:
	Config.ensure_actions()
	_smoke = OS.get_environment("SSK_PILOT_SMOKE").strip_edges() == "1"
	var hold := OS.get_environment("SSK_PILOT_FRAMES").strip_edges()
	if not hold.is_empty():
		_smoke_frames = maxi(int(hold), 24)
	var override := OS.get_environment("SSK_TRACK_CONTROLLER").strip_edges().to_upper()
	if override == "4WHEEL" or override == "FOUR_WHEEL_V1" or override == "4WHEEL_V1":
		_mode = MODE_FOUR_WHEEL
	elif override == "BASELINE":
		_mode = MODE_BASELINE
	_place_environment()
	_place_hud()
	_assemble()
	_cam = CamScript.new()
	_cam.name = "ChaseCam"
	_cam.current = true
	add_child(_cam)
	_spawn_car(_mode)
	if _smoke:
		Input.action_press("track_accel", 1.0)
	_first_tex = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	print("[TRACK_PILOT] CONTROLLER=%s pieces=%d estimated=%.2f tex=%.0f" % [
		_mode, _pieces.size(), _estimated, _first_tex
	])
	for row in _seams:
		print("[TRACK_PILOT] SEAM %s pos=%.6f yaw=%.4f up=%.4f" % [
			row["id"], row["position_m"], row["yaw_delta_deg"], row["up_delta_deg"]
		])
	if _smoke:
		_write_runtime_report("start")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or not event.echo == false:
		return
	match event.keycode:
		KEY_F3:
			_hud_on = not _hud_on
			if _label != null:
				_label.visible = _hud_on
			get_viewport().set_input_as_handled()
		KEY_F4:
			_debug_on = not _debug_on
			for piece in _pieces:
				if piece != null and piece.has_method("set_debug_visible"):
					piece.call("set_debug_visible", _debug_on)
			if _car != null and _car.has_method("set_collider_visible"):
				_car.call("set_collider_visible", _debug_on)
			get_viewport().set_input_as_handled()
		KEY_F5:
			_toggle_controller()
			get_viewport().set_input_as_handled()
		KEY_V:
			_cycle_visual_mode()
			get_viewport().set_input_as_handled()
		KEY_B:
			TrackPiece.boost_gameplay_enabled = not TrackPiece.boost_gameplay_enabled
			print("[TRACK_PILOT] boost_enabled=%s" % str(TrackPiece.boost_gameplay_enabled))
			get_viewport().set_input_as_handled()
		KEY_6:
			_set_visual_mode(0)
			get_viewport().set_input_as_handled()
		KEY_7:
			_set_visual_mode(1)
			get_viewport().set_input_as_handled()
		KEY_8:
			_set_visual_mode(2)
			get_viewport().set_input_as_handled()
		KEY_9:
			_set_visual_mode(3)
			get_viewport().set_input_as_handled()
		KEY_0:
			_set_visual_mode(4)
			get_viewport().set_input_as_handled()
		KEY_C:
			_reset_car()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_frame += 1
	if _timer_on and not _finished:
		_elapsed += delta
	_refresh_location()
	_refresh_hud()
	if _smoke and _frame >= _smoke_frames:
		_finish_smoke()


func _physics_process(_delta: float) -> void:
	if _car == null:
		return
	_watch_seams()
	if not _timer_on and not _finished:
		var speed := 0.0
		if _car.has_method("speed_kph"):
			speed = float(_car.call("speed_kph"))
		if speed > 4.0:
			_timer_on = true


func _assemble() -> void:
	_pieces.clear()
	_seams.clear()
	_estimated = 0.0
	var target := Transform3D.IDENTITY
	var packed: PackedScene = load(PIECE_SCENE) as PackedScene
	for id in Registry.PILOT_IDS:
		var piece = packed.instantiate()
		piece.piece_id = str(id)
		add_child(piece)
		piece.align_entry_to(target)
		_pieces.append(piece)
		_estimated += float(piece.meta.get("estimated_traversal_time", 0.5))
		if _pieces.size() > 1:
			var prev = _pieces[_pieces.size() - 2]
			_seams.append(_measure_seam(prev, piece))
		target = piece.exit_global()
		if piece.finish_area != null and not piece.finish_area.body_entered.is_connected(_on_finish):
			piece.finish_area.body_entered.connect(_on_finish)
	_place_seam_markers()
	var start_piece = _pieces[0] if _pieces.size() > 0 else null
	if start_piece != null and start_piece.player_spawn != null:
		_spawn = start_piece.player_spawn.global_transform
	else:
		_spawn = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -2.6))


func _measure_seam(prev, nxt) -> Dictionary:
	var a: Transform3D = prev.exit_global()
	var b: Transform3D = nxt.entry_global()
	var pos := a.origin.distance_to(b.origin)
	var fwd_a := -a.basis.z.normalized()
	var fwd_b := -b.basis.z.normalized()
	var up_a := a.basis.y.normalized()
	var up_b := b.basis.y.normalized()
	var yaw := rad_to_deg(fwd_a.signed_angle_to(fwd_b, Vector3.UP))
	var up := rad_to_deg(up_a.angle_to(up_b))
	return {
		"id": "%s->%s" % [prev.piece_id, nxt.piece_id],
		"a": prev.piece_id,
		"b": nxt.piece_id,
		"origin": a.origin,
		"position_m": pos,
		"yaw_delta_deg": yaw,
		"up_delta_deg": up,
	}


func _place_seam_markers() -> void:
	var root := Node3D.new()
	root.name = "SeamMarkers"
	add_child(root)
	for row in _seams:
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.24
		mesh.mesh = sphere
		var mat := StandardMaterial3D.new()
		var ok: bool = float(row["position_m"]) <= SEAM_POS_LIMIT
		mat.albedo_color = Color(0.2, 0.9, 0.35) if ok else Color(0.95, 0.2, 0.2)
		mesh.set_surface_override_material(0, mat)
		mesh.position = row["origin"]
		mesh.name = str(row["id"])
		root.add_child(mesh)
		var lab := Label3D.new()
		lab.text = str(row["id"])
		lab.position = row["origin"] + Vector3(0, 1.6, 0)
		lab.font_size = 28
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(lab)


func _spawn_car(mode: String) -> void:
	if _car != null:
		var old = _car
		_car = null
		if old.get_parent() == self:
			remove_child(old)
		old.free()
	var path := FOUR_WHEEL_SCENE_PATH if mode == MODE_FOUR_WHEEL else BASELINE_SCENE_PATH
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("[TRACK_PILOT] failed to load %s" % path)
		return
	_car = packed.instantiate()
	add_child(_car)
	_reset_car()
	_car.control_enabled = true
	if _cam != null:
		_cam.target = _car.camera_target() if _car.has_method("camera_target") else _car
		if _cam.has_method("snap_to_target"):
			_cam.snap_to_target()
	print("[TRACK_PILOT] CONTROLLER=%s (BASELINE remains canonical)" % mode)


func _reset_car() -> void:
	_timer_on = false
	_elapsed = 0.0
	_finished = false
	_finish_time = -1.0
	_prev_comp.clear()
	_prev_vy = 0.0
	if _car != null and _car.has_method("reset_to"):
		_car.call("reset_to", _spawn)
	elif _car is Node3D:
		(_car as Node3D).global_transform = _spawn


func _toggle_controller() -> void:
	var xform := _spawn
	if _car != null and _car is Node3D:
		xform = (_car as Node3D).global_transform
	_mode = MODE_BASELINE if _mode == MODE_FOUR_WHEEL else MODE_FOUR_WHEEL
	_spawn_car(_mode)
	if _car != null and _car.has_method("reset_to"):
		_car.call("reset_to", xform)
	print("[TRACK_PILOT] live_track_car_count=%d" % _live_car_count())


func _live_car_count() -> int:
	return get_tree().get_nodes_in_group("track_runtime_car").size()


func _visual_root():
	if _car == null:
		return null
	return _car.get_node_or_null("VisualRoot")


func _cycle_visual_mode() -> void:
	var vis = _visual_root()
	if vis != null and vis.has_method("cycle_articulation_mode"):
		vis.call("cycle_articulation_mode")


func _set_visual_mode(mode: int) -> void:
	var vis = _visual_root()
	if vis != null and vis.has_method("set_articulation_mode"):
		vis.call("set_articulation_mode", mode)


func _on_finish(body: Node) -> void:
	if _finished:
		return
	if body != _car:
		return
	_finished = true
	_timer_on = false
	_finish_time = _elapsed
	print("[TRACK_PILOT] FINISH t=%.3f estimated=%.3f delta=%.3f controller=%s" % [
		_finish_time, _estimated, _finish_time - _estimated, _mode
	])


func _refresh_location() -> void:
	if _car == null or not (_car is Node3D) or _pieces.is_empty():
		return
	var pos: Vector3 = (_car as Node3D).global_position
	var best := 1.0e9
	_current_piece = ""
	for piece in _pieces:
		if piece == null:
			continue
		var d: float = pos.distance_to(piece.global_position)
		if d < best:
			best = d
			_current_piece = piece.piece_id
	_nearest_seam = ""
	best = 1.0e9
	for row in _seams:
		var d: float = pos.distance_to(row["origin"])
		if d < best:
			best = d
			_nearest_seam = str(row["id"])
	if best > 8.0:
		_nearest_seam = ""


func _watch_seams() -> void:
	if _car == null or not (_car is Node3D):
		return
	var pos: Vector3 = (_car as Node3D).global_position
	var near := ""
	var near_d := 1.0e9
	for row in _seams:
		var d: float = pos.distance_to(row["origin"])
		if d < near_d:
			near_d = d
			near = str(row["id"])
	if near_d > SEAM_WINDOW_M:
		_prev_comp.clear()
		_prev_vy = _vertical_speed()
		return
	var vy := _vertical_speed()
	if absf(vy - _prev_vy) > SPIKE_VY and absf(vy) > SPIKE_VY:
		var msg := "[TRACK_SEAM_SPIKE] vertical %s vy_before=%.3f vy_after=%.3f speed=%.1f" % [
			near, _prev_vy, vy, _speed_ms()
		]
		_spike_logs.append(msg)
		print(msg)
	_prev_vy = vy
	if _mode != MODE_FOUR_WHEEL or not _car.has_method("wheels"):
		return
	var grounded_n := 0
	for w in _car.call("wheels"):
		if w == null:
			continue
		var wid := str(w.wheel_id)
		if bool(w.is_grounded):
			grounded_n += 1
		var prev_c := float(_prev_comp.get(wid, w.compression))
		var dc: float = absf(float(w.compression) - prev_c)
		if dc > SPIKE_COMPRESSION:
			var msg := "[TRACK_SEAM_SPIKE] %s %s before=%.3f after=%.3f speed=%.1f" % [
				near, wid, prev_c, float(w.compression), _speed_ms()
			]
			_spike_logs.append(msg)
			print(msg)
		_prev_comp[wid] = float(w.compression)
	if grounded_n == 0 and _speed_ms() > 4.0:
		var loss := "[TRACK_SEAM_CONTACT_LOSS] %s airborne_all speed=%.1f" % [near, _speed_ms()]
		_contact_loss.append(loss)
		print(loss)


func _vertical_speed() -> float:
	if _car is RigidBody3D:
		return (_car as RigidBody3D).linear_velocity.y
	if _car is CharacterBody3D:
		return (_car as CharacterBody3D).velocity.y
	return 0.0


func _speed_ms() -> float:
	if _car != null and _car.has_method("speed_kph"):
		return float(_car.call("speed_kph")) / 3.6
	return 0.0


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
	var lines := PackedStringArray([
		"TRACK MODULAR KIT PILOT V1",
		"CONTROLLER: %s  (BASELINE canonical · 4WHEEL parallel)" % _mode,
		"piece %s   seam %s" % [_current_piece, _nearest_seam],
		"timer %.2f / est %.2f%s" % [_elapsed, _estimated, "  FINISH" if _finished else ""],
	])
	if _car != null and _car.has_method("debug_hud_lines"):
		lines.append_array(_car.debug_hud_lines())
	elif _car != null:
		lines.append("speed %.1f  steer %.2f  drift %s" % [
			float(_car.get("debug_speed")),
			float(_car.get("debug_steer")),
			str(_car.get("drift_state")),
		])
	lines.append("F3 HUD · F4 seams/collision · F5 A/B · V visual · 6-0 modes · B boost · C reset · WASD · Shift drift")
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
	world.environment = env
	add_child(world)


func _finish_smoke() -> void:
	var grounded := _count_grounded()
	var max_pos := 0.0
	for row in _seams:
		max_pos = maxf(max_pos, float(row["position_m"]))
	var tex := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	print("[TRACK_PILOT] SMOKE END controller=%s grounded=%d/%s max_seam=%.6f tex=%.0f spikes=%d loss=%d piece=%s finished=%s t=%.2f" % [
		_mode,
		grounded,
		"4" if _mode == MODE_FOUR_WHEEL else "n/a",
		max_pos,
		tex,
		_spike_logs.size(),
		_contact_loss.size(),
		_current_piece,
		str(_finished),
		_elapsed,
	])
	_write_runtime_report("end")
	var fail := max_pos > 0.001 or (_mode == MODE_FOUR_WHEEL and grounded < 2)
	get_tree().quit(1 if fail else 0)


func _count_grounded() -> int:
	if _car == null or not _car.has_method("wheels"):
		if _car is CharacterBody3D:
			return 1 if (_car as CharacterBody3D).is_on_floor() else 0
		return 0
	var n := 0
	for w in _car.call("wheels"):
		if w != null and bool(w.is_grounded):
			n += 1
	return n


func _write_runtime_report(phase: String) -> void:
	var payload := {
		"phase": phase,
		"controller": _mode,
		"canonical_controller": Config.CONTROLLER_MODE,
		"seams": _seams_plain(),
		"estimated_traversal_time": _estimated,
		"elapsed": _elapsed,
		"finish_time": _finish_time,
		"grounded": _count_grounded(),
		"spikes": Array(_spike_logs),
		"contact_loss": Array(_contact_loss),
		"texture_mem": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"video_mem": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"gpu": str(RenderingServer.get_video_adapter_name()),
	}
	var f := FileAccess.open(RUNTIME_REPORT, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "  "))


func _seams_plain() -> Array:
	var out := []
	for row in _seams:
		out.append({
			"id": row["id"],
			"position_m": row["position_m"],
			"yaw_delta_deg": row["yaw_delta_deg"],
			"up_delta_deg": row["up_delta_deg"],
		})
	return out
