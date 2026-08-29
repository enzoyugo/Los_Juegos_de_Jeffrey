class_name GlobalUiLayout
extends RefCounted

const DESIGN := Vector2(1920.0, 1080.0)


static func apply_frac(control: Control, left: float, top: float, width: float, height: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = left + width
	control.anchor_bottom = top + height
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


static func bind_full(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


static func cover_centered(tex_size: Vector2, viewport_size: Vector2) -> Rect2:
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Rect2(Vector2.ZERO, viewport_size)
	var scale: float = maxf(viewport_size.x / tex_size.x, viewport_size.y / tex_size.y)
	var drawn := tex_size * scale
	return Rect2((viewport_size - drawn) * 0.5, drawn)


static func contain_centered(tex_size: Vector2, viewport_size: Vector2) -> Rect2:
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Rect2(Vector2.ZERO, viewport_size)
	var scale: float = minf(viewport_size.x / tex_size.x, viewport_size.y / tex_size.y)
	var drawn := tex_size * scale
	return Rect2((viewport_size - drawn) * 0.5, drawn)


static func bind_frac_rect(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


static func outlined_label(text: String, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
