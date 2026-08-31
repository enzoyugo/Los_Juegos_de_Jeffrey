class_name ModeSelectCard
extends "res://scripts/ui/jeffrey/global_image_button.gd"

const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")

var mode_id: String = ""


func setup_mode(id: String, art_path: String, fallback: String, status: String) -> void:
	mode_id = id
	setup(art_path, fallback, Vector2(280, 90))
	## Playable modes already communicate the action through the authored card art.
	## Do not duplicate the legacy/debug "JUGAR" badge beside the button.
	var badge := Layout.outlined_label("" if status.strip_edges().to_upper() == "JUGAR" else status, 15, ThemeRef.GOLD_HOT, HORIZONTAL_ALIGNMENT_RIGHT)
	Styles.apply(badge, "mode_badge")
	badge.add_theme_font_size_override("font_size", 15)
	badge.add_theme_color_override("font_color", ThemeRef.GOLD_HOT)
	badge.add_theme_constant_override("outline_size", 6)
	add_child(badge)
	badge.anchor_left = 0.62
	badge.anchor_right = 0.96
	badge.anchor_top = 0.58
	badge.anchor_bottom = 0.92
	badge.offset_left = 0
	badge.offset_right = 0
	badge.offset_top = 0
	badge.offset_bottom = 0
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	## Soft plate behind badge for contrast on busy art.
	var plate := ColorRect.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.color = Color(0.02, 0.02, 0.03, 0.72)
	plate.visible = badge.text != ""
	add_child(plate)
	move_child(plate, badge.get_index())
	plate.anchor_left = 0.58
	plate.anchor_right = 0.98
	plate.anchor_top = 0.55
	plate.anchor_bottom = 0.95
	plate.offset_left = 0
	plate.offset_right = 0
	plate.offset_top = 0
	plate.offset_bottom = 0
