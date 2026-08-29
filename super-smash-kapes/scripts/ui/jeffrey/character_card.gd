class_name CharacterCard
extends Button

const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")

signal character_picked(character_id: String)

var character_id: String = ""
var display_name: String = ""
var is_random: bool = false
var _frame: TextureRect
var _portrait: TextureRect
var _name_label: Label
var _focus: ColorRect
var _selected_tex: Texture2D
var _idle_tex: Texture2D
var _marked: bool = false
var _art_root: Control


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Styles.CHAR_CARD_MIN
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	pressed.connect(func():
		AudioHooks.play_select(self)
		character_picked.emit(character_id)
	)
	focus_entered.connect(func():
		AudioHooks.play_focus(self)
		_refresh()
	)
	focus_exited.connect(_refresh)
	_build()
	_refresh()


func setup(id: String, name_text: String, portrait: Texture2D = null, random: bool = false) -> void:
	character_id = id
	display_name = name_text
	is_random = random
	_idle_tex = Assets.texture(Assets.CHAR_RANDOM if is_random else Assets.CHAR_CARD)
	_selected_tex = Assets.texture(Assets.CHAR_CARD_SELECTED)
	if is_random:
		var random_tex := Assets.texture(Assets.CHAR_RANDOM)
		if random_tex != null:
			_idle_tex = random_tex
	if _name_label != null:
		_name_label.text = display_name.to_upper()
	if _portrait != null:
		_portrait.texture = _portrait_without_cream(portrait)
		_portrait.visible = portrait != null and not random
	_refresh()


func _portrait_without_cream(src: Texture2D) -> Texture2D:
	## Punch studio white/cream plates to alpha (Cartes/Fort/Jaguareté crops).
	if src == null:
		return null
	var img: Image = null
	var path := str(src.resource_path)
	if path.begins_with("res://") and path.ends_with(".png"):
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			img = Image.load_from_file(abs_path)
	if img == null:
		img = src.get_image()
	if img == null:
		return src
	img.convert(Image.FORMAT_RGBA8)
	var changed := false
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.05:
				continue
			var near_white := c.r > 0.90 and c.g > 0.90 and c.b > 0.90
			var cream := c.r > 0.88 and c.g > 0.82 and c.b > 0.78 and absf(c.r - c.g) < 0.12 and absf(c.g - c.b) < 0.14
			## Soft plate: high luminance, low saturation.
			var luma := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			var sat := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
			var soft_plate := luma > 0.86 and sat < 0.12
			if near_white or cream or soft_plate:
				c.a = 0.0
				img.set_pixel(x, y, c)
				changed = true
	if not changed:
		return src
	return ImageTexture.create_from_image(img)


func mark_selected(on: bool) -> void:
	_marked = on
	_refresh()


func _build() -> void:
	_idle_tex = Assets.texture(Assets.CHAR_RANDOM if is_random else Assets.CHAR_CARD)
	_selected_tex = Assets.texture(Assets.CHAR_CARD_SELECTED)
	if is_random:
		var random_tex := Assets.texture(Assets.CHAR_RANDOM)
		if random_tex != null:
			_idle_tex = random_tex
			_selected_tex = random_tex
	var box := AspectRatioContainer.new()
	box.ratio = Styles.PORTRAIT_RATIO
	box.stretch_mode = AspectRatioContainer.STRETCH_FIT
	Layout.bind_full(box)
	add_child(box)
	_art_root = Control.new()
	_art_root.name = "ArtRoot"
	_art_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_root.clip_contents = true
	box.add_child(_art_root)
	_frame = TextureRect.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	Layout.bind_full(_frame)
	_art_root.add_child(_frame)
	_portrait = TextureRect.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.visible = false
	_art_root.add_child(_portrait)
	Styles.bind_character_portrait(_portrait)
	var plate := Control.new()
	plate.name = "NamePlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.clip_contents = true
	_art_root.add_child(plate)
	Styles.bind_character_nameplate(plate)
	_name_label = Styles.name_label(display_name)
	_name_label.name = "NameLabel"
	Styles.apply(_name_label, "character")
	Layout.bind_full(_name_label)
	plate.add_child(_name_label)
	_focus = ColorRect.new()
	_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus.color = Color(0, 0, 0, 0)
	Layout.bind_full(_focus)
	_art_root.add_child(_focus)


func _refresh() -> void:
	if _frame != null:
		_frame.texture = _selected_tex if _marked and _selected_tex != null else _idle_tex
	if _focus != null:
		_focus.color = Color(1, 1, 1, 0.12) if has_focus() else Color(0, 0, 0, 0)
	if _art_root != null:
		_art_root.scale = Vector2(1.04, 1.04) if _marked or has_focus() else Vector2.ONE
		_art_root.pivot_offset = _art_root.size * 0.5
