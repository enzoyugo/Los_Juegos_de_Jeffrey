class_name JeffreyHubScreen
extends Control

signal mode_chosen(mode_id: String)
signal edit_players_pressed
signal options_pressed

const Frame := preload("res://scripts/ui/jeffrey/global_screen_frame.gd")
const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const ImageButton := preload("res://scripts/ui/jeffrey/global_image_button.gd")
const ModeCard := preload("res://scripts/ui/jeffrey/mode_select_card.gd")
const ActivePanel := preload("res://scripts/ui/jeffrey/active_players_panel.gd")
const CopaPanel := preload("res://scripts/ui/jeffrey/copa_jeffrey_hub_panel.gd")
const GoldButton := preload("res://scripts/ui/jeffrey/gold_action_button.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")

signal scoreboard_pressed
signal nueva_copa_pressed

var _error: Label
var _mode_buttons: Array = []
var _mode_ids: Array[String] = []
var _selected_index: int = 0


func _ready() -> void:
	set_process_unhandled_input(true)
	Layout.bind_full(self)
	var frame = Frame.new()
	add_child(frame)
	frame.configure(Assets.HUB_BACKGROUND, "", 0.18, Assets.HUB_CONTROLS)

	var logo := TextureRect.new()
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture = Assets.texture(Assets.HUB_LOGO)
	frame.content.add_child(logo)
	Layout.apply_frac(logo, 0.025, 0.02, 0.36, 0.26)
	if logo.texture == null:
		var fallback := Layout.outlined_label("LOS JUEGOS DE JEFFREY", 32, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		frame.content.add_child(fallback)
		Layout.apply_frac(fallback, 0.03, 0.04, 0.34, 0.12)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	frame.content.add_child(stack)
	Layout.apply_frac(stack, 0.03, 0.28, 0.34, 0.50)
	# Visual SOCO / TRACK / ZOMBIES map to smash / racing / zombies via Assets.hub_mode_order().
	for mode_id in Assets.hub_mode_order():
		var mode = JeffreyCore.modes.get_mode(mode_id)
		var btn = ModeCard.new()
		stack.add_child(btn)
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var status := ""
		if mode != null:
			status = mode.status_label()
		btn.setup_mode(str(mode_id), str(Assets.MODE_ART.get(mode_id, "")), Assets.mode_fallback_label(mode_id), status)
		var captured := str(mode_id)
		btn.pressed.connect(func(): _activate(captured))
		btn.focus_entered.connect(func(): _on_mode_focused(captured))
		_mode_buttons.append(btn)
		_mode_ids.append(captured)

	var edit = ImageButton.new()
	frame.content.add_child(edit)
	edit.setup(Assets.EDIT_PLAYERS_BUTTON, "EDITAR JUGADORES", Vector2(280, 70))
	Layout.apply_frac(edit, 0.03, 0.80, 0.30, 0.08)
	edit.pressed.connect(func():
		AudioHooks.play_confirm(self)
		edit_players_pressed.emit()
	)

	var panel = ActivePanel.new()
	frame.content.add_child(panel)
	Layout.apply_frac(panel, 0.72, 0.28, 0.25, 0.60)

	var copa = CopaPanel.new()
	frame.content.add_child(copa)
	Layout.apply_frac(copa, 0.68, 0.04, 0.30, 0.22)
	copa.scoreboard_pressed.connect(func(): scoreboard_pressed.emit())
	copa.nueva_copa_pressed.connect(func(): nueva_copa_pressed.emit())
	# Roster shell: Assets.ACTIVE_PLAYERS_PANEL is owned by ActivePlayersPanel.

	_error = Layout.outlined_label("", 16, ThemeRef.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	frame.content.add_child(_error)
	Layout.apply_frac(_error, 0.22, 0.74, 0.46, 0.05)

	var options = GoldButton.new()
	options.configure("OPCIONES", Vector2(140, 40))
	frame.content.add_child(options)
	Layout.apply_frac(options, 0.86, 0.915, 0.12, 0.055)
	options.pressed.connect(func(): options_pressed.emit())

	call_deferred("_focus_selected")


func _focus_selected() -> void:
	if _selected_index >= 0 and _selected_index < _mode_buttons.size():
		_mode_buttons[_selected_index].grab_focus()


func _on_mode_focused(mode_id: String) -> void:
	var found := _mode_ids.find(mode_id)
	if found >= 0:
		_selected_index = found


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_match"):
		return
	if _is_enter(event):
		if _selected_index >= 0 and _selected_index < _mode_ids.size():
			_activate(_mode_ids[_selected_index])
		get_viewport().set_input_as_handled()
		return
	var dir := 0
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_W):
		dir = -1
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S):
		dir = 1
	if dir != 0 and not _mode_ids.is_empty():
		_selected_index = clampi(_selected_index + dir, 0, _mode_ids.size() - 1)
		_mode_buttons[_selected_index].grab_focus()
		AudioHooks.play_focus(self)
		get_viewport().set_input_as_handled()


func _is_enter(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER


func _activate(mode_id: String) -> void:
	var mode = JeffreyCore.modes.get_mode(mode_id)
	if mode == null:
		_error.text = "Ese modo no está registrado."
		return
	if mode.availability == "playable" and not ResourceLoader.exists(mode.scene_path):
		_error.text = "No se encontró la escena de %s." % Assets.mode_fallback_label(mode_id)
		push_error("[Jeffrey] missing mode scene: %s" % mode.scene_path)
		return
	_error.text = ""
	AudioHooks.play_confirm(self)
	print("[MODE] Selected: %s" % Assets.mode_fallback_label(mode_id))
	mode_chosen.emit(mode_id)
