class_name ZombiesMain
extends Node

signal session_exited

const Config := preload("res://scripts/zombies/zombies_config.gd")
const PlayerScript := preload("res://scripts/zombies/zombies_player.gd")
const EnemyScript := preload("res://scripts/zombies/zombies_enemy.gd")
const WavesScript := preload("res://scripts/zombies/zombies_waves.gd")
const HudScript := preload("res://scripts/zombies/zombies_hud.gd")
const MapScript := preload("res://scripts/zombies/zombies_map.gd")
const StateScript := preload("res://scripts/zombies/zombies_game_state.gd")
const AudioScript := preload("res://scripts/zombies/zombies_audio.gd")

var participants: Array = []
var _player
var _hud
var _waves
var _map
var _state
var _audio
var _enemies: Node3D
var _paused: bool = false
var _lost: bool = false
var _debug_stuck: Dictionary = {}
var _debug_stuck_clock: float = 0.0
var _pending_spawn: int = 0
var _remaining: int = 0
var _spawn_cd: float = 0.0
var _between_cd: float = 0.0
var _phase: String = "idle"
var _spawn_i: int = 0
var _copa_match_id: String = ""
var _copa_recorded: bool = false
## Read-only MCP snapshot. Never written by gameplay systems other than this adapter.
var jeffrey_debug_state: Dictionary = {}


func setup(roster: Array) -> void:
	participants = roster.duplicate(true)


func _ready() -> void:
	Config.ensure_actions()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("jeffrey_mode_host")
	add_to_group("jeffrey_zombies_host")
	_state = StateScript.new()
	_waves = WavesScript.new()
	_map = MapScript.new()
	add_child(_map)
	_map.build()
	var Probe := load("res://scripts/debug/jeffrey_resource_probe.gd")
	if Probe != null:
		Probe.dump("ZombiesMain.ready", self)
		var hosts := get_tree().get_nodes_in_group("jeffrey_zombies_host")
		print("[ZOMBIES_LIFECYCLE] host_count=%d map_children=%d" % [hosts.size(), _map.get_child_count()])
	_audio = AudioScript.new()
	add_child(_audio)
	if _map.main_entrance != null:
		_map.main_entrance.opened.connect(func():
			if _audio != null:
				_audio.play("shopping_open")
		)
	if _map.door != null:
		_map.door.opened.connect(func():
			if _audio != null:
				_audio.play("door_buy")
		)
	_player = PlayerScript.new()
	_player.game_state = _state
	_player.position = _map.player_spawn
	add_child(_player)
	_player.died.connect(_on_dead)
	_player.max_ammo_taken.connect(_on_max_ammo)
	_player.fired.connect(_on_fired)
	_player.damaged.connect(_on_damaged)
	_player.dry_fired.connect(_on_dry_fired)
	_state.points_gained.connect(_on_points_gained)
	_enemies = Node3D.new()
	add_child(_enemies)
	_hud = HudScript.new()
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hud)
	_hud.hub_pressed.connect(_exit)
	_hud.restart_pressed.connect(_restart)
	_hud.resume_pressed.connect(func():
		_paused = false
		get_tree().paused = false
	)
	_copa_match_id = JeffreyCore.generate_copa_match_id("zombies")
	_copa_recorded = false
	_start_wave()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_match"):
		if _lost:
			_exit()
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restart_match") and _lost:
		_restart()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_ev: InputEventKey = event as InputEventKey
		match key_ev.physical_keycode:
			KEY_F3:
				_hud.toggle_debug()
			KEY_F8:
				_state.add_points(Config.DEBUG_POINTS)
			KEY_F9:
				debug_spawn_one()
			KEY_F10:
				debug_kill_all()


func _process(delta: float) -> void:
	if _lost:
		_refresh_hud()
		_refresh_jeffrey_debug_state()
		return
	if _phase == "between":
		_between_cd -= delta
		if _between_cd <= 0.0:
			_start_wave()
	elif _phase == "spawning" or _pending_spawn > 0:
		_tick_spawns(delta)
	_refresh_hud()
	_tick_debug_stuck(delta)
	_refresh_jeffrey_debug_state()


func _start_wave() -> void:
	if _lost:
		return
	var count: int = _waves.next_count()
	_pending_spawn = count
	_remaining = count
	_state.round_number = _waves.wave
	_spawn_cd = 0.12
	_phase = "spawning"
	_hud.set_wave(_waves.wave, _remaining)
	_hud.announce_round(_waves.wave)
	if _audio != null:
		_audio.play("round_start")


func _tick_spawns(delta: float) -> void:
	if _pending_spawn <= 0:
		_phase = "fighting"
		return
	if _count_alive() >= Config.MAX_ALIVE:
		return
	_spawn_cd -= delta
	if _spawn_cd > 0.0:
		return
	_spawn_cd = Config.SPAWN_INTERVAL
	_pending_spawn -= 1
	_spawn_zombie(_pick_spawn())
	if _pending_spawn <= 0:
		_phase = "fighting"


func _pick_spawn() -> Vector3:
	var pts: Array[Vector3] = _map.spawn_points_for(_player.global_position if _player != null else Vector3.ZERO)
	if pts.is_empty():
		return Vector3(8, 0.05, -6)
	var origin: Vector3 = _player.global_position if _player != null else Vector3.ZERO
	var start: int = _spawn_i
	for _n in pts.size():
		var p: Vector3 = pts[_spawn_i % pts.size()]
		_spawn_i += 1
		if p.distance_to(origin) >= 3.4:
			return p
	return pts[start % pts.size()]


func _spawn_zombie(at: Vector3) -> void:
	var z = EnemyScript.new()
	_enemies.add_child(z)
	z.global_position = at
	z.target = _player
	z.use_navigation = _map.nav_ready
	z.configure_health(_waves.zombie_health())
	z.died.connect(_on_zombie_dead)
	z.hurt.connect(_on_zombie_hurt)
	z.attack_started.connect(_on_zombie_attack)


func debug_spawn_one() -> void:
	if _lost:
		return
	_remaining += 1
	_spawn_zombie(_pick_spawn())
	_hud.set_wave(_waves.wave, _remaining)


func debug_kill_all() -> void:
	for child in _enemies.get_children():
		if child is ZombiesEnemy and child.alive:
			child.take_damage(9999.0)
	_between_cd = 0.05


func _count_alive() -> int:
	var n: int = 0
	for child in _enemies.get_children():
		if child is ZombiesEnemy and child.alive:
			n += 1
	return n


func _on_zombie_hurt() -> void:
	if _lost:
		return
	_state.add_points(Config.POINTS_HIT)
	if _audio != null:
		_audio.play("zombie_hurt")


func _on_zombie_attack() -> void:
	if _audio != null:
		_audio.play("zombie_attack")


func _on_zombie_dead() -> void:
	_remaining = maxi(_remaining - 1, 0)
	if not _lost:
		_state.add_kill()
		_state.add_points(Config.POINTS_KILL)
		if _audio != null:
			_audio.play("zombie_death")
	_hud.set_wave(_waves.wave, _remaining)
	if _remaining <= 0 and _pending_spawn <= 0 and not _lost:
		_phase = "between"
		_between_cd = Config.ROUND_DELAY
		_hud.announce("OLEADA LIMPIA", 1.5)


func _on_max_ammo() -> void:
	_hud.show_max_ammo()
	if _audio != null:
		_audio.play("max_ammo")


func _on_fired() -> void:
	if _audio != null and _player != null:
		var w = _player.current_weapon()
		var id := "pistol"
		if w != null and w.data != null and str(w.data.id) == "smg":
			id = "smg"
		_audio.play(id)
	if _hud == null or _player == null:
		return
	if _player.last_hit_was_zombie:
		_hud.show_hit_marker(_player.last_hit_was_kill)


func _on_damaged() -> void:
	if _hud != null:
		_hud.pulse_damage()
	if _audio != null:
		_audio.play("player_hit")


func _on_dry_fired() -> void:
	if _hud != null:
		_hud.flash_ammo()


func _on_points_gained(amount: int) -> void:
	if _hud != null:
		_hud.show_points_toast(amount)


func _on_dead() -> void:
	_lost = true
	_state.mark_game_over()
	_record_copa_if_needed(false)
	if _player != null:
		_player.control_enabled = false
	for child in _enemies.get_children():
		if child is ZombiesEnemy:
			child.ai_enabled = false
	if _hud != null:
		_hud.play_death_vignette()
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(self) or _hud == null:
		return
	_hud.show_game_over(_waves.wave, _state.kills)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _tick_debug_stuck(delta: float) -> void:
	## Observational only. Does not change AI, nav, or spawn rules.
	_debug_stuck_clock += delta
	if _enemies == null:
		return
	var now: float = _debug_stuck_clock
	for child in _enemies.get_children():
		if not (child is ZombiesEnemy):
			continue
		var enemy: ZombiesEnemy = child
		if not enemy.ai_enabled:
			continue
		var id: int = enemy.get_instance_id()
		var xz := Vector2(enemy.global_position.x, enemy.global_position.z)
		var prev: Variant = _debug_stuck.get(id)
		if typeof(prev) != TYPE_DICTIONARY:
			_debug_stuck[id] = {"xz": xz, "t": now}
			continue
		var moved: float = xz.distance_to(prev["xz"])
		if moved > 0.18:
			_debug_stuck[id] = {"xz": xz, "t": now}
	var live: Dictionary = {}
	for child in _enemies.get_children():
		if child is ZombiesEnemy:
			live[child.get_instance_id()] = true
	for key in _debug_stuck.keys():
		if not live.has(key):
			_debug_stuck.erase(key)


func _debug_stuck_count() -> int:
	var n: int = 0
	var now: float = _debug_stuck_clock
	for child in _enemies.get_children():
		if not (child is ZombiesEnemy):
			continue
		var enemy: ZombiesEnemy = child
		if not enemy.ai_enabled:
			continue
		var prev: Variant = _debug_stuck.get(enemy.get_instance_id())
		if typeof(prev) != TYPE_DICTIONARY:
			continue
		var moved: float = Vector2(enemy.global_position.x, enemy.global_position.z).distance_to(prev["xz"])
		var has_target: bool = enemy.use_navigation or _player != null
		if has_target and moved <= 0.18 and (now - float(prev["t"])) > 2.5:
			n += 1
	return n


func _debug_nearest_enemy_distance() -> Variant:
	if _player == null or _enemies == null:
		return "UNAVAILABLE"
	var best: float = -1.0
	var pxz := Vector2(_player.global_position.x, _player.global_position.z)
	for child in _enemies.get_children():
		if not (child is ZombiesEnemy):
			continue
		var enemy: ZombiesEnemy = child
		if not enemy.ai_enabled:
			continue
		var d: float = pxz.distance_to(Vector2(enemy.global_position.x, enemy.global_position.z))
		if best < 0.0 or d < best:
			best = d
	if best < 0.0:
		return "UNAVAILABLE"
	return best


func _refresh_jeffrey_debug_state() -> void:
	var pos: Array = []
	var vel: Variant = "UNAVAILABLE"
	var health: Variant = "UNAVAILABLE"
	if _player != null and is_instance_valid(_player):
		var gp: Vector3 = _player.global_position
		pos = [gp.x, gp.y, gp.z]
		health = _player.health
		var pv: Vector3 = _player.velocity
		vel = [pv.x, pv.y, pv.z]
	var polygons: Variant = "UNAVAILABLE"
	if _map != null:
		var region = _map.get("_nav_region")
		if region != null and region.navigation_mesh != null:
			polygons = region.navigation_mesh.get_polygon_count()
	jeffrey_debug_state = {
		"scene": "res://scenes/zombies/ZombiesMain.tscn",
		"round": _waves.wave if _waves != null else "UNAVAILABLE",
		"points": _state.points if _state != null else "UNAVAILABLE",
		"kills": _state.kills if _state != null else "UNAVAILABLE",
		"zombies_alive": _count_alive(),
		"spawn_queue": _pending_spawn,
		"remaining": _remaining,
		"phase": _phase,
		"shopping_open": _map.shopping_open if _map != null else "UNAVAILABLE",
		"gallery_open": _map.gallery_open if _map != null else "UNAVAILABLE",
		"navigation_mode": _map.nav_mode if _map != null else "UNAVAILABLE",
		"nav_polygon_count": polygons,
		"player_position": pos if not pos.is_empty() else "UNAVAILABLE",
		"player_velocity": vel,
		"player_health": health,
		"nearest_enemy_distance": _debug_nearest_enemy_distance(),
		"pickup_state": "UNAVAILABLE",
		"player_threat": "UNAVAILABLE",
		"stuck_zombie_count": _debug_stuck_count(),
		"DEBUG_HEURISTIC_STUCK": _debug_stuck_count(),
		"mutating": false,
	}


func _refresh_hud() -> void:
	if _hud == null or _player == null or not is_instance_valid(_player):
		return
	_hud.set_hp(_player.health)
	_hud.set_points(_state.points)
	_hud.set_wave(_waves.wave, _remaining)
	_hud.set_prompt(_player.interact_prompt)
	var w = _player.current_weapon()
	if w != null:
		_hud.set_weapon(w.display_name(), w.mag, w.reserve, w.is_reloading())
	if _hud.is_debug():
		var nav: String = _map.nav_mode if _map != null else "?"
		_hud.set_debug("F3 debug  F8 +%d pts  F9 spawn  F10 clear\nnav %s  phase %s  pending %d\nG recargar  E interactuar" % [Config.DEBUG_POINTS, nav, _phase, _pending_spawn])


func _toggle_pause() -> void:
	if _lost:
		_exit()
		return
	_paused = not _paused
	get_tree().paused = _paused
	_hud.show_pause(_paused)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _paused else Input.MOUSE_MODE_CAPTURED


func _record_copa_if_needed(team_cleared: bool) -> void:
	if _copa_recorded or _copa_match_id.is_empty():
		return
	JeffreyCore.record_zombies_copa_match(_copa_match_id, participants, team_cleared)
	_copa_recorded = true


func _restart() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_copa_match_id = JeffreyCore.generate_copa_match_id("zombies")
	_copa_recorded = false
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()
		return
	var packed = load("res://scenes/zombies/ZombiesMain.tscn")
	var parent := get_parent()
	if packed == null or parent == null:
		return
	var idx: int = get_index()
	var roster: Array = participants.duplicate(true)
	var fresh = packed.instantiate()
	if fresh.has_method("setup"):
		fresh.call("setup", roster)
	parent.add_child(fresh)
	parent.move_child(fresh, idx)
	queue_free()


func _exit() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	session_exited.emit()
