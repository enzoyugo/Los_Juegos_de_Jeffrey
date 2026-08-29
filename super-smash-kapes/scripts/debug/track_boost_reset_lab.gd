extends Node3D

## Same-process Area3D boost rearm after reset_to. 4WHEEL only. Not a handling retune.

const Config := preload("res://scripts/track/track_config.gd")
const PIECE_SCENE := "res://scenes/track/modules/TrackPiece.tscn"
const FOUR_WHEEL_SCENE_PATH := "res://scenes/track/TrackCarWheelPhysics.tscn"
const AUDIT_PATH := "res://docs/generated/track_boost_reset/audit.json"
const SEQ: PackedStringArray = ["start", "boost_straight", "finish"]
const RUNS := 3
const RUN_TIMEOUT := 8.0
const POST_BOOST_HOLD := 0.35
const RESET_COOLDOWN := 0.4

var _pieces: Array = []
var _car
var _spawn := Transform3D.IDENTITY
var _run_index: int = 0
var _hits: Array = []
var _counted: bool = false
var _clock: float = 0.0
var _hold: float = -1.0
var _cooldown: float = 0.0
var _done: bool = false
var _smoke: bool = false
var _boost_logs: PackedStringArray = PackedStringArray()


func _ready() -> void:
	Config.ensure_actions()
	_smoke = OS.get_environment("SSK_BOOST_RESET_SMOKE").strip_edges() == "1" or OS.has_feature("headless")
	_place_environment()
	_assemble()
	_spawn_car()
	print("[TRACK_BOOST_RESET] START runs=%d" % RUNS)


func _physics_process(delta: float) -> void:
	if _done or _car == null:
		return
	if _cooldown > 0.0:
		_cooldown -= delta
		return
	_clock += delta
	if _hold >= 0.0:
		_hold -= delta
		if _hold <= 0.0:
			_hold = -1.0
			_advance_or_finish()
		return
	if not _counted and bool(_car.get("boost_active") == true):
		_register_boost("boost_active")
	if not _counted and _clock > RUN_TIMEOUT:
		_register_miss()
		_advance_or_finish()


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
	var packed: PackedScene = load(FOUR_WHEEL_SCENE_PATH) as PackedScene
	_car = packed.instantiate()
	add_child(_car)
	_car.use_scripted_input = true
	_car.scripted_throttle = 1.0
	_car.scripted_steer = 0.0
	_car.control_enabled = true
	if _car.has_method("reset_to"):
		_car.call("reset_to", _spawn)


func _on_boost_body(body: Node) -> void:
	if body != _car:
		return
	_register_boost("body_entered")


func _register_boost(source: String) -> void:
	if _counted or _done or _cooldown > 0.0:
		return
	_counted = true
	_hits.append(true)
	var msg := "[TRACK_BOOST_RESET] BOOST_ENTRY run=%d source=%s" % [_run_index + 1, source]
	_boost_logs.append(msg)
	print(msg)
	print("[TRACK_4WHEEL] BOOST run=%d" % (_run_index + 1))
	_hold = POST_BOOST_HOLD


func _register_miss() -> void:
	_counted = true
	_hits.append(false)
	var msg := "[TRACK_BOOST_RESET] MISS run=%d t=%.2f" % [_run_index + 1, _clock]
	_boost_logs.append(msg)
	print(msg)


func _advance_or_finish() -> void:
	if _hits.size() >= RUNS:
		_finish()
		return
	_run_index += 1
	_counted = false
	_clock = 0.0
	_hold = -1.0
	_cooldown = RESET_COOLDOWN
	if _car != null and _car.has_method("reset_to"):
		_car.call("reset_to", _spawn)
		_car.use_scripted_input = true
		_car.scripted_throttle = 1.0
		_car.scripted_steer = 0.0
	for piece in _pieces:
		if piece != null and piece.has_method("rearm_boost_trigger"):
			piece.call("rearm_boost_trigger")
	print("[TRACK_BOOST_RESET] NEXT_RUN %d" % (_run_index + 1))


func _finish() -> void:
	if _done:
		return
	_done = true
	var ok_n := 0
	for hit in _hits:
		if bool(hit):
			ok_n += 1
	var ok: bool = ok_n == RUNS
	var status := "TRACK_BOOST_RESET_OK" if ok else "TRACK_BOOST_RESET_PARTIAL"
	var payload := {
		"runs": RUNS,
		"hits": _hits,
		"ok_count": ok_n,
		"ok": ok,
		"status": status,
		"logs": Array(_boost_logs),
	}
	_write_json(AUDIT_PATH, payload)
	print("[TRACK_BOOST_RESET] %s %d/%d" % [status, ok_n, RUNS])
	if _smoke:
		get_tree().quit(0 if ok else 1)


func _write_json(path: String, payload: Dictionary) -> void:
	var dir_path := path.get_base_dir()
	var abs_dir := ProjectSettings.globalize_path(dir_path)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[TRACK_BOOST_RESET] write_fail %s err=%d" % [path, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(payload, "  "))
	print("[TRACK_BOOST_RESET] wrote %s" % path)


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
