class_name ShellBackground
extends Control

const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const Assets := preload("res://scripts/ui/jeffrey/shell_assets.gd")
const UILayout := preload("res://scripts/ui/kapes_ui_layout.gd")

var _photo: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_photo = TextureRect.new()
	_photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_photo.modulate = Color(1, 1, 1, 0.18)
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := Assets.background()
	if tex != null:
		_photo.texture = tex
	add_child(_photo)
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var size := get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var steps := 24
	for i in steps:
		var t := float(i) / float(steps)
		var color: Color = ThemeRef.BG_TOP.lerp(ThemeRef.BG_BOTTOM, t)
		var y := size.y * t
		draw_rect(Rect2(0.0, y, size.x, size.y / float(steps) + 1.0), color)
	draw_rect(Rect2(0.0, 0.0, 8.0, size.y), Color(ThemeRef.ACCENT, 0.18))
	draw_rect(Rect2(size.x - 8.0, 0.0, 8.0, size.y), Color(ThemeRef.ACCENT, 0.10))
	draw_rect(Rect2(0.0, size.y * 0.72, size.x, 2.0), Color(ThemeRef.STROKE, 0.55))
