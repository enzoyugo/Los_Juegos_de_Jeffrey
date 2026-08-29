extends Node3D

## Wrong-way boost must skip, not reverse-launch.

const Config := preload("res://scripts/track/track_config.gd")
const PIECE_SCENE := "res://scenes/track/modules/TrackPiece.tscn"
const CAR_PATH := "res://scenes/track/TrackCarWheelPhysics.tscn"

var _car
var _clock: float = 0.0
var _phase: int = 0


func _ready() -> void:
	Config.ensure_actions()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	add_child(sun)
	var packed: PackedScene = load(PIECE_SCENE) as PackedScene
	var piece = packed.instantiate()
	piece.piece_id = "boost_straight"
	add_child(piece)
	piece.align_entry_to(Transform3D.IDENTITY)
	var car_ps: PackedScene = load(CAR_PATH) as PackedScene
	_car = car_ps.instantiate()
	add_child(_car)
	var spawn := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -2.2))
	_car.reset_to(spawn)
	_car.rotate_y(PI)
	_car.control_enabled = true
	_car.use_scripted_input = true
	_car.scripted_throttle = 1.0
	print("[TRACK_BOOST_WRONG_WAY] START facing_opposite")


func _physics_process(delta: float) -> void:
	_clock += delta
	if _phase == 0 and _clock > 0.25:
		var fwd := Vector3(0, 0, -1)
		_car.apply_track_boost(fwd, 1.35)
		var applied := int(_car.get("boost_apply_count"))
		print("[TRACK_BOOST_WRONG_WAY] after_apply count=%d active=%s" % [applied, str(_car.get("boost_active"))])
		if applied == 0:
			print("[TRACK_BOOST_WRONG_WAY] PASS")
			get_tree().quit(0)
		else:
			print("[TRACK_BOOST_WRONG_WAY] FAIL apply_count=%d" % applied)
			get_tree().quit(1)
