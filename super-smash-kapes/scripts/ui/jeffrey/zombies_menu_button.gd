class_name JeffreyZombiesMenuButton
extends Button

## Texture-backed Zombies menu control. PNG already contains label/icon.

const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")

var _art: TextureRect


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_empty_styles()
	focus_entered.connect(func():
		AudioHooks.play_focus(self)
		_refresh_focus()
	)
	focus_exited.connect(_refresh_focus)
	mouse_entered.connect(func():
		if not has_focus():
			grab_focus()
		_refresh_focus()
	)
	mouse_exited.connect(_refresh_focus)
	resized.connect(_center_pivot)


func setup(path: String) -> void:
	_art = TextureRect.new()
	_art.name = "Art"
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_art.texture = Assets.texture(path)
	Layout.bind_full(_art)
	add_child(_art)
	_refresh_focus()
	call_deferred("_center_pivot")


func _empty_styles() -> void:
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_stylebox_override("disabled", empty)
	add_theme_color_override("font_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_focus_color", Color(0, 0, 0, 0))
	add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0))


func _center_pivot() -> void:
	pivot_offset = size * 0.5


func _refresh_focus() -> void:
	var lit: bool = (has_focus() or is_hovered()) and not disabled
	if _art != null:
		_art.modulate = Color(1.10, 1.22, 1.08, 1.0) if lit else Color.WHITE
	var target := Vector2(1.05, 1.05) if lit else Vector2.ONE
	var tween := create_tween()
	tween.tween_property(self, "scale", target, 0.08)
