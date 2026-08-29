class_name ShellLabels
extends RefCounted

const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")


static func game_title(text: String) -> Label:
	return _make(text, ThemeRef.SIZE_GAME_TITLE, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_CENTER)


static func screen_title(text: String) -> Label:
	return _make(text, ThemeRef.SIZE_SCREEN_TITLE, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_CENTER)


static func section(text: String) -> Label:
	return _make(text, ThemeRef.SIZE_SECTION, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_LEFT)


static func helper(text: String) -> Label:
	var label := _make(text, ThemeRef.SIZE_HELPER, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


static func error(text: String = "") -> Label:
	return _make(text, ThemeRef.SIZE_HELPER, ThemeRef.DANGER, HORIZONTAL_ALIGNMENT_CENTER)


static func _make(text: String, size: int, color: Color, align: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
