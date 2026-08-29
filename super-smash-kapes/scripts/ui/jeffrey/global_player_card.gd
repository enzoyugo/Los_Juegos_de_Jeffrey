class_name GlobalPlayerCard
extends Button

## Reusable profile card. Name lives in NamePlate on the visible art, not the letterbox.

const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")

const LAYOUT_PORTRAIT := "portrait"
const LAYOUT_BANNER := "banner"

signal card_toggled(profile_id: String, selected: bool)

var profile_id: String = ""
var display_name: String = ""
var portrait_path: String = ""
var slot_caption: String = ""
var layout_kind: String = LAYOUT_PORTRAIT
var selected_art_path: String = Assets.PLAYER_CARD_SELECTED
var unselected_art_path: String = Assets.PLAYER_CARD_UNSELECTED
var _frame: TextureRect
var _portrait: TextureRect
var _name_label: Label
var _slot_label: Label
var _check: Label
var _focus_pulse: ColorRect
var _selected_tex: Texture2D
var _unselected_tex: Texture2D
var _art_root: Control


func _ready() -> void:
	toggle_mode = true
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_min_size()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_color_override("font_color", Color(0, 0, 0, 0))
	toggled.connect(_on_toggled)
	focus_entered.connect(func():
		AudioHooks.play_focus(self)
		_refresh_focus()
	)
	focus_exited.connect(_refresh_focus)
	resized.connect(func(): pivot_offset = size * 0.5)
	_build()
	_refresh_frame()
	_refresh_focus()


func setup(id: String, name_text: String, selected: bool, portrait: String = "") -> void:
	profile_id = id
	display_name = name_text
	portrait_path = portrait
	set_pressed_no_signal(selected)
	if _name_label != null:
		_name_label.text = display_name.to_upper()
		_apply_portrait()
		_refresh_frame()


func set_slot_caption(caption: String) -> void:
	slot_caption = caption
	if _slot_label != null:
		_slot_label.text = caption
		_slot_label.visible = not caption.is_empty()


func _apply_min_size() -> void:
	if layout_kind == LAYOUT_BANNER:
		custom_minimum_size = Vector2(420, 168)
	else:
		custom_minimum_size = Vector2(176, 220)


func _build() -> void:
	_selected_tex = Assets.texture(selected_art_path)
	_unselected_tex = Assets.texture(unselected_art_path)
	var ratio := Styles.BANNER_RATIO if layout_kind == LAYOUT_BANNER else Styles.PORTRAIT_RATIO
	var box := AspectRatioContainer.new()
	box.name = "CardAspect"
	box.ratio = ratio
	box.stretch_mode = AspectRatioContainer.STRETCH_FIT
	Layout.bind_full(box)
	add_child(box)
	_art_root = Control.new()
	_art_root.name = "ArtRoot"
	_art_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_root.clip_contents = true
	_art_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_art_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_art_root)

	_frame = TextureRect.new()
	_frame.name = "SelectedFrame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	Layout.bind_full(_frame)
	_art_root.add_child(_frame)

	_portrait = TextureRect.new()
	_portrait.name = "PortraitArea"
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.visible = false
	_art_root.add_child(_portrait)
	if layout_kind == LAYOUT_BANNER:
		Styles.bind_banner_portrait(_portrait)
	else:
		Styles.bind_portrait(_portrait)

	var plate := Control.new()
	plate.name = "NamePlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.clip_contents = true
	_art_root.add_child(plate)
	if layout_kind == LAYOUT_BANNER:
		Styles.bind_banner_nameplate(plate)
	else:
		Styles.bind_nameplate(plate)
	_name_label = Styles.name_label(display_name)
	_name_label.name = "NameLabel"
	Layout.bind_full(_name_label)
	plate.add_child(_name_label)

	_check = Layout.outlined_label("✓", 18, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_check.name = "CheckIndicator"
	_check.visible = false
	_art_root.add_child(_check)
	if layout_kind == LAYOUT_BANNER:
		Styles.bind_banner_check(_check)
	else:
		Layout.bind_frac_rect(_check, 0.72, 0.06, 0.94, 0.16)

	_slot_label = Layout.outlined_label("", 12, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_slot_label.visible = false
	_art_root.add_child(_slot_label)
	if layout_kind == LAYOUT_BANNER:
		Styles.bind_banner_status(_slot_label)
	else:
		Layout.bind_frac_rect(_slot_label, 0.18, 0.70, 0.82, 0.78)

	_focus_pulse = ColorRect.new()
	_focus_pulse.name = "FocusFrame"
	_focus_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_pulse.color = Color(1, 1, 1, 0)
	Layout.bind_full(_focus_pulse)
	_art_root.add_child(_focus_pulse)


func _apply_portrait() -> void:
	if _portrait == null:
		return
	var tex := Assets.texture(portrait_path) if not portrait_path.is_empty() else null
	_portrait.texture = tex
	_portrait.visible = tex != null


func _on_toggled(_on: bool) -> void:
	AudioHooks.play_select(self)
	_refresh_frame()
	card_toggled.emit(profile_id, button_pressed)


func _refresh_frame() -> void:
	if _frame == null:
		return
	_frame.texture = _selected_tex if button_pressed and _selected_tex != null else _unselected_tex
	if _frame.texture == null:
		_frame.modulate = ThemeRef.GOLD if button_pressed else ThemeRef.SURFACE
	if _check != null:
		# Selected portrait art already paints a check badge. Banner uses the empty gold circle.
		_check.visible = button_pressed and layout_kind == LAYOUT_BANNER
	if _art_root != null:
		_art_root.scale = Vector2(1.02, 1.02) if button_pressed else Vector2.ONE
		_art_root.pivot_offset = _art_root.size * 0.5


func _refresh_focus() -> void:
	if _focus_pulse == null:
		return
	_focus_pulse.color = Color(1, 1, 1, 0.14) if has_focus() else Color(0, 0, 0, 0)
	if _art_root == null:
		return
	if has_focus() and not button_pressed:
		_art_root.scale = Vector2(1.015, 1.015)
	elif not button_pressed:
		_art_root.scale = Vector2.ONE
	_art_root.pivot_offset = _art_root.size * 0.5
