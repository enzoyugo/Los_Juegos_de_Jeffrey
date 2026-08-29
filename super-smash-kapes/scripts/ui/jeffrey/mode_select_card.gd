class_name ModeSelectCard
extends "res://scripts/ui/jeffrey/global_image_button.gd"

const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")

var mode_id: String = ""


func setup_mode(id: String, art_path: String, fallback: String, status: String) -> void:
	mode_id = id
	setup(art_path, fallback, Vector2(280, 90))
	var badge := Layout.outlined_label(status, Styles.SIZE_BADGE, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	Styles.apply(badge, "mode_badge")
	add_child(badge)
	badge.anchor_left = 0.58
	badge.anchor_right = 0.94
	badge.anchor_top = 0.62
	badge.anchor_bottom = 0.90
	badge.offset_left = 0
	badge.offset_right = 0
	badge.offset_top = 0
	badge.offset_bottom = 0
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
