class_name CopaJeffreyPodiumV1
extends PanelContainer

## First-party Copa podium — StyleBox composition (no fake 3D boxes).
## Displays top-3 from JeffreyCore.copa leaderboard data only.

const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")


func configure(board: Array) -> void:
	for child in get_children():
		child.queue_free()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.06, 0.09, 0.92)
	box.border_color = ThemeRef.Base.GOLD
	box.border_width_left = 2
	box.border_width_top = 3
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.corner_radius_top_left = 6
	box.corner_radius_top_right = 14
	box.corner_radius_bottom_right = 6
	box.corner_radius_bottom_left = 14
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	add_theme_stylebox_override("panel", box)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	root.add_child(Layout.outlined_label("PODIO", 14, ThemeRef.Base.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	root.add_child(row)

	## Order visual: 2° | 1° | 3°
	var slots := [1, 0, 2]
	var heights := [72, 96, 60]
	for si in slots.size():
		var idx: int = slots[si]
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_END
		col.add_theme_constant_override("separation", 4)
		col.custom_minimum_size = Vector2(120, 0)
		row.add_child(col)
		var name_text := "—"
		var pts := 0
		if idx < board.size() and board[idx] is Dictionary:
			var entry: Dictionary = board[idx]
			var profile = JeffreyCore.profiles.get_profile(str(entry.get("profile_id", "")))
			name_text = profile.display_name if profile != null else str(entry.get("profile_id", "?"))
			pts = int(entry.get("total_points", 0))
		var place := idx + 1
		var accent := ThemeRef.Base.GOLD_HOT if place == 1 else (Color("#c0c8d0") if place == 2 else Color("#c08050"))
		col.add_child(Layout.outlined_label("%d°" % place, 22 if place == 1 else 18, accent, HORIZONTAL_ALIGNMENT_CENTER))
		col.add_child(Layout.outlined_label(name_text.to_upper(), 14, ThemeRef.Base.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		col.add_child(Layout.outlined_label("%d PTS" % pts, 16, accent, HORIZONTAL_ALIGNMENT_CENTER))
		var plinth := ColorRect.new()
		plinth.color = Color(accent.r, accent.g, accent.b, 0.35)
		plinth.custom_minimum_size = Vector2(100, heights[si])
		col.add_child(plinth)
		if place == 1:
			col.add_child(Layout.outlined_label("★", 18, ThemeRef.Base.GOLD_HOT, HORIZONTAL_ALIGNMENT_CENTER))
