class_name KapesResultsScreen
extends Control

signal rematch_pressed
signal change_kapes_pressed
signal menu_pressed

const UILayout := preload("res://scripts/ui/kapes_ui_layout.gd")
const FIGHTER_CATALOG := preload("res://scripts/fighters/fighter_catalog.gd")

const VICTORY_BG := "res://assets/ui/victory/common/victory_bg_defensores.png"
const STATS_PANEL := "res://assets/ui/victory/common/victory_stats_panel.png"
const BTN_REMATCH := "res://assets/ui/victory/common/victory_btn_rematch.png"
const BTN_MENU := "res://assets/ui/victory/common/victory_btn_menu.png"
const TERERE_VICTORY := "res://assets/ui/victory/terere/terere_victory.png"
const JAGUARETE_VICTORY := "res://assets/ui/victory/jaguarete/jaguarete_victory.png"

var _intro_tween: Tween


func _ready() -> void:
	UILayout.bind_full_rect(self)
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(winner_id: int, summary: Dictionary, match_setup = null) -> void:
	for child in get_children():
		child.queue_free()
	_build(winner_id, summary, match_setup)
	if not resized.is_connected(_apply_layout):
		resized.connect(_apply_layout)
	_apply_layout()
	_play_intro()
	var AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")
	AudioHooks.play_result(self)


func _build(winner_id: int, summary: Dictionary, match_setup) -> void:
	var background := _make_tex(_load_tex(VICTORY_BG), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	background.name = "VictoryBackground"
	add_child(background)

	var wash := ColorRect.new()
	wash.name = "VictoryWash"
	var winner_color := KapesVisual.player_color(winner_id)
	wash.color = Color(winner_color.r, winner_color.g, winner_color.b, 0.0)
	wash.focus_mode = Control.FOCUS_NONE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	var content := Control.new()
	content.name = "ResultsContent"
	content.focus_mode = Control.FOCUS_NONE
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	## LEFT: huge winner art — floats over background, no panel.
	var hero := _make_tex(_victory_art_for_player(winner_id, match_setup), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	hero.name = "WinnerHero"
	content.add_child(hero)

	## RIGHT: single vertical stack — no mega backplate, no title banner asset.
	var right_stack := VBoxContainer.new()
	right_stack.name = "RightStack"
	right_stack.add_theme_constant_override("separation", 14)
	right_stack.focus_mode = Control.FOCUS_NONE
	right_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(right_stack)

	var title_block := VBoxContainer.new()
	title_block.name = "TitleBlock"
	title_block.add_theme_constant_override("separation", 4)
	title_block.focus_mode = Control.FOCUS_NONE
	title_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_stack.add_child(title_block)

	var accent_line := HBoxContainer.new()
	accent_line.name = "TricolorAccent"
	accent_line.add_theme_constant_override("separation", 0)
	accent_line.custom_minimum_size = Vector2(0, 6)
	for color in [KapesVisual.RED, KapesVisual.WHITE, KapesVisual.BLUE]:
		var band := ColorRect.new()
		band.color = color
		band.custom_minimum_size = Vector2(28, 6)
		band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		accent_line.add_child(band)
	title_block.add_child(accent_line)

	var ganador := _make_label(title_block, "GANADOR", 30, KapesVisual.GOLD)
	ganador.name = "WinnerTitle"

	var winner_name := _fighter_display_name(winner_id, summary, match_setup)
	var winner := _make_label(title_block, winner_name, 80, KapesVisual.WHITE)
	winner.name = "WinnerName"
	winner.add_theme_color_override("font_outline_color", winner_color)
	winner.add_theme_constant_override("outline_size", 5)

	var accent := _make_label(title_block, "¡VICTORIA!", 34, winner_color)
	accent.name = "VictoryAccent"

	var stats_row := HBoxContainer.new()
	stats_row.name = "StatsFrame"
	stats_row.add_theme_constant_override("separation", 14)
	stats_row.focus_mode = Control.FOCUS_NONE
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_stack.add_child(stats_row)
	for id in [1, 2]:
		stats_row.add_child(_make_stats_card(id, summary, match_setup, winner_id))

	var actions := VBoxContainer.new()
	actions.name = "ActionsRow"
	actions.add_theme_constant_override("separation", 10)
	actions.focus_mode = Control.FOCUS_NONE
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_stack.add_child(actions)

	var rematch_row := Control.new()
	rematch_row.name = "RematchRow"
	rematch_row.custom_minimum_size = Vector2(0, 72)
	actions.add_child(rematch_row)
	var rematch_art := _make_tex(_load_tex(BTN_REMATCH), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	rematch_art.name = "RematchArt"
	rematch_row.add_child(rematch_art)
	var rematch_btn := _make_hotspot(rematch_row, "RematchButton")
	rematch_btn.pressed.connect(func(): rematch_pressed.emit())

	var secondary_row := HBoxContainer.new()
	secondary_row.name = "SecondaryRow"
	secondary_row.add_theme_constant_override("separation", 12)
	secondary_row.custom_minimum_size = Vector2(0, 64)
	actions.add_child(secondary_row)

	var change_wrap := Control.new()
	change_wrap.name = "ChangeKapesWrap"
	change_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secondary_row.add_child(change_wrap)
	var change_art := _make_change_kapes_art(change_wrap)
	change_art.name = "ChangeKapesArt"
	var change_label := _make_label(change_wrap, "CAMBIAR KAPES", 20, KapesVisual.WHITE)
	change_label.name = "ChangeKapesLabel"
	change_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	change_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var change_btn := _make_hotspot(change_wrap, "ChangeKapesButton")
	change_btn.pressed.connect(func(): change_kapes_pressed.emit())

	var menu_wrap := Control.new()
	menu_wrap.name = "MenuWrap"
	menu_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secondary_row.add_child(menu_wrap)
	var menu_art := _make_tex(_load_tex(BTN_MENU), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	menu_art.name = "MenuArt"
	menu_wrap.add_child(menu_art)
	var menu_btn := _make_hotspot(menu_wrap, "MenuButton")
	menu_btn.pressed.connect(func(): menu_pressed.emit())

	rematch_btn.grab_focus()


func _make_change_kapes_art(parent: Control) -> Panel:
	var panel := Panel.new()
	panel.name = "ChangeKapesPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := KapesVisual.panel_style(Color(0.04, 0.07, 0.14, 0.94), KapesVisual.GOLD, 3)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _make_stats_card(player_id: int, summary: Dictionary, match_setup, winner_id: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "StatsP%d" % player_id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var accent := KapesVisual.player_color(player_id)
	if player_id == winner_id:
		accent = accent.lightened(0.08)
	card.add_theme_stylebox_override("panel", KapesVisual.panel_style(Color(0.04, 0.07, 0.14, 0.88), accent, 2))
	card.add_child(_make_stats_column(player_id, summary, match_setup, winner_id))
	return card


func _make_stats_column(player_id: int, summary: Dictionary, match_setup, winner_id: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.name = "StatsColumnP%d" % player_id
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fighter_name := _fighter_display_name(player_id, summary, match_setup)
	var stats: Dictionary = summary.get(player_id, {})
	var header_color := KapesVisual.player_color(player_id)
	if player_id == winner_id:
		header_color = header_color.lightened(0.08)
	var header := _make_label(col, "P%d  %s" % [player_id, fighter_name], 22, header_color)
	header.name = "Header"
	_add_stat_row(col, "KOs", str(int(stats.get("kos", 0))))
	_add_stat_row(col, "CAÍDAS", str(int(stats.get("falls", 0))))
	_add_stat_row(col, "DAÑO", "%.0f%%" % float(stats.get("damage_dealt", 0.0)))
	_add_stat_row(col, "GOLPES", str(int(stats.get("attacks_connected", 0))))
	return col


func _add_stat_row(parent: VBoxContainer, label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := _make_label(row, label_text, 20, KapesVisual.MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := _make_label(row, value_text, 24, KapesVisual.WHITE)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(row)


func _victory_art_for_player(player_id: int, match_setup) -> Texture2D:
	var definition = _fighter_definition_for_player(player_id, match_setup)
	if definition != null:
		var from_def: Texture2D = definition.load_victory_texture() if definition.has_method("load_victory_texture") else definition.victory_texture
		if from_def != null:
			return from_def
	var fighter_id := ""
	if match_setup != null:
		fighter_id = match_setup.player_1_fighter_id if player_id == 1 else match_setup.player_2_fighter_id
	if fighter_id == "jaguarete":
		return _load_tex(JAGUARETE_VICTORY)
	if fighter_id == "terere":
		return _load_tex(TERERE_VICTORY)
	return null


func _play_intro() -> void:
	var AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")
	AudioHooks.play_result(self)
	if _intro_tween != null:
		_intro_tween.kill()
	var content := get_node_or_null("ResultsContent") as Control
	if content == null:
		return
	var wash := get_node_or_null("VictoryWash") as ColorRect
	var hero := content.get_node_or_null("WinnerHero") as Control
	var right := content.get_node_or_null("RightStack") as Control
	var title := content.get_node_or_null("RightStack/TitleBlock") as Control
	var stats := content.get_node_or_null("RightStack/StatsFrame") as Control
	var actions := content.get_node_or_null("RightStack/ActionsRow") as Control
	for node in [hero, title, stats, actions]:
		if node != null:
			node.modulate.a = 0.0
	if hero != null:
		hero.position.x -= 64.0
		hero.scale = Vector2(0.90, 0.90)
	if wash != null:
		wash.color.a = 0.0
	_intro_tween = create_tween()
	if wash != null:
		_intro_tween.tween_property(wash, "color:a", 0.14, 0.08)
	if hero != null:
		_intro_tween.parallel().tween_property(hero, "modulate:a", 1.0, 0.20)
		_intro_tween.parallel().tween_property(hero, "position:x", hero.position.x + 64.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_intro_tween.parallel().tween_property(hero, "scale", Vector2(1.02, 1.02), 0.18).set_trans(Tween.TRANS_BACK)
		_intro_tween.tween_property(hero, "scale", Vector2.ONE, 0.08)
	_intro_tween.tween_interval(0.02)
	if title != null:
		_intro_tween.parallel().tween_property(title, "modulate:a", 1.0, 0.14).set_delay(0.10)
	if stats != null:
		_intro_tween.parallel().tween_property(stats, "modulate:a", 1.0, 0.14).set_delay(0.22)
	if actions != null:
		_intro_tween.parallel().tween_property(actions, "modulate:a", 1.0, 0.12).set_delay(0.36)


func _fighter_definition_for_player(player_id: int, match_setup):
	if match_setup == null:
		return null
	var fighter_id: String = match_setup.player_1_fighter_id if player_id == 1 else match_setup.player_2_fighter_id
	return FIGHTER_CATALOG.get_by_id(fighter_id)


func _fighter_display_name(player_id: int, summary: Dictionary, match_setup = null) -> String:
	var names: Dictionary = summary.get("fighter_names", {})
	if names.has(player_id):
		return str(names[player_id])
	var definition = _fighter_definition_for_player(player_id, match_setup)
	if definition != null:
		return definition.display_name
	return "P%d" % player_id


func _apply_layout() -> void:
	var safe := UILayout.safe_rect(get_viewport())
	for child in get_children():
		if child is TextureRect or child is ColorRect:
			UILayout.bind_full_rect(child as Control)
	var content := get_node_or_null("ResultsContent") as Control
	if content == null:
		return
	content.position = safe.position
	content.size = safe.size
	var scale := UILayout.scale_factor(get_viewport())

	## Left 45%: hero. Right 50%: title / compact stats / actions.
	var right_x := safe.size.x * 0.50
	var right_w := safe.size.x * 0.46
	var right_y := safe.size.y * 0.10
	var right_h := safe.size.y * 0.80

	var hero := content.get_node_or_null("WinnerHero") as TextureRect
	if hero != null:
		hero.size = Vector2(safe.size.x * KapesVisual.RESULTS_HERO_RATIO, safe.size.y * KapesVisual.RESULTS_WINNER_HEIGHT_RATIO)
		var feet_y := safe.size.y * 0.93
		hero.position = Vector2(safe.size.x * 0.03, feet_y - hero.size.y)

	var right_stack := content.get_node_or_null("RightStack") as VBoxContainer
	if right_stack != null:
		right_stack.position = Vector2(right_x, right_y)
		right_stack.size = Vector2(right_w, right_h)

	var title_block := content.get_node_or_null("RightStack/TitleBlock") as VBoxContainer
	if title_block != null:
		var ganador := title_block.get_node_or_null("WinnerTitle") as Label
		var winner := title_block.get_node_or_null("WinnerName") as Label
		var accent := title_block.get_node_or_null("VictoryAccent") as Label
		if ganador != null:
			ganador.add_theme_font_size_override("font_size", UILayout.font_size(get_viewport(), 30))
		if winner != null:
			winner.add_theme_font_size_override("font_size", UILayout.font_size(get_viewport(), 78))
			winner.autowrap_mode = TextServer.AUTOWRAP_WORD
		if accent != null:
			accent.add_theme_font_size_override("font_size", UILayout.font_size(get_viewport(), 34))

	var stats_frame := content.get_node_or_null("RightStack/StatsFrame") as Control
	if stats_frame != null:
		stats_frame.custom_minimum_size = Vector2(right_w, safe.size.y * KapesVisual.RESULTS_STATS_RATIO)

	var actions := content.get_node_or_null("RightStack/ActionsRow") as VBoxContainer
	if actions != null:
		var rematch_row := actions.get_node_or_null("RematchRow") as Control
		var secondary := actions.get_node_or_null("SecondaryRow") as HBoxContainer
		if rematch_row != null:
			rematch_row.custom_minimum_size = Vector2(right_w * 0.68, 72.0 * scale)
			var rematch_art := rematch_row.get_node_or_null("RematchArt") as Control
			var rematch_btn := rematch_row.get_node_or_null("RematchButton") as Control
			if rematch_art != null:
				rematch_art.set_anchors_preset(Control.PRESET_FULL_RECT)
			if rematch_btn != null:
				rematch_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		if secondary != null:
			secondary.custom_minimum_size = Vector2(right_w, 64.0 * scale)
			var change_wrap := secondary.get_node_or_null("ChangeKapesWrap") as Control
			var menu_wrap := secondary.get_node_or_null("MenuWrap") as Control
			if change_wrap != null:
				var change_art := change_wrap.get_node_or_null("ChangeKapesArt") as Control
				var change_label := change_wrap.get_node_or_null("ChangeKapesLabel") as Label
				var change_btn := change_wrap.get_node_or_null("ChangeKapesButton") as Control
				if change_art != null:
					change_art.set_anchors_preset(Control.PRESET_FULL_RECT)
				if change_label != null:
					change_label.set_anchors_preset(Control.PRESET_FULL_RECT)
					change_label.add_theme_font_size_override("font_size", UILayout.font_size(get_viewport(), 20))
				if change_btn != null:
					change_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
			if menu_wrap != null:
				var menu_art := menu_wrap.get_node_or_null("MenuArt") as Control
				var menu_btn := menu_wrap.get_node_or_null("MenuButton") as Control
				if menu_art != null:
					menu_art.set_anchors_preset(Control.PRESET_FULL_RECT)
				if menu_btn != null:
					menu_btn.set_anchors_preset(Control.PRESET_FULL_RECT)


func _load_tex(path: String) -> Texture2D:
	if path.is_empty():
		return null
	return load(path) as Texture2D


func _make_tex(texture: Texture2D, stretch_mode: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = stretch_mode
	rect.focus_mode = Control.FOCUS_NONE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _make_hotspot(parent: Control, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.focus_mode = Control.FOCUS_ALL
	button.flat = true
	button.modulate = Color(1, 1, 1, 0.01)
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.focus_entered.connect(func(): button.scale = Vector2(1.04, 1.04))
	button.focus_exited.connect(func(): button.scale = Vector2.ONE)
	parent.add_child(button)
	return button


func _make_label(parent: Control, text: String, design_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UILayout.font_size(get_viewport(), design_size))
	label.add_theme_color_override("font_color", color)
	label.focus_mode = Control.FOCUS_NONE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
