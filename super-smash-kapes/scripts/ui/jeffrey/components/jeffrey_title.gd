class_name JeffreyTitle
extends Control

const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")
const Motion := preload("res://scripts/ui/jeffrey/system/jeffrey_ui_motion.gd")

var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(text_value: String, level: int = 1, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	for child in get_children():
		child.queue_free()
	var size := ThemeRef.Base.SIZE_SCREEN_TITLE
	var color := ThemeRef.Base.GOLD
	match level:
		2:
			size = ThemeRef.Base.SIZE_MODE_TITLE
			color = ThemeRef.Base.ACCENT
		3:
			size = ThemeRef.Base.SIZE_SECTION
			color = ThemeRef.Base.MUTED
	_label = Layout.outlined_label(text_value, size, color, align)
	add_child(_label)
	Layout.bind_full(_label)
	Motion.fade_in(_label, ThemeRef.DURATION_NORMAL)
