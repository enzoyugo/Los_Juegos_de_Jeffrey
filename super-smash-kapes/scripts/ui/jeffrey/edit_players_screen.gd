class_name JeffreyEditPlayersScreen
extends Control

signal saved(selected_ids: Array)
signal cancelled

const Frame := preload("res://scripts/ui/jeffrey/global_screen_frame.gd")
const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const ImageButton := preload("res://scripts/ui/jeffrey/global_image_button.gd")
const GoldButton := preload("res://scripts/ui/jeffrey/gold_action_button.gd")
const CardScript := preload("res://scripts/ui/jeffrey/edit_player_card.gd")
const ModalScript := preload("res://scripts/ui/jeffrey/create_player_modal.gd")
const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")

var _grid: GridContainer
var _cards: Dictionary = {}
var _info_name: Label
var _info_created: Label
var _info_active: Label
var _info_sessions: Label
var _modal: Control
var _add: Button
var _focused_id: String = ""


func _ready() -> void:
	set_process_unhandled_input(true)
	Layout.bind_full(self)
	var frame = Frame.new()
	add_child(frame)
	frame.configure(Assets.EDIT_BACKGROUND, "", 0.35, Assets.EDIT_CONTROLS)

	var title := TextureRect.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.texture = Assets.texture(Assets.EDIT_TITLE)
	frame.content.add_child(title)
	Layout.apply_frac(title, 0.04, 0.02, 0.58, 0.14)
	if title.texture == null:
		var fallback := Layout.outlined_label("EDITAR JUGADORES", 36, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		frame.content.add_child(fallback)
		Layout.apply_frac(fallback, 0.04, 0.03, 0.5, 0.1)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.content.add_child(scroll)
	Layout.apply_frac(scroll, 0.03, 0.17, 0.64, 0.60)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	var FitHost := preload("res://scripts/ui/jeffrey/texture_fit_host.gd")
	var panel = FitHost.new()
	frame.content.add_child(panel)
	Layout.apply_frac(panel, 0.68, 0.16, 0.29, 0.54)
	panel.set_texture(Assets.texture(Assets.EDIT_PANEL))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	var info_margin := MarginContainer.new()
	Layout.bind_full(info_margin)
	info_margin.add_theme_constant_override("margin_left", 24)
	info_margin.add_theme_constant_override("margin_right", 24)
	info_margin.add_theme_constant_override("margin_top", 36)
	info_margin.add_theme_constant_override("margin_bottom", 28)
	panel.art_space.add_child(info_margin)
	info_margin.add_child(info)
	var info_title := Layout.outlined_label("PERFIL", Styles.SIZE_PANEL_TITLE, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	Styles.apply(info_title, "panel_title")
	info.add_child(info_title)
	_info_name = Layout.outlined_label("—", Styles.SIZE_PROFILE, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	Styles.apply(_info_name, "profile")
	_info_name.clip_text = true
	_info_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(_info_name)
	_info_created = Layout.outlined_label("Creado: —", Styles.SIZE_HELPER, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	Styles.apply(_info_created, "small_helper")
	info.add_child(_info_created)
	_info_active = Layout.outlined_label("Hoy: —", Styles.SIZE_HELPER, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	Styles.apply(_info_active, "status")
	info.add_child(_info_active)
	_info_sessions = Layout.outlined_label("Sesiones: —", Styles.SIZE_HELPER, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	Styles.apply(_info_sessions, "small_helper")
	info.add_child(_info_sessions)
	var note := Layout.outlined_label("Los perfiles no se borran.", Styles.SIZE_HELPER, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	Styles.apply(note, "small_helper")
	info.add_child(note)

	_add = ImageButton.new()
	frame.content.add_child(_add)
	_add.setup(Assets.EDIT_ADD, "NUEVO JUGADOR", Vector2(200, 72))
	Layout.apply_frac(_add, 0.70, 0.62, 0.24, 0.10)
	_add.pressed.connect(_open_modal)

	var back = GoldButton.new()
	back.configure("VOLVER", Vector2(180, 52))
	frame.content.add_child(back)
	Layout.apply_frac(back, 0.06, 0.80, 0.16, 0.08)
	back.pressed.connect(func():
		AudioHooks.play_back(self)
		cancelled.emit()
	)
	var save = GoldButton.new()
	save.configure("GUARDAR", Vector2(200, 52))
	frame.content.add_child(save)
	Layout.apply_frac(save, 0.26, 0.80, 0.18, 0.08)
	save.pressed.connect(_save)

	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if _modal != null:
		return
	if event.is_action_pressed("pause_match"):
		cancelled.emit()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()
	for profile in JeffreyCore.profiles.get_all():
		var card = CardScript.new()
		_grid.add_child(card)
		card.setup(profile.profile_id, profile.display_name, JeffreyCore.session.has_player(profile.profile_id), profile.portrait_path)
		card.focused.connect(_show_profile)
		card.card_toggled.connect(func(id, _on): _show_profile(id))
		_cards[profile.profile_id] = card
		if _focused_id.is_empty():
			_show_profile(profile.profile_id)


func _selected_ids() -> Array[String]:
	var selected: Array[String] = []
	for profile_id in _cards.keys():
		if _cards[profile_id].button_pressed:
			selected.append(profile_id)
	return selected


func _show_profile(profile_id: String) -> void:
	_focused_id = profile_id
	var profile = JeffreyCore.profiles.get_profile(profile_id)
	if profile == null:
		return
	if _info_name != null:
		_info_name.text = profile.display_name.to_upper()
	if _info_created != null:
		var dt: Dictionary = Time.get_datetime_dict_from_unix_time(int(profile.created_at))
		_info_created.text = "Creado: %02d/%02d/%d" % [int(dt.get("day", 0)), int(dt.get("month", 0)), int(dt.get("year", 0))]
	if _info_active != null:
		var on: bool = _cards.has(profile_id) and _cards[profile_id].button_pressed
		_info_active.text = "Hoy: ACTIVO" if on else "Hoy: INACTIVO"
	if _info_sessions != null:
		_info_sessions.text = "Sesiones: %d" % profile.sessions_played


func _save() -> void:
	AudioHooks.play_confirm(self)
	saved.emit(_selected_ids())


func _open_modal() -> void:
	if _modal != null:
		return
	_modal = ModalScript.new()
	add_child(_modal)
	_modal.created.connect(_on_created)
	_modal.cancelled.connect(func():
		if _modal != null:
			_modal.queue_free()
		_modal = null
	)


func _on_created(display_name: String) -> void:
	var created = JeffreyCore.profiles.create(display_name)
	if created == null:
		if _modal != null:
			_modal.set_error("Ya existe un jugador con ese nombre." if JeffreyCore.profiles.last_error == "duplicate" else "Escribí un nombre.")
		return
	JeffreyCore.session.add_player(created.profile_id)
	JeffreyCore.save()
	if _modal != null:
		_modal.queue_free()
	_modal = null
	_rebuild()
