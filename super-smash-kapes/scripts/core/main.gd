extends Node

signal smash_session_exited
signal smash_character_select_cancelled

const PLAYGROUND_SCENE := preload("res://scenes/core/M0Playground.tscn")
const FLAG_WIPE := preload("res://scripts/ui/flag_wipe.gd")
const UI_LAYERS := preload("res://scripts/ui/kapes_layers.gd")
const UILayout := preload("res://scripts/ui/kapes_ui_layout.gd")
const MENU_SCREEN := "res://scripts/ui/kapes_menu_screen.gd"
const RESULTS_SCREEN := "res://scripts/ui/kapes_results_screen.gd"
const PAUSE_OVERLAY := preload("res://scripts/ui/kapes_pause_overlay.gd")
const CHARACTER_SELECT := "res://scripts/ui/kapes_character_select.gd"
const MATCH_SETUP := preload("res://scripts/core/match_setup.gd")
const FIGHTER_CATALOG := preload("res://scripts/fighters/fighter_catalog.gd")

@onready var ui: CanvasLayer = $UI
var active_match: M0Playground = null
var screen_root: Control = null
var pause_overlay: Control = null
var is_result_screen: bool = false
var transitioning: bool = false
var match_setup = MATCH_SETUP.new()
var hosted_by_shell: bool = false
var hosted_p1_profile_id: String = ""
var hosted_p2_profile_id: String = ""
var _copa_match_id: String = ""
var _copa_recorded: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	ui.layer = UI_LAYERS.MENU_UI
	match_setup = FIGHTER_CATALOG.default_match_setup()
	if OS.get_environment("SSK_FREEZE_AUDIT") == "1":
		print("[FREEZE_AUDIT] main ready")
	if hosted_by_shell:
		if OS.get_environment("SSK_AUTO_START_BATTLE") == "1":
			get_tree().create_timer(0.5, true, false, true).timeout.connect(_start_match)
		elif OS.get_environment("SSK_AUTO_SELECT_BATTLE") == "1":
			get_tree().create_timer(0.5, true, false, true).timeout.connect(_auto_select_battle)
		return
	_show_title()
	if OS.get_environment("SSK_AUTO_START_BATTLE") == "1":
		get_tree().create_timer(0.5, true, false, true).timeout.connect(_start_match)
	elif OS.get_environment("SSK_AUTO_SELECT_BATTLE") == "1":
		get_tree().create_timer(0.5, true, false, true).timeout.connect(_auto_select_battle)

func _input(event: InputEvent) -> void:
	var select_screen: Node = _get_character_select()
	if select_screen == null:
		return
	if select_screen.handle_input_event(event):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if hosted_by_shell and active_match == null and not is_result_screen and not transitioning:
		if event.is_action_pressed("pause_match") and _get_character_select() != null:
			smash_character_select_cancelled.emit()
			get_viewport().set_input_as_handled()
			return
	if active_match != null and event.is_action_pressed("pause_match"):
		_toggle_pause()
		return
	if active_match == null and not transitioning and (event.is_action_pressed("p1_attack") or event.is_action_pressed("p1_jump")):
		if not is_result_screen and screen_root != null and screen_root.get_child_count() > 0 and screen_root.get_child(0).has_signal("battle_pressed"):
			_show_character_select()

func _show_title() -> void:
	_stop_match()
	transitioning = false
	is_result_screen = false
	var root := _new_screen()
	var menu = (load(MENU_SCREEN) as GDScript).new()
	UILayout.bind_full_rect(menu)
	root.add_child(menu)
	menu.battle_pressed.connect(_show_character_select)

func begin_character_select() -> void:
	_show_character_select()


func begin_hosted_match(setup) -> bool:
	if setup == null:
		return false
	if not _validate_match_setup(setup):
		return false
	hosted_p1_profile_id = str(setup.player_1_profile_id)
	hosted_p2_profile_id = str(setup.player_2_profile_id)
	_start_match_with_setup(setup)
	return true


func _show_character_select() -> void:
	if transitioning:
		return
	transitioning = false
	is_result_screen = false
	_release_menu_focus()
	var root := _new_screen()
	var select_screen = (load(CHARACTER_SELECT) as GDScript).new()
	UILayout.bind_full_rect(select_screen)
	root.add_child(select_screen)
	select_screen.roster_confirmed.connect(_start_match_with_setup)
	if hosted_by_shell and select_screen.has_method("set_participant_names"):
		select_screen.call("set_participant_names", _hosted_profile_name(hosted_p1_profile_id, "P1"), _hosted_profile_name(hosted_p2_profile_id, "P2"))

func _get_character_select() -> Node:
	if screen_root == null or not is_instance_valid(screen_root) or screen_root.get_child_count() == 0:
		return null
	var child: Node = screen_root.get_child(0)
	if child != null and child.has_method("handle_input_event"):
		return child
	return null

func _auto_select_battle() -> void:
	_show_character_select()
	call_deferred("_run_auto_select_battle")

func _run_auto_select_battle() -> void:
	var select_screen: Node = _get_character_select()
	if select_screen == null:
		return
	if select_screen.has_method("auto_confirm_for_testing"):
		select_screen.call("auto_confirm_for_testing")

func _start_match_with_setup(setup) -> void:
	if not _validate_match_setup(setup):
		return
	_release_menu_focus()
	match_setup = setup.duplicate_setup()
	match_setup.player_1_profile_id = hosted_p1_profile_id
	match_setup.player_2_profile_id = hosted_p2_profile_id
	if OS.get_environment("SSK_SELECT_AUDIT") == "1":
		print("[SELECT_AUDIT] battle entered")
	if hosted_by_shell:
		print("[CHARACTER] %s -> %s" % [_hosted_profile_name(hosted_p1_profile_id, "P1"), setup.player_1_fighter_id])
		print("[CHARACTER] %s -> %s" % [_hosted_profile_name(hosted_p2_profile_id, "P2"), setup.player_2_fighter_id])
	_start_match()

func _validate_match_setup(setup) -> bool:
	if setup == null:
		push_error("Character Select passed null MatchSetup")
		return false
	var p1_def = FIGHTER_CATALOG.get_by_id(setup.player_1_fighter_id)
	var p2_def = FIGHTER_CATALOG.get_by_id(setup.player_2_fighter_id)
	if p1_def == null or p2_def == null:
		push_error("Main rejected MatchSetup IDs: P1=%s P2=%s" % [setup.player_1_fighter_id, setup.player_2_fighter_id])
		return false
	return true

func _start_match() -> void:
	if active_match != null or transitioning:
		return
	_play_transition(_enter_match)

func _enter_match() -> void:
	transitioning = false
	get_tree().paused = false
	is_result_screen = false
	_release_menu_focus()
	if screen_root != null and is_instance_valid(screen_root):
		screen_root.queue_free()
		screen_root = null
	_copa_match_id = JeffreyCore.generate_copa_match_id("smash") if hosted_by_shell else ""
	_copa_recorded = false
	active_match = PLAYGROUND_SCENE.instantiate() as M0Playground
	active_match.match_setup = match_setup.duplicate_setup()
	if OS.get_environment("SSK_FREEZE_AUDIT") == "1":
		print("[FREEZE_AUDIT] transition callback entered battle")
	active_match.match_finished.connect(_on_match_finished)
	active_match.restart_requested.connect(_restart_match)
	add_child(active_match)
	call_deferred("_audit_battle_focus")

func _restart_match() -> void:
	if active_match != null and is_instance_valid(active_match):
		active_match.queue_free()
	active_match = null
	_start_match()

func _on_match_finished(winner_id: int, summary: Dictionary) -> void:
	if hosted_by_shell:
		JeffreyCore.record_smash_match(winner_id, summary, match_setup)
		if not _copa_recorded and not _copa_match_id.is_empty():
			JeffreyCore.record_smash_copa_match(_copa_match_id, winner_id, match_setup)
			_copa_recorded = true
	if active_match != null:
		active_match.queue_free()
	active_match = null
	_play_transition(func(): _show_results(winner_id, summary))

func _show_results(winner_id: int, summary: Dictionary) -> void:
	transitioning = false
	is_result_screen = true
	var root := _new_screen()
	var results = (load(RESULTS_SCREEN) as GDScript).new()
	UILayout.bind_full_rect(results)
	root.add_child(results)
	results.setup(winner_id, summary, match_setup)
	results.rematch_pressed.connect(_start_match)
	results.change_kapes_pressed.connect(_show_character_select)
	results.menu_pressed.connect(_return_to_title)

func _return_to_title() -> void:
	if transitioning:
		return
	if hosted_by_shell:
		_stop_match()
		smash_session_exited.emit()
		return
	_play_transition(_show_title)

func _toggle_pause() -> void:
	if active_match == null:
		return
	if get_tree().paused:
		get_tree().paused = false
		_clear_pause_overlay()
	else:
		get_tree().paused = true
		_show_pause_overlay()

func _show_pause_overlay() -> void:
	if pause_overlay != null and is_instance_valid(pause_overlay):
		return
	pause_overlay = PAUSE_OVERLAY.new()
	UILayout.bind_full_rect(pause_overlay)
	ui.add_child(pause_overlay)
	pause_overlay.resume_pressed.connect(_toggle_pause)
	pause_overlay.restart_pressed.connect(func():
		get_tree().paused = false
		_clear_pause_overlay()
		_restart_match()
	)
	pause_overlay.menu_pressed.connect(func():
		get_tree().paused = false
		_clear_pause_overlay()
		_return_to_title()
	)

func _clear_pause_overlay() -> void:
	if pause_overlay != null and is_instance_valid(pause_overlay):
		pause_overlay.queue_free()
	pause_overlay = null

func _play_transition(callback: Callable) -> void:
	if transitioning:
		return
	transitioning = true
	if OS.get_environment("SSK_FREEZE_AUDIT") == "1":
		print("[FREEZE_AUDIT] transition started")
	var transition_layer := CanvasLayer.new()
	transition_layer.name = "TransitionLayer"
	transition_layer.layer = UI_LAYERS.TRANSITION
	ui.add_child(transition_layer)
	var wipe: KapesFlagWipe = FLAG_WIPE.new()
	UILayout.bind_full_rect(wipe)
	transition_layer.add_child(wipe)
	wipe.play(callback)

func _new_screen() -> Control:
	_clear_pause_overlay()
	if screen_root != null and is_instance_valid(screen_root):
		screen_root.queue_free()
	screen_root = Control.new()
	screen_root.name = "ScreenRoot"
	UILayout.bind_full_rect(screen_root)
	ui.add_child(screen_root)
	return screen_root

func _hosted_profile_name(profile_id: String, fallback: String) -> String:
	if profile_id.is_empty():
		return fallback
	var profile = JeffreyCore.profiles.get_profile(profile_id)
	if profile == null or str(profile.display_name).strip_edges().is_empty():
		return fallback
	return profile.display_name


func _stop_match() -> void:
	get_tree().paused = false
	_clear_pause_overlay()
	if active_match != null and is_instance_valid(active_match):
		active_match.queue_free()
	active_match = null

func _release_menu_focus() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()
	get_viewport().gui_release_focus()

func _audit_battle_focus() -> void:
	if OS.get_environment("SSK_FREEZE_AUDIT") != "1":
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		print("[FREEZE_AUDIT] battle focus owner: null")
	else:
		print("[FREEZE_AUDIT] battle focus owner: %s" % focus_owner.get_path())
