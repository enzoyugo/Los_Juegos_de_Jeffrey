class_name JeffreyButton
extends Button

enum Kind { PRIMARY, SECONDARY, DANGER, GHOST }

const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")
const Motion := preload("res://scripts/ui/jeffrey/system/jeffrey_ui_motion.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")

var _kind: Kind = Kind.PRIMARY
var _paint_key := ""


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_repaint()
	focus_entered.connect(func():
		AudioHooks.play_focus(self)
		_repaint()
	)
	focus_exited.connect(_repaint)
	mouse_entered.connect(_repaint)
	mouse_exited.connect(_repaint)
	button_down.connect(_repaint)
	button_up.connect(_repaint)
	Motion.bind_focus_scale(self)


func configure(text_value: String, kind: Kind = Kind.PRIMARY, min_size: Vector2 = ThemeRef.BTN_MIN) -> void:
	text = text_value
	_kind = kind
	custom_minimum_size = min_size
	_repaint()


func _repaint() -> void:
	var lit := has_focus() or is_hovered()
	var kind_name := "primary"
	match _kind:
		Kind.SECONDARY:
			kind_name = "secondary"
		Kind.DANGER:
			kind_name = "danger"
		Kind.GHOST:
			kind_name = "secondary"
	var key := "%s|%s|%s" % [kind_name, lit, disabled]
	if key == _paint_key:
		return
	_paint_key = key
	var box := ThemeRef.button_style(kind_name, lit, disabled)
	add_theme_stylebox_override("normal", box)
	add_theme_stylebox_override("hover", box)
	add_theme_stylebox_override("pressed", box)
	add_theme_stylebox_override("focus", box)
	add_theme_stylebox_override("disabled", ThemeRef.button_style(kind_name, false, true))
	ThemeRef.apply_button_font(self, lit, disabled)
