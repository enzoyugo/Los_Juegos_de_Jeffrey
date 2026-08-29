class_name JeffreyPlayersTodayScreen
extends Control

signal roster_confirmed(selected_ids: Array)
signal cancelled

const Frame := preload("res://scripts/ui/jeffrey/global_screen_frame.gd")
const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const JeffreyThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")
const ImageButton := preload("res://scripts/ui/jeffrey/global_image_button.gd")
const PlayerCard := preload("res://scripts/ui/jeffrey/global_player_card.gd")
const ModalScript := preload("res://scripts/ui/jeffrey/create_player_modal.gd")
const SelectedPanel := preload("res://scripts/ui/jeffrey/selected_players_panel.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")
const JeffreyButton := preload("res://scripts/ui/jeffrey/components/jeffrey_button.gd")
const JeffreyTitle := preload("res://scripts/ui/jeffrey/components/jeffrey_title.gd")
const JeffreyPlayerChip := preload("res://scripts/ui/jeffrey/components/jeffrey_player_chip.gd")

const CONTEXT_BOOT := "BOOT"
const CONTEXT_EDIT := "EDIT_SESSION"

var context: String = CONTEXT_BOOT
var _grid: GridContainer
var _cards: Dictionary = {}
var _new_card: Button
var _continue: Button
var _back: Button
var _selected_panel
var _error: Label
var _count_label: Label
var _chip_row: HBoxContainer
var _modal: Control
var _focusables: Array = []
var _confirming: bool = false


func request_back() -> void:
	AudioHooks.play_back(self)
	cancelled.emit()


func _ready() -> void:
	set_process_unhandled_input(true)
	Layout.bind_full(self)
	var frame = Frame.new()
	add_child(frame)
	frame.configure(Assets.PLAYERS_BACKGROUND, "", 0.38, Assets.PLAYERS_CONTROLS)

	var title := TextureRect.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.texture = Assets.texture(Assets.PLAYERS_TITLE)
	frame.content.add_child(title)
	Layout.apply_frac(title, 0.04, 0.02, 0.62, 0.16)
	if title.texture == null:
		var fallback = JeffreyTitle.new()
		fallback.configure("¿QUIÉNES ESTÁN HOY?", 1, HORIZONTAL_ALIGNMENT_CENTER)
		frame.content.add_child(fallback)
		Layout.apply_frac(fallback, 0.04, 0.03, 0.6, 0.12)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.content.add_child(scroll)
	Layout.apply_frac(scroll, 0.035, 0.18, 0.62, 0.52)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 18)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	var panel = SelectedPanel.new()
	frame.content.add_child(panel)
	Layout.apply_frac(panel, 0.68, 0.16, 0.29, 0.50)
	_selected_panel = panel

	_count_label = Layout.outlined_label("0 SELECCIONADOS", 18, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	frame.content.add_child(_count_label)
	Layout.apply_frac(_count_label, 0.68, 0.68, 0.29, 0.05)

	_chip_row = HBoxContainer.new()
	_chip_row.add_theme_constant_override("separation", 8)
	frame.content.add_child(_chip_row)
	Layout.apply_frac(_chip_row, 0.035, 0.72, 0.62, 0.06)

	_error = Layout.outlined_label("", 16, ThemeRef.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	frame.content.add_child(_error)
	Layout.apply_frac(_error, 0.08, 0.78, 0.5, 0.04)

	_back = JeffreyButton.new()
	frame.content.add_child(_back)
	_back.configure("VOLVER", JeffreyButton.Kind.SECONDARY, JeffreyThemeRef.BTN_BACK)
	Layout.apply_frac(_back, 0.06, 0.84, 0.18, 0.08)
	_back.pressed.connect(request_back)

	_continue = JeffreyButton.new()
	frame.content.add_child(_continue)
	_continue.configure("CONTINUAR", JeffreyButton.Kind.PRIMARY, Vector2(240, 56))
	Layout.apply_frac(_continue, 0.28, 0.84, 0.24, 0.08)
	_continue.pressed.connect(_confirm)

	_rebuild()
	call_deferred("_focus_default")


func _focus_default() -> void:
	if not _focusables.is_empty():
		_focusables[0].grab_focus()
	elif _continue != null:
		_continue.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _modal != null:
		return
	if event.is_action_pressed("pause_match"):
		request_back()
		get_viewport().set_input_as_handled()
		return
	if _is_enter(event):
		_confirm()
		get_viewport().set_input_as_handled()
		return
	if _is_space(event):
		_toggle_focused()
		get_viewport().set_input_as_handled()
		return
	var dir := _nav_dir(event)
	if dir != Vector2i.ZERO:
		_move_focus(dir)
		get_viewport().set_input_as_handled()


func _is_enter(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER


func _is_space(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	return event.keycode == KEY_SPACE


func _nav_dir(event: InputEvent) -> Vector2i:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return Vector2i.ZERO
	if event.keycode == KEY_LEFT or event.keycode == KEY_A:
		return Vector2i(-1, 0)
	if event.keycode == KEY_RIGHT or event.keycode == KEY_D:
		return Vector2i(1, 0)
	if event.keycode == KEY_UP or event.keycode == KEY_W:
		return Vector2i(0, -1)
	if event.keycode == KEY_DOWN or event.keycode == KEY_S:
		return Vector2i(0, 1)
	return Vector2i.ZERO


func _move_focus(dir: Vector2i) -> void:
	if _focusables.is_empty():
		return
	var current := get_viewport().gui_get_focus_owner()
	var index := _focusables.find(current)
	if index < 0:
		index = 0
	var cols := maxi(_grid.columns, 1)
	if dir.x != 0:
		index = clampi(index + dir.x, 0, _focusables.size() - 1)
	else:
		index = clampi(index + dir.y * cols, 0, _focusables.size() - 1)
	_focusables[index].grab_focus()
	AudioHooks.play_focus(self)


func _toggle_focused() -> void:
	var current := get_viewport().gui_get_focus_owner()
	if current == _new_card:
		_open_modal()
		return
	if current is BaseButton and current.toggle_mode:
		current.button_pressed = not current.button_pressed


func _rebuild() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()
	_focusables.clear()
	var profiles: Array = JeffreyCore.profiles.get_all()
	for profile in profiles:
		var card = PlayerCard.new()
		_grid.add_child(card)
		card.setup(profile.profile_id, profile.display_name, JeffreyCore.session.has_player(profile.profile_id), profile.portrait_path)
		card.card_toggled.connect(func(_id, _on): _refresh_selection())
		_cards[profile.profile_id] = card
		_focusables.append(card)
	_new_card = ImageButton.new()
	_grid.add_child(_new_card)
	_new_card.setup(Assets.NEW_PLAYER_CARD, "NUEVO JUGADOR", Vector2(176, 220))
	_new_card.custom_minimum_size = Vector2(176, 220)
	_new_card.pressed.connect(_open_modal)
	_focusables.append(_new_card)
	_refresh_selection()


func _selected_ids() -> Array[String]:
	var selected: Array[String] = []
	for profile_id in _cards.keys():
		if _cards[profile_id].button_pressed:
			selected.append(profile_id)
	return selected


func _refresh_selection() -> void:
	var selected := _selected_ids()
	if _continue != null:
		_continue.disabled = selected.is_empty()
		if _continue.has_method("_repaint"):
			_continue.call("_repaint")
	if _selected_panel != null and _selected_panel.has_method("set_profile_ids"):
		_selected_panel.set_profile_ids(selected)
	if _count_label != null:
		_count_label.text = "%d SELECCIONADOS" % selected.size()
	if _chip_row != null:
		for child in _chip_row.get_children():
			child.queue_free()
		var slot := 0
		for profile_id in selected:
			var profile = JeffreyCore.profiles.get_profile(profile_id)
			var chip = JeffreyPlayerChip.new()
			_chip_row.add_child(chip)
			chip.configure(profile_id, profile.display_name if profile != null else profile_id, slot)
			chip.custom_minimum_size = Vector2(120, 34)
			slot += 1
	if _error != null and not selected.is_empty():
		_error.text = ""


func _confirm() -> void:
	if _confirming:
		return
	var selected := _selected_ids()
	if selected.is_empty():
		_error.text = "Seleccioná al menos una persona que esté hoy."
		return
	_confirming = true
	_error.text = ""
	AudioHooks.play_confirm(self)
	roster_confirmed.emit(selected)


func _open_modal() -> void:
	if _modal != null:
		return
	_modal = ModalScript.new()
	add_child(_modal)
	_modal.created.connect(_on_modal_created)
	_modal.cancelled.connect(_close_modal)


func _on_modal_created(display_name: String) -> void:
	var created = JeffreyCore.profiles.create(display_name)
	if created == null:
		if JeffreyCore.profiles.last_error == "duplicate":
			_modal.set_error("Ya existe un jugador con ese nombre.")
		else:
			_modal.set_error("Escribí un nombre.")
		return
	JeffreyCore.session.add_player(created.profile_id)
	JeffreyCore.save()
	_close_modal()
	_rebuild()
	call_deferred("_focus_default")


func _close_modal() -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
