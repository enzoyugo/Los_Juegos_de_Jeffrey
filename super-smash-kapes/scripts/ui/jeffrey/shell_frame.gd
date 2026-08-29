class_name ShellFrame
extends RefCounted

const BackgroundScript := preload("res://scripts/ui/jeffrey/shell_background.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")


static func decorate(root: Control) -> MarginContainer:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var background = BackgroundScript.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	root.resized.connect(func(): _apply_margins(root, margin))
	_apply_margins(root, margin)
	return margin


static func _apply_margins(root: Control, margin: MarginContainer) -> void:
	var size := root.get_viewport_rect().size
	if size.x <= 1.0:
		size = Vector2(1920, 1080)
	var pad_x: int = int(round(size.x * ThemeRef.MARGIN))
	var pad_y: int = int(round(size.y * ThemeRef.MARGIN))
	margin.add_theme_constant_override("margin_left", pad_x)
	margin.add_theme_constant_override("margin_right", pad_x)
	margin.add_theme_constant_override("margin_top", pad_y)
	margin.add_theme_constant_override("margin_bottom", pad_y)


static func grid_columns(count: int) -> int:
	if count <= 1:
		return 1
	if count <= 4:
		return mini(count, 4)
	if count <= 6:
		return 3
	if count <= 8:
		return 4
	return 5
