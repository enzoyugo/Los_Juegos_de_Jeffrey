class_name ShellStatusBadge
extends Label

const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")


func setup(text_value: String, playable: bool) -> void:
	text = "  %s  " % text_value
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", ThemeRef.SIZE_STATUS)
	add_theme_color_override("font_color", ThemeRef.BG_TOP if playable else ThemeRef.TEXT)
	var box := StyleBoxFlat.new()
	box.bg_color = ThemeRef.OK if playable else ThemeRef.SURFACE_ALT
	box.corner_radius_top_left = 6
	box.corner_radius_top_right = 6
	box.corner_radius_bottom_left = 6
	box.corner_radius_bottom_right = 6
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	if not playable:
		box.border_width_left = 1
		box.border_width_top = 1
		box.border_width_right = 1
		box.border_width_bottom = 1
		box.border_color = ThemeRef.STROKE
	add_theme_stylebox_override("normal", box)
