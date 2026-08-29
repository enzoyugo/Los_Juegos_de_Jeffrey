extends Node

const MAIN_SCENE_PATH := "res://scenes/core/Main.tscn"
const BOOT_SCREEN := preload("res://scripts/ui/jeffrey/boot_screen.gd")
const PLAYERS_TODAY := preload("res://scripts/ui/jeffrey/players_today_screen.gd")
const GAME_SELECT := preload("res://scripts/ui/jeffrey/hub_screen.gd")
const EDIT_PLAYERS := preload("res://scripts/ui/jeffrey/edit_players_screen.gd")
const MODE_PLAYERS := preload("res://scripts/ui/jeffrey/mode_player_select_screen.gd")
const CHAR_SELECT := preload("res://scripts/ui/jeffrey/character_select_screen.gd")
const TRANSITION := preload("res://scripts/ui/jeffrey/mode_transition_controller.gd")
const COMING_SOON := preload("res://scripts/ui/jeffrey/coming_soon_screen.gd")
const ZOMBIES_MENU := preload("res://scripts/ui/jeffrey/zombies_menu_screen.gd")
const ZOMBIES_LOADING := preload("res://scripts/ui/jeffrey/zombies_loading_screen.gd")
const TRACK_MENU := preload("res://scripts/ui/jeffrey/track_menu_screen.gd")
const TRACK_SCENE_PATH := "res://scenes/track/TrackMain.tscn"
const ZOMBIES_SCENE_PATH := "res://scenes/zombies/ZombiesMain.tscn"
const OPTIONS_SCREEN := preload("res://scripts/ui/jeffrey/options_screen.gd")
const COPA_RESULTS := preload("res://scripts/ui/jeffrey/copa_jeffrey_results_screen.gd")
const COPA_SCOREBOARD := preload("res://scripts/ui/jeffrey/copa_jeffrey_scoreboard_screen.gd")
const COPA_CONFIRM := preload("res://scripts/ui/jeffrey/copa_jeffrey_confirm_dialog.gd")
const UILayout := preload("res://scripts/ui/kapes_ui_layout.gd")
const ShellTransition := preload("res://scripts/ui/jeffrey/system/jeffrey_shell_transition.gd")
const ModeRegistry := preload("res://scripts/core/jeffrey/game_mode_registry.gd")
const MATCH_SETUP := preload("res://scripts/core/match_setup.gd")

var ui: CanvasLayer
var screen_root: Control
var smash_host: Node = null
var track_host: Node = null
var zombies_host: Node = null
var pending_mode_id: String = ""
var pending_stage_id: String = "defensores"
var pending_match_profile_ids: Array[String] = []
var pending_participants: Array = []
var pending_track_length_id: String = "media"
var pending_track_difficulty_id: String = "picante"
var _fading: Control = null
var _transition_busy: bool = false
var _zombies_browse_characters: bool = false
var _last_shown_copa_match_id: String = ""
var _copa_overlay: Control = null
var _preloaded_track: PackedScene = null
var _preloaded_zombies: PackedScene = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui = CanvasLayer.new()
	ui.name = "ShellUI"
	ui.layer = 8
	add_child(ui)
	if OS.get_environment("SSK_AUTO_START_BATTLE") == "1" or OS.get_environment("SSK_AUTO_SELECT_BATTLE") == "1":
		_bootstrap_dev_session()
		_host_smash()
		return
	_show_boot()


func _show_boot() -> void:
	_clear_smash_host()
	var screen = BOOT_SCREEN.new()
	screen.start_pressed.connect(func(): _show_players_today(false))
	screen.quit_pressed.connect(func(): get_tree().quit())
	_present(screen)


func _show_players_today(edit_session: bool) -> void:
	_clear_smash_host()
	var screen = PLAYERS_TODAY.new()
	screen.context = PLAYERS_TODAY.CONTEXT_EDIT if edit_session else PLAYERS_TODAY.CONTEXT_BOOT
	screen.roster_confirmed.connect(func(ids): _on_logon_confirmed(ids, not edit_session))
	if edit_session:
		screen.cancelled.connect(_show_game_select)
	else:
		screen.cancelled.connect(_show_boot)
	_present(screen)


func _on_logon_confirmed(ids, is_new_session: bool) -> void:
	var selected: Array[String] = []
	for item in ids:
		selected.append(str(item))
	JeffreyCore.apply_logon_roster(selected, is_new_session)
	_show_game_select()


func _show_copa_scoreboard() -> void:
	var screen = COPA_SCOREBOARD.new()
	screen.back_pressed.connect(_show_game_select)
	screen.nueva_copa_pressed.connect(_show_nueva_copa_confirm)
	_present(screen)


func _show_nueva_copa_confirm() -> void:
	_clear_copa_overlay()
	var dialog = COPA_CONFIRM.new()
	_copa_overlay = dialog
	ui.add_child(dialog)
	dialog.confirmed.connect(func():
		JeffreyCore.start_new_copa()
		_last_shown_copa_match_id = ""
		_clear_copa_overlay()
		_show_game_select()
	)
	dialog.cancelled.connect(_clear_copa_overlay)


func _clear_copa_overlay() -> void:
	if _copa_overlay != null and is_instance_valid(_copa_overlay):
		_copa_overlay.queue_free()
	_copa_overlay = null


func _maybe_show_copa_results(mode_id: String, on_hub: Callable) -> bool:
	var result: Dictionary = JeffreyCore.copa.last_recorded_result
	var match_id := str(result.get("match_id", ""))
	if result.is_empty() or match_id.is_empty() or match_id == _last_shown_copa_match_id:
		return false
	_show_copa_results(mode_id, result, on_hub)
	return true


func _show_copa_results(mode_id: String, result: Dictionary, on_hub: Callable) -> void:
	_clear_screen()
	var screen = COPA_RESULTS.new()
	screen.setup(result)
	screen.revancha_pressed.connect(func(): _on_copa_revancha(mode_id))
	screen.hub_pressed.connect(func():
		_last_shown_copa_match_id = str(result.get("match_id", ""))
		on_hub.call()
	)
	_present(screen)


func _on_copa_revancha(mode_id: String) -> void:
	_last_shown_copa_match_id = str(JeffreyCore.copa.last_recorded_result.get("match_id", ""))
	if mode_id == ModeRegistry.MODE_SMASH and smash_host != null and is_instance_valid(smash_host):
		_clear_screen()
		if smash_host.has_method("_start_match"):
			smash_host.call("_start_match")
		return
	if mode_id == ModeRegistry.MODE_RACING and track_host != null and is_instance_valid(track_host):
		_clear_screen()
		if track_host.has_method("restart_session"):
			track_host.call("restart_session")
		else:
			_host_track({})
		return
	if mode_id == ModeRegistry.MODE_ZOMBIES:
		_clear_screen()
		## Never call ZombiesMain._restart under shell hosting — it orphans a fresh
		## host while zombies_host still points at the freeing instance (VRAM leak).
		_clear_mode_hosts()
		_host_zombies({})
		return
	_show_game_select()


func _finish_mode_to_hub(mode_id: String) -> void:
	if _maybe_show_copa_results(mode_id, func(): _return_mode_host_to_hub(mode_id)):
		return
	_return_mode_host_to_hub(mode_id)


func _return_mode_host_to_hub(_mode_id: String) -> void:
	_clear_smash_host()
	_show_game_select()


func _show_game_select() -> void:
	_clear_smash_host()
	pending_mode_id = ""
	pending_match_profile_ids.clear()
	pending_participants.clear()
	_transition_busy = false
	_zombies_browse_characters = false
	var screen = GAME_SELECT.new()
	screen.mode_chosen.connect(_on_mode_chosen)
	screen.edit_players_pressed.connect(_show_edit_players)
	screen.options_pressed.connect(_show_options)
	screen.scoreboard_pressed.connect(_show_copa_scoreboard)
	screen.nueva_copa_pressed.connect(_show_nueva_copa_confirm)
	_present(screen)


func _show_edit_players() -> void:
	var screen = EDIT_PLAYERS.new()
	screen.saved.connect(_on_edit_saved)
	screen.cancelled.connect(_show_game_select)
	_present(screen)


func _on_edit_saved(ids) -> void:
	var selected: Array[String] = []
	for item in ids:
		selected.append(str(item))
	JeffreyCore.apply_logon_roster(selected, false)
	_show_game_select()


func _show_options() -> void:
	var screen = OPTIONS_SCREEN.new()
	screen.back_pressed.connect(_show_game_select)
	_present(screen)


func _show_zombies_options() -> void:
	var screen = OPTIONS_SCREEN.new()
	screen.back_pressed.connect(_show_zombies_menu)
	_present(screen)


func _on_mode_chosen(mode_id: String) -> void:
	pending_mode_id = mode_id
	pending_match_profile_ids.clear()
	pending_participants.clear()
	_zombies_browse_characters = false
	if mode_id == ModeRegistry.MODE_ZOMBIES:
		_show_zombies_menu()
		return
	_show_mode_players()


func _show_zombies_menu() -> void:
	_clear_smash_host()
	_transition_busy = false
	_zombies_browse_characters = false
	pending_mode_id = ModeRegistry.MODE_ZOMBIES
	var screen = ZOMBIES_MENU.new()
	screen.play_pressed.connect(_on_zombies_play)
	screen.characters_pressed.connect(_on_zombies_characters)
	screen.map_pressed.connect(func(): pass)
	screen.options_pressed.connect(_show_zombies_options)
	screen.back_pressed.connect(_show_game_select)
	_present(screen)


func _on_zombies_play() -> void:
	_zombies_browse_characters = false
	_show_mode_players()


func _on_zombies_characters() -> void:
	_zombies_browse_characters = true
	if pending_match_profile_ids.is_empty():
		var mode = JeffreyCore.modes.get_mode(ModeRegistry.MODE_ZOMBIES)
		var max_p: int = mode.max_players if mode != null else 2
		for profile_id in JeffreyCore.session.active_player_ids:
			pending_match_profile_ids.append(profile_id)
			if pending_match_profile_ids.size() >= max_p:
				break
	_show_character_select()


func _show_mode_players() -> void:
	var screen = MODE_PLAYERS.new()
	screen.mode_id = pending_mode_id
	screen.preselected_ids = pending_match_profile_ids.duplicate()
	screen.players_confirmed.connect(_on_mode_players_confirmed)
	if pending_mode_id == ModeRegistry.MODE_ZOMBIES:
		screen.cancelled.connect(_show_zombies_menu)
	else:
		screen.cancelled.connect(_show_game_select)
	_present(screen)


func _on_mode_players_confirmed(ids) -> void:
	pending_match_profile_ids.clear()
	for item in ids:
		pending_match_profile_ids.append(str(item))
	_show_character_select()


func _show_character_select() -> void:
	var screen = CHAR_SELECT.new()
	screen.mode_id = pending_mode_id
	screen.participants = _slot_participants()
	screen.roster_confirmed.connect(func(parts: Array):
		pending_stage_id = screen.selected_stage_id
		_on_characters_confirmed(parts)
	)
	if _zombies_browse_characters:
		screen.cancelled.connect(_show_zombies_menu)
	else:
		screen.cancelled.connect(_show_mode_players)
	_present(screen)


func _slot_participants() -> Array:
	var out: Array = []
	var slot := 1
	for profile_id in pending_match_profile_ids:
		out.append({
			"profile_id": profile_id,
			"player_slot": slot,
			"character_id": "",
		})
		slot += 1
	return out


func _on_characters_confirmed(payload) -> void:
	pending_participants = []
	for row in payload:
		pending_participants.append(row)
	if _zombies_browse_characters:
		_zombies_browse_characters = false
		_show_zombies_menu()
		return
	if pending_mode_id == ModeRegistry.MODE_RACING:
		_show_track_menu()
		return
	_show_mode_transition()


func _show_track_menu() -> void:
	_clear_smash_host()
	_transition_busy = false
	pending_mode_id = ModeRegistry.MODE_RACING
	var screen = TRACK_MENU.new()
	screen.configure(pending_participants)
	screen.length_id = pending_track_length_id
	screen.difficulty_id = pending_track_difficulty_id
	screen.start_pressed.connect(_on_track_menu_start)
	screen.back_pressed.connect(_show_character_select)
	_present(screen)


func _on_track_menu_start(length_id: String, difficulty_id: String) -> void:
	pending_track_length_id = length_id
	pending_track_difficulty_id = difficulty_id
	_show_mode_transition()


func _show_mode_transition() -> void:
	if _transition_busy:
		return
	_transition_busy = true
	print("[INPUT_RECEIVED] shell_mode_entry mode=%s" % pending_mode_id)
	var mode = JeffreyCore.modes.get_mode(pending_mode_id)
	var context := {
		"participants": pending_participants,
		"target_scene": mode.scene_path if mode != null else "",
	}
	## Begin scene load behind the transition so reveal is continuous.
	if pending_mode_id == ModeRegistry.MODE_RACING:
		_preloaded_track = load(TRACK_SCENE_PATH) as PackedScene
	elif pending_mode_id == ModeRegistry.MODE_ZOMBIES:
		_preloaded_zombies = load(ZOMBIES_SCENE_PATH) as PackedScene
	if pending_mode_id == ModeRegistry.MODE_ZOMBIES:
		var zombies_loading = ZOMBIES_LOADING.new()
		zombies_loading.finished.connect(_on_transition_finished)
		_present(zombies_loading)
		zombies_loading.present(pending_mode_id, context)
		print("[TRANSITION_STARTED] zombies_loading")
		return
	var screen = TRANSITION.new()
	screen.finished.connect(_on_transition_finished)
	_present(screen)
	screen.show_mode_transition(pending_mode_id, context)


func _on_transition_finished(mode_id: String, context: Dictionary) -> void:
	if mode_id == ModeRegistry.MODE_SMASH:
		_host_smash_resolved(context)
		return
	if mode_id == ModeRegistry.MODE_RACING:
		_host_track(context)
		return
	if mode_id == ModeRegistry.MODE_ZOMBIES:
		_host_zombies(context)
		return
	_transition_busy = false
	_show_coming_soon()


func _show_coming_soon() -> void:
	var screen = COMING_SOON.new()
	screen.mode_id = pending_mode_id
	var names: PackedStringArray = PackedStringArray()
	for profile_id in pending_match_profile_ids:
		var profile = JeffreyCore.profiles.get_profile(profile_id)
		if profile != null:
			names.append(profile.display_name)
	screen.participant_names = names
	screen.back_pressed.connect(_show_mode_players)
	_present(screen)


func _host_track(_context: Dictionary) -> void:
	if track_host != null and is_instance_valid(track_host):
		_transition_busy = false
		return
	_clear_screen()
	_clear_smash_host()
	print("[SCREEN_SWITCHED] track_host")
	var packed: PackedScene = _preloaded_track
	if packed == null:
		packed = load(TRACK_SCENE_PATH) as PackedScene
	_preloaded_track = null
	if packed == null:
		_show_load_error("TRACK")
		return
	track_host = packed.instantiate()
	if track_host.has_method("setup"):
		track_host.call(
			"setup",
			pending_participants,
			0,
			pending_track_length_id,
			pending_track_difficulty_id
		)
	if track_host.has_signal("session_exited"):
		track_host.connect("session_exited", func(): _finish_mode_to_hub(ModeRegistry.MODE_RACING))
	add_child(track_host)
	_transition_busy = false


func _host_zombies(_context: Dictionary) -> void:
	if zombies_host != null and is_instance_valid(zombies_host):
		_transition_busy = false
		return
	_clear_screen()
	_clear_smash_host()
	print("[SCREEN_SWITCHED] zombies_host")
	var packed: PackedScene = _preloaded_zombies
	if packed == null:
		packed = load(ZOMBIES_SCENE_PATH) as PackedScene
	_preloaded_zombies = null
	if packed == null:
		_show_load_error("ZOMBIES")
		return
	zombies_host = packed.instantiate()
	if zombies_host.has_method("setup"):
		zombies_host.call("setup", pending_participants)
	if zombies_host.has_signal("session_exited"):
		zombies_host.connect("session_exited", func(): _finish_mode_to_hub(ModeRegistry.MODE_ZOMBIES))
	add_child(zombies_host)
	_transition_busy = false


func _host_smash() -> void:
	_clear_screen()
	_clear_smash_host()
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_show_load_error("SMASH")
		return
	smash_host = packed.instantiate()
	smash_host.hosted_by_shell = true
	if pending_match_profile_ids.size() >= 1:
		smash_host.hosted_p1_profile_id = pending_match_profile_ids[0]
	if pending_match_profile_ids.size() >= 2:
		smash_host.hosted_p2_profile_id = pending_match_profile_ids[1]
	smash_host.smash_session_exited.connect(func(): _finish_mode_to_hub(ModeRegistry.MODE_SMASH))
	smash_host.smash_character_select_cancelled.connect(_show_mode_players)
	add_child(smash_host)
	if OS.get_environment("SSK_AUTO_START_BATTLE") == "1" or OS.get_environment("SSK_AUTO_SELECT_BATTLE") == "1":
		return
	smash_host.begin_character_select()


func _host_smash_resolved(context: Dictionary) -> void:
	var setup = MATCH_SETUP.new()
	var parts: Array = context.get("participants", pending_participants)
	if parts.size() >= 1:
		setup.player_1_profile_id = str(parts[0].get("profile_id", ""))
		setup.player_1_fighter_id = JeffreyCore.characters.smash_fighter_id_for(str(parts[0].get("character_id", "")))
	if parts.size() >= 2:
		setup.player_2_profile_id = str(parts[1].get("profile_id", ""))
		setup.player_2_fighter_id = JeffreyCore.characters.smash_fighter_id_for(str(parts[1].get("character_id", "")))
	var StageCatalog := preload("res://scripts/stages/stage_catalog.gd")
	setup.stage_id = pending_stage_id if pending_stage_id != "" else StageCatalog.default_stage_id()
	_clear_screen()
	_clear_smash_host()
	smash_host = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	smash_host.hosted_by_shell = true
	smash_host.hosted_p1_profile_id = setup.player_1_profile_id
	smash_host.hosted_p2_profile_id = setup.player_2_profile_id
	smash_host.smash_session_exited.connect(func(): _finish_mode_to_hub(ModeRegistry.MODE_SMASH))
	smash_host.smash_character_select_cancelled.connect(_show_mode_players)
	add_child(smash_host)
	if not smash_host.begin_hosted_match(setup):
		_transition_busy = false
		_show_character_select()
		return
	_transition_busy = false


func _bootstrap_dev_session() -> void:
	if JeffreyCore.profiles.get_all().is_empty():
		JeffreyCore.profiles.create("P1")
		JeffreyCore.profiles.create("P2")
	var ids: Array[String] = []
	for profile in JeffreyCore.profiles.get_all():
		ids.append(profile.profile_id)
		if ids.size() >= 2:
			break
	JeffreyCore.apply_logon_roster(ids, true)
	pending_mode_id = ModeRegistry.MODE_SMASH
	pending_match_profile_ids = ids


func _show_load_error(mode_label: String) -> void:
	_transition_busy = false
	_clear_screen()
	_clear_smash_host()
	var panel := Control.new()
	UILayout.bind_full_rect(panel)
	var wash := ColorRect.new()
	wash.color = Color(0.02, 0.03, 0.05, 0.92)
	UILayout.bind_full_rect(wash)
	panel.add_child(wash)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	UILayout.bind_full_rect(box)
	panel.add_child(box)
	var title := Label.new()
	title.text = "ERROR AL CARGAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#f05a3c"))
	box.add_child(title)
	var detail := Label.new()
	detail.text = "No se pudo abrir %s." % mode_label
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 20)
	detail.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	box.add_child(detail)
	var back := Button.new()
	back.text = "VOLVER AL HUB"
	back.custom_minimum_size = Vector2(280, 56)
	back.pressed.connect(func(): _finish_mode_to_hub(""))
	box.add_child(back)
	_present(panel)
	call_deferred("_focus_load_error_button", back)


func _focus_load_error_button(button: Button) -> void:
	if is_instance_valid(button):
		button.grab_focus()


func _present(screen: Control) -> void:
	_clear_smash_host()
	var previous := screen_root
	screen_root = Control.new()
	screen_root.name = "ScreenRoot"
	UILayout.bind_full_rect(screen_root)
	ui.add_child(screen_root)
	UILayout.bind_full_rect(screen)
	screen_root.add_child(screen)
	ShellTransition.present(self, screen_root, screen, previous, func():
		if previous != null and is_instance_valid(previous):
			if _fading == previous:
				_fading = null
	)
	if previous != null and is_instance_valid(previous):
		_fading = previous


func _clear_screen() -> void:
	if _fading != null and is_instance_valid(_fading):
		_fading.queue_free()
	_fading = null
	if screen_root != null and is_instance_valid(screen_root):
		screen_root.queue_free()
	screen_root = null


func _clear_smash_host() -> void:
	_clear_mode_hosts()


func _clear_mode_hosts() -> void:
	if smash_host != null and is_instance_valid(smash_host):
		if smash_host.has_method("_stop_match"):
			smash_host._stop_match()
		smash_host.queue_free()
	smash_host = null
	if track_host != null and is_instance_valid(track_host):
		track_host.queue_free()
	track_host = null
	if zombies_host != null and is_instance_valid(zombies_host):
		zombies_host.queue_free()
	zombies_host = null
	## Sweep orphans from prior _restart bugs or failed transitions.
	for child in get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child.is_in_group("jeffrey_mode_host"):
			child.queue_free()
	get_tree().paused = false
