class_name ZombiesConfig
extends RefCounted

const WALK := 6.2
const SPRINT := 9.4
const JUMP := 6.8
const GRAVITY := 28.0
const MOUSE := 0.12
const PITCH_MAX := 1.2
const FIRE_GAP := 0.22
const DAMAGE := 35.0
const PLAYER_HP := 100.0
const ZOMBIE_HP := 80.0
const ZOMBIE_SPEED := 3.4
const ZOMBIE_DAMAGE := 12.0
const ZOMBIE_RANGE := 2.1
const ZOMBIE_ATTACK_GAP := 0.9
const HEALTH_SCALE := 1.12
const POINTS_HIT := 10
const POINTS_KILL := 100
const DOOR_COST := 1000
const DOOR_NAME := "GALERÍA"
const MAIN_ENTRANCE_COST := 1500
const MAIN_ENTRANCE_NAME := "SHOPPING"
const WALL_SMG_COST := 1800
const WALL_AMMO_COST := 750
const ROUND_DELAY := 3.0
const SPAWN_INTERVAL := 0.65
const MAX_ALIVE := 10
const MAX_AMMO_CHANCE := 0.10
const INTERACT_RANGE := 2.8
const DEBUG_POINTS := 5000
const LAYER_WORLD := 1
const LAYER_PLAYER := 4
const LAYER_ZOMBIE := 8
const LAYER_INTERACT := 16
const COLOR_TERRACOTTA := Color("#c47a5a")
const COLOR_CREAM := Color("#e8dcc8")
const COLOR_FLOOR := Color("#2a2420")
const COLOR_DOOR := Color("#8a4a38")
const RELOAD_HINT := "G"
const PISTOL_PATH := "res://data/zombies/pistol.tres"
const SMG_PATH := "res://data/zombies/smg.tres"
const WeaponDataScript := preload("res://scripts/zombies/zombies_weapon_data.gd")


static func ensure_actions() -> void:
	_bind("z_forward", [KEY_W])
	_bind("z_back", [KEY_S])
	_bind("z_left", [KEY_A])
	_bind("z_right", [KEY_D])
	_bind("z_jump", [KEY_SPACE])
	_bind("z_sprint", [KEY_SHIFT])
	_bind("z_fire", [MOUSE_BUTTON_LEFT])
	_bind("z_interact", [KEY_E])
	_bind("z_reload", [KEY_G])
	_bind("z_weapon_next", [KEY_Q])


static func _bind(action: String, codes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for code in codes:
		if code == MOUSE_BUTTON_LEFT:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			if not InputMap.action_has_event(action, mouse):
				InputMap.action_add_event(action, mouse)
		else:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)


static func load_weapon(id: String):
	var path := PISTOL_PATH
	if id == "smg":
		path = SMG_PATH
	var res = load(path)
	if res == null:
		var fallback = WeaponDataScript.new()
		fallback.id = id
		return fallback
	return res


static func is_headless() -> bool:
	if OS.get_environment("SSK_ZOMBIES_SMOKE").strip_edges() == "1":
		return true
	return DisplayServer.get_name() == "headless"
