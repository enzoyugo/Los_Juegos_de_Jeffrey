class_name ShellPlayerCard
extends Button

const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")

var profile_id: String = ""
var _name: String = ""
var _slot_caption: String = ""
var _initials: Label
var _name_label: Label
var _slot_label: Label
var _mark: Label


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(160, 150)
	toggled.connect(func(_on): _refresh())
	_build()
	_refresh()


func setup(id: String, display_name: String, selected: bool) -> void:
	profile_id = id
	_name = display_name
	button_pressed = selected
	if _name_label != null:
		_apply_text()
		_refresh()


func set_slot_caption(caption: String) -> void:
	_slot_caption = caption
	if _slot_label != null:
		_slot_label.text = caption
		_slot_label.visible = not caption.is_empty()


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 12
	root.offset_right = -12
	root.offset_bottom = -12
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	_initials = Label.new()
	_initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initials.add_theme_font_size_override("font_size", 28)
	_initials.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_initials)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", ThemeRef.SIZE_PLAYER)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(_name_label)
	_slot_label = Label.new()
	_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_label.add_theme_font_size_override("font_size", ThemeRef.SIZE_STATUS)
	_slot_label.add_theme_color_override("font_color", ThemeRef.MUTED)
	_slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_slot_label)
	_mark = Label.new()
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mark.add_theme_font_size_override("font_size", 18)
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_mark)
	_apply_text()


func _apply_text() -> void:
	_name_label.text = _name
	_initials.text = ThemeRef.initials(_name)
	_initials.add_theme_color_override("font_color", ThemeRef.profile_color(profile_id))
	_slot_label.text = _slot_caption
	_slot_label.visible = not _slot_caption.is_empty()


func _refresh() -> void:
	var selected: bool = button_pressed
	_mark.text = "✓" if selected else ""
	_name_label.add_theme_color_override("font_color", ThemeRef.TEXT)
	var box := StyleBoxFlat.new()
	box.bg_color = ThemeRef.SURFACE_ALT if selected else ThemeRef.SURFACE
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = ThemeRef.profile_color(profile_id) if selected else ThemeRef.STROKE
	box.corner_radius_top_left = ThemeRef.CARD_RADIUS
	box.corner_radius_top_right = ThemeRef.CARD_RADIUS
	box.corner_radius_bottom_left = ThemeRef.CARD_RADIUS
	box.corner_radius_bottom_right = ThemeRef.CARD_RADIUS
	add_theme_stylebox_override("normal", box)
	add_theme_stylebox_override("hover", box)
	add_theme_stylebox_override("pressed", box)
	add_theme_stylebox_override("focus", box)
	scale = Vector2(1.02, 1.02) if selected else Vector2.ONE
