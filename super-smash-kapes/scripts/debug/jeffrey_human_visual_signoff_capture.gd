extends Node

## Deterministic 1920×1080 visual sign-off capture for Jeffrey shell + Track + Zombies.
## Run windowed on real GPU:
##   Godot --display-driver windows --rendering-method forward_plus --rendering-driver d3d12
##   --gpu-index 0 --resolution 1920x1080 res://scenes/debug/JeffreyHumanVisualSignoffCapture.tscn

const BOOT := preload("res://scripts/ui/jeffrey/boot_screen.gd")
const PLAYERS := preload("res://scripts/ui/jeffrey/players_today_screen.gd")
const HUB := preload("res://scripts/ui/jeffrey/hub_screen.gd")
const CHARS := preload("res://scripts/ui/jeffrey/character_select_screen.gd")
const OPTIONS := preload("res://scripts/ui/jeffrey/options_screen.gd")
const COPA_BOARD := preload("res://scripts/ui/jeffrey/copa_jeffrey_scoreboard_screen.gd")
const COPA_CONFIRM := preload("res://scripts/ui/jeffrey/copa_jeffrey_confirm_dialog.gd")
const COPA_RESULTS := preload("res://scripts/ui/jeffrey/copa_jeffrey_results_screen.gd")
const ZOMBIES_MENU := preload("res://scripts/ui/jeffrey/zombies_menu_screen.gd")
const TrackMainScript := preload("res://scripts/track/track_main.gd")
const RaceScript := preload("res://scripts/track/track_race.gd")
const ModeRegistry := preload("res://scripts/core/jeffrey/game_mode_registry.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")

const OUT_ROOT := "E:/JeffreyAIResearch/outputs/runtime-review/jeffrey_human_visual_signoff_v1"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await get_tree().process_frame
	await get_tree().process_frame
	_ensure_roster()
	_seed_copa()
	_make_dirs()
	_write_meta()

	await _shot(BOOT.new(), "01_boot/01_boot.png", "Boot CTA")
	var players = PLAYERS.new()
	await _shot(players, "02_players_today/02_players_today.png", "Players Today roster")

	var hub = HUB.new()
	await _shot(hub, "03_hub/03_hub.png", "Hub modes + panels")
	await _shot(HUB.new(), "03_hub/04_hub_copa_compact.png", "Hub with Copa compact (same layout)")

	var board = COPA_BOARD.new()
	await _shot(board, "04_copa/05_copa_full.png", "Copa full standings")

	var hub2 = HUB.new()
	add_child(hub2)
	Layout.bind_full(hub2)
	await get_tree().process_frame
	var modal = COPA_CONFIRM.new()
	hub2.add_child(modal)
	await get_tree().process_frame
	await get_tree().process_frame
	_save("04_copa/06_nueva_copa_modal.png", "Nueva Copa modal over Hub")
	hub2.queue_free()
	await get_tree().process_frame

	await _shot(HUB.new(), "03_hub/07_mode_cards.png", "Hub mode cards focus area")

	var chars = CHARS.new()
	chars.mode_id = ModeRegistry.MODE_RACING
	chars.participants = _participants()
	await _shot(chars, "05_character_select/08_character_select.png", "Character select Track")

	## Track entry setup + gameplay + HUD + pause
	OS.set_environment("SSK_PERF_DIAG", "1")
	var track = TrackMainScript.new()
	add_child(track)
	if track.has_method("setup"):
		track.call("setup", _participants(), 424242)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_save("06_track/09_track_entry.png", "Track setup / entry")
	if track.has_method("_on_play"):
		track.call("_on_play", "media", "picante")
	for _i in 90:
		await get_tree().process_frame
	_save("06_track/10_track_gameplay.png", "Track gameplay")
	_save("06_track/11_track_hud.png", "Track HUD focus")
	if track.has_method("_toggle_pause"):
		track.call("_toggle_pause")
	await get_tree().process_frame
	await get_tree().process_frame
	_save("06_track/12_track_pause.png", "Track pause")
	if track.has_method("_toggle_pause"):
		track.call("_toggle_pause")
	await get_tree().process_frame
	track.queue_free()
	await get_tree().process_frame

	var results = COPA_RESULTS.new()
	results.setup(_fake_track_result())
	await _shot(results, "08_results/13_track_results.png", "Track / Copa results")

	await _shot(ZOMBIES_MENU.new(), "07_zombies/14_zombies_setup.png", "Zombies menu setup")

	## Zombies game-over via HUD alone
	var z_hud_script: Script = load("res://scripts/zombies/zombies_hud.gd") as Script
	if z_hud_script != null:
		var zh = z_hud_script.new()
		add_child(zh)
		await get_tree().process_frame
		await get_tree().process_frame
		if zh.has_method("show_game_over"):
			zh.call("show_game_over", 3, 12)
		await get_tree().process_frame
		await get_tree().process_frame
		_save("07_zombies/15_zombies_game_over.png", "Zombies game over")
		zh.queue_free()
		await get_tree().process_frame

	await _shot(OPTIONS.new(), "09_options/16_options.png", "Options / settings")

	print("[JEFFREY_VISUAL_SIGNOFF] PASS root=%s" % OUT_ROOT)
	get_tree().quit(0)


func _ensure_roster() -> void:
	if JeffreyCore.profiles.get_all().is_empty():
		JeffreyCore.profiles.create("Jeffrey")
		JeffreyCore.profiles.create("Enzo")
		JeffreyCore.profiles.create("Kape")
	var ids: Array[String] = []
	for profile in JeffreyCore.profiles.get_all():
		ids.append(profile.profile_id)
		if ids.size() >= 3:
			break
	JeffreyCore.apply_logon_roster(ids, true)


func _seed_copa() -> void:
	JeffreyCore.start_new_copa()
	var ids: Array = JeffreyCore.session.active_player_ids.duplicate()
	if ids.size() < 2:
		return
	var match_id := JeffreyCore.generate_copa_match_id("racing")
	var placements: Array = []
	var place := 1
	for pid in ids:
		placements.append({"profile_id": str(pid), "placement": place})
		place += 1
		if place > 4:
			break
	JeffreyCore.record_match_result({
		"match_id": match_id,
		"mode": "racing",
		"participants": ids,
		"placements": placements,
	})


func _participants() -> Array:
	var out: Array = []
	var slot := 1
	for profile_id in JeffreyCore.session.active_player_ids:
		out.append({"profile_id": profile_id, "player_slot": slot, "character_id": "terere" if slot == 1 else "jaguarete"})
		slot += 1
		if slot > 2:
			break
	return out


func _fake_track_result() -> Dictionary:
	var awarded: Array = []
	var place := 1
	for profile_id in JeffreyCore.session.active_player_ids:
		var pts := 5 if place == 1 else (3 if place == 2 else 2)
		awarded.append({
			"profile_id": profile_id,
			"placement": place,
			"points": pts,
			"total_points": pts,
		})
		place += 1
		if place > 3:
			break
	return {"mode": "racing", "awarded": awarded, "match_id": "visual_signoff"}


func _find_race(track: Node) -> Node:
	for child in track.get_children():
		if child.get_script() == RaceScript:
			return child
	return null


func _make_dirs() -> void:
	for folder in [
		"01_boot", "02_players_today", "03_hub", "04_copa", "05_character_select",
		"06_track", "07_zombies", "08_results", "09_options",
	]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [OUT_ROOT, folder])


func _write_meta() -> void:
	var meta := {
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"resolution": "1920x1080",
		"gpu": str(RenderingServer.get_video_adapter_name()),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"godot": "4.7.2",
	}
	var f := FileAccess.open("%s/CAPTURE_META.json" % OUT_ROOT, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(meta, "\t"))
		f.close()


func _shot(screen: Control, rel: String, state: String) -> void:
	add_child(screen)
	Layout.bind_full(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_save(rel, state)
	screen.queue_free()
	await get_tree().process_frame


func _save(rel: String, state: String) -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("[JEFFREY_VISUAL_SIGNOFF] no image for %s" % rel)
		return
	var path := "%s/%s" % [OUT_ROOT, rel]
	image.save_png(path)
	print("[JEFFREY_VISUAL_SIGNOFF] %s | %s | %s" % [rel, state, path])
