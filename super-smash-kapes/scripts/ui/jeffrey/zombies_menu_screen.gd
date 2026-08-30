class_name JeffreyZombiesMenuScreen
extends Control

## Presentation-only Zombies mode menu. Does not change gameplay.

signal play_pressed
signal characters_pressed
signal map_pressed
signal options_pressed
signal back_pressed

const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const Typography := preload("res://scripts/ui/jeffrey/system/jeffrey_typography.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")
const ZAssets := preload("res://scripts/ui/jeffrey/zombies_ui_assets.gd")
const ZombiesBtn := preload("res://scripts/ui/jeffrey/zombies_menu_button.gd")

var _buttons: Array[Button] = []
var _selected: int = 0
var _map_note: Label


func request_back() -> void:
	AudioHooks.play_back(self)
	back_pressed.emit()


func _ready() -> void:
	name = "ZombiesMenu"
	set_process_unhandled_input(true)
	Layout.bind_full(self)
	theme = Typography.theme_for(Typography.ZOMBIES)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	call_deferred("_focus_play")


func _build() -> void:
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.texture = Assets.texture(ZAssets.MENU_BG)
	Layout.bind_full(bg)
	add_child(bg)

	var shade := TextureRect.new()
	shade.name = "LeftShade"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.texture = _left_shade()
	Layout.apply_frac(shade, 0.0, 0.0, 0.28, 1.0)
	add_child(shade)

	var safe := Control.new()
	safe.name = "SafeArea"
	add_child(safe)
	## Left column only so Shopping, the horde, and EL GALLO stay visible.
	Layout.apply_frac(safe, 0.031, 0.051, 0.32, 0.90)

	var title := TextureRect.new()
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	title.texture = Assets.texture(ZAssets.TITLE)
	safe.add_child(title)
	Layout.apply_frac(title, 0.0, 0.0, 1.0, 0.36)

	var stack := VBoxContainer.new()
	stack.name = "MenuButtons"
	stack.add_theme_constant_override("separation", 2)
	safe.add_child(stack)
	Layout.apply_frac(stack, 0.02, 0.39, 0.92, 0.58)

	var specs := [
		["Play", ZAssets.BTN_PLAY, "_on_play"],
		["Characters", ZAssets.BTN_CHARACTERS, "_on_characters"],
		["Map", ZAssets.BTN_MAP, "_on_map"],
		["Options", ZAssets.BTN_OPTIONS, "_on_options"],
		["Back", ZAssets.BTN_BACK, "_on_back"],
	]
	for spec in specs:
		var btn = ZombiesBtn.new()
		btn.name = str(spec[0])
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(btn)
		btn.setup(str(spec[1]))
		btn.pressed.connect(Callable(self, str(spec[2])))
		btn.focus_entered.connect(func():
			var found := _buttons.find(btn)
			if found >= 0:
				_selected = found
		)
		_buttons.append(btn)

	for i in _buttons.size():
		var prev: Control = _buttons[i - 1] if i > 0 else _buttons[_buttons.size() - 1]
		var next: Control = _buttons[i + 1] if i < _buttons.size() - 1 else _buttons[0]
		_buttons[i].focus_neighbor_top = _buttons[i].get_path_to(prev)
		_buttons[i].focus_neighbor_bottom = _buttons[i].get_path_to(next)
		_buttons[i].focus_neighbor_left = _buttons[i].get_path_to(_buttons[i])
		_buttons[i].focus_neighbor_right = _buttons[i].get_path_to(_buttons[i])

	_map_note = Layout.outlined_label("", 15, ZAssets.SLIME, HORIZONTAL_ALIGNMENT_LEFT)
	_map_note.name = "MapNote"
	_map_note.visible = false
	safe.add_child(_map_note)
	Layout.apply_frac(_map_note, 0.02, 0.96, 1.0, 0.04)

	var focus_host := Node.new()
	focus_host.name = "FocusController"
	add_child(focus_host)


func _left_shade() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0, 0, 0, 0.28),
		Color(0, 0, 0, 0.10),
		Color(0, 0, 0, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 8
	tex.fill_from = Vector2(0, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	return tex


func _focus_play() -> void:
	if _buttons.is_empty():
		return
	_selected = 0
	_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_match") or event.is_action_pressed("ui_cancel") or _is_escape(event):
		_on_back()
		get_viewport().set_input_as_handled()
		return
	if _is_accept(event):
		if _selected >= 0 and _selected < _buttons.size():
			_buttons[_selected].pressed.emit()
		get_viewport().set_input_as_handled()
		return
	var dir := 0
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_W):
		dir = -1
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S):
		dir = 1
	if dir != 0 and not _buttons.is_empty():
		_selected = posmod(_selected + dir, _buttons.size())
		_buttons[_selected].grab_focus()
		get_viewport().set_input_as_handled()


func _is_accept(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_A
	return false


func _is_escape(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE


func _on_play() -> void:
	AudioHooks.play_confirm(self)
	play_pressed.emit()


func _on_characters() -> void:
	AudioHooks.play_confirm(self)
	characters_pressed.emit()


func _on_map() -> void:
	AudioHooks.play_confirm(self)
	if _map_note != null:
		_map_note.text = ZAssets.MAP_COPY
		_map_note.visible = true
	map_pressed.emit()


func _on_options() -> void:
	AudioHooks.play_confirm(self)
	options_pressed.emit()


func _on_back() -> void:
	request_back()
