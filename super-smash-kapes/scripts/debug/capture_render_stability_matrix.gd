extends Node3D

## Interactive D3D12 / GL reproduction harness.
## Case selected by SSK_STABILITY_CASE (A–L). Does not change gameplay scenes.

const VisualConfig := preload("res://scripts/track/track_car_visual_config.gd")
const VisualScript := preload("res://scripts/track/track_car_visual.gd")
const GhostScript := preload("res://scripts/track/track_ghost_player.gd")

var _case: String = "A"
var _hold_frames: int = 90
var _frame: int = 0
var _label: Label
var _first_mem := 0.0


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_case = OS.get_environment("SSK_STABILITY_CASE").strip_edges().to_upper()
	if _case.is_empty():
		_case = "A"
	var hold := OS.get_environment("SSK_STABILITY_FRAMES").strip_edges()
	if not hold.is_empty():
		_hold_frames = maxi(int(hold), 12)
	_place_environment()
	_place_hud()
	print("[STABILITY] CASE=%s START renderer=%s driver=%s gpu=%s" % [
		_case,
		str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		OS.get_environment("GODOT_RENDERING_DRIVER"),
		str(RenderingServer.get_video_adapter_name()),
	])
	_mount_case()
	_log_mem("after_mount")
	_first_mem = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	print("[STABILITY] atlas_id=%d ghost_mat=%d source_loaded=%s articulated_loaded=%s" % [
		TrackCarVisual.shared_atlas_id(),
		TrackCarVisual.ghost_material_id(),
		str(ResourceLoader.has_cached(VisualConfig.SOURCE_GLB)),
		str(ResourceLoader.has_cached(VisualConfig.PROCESSED_ARTICULATED_GLB)),
	])


func _process(_delta: float) -> void:
	_frame += 1
	if _label != null:
		_label.text = "STABILITY %s  frame=%d  tex=%.0f  video=%.0f" % [
			_case,
			_frame,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		]
	if _frame == 2:
		_log_mem("frame2")
	if _frame >= _hold_frames:
		_log_mem("end")
		print("[STABILITY] CASE=%s END frames=%d" % [_case, _frame])
		get_tree().quit(0)


func _mount_case() -> void:
	match _case:
		"A":
			_marker("EMPTY 3D")
		"B":
			_add_visual(false, Vector3.ZERO)
			_marker("FUSED SOURCE VISUAL")
		"C":
			_add_visual(true, Vector3.ZERO)
			_marker("ARTICULATED VISUAL")
		"D":
			_add_scene("res://scenes/track/TrackCar.tscn", Vector3(0, 1.15, 0))
			_marker("BASELINE WRAPPER")
		"E":
			_add_four_wheel_no_visual()
			_marker("4WHEEL NO CAR VISUAL")
		"F":
			_add_scene("res://scenes/track/TrackCarWheelPhysics.tscn", Vector3(0, 1.15, 0))
			_marker("4WHEEL + ARTICULATED")
		"G":
			_add_visual(false, Vector3(-3, 0, 0))
			_add_visual(true, Vector3(3, 0, 0))
			_marker("SOURCE + ARTICULATED RESIDENT")
		"H":
			_add_scene("res://scenes/debug/TrackWheelPhysicsLab.tscn", Vector3.ZERO)
			_marker("A/B LAB")
		"I":
			_add_track_main(0)
			_marker("TRACKMAIN 0 GHOSTS")
		"J":
			_add_track_main(1)
			_marker("TRACKMAIN 1 GHOST")
		"K":
			_add_track_main(4)
			_marker("TRACKMAIN 4 GHOSTS")
		"L":
			_add_scene("res://scenes/core/JeffreyBoot.tscn", Vector3.ZERO)
			_marker("FULL SHELL BOOT")
		_:
			push_error("[STABILITY] unknown case %s" % _case)
			_marker("UNKNOWN CASE")


func _add_visual(articulated: bool, origin: Vector3) -> void:
	var vis := Node3D.new()
	vis.set_script(VisualScript)
	vis.set("apply_runtime_transform", true)
	vis.set("use_articulated", articulated)
	vis.set("show_debug_pivots", false)
	vis.position = origin
	add_child(vis)


func _add_scene(path: String, origin: Vector3) -> void:
	if not ResourceLoader.exists(path):
		push_error("[STABILITY] missing %s" % path)
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("[STABILITY] failed load %s" % path)
		return
	var node: Node = packed.instantiate()
	if node is Node3D:
		(node as Node3D).position = origin
	add_child(node)
	if node.get("control_enabled") != null:
		node.set("control_enabled", true)


func _add_four_wheel_no_visual() -> void:
	var body := RigidBody3D.new()
	body.mass = 420.0
	body.position = Vector3(0, 1.15, 0)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 0.82, 3.55)
	col.shape = box
	col.position = Vector3(0, 0.48, 0)
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.8, 0.82, 3.55)
	mesh.mesh = bm
	mesh.position = Vector3(0, 0.48, 0)
	body.add_child(mesh)
	add_child(body)
	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(40, 0.4, 40)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	floor_body.position = Vector3(0, -0.2, 0)
	add_child(floor_body)


func _add_track_main(ghosts: int) -> void:
	_add_scene("res://scenes/track/TrackMain.tscn", Vector3.ZERO)
	if ghosts <= 0:
		return
	var samples: Array = []
	var a := Transform3D(Basis.IDENTITY, Vector3(0, 1.1, 0))
	var b := Transform3D(Basis.IDENTITY, Vector3(0, 1.1, -20))
	for i in 40:
		samples.append(a.interpolate_with(b, float(i) / 39.0))
	for i in ghosts:
		var ghost = GhostScript.new()
		ghost.name = "StabilityGhost%d" % i
		add_child(ghost)
		ghost.setup("ghost_%d" % i, samples)
		ghost.begin_playback()


func _place_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#5d6f7d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c8d4e0")
	env.ambient_light_energy = 0.5
	world.environment = env
	add_child(world)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.4, 8)
	cam.current = true
	add_child(cam)
	cam.look_at(Vector3(0, 0.6, 0))


func _place_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(_label)


func _marker(text: String) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.position = Vector3(0, 2.6, 0)
	lab.font_size = 48
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(lab)
	print("[STABILITY] CASE=%s visual=%s" % [_case, text])


func _log_mem(tag: String) -> void:
	print("[STABILITY] MEM tag=%s objects=%.0f resources=%.0f video=%.0f texture=%.0f" % [
		tag,
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
	])
