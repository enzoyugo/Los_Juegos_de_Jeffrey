class_name CopaJeffreyScoreboardScreen
extends Control

signal back_pressed
signal nueva_copa_pressed

const Frame := preload("res://scripts/ui/jeffrey/global_screen_frame.gd")
const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")
const JeffreyBtn := preload("res://scripts/ui/jeffrey/components/jeffrey_button.gd")
const BackBtn := preload("res://scripts/ui/jeffrey/components/jeffrey_back_button.gd")
const TitleScript := preload("res://scripts/ui/jeffrey/components/jeffrey_title.gd")
const ScoreRow := preload("res://scripts/ui/jeffrey/components/jeffrey_score_row.gd")
const PanelScript := preload("res://scripts/ui/jeffrey/components/jeffrey_panel.gd")
const Motion := preload("res://scripts/ui/jeffrey/system/jeffrey_ui_motion.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")
const Podium := preload("res://scripts/ui/jeffrey/copa_jeffrey_podium_v1.gd")


func _ready() -> void:
	set_process_unhandled_input(true)
	Layout.bind_full(self)
	var frame = Frame.new()
	add_child(frame)
	frame.configure(Assets.HUB_BACKGROUND, "", 0.35, Assets.HUB_CONTROLS)

	var title = TitleScript.new()
	frame.content.add_child(title)
	Layout.apply_frac(title, 0.18, 0.04, 0.64, 0.10)
	title.configure("COPA JEFFREY", 1, HORIZONTAL_ALIGNMENT_CENTER)

	var podium = Podium.new()
	frame.content.add_child(podium)
	Layout.apply_frac(podium, 0.18, 0.14, 0.64, 0.22)
	podium.configure(JeffreyCore.copa.leaderboard(true))

	var header := Layout.outlined_label(
		"POS    JUGADOR              PTS    W    PJ",
		ThemeRef.Base.SIZE_SECTION,
		ThemeRef.Base.MUTED,
		HORIZONTAL_ALIGNMENT_LEFT
	)
	frame.content.add_child(header)
	Layout.apply_frac(header, 0.18, 0.38, 0.64, 0.04)

	var standings_panel = PanelScript.new()
	standings_panel.configure(ThemeRef.Base.GOLD, 0.88)
	frame.content.add_child(standings_panel)
	Layout.apply_frac(standings_panel, 0.18, 0.42, 0.64, 0.22)
	var standings := VBoxContainer.new()
	standings.add_theme_constant_override("separation", 6)
	Layout.bind_full(standings)
	standings.offset_left = ThemeRef.SPACE_MD
	standings.offset_top = ThemeRef.SPACE_SM
	standings.offset_right = -ThemeRef.SPACE_MD
	standings.offset_bottom = -ThemeRef.SPACE_SM
	standings_panel.add_child(standings)
	_fill_standings(standings)

	var rounds_title = TitleScript.new()
	frame.content.add_child(rounds_title)
	Layout.apply_frac(rounds_title, 0.18, 0.66, 0.40, 0.04)
	rounds_title.configure("ÚLTIMAS RONDAS", 2, HORIZONTAL_ALIGNMENT_LEFT)

	var rounds_panel = PanelScript.new()
	rounds_panel.configure(ThemeRef.Base.ACCENT, 0.85)
	frame.content.add_child(rounds_panel)
	Layout.apply_frac(rounds_panel, 0.18, 0.70, 0.64, 0.14)
	var rounds := VBoxContainer.new()
	rounds.add_theme_constant_override("separation", 4)
	Layout.bind_full(rounds)
	rounds.offset_left = ThemeRef.SPACE_MD
	rounds.offset_top = ThemeRef.SPACE_SM
	rounds.offset_right = -ThemeRef.SPACE_MD
	rounds.offset_bottom = -ThemeRef.SPACE_SM
	rounds_panel.add_child(rounds)
	_fill_rounds(rounds)

	var back = BackBtn.new()
	frame.content.add_child(back)
	Layout.apply_frac(back, 0.06, 0.86, 0.18, 0.09)
	back.pressed.connect(func():
		AudioHooks.play_back(self)
		back_pressed.emit()
	)

	var reset = JeffreyBtn.new()
	frame.content.add_child(reset)
	reset.configure("NUEVA COPA", JeffreyBtn.Kind.DANGER, ThemeRef.BTN_PRIMARY)
	Layout.apply_frac(reset, 0.68, 0.88, 0.22, 0.06)
	reset.pressed.connect(func(): nueva_copa_pressed.emit())

	Motion.fade_in(frame, ThemeRef.DURATION_SCREEN)


func _fill_standings(container: VBoxContainer) -> void:
	var board: Array = JeffreyCore.copa.leaderboard(true)
	if board.is_empty():
		container.add_child(Layout.outlined_label("Sin datos de sesión", 18, ThemeRef.Base.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
		return
	var rank := 1
	for row in board:
		var profile = JeffreyCore.profiles.get_profile(str(row.get("profile_id", "")))
		var name_text: String = profile.display_name if profile != null else str(row.get("profile_id", "?"))
		var line := Layout.outlined_label(
			"%d    %s    %d    %d    %d" % [
				rank,
				name_text.to_upper(),
				int(row.get("total_points", 0)),
				int(row.get("wins", 0)),
				int(row.get("matches_played", 0)),
			],
			18,
			ThemeRef.Base.TEXT if rank > 1 else ThemeRef.Base.GOLD_HOT,
			HORIZONTAL_ALIGNMENT_LEFT
		)
		container.add_child(line)
		rank += 1


func _fill_rounds(container: VBoxContainer) -> void:
	var recent: Array = JeffreyCore.copa.recent_rounds(8)
	if recent.is_empty():
		container.add_child(Layout.outlined_label("Todavía no hay rondas", 16, ThemeRef.Base.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
		return
	for round_entry in recent:
		if not (round_entry is Dictionary):
			continue
		var mode_id := str(round_entry.get("mode", ""))
		var mode_label := Assets.mode_fallback_label(mode_id)
		var placements: Array = round_entry.get("placements", [])
		if placements.is_empty():
			continue
		var top: Dictionary = placements[0]
		for p in placements:
			if int(p.get("points", 0)) > int(top.get("points", 0)):
				top = p
		var profile = JeffreyCore.profiles.get_profile(str(top.get("profile_id", "")))
		var name_text: String = profile.display_name if profile != null else str(top.get("profile_id", "?"))
		var points := int(top.get("points", 0))
		var suffix := "Team Clear +3" if mode_id == "zombies" and points == 3 else "%s +%d" % [name_text, points]
		container.add_child(Layout.outlined_label(
			"%-12s  %s" % [mode_label, suffix],
			16,
			ThemeRef.Base.TEXT,
			HORIZONTAL_ALIGNMENT_LEFT
		))
