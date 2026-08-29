extends Node3D

## Intentional arcade drift lab. No suspension retune.

const Config := preload("res://scripts/track/track_config.gd")
const Assembler := preload("res://scripts/track/track_kit_assembler.gd")
const CamScript := preload("res://scripts/track/track_dynamic_chase_camera.gd")
const SkidScript := preload("res://scripts/track/track_skid_marks.gd")
const Telemetry := preload("res://scripts/track/track_debug_telemetry.gd")

const SEQ: PackedStringArray = ["start", "straight_long", "curve_r_90", "straight_medium", "curve_l_90", "finish"]

var _car
var _label: Label
var _entered: bool = false


func _ready() -> void:
	Config.ensure_actions()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 24, 0)
	add_child(sun)
	Assembler.assemble(self, SEQ)
	var packed: PackedScene = load("res://scenes/track/TrackCarWheelPhysics.tscn") as PackedScene
	_car = packed.instantiate()
	add_child(_car)
	_car.control_enabled = true
	var cam = CamScript.new()
	cam.current = true
	add_child(cam)
	cam.target = _car.camera_target() if _car.has_method("camera_target") else _car
	_car.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 1.15, -2.6)))
	cam.snap_to_target()
	var skid = SkidScript.new()
	add_child(skid)
	skid.setup(_car)
	_label = Label.new()
	_label.position = Vector2(12, 10)
	_label.add_theme_font_size_override("font_size", 16)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(_label)
	print("[TRACK_DRIFT] Shift+steer+speed  VISUAL_REVIEW_PENDING")


func _process(_delta: float) -> void:
	var st := Telemetry.debug_string(_car, "drift_state", "grip")
	var slip := Telemetry.debug_float(_car, "debug_slip_angle", 0.0)
	if st == "drift" or st == "drift_entry":
		if not _entered:
			_entered = true
			print("[TRACK_DRIFT] ENTER slip=%.2f" % slip)
	elif st == "grip":
		_entered = false
	_label.text = "DRIFT %s  slip %.2f  speed %.1f  yaw %.2f" % [
		st,
		slip,
		Telemetry.debug_float(_car, "debug_speed", 0.0),
		Telemetry.debug_float(_car, "debug_yaw_rate", 0.0),
	]
