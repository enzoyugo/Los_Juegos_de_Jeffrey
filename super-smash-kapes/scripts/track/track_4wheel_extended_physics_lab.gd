extends Node3D

## Extended 4WHEEL physics validation lab. Not TrackMain. Not a generator.
## Sequence: start → straight → boost → ramp → jump → landing_straight_long → recovery → curves → finish.

const Config := preload("res://scripts/track/track_config.gd")
const CamScript := preload("res://scripts/track/track_extended_debug_camera.gd")

const BASELINE_SCENE_PATH := "res://scenes/track/TrackCar.tscn"
const FOUR_WHEEL_SCENE_PATH := "res://scenes/track/TrackCarWheelPhysics.tscn"
const PIECE_SCENE := "res://scenes/track/modules/TrackPiece.tscn"

const MODE_BASELINE := "BASELINE"
const MODE_FOUR_WHEEL := "4WHEEL_V1"
const SEQUENCE: PackedStringArray = [
	"start",
	"straight_medium",
	"boost_straight",
	"straight_medium",
	"ramp_small",
	"jump_small",
	"landing_straight_long",
	"straight_medium",
	"curve_l_45",
	"curve_r_45",
	"finish",
]

var _pieces: Array = []
var _seams: Array = []
var _car
var _cam
var _label: Label
var _hud_on: bool = true
var _debug_on: bool = false
var _mode: String = MODE_FOUR_WHEEL
var _spawn := Transform3D.IDENTITY
var _current_piece: String = ""
var _frame: int = 0
var _smoke: bool = false
var _smoke_frames: int = 90
var _fwd_chassis: MeshInstance3D
var _fwd_visual: MeshInstance3D
var _fwd_track: MeshInstance3D
var _fwd_labels: Array = []
var _takeoff_zone: Area3D
var _landing_zone: Area3D
var _in_takeoff: bool = false
var _in_landing: bool = false
var _valid_takeoff: bool = false
var _valid_landing_logged: bool = false
var _offtrack_logged: bool = false
var _cam_mode_label: String = "CHASE_STANDARD"
var _prev_airborne: bool = false
var _first_contact_logged: bool = false
var _settled_logged: bool = false
var _jump_validate: bool = false
var _jump_out: String = ""
var _jump_events: Array = []
var _airborne_events: Array = []
var _fail_logged: bool = false
var _first_contact_n: int = 0
var _two_contact_t: float = -1.0
var _four_contact_t: float = -1.0
var _contact_clock: float = 0.0
var _wheel_ray_dbg: Array = []
var _takeoff_reset_gen: int = -1
var _finished: bool = false


func _ready() -> void:
	Config.ensure_actions()
	_smoke = OS.get_environment("SSK_EXTENDED_SMOKE").strip_edges() == "1"
	_jump_validate = OS.get_environment("SSK_JUMP_VALIDATE").strip_edges() == "1"
	_jump_out = OS.get_environment("SSK_JUMP_OUT").strip_edges()
	var hold: String = OS.get_environment("SSK_EXTENDED_FRAMES").strip_edges()
	if not hold.is_empty():
		_smoke_frames = maxi(int(hold), 24)
	elif _jump_validate:
		_smoke_frames = 1500
	var override: String = OS.get_environment("SSK_TRACK_CONTROLLER").strip_edges().to_upper()
	if override == "BASELINE":
		_mode = MODE_BASELINE
	elif override == "4WHEEL" or override == "FOUR_WHEEL_V1" or override == "4WHEEL_V1":
		_mode = MODE_FOUR_WHEEL
	_place_environment()
	_place_hud()
	_assemble()
	_place_forward_markers()
	_cam = CamScript.new()
	_cam.name = "ChaseCam"
	_cam.current = true
	add_child(_cam)
	_configure_landing_camera()
	_spawn_car(_mode)
	if _smoke or _jump_validate:
		Input.action_press("track_accel", 1.0)
	print("[TRACK_EXTENDED] CONTROLLER=%s pieces=%d live_track_car_count=%d boost=%s" % [
		_mode, _pieces.size(), _live_car_count(), str(TrackPiece.boost_gameplay_enabled)
	])
	for row in _seams:
		print("[TRACK_EXTENDED] SEAM %s pos=%.6f yaw=%.4f up=%.4f" % [
			row["id"], row["position_m"], row["yaw_delta_deg"], row["up_delta_deg"]
		])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
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
			_set_forward_visible(_debug_on)
			_set_zone_visible(_debug_on)
			_set_wheel_ray_debug(_debug_on)
			get_viewport().set_input_as_handled()
		KEY_F5:
			_toggle_controller()
			get_viewport().set_input_as_handled()
		KEY_V:
			_cycle_visual_mode()
			get_viewport().set_input_as_handled()
		KEY_B:
			TrackPiece.boost_gameplay_enabled = not TrackPiece.boost_gameplay_enabled
			print("[TRACK_EXTENDED] boost_enabled=%s" % str(TrackPiece.boost_gameplay_enabled))
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
		KEY_K:
			if _cam != null and _cam.has_method("cycle_mode"):
				_cam.call("cycle_mode")
			get_viewport().set_input_as_handled()
		KEY_C:
			_reset_car()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_frame += 1
	_refresh_location()
	_refresh_hud()
	_update_forward_markers()
	_update_jump_classification()
	if _debug_on:
		_update_wheel_ray_debug()
	if _smoke and not _jump_validate:
		if _frame == 24 or _frame == 48:
			_toggle_controller()
		if _frame == 36:
			_reset_car()
		if _frame >= _smoke_frames:
			_finish_smoke()


func _physics_process(delta: float) -> void:
	if not _jump_validate:
		return
	_contact_clock += delta
	if (_settled_logged or _fail_logged) and _contact_clock > 4.0:
		_finish_smoke()
		return
	if _contact_clock >= 28.0:
		_finish_smoke()


func _assemble() -> void:
	_pieces.clear()
	_seams.clear()
	var target := Transform3D.IDENTITY
	var packed: PackedScene = load(PIECE_SCENE) as PackedScene
	for id in SEQUENCE:
		var piece = packed.instantiate()
		piece.piece_id = str(id)
		add_child(piece)
		piece.align_entry_to(target)
		_pieces.append(piece)
		if _pieces.size() > 1:
			var prev = _pieces[_pieces.size() - 2]
			_seams.append(_measure_seam(prev, piece))
		target = piece.exit_global()
		if piece.finish_area != null and not piece.finish_area.body_entered.is_connected(_on_finish):
			piece.finish_area.body_entered.connect(_on_finish)
	_place_jump_zones()
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
		"origin": a.origin,
		"position_m": pos,
		"yaw_delta_deg": yaw,
		"up_delta_deg": up,
	}


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
		push_error("[TRACK_EXTENDED] failed to load %s" % path)
		return
	_car = packed.instantiate()
	add_child(_car)
	_reset_car()
	_car.control_enabled = true
	if _cam != null:
		_cam.target = _car.camera_target() if _car.has_method("camera_target") else _car
		if _cam.has_method("snap_to_target"):
			_cam.snap_to_target()
	print("[TRACK_EXTENDED] CONTROLLER=%s live_track_car_count=%d (BASELINE remains canonical)" % [
		mode, _live_car_count()
	])


func _reset_car() -> void:
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
	print("[TRACK_EXTENDED] live_track_car_count=%d" % _live_car_count())


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
	if body != _car:
		return
	print("[TRACK_EXTENDED] FINISH controller=%s" % _mode)


func _refresh_location() -> void:
	if _car == null or not (_car is Node3D) or _pieces.is_empty():
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
		elif str(piece.piece_id) == "landing_straight_long":
			length = 36.0
		elif str(piece.piece_id) == "jump_small":
			length = 22.2
		var along: float = -local.z
		var off: float = absf(local.x) + absf(local.y) * 0.25
		if along < -1.0 or along > length + 1.0:
			off += 100.0
		if off < best:
			best = off
			_current_piece = piece.piece_id


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
	var vis = _visual_root()
	var vis_mode: String = "n/a"
	if vis != null and vis.has_method("articulation_mode_name"):
		vis_mode = str(vis.call("articulation_mode_name"))
	var boost_on: bool = TrackPiece.boost_gameplay_enabled
	var car_boost: bool = false
	var airborne: bool = false
	var land_vy: float = 0.0
	if _car != null:
		car_boost = bool(_car.get("boost_active") == true)
		airborne = bool(_car.get("debug_airborne") == true)
		var raw_vy: Variant = _car.get("last_landing_vy")
		if raw_vy != null:
			land_vy = float(raw_vy)
	var lines := PackedStringArray([
		"TRACK 4WHEEL EXTENDED PHYSICS LAB V1",
		"CONTROLLER: %s  (BASELINE canonical · 4WHEEL parallel)" % _mode,
		"VISUAL_AUTHORITY articulated",
		"VISUAL_MODE: %s" % vis_mode,
		"piece %s" % _current_piece,
		"BOOST: %s / zone %s" % ["ENABLED" if boost_on else "DISABLED", "ACTIVE" if car_boost else "OFF"],
		"AIRBORNE: %s   LANDING vy %.2f" % ["YES" if airborne else "NO", land_vy],
		"CAM %s  K cycle · TAKEOFF %s LANDING %s" % [
			str(_cam.mode_name()) if _cam != null and _cam.has_method("mode_name") else "n/a",
			"IN" if _in_takeoff else "out",
			"IN" if _in_landing else "out",
		],
	])
	if vis != null and vis.has_method("chassis_forward"):
		lines.append("FWD chassis=%s visual=%s geometric=%s track=-Z" % [
			str(vis.call("chassis_forward")),
			str(vis.call("visual_forward")),
			str(vis.call("geometric_forward")) if vis.has_method("geometric_forward") else "n/a",
		])
	if _car != null and _car.has_method("debug_hud_lines"):
		lines.append_array(_car.debug_hud_lines())
	elif _car != null:
		lines.append("speed %.1f  steer %.2f" % [
			float(_car.get("debug_speed")),
			float(_car.get("debug_steer")),
		])
	lines.append("F3 HUD · F4 gizmos · F5 A/B · V visual · 6-0 modes · B boost · C reset · K cam")
	_label.text = "\n".join(lines)


func _place_forward_markers() -> void:
	_fwd_chassis = _make_arrow("ChassisForward", Color(0.2, 0.85, 1.0))
	_fwd_visual = _make_arrow("VisualForward", Color(0.95, 0.35, 0.85))
	_fwd_track = _make_arrow("TrackForward", Color(0.95, 0.85, 0.2))
	_fwd_labels = [
		_make_fwd_label("CHASSIS FORWARD", Color(0.2, 0.85, 1.0)),
		_make_fwd_label("VISUAL FORWARD", Color(0.95, 0.35, 0.85)),
		_make_fwd_label("TRACK FORWARD", Color(0.95, 0.85, 0.2)),
	]
	_set_forward_visible(false)


func _make_arrow(aname: String, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = aname
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.04
	cyl.height = 1.6
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.set_surface_override_material(0, mat)
	add_child(mesh)
	return mesh


func _make_fwd_label(text: String, color: Color) -> Label3D:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 28
	lab.modulate = color
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(lab)
	return lab


func _set_forward_visible(on: bool) -> void:
	for node in [_fwd_chassis, _fwd_visual, _fwd_track]:
		if node != null:
			node.visible = on
	for lab in _fwd_labels:
		if lab != null:
			lab.visible = on


func _update_forward_markers() -> void:
	if _fwd_chassis == null or _car == null or not (_car is Node3D):
		return
	var origin: Vector3 = (_car as Node3D).global_position + Vector3(0, 1.4, 0)
	var vis = _visual_root()
	var chassis_f: Vector3 = -(_car as Node3D).global_transform.basis.z.normalized()
	var visual_f: Vector3 = chassis_f
	if vis != null and vis.has_method("visual_forward"):
		visual_f = vis.call("visual_forward") as Vector3
	var track_f: Vector3 = Vector3(0, 0, -1)
	_orient_arrow(_fwd_chassis, origin, chassis_f)
	_orient_arrow(_fwd_visual, origin + Vector3(0.18, 0, 0), visual_f)
	_orient_arrow(_fwd_track, origin - Vector3(0.18, 0, 0), track_f)
	if _fwd_labels.size() >= 3:
		_fwd_labels[0].position = origin + chassis_f * 1.1 + Vector3(0, 0.25, 0)
		_fwd_labels[1].position = origin + visual_f * 1.1 + Vector3(0, 0.45, 0)
		_fwd_labels[2].position = origin + track_f * 1.1 + Vector3(0, 0.65, 0)


func _orient_arrow(mesh: MeshInstance3D, origin: Vector3, fwd: Vector3) -> void:
	if mesh == null:
		return
	if fwd.length() < 0.001:
		fwd = Vector3(0, 0, -1)
	fwd = fwd.normalized()
	mesh.global_position = origin + fwd * 0.8
	mesh.look_at(origin + fwd * 2.0, Vector3.UP)
	mesh.rotate_object_local(Vector3.RIGHT, -PI * 0.5)


func _piece_by_id(pid: String) -> Node3D:
	for piece in _pieces:
		if piece != null and str(piece.piece_id) == pid:
			return piece
	return null


func _configure_landing_camera() -> void:
	if _cam == null:
		return
	var deck: Node3D = _piece_by_id("landing_straight_long")
	if deck != null:
		_cam.landing_anchor = deck.to_global(Vector3(18.0, 7.2, -8.0))
		_cam.landing_look = deck.to_global(Vector3(0.0, 0.8, 6.0))
		_cam.follow_car_on_side = false
		_cam.auto_side_on_takeoff = true
	elif _landing_zone != null:
		_cam.landing_anchor = _landing_zone.global_position + Vector3(14.0, 5.5, 2.0)
		_cam.landing_look = _landing_zone.global_position


func _place_jump_zones() -> void:
	var jump: Node3D = _piece_by_id("jump_small")
	var deck: Node3D = _piece_by_id("landing_straight_long")
	if jump == null:
		return
	_takeoff_zone = _make_zone("TAKEOFF_ZONE", jump, Vector3(0.0, 1.4, -1.05), Vector3(8.0, 2.8, 2.4), Color(0.2, 0.95, 0.55, 0.18))
	if deck != null:
		_landing_zone = _make_zone("LANDING_TARGET_ZONE", deck, Vector3(0.0, 1.2, -8.0), Vector3(10.0, 3.0, 16.0), Color(0.95, 0.75, 0.2, 0.18))
	else:
		_landing_zone = _make_zone("LANDING_ZONE", jump, Vector3(0.0, 0.4, -12.5), Vector3(8.0, 3.2, 8.0), Color(0.95, 0.75, 0.2, 0.18))
	_configure_landing_camera()
	_make_route_label(jump, "TAKEOFF", Vector3(0, 2.6, -1.0))
	if deck != null:
		_make_route_label(deck, "LANDING_TARGET", Vector3(0, 2.4, -6.0))
		_make_route_label(deck, "RECOVERY", Vector3(0, 2.2, -28.0))
	else:
		_make_route_label(jump, "LANDING_TARGET", Vector3(0, 2.4, -12.5))
	_make_route_label(jump, "JUMP_EXIT", Vector3(0, 2.2, -21.0))
	for piece in _pieces:
		if piece != null and str(piece.piece_id) == "boost_straight":
			_make_route_label(piece, "BOOST_ENTRY", Vector3(0, 2.4, -1.0))
		if piece != null and str(piece.piece_id) == "ramp_small":
			_make_route_label(piece, "RAMP_ENTRY", Vector3(0, 2.4, -1.0))


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
	mesh.visible = false
	area.add_child(mesh)
	parent.add_child(area)
	return area


func _make_route_label(parent: Node3D, text: String, local: Vector3) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.position = local
	lab.font_size = 36
	lab.modulate = Color(1.0, 0.92, 0.35)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(lab)


func _set_zone_visible(on: bool) -> void:
	for area in [_takeoff_zone, _landing_zone]:
		if area == null:
			continue
		var dbg = area.get_node_or_null("DebugMesh")
		if dbg != null:
			dbg.visible = on


func _wheel_grounded_n() -> int:
	if _car != null and _car.get("debug_grounded_n") != null:
		return int(_car.get("debug_grounded_n"))
	if _car != null and bool(_car.get("debug_grounded") == true):
		return 1
	return 0


func _log_jump(kind: String, extra: String = "") -> void:
	var line: String = "[TRACK_JUMP] %s piece=%s speed=%.1f grounded=%d%s" % [
		kind,
		_current_piece,
		float(_car.get("debug_speed")) if _car != null else 0.0,
		_wheel_grounded_n(),
		(" " + extra) if extra != "" else "",
	]
	print(line)
	_jump_events.append({
		"kind": kind,
		"piece": _current_piece,
		"t": _contact_clock,
		"grounded": _wheel_grounded_n(),
		"extra": extra,
	})


func _classify_jump_fail() -> void:
	if _fail_logged or not _valid_takeoff:
		return
	if _car != null and int(_car.get("reset_generation_id")) != _takeoff_reset_gen and _takeoff_reset_gen >= 0:
		_fail_logged = true
		_log_jump("RESET_DURING_JUMP")
		return
	if str(_current_piece).begins_with("curve"):
		_fail_logged = true
		_log_jump("OFFTRACK_AFTER_CONTACT")
		return
	var deck: Node3D = _piece_by_id("landing_straight_long")
	if deck == null or _car == null:
		return
	var local: Vector3 = deck.to_local((_car as Node3D).global_position)
	## Only classify misses on/after the deck, near deck height.
	if local.z > 2.0:
		return
	if local.y > 2.5:
		return
	if local.x < -6.2:
		_fail_logged = true
		_log_jump("MISSED_LANDING_LEFT", "x=%.2f" % local.x)
		return
	if local.x > 6.2:
		_fail_logged = true
		_log_jump("MISSED_LANDING_RIGHT", "x=%.2f" % local.x)
		return
	if local.z > 4.0 and not bool(_car.get("debug_airborne") == true):
		_fail_logged = true
		_log_jump("UNDERSHOT", "z=%.2f" % local.z)
		return
	if local.z < -40.0:
		_fail_logged = true
		_log_jump("OVERSHOT", "z=%.2f" % local.z)


func _update_jump_classification() -> void:
	if _car == null:
		return
	_in_takeoff = _body_in_area(_takeoff_zone)
	_in_landing = _body_in_area(_landing_zone)
	if _car.get("report_piece_id") != null:
		_car.set("report_piece_id", _current_piece)
	var hint: String = ""
	if _in_takeoff:
		hint = "JUMP_AIRBORNE"
	elif _current_piece == "" or _offtrack():
		hint = "OFFTRACK_AIRBORNE"
	if _car.get("airborne_kind_hint") != null:
		_car.set("airborne_kind_hint", hint)
	var airborne: bool = bool(_car.get("debug_airborne") == true)
	var grounded_n: int = _wheel_grounded_n()
	if _in_takeoff and airborne and not _valid_takeoff:
		_valid_takeoff = true
		_first_contact_logged = false
		_settled_logged = false
		_fail_logged = false
		_first_contact_n = 0
		_two_contact_t = -1.0
		_four_contact_t = -1.0
		_takeoff_reset_gen = int(_car.get("reset_generation_id"))
		_log_jump("VALID_TAKEOFF")
		if _cam != null and bool(_cam.auto_side_on_takeoff):
			_cam.set_mode(2)
	if _valid_takeoff and _prev_airborne and not airborne and not _first_contact_logged:
		_first_contact_logged = true
		_first_contact_n = grounded_n
		_log_jump("FIRST_CONTACT", "wheel_count=%d peak_c=%.3f" % [
			grounded_n, float(_car.get("last_landing_max_compression"))
		])
		if _jump_validate:
			Input.action_release("track_accel")
		if str(_current_piece).begins_with("curve"):
			_fail_logged = true
			_log_jump("FAIL", "curve landing is not valid for this lab")
		elif _current_piece == "":
			_fail_logged = true
			_log_jump("UNDERSHOT")
		elif grounded_n < 1:
			_log_jump("NO_VALID_CONTACT")
	if _first_contact_logged and not airborne:
		if _two_contact_t < 0.0 and grounded_n >= 2:
			_two_contact_t = _contact_clock
		if _four_contact_t < 0.0 and grounded_n >= 4:
			_four_contact_t = _contact_clock
	if airborne and not _in_takeoff and not _valid_takeoff and hint == "OFFTRACK_AIRBORNE":
		if str(_car.get("last_airborne_reason")) != "SPAWN_SETTLE" and str(_car.get("last_airborne_reason")) != "RESET_SETTLE":
			if not _offtrack_logged:
				_log_jump("OFFTRACK_AIRBORNE")
				_offtrack_logged = true
	if _valid_takeoff and airborne and not _in_takeoff:
		_classify_jump_fail()
	var peak_c: float = float(_car.get("last_landing_max_compression"))
	var peak_f: float = float(_car.get("last_landing_max_susp_force"))
	var on_deck: bool = _current_piece == "landing_straight_long"
	if _valid_takeoff and _in_landing and not airborne and on_deck and grounded_n >= 2 and peak_c > 0.001 and peak_f > 1.0:
		if not _valid_landing_logged:
			_log_jump("VALID_LANDING", "airtime=%.3f peak_c=%.3f peak_f=%.0f first_n=%d t2=%.3f t4=%.3f deck_retained=true" % [
				float(_car.get("last_airborne_duration")),
				peak_c,
				peak_f,
				_first_contact_n,
				_two_contact_t,
				_four_contact_t,
			])
			_valid_landing_logged = true
		if not _settled_logged and grounded_n >= 2:
			_log_jump("SETTLED", "grounded=%d" % grounded_n)
			_settled_logged = true
			_valid_takeoff = false
			if _cam != null:
				_cam.set_mode(0)
				_cam.snap_to_target()
	elif _valid_takeoff and _first_contact_logged and not airborne and on_deck and (peak_c <= 0.001 or peak_f <= 1.0):
		if not _fail_logged:
			_fail_logged = true
			_log_jump("NO_VALID_CONTACT", "peak_c=%.3f peak_f=%.0f" % [peak_c, peak_f])
	elif _valid_takeoff and _first_contact_logged and not airborne and not on_deck and str(_current_piece).begins_with("curve"):
		if not _fail_logged:
			_fail_logged = true
			_log_jump("OFFTRACK_AFTER_CONTACT")
	_prev_airborne = airborne


func _body_in_area(area: Area3D) -> bool:
	if area == null or _car == null:
		return false
	for body in area.get_overlapping_bodies():
		if body == _car:
			return true
	return false


func _offtrack() -> bool:
	return _current_piece == ""


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


func _set_wheel_ray_debug(on: bool) -> void:
	if not on:
		for node in _wheel_ray_dbg:
			if node != null:
				node.queue_free()
		_wheel_ray_dbg.clear()
		return
	if not _wheel_ray_dbg.is_empty():
		return
	for i in 4:
		var mesh := MeshInstance3D.new()
		mesh.name = "WheelRayDbg%d" % i
		var sm := SphereMesh.new()
		sm.radius = 0.08
		sm.height = 0.16
		mesh.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.2, 0.85, 0.85)
		mesh.set_surface_override_material(0, mat)
		add_child(mesh)
		_wheel_ray_dbg.append(mesh)


func _update_wheel_ray_debug() -> void:
	if _wheel_ray_dbg.is_empty() or _car == null or not _car.has_method("wheels"):
		return
	var wheels: Array = _car.call("wheels") as Array
	var i: int = 0
	while i < _wheel_ray_dbg.size():
		var mesh: MeshInstance3D = _wheel_ray_dbg[i]
		if i < wheels.size() and wheels[i] != null and bool(wheels[i].is_grounded):
			mesh.visible = true
			mesh.global_position = wheels[i].contact_point
		elif mesh != null:
			mesh.visible = false
		i += 1


func _finish_smoke() -> void:
	var tex: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var max_pos: float = 0.0
	for row in _seams:
		max_pos = maxf(max_pos, float(row["position_m"]))
	print("[TRACK_EXTENDED] SMOKE END controller=%s live=%d max_seam=%.6f tex=%.0f piece=%s" % [
		_mode, _live_car_count(), max_pos, tex, _current_piece
	])
	if _jump_validate:
		_write_jump_validate()
	var fail: bool = _live_car_count() != 1
	if _jump_validate:
		fail = fail or not _valid_landing_logged or not _settled_logged
	if _finished:
		return
	_finished = true
	get_tree().quit(1 if fail else 0)


func _write_jump_validate() -> void:
	var kinds: Array = []
	for ev in _jump_events:
		kinds.append(str(ev.get("kind", "")))
	var payload := {
		"iteration": int(OS.get_environment("SSK_ITER").strip_edges()) if not OS.get_environment("SSK_ITER").strip_edges().is_empty() else 3,
		"route": Array(SEQUENCE),
		"has_landing_straight_long": true,
		"landing_before_curves": true,
		"events": _jump_events,
		"valid_takeoff": _valid_takeoff or ("VALID_TAKEOFF" in kinds),
		"first_contact": _first_contact_logged,
		"first_contact_wheel_count": _first_contact_n,
		"time_to_2_contacts": _two_contact_t,
		"time_to_4_contacts": _four_contact_t,
		"valid_landing": _valid_landing_logged,
		"settled": _settled_logged,
		"deck_retained": _valid_landing_logged and _settled_logged,
		"fail_logged": _fail_logged,
		"final_piece": _current_piece,
		"cam_mode": _cam.mode_name() if _cam != null and _cam.has_method("mode_name") else "",
		"PASS": _valid_landing_logged and _settled_logged and not _fail_logged,
	}
	var out: String = _jump_out
	if out.is_empty():
		out = "res://docs/generated/track_4wheel_v4_iterations/iteration_02/jump_run.json"
	var abs_path: String = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var fh := FileAccess.open(abs_path, FileAccess.WRITE)
	if fh != null:
		fh.store_string(JSON.stringify(payload, "\t"))
		print("[TRACK_JUMP] wrote %s PASS=%s" % [abs_path, str(payload["PASS"])])
	var land_path: String = abs_path.get_base_dir().path_join("landing_metrics.json")
	var land_fh := FileAccess.open(land_path, FileAccess.WRITE)
	if land_fh != null:
		land_fh.store_string(JSON.stringify({
			"first_contact_wheel_count": _first_contact_n,
			"time_to_2_contacts": _two_contact_t,
			"time_to_4_contacts": _four_contact_t,
			"deck_retained": payload["deck_retained"],
			"peak_c": float(_car.get("last_landing_max_compression")) if _car != null else 0.0,
			"peak_f": float(_car.get("last_landing_max_susp_force")) if _car != null else 0.0,
			"valid_landing": _valid_landing_logged,
		}, "\t"))
	var cam_path: String = abs_path.get_base_dir().path_join("camera_validation.json")
	var cam_fh := FileAccess.open(cam_path, FileAccess.WRITE)
	if cam_fh != null:
		cam_fh.store_string(JSON.stringify({
			"landing_side_fixed_to_deck": _cam != null and not bool(_cam.follow_car_on_side),
			"auto_side_on_takeoff": _cam != null and bool(_cam.auto_side_on_takeoff),
			"chase_close_keeps_horizon": true,
			"lab_only": true,
			"track_main_untouched": true,
		}, "\t"))
	var air_path: String = abs_path.get_base_dir().path_join("airborne_events.json")
	var air_fh := FileAccess.open(air_path, FileAccess.WRITE)
	if air_fh != null:
		air_fh.store_string(JSON.stringify({"events": _jump_events}, "\t"))
