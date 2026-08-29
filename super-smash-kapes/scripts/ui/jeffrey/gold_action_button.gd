class_name GoldActionButton
extends Button

const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_paint()
	focus_entered.connect(func():
		AudioHooks.play_focus(self)
		_paint()
	)
	focus_exited.connect(_paint)
	mouse_entered.connect(_paint)
	mouse_exited.connect(_paint)


func configure(text_value: String, min_size: Vector2 = Vector2(140, 40)) -> void:
	text = text_value
	custom_minimum_size = min_size
	_paint()


func _paint() -> void:
	var lit: bool = has_focus() or is_hovered()
	add_theme_color_override("font_color", ThemeRef.GOLD_HOT if lit else ThemeRef.GOLD)
	add_theme_color_override("font_hover_color", ThemeRef.GOLD_HOT)
	add_theme_color_override("font_focus_color", ThemeRef.GOLD_HOT)
	add_theme_color_override("font_pressed_color", ThemeRef.GOLD)
	add_theme_font_size_override("font_size", 15)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	add_theme_constant_override("outline_size", 5)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#07080c")
	box.border_color = ThemeRef.GOLD_HOT if lit else Color(ThemeRef.GOLD.r, ThemeRef.GOLD.g, ThemeRef.GOLD.b, 0.92)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 3
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 2)
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	add_theme_stylebox_override("normal", box)
	add_theme_stylebox_override("hover", box)
	add_theme_stylebox_override("pressed", box)
	add_theme_stylebox_override("focus", box)
	add_theme_stylebox_override("disabled", box)
