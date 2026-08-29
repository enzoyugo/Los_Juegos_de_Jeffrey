extends Node3D

## Dynamic chase camera situations. VISUAL_REVIEW_PENDING.

const Config := preload("res://scripts/track/track_config.gd")
const Assembler := preload("res://scripts/track/track_kit_assembler.gd")
const CamScript := preload("res://scripts/track/track_dynamic_chase_camera.gd")
const Telemetry := preload("res://scripts/track/track_debug_telemetry.gd")

const SEQ: PackedStringArray = ["start", "straight_long", "curve_l_45", "curve_r_90", "chicane_lr", "boost_straight", "crest_gentle", "finish"]

var _car
var _cam
var _label: Label


func _ready() -> void:
	Config.ensure_actions()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	add_child(sun)
	Assembler.assemble(self, SEQ)
	var packed: PackedScene = load("res://scenes/track/TrackCarWheelPhysics.tscn") as PackedScene
	_car = packed.instantiate()
	add_child(_car)
	_car.control_enabled = true
	_cam = CamScript.new()
	_cam.current = true
	add_child(_cam)
	_cam.target = _car.camera_target() if _car.has_method("camera_target") else _car
	if _car.has_method("reset_to"):
		_car.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 1.15, -2.6)))
	_cam.snap_to_target()
	_label = Label.new()
	_label.position = Vector2(12, 10)
	_label.add_theme_font_size_override("font_size", 16)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(_label)


func _process(_delta: float) -> void:
	if _cam == null:
		return
	_label.text = "CAM  fov=%.1f dist=%.1f speed=%.1f drift=%s air=%s" % [
		_cam.last_fov,
		_cam.last_distance,
		Telemetry.debug_float(_car, "debug_speed", 0.0),
		Telemetry.debug_string(_car, "drift_state", "-"),
		str(Telemetry.debug_bool(_car, "debug_airborne", false)),
	]
	if not is_finite(_cam.last_fov) or _cam.last_fov < 60.0 or _cam.last_fov > 92.0:
		push_error("[TRACK_CAMERA] FOV out of bounds")
