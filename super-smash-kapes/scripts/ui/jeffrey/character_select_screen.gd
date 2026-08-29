class_name JeffreyCharacterSelectScreen
extends Control

signal roster_confirmed(participants: Array)
signal cancelled

const Frame := preload("res://scripts/ui/jeffrey/global_screen_frame.gd")
const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const ImageButton := preload("res://scripts/ui/jeffrey/global_image_button.gd")
const CardScript := preload("res://scripts/ui/jeffrey/character_card.gd")
const OrderRow := preload("res://scripts/ui/jeffrey/character_order_row.gd")
const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")

var mode_id: String = ""
var participants: Array = []
var _grid: HBoxContainer
var _cards: Dictionary = {}
var _panel_list: VBoxContainer
var _continue: Button
var _picker: int = 0
var _picks: Dictionary = {}
var _busy: bool = false


func request_back() -> void:
	if _busy:
		return
	AudioHooks.play_back(self)
	cancelled.emit()


func _ready() -> void:
	set_process_unhandled_input(true)
	Layout.bind_full(self)
	var frame = Frame.new()
	add_child(frame)
	frame.configure(Assets.CHAR_BACKGROUND, "", 0.34, Assets.CHAR_CONTROLS)

	var title := TextureRect.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.texture = Assets.texture(Assets.CHAR_TITLE)
	frame.content.add_child(title)
	Layout.apply_frac(title, 0.04, 0.02, 0.58, 0.14)
	if title.texture == null:
		var fallback := Layout.outlined_label("ELEGÍ TU KAPE", 36, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		frame.content.add_child(fallback)
		Layout.apply_frac(fallback, 0.04, 0.03, 0.5, 0.1)

	var cards_host := CenterContainer.new()
	frame.content.add_child(cards_host)
	Layout.apply_frac(cards_host, 0.01, 0.14, 0.68, 0.64)
	_grid = HBoxContainer.new()
	_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	_grid.add_theme_constant_override("separation", 36)
	cards_host.add_child(_grid)

	var FitHost := preload("res://scripts/ui/jeffrey/texture_fit_host.gd")
	var panel = FitHost.new()
	frame.content.add_child(panel)
	Layout.apply_frac(panel, 0.70, 0.12, 0.28, 0.66)
	panel.set_texture(Assets.texture(Assets.CHAR_PLAYERS_PANEL))
	var panel_box := VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 8)
	var panel_margin := MarginContainer.new()
	Layout.bind_full(panel_margin)
	panel_margin.add_theme_constant_override("margin_left", 22)
	panel_margin.add_theme_constant_override("margin_right", 22)
	panel_margin.add_theme_constant_override("margin_top", 88)
	panel_margin.add_theme_constant_override("margin_bottom", 36)
	panel.art_space.add_child(panel_margin)
	panel_margin.add_child(panel_box)
	var heading := Layout.outlined_label("TURNO", Styles.SIZE_PANEL_TITLE, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	Styles.apply(heading, "panel_title")
	panel_box.add_child(heading)
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_box.add_child(list_scroll)
	_panel_list = VBoxContainer.new()
	_panel_list.add_theme_constant_override("separation", 6)
	list_scroll.add_child(_panel_list)

	var back = ImageButton.new()
	frame.content.add_child(back)
	back.setup(Assets.CHAR_BACK, "VOLVER", Vector2(180, 64))
	Layout.apply_frac(back, 0.06, 0.80, 0.18, 0.09)
	back.pressed.connect(request_back)

	_continue = ImageButton.new()
	frame.content.add_child(_continue)
	_continue.setup(Assets.CHAR_CONTINUE, "CONTINUAR", Vector2(220, 64))
	Layout.apply_frac(_continue, 0.28, 0.80, 0.22, 0.09)
	_continue.pressed.connect(_confirm)

	var Hint := preload("res://scripts/ui/jeffrey/components/jeffrey_input_hint.gd")
	var hints := HBoxContainer.new()
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	hints.add_theme_constant_override("separation", 18)
	frame.content.add_child(hints)
	Layout.apply_frac(hints, 0.06, 0.91, 0.60, 0.05)
	hints.add_child(Hint.make("confirm", "Elegir", ThemeRef.GOLD))
	hints.add_child(Hint.make("back", "Volver", ThemeRef.MUTED))

	_build_cards()
	_refresh_panel()
	call_deferred("_focus_first_card")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_match") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		request_back()
		get_viewport().set_input_as_handled()


func _focus_first_card() -> void:
	for character_id in _cards.keys():
		var card = _cards[character_id]
		if card is Control:
			card.grab_focus()
			return


func _build_cards() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()
	var roster: Array = JeffreyCore.characters.get_enabled_characters()
	for character in roster:
		var card = CardScript.new()
		_grid.add_child(card)
		var portrait: Texture2D = character.portrait if character.portrait is Texture2D else null
		card.setup(character.character_id, character.display_name, portrait, false)
		card.character_picked.connect(_on_character_picked)
		_cards[character.character_id] = card
	var random_card = CardScript.new()
	random_card.is_random = true
	_grid.add_child(random_card)
	random_card.setup(Assets.RANDOM_CHARACTER_ID, "RANDOM", null, true)
	random_card.character_picked.connect(_on_character_picked)
	_cards[Assets.RANDOM_CHARACTER_ID] = random_card


func _current_profile_id() -> String:
	if _picker < 0 or _picker >= participants.size():
		return ""
	return str(participants[_picker].get("profile_id", ""))


func _on_character_picked(character_id: String) -> void:
	var profile_id := _current_profile_id()
	if profile_id.is_empty():
		return
	_picks[profile_id] = character_id
	_advance_picker()
	_refresh_panel()
	_refresh_cards()
	if _all_picked() and _continue != null:
		_continue.grab_focus()


func _advance_picker() -> void:
	if participants.is_empty():
		return
	for i in range(participants.size()):
		var next: int = (_picker + 1 + i) % participants.size()
		var pid := str(participants[next].get("profile_id", ""))
		if not _picks.has(pid):
			_picker = next
			return
	_picker = 0


func _all_picked() -> bool:
	if participants.is_empty():
		return false
	for row in participants:
		if not _picks.has(str(row.get("profile_id", ""))):
			return false
	return true


func _character_label(character_id: String) -> String:
	if character_id == Assets.RANDOM_CHARACTER_ID:
		return "RANDOM"
	var definition = JeffreyCore.characters.get_character(character_id)
	if definition == null:
		return "—"
	return str(definition.display_name).to_upper()


func _refresh_cards() -> void:
	var current_pick := str(_picks.get(_current_profile_id(), ""))
	for character_id in _cards.keys():
		_cards[character_id].mark_selected(character_id == current_pick)


func _refresh_panel() -> void:
	if _continue != null:
		_continue.set_art_enabled(_all_picked() and not _busy)
	if _panel_list == null:
		return
	for child in _panel_list.get_children():
		child.queue_free()
	var index := 0
	for row in participants:
		var profile_id := str(row.get("profile_id", ""))
		var slot: int = int(row.get("player_slot", index + 1))
		var profile = JeffreyCore.profiles.get_profile(profile_id)
		var person: String = profile.display_name.to_upper() if profile != null else profile_id
		var picked := str(_picks.get(profile_id, ""))
		var kape := _character_label(picked) if not picked.is_empty() else "…"
		var order_row = OrderRow.new()
		_panel_list.add_child(order_row)
		order_row.setup(slot, person, kape, index == _picker)
		index += 1


func _resolve(character_id: String) -> String:
	if character_id != Assets.RANDOM_CHARACTER_ID:
		return character_id
	return JeffreyCore.characters.pick_random_enabled()


func _confirm() -> void:
	if _busy or not _all_picked():
		return
	_busy = true
	if _continue != null:
		_continue.set_art_enabled(false)
	var payload: Array = []
	for row in participants:
		var profile_id := str(row.get("profile_id", ""))
		var slot: int = int(row.get("player_slot", payload.size() + 1))
		var resolved := _resolve(str(_picks.get(profile_id, "")))
		if resolved.is_empty():
			_busy = false
			if _continue != null:
				_continue.set_art_enabled(true)
			return
		var profile = JeffreyCore.profiles.get_profile(profile_id)
		var person: String = str(profile.display_name) if profile != null else profile_id
		print("[CHARACTER] %s -> %s" % [person, resolved])
		payload.append({
			"profile_id": profile_id,
			"player_slot": slot,
			"character_id": resolved,
		})
	AudioHooks.play_confirm(self)
	roster_confirmed.emit(payload)
