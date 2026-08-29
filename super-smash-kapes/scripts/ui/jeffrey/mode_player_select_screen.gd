class_name JeffreyModePlayerSelectScreen
extends Control

signal players_confirmed(profile_ids: Array)
signal cancelled

const Frame := preload("res://scripts/ui/jeffrey/global_screen_frame.gd")
const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const ImageButton := preload("res://scripts/ui/jeffrey/global_image_button.gd")
const PlayerCard := preload("res://scripts/ui/jeffrey/global_player_card.gd")
const RowScript := preload("res://scripts/ui/jeffrey/selected_player_row.gd")
const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")
const ModeRegistry := preload("res://scripts/core/jeffrey/game_mode_registry.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")

var mode_id: String = ModeRegistry.MODE_SMASH
var preselected_ids: Array[String] = []
var _grid: GridContainer
var _cards: Dictionary = {}
var _continue: Button
var _count: Label
var _limits_label: Label
var _list: VBoxContainer
var _error: Label


func request_back() -> void:
	AudioHooks.play_back(self)
	cancelled.emit()


func _ready() -> void:
	set_process_unhandled_input(true)
	Layout.bind_full(self)
	var frame = Frame.new()
	add_child(frame)
	frame.configure(Assets.MODE_PLAYERS_BACKGROUND, "", 0.34, Assets.MODE_PLAYERS_CONTROLS)

	var title := TextureRect.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.texture = Assets.texture(Assets.MODE_PLAYERS_TITLE)
	frame.content.add_child(title)
	Layout.apply_frac(title, 0.04, 0.02, 0.60, 0.14)
	if title.texture == null:
		var mode = JeffreyCore.modes.get_mode(mode_id)
		var heading := "¿QUIÉNES JUEGAN?"
		if mode != null:
			heading = "¿QUIÉNES JUEGAN %s?" % Assets.mode_fallback_label(mode_id)
		var fallback := Layout.outlined_label(heading, 32, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		frame.content.add_child(fallback)
		Layout.apply_frac(fallback, 0.04, 0.03, 0.58, 0.1)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.content.add_child(scroll)
	Layout.apply_frac(scroll, 0.03, 0.16, 0.64, 0.60)
	_grid = GridContainer.new()
	_grid.columns = 1
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	var FitHost := preload("res://scripts/ui/jeffrey/texture_fit_host.gd")
	var summary = FitHost.new()
	frame.content.add_child(summary)
	Layout.apply_frac(summary, 0.68, 0.12, 0.30, 0.66)
	summary.set_texture(Assets.texture(Assets.MODE_PLAYERS_SUMMARY))
	var cover := ColorRect.new()
	cover.color = Color(0.04, 0.04, 0.05, 0.92)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.art_space.add_child(cover)
	Layout.bind_frac_rect(cover, 0.12, 0.68, 0.88, 0.97)
	var summary_box := VBoxContainer.new()
	summary_box.add_theme_constant_override("separation", 8)
	var summary_margin := MarginContainer.new()
	Layout.bind_full(summary_margin)
	summary_margin.add_theme_constant_override("margin_left", 28)
	summary_margin.add_theme_constant_override("margin_right", 28)
	summary_margin.add_theme_constant_override("margin_top", 56)
	summary_margin.add_theme_constant_override("margin_bottom", 100)
	summary.art_space.add_child(summary_margin)
	summary_margin.add_child(summary_box)
	_count = Layout.outlined_label("0 SELECCIONADOS", 22, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	Styles.apply(_count, "counter")
	_count.add_theme_font_size_override("font_size", 22)
	summary_box.add_child(_count)
	var limits := _limits()
	_limits_label = Layout.outlined_label("MÍN %d · MÁX %d" % [limits.x, limits.y], Styles.SIZE_HELPER, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	Styles.apply(_limits_label, "small_helper")
	summary_box.add_child(_limits_label)
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summary_box.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	list_scroll.add_child(_list)

	_error = Layout.outlined_label("", 16, ThemeRef.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	frame.content.add_child(_error)
	Layout.apply_frac(_error, 0.08, 0.75, 0.5, 0.04)

	var back = ImageButton.new()
	frame.content.add_child(back)
	back.setup(Assets.MODE_PLAYERS_BACK, "VOLVER", Vector2(180, 64))
	Layout.apply_frac(back, 0.06, 0.80, 0.18, 0.09)
	back.pressed.connect(request_back)

	_continue = ImageButton.new()
	frame.content.add_child(_continue)
	_continue.setup(Assets.MODE_PLAYERS_CONTINUE, "CONTINUAR", Vector2(220, 64))
	Layout.apply_frac(_continue, 0.28, 0.80, 0.22, 0.09)
	_continue.pressed.connect(_confirm)

	_rebuild()
	call_deferred("_focus_continue")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_match") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		request_back()
		get_viewport().set_input_as_handled()
		return


func _focus_continue() -> void:
	if _continue != null:
		_continue.grab_focus()


func _limits() -> Vector2i:
	var mode = JeffreyCore.modes.get_mode(mode_id)
	if mode == null:
		return Vector2i(1, 1)
	var min_p: int = mode.min_players
	var max_p: int = mode.max_players
	if mode_id == ModeRegistry.MODE_SMASH:
		min_p = JeffreyCore.SMASH_ADAPTER_PLAYERS
		max_p = JeffreyCore.SMASH_ADAPTER_PLAYERS
	return Vector2i(min_p, max_p)


func _rebuild() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()
	var ids: Array = JeffreyCore.session.active_player_ids
	_grid.columns = 1
	if ids.is_empty():
		_grid.add_child(Layout.outlined_label("No hay jugadores activos. Volvé a Editar.", Styles.SIZE_HELPER, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		_refresh()
		return
	var limits := _limits()
	var auto_on := 0
	var restore: bool = not preselected_ids.is_empty()
	for profile_id in ids:
		var profile = JeffreyCore.profiles.get_profile(profile_id)
		if profile == null:
			continue
		var card = PlayerCard.new()
		card.layout_kind = PlayerCard.LAYOUT_BANNER
		card.selected_art_path = Assets.MODE_PLAYER_CARD_SELECTED
		card.unselected_art_path = Assets.MODE_PLAYER_CARD
		_grid.add_child(card)
		var start_on: bool
		if restore:
			start_on = preselected_ids.has(profile.profile_id)
		else:
			start_on = auto_on < limits.y
		card.setup(profile.profile_id, profile.display_name, start_on, profile.portrait_path)
		if start_on:
			auto_on += 1
		if mode_id == ModeRegistry.MODE_SMASH and start_on and auto_on <= 2:
			card.set_slot_caption("Teclado %d" % auto_on)
		card.card_toggled.connect(func(_id, _on): _refresh())
		_cards[profile.profile_id] = card
	_refresh()


func _selected() -> Array[String]:
	## Card toggle state is the single authority — not a parallel sidebar list.
	var selected: Array[String] = []
	for profile_id in _cards.keys():
		var card = _cards[profile_id]
		if card != null and is_instance_valid(card) and card.button_pressed:
			selected.append(str(profile_id))
	return selected


func _refresh() -> void:
	var selected := _selected()
	var limits := _limits()
	if _count != null:
		_count.text = "%d SELECCIONADOS" % selected.size()
	var valid: bool = selected.size() >= limits.x and selected.size() <= limits.y
	if _continue != null:
		_continue.set_art_enabled(valid)
	if valid and _error != null:
		_error.text = ""
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	var smash: bool = mode_id == ModeRegistry.MODE_SMASH
	var color_i := 0
	for profile_id in selected:
		var profile = JeffreyCore.profiles.get_profile(profile_id)
		if profile == null:
			continue
		var row = RowScript.new()
		_list.add_child(row)
		row.setup(profile.display_name, ThemeRef.slot_color(color_i))
		if smash and color_i < 2 and _cards.has(profile_id):
			_cards[profile_id].set_slot_caption("Teclado %d" % (color_i + 1))
		elif _cards.has(profile_id):
			_cards[profile_id].set_slot_caption("")
		color_i += 1


func _confirm() -> void:
	var selected := _selected()
	var limits := _limits()
	if selected.size() < limits.x:
		_error.text = "Necesitás al menos %d jugadores." % limits.x
		return
	if selected.size() > limits.y:
		_error.text = "Este modo admite como máximo %d." % limits.y
		return
	_error.text = ""
	AudioHooks.play_confirm(self)
	print("[MODE] Participants: %s" % str(selected.size()))
	players_confirmed.emit(selected)
