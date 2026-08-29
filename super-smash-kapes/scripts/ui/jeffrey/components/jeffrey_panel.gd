class_name JeffreyPanel
extends PanelContainer

const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func configure(accent: Color = Color.TRANSPARENT, alpha: float = 0.92) -> void:
	var use_accent := accent
	if use_accent == Color.TRANSPARENT:
		use_accent = ThemeRef.Base.GOLD
	add_theme_stylebox_override("panel", ThemeRef.panel_style(use_accent, alpha))
