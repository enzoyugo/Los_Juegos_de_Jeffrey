class_name TextureFitHost
extends Control

## Decorative texture letterboxed inside this control.
## Children of `art_space` use 0–1 anchors relative to the *visible* art,
## never the letterbox. That keeps names/counts inside painted plates.

const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")

var art_space: Control
var _tex: TextureRect


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = TextureRect.new()
	_tex.name = "DecorativeFrame"
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	Layout.bind_full(_tex)
	add_child(_tex)
	art_space = Control.new()
	art_space.name = "ArtSpace"
	art_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_space.clip_contents = true
	add_child(art_space)


func _ready() -> void:
	resized.connect(_fit)
	call_deferred("_fit")


func set_texture(texture: Texture2D) -> void:
	if _tex == null:
		return
	_tex.texture = texture
	_fit()


func _fit() -> void:
	if art_space == null:
		return
	if _tex == null or _tex.texture == null:
		art_space.position = Vector2.ZERO
		art_space.size = size
		return
	var fitted := Layout.contain_centered(_tex.texture.get_size(), size)
	art_space.position = fitted.position
	art_space.size = fitted.size
