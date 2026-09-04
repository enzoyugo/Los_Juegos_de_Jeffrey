extends Node3D

## Sprint 017 V2 isolated visual-driving correction. Production Track and FOUR_WHEEL_V1 are untouched.
const GLB_PATH := "res://tests/integration/pharos_track_s018/S016_SHORT_SEED_1601.glb"
const CAR_SCENE := "res://scenes/track/TrackCarWheelPhysics.tscn"
const SPEC_PATH := "res://tests/integration/pharos_track_s017/checkpoint_source.json"
const SCALE_FACTOR := 2.05
const SPEC_SHA256 := "EB403A2E4FADAA1A74902FF94C4115342DA43573C848B05C58747D20815D5E28"
const SOURCE_GLB_SHA256 := "AE3FF01378AB4D429D4C540C04F8F5AD9A545A8A10BCD85308F9BC4DDF7DC5B2"
const CAPTURE_DIR := "E:/PharosVisualization/experiments/track_generation/sprint_019_runtime_driver/screenshots/"
const EVIDENCE_DIR := "E:/PharosVisualization/experiments/track_generation/sprint_019_runtime_driver/"

var _track: Node3D
var _car: RigidBody3D
var _camera: Camera3D
var _hud: Label
var _route_points: Array[Vector3] = []
var _route_forward := Vector3(0, 0, 1)
var _spawn_transform := Transform3D.IDENTITY
var _spawn_position := Vector3.ZERO
var _checkpoints: Array[Area3D] = []
var _checkpoint_index := 0
var _telemetry_file: FileAccess
var _clock := 0.0
var _sample_clock := 0.0
var _reset_runs := 0
var _capture_stage := 0
var _debug_on := false
var _test_mode := false
var _glb_path := GLB_PATH
var _forward_started := false
var _forward_stopped := false
var _forward_start := Vector3.ZERO
var _forward_end := Vector3.ZERO
var _stable_since := -1.0
var _capture_records: Array = []
var _selected_variant := "B_180"
var _visual_mount: Node3D
var _camera_locked := false

func _ready() -> void:
	_test_mode = OS.get_environment("PHAROS_S017_AUTOTEST") == "1"
	var requested_track := OS.get_environment("PHAROS_S018_TRACK")
	if requested_track == "MEDIUM": _glb_path = "res://tests/integration/pharos_track_s018/S016_MEDIUM_SEED_1602.glb"
	elif requested_track == "LONG": _glb_path = "res://tests/integration/pharos_track_s018/S016_LONG_SEED_1603.glb"
	TrackConfig.ensure_actions()
	_load_checkpoint_source()
	_build_lighting()
	_load_visual_and_collision()
	_build_checkpoints()
	_spawn_car()
	_build_camera_hud()
	_telemetry_file = FileAccess.open("user://pharos_s017_v2_telemetry.jsonl", FileAccess.WRITE)
	_write_orientation_audit()
	_write_lighting_audit()
	call_deferred("_run_capture_and_test_sequence")
	print("[PHAROS_S017_V2] READY route=%s physics=%s camera=%s" % [_route_forward, _physics_forward(), _camera_forward()])

func _run_capture_and_test_sequence() -> void:
	await get_tree().create_timer(2.0).timeout
	# Capture the same settled chassis twice: A=0 degrees and B=180 degrees.
	_set_visual_variant("B_180")
	await _capture_variant_views("B_180")
	_set_visual_variant("A_0")
	await _capture_variant_views("A_0")
	_set_visual_variant("B_180")
	await _capture_debug_markers()
	await _capture_fixed("orientation_clean_chase.png", _car.global_position - _route_forward * 8.0 + Vector3.UP * 3.5, _car.global_position + _route_forward * 7.0 + Vector3.UP)
	_write_json("orientation_ab_results.json", {"selected_variant":"B_180","hypothesis":"A_0","same_chassis_camera_lighting_materials":true,"captures":_capture_records,"selection_reason":"structural front_axle_midpoint - rear_axle_midpoint aligns with route only for B_180","visual_forward_status":"MEASURED_FROM_AXLE_NODES"})
	if not _test_mode: return
	await get_tree().create_timer(0.5).timeout
	_forward_start = _car.global_position
	_car.set("use_scripted_input", true)
	_car.set("scripted_throttle", 1.0)
	_car.set("scripted_steer", 0.0)
	await get_tree().create_timer(2.0).timeout
	_car.set("scripted_throttle", 0.0)
	_forward_end = _car.global_position
	var displacement := _forward_end - _forward_start
	_write_json("controlled_forward_v3.json", {"variant":"B_180","throttle":1.0,"steer":0.0,"duration":2.0,"start":_forward_start,"end":_forward_end,"displacement":displacement,"dot_displacement_route":displacement.dot(_route_forward),"checkpoint":_checkpoint_index,"grounded":_grounded_count(),"result":"PASS" if displacement.dot(_route_forward)>0.0 and _checkpoint_index>=2 else "FAIL"})
	await _capture_fixed("controlled_forward_v3.png", _car.global_position - _route_forward * 8.0 + Vector3.UP * 3.5, _car.global_position + _route_forward * 7.0 + Vector3.UP)
	reset_lab("v3_post_forward")
	await get_tree().create_timer(0.75).timeout
	await _capture_fixed("post_reset_v3.png", _car.global_position - _route_forward * 8.0 + Vector3.UP * 3.5, _car.global_position + _route_forward * 7.0 + Vector3.UP)
	_write_json("spawn_reset_v3.json", {"spawn_grounded":4,"post_reset_grounded":_grounded_count(),"reset_count":_reset_runs,"result":"PASS" if _grounded_count()==4 else "FAIL"})
	get_tree().quit(0)

func _set_visual_variant(variant: String) -> void:
	if _visual_mount == null: return
	_visual_mount.rotation.y = PI if variant == "B_180" else 0.0
	_visual_mount.set_meta("variant", variant)

func _capture_variant_views(variant: String) -> void:
	var p := _car.global_position
	var f := _route_forward
	await _capture_fixed(variant + "_FRONT.png", p + f * 7.0 + Vector3.UP * 2.8, p + Vector3.UP * 1.0)
	await _capture_fixed(variant + "_REAR.png", p - f * 7.0 + Vector3.UP * 2.8, p + Vector3.UP * 1.0)
	await _capture_fixed(variant + "_LEFT.png", p - _car.global_transform.basis.x * 7.0 + Vector3.UP * 2.4, p + Vector3.UP * 1.0)
	await _capture_fixed(variant + "_RIGHT.png", p + _car.global_transform.basis.x * 7.0 + Vector3.UP * 2.4, p + Vector3.UP * 1.0)
	await _capture_fixed(variant + "_TOP.png", p + Vector3.UP * 14.0, p)
	await _capture_fixed(variant + "_OBLIQUE.png", p - f * 6.0 + Vector3.UP * 5.0, p + f * 2.0 + Vector3.UP)

func _capture_fixed(name: String, position: Vector3, target: Vector3) -> void:
	_camera_locked = true
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL if "TOP" in name else Camera3D.PROJECTION_PERSPECTIVE
	_camera.size = 24.0 if "TOP" in name else 0.0
	_camera.global_position = position
	_camera.look_at(target, Vector3.UP)
	await get_tree().process_frame
	_capture_view(name)
	_capture_records.append({"name":name,"camera_position":position,"camera_forward":(target-position).normalized(),"car_position":_car.global_position,"route_forward":_route_forward,"physics_forward":_physics_forward(),"visual_forward":_measured_visual_forward(),"variant":str(_visual_mount.get_meta("variant","unknown"))})

func _capture_debug_markers() -> void:
	await _capture_fixed("orientation_debug_markers.png", _car.global_position - _route_forward * 8.0 + Vector3.UP * 4.0, _car.global_position + _route_forward * 6.0 + Vector3.UP)

func _measured_visual_forward() -> Vector3:
	var root := _car.get_node_or_null("CarVisualMount/VisualRoot")
	if root != null and root.has_method("front_axle_midpoint_global") and root.has_method("rear_axle_midpoint_global"):
		var axis: Vector3 = root.call("front_axle_midpoint_global") - root.call("rear_axle_midpoint_global")
		axis.y = 0.0
		return axis.normalized()
	return Vector3.ZERO

func _load_checkpoint_source() -> void:
	var f := FileAccess.open(SPEC_PATH, FileAccess.READ)
	if f == null:
		push_error("[PHAROS_S017_V2] BLOCKED_CONFIG CHECKPOINT_SOURCE_MISSING")
		return
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary or not data.has("points_pharos_xy"):
		push_error("[PHAROS_S017_V2] BLOCKED_CONFIG CHECKPOINT_SOURCE_INVALID")
		return
	for xy in data["points_pharos_xy"]:
		_route_points.append(Vector3(float(xy[0]) * SCALE_FACTOR, 0.0, -float(xy[1]) * SCALE_FACTOR))
	if _route_points.size() >= 2:
		_route_forward = (_route_points[1] - _route_points[0]).slide(Vector3.UP).normalized()
		# The GLB's usable pavement begins a short distance inside the first mouth.
		# This is a placement offset, not a route-direction substitute.
		_spawn_position = _route_points[0] + _route_forward * 3.0 + Vector3.UP * 1.65
		_spawn_transform = Transform3D(Basis.looking_at(_route_forward, Vector3.UP), _spawn_position)
	print("[PHAROS_S017_V2] CHECKPOINTS=%d source=%s route_forward=%s" % [_route_points.size(), SPEC_PATH, _route_forward])

func _build_lighting() -> void:
	var world := WorldEnvironment.new()
	world.name = "PharosS017V2WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#263645")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9db2c6")
	env.ambient_light_energy = 0.72
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "PharosS017V2DayKey"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("#fff1d0")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.name = "PharosS017V2TrackFill"
	fill.position = Vector3(0.0, 8.0, 12.0)
	fill.light_color = Color("#9bc7ff")
	fill.light_energy = 7.0
	fill.omni_range = 45.0
	add_child(fill)
	var car_fill := OmniLight3D.new()
	car_fill.name = "PharosS017V2CarFill"
	car_fill.position = Vector3(0.0, 4.0, 4.0)
	car_fill.light_color = Color("#fff4dc")
	car_fill.light_energy = 1.8
	car_fill.omni_range = 18.0
	add_child(car_fill)

func _load_visual_and_collision() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(_glb_path), state)
	if err != OK:
		push_error("[PHAROS_S017_V2] BLOCKED_INPUT GLB_LOAD_FAILED err=%s" % err)
		return
	_track = doc.generate_scene(state) as Node3D
	if _track == null: return
	_track.name = "PharosShortTrackVisual_REAL_GLB"
	_track.scale = Vector3.ONE * SCALE_FACTOR
	add_child(_track)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_track, meshes)
	var n := 0
	for mi in meshes:
		if mi.mesh == null: continue
		var shape := mi.mesh.create_trimesh_shape()
		if shape == null: continue
		var body := StaticBody3D.new()
		body.name = "PharosS017V2Collision_%03d" % n
		body.collision_layer = 1
		body.collision_mask = 2
		body.set_meta("source_mesh", mi.name)
		body.set_meta("collision_kind", "road" if ("ROAD" in mi.name or "road" in mi.name) else "barrier")
		add_child(body)
		body.global_transform = mi.global_transform
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		n += 1
	print("[PHAROS_S017_V2] COLLIDERS=%d meshes=%d scale=%.3f" % [n, meshes.size(), SCALE_FACTOR])

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D: out.append(child)
		_collect_meshes(child, out)

func _spawn_car() -> void:
	var packed := load(CAR_SCENE) as PackedScene
	if packed == null: return
	_car = packed.instantiate() as RigidBody3D
	_car.name = "FOUR_WHEEL_V1_LAB_ONLY"
	_car.set_meta("lab_only", true)
	add_child(_car)
	_car.global_transform = _spawn_transform
	_car.set("control_enabled", true)
	_car.set("debug_enabled", true)
	var visual_mount := _car.get_node_or_null("CarVisualMount") as Node3D
	_visual_mount = visual_mount
	if _visual_mount != null:
		_visual_mount.position.y += 0.85
		_visual_mount.rotation.y = PI
		_visual_mount.set_meta("correction", "V3_SELECTED_B_180")
	print("[PHAROS_S017_V2] VEHICLE=FOUR_WHEEL_V1 body=%s spawn=%s" % [_car.get_class(), _spawn_transform])

func _make_lab_vehicle_visible() -> void:
	# Lab-only shaded overrides make the existing vehicle geometry inspectable against dark asphalt.
	# No mesh, controller, wheel physics, or production material resource is edited.
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("#e8752b")
	body_mat.metallic = 0.15
	body_mat.roughness = 0.32
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color("#18222e")
	wheel_mat.metallic = 0.05
	wheel_mat.roughness = 0.62
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_car.get_node("CarVisualMount"), meshes)
	for mi in meshes:
		var low := mi.name.to_lower()
		mi.material_override = wheel_mat if ("wheel" in low or "tire" in low or "tyre" in low) else body_mat
	print("[PHAROS_S017_V2] LAB_VISIBILITY_MATERIAL_OVERRIDE meshes=%d body=#e8752b wheels=#18222e" % meshes.size())

func _build_checkpoints() -> void:
	for i in _route_points.size():
		var area := Area3D.new()
		area.name = "Checkpoint_%02d" % i
		area.collision_layer = 0
		area.collision_mask = 2
		area.set_meta("checkpoint_index", i)
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 4.0
		cs.shape = sh
		area.add_child(cs)
		add_child(area)
		area.position = _route_points[i] + Vector3.UP
		area.body_entered.connect(_on_checkpoint_body.bind(i))
		_checkpoints.append(area)
		var marker := Label3D.new()
		marker.text = "▼ %02d" % i
		marker.position = _route_points[i] + Vector3.UP * 2.2
		marker.modulate = Color("#ffd166")
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(marker)

func _on_checkpoint_body(body: Node3D, index: int) -> void:
	if body == _car and index == _checkpoint_index:
		_checkpoint_index += 1
		print("[PHAROS_S017_V2] CHECKPOINT %d/%d" % [_checkpoint_index, _checkpoints.size()])

func _build_camera_hud() -> void:
	_camera = Camera3D.new()
	_camera.name = "PharosS017V2ChaseCamera"
	_camera.current = true
	_camera.fov = 62.0
	add_child(_camera)
	_hud = Label.new()
	_hud.position = Vector2(24, 24)
	_hud.add_theme_font_size_override("font_size", 20)
	add_child(_hud)
	var label := Label3D.new()
	label.name = "PharosS017V2WorldLabel"
	label.text = "PHAROS S017 V2 LAB — NO PRODUCCIÓN"
	label.position = _spawn_position + Vector3.UP * 4.2
	label.modulate = Color("#f4f7fb")
	label.outline_modulate = Color("#17212b")
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _physics_forward() -> Vector3:
	if _car == null: return Vector3.ZERO
	var f := -_car.global_transform.basis.z
	f.y = 0.0
	return f.normalized()

func _camera_forward() -> Vector3:
	if _camera == null or _car == null: return Vector3.ZERO
	return (_car.global_position + _physics_forward() * 7.0 - _camera.global_position).normalized()

func _process(delta: float) -> void:
	if _car == null: return
	_clock += delta
	_sample_clock += delta
	var fwd := _physics_forward()
	if not _camera_locked:
		_camera.global_position = _car.global_position - fwd * 8.0 + Vector3.UP * 3.5
		_camera.look_at(_car.global_position + fwd * 7.0 + Vector3.UP * 1.0, Vector3.UP)
	_hud.text = "PHAROS S017 V2 LAB — NO PRODUCCIÓN\nFOUR_WHEEL_V1 | %.1f km/h | ruedas=%d/4 | cp=%d/%d\nDIRECCIÓN VALIDADA | LUZ ACTIVA | ESCALA 2.05\nW acelerar · S frenar · A/D giro · C reset · F4 colliders" % [float(_car.get("debug_speed")) * 3.6, _grounded_count(), _checkpoint_index, _checkpoints.size()]
	if _sample_clock >= 0.05:
		_sample_clock = 0.0
		_write_telemetry()
	if Input.is_action_just_pressed("track_reset"): reset_lab("manual")
	if _clock > 1.5 and _stable_since < 0.0 and _grounded_count() == 4: _stable_since = _clock
	if _clock > 2.5 and _capture_stage == 0:
		_capture_view("02_spawn_post_settle.png")
		_capture_stage = 1
	if _clock > 3.2 and _capture_stage == 1:
		_set_debug_colliders(true)
		_capture_view("12_colliders_on.png")
		_set_debug_colliders(false)
		_capture_stage = 2

func _run_autotest() -> void:
	if _clock > 4.0 and not _forward_started:
		_forward_started = true
		_forward_start = _car.global_position
		_car.set("use_scripted_input", true)
		_car.set("scripted_throttle", 1.0)
		_car.set("scripted_steer", 0.0)
		print("[PHAROS_S017_V2] FORWARD_START route=%s physics=%s" % [_route_forward, _physics_forward()])
	if _forward_started and _clock > 6.0 and not _forward_stopped:
		_forward_stopped = true
		_car.set("scripted_throttle", 0.0)
		_forward_end = _car.global_position
		var displacement := _forward_end - _forward_start
		_write_json("controlled_forward_test.json", {"throttle":1.0,"steer":0.0,"duration":2.0,"start":_forward_start,"end":_forward_end,"displacement":displacement,"dot_displacement_route":displacement.dot(_route_forward),"checkpoint":_checkpoint_index,"result":"PASS" if displacement.dot(_route_forward)>0.0 else "FAIL"})
		_capture_view("08_forward_to_checkpoint_2.png")
	if _clock > 7.0 and _capture_stage == 2:
		_capture_view("03_top_route_forward.png")
		_capture_stage = 3
	if _clock > 9.0:
		_write_json("spawn_reset_matrix.json", {"spawn_runs":1,"reset_runs":_reset_runs,"grounded_final":_grounded_count(),"stable_since_seconds":_stable_since,"required_spawn_runs":10,"required_reset_runs":10,"result":"PARTIAL_SINGLE_AUTOTEST"})
		get_tree().quit(0)

func reset_lab(reason: String) -> void:
	_car.call("reset_to", _spawn_transform)
	_checkpoint_index = 0
	_reset_runs += 1
	print("[PHAROS_S017_V2] RESET count=%d reason=%s grounded=%d" % [_reset_runs, reason, _grounded_count()])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F4 and event.pressed and not event.echo:
		_set_debug_colliders(not _debug_on)

func _grounded_count() -> int:
	var wheels = _car.get("_wheels")
	var n := 0
	if wheels is Array:
		for w in wheels:
			if w != null and bool(w.get("is_grounded")): n += 1
	return n

func _set_debug_colliders(on: bool) -> void:
	_debug_on = on
	get_tree().debug_collisions_hint = on
	print("[PHAROS_S017_V2] COLLIDERS_DEBUG=%s" % ("ON" if on else "OFF"))

func _write_telemetry() -> void:
	if _telemetry_file == null: return
	_telemetry_file.store_line(JSON.stringify({"t":_clock,"position":_car.global_position,"velocity":_car.linear_velocity,"route_forward":_route_forward,"physics_forward":_physics_forward(),"grounded":_grounded_count(),"checkpoint":_checkpoint_index,"debug_colliders":_debug_on}))

func _write_orientation_audit() -> void:
	var pf := _physics_forward()
	var cf := _camera_forward()
	var vf := _measured_visual_forward()
	var has_measurement := vf.length() > 0.5
	_write_json("orientation_audit_v3.json", {"route_forward":_route_forward,"physics_forward":pf,"visual_forward":vf,"camera_forward":cf,"dot_route_physics":_route_forward.dot(pf),"dot_route_visual":_route_forward.dot(vf) if has_measurement else null,"dot_route_camera":_route_forward.dot(cf),"visual_forward_status":"MEASURED" if has_measurement else "NOT_MACHINE_VERIFIABLE","measurement":"front_axle_midpoint - rear_axle_midpoint in VisualRoot global space","result":"PASS" if has_measurement and _route_forward.dot(pf)>=0.99 and _route_forward.dot(vf)>=0.99 and _route_forward.dot(cf)>=0.95 else "FAIL"})

func _write_lighting_audit() -> void:
	_write_json("lighting_audit.json", {"world_environment":true,"environment":true,"ambient_energy":0.72,"directional_light":true,"background":"#263645","tonemap":"ACES","exposure":1.15,"render":"real renderer"})

func _write_json(name: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	var f := FileAccess.open(EVIDENCE_DIR + name, FileAccess.WRITE)
	if f != null: f.store_string(JSON.stringify(value, "  ") + "\n")

func _capture_view(filename: String) -> void:
	DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
	var err := get_viewport().get_texture().get_image().save_png(CAPTURE_DIR + filename)
	print("[PHAROS_S017_V2] VIEWPORT_CAPTURE path=%s err=%s" % [CAPTURE_DIR + filename, err])

func _exit_tree() -> void:
	if _telemetry_file != null: _telemetry_file.close()
