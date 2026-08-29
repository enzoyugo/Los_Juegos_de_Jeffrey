class_name JeffreyTrackMenuScreen
extends Control

## Canonical Track configuration menu (procedural race — no track picker).

signal start_pressed(length_id: String, difficulty_id: String)
signal back_pressed

const Assets := preload("res://scripts/ui/jeffrey/track_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")
const InputHint := preload("res://scripts/ui/jeffrey/components/jeffrey_input_hint.gd")
const Config := preload("res://scripts/track/track_config.gd")

var participants: Array = []
var length_id: String = Config.LENGTH_MEDIA
var difficulty_id: String = Config.DIFF_PICANTE

var _length_btns: Array[Button] = []
var _diff_btns: Array[Button] = []
var _start_btn: Button
var _back_btn: Button
var _focus_group: Array[Control] = []
var _focus_index: int = 0
var _player_slots: Array[Control] = []


func configure(roster: Array) -> void:
	participants = roster.duplicate(true)


func request_back() -> void:
	AudioHooks.play_back(self)
	back_pressed.emit()


func _ready() -> void:
	name = "TrackMenu"
	set_process_unhandled_input(true)
	Layout.bind_full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	call_deferred("_grab_initial_focus")


func _build() -> void:
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.texture = Assets.texture(Assets.BG)
	Layout.bind_full(bg)
	add_child(bg)

	var shade := ColorRect.new()
	shade.name = "LeftShade"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.02, 0.02, 0.06, 0.55)
	Layout.apply_frac(shade, 0.0, 0.0, 0.42, 1.0)
	add_child(shade)

	var col := Control.new()
	col.name = "ConfigColumn"
	add_child(col)
	Layout.apply_frac(col, 0.02, 0.04, 0.36, 0.92)

	var header := TextureRect.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	header.texture = Assets.texture(Assets.HEADER)
	col.add_child(header)
	Layout.apply_frac(header, 0.0, 0.0, 1.0, 0.16)

	_build_players_block(col)
	_build_length_block(col)
	_build_difficulty_block(col)
	_build_actions(col)

	var hint := TextureRect.new()
	hint.name = "ControlsHint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	hint.texture = Assets.texture(Assets.HINTS)
	add_child(hint)
	Layout.apply_frac(hint, 0.62, 0.88, 0.36, 0.10)

	_rebuild_focus_group()
	_refresh_selector_styles()


func _build_players_block(col: Control) -> void:
	var panel := TextureRect.new()
	panel.name = "PlayersPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	panel.texture = Assets.texture(Assets.PLAYERS_PANEL)
	col.add_child(panel)
	Layout.apply_frac(panel, 0.0, 0.18, 1.0, 0.22)

	## Dynamic overlay covering baked demo slots.
	var overlay := HBoxContainer.new()
	overlay.name = "PlayersOverlay"
	overlay.add_theme_constant_override("separation", 6)
	panel.add_child(overlay)
	Layout.apply_frac(overlay, 0.04, 0.28, 0.92, 0.62)

	var max_slots := 4
	for i in max_slots:
		var slot := _make_player_slot(i)
		overlay.add_child(slot)
		_player_slots.append(slot)
	_refresh_players()


func _make_player_slot(index: int) -> Control:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	style.border_color = Color(0.35, 0.2, 0.55, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", style)
	box.set_meta("slot_style", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)

	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(42, 42)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(portrait)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)

	var tag := Label.new()
	tag.name = "Tag"
	tag.text = "J%d" % (index + 1)
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Assets.ACCENT)
	text_col.add_child(tag)

	var name_l := Label.new()
	name_l.name = "Name"
	name_l.text = "—"
	name_l.add_theme_font_size_override("font_size", 14)
	name_l.add_theme_color_override("font_color", Color.WHITE)
	text_col.add_child(name_l)

	var car_l := Label.new()
	car_l.name = "Car"
	car_l.text = ""
	car_l.add_theme_font_size_override("font_size", 11)
	car_l.add_theme_color_override("font_color", Assets.GOLD)
	text_col.add_child(car_l)
	return box


func _refresh_players() -> void:
	for i in _player_slots.size():
		var slot: Control = _player_slots[i]
		var style: StyleBoxFlat = slot.get_meta("slot_style")
		var name_l: Label = slot.find_child("Name", true, false)
		var car_l: Label = slot.find_child("Car", true, false)
		var portrait: TextureRect = slot.find_child("Portrait", true, false)
		if i >= participants.size():
			style.border_color = Color(0.25, 0.2, 0.35, 0.55)
			name_l.text = "VACÍO"
			car_l.text = ""
			portrait.texture = null
			portrait.modulate = Color(0.4, 0.4, 0.45, 0.6)
			continue
		var row: Dictionary = participants[i]
		var profile_id := str(row.get("profile_id", ""))
		var character_id := str(row.get("character_id", ""))
		var profile = JeffreyCore.profiles.get_profile(profile_id) if JeffreyCore != null else null
		var display: String = str(profile.display_name) if profile != null else profile_id
		var accent: Color = _slot_color(i)
		style.border_color = accent
		name_l.text = display.to_upper()
		car_l.text = _character_label(character_id)
		portrait.modulate = Color.WHITE
		portrait.texture = _portrait_for(character_id, profile_id)


func _slot_color(i: int) -> Color:
	var colors := [Color("#e53935"), Color("#43a047"), Color("#8e24aa"), Color("#546e7a")]
	return colors[i % colors.size()]


func _character_label(character_id: String) -> String:
	if character_id.is_empty():
		return ""
	if JeffreyCore != null and JeffreyCore.characters != null:
		var def = JeffreyCore.characters.get_character(character_id)
		if def != null:
			return str(def.display_name).to_upper()
	return character_id.to_upper()


func _portrait_for(character_id: String, _profile_id: String) -> Texture2D:
	if character_id.is_empty():
		return null
	if JeffreyCore != null and JeffreyCore.characters != null:
		var def = JeffreyCore.characters.get_character(character_id)
		if def != null and def.portrait_texture != null:
			return def.portrait_texture
	var path := "res://assets/ui/portraits/%s_portrait.png" % character_id
	return Assets.texture(path)


func _build_length_block(col: Control) -> void:
	var panel := TextureRect.new()
	panel.name = "LengthPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	panel.texture = Assets.texture(Assets.LENGTH_SELECTOR)
	col.add_child(panel)
	Layout.apply_frac(panel, 0.0, 0.42, 1.0, 0.16)
	_length_btns = _overlay_choice_row(panel, Assets.LENGTH_IDS, Assets.LENGTH_LABELS, true)


func _build_difficulty_block(col: Control) -> void:
	var panel := TextureRect.new()
	panel.name = "DifficultyPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	panel.texture = Assets.texture(Assets.DIFFICULTY_SELECTOR)
	col.add_child(panel)
	Layout.apply_frac(panel, 0.0, 0.60, 1.0, 0.16)
	_diff_btns = _overlay_choice_row(panel, Assets.DIFF_IDS, Assets.DIFF_LABELS, false)


func _overlay_choice_row(panel: Control, ids: Array, labels: Array, is_length: bool) -> Array[Button]:
	var row := HBoxContainer.new()
	row.name = "Choices"
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	Layout.apply_frac(row, 0.06, 0.42, 0.88, 0.45)
	var out: Array[Button] = []
	for i in ids.size():
		var btn := Button.new()
		btn.text = str(labels[i])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_ALL
		btn.set_meta("choice_id", str(ids[i]))
		btn.pressed.connect(func():
			AudioHooks.play_select(self)
			if is_length:
				length_id = str(ids[i])
			else:
				difficulty_id = str(ids[i])
			_refresh_selector_styles()
		)
		btn.focus_entered.connect(func():
			AudioHooks.play_focus(self)
			_focus_index = _focus_group.find(btn)
		)
		row.add_child(btn)
		out.append(btn)
	return out


func _build_actions(col: Control) -> void:
	_start_btn = _texture_action_button("Start", Assets.BTN_START)
	col.add_child(_start_btn)
	Layout.apply_frac(_start_btn, 0.0, 0.78, 1.0, 0.10)
	_start_btn.pressed.connect(_on_start)

	_back_btn = _texture_action_button("Back", Assets.BTN_BACK)
	col.add_child(_back_btn)
	Layout.apply_frac(_back_btn, 0.0, 0.90, 0.55, 0.08)
	_back_btn.pressed.connect(_on_back)


func _texture_action_button(btn_name: String, path: String) -> Button:
	var btn := Button.new()
	btn.name = btn_name
	btn.focus_mode = Control.FOCUS_ALL
	btn.flat = true
	var tex := Assets.texture(path)
	if tex != null:
		btn.icon = tex
		btn.expand_icon = true
		btn.text = ""
	else:
		btn.text = btn_name
	btn.focus_entered.connect(func():
		AudioHooks.play_focus(self)
		_focus_index = _focus_group.find(btn)
	)
	return btn


func _rebuild_focus_group() -> void:
	_focus_group.clear()
	for b in _length_btns:
		_focus_group.append(b)
	for b in _diff_btns:
		_focus_group.append(b)
	if _start_btn:
		_focus_group.append(_start_btn)
	if _back_btn:
		_focus_group.append(_back_btn)
	for i in _focus_group.size():
		var cur: Control = _focus_group[i]
		var prev: Control = _focus_group[i - 1] if i > 0 else _focus_group[_focus_group.size() - 1]
		var next: Control = _focus_group[i + 1] if i < _focus_group.size() - 1 else _focus_group[0]
		cur.focus_neighbor_top = cur.get_path_to(prev)
		cur.focus_neighbor_bottom = cur.get_path_to(next)
		cur.focus_neighbor_left = cur.get_path_to(prev)
		cur.focus_neighbor_right = cur.get_path_to(next)


func _refresh_selector_styles() -> void:
	_style_choice_buttons(_length_btns, length_id)
	_style_choice_buttons(_diff_btns, difficulty_id)


func _style_choice_buttons(buttons: Array[Button], selected_id: String) -> void:
	for btn in buttons:
		var id := str(btn.get_meta("choice_id"))
		var on := id == selected_id
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.95, 0.75, 0.2, 0.95) if on else Color(0.08, 0.08, 0.1, 0.75)
		normal.border_color = Assets.GOLD if on else Color(0.7, 0.7, 0.75, 0.55)
		normal.set_border_width_all(2)
		normal.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", normal)
		btn.add_theme_stylebox_override("focus", normal)
		btn.add_theme_stylebox_override("pressed", normal)
		btn.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05) if on else Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.05) if on else Color.WHITE)
		btn.add_theme_color_override("font_focus_color", Color(0.05, 0.05, 0.05) if on else Color.WHITE)


func _grab_initial_focus() -> void:
	_refresh_players()
	## Focus Start as primary CTA after selectors exist.
	if _start_btn:
		_focus_index = _focus_group.find(_start_btn)
		_start_btn.grab_focus()
	elif not _focus_group.is_empty():
		_focus_group[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_match") or event.is_action_pressed("ui_cancel") or _is_escape(event):
		_on_back()
		get_viewport().set_input_as_handled()
		return
	if _is_accept(event):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button:
			(focused as Button).emit_signal("pressed")
		get_viewport().set_input_as_handled()


func _on_start() -> void:
	AudioHooks.play_confirm(self)
	AudioHooks.play_track_whoosh(self)
	start_pressed.emit(length_id, difficulty_id)


func _on_back() -> void:
	request_back()


func _is_escape(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE


func _is_accept(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):
		return true
	return event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]
