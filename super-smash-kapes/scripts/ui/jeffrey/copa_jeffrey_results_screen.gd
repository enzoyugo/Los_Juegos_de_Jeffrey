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
const RESULT_BG := "res://assets/ui/shared/copa_jeffrey_v2/01_result_background.png"
const RESULT_TITLE := "res://assets/ui/shared/copa_jeffrey_v2/02_resultado_final_title.png"
const RESULT_LOGO := "res://assets/ui/shared/copa_jeffrey_v2/03_logo_los_juegos_de_jeffrey.png"
const RESULT_COPA := "res://assets/ui/shared/copa_jeffrey_v2/04_logo_copa_jeffrey.png"


func setup(result: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	_build(result)


func _build(result: Dictionary) -> void:
	Layout.bind_full(self)
	var mode_id := str(result.get("mode", ""))
	theme = Typography.theme_for(Typography.GLOBAL)
	var backdrop := _raster(RESULT_BG, Vector2.ZERO, Vector2(1920, 1080), true)
	backdrop.modulate.a = 1.0
	add_child(backdrop)
	var wash := ColorRect.new()
	wash.color = Color(0.01, 0.01, 0.03, 0.16)
	Layout.bind_full(wash)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	_add_result_art(self)
	var table := VBoxContainer.new()
	table.position = Vector2(385, 365)
	table.size = Vector2(1150, 420)
	table.add_theme_constant_override("separation", 12)
	add_child(table)

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
		var supplied_name := str(row.get("display_name", row.get("player_name", ""))).strip_edges()
		var name_text: String = supplied_name if not supplied_name.is_empty() else (profile.display_name if profile != null else _friendly_fallback_name(fallback_id))
		var placement := int(row.get("placement", 0))
		var points := int(row.get("points", 0))
		var total := int(row.get("total_points", 0))
		_add_score_template(table, placement if placement > 0 else 0, name_text, points, total, placement == 1)

	var actions := HBoxContainer.new()
	actions.position = Vector2(650, 870)
	actions.size = Vector2(620, 90)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	add_child(actions)

	var revancha := _copa_button("REVANCHA", "res://assets/ui/shared/copa_jeffrey_v2/08_button_gold.png")
	revancha.pressed.connect(func(): revancha_pressed.emit())
	actions.add_child(revancha)

	var hub := _copa_button("VOLVER AL HUB", "res://assets/ui/shared/copa_jeffrey_v2/09_button_purple.png")
	hub.pressed.connect(func(): hub_pressed.emit())
	actions.add_child(hub)

	call_deferred("_focus_first", revancha)


func _add_result_art(shell: Control) -> void:
	shell.add_child(_raster(RESULT_LOGO, Vector2(70, 34), Vector2(280, 198)))
	shell.add_child(_raster(RESULT_COPA, Vector2(1600, 28), Vector2(260, 211)))
	shell.add_child(_raster(RESULT_TITLE, Vector2(670, 68), Vector2(580, 197)))


func _raster(path: String, pos: Vector2, size: Vector2, ignore_size: bool = true) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load(path)
	image.position = pos
	image.size = size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE if ignore_size else TextureRect.EXPAND_KEEP_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


func _add_score_template(parent: Control, placement: int, player_name: String, points: int, total: int, winner: bool) -> void:
	var row := Control.new()
	row.custom_minimum_size = Vector2(1150, 90)
	parent.add_child(row)
	row.add_child(_raster("res://assets/ui/shared/copa_jeffrey_v2/05_player_stack_template.png", Vector2.ZERO, Vector2(475, 87)))
	row.add_child(_raster("res://assets/ui/shared/copa_jeffrey_v2/06_puntos_sumados_template.png", Vector2(495, 0), Vector2(224, 88)))
	row.add_child(_raster("res://assets/ui/shared/copa_jeffrey_v2/07_puntos_totales_template.png", Vector2(727, 0), Vector2(397, 87)))
	var place := Layout.outlined_label("%d" % placement, 34, ThemeRef.Base.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	place.position = Vector2(21, 24); place.size = Vector2(44, 40); row.add_child(place)
	var name := Layout.outlined_label(player_name.to_upper(), 22, ThemeRef.Base.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	name.position = Vector2(85, 24); name.size = Vector2(360, 38); row.add_child(name)
	## The approved gained-points template already supplies the plus glyph;
	## render one dynamic numeric value beside it, avoiding a duplicate sign.
	var gained := Layout.outlined_label("%d" % points, 34, ThemeRef.Base.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	gained.position = Vector2(532, 24); gained.size = Vector2(155, 38); row.add_child(gained)
	var sum := Layout.outlined_label("%d" % total, 34, ThemeRef.Base.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	sum.position = Vector2(800, 24); sum.size = Vector2(210, 38); row.add_child(sum)
	if winner:
		name.add_theme_color_override("font_color", ThemeRef.Base.GOLD)


func _copa_button(text_value: String, path: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(330, 76)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", ThemeRef.Base.TEXT)
	button.add_theme_color_override("font_hover_color", ThemeRef.Base.TEXT)
	var texture := load(path)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxTexture.new()
		style.texture = texture
		style.texture_margin_left = 60
		style.texture_margin_right = 60
		style.texture_margin_top = 16
		style.texture_margin_bottom = 16
		button.add_theme_stylebox_override(state_name, style)
	return button


func _friendly_fallback_name(profile_id: String) -> String:
	var upper := profile_id.strip_edges().to_upper()
	if upper.begins_with("P") and upper.substr(1).is_valid_int():
		return "JUGADOR %d" % int(upper.substr(1))
	return profile_id


func _authoritative_mode_label(mode_id: String) -> String:
	match mode_id.strip_edges().to_lower():
		"track", "racing", "copa":
			return "TRACK"
		"smash", "soco":
			return "SOCO"
		"zombies", "zombie":
			return "ZOMBIES"
		_:
			return mode_id.strip_edges().to_upper() if not mode_id.strip_edges().is_empty() else "PARTIDA"


func _focus_first(button: Button) -> void:
	if button != null and is_instance_valid(button):
		button.grab_focus()
