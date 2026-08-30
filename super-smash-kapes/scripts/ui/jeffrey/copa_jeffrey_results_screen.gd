class_name CopaJeffreyResultsScreen
extends Control

signal revancha_pressed
signal hub_pressed

const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const Typography := preload("res://scripts/ui/jeffrey/system/jeffrey_typography.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")
const JeffreyBtn := preload("res://scripts/ui/jeffrey/components/jeffrey_button.gd")
const TitleScript := preload("res://scripts/ui/jeffrey/components/jeffrey_title.gd")
const ScoreRow := preload("res://scripts/ui/jeffrey/components/jeffrey_score_row.gd")
const Motion := preload("res://scripts/ui/jeffrey/system/jeffrey_ui_motion.gd")
const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const PanelScript := preload("res://scripts/ui/jeffrey/components/jeffrey_panel.gd")


func setup(result: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	_build(result)


func _build(result: Dictionary) -> void:
	Layout.bind_full(self)
	var mode_id := str(result.get("mode", ""))
	var is_track := mode_id == ThemeRef.MODE_RACING or mode_id == "racing" or mode_id == "track"
	theme = Typography.theme_for(Typography.TRACK if is_track else (Typography.ZOMBIES if mode_id == Typography.ZOMBIES else Typography.GLOBAL))

	var wash := ColorRect.new()
	if is_track:
		## Dim Track wash — connects race → result without a live 3D backdrop.
		wash.color = Color(0.03, 0.08, 0.1, 0.88)
	else:
		wash.color = Color(0.02, 0.03, 0.06, 0.92)
	Layout.bind_full(wash)
	add_child(wash)

	var shell = PanelScript.new()
	shell.configure(ThemeRef.mode_accent(mode_id), 0.95)
	shell.set_anchors_preset(Control.PRESET_CENTER)
	if is_track:
		## Stronger 16:9 hierarchy while retaining a compact race-results card.
		shell.offset_left = -440
		shell.offset_top = -240
		shell.offset_right = 440
		shell.offset_bottom = 240
	else:
		shell.offset_left = -440
		shell.offset_top = -320
		shell.offset_right = 440
		shell.offset_bottom = 320
	add_child(shell)
	Motion.modal_pop(shell)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8 if is_track else ThemeRef.SPACE_MD)
	Layout.bind_full(root)
	root.offset_left = ThemeRef.SPACE_XL
	root.offset_top = ThemeRef.SPACE_MD if is_track else ThemeRef.SPACE_LG
	root.offset_right = -ThemeRef.SPACE_XL
	root.offset_bottom = -ThemeRef.SPACE_MD if is_track else -ThemeRef.SPACE_LG
	shell.add_child(root)

	var title = TitleScript.new()
	if is_track:
		var banner = preload("res://scripts/track/track_hud_chrome_v1.gd").make_result_banner()
		root.add_child(banner)
		var banner_col := VBoxContainer.new()
		banner_col.add_theme_constant_override("separation", 2)
		banner.add_child(banner_col)
		banner_col.add_child(Layout.outlined_label("TRACK", 16, ThemeRef.mode_accent(ThemeRef.MODE_RACING), HORIZONTAL_ALIGNMENT_CENTER))
		banner_col.add_child(Layout.outlined_label("RESULTADO FINAL", 30, ThemeRef.Base.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		title.configure("COPA JEFFREY", 2, HORIZONTAL_ALIGNMENT_CENTER)
		title.custom_minimum_size = Vector2(0, 36)
		root.add_child(title)
	else:
		title.configure("COPA JEFFREY", 1, HORIZONTAL_ALIGNMENT_CENTER)
		title.custom_minimum_size = Vector2(0, 48)
		root.add_child(title)
		var mode_label := Assets.mode_fallback_label(mode_id) if not mode_id.is_empty() else "PARTIDA"
		var subtitle := Layout.outlined_label("RESULTADO  ·  %s" % mode_label.to_upper(), 20, ThemeRef.mode_accent(mode_id), HORIZONTAL_ALIGNMENT_CENTER)
		subtitle.custom_minimum_size = Vector2(0, 28)
		root.add_child(subtitle)

	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation", 6 if is_track else 8)
	root.add_child(table)

	var awarded: Array = result.get("awarded", [])
	var sorted_awarded := awarded.duplicate()
	sorted_awarded.sort_custom(func(a, b) -> bool:
		var pa := int(a.get("placement", 99))
		var pb := int(b.get("placement", 99))
		if pa <= 0 and pb <= 0:
			return false
		if pa <= 0:
			return false
		if pb <= 0:
			return true
		return pa < pb
	)
	for row in sorted_awarded:
		if not (row is Dictionary):
			continue
		var profile = JeffreyCore.profiles.get_profile(str(row.get("profile_id", "")))
		var fallback_id := str(row.get("profile_id", "?"))
		var name_text: String = profile.display_name if profile != null else _friendly_fallback_name(fallback_id)
		var placement := int(row.get("placement", 0))
		var points := int(row.get("points", 0))
		var total := int(row.get("total_points", 0))
		var score_row = ScoreRow.new()
		table.add_child(score_row)
		score_row.configure(placement if placement > 0 else 0, name_text, points, total, placement == 1, str(row.get("profile_id", "")))
		score_row.emphasize_points()

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6 if is_track else 24)
	root.add_child(spacer)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", ThemeRef.SPACE_LG)
	root.add_child(actions)

	var revancha = JeffreyBtn.new()
	revancha.configure("REVANCHA", JeffreyBtn.Kind.PRIMARY, ThemeRef.BTN_PRIMARY)
	revancha.pressed.connect(func(): revancha_pressed.emit())
	actions.add_child(revancha)

	var hub = JeffreyBtn.new()
	hub.configure("VOLVER AL HUB", JeffreyBtn.Kind.SECONDARY, Vector2(220, 52))
	hub.pressed.connect(func(): hub_pressed.emit())
	actions.add_child(hub)

	call_deferred("_focus_first", revancha)


func _friendly_fallback_name(profile_id: String) -> String:
	var upper := profile_id.strip_edges().to_upper()
	if upper.begins_with("P") and upper.substr(1).is_valid_int():
		return "JUGADOR %d" % int(upper.substr(1))
	return profile_id


func _focus_first(button: Button) -> void:
	if button != null and is_instance_valid(button):
		button.grab_focus()
