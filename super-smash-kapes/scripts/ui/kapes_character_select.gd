class_name KapesCharacterSelectScreen
extends Control

signal roster_confirmed(setup)

const MENU_BACKGROUND := "res://assets/ui/menu/main_menu_bg.png"
const UILayout := preload("res://scripts/ui/kapes_ui_layout.gd")
const FIGHTER_CATALOG := preload("res://scripts/fighters/fighter_catalog.gd")
const MATCH_SETUP := preload("res://scripts/core/match_setup.gd")
const Typography := preload("res://scripts/ui/jeffrey/system/jeffrey_typography.gd")

const KEY_P1_LEFT := KEY_A
const KEY_P1_RIGHT := KEY_D
const KEY_P1_CONFIRM := KEY_F
const KEY_P2_LEFT := KEY_LEFT
const KEY_P2_RIGHT := KEY_RIGHT
const KEY_P2_CONFIRM := KEY_N

var fighters: Array = []
var p1_index: int = 0
var p2_index: int = 1
var p1_ready: bool = false
var p2_ready: bool = false
var _p1_label: String = "P1"
var _p2_label: String = "P2"
var _transition_started: bool = false
var _cards: Array[Control] = []
var _select_audit_enabled: bool = OS.get_environment("SSK_SELECT_AUDIT") == "1"
var _stage_id: String = "defensores"
const StageCatalog := preload("res://scripts/stages/stage_catalog.gd")

func _ready() -> void:
	theme = Typography.theme_for(Typography.SOCO)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	set_process_unhandled_input(true)
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UILayout.bind_full_rect(self)
	fighters = FIGHTER_CATALOG.get_all_fighters()
	_sync_default_indices()
	_build()
	resized.connect(_apply_layout)
	call_deferred("_apply_layout")
	call_deferred("_audit_ready")

func _sync_default_indices() -> void:
	for index in fighters.size():
		match fighters[index].id:
			"terere":
				p1_index = index
			"jaguarete":
				p2_index = index

func _audit_ready() -> void:
	if not _select_audit_enabled:
		return
	print("[SELECT_AUDIT] ready")
	_audit_focus("ready")

func _audit_focus(context: String) -> void:
	if not _select_audit_enabled:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		print("[SELECT_AUDIT] focus owner (%s): null" % context)
	else:
		print("[SELECT_AUDIT] focus owner (%s): %s" % [context, focus_owner.get_path()])
	print(
		"[SELECT_AUDIT] processing input=%s unhandled=%s transition=%s p1=%d/%s p2=%d/%s" % [
			is_processing_input(),
			is_processing_unhandled_input(),
			_transition_started,
			p1_index,
			p1_ready,
			p2_index,
			p2_ready
		]
	)

func handle_input_event(event: InputEvent) -> bool:
	if _transition_started:
		return false
	if event.is_echo():
		return false
	if not event is InputEventKey or not event.pressed:
		return false
	return _handle_keyboard(event)

func _input(event: InputEvent) -> void:
	if handle_input_event(event):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if handle_input_event(event):
		get_viewport().set_input_as_handled()

func _handle_keyboard(event: InputEventKey) -> bool:
	var key := event.physical_keycode
	if key == KEY_ESCAPE and not _transition_started:
		_audit_log("cancel")
		return false

	if _matches_p1_left(event):
		_audit_log("P1 left")
		_move_selection(1, -1)
		return true
	if _matches_p1_right(event):
		_audit_log("P1 right")
		_move_selection(1, 1)
		return true
	if _matches_p1_confirm(event):
		_audit_log("P1 confirm")
		_confirm_player(1)
		return true
	if _matches_p2_left(event):
		_audit_log("P2 left")
		_move_selection(2, -1)
		return true
	if _matches_p2_right(event):
		_audit_log("P2 right")
		_move_selection(2, 1)
		return true
	if _matches_p2_confirm(event):
		_audit_log("P2 confirm")
		_confirm_player(2)
		return true
	if event.pressed and not event.echo and key == KEY_Q:
		_cycle_stage(-1)
		return true
	if event.pressed and not event.echo and key == KEY_E:
		_cycle_stage(1)
		return true
	return false

func _matches_p1_left(event: InputEventKey) -> bool:
	return event.is_action("p1_left", true) and event.is_pressed() and not event.is_echo() or event.physical_keycode == KEY_P1_LEFT

func _matches_p1_right(event: InputEventKey) -> bool:
	return event.is_action("p1_right", true) and event.is_pressed() and not event.is_echo() or event.physical_keycode == KEY_P1_RIGHT

func _matches_p1_confirm(event: InputEventKey) -> bool:
	return (
		(event.is_action("p1_attack", true) and event.is_pressed() and not event.is_echo())
		or (event.is_action("p1_jump", true) and event.is_pressed() and not event.is_echo())
		or event.physical_keycode == KEY_P1_CONFIRM
		or event.physical_keycode == KEY_SPACE
	)

func _matches_p2_left(event: InputEventKey) -> bool:
	return event.is_action("p2_left", true) and event.is_pressed() and not event.is_echo() or event.physical_keycode == KEY_P2_LEFT

func _matches_p2_right(event: InputEventKey) -> bool:
	return event.is_action("p2_right", true) and event.is_pressed() and not event.is_echo() or event.physical_keycode == KEY_P2_RIGHT

func _matches_p2_confirm(event: InputEventKey) -> bool:
	return event.is_action("p2_attack", true) and event.is_pressed() and not event.is_echo() or event.physical_keycode == KEY_P2_CONFIRM

func set_participant_names(p1_display: String, p2_display: String) -> void:
	if not p1_display.strip_edges().is_empty():
		_p1_label = p1_display.strip_edges()
	if not p2_display.strip_edges().is_empty():
		_p2_label = p2_display.strip_edges()
	if has_node("Hint"):
		get_node("Hint").text = "%s: A/D + F/SPACE     •     %s: ←/→ + N" % [_p1_label, _p2_label]
	if has_node("Status"):
		_refresh_status()


func auto_confirm_for_testing() -> void:
	if _transition_started:
		return
	_sync_default_indices()
	p1_ready = true
	p2_ready = true
	_refresh_status()
	_audit_log("auto confirm")
	_finalize_roster()

func _build() -> void:
	var background := TextureRect.new()
	background.texture = load(MENU_BACKGROUND) as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.focus_mode = Control.FOCUS_NONE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.45)
	shade.focus_mode = Control.FOCUS_NONE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var title := Label.new()
	title.name = "Title"
	title.text = "ELIGÍ TU KAPE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", KapesVisual.WHITE)
	title.focus_mode = Control.FOCUS_NONE
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "%s: A/D + F/SPACE     •     %s: ←/→ + N" % [_p1_label, _p2_label]
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", KapesVisual.MUTED)
	hint.focus_mode = Control.FOCUS_NONE
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	var grid := HBoxContainer.new()
	grid.name = "CardGrid"
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 48)
	add_child(grid)
	for fighter in fighters:
		var card := _make_card(fighter)
		grid.add_child(card)
		_cards.append(card)
	var status := Label.new()
	status.name = "Status"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.focus_mode = Control.FOCUS_NONE
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)

func _make_card(fighter) -> Control:
	var card := PanelContainer.new()
	card.name = "Card_%s" % fighter.id
	card.custom_minimum_size = Vector2(260, 360)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var root := VBoxContainer.new()
	root.name = "CardContent"
	root.add_theme_constant_override("separation", 12)
	card.add_child(root)
	var portrait := TextureRect.new()
	portrait.texture = fighter.portrait_texture
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(220, 220)
	portrait.focus_mode = Control.FOCUS_NONE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(portrait)
	var name_label := Label.new()
	name_label.text = fighter.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", fighter.primary_color)
	name_label.focus_mode = Control.FOCUS_NONE
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_label)
	var ready_label := Label.new()
	ready_label.name = "ReadyLabel"
	ready_label.text = ""
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.add_theme_color_override("font_color", KapesVisual.GOLD)
	ready_label.focus_mode = Control.FOCUS_NONE
	ready_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ready_label)
	var tagline := Label.new()
	tagline.text = fighter.fighter_tagline
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD
	tagline.add_theme_color_override("font_color", KapesVisual.MUTED)
	tagline.focus_mode = Control.FOCUS_NONE
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tagline)
	return card

func _apply_layout() -> void:
	for child in get_children():
		if child is TextureRect or child is ColorRect:
			UILayout.bind_full_rect(child as Control)
	var safe := UILayout.safe_rect(get_viewport())
	var title: Label = get_node("Title")
	var hint: Label = get_node("Hint")
	var status: Label = get_node("Status")
	var grid: HBoxContainer = get_node("CardGrid")
	title.add_theme_font_size_override("font_size", UILayout.font_size(get_viewport(), 54))
	hint.add_theme_font_size_override("font_size", UILayout.font_size(get_viewport(), 18))
	status.add_theme_font_size_override("font_size", UILayout.font_size(get_viewport(), 24))
	title.size = Vector2(safe.size.x, title.get_theme_font_size("font_size") * 1.4)
	title.position = Vector2(safe.position.x, safe.position.y + safe.size.y * 0.06)
	hint.size = Vector2(safe.size.x, hint.get_theme_font_size("font_size") * 1.6)
	hint.position = Vector2(safe.position.x, safe.position.y + safe.size.y * 0.88)
	status.size = Vector2(safe.size.x, status.get_theme_font_size("font_size") * 1.5)
	status.position = Vector2(safe.position.x, safe.position.y + safe.size.y * 0.78)
	var card_span := 260.0 * fighters.size() + 48.0 * maxi(fighters.size() - 1, 0)
	grid.position = Vector2(safe.position.x + safe.size.x * 0.5 - card_span * 0.5, safe.position.y + safe.size.y * 0.24)
	_refresh_status()

func _move_selection(player: int, direction: int) -> void:
	if _transition_started:
		return
	if player == 1:
		if p1_ready:
			return
		p1_index = posmod(p1_index + direction, fighters.size())
	else:
		if p2_ready:
			return
		p2_index = posmod(p2_index + direction, fighters.size())
	_refresh_status()

func _selected_stage_id() -> String:
	var env := OS.get_environment("SSK_STAGE_ID").strip_edges()
	if not env.is_empty():
		return env
	return _stage_id


func _cycle_stage(direction: int = 1) -> void:
	var stages: Array = StageCatalog.get_all_stages()
	if stages.is_empty():
		return
	var idx := 0
	for i in range(stages.size()):
		if str(stages[i].get("id", "")) == _stage_id:
			idx = i
			break
	idx = posmod(idx + direction, stages.size())
	_stage_id = str(stages[idx].get("id", "defensores"))
	_refresh_status()


func _confirm_player(player: int) -> void:
	if _transition_started:
		return
	if player == 1:
		if not p1_ready:
			p1_ready = true
			_audit_log("P1 ready=true")
	else:
		if not p2_ready:
			p2_ready = true
			_audit_log("P2 ready=true")
	_refresh_status()
	if p1_ready and p2_ready:
		_finalize_roster()

func _finalize_roster() -> void:
	if _transition_started:
		return
	_transition_started = true
	set_process_input(false)
	set_process_unhandled_input(false)
	_release_select_focus()
	var setup = MATCH_SETUP.new()
	setup.player_1_fighter_id = fighters[p1_index].id
	setup.player_2_fighter_id = fighters[p2_index].id
	setup.stage_id = _selected_stage_id()
	if not _validate_setup(setup):
		_transition_started = false
		set_process_input(true)
		set_process_unhandled_input(true)
		return
	_audit_log("both ready")
	_audit_log("match setup created ids=%s/%s" % [setup.player_1_fighter_id, setup.player_2_fighter_id])
	roster_confirmed.emit(setup)
	_audit_log("transition requested")

func _validate_setup(setup) -> bool:
	var p1_def = FIGHTER_CATALOG.get_by_id(setup.player_1_fighter_id)
	var p2_def = FIGHTER_CATALOG.get_by_id(setup.player_2_fighter_id)
	if p1_def == null or p2_def == null:
		push_error("Character Select invalid fighter IDs: P1=%s P2=%s" % [setup.player_1_fighter_id, setup.player_2_fighter_id])
		return false
	return true

func _release_select_focus() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()
	get_viewport().gui_release_focus()

func _refresh_status() -> void:
	var status: Label = get_node("Status")
	var p1_name: String = fighters[p1_index].display_name
	var p2_name: String = fighters[p2_index].display_name
	var stage_name := str(StageCatalog.get_by_id(_selected_stage_id()).get("display_name", _selected_stage_id()))
	status.text = "%s: %s %s     •     %s: %s %s\nESCENARIO: %s  (Q/E)" % [
		_p1_label,
		p1_name,
		"LISTO" if p1_ready else "",
		_p2_label,
		p2_name,
		"LISTO" if p2_ready else "",
		stage_name,
	]
	for index in _cards.size():
		var card := _cards[index]
		var ready_label: Label = card.get_node("CardContent/ReadyLabel")
		var p1_on_card := index == p1_index
		var p2_on_card := index == p2_index
		var ready_bits: Array[String] = []
		if p1_on_card and p1_ready:
			ready_bits.append("%s LISTO" % _p1_label)
		if p2_on_card and p2_ready:
			ready_bits.append("%s LISTO" % _p2_label)
		ready_label.text = "  •  ".join(ready_bits)
		var style := KapesVisual.panel_style(Color(0.03, 0.05, 0.10, 0.72), KapesVisual.MUTED, 2)
		if p1_on_card and p2_on_card:
			style = KapesVisual.panel_style(Color(0.45, 0.12, 0.22, 0.92), KapesVisual.GOLD, 5)
		elif p1_on_card:
			style = KapesVisual.panel_style(Color(0.72, 0.16, 0.13, 0.88), KapesVisual.P1_COLOR, 4)
		elif p2_on_card:
			style = KapesVisual.panel_style(Color(0.10, 0.18, 0.34, 0.88), KapesVisual.P2_COLOR, 4)
		card.add_theme_stylebox_override("panel", style)

func _audit_log(message: String) -> void:
	if _select_audit_enabled:
		print("[SELECT_AUDIT] %s" % message)
