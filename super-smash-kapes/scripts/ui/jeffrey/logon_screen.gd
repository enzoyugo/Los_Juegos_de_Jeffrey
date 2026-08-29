class_name JeffreyLogonScreen
extends Control

signal roster_confirmed(selected_ids: Array)
signal cancelled

const Frame := preload("res://scripts/ui/jeffrey/shell_frame.gd")
const Labels := preload("res://scripts/ui/jeffrey/shell_labels.gd")
const PlayerCard := preload("res://scripts/ui/jeffrey/shell_player_card.gd")
const ButtonScript := preload("res://scripts/ui/jeffrey/shell_button.gd")

var _allow_cancel: bool = false
var _title_text: String = "¿QUIÉNES ESTÁN HOY?"
var _continue_text: String = "CONTINUAR"
var _grid: GridContainer
var _name_edit: LineEdit
var _error: Label
var _helper: Label
var _cards: Dictionary = {}
var _continue_button: Button


func configure(title_text: String, continue_text: String, allow_cancel: bool) -> void:
	_title_text = title_text
	_continue_text = continue_text
	_allow_cancel = allow_cancel


func request_back() -> void:
	if _allow_cancel:
		cancelled.emit()


func _ready() -> void:
	set_process_unhandled_input(true)
	var margin = Frame.decorate(self)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	layout.add_child(Labels.screen_title(_title_text))
	_helper = Labels.helper("Marcá quién está en la juntada.")
	layout.add_child(_helper)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	var create_box := VBoxContainer.new()
	create_box.add_theme_constant_override("separation", 8)
	layout.add_child(create_box)
	create_box.add_child(Labels.section("NOMBRE"))
	var create_row := HBoxContainer.new()
	create_row.add_theme_constant_override("separation", 12)
	create_box.add_child(create_row)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nombre"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.custom_minimum_size = Vector2(280, 48)
	_name_edit.add_theme_font_size_override("font_size", 20)
	_name_edit.text_submitted.connect(func(_text): _create_player())
	create_row.add_child(_name_edit)
	var create_btn = ButtonScript.new()
	create_btn.configure("CREAR", ButtonScript.Kind.SECONDARY, Vector2(140, 48))
	create_btn.pressed.connect(_create_player)
	create_row.add_child(create_btn)

	_error = Labels.error()
	layout.add_child(_error)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	layout.add_child(actions)
	if _allow_cancel:
		var back = ButtonScript.new()
		back.configure("VOLVER", ButtonScript.Kind.SECONDARY, Vector2(180, 52))
		back.pressed.connect(func(): cancelled.emit())
		actions.add_child(back)
	_continue_button = ButtonScript.new()
	_continue_button.configure(_continue_text, ButtonScript.Kind.PRIMARY, Vector2(240, 52))
	_continue_button.pressed.connect(_confirm)
	actions.add_child(_continue_button)
	_rebuild()
	call_deferred("_focus_default")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_match"):
		request_back()
		get_viewport().set_input_as_handled()


func _focus_default() -> void:
	if JeffreyCore.profiles.get_all().is_empty() and _name_edit != null:
		_name_edit.grab_focus()
	elif _continue_button != null:
		_continue_button.grab_focus()


func _rebuild() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()
	var all_profiles: Array = JeffreyCore.profiles.get_all()
	_grid.columns = Frame.grid_columns(maxi(all_profiles.size(), 1))
	if all_profiles.is_empty():
		var empty := Labels.helper("Creá el primer jugador.")
		_grid.add_child(empty)
		_refresh_continue()
		return
	for profile in all_profiles:
		var card = PlayerCard.new()
		_grid.add_child(card)
		card.setup(profile.profile_id, profile.display_name, JeffreyCore.session.has_player(profile.profile_id))
		card.toggled.connect(func(_on): _refresh_continue())
		_cards[profile.profile_id] = card
	_refresh_continue()


func _create_player() -> void:
	var created = JeffreyCore.profiles.create(_name_edit.text)
	if created == null:
		if JeffreyCore.profiles.last_error == "duplicate":
			_error.text = "Ya existe un jugador con ese nombre."
		else:
			_error.text = "Escribí un nombre."
		return
	_name_edit.text = ""
	_error.text = ""
	JeffreyCore.session.add_player(created.profile_id)
	JeffreyCore.save()
	_rebuild()


func _selected_ids() -> Array[String]:
	var selected: Array[String] = []
	for profile_id in _cards.keys():
		var card = _cards[profile_id]
		if card.button_pressed:
			selected.append(profile_id)
	return selected


func _refresh_continue() -> void:
	if _continue_button == null:
		return
	_continue_button.disabled = _selected_ids().is_empty()


func _confirm() -> void:
	var selected := _selected_ids()
	if selected.is_empty():
		_error.text = "Seleccioná al menos una persona que esté hoy."
		return
	_error.text = ""
	roster_confirmed.emit(selected)
