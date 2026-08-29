extends Node3D

## Compare 14 / 15 / 16 m road width. Measurement lab. Not canonical.

const Config := preload("res://scripts/track/track_config.gd")
const Assembler := preload("res://scripts/track/track_kit_assembler.gd")
const Width := preload("res://scripts/track/track_width_policy.gd")
const CamScript := preload("res://scripts/track/track_dynamic_chase_camera.gd")

const SEQ: PackedStringArray = ["start", "straight_medium", "curve_r_90", "straight_short", "boost_straight", "crest_gentle", "finish"]

var _car
var _cam
var _label: Label
var _lane: int = 1
var _widths: Array = [Config.ROAD_WIDTH_LAB_14, Config.ROAD_WIDTH_LAB_15, Config.ROAD_WIDTH_LAB_16]
var _spawns: Array = []


func _ready() -> void:
	Config.ensure_actions()
	_sun()
	_label = Label.new()
	_label.position = Vector2(12, 10)
	_label.add_theme_font_size_override("font_size", 16)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(_label)
	for i in 3:
		var root := Node3D.new()
		root.name = "Lane_%d" % int(_widths[i])
		root.position = Vector3(float(i) * 48.0 - 48.0, 0, 0)
		add_child(root)
		var built: Dictionary = Assembler.assemble(root, SEQ)
		var pieces: Array = built["pieces"]
		for p in pieces:
			Width.apply_local_x(p, float(_widths[i]))
		var spawn: Transform3D = built["spawn"]
		spawn.origin += root.position
		_spawns.append(spawn)
	_spawn_car()
	print("[TRACK_WIDTH] 1=14m 2=15m 3=16m  candidate=15 VISUAL_REVIEW_PENDING")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_1:
		_lane = 0
		_reset()
	elif event.keycode == KEY_2:
		_lane = 1
		_reset()
	elif event.keycode == KEY_3:
		_lane = 2
		_reset()


func _process(_delta: float) -> void:
	_label.text = "WIDTH LAB  lane=%.0fm  (candidate 15)  1/2/3 switch  WASD" % float(_widths[_lane])


func _spawn_car() -> void:
	var packed: PackedScene = load("res://scenes/track/TrackCarWheelPhysics.tscn") as PackedScene
	_car = packed.instantiate()
	add_child(_car)
	_car.control_enabled = true
	_cam = CamScript.new()
	_cam.current = true
	add_child(_cam)
	_cam.target = _car.camera_target() if _car.has_method("camera_target") else _car
	_reset()


func _reset() -> void:
	var xf: Transform3D = _spawns[_lane]
	if _car.has_method("reset_to"):
		_car.reset_to(xf)
	_cam.snap_to_target()


func _sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 30, 0)
	add_child(sun)
