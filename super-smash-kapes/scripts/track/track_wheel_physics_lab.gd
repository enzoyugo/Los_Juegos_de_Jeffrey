class_name TrackWheelPhysicsLab
extends Node3D

## Deterministic A/B course for FOUR_WHEEL_V1 vs BASELINE. Not the procedural generator.

const Config := preload("res://scripts/track/track_config.gd")
const BASELINE_SCENE_PATH := "res://scenes/track/TrackCar.tscn"
const FOUR_WHEEL_SCENE_PATH := "res://scenes/track/TrackCarWheelPhysics.tscn"
const CamScript := preload("res://scripts/track/track_camera.gd")

const MODE_BASELINE := "BASELINE"
const MODE_FOUR_WHEEL := "4WHEEL_V1"

var _car
var _cam
var _label: Label
var _hud_on: bool = true
var _mode: String = MODE_FOUR_WHEEL
var _mat_cache: Dictionary = {}
var _spawn := Transform3D(Basis.IDENTITY, Vector3(0, 1.15, 4))


func _ready() -> void:
	Config.ensure_actions()
	_place_world()
	_place_environment()
	_place_hud()
	_cam = CamScript.new()
	_cam.name = "ChaseCam"
	_cam.current = true
	add_child(_cam)
	_spawn_car(_mode)


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
			if _car != null and _car.has_method("set_collider_visible"):
				var debug_node = _car.get_node_or_null("ColliderDebug")
				var on := true
				if debug_node != null:
					on = not bool(debug_node.visible)
				_car.call("set_collider_visible", on)
			get_viewport().set_input_as_handled()
		KEY_F5:
			_toggle_controller()
			get_viewport().set_input_as_handled()
		KEY_V:
			if _car != null:
				var vis = _car.get_node_or_null("VisualRoot")
				if vis != null and vis.has_method("cycle_articulation_mode"):
					vis.call("cycle_articulation_mode")
			get_viewport().set_input_as_handled()
		KEY_B:
			TrackPiece.boost_gameplay_enabled = not TrackPiece.boost_gameplay_enabled
			print("[TRACK_WHEEL_LAB] boost_enabled=%s" % str(TrackPiece.boost_gameplay_enabled))
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
			if _car != null and _car.has_method("reset_to"):
				_car.call("reset_to", _spawn)
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_refresh_hud()


func _toggle_controller() -> void:
	var xform := _spawn
	if _car != null and _car is Node3D:
		xform = (_car as Node3D).global_transform
	_mode = MODE_BASELINE if _mode == MODE_FOUR_WHEEL else MODE_FOUR_WHEEL
	_spawn_car(_mode)
	if _car != null and _car.has_method("reset_to"):
		_car.call("reset_to", xform)
	print("[TRACK_WHEEL_LAB] live_track_car_count=%d" % get_tree().get_nodes_in_group("track_runtime_car").size())


func _set_visual_mode(mode: int) -> void:
	if _car == null:
		return
	var vis = _car.get_node_or_null("VisualRoot")
	if vis != null and vis.has_method("set_articulation_mode"):
		vis.call("set_articulation_mode", mode)


func _load_scene(path: String):
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("[TRACK_WHEEL_LAB] failed to load %s" % path)
		return null
	return packed.instantiate()


func _spawn_car(mode: String) -> void:
	if _car != null:
		var old = _car
		_car = null
		if old.get_parent() == self:
			remove_child(old)
		old.free()
	if mode == MODE_FOUR_WHEEL:
		_car = _load_scene(FOUR_WHEEL_SCENE_PATH)
	else:
		_car = _load_scene(BASELINE_SCENE_PATH)
	if _car == null:
		return
	add_child(_car)
	if _car.has_method("reset_to"):
		_car.call("reset_to", _spawn)
	else:
		_car.global_transform = _spawn
	_car.control_enabled = true
	if _cam != null:
		_cam.target = _car.camera_target() if _car.has_method("camera_target") else _car
		if _cam.has_method("snap_to_target"):
			_cam.snap_to_target()
	print("[TRACK_WHEEL_LAB] CONTROLLER=%s" % mode)


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
		"TRACK WHEEL PHYSICS LAB",
		"CONTROLLER: %s" % _mode,
		"road %.1f m  rails h=%.2f  HUMAN_A_B_DRIVE_REVIEW_REQUIRED" % [Config.ROAD_WIDTH, Config.GUARDRAIL_HEIGHT],
	])
	if _car != null and _car.has_method("debug_hud_lines"):
		lines.append_array(_car.debug_hud_lines())
	elif _car != null:
		lines.append("speed %.1f  steer %.2f  drift %s" % [
			float(_car.get("debug_speed")),
			float(_car.get("debug_steer")),
			str(_car.get("drift_state")),
		])
		lines.append("F3 HUD · F4 collider · F5 A/B · C reset · WASD · Shift drift")
	_label.text = "\n".join(lines)


func _place_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#6f8699")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c8d4e0")
	env.ambient_light_energy = 0.55
	world.environment = env
	add_child(world)


func _place_world() -> void:
	var w := Config.ROAD_WIDTH
	## A STRAIGHT
	_road_box(Vector3(0, -0.4, 28), Vector3(w, 0.8, 56), true, Color("#3d424c"))
	_marker(Vector3(0, 1.4, 8), "A STRAIGHT")
	## B SLALOM
	_road_box(Vector3(0, -0.4, 72), Vector3(w, 0.8, 32), true, Color("#3a4048"))
	_marker(Vector3(0, 1.4, 58), "B SLALOM")
	for i in 5:
		var side := -1.0 if i % 2 == 0 else 1.0
		_box(Vector3(side * 2.4, 0.45, 62.0 + float(i) * 5.5), Vector3(0.7, 1.1, 1.1), Color("#c45a2e"))
	## C FAST SWEEPER
	_marker(Vector3(0, 1.4, 90), "C SWEEPER")
	_arc("right", Vector3(14, 0, 102), 18.0, 10, PI * 0.55)
	## D HAIRPIN
	_marker(Vector3(28, 1.4, 118), "D HAIRPIN")
	_arc("left", Vector3(14, 0, 128), 10.5, 10, PI * 0.95)
	## E DRIFT CORNER
	_road_box(Vector3(-2, -0.4, 148), Vector3(w + 2.0, 0.8, 22), true, Color("#414650"))
	_marker(Vector3(-2, 1.4, 140), "E DRIFT")
	_arc("right", Vector3(12, 0, 168), 14.0, 8, PI * 0.7)
	## F BUMPS
	_road_box(Vector3(24, -0.4, 190), Vector3(w, 0.8, 28), true, Color("#3d424c"))
	_marker(Vector3(24, 1.4, 178), "F BUMPS")
	_box(Vector3(21.2, 0.12, 186), Vector3(3.2, 0.28, 2.2), Color("#5a6570"))
	_box(Vector3(26.8, 0.12, 194), Vector3(3.2, 0.28, 2.2), Color("#5a6570"))
	_box(Vector3(21.2, 0.16, 202), Vector3(3.2, 0.36, 2.2), Color("#5a6570"))
	## G JUMP
	_road_box(Vector3(24, -0.05, 216), Vector3(w, 0.8, 12), true, Color("#3d424c"))
	_marker(Vector3(24, 1.6, 210), "G JUMP")
	_box(Vector3(24, 0.35, 222), Vector3(w, 0.5, 6), Color("#4a5560"))
	## gap has no geometry
	_road_box(Vector3(24, -0.4, 242), Vector3(w, 0.8, 18), true, Color("#3d424c"))
	## H GUARDRAIL
	_road_box(Vector3(24, -0.4, 268), Vector3(w, 0.8, 28), true, Color("#3d424c"))
	_marker(Vector3(24, 1.4, 254), "H RAILS")
	_box(Vector3(18.2, 0.55, 268), Vector3(0.35, 1.1, 10), Color("#9aa0aa"))
	_box(Vector3(29.8, 0.55, 268), Vector3(0.35, 1.1, 10), Color("#9aa0aa"))


func _arc(kind: String, origin: Vector3, radius: float, steps: int, span: float) -> void:
	for i in range(steps):
		var t := float(i) / float(maxi(steps - 1, 1))
		var ang := lerpf(0.0, span, t)
		if kind == "left":
			ang = -ang
		var pos := origin + Vector3(sin(ang) * radius, -0.4, cos(ang) * radius)
		var xform := Transform3D(Basis.from_euler(Vector3(0, ang, 0)), pos)
		_box_at(xform, Vector3(Config.ROAD_WIDTH, 0.8, 6.5), Color("#414650"))
		_rails_at(xform, Config.ROAD_WIDTH, 6.5)


func _road_box(origin: Vector3, size: Vector3, rails: bool, color: Color) -> void:
	_box(origin, size, color)
	if rails:
		var xform := Transform3D(Basis.IDENTITY, origin)
		_rails_at(xform, size.x, size.z)


func _rails_at(xform: Transform3D, width: float, length: float) -> void:
	var sh := Config.ROAD_SHOULDER
	var th := Config.GUARDRAIL_THICKNESS
	var hh := Config.GUARDRAIL_HEIGHT
	var y := 0.4 + hh * 0.5
	var left := xform * Transform3D(Basis.IDENTITY, Vector3(-(width * 0.5 + sh + th * 0.5), y, 0.0))
	var right := xform * Transform3D(Basis.IDENTITY, Vector3(width * 0.5 + sh + th * 0.5, y, 0.0))
	_box_at(left, Vector3(th, hh, length), Color("#9aa0aa"))
	_box_at(right, Vector3(th, hh, length), Color("#9aa0aa"))
	_box_at(xform * Transform3D(Basis.IDENTITY, Vector3(-(width * 0.5 + sh * 0.5), 0.02, 0.0)), Vector3(sh, 0.7, length), Color("#4d5460"))
	_box_at(xform * Transform3D(Basis.IDENTITY, Vector3(width * 0.5 + sh * 0.5, 0.02, 0.0)), Vector3(sh, 0.7, length), Color("#4d5460"))


func _box(origin: Vector3, size: Vector3, color: Color) -> void:
	_box_at(Transform3D(Basis.IDENTITY, origin), size, color)


func _box_at(xform: Transform3D, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = xform
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.set_surface_override_material(0, _shared_color(color))
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _shared_color(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	_mat_cache[key] = mat
	return mat


func _marker(pos: Vector3, text: String) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.position = pos
	lab.font_size = 48
	lab.modulate = Color(1, 0.92, 0.55)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(lab)
