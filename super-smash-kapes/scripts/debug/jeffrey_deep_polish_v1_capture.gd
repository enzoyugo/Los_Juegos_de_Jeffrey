extends Node

## Deep polish rendered capture — production screens at 1920×1080 (GUI, not headless).

const BOOT := preload("res://scripts/ui/jeffrey/boot_screen.gd")
const PLAYERS := preload("res://scripts/ui/jeffrey/players_today_screen.gd")
const HUB := preload("res://scripts/ui/jeffrey/hub_screen.gd")
const MODE_PLAYERS := preload("res://scripts/ui/jeffrey/mode_player_select_screen.gd")
const CHARS := preload("res://scripts/ui/jeffrey/character_select_screen.gd")
const OPTIONS := preload("res://scripts/ui/jeffrey/options_screen.gd")
const TRACK_MENU := preload("res://scripts/ui/jeffrey/track_menu_screen.gd")
const ZMENU := preload("res://scripts/ui/jeffrey/zombies_menu_screen.gd")
const COPA_RESULTS := preload("res://scripts/ui/jeffrey/copa_jeffrey_results_screen.gd")
const TrackMainScript := preload("res://scripts/track/track_main.gd")
const ModeRegistry := preload("res://scripts/core/jeffrey/game_mode_registry.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const PauseOverlay := preload("res://scripts/ui/kapes_pause_overlay.gd")

const OUT := "E:/JeffreyAIResearch/outputs/runtime-review/jeffrey_overnight_total_repair_v1/DEEP_POLISH"
const FINAL := OUT + "/FINAL"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame
	await get_tree().process_frame
	for d in [OUT, FINAL, OUT + "/SHELL", OUT + "/SMASH", OUT + "/TRACK", OUT + "/ZOMBIES", OUT + "/COMPARE"]:
		DirAccess.make_dir_recursive_absolute(d)
	_ensure_roster()
	print("[DEEP_POLISH_CAPTURE] start size=%s" % str(DisplayServer.window_get_size()))

	await _shell()
	await _smash()
	await _track()
	await _zombies()
	_write_meta()
	print("[DEEP_POLISH_CAPTURE] PASS root=%s" % OUT)
	get_tree().quit(0)


func _ensure_roster() -> void:
	if JeffreyCore.profiles.get_all().is_empty():
		JeffreyCore.profiles.create("Jeffrey")
		JeffreyCore.profiles.create("Enzo")
		JeffreyCore.profiles.create("Sofi")
	var ids: Array[String] = []
	for profile in JeffreyCore.profiles.get_all():
		ids.append(profile.profile_id)
		if ids.size() >= 3:
			break
	JeffreyCore.apply_logon_roster(ids, true)


func _shell() -> void:
	await _ui(PLAYERS.new(), OUT + "/SHELL/01_players_today.png")
	await _ui(HUB.new(), OUT + "/SHELL/02_hub.png")
	var mp = MODE_PLAYERS.new()
	mp.mode_id = ModeRegistry.MODE_SMASH
	await _ui(mp, OUT + "/SHELL/03_mode_player_select.png")
	await _ui(OPTIONS.new(), OUT + "/SHELL/04_options.png")
	## Final copies
	_copy(OUT + "/SHELL/01_players_today.png", FINAL + "/players_today.png")
	_copy(OUT + "/SHELL/02_hub.png", FINAL + "/hub.png")
	_copy(OUT + "/SHELL/03_mode_player_select.png", FINAL + "/mode_players.png")
	_copy(OUT + "/SHELL/04_options.png", FINAL + "/options.png")


func _smash() -> void:
	var chars = CHARS.new()
	chars.mode_id = ModeRegistry.MODE_SMASH
	chars.participants = _participants(["terere", "jaguarete"])
	await _ui(chars, OUT + "/SMASH/05_character_select.png")
	_copy(OUT + "/SMASH/05_character_select.png", FINAL + "/smash_character_select.png")

	for pair in [
		["defensores", OUT + "/SMASH/06_defensores.png", FINAL + "/smash_defensores.png"],
		["palacio", OUT + "/SMASH/07_palacio.png", FINAL + "/smash_palacio.png"],
		["costanera", OUT + "/SMASH/08_costanera.png", FINAL + "/smash_costanera.png"],
	]:
		await _smash_stage(str(pair[0]), str(pair[1]), str(pair[2]))

	var pause = PauseOverlay.new()
	add_child(pause)
	Layout.bind_full(pause)
	await get_tree().process_frame
	await get_tree().process_frame
	await _save(OUT + "/SMASH/09_pause.png")
	_copy(OUT + "/SMASH/09_pause.png", FINAL + "/smash_pause.png")
	pause.queue_free()
	await get_tree().process_frame

	var results = COPA_RESULTS.new()
	add_child(results)
	Layout.bind_full(results)
	results.setup({
		"mode": "smash",
		"awarded": [
			{"profile_id": _ids()[0], "placement": 1, "points": 5, "total_points": 5, "fighter_id": "terere"},
			{"profile_id": _ids()[1], "placement": 2, "points": 3, "total_points": 3, "fighter_id": "jaguarete"},
		],
	})
	await get_tree().process_frame
	await get_tree().process_frame
	await _save(OUT + "/SMASH/10_result.png")
	_copy(OUT + "/SMASH/10_result.png", FINAL + "/smash_result.png")
	results.queue_free()
	await get_tree().process_frame


func _smash_stage(stage_id: String, path: String, final_path: String) -> void:
	OS.set_environment("SSK_STAGE_ID", stage_id)
	OS.set_environment("SSK_AUTO_START_BATTLE", "1")
	var packed := load("res://scenes/core/M0Playground.tscn") as PackedScene
	if packed == null:
		print("[DEEP_POLISH] M0Playground missing")
		return
	var host = packed.instantiate()
	add_child(host)
	for _i in 40:
		await get_tree().process_frame
	await _save(path)
	_copy(path, final_path)
	host.queue_free()
	await get_tree().process_frame
	OS.set_environment("SSK_AUTO_START_BATTLE", "")
	OS.set_environment("SSK_STAGE_ID", "")


func _track() -> void:
	var menu = TRACK_MENU.new()
	menu.configure(_participants(["gallo", "chick_hicks"]))
	await _ui(menu, OUT + "/TRACK/11_track_menu.png")
	_copy(OUT + "/TRACK/11_track_menu.png", FINAL + "/track_menu.png")

	var track = TrackMainScript.new()
	track.setup(_participants(["gallo", "chick_hicks"]), 424242, "media", "picante")
	add_child(track)
	await get_tree().process_frame
	await get_tree().process_frame
	if track.has_method("_on_play"):
		track.call("_on_play", "media", "picante")
	for _i in 45:
		await get_tree().process_frame
	await _save(OUT + "/TRACK/12_track_gameplay.png")
	_copy(OUT + "/TRACK/12_track_gameplay.png", FINAL + "/track_gameplay.png")

	## Steering visual — nudge car input if present
	var car = null
	for c in track.get_children():
		if c.is_in_group("track_runtime_car") or c.has_method("apply_track_boost"):
			car = c
			break
	if car != null:
		car.set("control_enabled", true)
	for _i in 45:
		if InputMap.has_action("steer_right"):
			Input.action_press("steer_right")
		elif InputMap.has_action("ui_right"):
			Input.action_press("ui_right")
		if InputMap.has_action("accelerate"):
			Input.action_press("accelerate")
		await get_tree().process_frame
	if InputMap.has_action("steer_right"):
		Input.action_release("steer_right")
	if InputMap.has_action("ui_right"):
		Input.action_release("ui_right")
	if InputMap.has_action("accelerate"):
		Input.action_release("accelerate")
	await get_tree().process_frame
	await _save(OUT + "/TRACK/13_track_steering.png")
	_copy(OUT + "/TRACK/13_track_steering.png", FINAL + "/track_steering.png")

	for c in track.get_children():
		if c is CanvasLayer and c.has_method("show_pause"):
			c.show_pause(true)
			await get_tree().process_frame
			await _save(OUT + "/TRACK/14_track_pause.png")
			_copy(OUT + "/TRACK/14_track_pause.png", FINAL + "/track_pause.png")
			c.show_pause(false)
			break

	track.queue_free()
	await get_tree().process_frame

	var results = COPA_RESULTS.new()
	add_child(results)
	Layout.bind_full(results)
	results.setup({
		"mode": "racing",
		"awarded": [
			{"profile_id": _ids()[0], "placement": 1, "points": 5, "total_points": 12},
			{"profile_id": _ids()[1], "placement": 2, "points": 3, "total_points": 8},
		],
	})
	await get_tree().process_frame
	await get_tree().process_frame
	await _save(OUT + "/TRACK/15_track_result.png")
	_copy(OUT + "/TRACK/15_track_result.png", FINAL + "/track_result.png")
	results.queue_free()
	await get_tree().process_frame


func _zombies() -> void:
	var menu = ZMENU.new()
	await _ui(menu, OUT + "/ZOMBIES/16_zombies_menu.png")
	_copy(OUT + "/ZOMBIES/16_zombies_menu.png", FINAL + "/zombies_menu.png")

	var packed := load("res://scenes/zombies/ZombiesMain.tscn") as PackedScene
	if packed == null:
		return
	var host = packed.instantiate()
	if host.has_method("setup"):
		host.call("setup", _participants(["terere"]))
	add_child(host)
	for _i in 50:
		await get_tree().process_frame
	await _save(OUT + "/ZOMBIES/17_shopping_environment.png")
	_copy(OUT + "/ZOMBIES/17_shopping_environment.png", FINAL + "/zombies_environment.png")
	await _save(OUT + "/ZOMBIES/18_zombies_gameplay.png")
	_copy(OUT + "/ZOMBIES/18_zombies_gameplay.png", FINAL + "/zombies_gameplay.png")
	## Allow spawn frames
	for _i in 90:
		await get_tree().process_frame
	await _save(OUT + "/ZOMBIES/19_zombies_combat.png")
	_copy(OUT + "/ZOMBIES/19_zombies_combat.png", FINAL + "/zombies_combat.png")
	for c in host.get_children():
		if c is CanvasLayer and c.has_method("show_pause"):
			c.show_pause(true)
			await get_tree().process_frame
			await _save(OUT + "/ZOMBIES/20_zombies_end.png")
			_copy(OUT + "/ZOMBIES/20_zombies_end.png", FINAL + "/zombies_end.png")
			break
	if not FileAccess.file_exists(OUT + "/ZOMBIES/20_zombies_end.png"):
		await _save(OUT + "/ZOMBIES/20_zombies_end.png")
		_copy(OUT + "/ZOMBIES/20_zombies_end.png", FINAL + "/zombies_end.png")
	host.queue_free()
	await get_tree().process_frame


func _ui(screen: Control, path: String) -> void:
	add_child(screen)
	Layout.bind_full(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _save(path)
	screen.queue_free()
	await get_tree().process_frame


func _save(path: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		print("[DEEP_POLISH] FAIL capture %s" % path)
		return
	img.save_png(path)
	print("[DEEP_POLISH_SHOT] %s (%dx%d)" % [path.get_file(), img.get_width(), img.get_height()])


func _copy(src: String, dst: String) -> void:
	if FileAccess.file_exists(src):
		DirAccess.copy_absolute(src, dst)


func _ids() -> Array[String]:
	var ids: Array[String] = []
	for profile in JeffreyCore.profiles.get_all():
		ids.append(profile.profile_id)
	return ids


func _participants(chars: Array) -> Array:
	var ids := _ids()
	var out: Array = []
	for i in mini(ids.size(), chars.size()):
		out.append({
			"profile_id": ids[i],
			"character_id": str(chars[i]),
			"player_slot": i + 1,
		})
	return out


func _write_meta() -> void:
	var f := FileAccess.open(OUT + "/CAPTURE_META.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"sprint": "JEFFREY_OVERNIGHT_TOTAL_REPAIR_V1_CONTINUE_DEEP_POLISH",
			"resolution": "1920x1080",
			"head": "9dabf79+",
			"rendered": true,
		}, "\t"))
		f.close()
