class_name ShellButton
extends Button

const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")

enum Kind { PRIMARY, SECONDARY }

var kind: Kind = Kind.PRIMARY


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	_apply_kind()
	focus_entered.connect(_on_focus.bind(true))
	focus_exited.connect(_on_focus.bind(false))
	mouse_entered.connect(_on_focus.bind(true))
	mouse_exited.connect(func(): _on_focus(has_focus()))


func configure(text_value: String, button_kind: Kind, min_size: Vector2 = Vector2(200, 52)) -> void:
	text = text_value
	kind = button_kind
	custom_minimum_size = min_size
	_apply_kind()


func _apply_kind() -> void:
	var fill: Color = ThemeRef.ACCENT if kind == Kind.PRIMARY else ThemeRef.SURFACE
	var font: Color = ThemeRef.BG_TOP if kind == Kind.PRIMARY else ThemeRef.TEXT
	add_theme_color_override("font_color", font)
	add_theme_color_override("font_hover_color", font)
	add_theme_color_override("font_focus_color", font)
	add_theme_color_override("font_disabled_color", ThemeRef.MUTED)
	add_theme_font_size_override("font_size", ThemeRef.SIZE_BODY)
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	if kind == Kind.SECONDARY:
		box.border_width_left = 1
		box.border_width_top = 1
		box.border_width_right = 1
		box.border_width_bottom = 1
		box.border_color = ThemeRef.STROKE
	add_theme_stylebox_override("normal", box)
	var hover := box.duplicate()
	hover.bg_color = fill.lightened(0.08)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("focus", hover)
	var disabled := box.duplicate()
	disabled.bg_color = ThemeRef.SURFACE_ALT
	add_theme_stylebox_override("disabled", disabled)


func _on_focus(on: bool) -> void:
	var target := Vector2(1.03, 1.03) if on and not disabled else Vector2.ONE
	var tween := create_tween()
	tween.tween_property(self, "scale", target, 0.08)
