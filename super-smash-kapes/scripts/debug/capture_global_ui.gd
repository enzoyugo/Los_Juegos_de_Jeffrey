extends Node

## Headless layout capture for global UI screens. Does not touch Smash.

const BOOT := preload("res://scripts/ui/jeffrey/boot_screen.gd")
const PLAYERS := preload("res://scripts/ui/jeffrey/players_today_screen.gd")
const HUB := preload("res://scripts/ui/jeffrey/hub_screen.gd")
const EDIT := preload("res://scripts/ui/jeffrey/edit_players_screen.gd")
const MODE_PLAYERS := preload("res://scripts/ui/jeffrey/mode_player_select_screen.gd")
const CHARS := preload("res://scripts/ui/jeffrey/character_select_screen.gd")
const TRANSITION := preload("res://scripts/ui/jeffrey/mode_transition_controller.gd")
const ModeRegistry := preload("res://scripts/core/jeffrey/game_mode_registry.gd")

const SIZES := [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1366, 768),
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	if JeffreyCore.profiles.get_all().is_empty():
		JeffreyCore.profiles.create("Jeffrey")
		JeffreyCore.profiles.create("Enzo")
	var ids: Array[String] = []
	for profile in JeffreyCore.profiles.get_all():
		ids.append(profile.profile_id)
		if ids.size() >= 2:
			break
	JeffreyCore.apply_logon_roster(ids, true)
	var out_dir := "user://global_ui_capture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	for size in SIZES:
		DisplayServer.window_set_size(size)
		await get_tree().process_frame
		await _capture(BOOT.new(), "boot_%dx%d" % [size.x, size.y], out_dir)
		await _capture(PLAYERS.new(), "players_%dx%d" % [size.x, size.y], out_dir)
		await _capture(HUB.new(), "hub_%dx%d" % [size.x, size.y], out_dir)
		await _capture(EDIT.new(), "edit_%dx%d" % [size.x, size.y], out_dir)
		var mode_players = MODE_PLAYERS.new()
		mode_players.mode_id = ModeRegistry.MODE_SMASH
		await _capture(mode_players, "mode_players_%dx%d" % [size.x, size.y], out_dir)
		var chars = CHARS.new()
		chars.mode_id = ModeRegistry.MODE_SMASH
		chars.participants = _sample_participants(ids)
		await _capture(chars, "character_select_%dx%d" % [size.x, size.y], out_dir)
		for mode_id in [ModeRegistry.MODE_SMASH, ModeRegistry.MODE_RACING, ModeRegistry.MODE_ZOMBIES]:
			var transition = TRANSITION.new()
			await _capture_transition(transition, mode_id, "transition_%s_%dx%d" % [mode_id, size.x, size.y], out_dir)
	print("[GLOBAL_UI_CAPTURE] wrote %s" % out_dir)
	get_tree().quit(0)


func _sample_participants(ids: Array[String]) -> Array:
	var out: Array = []
	var slot := 1
	for profile_id in ids:
		out.append({"profile_id": profile_id, "player_slot": slot, "character_id": ""})
		slot += 1
	return out


func _capture(screen: Control, name: String, out_dir: String) -> void:
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_viewport(name, out_dir)
	screen.queue_free()
	await get_tree().process_frame


func _capture_transition(screen: Control, mode_id: String, name: String, out_dir: String) -> void:
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if screen.has_method("show_mode_transition"):
		screen.call("show_mode_transition", mode_id, {"participants": _sample_participants(_session_ids())})
	await get_tree().process_frame
	await get_tree().process_frame
	_save_viewport(name, out_dir)
	screen.queue_free()
	await get_tree().process_frame


func _session_ids() -> Array[String]:
	var ids: Array[String] = []
	for profile_id in JeffreyCore.session.active_player_ids:
		ids.append(profile_id)
	return ids


func _save_viewport(name: String, out_dir: String) -> void:
	var image := get_viewport().get_texture().get_image()
	if image != null:
		var path := "%s/%s.png" % [out_dir, name]
		image.save_png(path)
		print("[GLOBAL_UI_CAPTURE] %s" % path)
