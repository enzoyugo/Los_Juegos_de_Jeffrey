class_name JeffreyPlayerChip
extends PanelContainer

const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")
const BaseTheme := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")


func configure(profile_id: String, display_name: String, slot_index: int = 0) -> void:
	for child in get_children():
		child.queue_free()
	var accent := BaseTheme.profile_color(profile_id)
	if slot_index >= 0:
		accent = BaseTheme.slot_color(slot_index)
	add_theme_stylebox_override("panel", ThemeRef.panel_style(accent, 0.82))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var badge := Layout.outlined_label(BaseTheme.initials(display_name), 14, ThemeRef.Base.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	badge.custom_minimum_size = Vector2(28, 28)
	row.add_child(badge)
	var name_label := Layout.outlined_label(display_name.to_upper(), 15, ThemeRef.Base.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
