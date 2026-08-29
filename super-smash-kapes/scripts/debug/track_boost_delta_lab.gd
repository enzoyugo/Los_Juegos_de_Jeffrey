extends Node3D

## BASELINE boost speed-delta. Two in-process runs. Not a 4WHEEL lab.

const Config := preload("res://scripts/track/track_config.gd")
const FeedbackScript := preload("res://scripts/track/track_boost_feedback.gd")

const BASELINE_SCENE_PATH := "res://scenes/track/TrackCar.tscn"
const PIECE_SCENE := "res://scenes/track/modules/TrackPiece.tscn"
const OUT_PATH := "res://docs/generated/track_boost_v3/delta.json"
const SEQ: PackedStringArray = ["start", "straight_medium", "boost_straight", "straight_medium", "finish"]
const PEAK_DELTA_MIN := 4.0
const RUN_TIMEOUT := 12.0

var _pieces: Array = []
var _car
var _spawn := Transform3D.IDENTITY
var _phase: int = 0
var _clock: float = 0.0
var _entered: bool = false
var _enter_t: float = -1.0
var _enter_speed: float = 0.0
var _s025: float = -1.0
var _s050: float = -1.0
var _end_speed: float = -1.0
var _peak: float = 0.0
var _boost_ended: bool = false
var _run_a: Dictionary = {}
var _run_b: Dictionary = {}
var _done: bool = false
var _feedback: Node
var _label: Label


func _ready() -> void:
	Config.ensure_actions()
	_place_environment()
	_place_hud()
	_assemble()
	_spawn_car()
	_begin_run(false)
	print("[TRACK_BOOST_DELTA] START")


func _physics_process(delta: float) -> void:
	if _done or _car == null:
		return
	_clock += delta
	var speed: float = 0.0
	if _car.has_method("planar_speed"):
		speed = float(_car.call("planar_speed"))
	else:
		speed = float(_car.get("debug_speed"))
	_peak = maxf(_peak, speed)
	if _entered:
		var age: float = _clock - _enter_t
		if _s025 < 0.0 and age >= 0.25:
			_s025 = speed
		if _s050 < 0.0 and age >= 0.50:
			_s050 = speed
		if not _boost_ended:
			if _phase == 0:
				if age >= Config.BOOST_DURATION:
					_end_speed = speed
					_boost_ended = true
			elif not bool(_car.get("boost_active")):
				_end_speed = speed
				_boost_ended = true
		if _boost_ended and age >= Config.BOOST_DURATION + 0.35:
			_finish_run()
			return
	if _clock > RUN_TIMEOUT:
		if _entered and not _boost_ended:
			_end_speed = speed
			_boost_ended = true
		_finish_run()


func _assemble() -> void:
	var packed: PackedScene = load(PIECE_SCENE) as PackedScene
	var target := Transform3D.IDENTITY
	for id in SEQ:
		var piece = packed.instantiate()
		piece.piece_id = str(id)
		add_child(piece)
		piece.align_entry_to(target)
		_pieces.append(piece)
		target = piece.exit_global()
		if piece.boost_area != null and not piece.boost_area.body_entered.is_connected(_on_boost_body):
			piece.boost_area.body_entered.connect(_on_boost_body)
	var start_piece = _pieces[0]
	if start_piece != null and start_piece.player_spawn != null:
		_spawn = start_piece.player_spawn.global_transform
	else:
		_spawn = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.15, -2.6))


func _spawn_car() -> void:
	var packed: PackedScene = load(BASELINE_SCENE_PATH) as PackedScene
	_car = packed.instantiate()
	add_child(_car)
	_car.use_scripted_input = true
	_car.scripted_throttle = 1.0
	_car.scripted_steer = 0.0
	_car.control_enabled = true
	_car.call("reset_to", _spawn)
	_feedback = FeedbackScript.new()
	add_child(_feedback)
	if _feedback.has_method("setup"):
		_feedback.call("setup", _car, null)


func _begin_run(enable_boost: bool) -> void:
	TrackPiece.boost_gameplay_enabled = enable_boost
	_clock = 0.0
	_entered = false
	_enter_t = -1.0
	_enter_speed = 0.0
	_s025 = -1.0
	_s050 = -1.0
	_end_speed = -1.0
	_peak = 0.0
	_boost_ended = false
	if _car != null and _car.has_method("reset_to"):
		_car.call("reset_to", _spawn)
		_car.use_scripted_input = true
		_car.scripted_throttle = 1.0
		_car.scripted_steer = 0.0
		_car.control_enabled = true
	for piece in _pieces:
		if piece != null and piece.has_method("rearm_boost_trigger"):
			piece.call("rearm_boost_trigger")
	print("[TRACK_BOOST_DELTA] RUN %s" % ("B" if enable_boost else "A"))


func _on_boost_body(body: Node) -> void:
	if body != _car or _entered:
		return
	_entered = true
	_enter_t = _clock
	if _car.has_method("planar_speed"):
		_enter_speed = float(_car.call("planar_speed"))
	else:
		_enter_speed = float(_car.get("debug_speed"))
	_peak = maxf(_peak, _enter_speed)
	print("[TRACK_BOOST_DELTA] ENTRY phase=%d speed=%.2f" % [_phase, _enter_speed])


func _snapshot() -> Dictionary:
	return {
		"entry": _enter_speed,
		"t025": _s025,
		"t050": _s050,
		"end": _end_speed,
		"peak": _peak,
		"entered": _entered,
	}


func _finish_run() -> void:
	if _phase == 0:
		_run_a = _snapshot()
		_phase = 1
		_begin_run(true)
		return
	_run_b = _snapshot()
	_done = true
	TrackPiece.boost_gameplay_enabled = true
	var a_peak: float = float(_run_a.get("peak", 0.0))
	var b_peak: float = float(_run_b.get("peak", 0.0))
	var delta_v: float = b_peak - a_peak
	var ok: bool = bool(_run_a.get("entered", false)) and bool(_run_b.get("entered", false)) and delta_v >= PEAK_DELTA_MIN
	var payload := {
		"run_a": _run_a,
		"run_b": _run_b,
		"peak_delta": delta_v,
		"peak_delta_min": PEAK_DELTA_MIN,
		"ok": ok,
		"controller": "BASELINE",
		"boost_duration": Config.BOOST_DURATION,
		"boost_overspeed": Config.BOOST_OVERSPEED,
	}
	_write_json(OUT_PATH, payload)
	if ok:
		print("[TRACK_BOOST_DELTA] PASS a_peak=%.2f b_peak=%.2f delta=%.2f" % [a_peak, b_peak, delta_v])
		get_tree().quit(0)
	else:
		print("[TRACK_BOOST_DELTA] FAIL a_peak=%.2f b_peak=%.2f delta=%.2f" % [a_peak, b_peak, delta_v])
		get_tree().quit(1)


func _write_json(path: String, payload: Dictionary) -> void:
	var dir_path := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "  "))
		print("[TRACK_BOOST_DELTA] wrote %s" % path)


func _place_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(14, 10)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	layer.add_child(_label)
	_label.text = "BOOST DELTA LAB"


func _place_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#5c6b78")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c5d0da")
	env.ambient_light_energy = 0.5
	world.environment = env
	add_child(world)
