class_name ZombiesResultBannerV1
extends PanelContainer

## First-party Zombies result banner — dark green danger identity.

const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")

const Z_GREEN := Color("#4caf63")
const Z_DARK := Color(0.04, 0.09, 0.05, 0.95)


static func make() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Z_DARK
	box.border_color = Z_GREEN
	box.border_width_left = 3
	box.border_width_top = 2
	box.border_width_right = 3
	box.border_width_bottom = 2
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 12
	box.corner_radius_bottom_right = 4
	box.corner_radius_bottom_left = 12
	box.shadow_color = Color(0.1, 0.35, 0.15, 0.4)
	box.shadow_size = 10
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", box)
	return panel


static func fill(panel: PanelContainer, wave: int, kills: int) -> void:
	for child in panel.get_children():
		child.queue_free()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	col.add_child(Layout.outlined_label("ZOMBIES", 16, Z_GREEN, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(Layout.outlined_label("GAME OVER", 28, ThemeRef.Base.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(Layout.outlined_label("RONDA  %d   ·   BAJAS  %d" % [wave, kills], 16, ThemeRef.Base.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(Layout.outlined_label("COPA  ·  0 PTS", 15, ThemeRef.Base.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
