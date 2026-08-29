class_name CopaJeffreyHubPanel
extends Control

signal scoreboard_pressed
signal nueva_copa_pressed

const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")
const PanelScript := preload("res://scripts/ui/jeffrey/components/jeffrey_panel.gd")
const TitleScript := preload("res://scripts/ui/jeffrey/components/jeffrey_title.gd")
const ScoreRow := preload("res://scripts/ui/jeffrey/components/jeffrey_score_row.gd")
const JeffreyBtn := preload("res://scripts/ui/jeffrey/components/jeffrey_button.gd")
const Motion := preload("res://scripts/ui/jeffrey/system/jeffrey_ui_motion.gd")

var _rows: VBoxContainer


func _ready() -> void:
	var panel = PanelScript.new()
	panel.configure(ThemeRef.Base.GOLD, 0.9)
	Layout.bind_full(panel)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", ThemeRef.SPACE_SM)
	Layout.bind_full(root)
	root.offset_left = ThemeRef.SPACE_SM
	root.offset_top = ThemeRef.SPACE_SM
	root.offset_right = -ThemeRef.SPACE_SM
	root.offset_bottom = -ThemeRef.SPACE_SM
	panel.add_child(root)

	var title = TitleScript.new()
	title.configure("COPA", 3, HORIZONTAL_ALIGNMENT_CENTER)
	title.custom_minimum_size = Vector2(0, 22)
	root.add_child(title)
	var subtitle := Layout.outlined_label("JEFFREY", 13, ThemeRef.Base.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(subtitle)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	root.add_child(_rows)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", ThemeRef.SPACE_SM)
	root.add_child(actions)

	var more = JeffreyBtn.new()
	more.configure("VER MÁS", JeffreyBtn.Kind.SECONDARY, Vector2(96, 32))
	more.pressed.connect(func(): scoreboard_pressed.emit())
	actions.add_child(more)

	var reset = JeffreyBtn.new()
	reset.configure("NUEVA COPA", JeffreyBtn.Kind.GHOST, Vector2(118, 32))
	reset.pressed.connect(func(): nueva_copa_pressed.emit())
	actions.add_child(reset)

	_refresh()
	Motion.fade_in(self, ThemeRef.DURATION_NORMAL)


func _refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var board: Array = JeffreyCore.copa.leaderboard(true)
	if board.is_empty():
		_rows.add_child(Layout.outlined_label("Sin puntos aún", 14, ThemeRef.Base.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return
	var rank := 1
	for row in board:
		if rank > 4:
			break
		var profile = JeffreyCore.profiles.get_profile(str(row.get("profile_id", "")))
		var name_text: String = profile.display_name if profile != null else str(row.get("profile_id", "?"))
		var score_row = ScoreRow.new()
		_rows.add_child(score_row)
		score_row.configure(
			rank,
			name_text,
			int(row.get("total_points", 0)),
			-1,
			rank == 1,
			str(row.get("profile_id", ""))
		)
		if rank == 1:
			score_row.emphasize_points()
		rank += 1
