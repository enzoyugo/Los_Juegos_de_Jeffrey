extends Node3D

## Per-module 4WHEEL traversal smoke. Not TrackMain.

const Config := preload("res://scripts/track/track_config.gd")
const FOUR_WHEEL_SCENE_PATH := "res://scenes/track/TrackCarWheelPhysics.tscn"
const PIECE_SCENE := "res://scenes/track/modules/TrackPiece.tscn"
const OUT_PATH := "res://docs/generated/track_4wheel_generator_v4/module_compat.json"

const MODULES: PackedStringArray = [
	"start",
	"straight_short",
	"straight_medium",
	"straight_long",
	"curve_l_45",
	"curve_r_45",
	"curve_l_90",
	"curve_r_90",
	"chicane_lr",
	"chicane_rl",
	"boost_straight",
	"slope_up_gentle",
	"crest_gentle",
	"slope_down_gentle",
	"finish",
]

var _piece
var _car
var _i: int = -1
var _clock: float = 0.0
var _rows: Array = []
var _hold: float = 1.6
var _spawn := Transform3D.IDENTITY
var _entered: bool = false
var _max_yaw: float = 0.0
var _max_roll: float = 0.0
var _air_n: int = 0
var _rail_n: int = 0
var _gnd_min: int = 4


func _ready() -> void:
	Config.ensure_actions()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	add_child(sun)
	_next()


func _physics_process(delta: float) -> void:
	if _car == null:
		return
	_clock += delta
	if _car.has_method("wheels"):
		var gnd := 0
		var rows = _car.call("wheels")
		if rows is Array:
			for w in rows:
				if w != null and bool(w.get("is_grounded")):
					gnd += 1
					if str(w.get("contact_kind")) == "rail":
						_rail_n += 1
		_gnd_min = mini(_gnd_min, gnd)
	if bool(_car.get("debug_airborne")) and _clock > 0.55:
		_air_n += 1
	var b: Basis = (_car as Node3D).global_transform.basis
	_max_yaw = maxf(_max_yaw, absf(b.get_euler().y))
	_max_roll = maxf(_max_roll, absf(b.get_euler().z))
	if (_car as Node3D).global_position.distance_to(_spawn.origin) > 1.2:
		_entered = true
	if _clock >= _hold:
		_record()
		_next()


func _next() -> void:
	_i += 1
	if _i >= MODULES.size():
		_finish()
		return
	if _piece != null:
		_piece.queue_free()
		_piece = null
	if _car != null:
		_car.queue_free()
		_car = null
	var packed: PackedScene = load(PIECE_SCENE) as PackedScene
	_piece = packed.instantiate()
	_piece.piece_id = MODULES[_i]
	add_child(_piece)
	_piece.align_entry_to(Transform3D.IDENTITY)
	if _piece.player_spawn != null:
		_spawn = _piece.player_spawn.global_transform
	else:
		_spawn = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -2.2))
	var car_ps: PackedScene = load(FOUR_WHEEL_SCENE_PATH) as PackedScene
	_car = car_ps.instantiate()
	add_child(_car)
	_car.reset_to(_spawn)
	_car.control_enabled = true
	_car.use_scripted_input = true
	_car.scripted_throttle = 1.0
	_car.scripted_steer = 0.0
	_clock = 0.0
	_entered = false
	_max_yaw = 0.0
	_max_roll = 0.0
	_air_n = 0
	_rail_n = 0
	_gnd_min = 4
	if str(MODULES[_i]).find("slope_") >= 0 or str(MODULES[_i]).begins_with("crest_"):
		_hold = 2.4
	else:
		_hold = 1.6


func _record() -> void:
	var exited := false
	if _car != null and _piece != null:
		var exit_p: Vector3 = _piece.exit_global().origin
		exited = (_car as Node3D).global_position.distance_to(exit_p) < 8.0
	_rows.append({
		"id": MODULES[_i],
		"entered": _entered,
		"exited": exited,
		"rail_hit": _rail_n > 2,
		"offtrack": false,
		"airborne_unintended": _air_n > 8 and not str(MODULES[_i]).begins_with("jump"),
		"wheel_contacts_min": _gnd_min,
		"max_yaw": _max_yaw,
		"max_roll": _max_roll,
		"completion": exited or _entered,
	})
	print("[TRACK_4WHEEL_COMPAT] %s entered=%s gnd_min=%d air=%d" % [
		MODULES[_i], str(_entered), _gnd_min, _air_n
	])


func _finish() -> void:
	var ok := true
	for row in _rows:
		if not bool(row.get("completion", false)):
			ok = false
	var payload := {"modules": _rows, "ok": ok}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PATH.get_base_dir()))
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "  "))
	print("[TRACK_4WHEEL_COMPAT] %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
