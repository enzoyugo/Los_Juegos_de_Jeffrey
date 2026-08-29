class_name GlobalScreenFrame
extends Control

## Shared root for Boot / Players Today / Hub.
## Background + optional ambience + dim + content + footer.

const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")

var background: TextureRect
var ambience: TextureRect
var dim: ColorRect
var content: Control
var footer: Control
var _bg_tex: Texture2D
var _ambience_tex: Texture2D


func configure(background_path: String, ambience_path: String = "", dim_alpha: float = 0.28, footer_path: String = "") -> void:
	Layout.bind_full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	clip_contents = true

	background = TextureRect.new()
	background.name = "Background"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_tex = Assets.texture(background_path)
	if _bg_tex != null:
		background.texture = _bg_tex
	else:
		background.modulate = ThemeRef.BG_TOP
	add_child(background)

	if not ambience_path.is_empty():
		ambience = TextureRect.new()
		ambience.name = "AmbienceOverlay"
		ambience.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ambience.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ambience.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_ambience_tex = Assets.texture(ambience_path)
		if _ambience_tex != null:
			ambience.texture = _ambience_tex
			ambience.modulate = Color(1, 1, 1, 0.85)
		else:
			ambience.visible = false
		add_child(ambience)

	dim = ColorRect.new()
	dim.name = "Dim"
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(0, 0, 0, dim_alpha)
	add_child(dim)

	content = Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	footer = Control.new()
	footer.name = "Footer"
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	if not footer_path.is_empty():
		var strip := TextureRect.new()
		strip.name = "ControlsStrip"
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		strip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		strip.texture = Assets.texture(footer_path)
		footer.add_child(strip)
		Layout.apply_frac(strip, 0.12, 0.0, 0.76, 1.0)

	resized.connect(_layout_layers)
	call_deferred("_layout_layers")


func _layout_layers() -> void:
	var size := get_size()
	if size.x <= 1.0 or size.y <= 1.0:
		size = Layout.DESIGN
	_fit_cover(background, _bg_tex, size)
	_fit_cover(ambience, _ambience_tex, size)
	if dim != null:
		dim.position = Vector2.ZERO
		dim.size = size
	if content != null:
		content.position = Vector2.ZERO
		content.size = size
	if footer != null:
		footer.position = Vector2(0.0, size.y * 0.90)
		footer.size = Vector2(size.x, size.y * 0.10)


func _fit_cover(rect: TextureRect, tex: Texture2D, viewport_size: Vector2) -> void:
	if rect == null:
		return
	if tex == null:
		rect.position = Vector2.ZERO
		rect.size = viewport_size
		return
	var fitted := Layout.cover_centered(tex.get_size(), viewport_size)
	rect.position = fitted.position
	rect.size = fitted.size
