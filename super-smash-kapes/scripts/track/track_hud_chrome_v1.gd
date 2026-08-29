class_name TrackHudChromeV1
extends RefCounted

## First-party Track HUD chrome — lightweight racing frame (no embedded text).

const TRACK_ACCENT := Color("#3db8c9")
const TRACK_ACCENT_DIM := Color("#1a6a78")
const PLATE := Color(0.03, 0.07, 0.09, 0.78)
const GOLD := Color("#e8b84a")


static func make_timer_frame() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PLATE
	box.border_color = TRACK_ACCENT
	box.border_width_left = 2
	box.border_width_top = 3
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 14
	box.corner_radius_bottom_right = 4
	box.corner_radius_bottom_left = 14
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 3)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	return panel


static func make_side_chip(accent: Color = TRACK_ACCENT) -> PanelContainer:
	## Compact micro-chip — no giant empty debug rectangle.
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.05, 0.07, 0.42)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.7)
	box.border_width_left = 3
	box.border_width_top = 0
	box.border_width_right = 0
	box.border_width_bottom = 0
	box.corner_radius_top_right = 6
	box.corner_radius_bottom_right = 6
	box.content_margin_left = 10
	box.content_margin_right = 12
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", box)
	return panel


static func make_hint_strip() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.04, 0.05, 0.55)
	box.border_color = Color(TRACK_ACCENT.r, TRACK_ACCENT.g, TRACK_ACCENT.b, 0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", box)
	return panel


static func make_result_banner() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.09, 0.11, 0.94)
	box.border_color = TRACK_ACCENT
	box.border_width_left = 3
	box.border_width_top = 2
	box.border_width_right = 3
	box.border_width_bottom = 2
	box.corner_radius_top_left = 6
	box.corner_radius_top_right = 18
	box.corner_radius_bottom_right = 6
	box.corner_radius_bottom_left = 18
	box.shadow_color = Color(0.05, 0.4, 0.45, 0.35)
	box.shadow_size = 10
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	return panel


static func make_accent_bar() -> ColorRect:
	var bar := ColorRect.new()
	bar.color = TRACK_ACCENT
	bar.custom_minimum_size = Vector2(0, 3)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return bar


static func make_setup_card() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.07, 0.09, 0.92)
	box.border_color = TRACK_ACCENT
	box.border_width_left = 2
	box.border_width_top = 3
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.corner_radius_top_left = 6
	box.corner_radius_top_right = 16
	box.corner_radius_bottom_right = 6
	box.corner_radius_bottom_left = 16
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 12
	box.content_margin_left = 26
	box.content_margin_right = 26
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", box)
	return panel
