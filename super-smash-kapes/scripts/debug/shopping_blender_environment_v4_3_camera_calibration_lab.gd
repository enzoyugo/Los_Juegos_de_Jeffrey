extends Node3D

## SDS V4.3 REFERENCE CAMERA CALIBRATION LAB.
## Art frozen. Only ReviewCamera parameters change.
## Native viewport 1280x720. KEY_R reload calib JSON. KEY_P save raw PNG (no resize).

const ENV_V43 := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v4_3_candidate.glb"
const CALIB_PATH := "E:/JeffreyAIResearch/outputs/runtime-review/sds_camera_calibration/camera_calibration.json"
const CAPTURE_PATH := "E:/JeffreyAIResearch/outputs/runtime-review/sds_camera_calibration/godot_raw_capture.png"
const Probe := preload("res://scripts/debug/jeffrey_resource_probe.gd")

const VIEWPORT_W := 1280
const VIEWPORT_H := 720

@export var iteration: int = 0
@export var cam_x: float = 0.0
@export var cam_y: float = 2.4
@export var cam_z: float = 28.0
@export var yaw_deg: float = 0.0
@export var pitch_deg: float = -8.0
@export var roll_deg: float = 0.0
@export var fov: float = 62.0
@export var look_at_x: float = 0.0
@export var look_at_y: float = 4.2
@export var look_at_z: float = 9.2
@export var use_look_at: bool = true
@export var last_capture_ok: bool = false
@export var last_capture_w: int = 0
@export var last_capture_h: int = 0
@export var viewport_w: int = VIEWPORT_W
@export var viewport_h: int = VIEWPORT_H
var _capture_busy: bool = false


func _ready() -> void:
	_force_viewport()
	_world()
	_proxies()
	_load_env()
	var cam := Camera3D.new()
	cam.name = "ReviewCamera"
	cam.current = true
	add_child(cam)
	_load_calibration()
	_apply_camera()
	set_process_unhandled_input(true)
	Probe.dump("sds_v4_3_camera_calibration_lab", self)
	print("[SDS_CAM_CALIB] ready iter=%d fov=%.1f pos=(%.2f,%.2f,%.2f) HUMAN_REVIEW_REQUIRED" % [iteration, fov, cam_x, cam_y, cam_z])


func _force_viewport() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(VIEWPORT_W, VIEWPORT_H))
	var vp := get_viewport()
	if vp != null:
		vp.size = Vector2i(VIEWPORT_W, VIEWPORT_H)
	viewport_w = VIEWPORT_W
	viewport_h = VIEWPORT_H


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_R:
		_load_calibration()
		_apply_camera()
		print("[SDS_CAM_CALIB] reloaded iter=%d" % iteration)
	elif event.keycode == KEY_P:
		if not _capture_busy:
			_capture_busy = true
			_capture_raw()


func _load_calibration() -> void:
	if not FileAccess.file_exists(CALIB_PATH):
		print("[SDS_CAM_CALIB] missing calib json — using defaults")
		return
	var f := FileAccess.open(CALIB_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	iteration = int(data.get("iteration", iteration))
	var pos = data.get("position", {})
	if typeof(pos) == TYPE_DICTIONARY:
		cam_x = float(pos.get("x", cam_x))
		cam_y = float(pos.get("y", cam_y))
		cam_z = float(pos.get("z", cam_z))
	var rot = data.get("rotation_degrees", {})
	if typeof(rot) == TYPE_DICTIONARY:
		pitch_deg = float(rot.get("x", pitch_deg))
		yaw_deg = float(rot.get("y", yaw_deg))
		roll_deg = float(rot.get("z", roll_deg))
	fov = float(data.get("fov", fov))
	use_look_at = bool(data.get("use_look_at", use_look_at))
	var la = data.get("look_at", {})
	if typeof(la) == TYPE_DICTIONARY:
		look_at_x = float(la.get("x", look_at_x))
		look_at_y = float(la.get("y", look_at_y))
		look_at_z = float(la.get("z", look_at_z))


func _apply_camera() -> void:
	var cam := get_node_or_null("ReviewCamera") as Camera3D
	if cam == null:
		return
	cam.fov = clampf(fov, 35.0, 90.0)
	cam.global_position = Vector3(cam_x, cam_y, cam_z)
	if use_look_at:
		cam.look_at(Vector3(look_at_x, look_at_y, look_at_z), Vector3.UP)
	else:
		cam.rotation_degrees = Vector3(pitch_deg, yaw_deg, roll_deg)


func _capture_raw() -> void:
	## Dedicated SubViewport guarantees native 1280x720 without post-resize.
	var src := get_node_or_null("ReviewCamera") as Camera3D
	if src == null:
		last_capture_ok = false
		_capture_busy = false
		print("[SDS_CAM_CALIB] capture FAIL no ReviewCamera")
		return
	var sv := SubViewport.new()
	sv.name = "CalibCaptureViewport"
	sv.size = Vector2i(VIEWPORT_W, VIEWPORT_H)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	sv.world_3d = get_viewport().world_3d
	add_child(sv)
	var cam := Camera3D.new()
	cam.fov = src.fov
	cam.global_transform = src.global_transform
	cam.current = true
	sv.add_child(cam)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var image: Image = sv.get_texture().get_image()
	sv.queue_free()
	if image == null:
		last_capture_ok = false
		_capture_busy = false
		print("[SDS_CAM_CALIB] capture FAIL no image")
		return
	last_capture_w = image.get_width()
	last_capture_h = image.get_height()
	if last_capture_w != VIEWPORT_W or last_capture_h != VIEWPORT_H:
		last_capture_ok = false
		_capture_busy = false
		print("[SDS_CAM_CALIB] capture REJECT size=%dx%d want=%dx%d" % [last_capture_w, last_capture_h, VIEWPORT_W, VIEWPORT_H])
		return
	var err := image.save_png(CAPTURE_PATH)
	last_capture_ok = err == OK
	_capture_busy = false
	print("[SDS_CAM_CALIB] capture ok=%s path=%s %dx%d iter=%d" % [str(last_capture_ok), CAPTURE_PATH, last_capture_w, last_capture_h, iteration])


func _world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, 140, 0)
	sun.light_energy = 0.28
	sun.light_color = Color("#8aa0c4")
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0c1420")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#3d4c62")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	_omni(Vector3(0, 4.4, 11.0), 1.15, 14.0, Color("#ffc070"))
	_omni(Vector3(0, 7.2, 8.4), 0.85, 8.0, Color("#ffd050"))
	_omni(Vector3(-12.4, 2.2, 11.2), 0.9, 8.0, Color("#ffb060"))
	_omni(Vector3(12.4, 2.2, 11.2), 0.7, 8.0, Color("#ffb060"))
	_omni(Vector3(-6.4, 0.4, 10.6), 0.35, 4.0, Color("#4dff4a"))
	_omni(Vector3(6.4, 0.4, 10.6), 0.25, 4.0, Color("#4dff4a"))
	_omni(Vector3(0, 11.5, -14.0), 2.0, 20.0, Color("#ffe8c0"))


func _omni(pos: Vector3, energy: float, rng: float, color: Color) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_energy = energy
	light.omni_range = rng
	light.light_color = color
	add_child(light)


func _proxies() -> void:
	_box(Vector3(0, -0.5, 26.0), Vector3(48, 1, 34))
	_box(Vector3(0, -0.5, 8.9), Vector3(6.2, 1, 2.4))
	_box(Vector3(0, -0.5, -8.0), Vector3(16, 1, 28))


func _load_env() -> void:
	if not ResourceLoader.exists(ENV_V43):
		print("[SDS_CAM_CALIB] MISSING glb")
		return
	var packed: PackedScene = load(ENV_V43) as PackedScene
	if packed == null:
		print("[SDS_CAM_CALIB] FAIL instantiate")
		return
	var inst := packed.instantiate()
	inst.name = "BlenderEnvV4_3Candidate"
	add_child(inst)
	_strip(inst)
	print("[SDS_CAM_CALIB] loaded=%s" % ENV_V43)


func _box(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _strip(node: Node) -> void:
	for child in node.get_children():
		_strip(child)
	if node is AnimationPlayer:
		node.queue_free()
