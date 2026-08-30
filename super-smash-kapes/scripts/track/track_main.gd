class_name TrackMain
extends Node

signal session_exited

const Config := preload("res://scripts/track/track_config.gd")
const RaceScript := preload("res://scripts/track/track_race.gd")
const CAR_SCENE_PATH := "res://scenes/track/TrackCar.tscn"
const FOUR_WHEEL_SCENE_PATH := "res://scenes/track/TrackCarWheelPhysics.tscn"
const CamScript := preload("res://scripts/track/track_camera.gd")
const TurnsScript := preload("res://scripts/track/track_turn_manager.gd")
const RecorderScript := preload("res://scripts/track/track_ghost_recorder.gd")
const GhostScript := preload("res://scripts/track/track_ghost_player.gd")
const HudScript := preload("res://scripts/track/track_hud.gd")
const ClockScript := preload("res://scripts/track/track_race_clock.gd")
## Production authority: articulated 4-wheel RigidBody. Opt out with SSK_TRACK_CONTROLLER=BASELINE.

var participants: Array = []
var _race
var _car
var _cam
var _hud
var _turns
var _recorder
var _ghosts: Node3D
var _ghost_samples: Dictionary = {}
var _seed: int = 0
var _seed_locked: bool = false
var _seed_pending: bool = false
var _length_id: String = "media"
var _difficulty_id: String = "picante"
var _menu_configured: bool = false
var _running: bool = false
var _timer: float = 0.0
var _next_check: int = 0
var _check_total: int = 0
var _paused: bool = false
var _turn_state: String = "idle"
var _clock = ClockScript.new()
var _go_banner: float = 0.0
var _copa_match_id: String = ""
var _copa_recorded: bool = false


func _spawn_player_car():
	var override := OS.get_environment("SSK_TRACK_CONTROLLER").strip_edges().to_upper()
	if override == "BASELINE" or override == "FUSED" or override == "TRACKCAR":
		var baseline: PackedScene = load(CAR_SCENE_PATH) as PackedScene
		print("[TRACK_MAIN] controller=BASELINE (SSK_TRACK_CONTROLLER override)")
		return baseline.instantiate()
	var four_wheel: PackedScene = load(FOUR_WHEEL_SCENE_PATH) as PackedScene
	if four_wheel != null:
		print("[TRACK_MAIN] controller=FOUR_WHEEL_V1")
		return four_wheel.instantiate()
	push_warning("[TRACK_MAIN] FOUR_WHEEL missing; falling back to BASELINE TrackCar")
	var CarScene: PackedScene = load(CAR_SCENE_PATH) as PackedScene
	return CarScene.instantiate()


func setup(roster: Array, seed_value: int = 0, length_id: String = "", difficulty_id: String = "") -> void:
	participants = roster.duplicate(true)
	_seed_locked = seed_value != 0
	_seed = seed_value if _seed_locked else Config.fresh_seed()
	if not str(length_id).is_empty():
		_length_id = str(length_id)
	if not str(difficulty_id).is_empty():
		_difficulty_id = str(difficulty_id)
	_menu_configured = not str(length_id).is_empty() and not str(difficulty_id).is_empty()


func _ready() -> void:
	Config.ensure_actions()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("jeffrey_mode_host")
	add_to_group("jeffrey_track_host")
	_race = RaceScript.new()
	add_child(_race)
	_car = _spawn_player_car()
	add_child(_car)
	_cam = CamScript.new()
	_cam.current = true
	_cam.target = _car.camera_target() if _car.has_method("camera_target") else _car
	add_child(_cam)
	_ghosts = Node3D.new()
	add_child(_ghosts)
	_recorder = RecorderScript.new()
	add_child(_recorder)
	_hud = HudScript.new()
	add_child(_hud)
	_hud.play_pressed.connect(_on_play)
	_hud.hub_pressed.connect(_exit)
	_hud.resume_pressed.connect(_resume)
	_hud.next_pressed.connect(_end_turn)
	_hud.otra_pressed.connect(_on_otra)
	_race.checkpoint_reached.connect(_on_checkpoint)
	if participants.is_empty():
		participants = _fallback_roster()
	_hud.set_status("")
	_hud.set_seed(_seed)
	_hud.set_prompt("ACELERAR W   ·   GIRO A/D   ·   DRIFT Shift   ·   PAUSA Esc")
	## Preview world behind setup so entry is never empty void (~17–20ms).
	var preview: Dictionary = _race.build(_seed, _length_id, _difficulty_id)
	_car.reset_to(_race.start_transform)
	if _cam != null and _cam.has_method("snap_to_target"):
		_cam.snap_to_target()
	_car.control_enabled = false
	_check_total = preview.get("checkpoints", []).size()
	if _menu_configured:
		## Canonical shell Track Menu already chose length/difficulty.
		_hud.hide_setup()
		call_deferred("_on_play", _length_id, _difficulty_id)
	else:
		_hud.show_setup()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_match"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if not _running or _paused:
		return
	if _clock == null or not _clock.is_active():
		return
	if event.is_action_pressed("track_reset"):
		_reset_checkpoint()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("track_restart"):
		_restart_or_surrender()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _paused or not _running:
		return
	if _clock.is_countdown():
		_hud.set_speed(_car_speed())
		if _clock.countdown_left > 0.05:
			_hud.set_status(str(maxi(ceili(_clock.countdown_left), 1)))
		else:
			_hud.set_status("DALE")
		if str(_clock.tick(delta)) == "started":
			_on_race_started()
		return
	if not _clock.is_active():
		return
	_clock.tick(delta)
	_timer = _clock.elapsed
	if _go_banner > 0.0:
		_go_banner -= delta
		if _go_banner <= 0.0:
			_hud.set_status("")
	var pid: String = _turns.current_profile_id() if _turns != null else ""
	if _turns != null:
		_turns.consume_fuel(pid, delta)
		_hud.set_timer(_timer)
	_hud.set_speed(_car_speed())
	_sync_ghosts(_timer)
	if _turns != null:
		var ld: bool = str(_turns.last_dance.get(pid, "none")) == "active"
		_hud.set_fuel(float(_turns.fuel.get(pid, 0.0)), ld, _driver_name())
		_hud.set_rank(_turns.alive_rank(pid), _turns.alive.size())
	_refresh_board()


func _on_play(length_id: String, difficulty_id: String) -> void:
	_length_id = length_id
	_difficulty_id = difficulty_id
	_copa_match_id = JeffreyCore.generate_copa_match_id("racing")
	_copa_recorded = false
	if not _seed_locked:
		if not _seed_pending:
			_seed = Config.fresh_seed()
		_seed_pending = false
	_build_and_start()


func _on_otra() -> void:
	_paused = false
	get_tree().paused = false
	_running = false
	if _car != null:
		_car.control_enabled = false
	_seed_locked = false
	_seed_pending = true
	_seed = Config.fresh_seed()
	_hud.set_seed(_seed)
	_hud.show_setup()
	_hud.set_status("")


func _build_and_start() -> void:
	var data: Dictionary = _race.build(_seed, _length_id, _difficulty_id)
	_check_total = data.get("checkpoints", []).size()
	if _turns == null:
		_turns = TurnsScript.new()
		_turns.setup(participants, float(data.get("estimated_time", 20.0)))
	_hud.set_seed(_seed)
	_hud.hide_setup()
	_hud.set_status("")
	_start_turn()


func _start_turn() -> void:
	if _turns == null or _turns.alive.is_empty():
		_show_results()
		return
	var info: Dictionary = _turns.begin_turn()
	_turn_state = str(info.get("state", "racing"))
	if _turn_state == "done":
		_show_results()
		return
	_next_check = 0
	_timer = 0.0
	_running = true
	_car.control_enabled = false
	_car.reset_to(_race.start_transform)
	if _cam != null and _cam.has_method("snap_to_target"):
		_cam.snap_to_target()
	_spawn_ghosts()
	var row: Dictionary = _turns.current_row()
	var profile = JeffreyCore.profiles.get_profile(str(row.get("profile_id", "")))
	var person: String = profile.display_name if profile != null else str(row.get("profile_id", ""))
	var character = JeffreyCore.characters.get_character(str(row.get("character_id", "")))
	var kape: String = character.display_name if character != null else "—"
	_hud.set_driver(person, kape, int(row.get("player_slot", 1)))
	_hud.set_progress(0, _check_total)
	var ld: bool = _turn_state == "last_dance"
	if _hud.has_method("set_best"):
		_hud.set_best(float(_turns.best_times.get(_turns.current_profile_id(), -1.0)))
	_hud.set_fuel(float(_turns.fuel.get(_turns.current_profile_id(), 0.0)), ld, person)
	_hud.set_rank(_turns.alive_rank(_turns.current_profile_id()), _turns.alive.size())
	_hud.set_seed(_seed)
	_hud.set_status("RENDICIÓN" if ld else "PREPARADOS")
	_hud.set_prompt("PUNTO C   ·   REINICIAR Backspace   ·   DRIFT Shift")
	_refresh_board()
	_enter_countdown()


func _on_checkpoint(index: int, is_finish: bool) -> void:
	if not _running or _car == null or not _car.control_enabled:
		return
	if index != _next_check:
		return
	_next_check += 1
	if is_finish:
		_finish_attempt()
	else:
		if _hud.has_method("flash_checkpoint"):
			_hud.flash_checkpoint(_next_check, _check_total)
		else:
			_hud.set_progress(_next_check, _check_total)


func _enter_countdown() -> void:
	_clock.begin_countdown(Config.COUNTDOWN_SECONDS)
	_timer = 0.0
	_go_banner = 0.0
	_car.control_enabled = false
	_hud.set_status(str(maxi(ceili(_clock.countdown_left), 1)))


func _on_race_started() -> void:
	_car.control_enabled = true
	_recorder.start(_car)
	for child in _ghosts.get_children():
		if child.has_method("begin_playback"):
			child.begin_playback()
		if child.has_method("set_elapsed"):
			child.set_elapsed(0.0)
	_go_banner = 0.55
	_hud.set_status("DALE")
	_hud.set_timer(0.0)


func _sync_ghosts(elapsed: float) -> void:
	for child in _ghosts.get_children():
		if child.has_method("set_elapsed"):
			child.set_elapsed(elapsed)


func _finish_attempt() -> void:
	_running = false
	_clock.finish()
	_car.control_enabled = false
	var pid: String = str(_turns.current_profile_id())
	var samples = _recorder.stop()
	if not samples.is_empty():
		var best := float(_turns.best_times.get(pid, -1.0))
		if best < 0.0 or _timer < best or not _ghost_samples.has(pid):
			_ghost_samples[pid] = samples
	var result: String = str(_turns.record_finish(pid, _timer))
	var best_now := float(_turns.best_times.get(pid, -1.0))
	if _hud.has_method("set_best"):
		_hud.set_best(best_now)
	if result == "eliminated":
		_hud.set_status("ELIMINATED")
		_ghost_samples.erase(pid)
	elif result == "survived":
		_hud.set_status("LAST DANCE  ·  SURVIVED / CLUTCH")
	else:
		if _hud.has_method("flash_finish"):
			_hud.flash_finish(_timer)
		else:
			_hud.set_status("TIEMPO  %0.2f" % _timer)
	_refresh_board()
	await get_tree().create_timer(1.4).timeout
	_end_turn()


func _end_turn() -> void:
	_running = false
	_car.control_enabled = false
	if _turns != null:
		_turns.advance()
		if _turns.session_over():
			_record_copa_if_needed()
			_show_results()
			return
	_start_turn()


func _record_copa_if_needed() -> void:
	if _copa_recorded or _copa_match_id.is_empty() or _turns == null:
		return
	JeffreyCore.record_track_copa_match(_copa_match_id, _turns)
	_copa_recorded = true


func restart_session() -> void:
	_running = false
	_paused = false
	get_tree().paused = false
	if _car != null:
		_car.control_enabled = false
	_turns = null
	_ghost_samples.clear()
	_copa_match_id = JeffreyCore.generate_copa_match_id("racing")
	_copa_recorded = false
	_hud.show_setup()
	_hud.set_status("")
	_hud.set_prompt("ACELERAR W   ·   GIRO A/D   ·   DRIFT Shift   ·   PAUSA Esc")


func _reset_checkpoint() -> void:
	if _race == null:
		return
	var marks: Array = _race.track_data.get("checkpoints", [])
	var xform: Transform3D = _race.start_transform
	if _next_check > 0 and _next_check - 1 < marks.size():
		xform = marks[_next_check - 1]["transform"]
	_car.reset_to(xform)


func _restart_or_surrender() -> void:
	var pid: String = str(_turns.current_profile_id()) if _turns != null else ""
	if _turn_state == "last_dance":
		_turns.surrender(pid)
		_hud.set_status("RENDICIÓN")
		_running = false
		_car.control_enabled = false
		_end_turn()
		return
	_timer = 0.0
	_next_check = 0
	_recorder.stop()
	_car.reset_to(_race.start_transform)
	_hud.set_progress(0, _check_total)
	for child in _ghosts.get_children():
		if child.has_method("arm"):
			child.arm()
	_enter_countdown()


func _spawn_ghosts() -> void:
	for child in _ghosts.get_children():
		child.queue_free()
	if _turns == null:
		return
	var current: String = str(_turns.current_profile_id())
	for pid in _turns.alive:
		if pid == current:
			continue
		if not _ghost_samples.has(pid):
			continue
		var ghost = GhostScript.new()
		_ghosts.add_child(ghost)
		ghost.setup(pid, _ghost_samples[pid])


func _refresh_board() -> void:
	if _turns == null:
		return
	var lines: PackedStringArray = PackedStringArray()
	var has_times := false
	var rank := 1
	for row in _turns.rank_list():
		var profile = JeffreyCore.profiles.get_profile(str(row["profile_id"]))
		var name_text: String = profile.display_name if profile != null else str(row["profile_id"])
		var best := float(row["best"])
		if best >= 0.0:
			has_times = true
		var best_txt := "--" if best < 0.0 else "%0.2f" % best
		var flag := "" if bool(row["alive"]) else "  OUT"
		lines.append("%d. %s  %s%s" % [rank, name_text.to_upper(), best_txt, flag])
		rank += 1
	## Hide sparse empty standings during countdown — show once someone has a time.
	if not has_times:
		_hud.set_board(PackedStringArray())
		return
	var headed := PackedStringArray()
	headed.append("Ronda %d" % _turns.round_number)
	headed.append_array(lines)
	_hud.set_board(headed)


func _driver_name() -> String:
	if _turns == null:
		return ""
	var row: Dictionary = _turns.current_row()
	var profile = JeffreyCore.profiles.get_profile(str(row.get("profile_id", "")))
	if profile != null:
		return str(profile.display_name)
	return str(row.get("profile_id", ""))


func _car_speed() -> float:
	if _car == null:
		return 0.0
	if _car is RigidBody3D:
		var v: Vector3 = (_car as RigidBody3D).linear_velocity
		return Vector3(v.x, 0.0, v.z).length()
	if _car is CharacterBody3D:
		var v2: Vector3 = (_car as CharacterBody3D).velocity
		return Vector3(v2.x, 0.0, v2.z).length()
	return 0.0


func _show_results() -> void:
	_running = false
	_car.control_enabled = false
	_hud.set_status("SESIÓN TERMINADA")
	_hud.set_prompt("Esc → Hub")
	_refresh_board()


func _toggle_pause() -> void:
	if _hud != null and _hud.is_setup_visible():
		_exit()
		return
	_paused = not _paused
	get_tree().paused = _paused
	_hud.show_pause(_paused)


func _resume() -> void:
	_paused = false
	get_tree().paused = false


func _exit() -> void:
	get_tree().paused = false
	session_exited.emit()


func _fallback_roster() -> Array:
	var out: Array = []
	var slot := 1
	for profile in JeffreyCore.profiles.get_all():
		out.append({"profile_id": profile.profile_id, "player_slot": slot, "character_id": "terere"})
		slot += 1
		if slot > 2:
			break
	return out
