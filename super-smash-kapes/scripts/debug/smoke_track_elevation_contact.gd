extends Node3D

## Composed gentle elevation contact. Isolated crest should not launch 4WHEEL.

const Config := preload("res://scripts/track/track_config.gd")
const PIECE_SCENE := "res://scenes/track/modules/TrackPiece.tscn"
const CAR_PATH := "res://scenes/track/TrackCarWheelPhysics.tscn"

const SEQ: PackedStringArray = ["start", "slope_up_gentle", "crest_gentle", "slope_down_gentle", "finish"]

var _car
var _clock: float = 0.0
var _air_n: int = 0
var _on_crest_air: int = 0


func _ready() -> void:
	Config.ensure_actions()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	add_child(sun)
	var packed: PackedScene = load(PIECE_SCENE) as PackedScene
	var target := Transform3D.IDENTITY
	for id in SEQ:
		var piece = packed.instantiate()
		piece.piece_id = id
		add_child(piece)
		piece.align_entry_to(target)
		target = piece.exit_global()
	var car_ps: PackedScene = load(CAR_PATH) as PackedScene
	_car = car_ps.instantiate()
	add_child(_car)
	var spawn := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -2.2))
	_car.reset_to(spawn)
	_car.control_enabled = true
	_car.use_scripted_input = true
	_car.scripted_throttle = 1.0
	print("[TRACK_ELEVATION] START seq=slope_up,crest,slope_down")


func _physics_process(delta: float) -> void:
	_clock += delta
	if _car != null and bool(_car.get("debug_airborne")):
		_air_n += 1
		if str(_car.get("report_piece_id")) == "crest_gentle":
			_on_crest_air += 1
	if _clock < 6.5:
		return
	var ok: bool = _on_crest_air < 12
	print("[TRACK_ELEVATION] air_frames=%d crest_air=%d %s" % [
		_air_n, _on_crest_air, "PASS" if ok else "FAIL"
	])
	get_tree().quit(0 if ok else 1)
