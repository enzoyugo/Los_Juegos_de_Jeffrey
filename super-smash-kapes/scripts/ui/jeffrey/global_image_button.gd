class_name GlobalImageButton
extends Button

## Texture-backed shell control. Falls back to a labeled panel if art is missing.

const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")

var _art: TextureRect
var _fallback: Label
var _focus_ring: ColorRect
var _base_modulate := Color.WHITE


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
	mouse_entered.connect(func(): _refresh_focus())
	mouse_exited.connect(func(): _refresh_focus())
	resized.connect(_center_pivot)


func setup(path: String, fallback_text: String, min_size: Vector2 = Vector2.ZERO) -> void:
	if min_size != Vector2.ZERO:
		custom_minimum_size = min_size
	_art = TextureRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	Layout.bind_full(_art)
	add_child(_art)
	var tex := Assets.texture(path)
	if tex != null:
		_art.texture = tex
	else:
		_fallback = Layout.outlined_label(fallback_text, ThemeRef.SIZE_BODY, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		Layout.bind_full(_fallback)
		add_child(_fallback)
		var fill := ColorRect.new()
		fill.color = Color(0.07, 0.08, 0.1, 0.88)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Layout.bind_full(fill)
		add_child(fill)
		move_child(fill, 0)
	_focus_ring = ColorRect.new()
	_focus_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_ring.color = Color(1, 1, 1, 0)
	Layout.bind_full(_focus_ring)
	add_child(_focus_ring)
	_refresh_focus()
	call_deferred("_center_pivot")


func set_art_enabled(on: bool) -> void:
	disabled = not on
	_base_modulate = Color(1, 1, 1, 1) if on else Color(0.55, 0.55, 0.55, 0.5)
	modulate = _base_modulate
	_refresh_focus()


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
	var lit: bool = has_focus() or is_hovered()
	if _focus_ring != null:
		_focus_ring.color = Color(ThemeRef.GOLD_HOT.r, ThemeRef.GOLD_HOT.g, ThemeRef.GOLD_HOT.b, 0.18) if lit and not disabled else Color(0, 0, 0, 0)
	var target := Vector2(1.02, 1.02) if lit and not disabled else Vector2.ONE
	var brightness := 1.1 if lit and not disabled else 1.0
	modulate = Color(brightness, brightness, brightness, _base_modulate.a)
	var tween := create_tween()
	tween.tween_property(self, "scale", target, 0.08)
