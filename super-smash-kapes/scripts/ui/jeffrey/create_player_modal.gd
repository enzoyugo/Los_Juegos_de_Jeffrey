class_name CreatePlayerModal
extends Control

signal created(display_name: String)
signal cancelled

const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const ButtonScript := preload("res://scripts/ui/jeffrey/shell_button.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")

var _name_edit: LineEdit
var _error: Label


func _ready() -> void:
	set_process_unhandled_input(true)
	Layout.bind_full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var wash := ColorRect.new()
	wash.color = Color(0, 0, 0, 0.72)
	Layout.bind_full(wash)
	add_child(wash)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(520, 280)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#0c0d12")
	box.border_color = ThemeRef.GOLD
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", box)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260
	panel.offset_top = -140
	panel.offset_right = 260
	panel.offset_bottom = 140
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	Layout.bind_full(layout)
	layout.offset_left = 28
	layout.offset_top = 24
	layout.offset_right = -28
	layout.offset_bottom = -24
	panel.add_child(layout)
	layout.add_child(Layout.outlined_label("NUEVO JUGADOR", 28, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	layout.add_child(Layout.outlined_label("NOMBRE", 14, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nombre"
	_name_edit.custom_minimum_size = Vector2(0, 48)
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.text_submitted.connect(func(_t): _confirm())
	layout.add_child(_name_edit)
	_error = Layout.outlined_label("", 16, ThemeRef.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	layout.add_child(_error)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	layout.add_child(actions)
	var cancel = ButtonScript.new()
	cancel.configure("CANCELAR", ButtonScript.Kind.SECONDARY, Vector2(160, 48))
	cancel.pressed.connect(_cancel)
	actions.add_child(cancel)
	var create_btn = ButtonScript.new()
	create_btn.configure("CREAR", ButtonScript.Kind.PRIMARY, Vector2(160, 48))
	create_btn.pressed.connect(_confirm)
	actions.add_child(create_btn)
	call_deferred("_focus_name")


func set_error(text: String) -> void:
	if _error != null:
		_error.text = text


func _focus_name() -> void:
	if _name_edit != null:
		_name_edit.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_match"):
		_cancel()
		get_viewport().set_input_as_handled()


func _confirm() -> void:
	var name_text := _name_edit.text.strip_edges()
	if name_text.is_empty():
		set_error("Escribí un nombre.")
		return
	AudioHooks.play_confirm(self)
	created.emit(name_text)


func _cancel() -> void:
	AudioHooks.play_back(self)
	cancelled.emit()
