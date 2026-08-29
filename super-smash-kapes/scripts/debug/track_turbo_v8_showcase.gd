extends Node3D

## Track Turbo V8: 15 m candidate kit + split HUD + Blender scenery.
## Does not replace TrackMain. Does not rewrite Generator V4. VISUAL_REVIEW_PENDING.

const Config := preload("res://scripts/track/track_config.gd")
const Registry := preload("res://scripts/track/track_piece_registry.gd")
const GenScript := preload("res://scripts/track/track_generator_v2.gd")
const Assembler := preload("res://scripts/track/track_kit_assembler.gd")
const RevealScript := preload("res://scripts/track/track_generation_reveal.gd")
const CamScript := preload("res://scripts/track/track_dynamic_chase_camera.gd")
const HudScript := preload("res://scripts/track/track_turbo_hud.gd")
const Hotseat := preload("res://scripts/track/track_hotseat_v2.gd")
const Rhythm := preload("res://scripts/track/track_rhythm_analyzer.gd")
const Scenery := preload("res://scripts/track/track_scenery_generator.gd")
const Signage := preload("res://scripts/track/track_signage.gd")
const Checkpoints := preload("res://scripts/track/track_checkpoint_layout.gd")
const SkidScript := preload("res://scripts/track/track_skid_marks.gd")
const AudioScript := preload("res://scripts/track/track_turbo_audio.gd")
const FeedbackScript := preload("res://scripts/track/track_boost_feedback.gd")
const Telemetry := preload("res://scripts/track/track_debug_telemetry.gd")
const VisualScript := preload("res://scripts/track/track_car_visual.gd")

const ST_SETUP := "setup"
const ST_REVEAL := "reveal"
const ST_SUMMARY := "summary"
const ST_COUNTDOWN := "countdown"
const ST_RACE := "race"
const ST_CARD := "card"
const ST_RUNOFF := "runoff"
const KIT_DIR := Registry.CORE_DIR_V8_15M
const ROAD_W := Config.ROAD_WIDTH_CANDIDATE

var _state: String = ST_SETUP
var _length: String = "SHORT"
var _diff: String = "PICANTE"
var _seed: int = 1
var _gen
var _result: Dictionary = {}
var _pieces: Array = []
var _car
var _chase
var _reveal_cam: Camera3D
var _hud
var _hs
var _scenery
var _audio
var _timer: float = 0.0
var _count: int = 3
var _next_cp: int = 0
var _cp_total: int = 0
var _gates: Array = []
var _card_t: float = 0.0
var _debug: bool = false
var _reveal
var _skid
var _was_air: bool = false
var _boost_fb
var _last_split_delta: float = NAN


func _ready() -> void:
	Config.ensure_actions()
	_seed = Config.fresh_seed()
	_gen = GenScript.new()
	_sun()
	_hud = HudScript.new()
	add_child(_hud)
	_audio = AudioScript.new()
	add_child(_audio)
	_hs = Hotseat.new()
	_hs.setup(_roster(), 24.0, Config.FUEL_MULTIPLIER)
	_reveal_cam = Camera3D.new()
	_reveal_cam.fov = 62.0
	add_child(_reveal_cam)
	_chase = CamScript.new()
	add_child(_chase)
	_set_state(ST_SETUP)
	print("[TRACK_TURBO_V8] 1 SHORT 2 MEDIUM 3 LONG  T difficulty  ENTER dale  F3 debug  F8 skip reveal  kit=15m")


func _roster() -> Array:
	return [
		{"id": "enzo", "name": "Enzo", "color": Color("#e8c04a")},
		{"id": "juan", "name": "Juan", "color": Color("#4aa8e8")},
		{"id": "santi", "name": "Santi", "color": Color("#e87a4a")},
		{"id": "tomi", "name": "Tomi", "color": Color("#7ad07a")},
	]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F3:
			_debug = not _debug
			_hud.debug_on = _debug
		KEY_F8:
			if _reveal != null:
				_reveal.skip = true
		KEY_1:
			if _state == ST_SETUP or _state == ST_SUMMARY:
				_length = "SHORT"
				_refresh_setup()
		KEY_2:
			if _state == ST_SETUP or _state == ST_SUMMARY:
				_length = "MEDIUM"
				_refresh_setup()
		KEY_3:
			if _state == ST_SETUP or _state == ST_SUMMARY:
				_length = "LONG"
				_refresh_setup()
		KEY_T:
			if _state == ST_SETUP or _state == ST_SUMMARY:
				_cycle_diff()
				_refresh_setup()
		KEY_ENTER, KEY_KP_ENTER:
			if _state == ST_SETUP or _state == ST_SUMMARY:
				_generate_and_reveal()
		KEY_R:
			if _state == ST_SUMMARY:
				_seed = Config.fresh_seed()
				_generate_and_reveal()
		KEY_SPACE:
			if _state == ST_SUMMARY:
				_start_countdown()


func _process(delta: float) -> void:
	match _state:
		ST_SETUP:
			_refresh_setup()
		ST_COUNTDOWN:
			_timer += delta
			if _timer >= 1.0:
				_timer = 0.0
				_count -= 1
				if _count > 0:
					_audio.play_countdown(_count)
					_hud.set_banner(str(_count), true)
				else:
					_audio.play_dale()
					_hud.set_banner("¡DALE!", true)
					_begin_race()
		ST_RACE:
			_tick_race(delta)
		ST_RUNOFF:
			_tick_runoff(delta)
		ST_CARD:
			_card_t -= delta
			if _card_t <= 0.0:
				_hud.hide_handoff()
				if str(_hs.phase) == Hotseat.PHASE_DONE:
					_hud.show_summary("FIN DE MESA", "R  OTRA PISTA")
					_set_state(ST_SUMMARY)
				else:
					_start_countdown()
	_refresh_hud_board()
	_update_piece_report()


func _generate_and_reveal() -> void:
	_clear_track()
	_result = _gen.generate(_seed, _length, _diff)
	if not bool(_result.get("accepted", false)):
		_hud.set_banner("NO SALIÓ LA PISTA", true)
		return
	var seq_raw = _result.get("piece_sequence", [])
	var seq: Array = []
	if seq_raw is Array:
		seq = seq_raw
	var built: Dictionary = Assembler.assemble(self, seq, KIT_DIR, true)
	_pieces = built["pieces"]
	_scenery = Scenery.new()
	add_child(_scenery)
	_scenery.road_clearance = ROAD_W * 0.5 + 1.6
	_scenery.build(_pieces)
	Signage.decorate(self, _pieces)
	var idxs: PackedInt32Array = Checkpoints.plan(seq, _length)
	_gates = Checkpoints.build_gates(self, _pieces, idxs, ROAD_W)
	_cp_total = _gates.size()
	for g in _gates:
		var area = (g["node"] as Node).get_meta("cp_area")
		if area is Area3D:
			(area as Area3D).body_entered.connect(_on_cp.bind(g))
	_reveal_cam.current = true
	_reveal_cam.global_position = Vector3(0, 14, 22)
	_reveal = RevealScript.new()
	add_child(_reveal)
	_reveal.finished.connect(_on_reveal_done)
	_set_state(ST_REVEAL)
	_hud.set_generating(true)
	_reveal.start(_pieces, _reveal_cam)


func _on_reveal_done() -> void:
	var rhy: Dictionary = Rhythm.analyze(_result.get("piece_sequence", []))
	var body := "%s  ·  %s\n\n%.0f m\n%d CURVAS    %d BOOST    %d CREST\n%d CHECKPOINTS\n\nSEED  %d" % [
		_length,
		_diff,
		float(_result.get("path_m", 0.0)),
		int(_result.get("turns", 0)),
		int(rhy.get("boosts", 0)),
		int(rhy.get("crests", 0)),
		_cp_total,
		_seed,
	]
	_hud.show_summary(body)
	_set_state(ST_SUMMARY)
	var expected := maxf(float(_result.get("path_m", 180.0)) / 28.0, 12.0)
	_hs.setup(_roster(), expected, Config.FUEL_MULTIPLIER)


func _start_countdown() -> void:
	_hud.hide_summary()
	_hud.hide_handoff()
	_spawn_car()
	_count = 3
	_timer = 0.0
	_audio.play_countdown(3)
	_hud.set_banner("3", true)
	if str(_hs.phase) == Hotseat.PHASE_QUALIFY:
		_hud.set_phase_chip("TODOS MARCAN TIEMPO")
	else:
		_hud.set_phase_chip("EL ÚLTIMO SIGUE")
	_car.control_enabled = false
	_set_state(ST_COUNTDOWN)


func _begin_race() -> void:
	_hs.begin_run()
	_timer = 0.0
	_next_cp = 0
	_last_split_delta = NAN
	_car.control_enabled = true
	_hud.set_banner("", false)
	_hud.clear_delta()
	_hud.set_target(-1)
	_set_state(ST_RACE)


func _tick_race(delta: float) -> void:
	_timer += delta
	_hs.tick_fuel(delta)
	var p: Dictionary = _hs.current()
	var ultima := bool(p.get("used_ultima", false))
	_hud.set_fuel(float(p.get("fuel", 0.0)), _hs.fuel_budget, ultima, float(p.get("fuel", 0.0)) < 10.0)
	if ultima and not p.get("_ultima_logged", false):
		p["_ultima_logged"] = true
		_audio.play_ultima()
		_hud.flash_ultima()
	var speed := Telemetry.debug_float(_car, "debug_speed", 0.0)
	_audio.tick(speed, Config.MAX_SPEED, Telemetry.debug_float(_car, "debug_slip_angle", 0.0), Telemetry.debug_bool(_car, "debug_airborne", false), "ROAD")
	var air := Telemetry.debug_bool(_car, "debug_airborne", false)
	if _was_air and not air:
		_chase.landing_impulse(4.0)
		_audio.play_landing(4.0)
	_was_air = air
	var tgt_ms: int = int(_hs.target_final_ms())
	_hud.set_target(tgt_ms)
	if str(_hs.phase) == Hotseat.PHASE_QUALIFY:
		_hud.set_target(-1)
		_hud.clear_delta()
	elif is_nan(_last_split_delta):
		_hud.clear_delta()
	else:
		_hud.set_delta(_last_split_delta)
	_hud.set_player("%s" % str(p.get("name", "")), p.get("color", Color.WHITE))


func _on_cp(body: Node, gate: Dictionary) -> void:
	if _state != ST_RACE or body != _car:
		return
	var idx: int = int(gate.get("index", 0))
	if idx != _next_cp:
		return
	_hs.record_split(_timer)
	var split_tgt: float = float(_hs.target_split_sec(idx))
	if split_tgt >= 0.0:
		_last_split_delta = _timer - split_tgt
		_hud.set_delta(_last_split_delta)
		print("[TRACK_SPLIT] cp=%d elapsed=%.3f target=%.3f delta=%.3f" % [idx + 1, _timer, split_tgt, _last_split_delta])
	else:
		_hud.clear_delta()
		print("[TRACK_SPLIT] cp=%d elapsed=%.3f target=none" % [idx + 1, _timer])
	_next_cp += 1
	if bool(gate.get("finish", false)):
		_begin_runoff()
	else:
		_hud.set_banner("CHECKPOINT %d/%d" % [_next_cp, _cp_total], true)


func _begin_runoff() -> void:
	if _car != null:
		_car.post_finish = true
		_car.control_enabled = true
	_audio.play_finish()
	_card_t = 1.8
	_set_state(ST_RUNOFF)
	print("[TRACK_TURBO_V8] finish_runoff t=%.3f" % _timer)


func _tick_runoff(delta: float) -> void:
	_card_t -= delta
	if _car != null and is_instance_valid(_car) and _card_t < 1.2:
		_car.control_enabled = false
	if _card_t <= 0.0:
		_show_finish_card()


func _show_finish_card() -> void:
	if _car != null and is_instance_valid(_car):
		_car.control_enabled = false
		_car.post_finish = true
	var rec: Dictionary = _hs.record_finish(_timer)
	var accent: Color = rec.get("color", Color("#f0d48a"))
	_hud.show_handoff(str(rec.get("card", "")), accent)
	if str(_hs.phase) != Hotseat.PHASE_QUALIFY:
		_hud.set_phase_chip("AHORA EL ÚLTIMO SIGUE")
	_card_t = 2.4
	_set_state(ST_CARD)
	print("[TRACK_TURBO_V8] finish t=%.3f splits=%s live=%d ghost=%d" % [
		_timer,
		str(rec.get("splits", [])),
		VisualScript.live_visuals(),
		VisualScript.ghost_visuals(),
	])


func _spawn_car() -> void:
	if _car != null and is_instance_valid(_car):
		_car.free()
	_car = null
	var packed: PackedScene = load("res://scenes/track/TrackCarWheelPhysics.tscn") as PackedScene
	_car = packed.instantiate()
	add_child(_car)
	var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 1.15, -2.6))
	if _pieces.size() > 0 and _pieces[0].player_spawn != null:
		spawn = _pieces[0].player_spawn.global_transform
	_car.reset_to(spawn)
	_car.control_enabled = false
	_chase.target = _car.camera_target() if _car.has_method("camera_target") else _car
	_chase.current = true
	_chase.snap_to_target()
	_reveal_cam.current = false
	if _skid == null:
		_skid = SkidScript.new()
		add_child(_skid)
	_skid.setup(_car)
	if _boost_fb == null:
		_boost_fb = FeedbackScript.new()
		add_child(_boost_fb)
	_boost_fb.setup(_car, _chase)
	print("[TRACK_VISUAL_LIFE] after_spawn live=%d ghost=%d" % [VisualScript.live_visuals(), VisualScript.ghost_visuals()])


func _clear_track() -> void:
	for p in _pieces:
		if is_instance_valid(p):
			p.queue_free()
	_pieces.clear()
	for g in _gates:
		var n = g.get("node")
		if n is Node and is_instance_valid(n):
			n.queue_free()
	_gates.clear()
	if _scenery != null:
		_scenery.queue_free()
		_scenery = null
	var signs := get_node_or_null("Signage")
	if signs != null:
		signs.queue_free()
	if _reveal != null:
		_reveal.queue_free()
		_reveal = null


func _refresh_setup() -> void:
	if _state != ST_SETUP:
		return
	_hud.show_summary("TRACK TURBO  V8\n15 m kit\n\n%s  ·  %s\nSEED  %d" % [_length, _diff, _seed], "ENTER  GENERAR     1/2/3  LARGO     T  DIFICULTAD")


func _refresh_hud_board() -> void:
	_hud.set_ranking(_hs.ranking(), _hs.current_id)
	if _debug:
		_hud.set_debug("fov=%.1f speed=%.1f drift=%s cp=%d/%d live=%d" % [
			_chase.last_fov if _chase != null else 0.0,
			Telemetry.debug_float(_car, "debug_speed", 0.0),
			Telemetry.debug_string(_car, "drift_state", "-"),
			_next_cp,
			_cp_total,
			VisualScript.live_visuals(),
		])


func _update_piece_report() -> void:
	if _car == null or not is_instance_valid(_car) or _pieces.is_empty():
		return
	var pos: Vector3 = _car.global_position
	var best := ""
	var best_d := 1.0e9
	var idx := -1
	for i in _pieces.size():
		var piece = _pieces[i]
		if piece == null or not (piece is Node3D):
			continue
		var d: float = (piece as Node3D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = str(piece.piece_id)
			idx = i
	if _car.get("report_piece_id") != null:
		_car.set("report_piece_id", best)
	if idx >= 0:
		_car.set("report_piece_prev", str(_pieces[idx - 1].piece_id) if idx > 0 else "")
		_car.set("report_piece_next", str(_pieces[idx + 1].piece_id) if idx + 1 < _pieces.size() else "")
	if idx >= 0 and _chase != null:
		var nxt = _pieces[idx + 1] if idx + 1 < _pieces.size() else _pieces[idx]
		if nxt != null and nxt.has_method("exit_global"):
			var xf: Transform3D = nxt.exit_global()
			_chase.road_look_dir = -xf.basis.z


func _cycle_diff() -> void:
	if _diff == "TRANQUI":
		_diff = "PICANTE"
	elif _diff == "PICANTE":
		_diff = "DEMENTE"
	else:
		_diff = "TRANQUI"


func _set_state(st: String) -> void:
	_state = st


func _sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 28, 0)
	sun.light_energy = 1.25
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#6e8aa8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d4c8b0")
	env.ambient_light_energy = 0.58
	env.fog_enabled = true
	env.fog_density = 0.0012
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
