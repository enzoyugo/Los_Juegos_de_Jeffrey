class_name SelectedPlayerRow
extends HBoxContainer

const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")


func setup(display_name: String, color: Color) -> void:
	custom_minimum_size = Vector2(0, 28)
	add_theme_constant_override("separation", 10)
	alignment = BoxContainer.ALIGNMENT_CENTER
	var dot := ColorRect.new()
	dot.name = "ColorIndicator"
	dot.custom_minimum_size = Vector2(10, 10)
	dot.color = color
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(dot)
	var name_label := Layout.outlined_label(display_name.to_upper(), Styles.SIZE_PROFILE, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.name = "NameLabel"
	Styles.apply(name_label, "profile")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(name_label)
