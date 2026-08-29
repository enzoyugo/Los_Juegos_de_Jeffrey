class_name EditPlayerCard
extends Button

const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")

signal card_toggled(profile_id: String, selected: bool)
signal focused(profile_id: String)

var profile_id: String = ""
var display_name: String = ""
var _frame: TextureRect
var _portrait: TextureRect
var _name_label: Label
var _status_label: Label
var _active_tex: Texture2D
var _idle_tex: Texture2D
var _focus: ColorRect
var _art_root: Control


func _ready() -> void:
	toggle_mode = true
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(420, 168)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	toggled.connect(func(_on):
		AudioHooks.play_select(self)
		_refresh()
		card_toggled.emit(profile_id, button_pressed)
	)
	focus_entered.connect(func():
		AudioHooks.play_focus(self)
		_refresh()
		focused.emit(profile_id)
	)
	focus_exited.connect(_refresh)
	_build()
	_refresh()


func setup(id: String, name_text: String, active: bool, portrait_path: String = "") -> void:
	profile_id = id
	display_name = name_text
	set_pressed_no_signal(active)
	if _name_label != null:
		_name_label.text = display_name.to_upper()
	if _portrait != null:
		var tex := Assets.texture(portrait_path) if not portrait_path.is_empty() else null
		_portrait.texture = tex
		_portrait.visible = tex != null
	_refresh()


func _build() -> void:
	_active_tex = Assets.texture(Assets.EDIT_CARD_ACTIVE)
	_idle_tex = Assets.texture(Assets.EDIT_CARD)
	var box := AspectRatioContainer.new()
	box.ratio = Styles.BANNER_RATIO
	box.stretch_mode = AspectRatioContainer.STRETCH_FIT
	Layout.bind_full(box)
	add_child(box)
	_art_root = Control.new()
	_art_root.name = "ArtRoot"
	_art_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_root.clip_contents = true
	box.add_child(_art_root)
	_frame = TextureRect.new()
	_frame.name = "DecorativeFrame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	Layout.bind_full(_frame)
	_art_root.add_child(_frame)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.visible = false
	_art_root.add_child(_portrait)
	Styles.bind_banner_portrait(_portrait)
	var plate := Control.new()
	plate.name = "MainNameZone"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.clip_contents = true
	_art_root.add_child(plate)
	Styles.bind_banner_nameplate(plate)
	_name_label = Styles.name_label(display_name)
	_name_label.name = "NameLabel"
	Layout.bind_full(_name_label)
	plate.add_child(_name_label)
	_status_label = Layout.outlined_label("", Styles.SIZE_HELPER, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	_status_label.name = "ActiveStatus"
	Styles.apply(_status_label, "small_helper")
	_art_root.add_child(_status_label)
	Styles.bind_banner_status(_status_label)
	_focus = ColorRect.new()
	_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus.color = Color(1, 1, 1, 0)
	Layout.bind_full(_focus)
	_art_root.add_child(_focus)


func _refresh() -> void:
	if _frame != null:
		_frame.texture = _active_tex if button_pressed and _active_tex != null else _idle_tex
	if _status_label != null:
		_status_label.text = "HOY  ACTIVO" if button_pressed else "HOY  INACTIVO"
		_status_label.add_theme_color_override("font_color", ThemeRef.GOLD if button_pressed else ThemeRef.MUTED)
	if _focus != null:
		_focus.color = Color(1, 1, 1, 0.12) if has_focus() else Color(0, 0, 0, 0)
	if _art_root != null:
		_art_root.scale = Vector2(1.02, 1.02) if button_pressed else Vector2.ONE
		_art_root.pivot_offset = _art_root.size * 0.5
