class_name ShellModeCard
extends Button

const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const Assets := preload("res://scripts/ui/jeffrey/shell_assets.gd")
const BadgeScript := preload("res://scripts/ui/jeffrey/shell_status_badge.gd")

var mode_id: String = ""


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(240, 320)
	focus_entered.connect(_set_hot.bind(true))
	focus_exited.connect(_set_hot.bind(false))
	mouse_entered.connect(_set_hot.bind(true))
	mouse_exited.connect(func(): _set_hot(has_focus()))


func setup(mode) -> void:
	mode_id = str(mode.id)
	text = ""
	var box := StyleBoxFlat.new()
	box.bg_color = ThemeRef.SURFACE
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = ThemeRef.STROKE
	box.corner_radius_top_left = 14
	box.corner_radius_top_right = 14
	box.corner_radius_bottom_left = 14
	box.corner_radius_bottom_right = 14
	add_theme_stylebox_override("normal", box)
	var hover := box.duplicate() as StyleBoxFlat
	hover.border_color = mode.accent_color
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("focus", hover)
	add_theme_stylebox_override("pressed", hover)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_top = 18
	root.offset_right = -18
	root.offset_bottom = -18
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var art := ColorRect.new()
	var fill: Color = mode.accent_color
	fill.a = 0.35
	art.color = fill
	art.custom_minimum_size = Vector2(0, 150)
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(art)
	var thumb := TextureRect.new()
	thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := Assets.texture_or_null(mode.thumbnail_path)
	if tex == null:
		tex = Assets.mode_thumbnail(mode.id)
	if tex != null:
		thumb.texture = tex
	art.add_child(thumb)

	var name_label := Label.new()
	name_label.text = str(mode.display_name).to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", ThemeRef.SIZE_MODE_TITLE)
	name_label.add_theme_color_override("font_color", ThemeRef.TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_label)

	var limits := Label.new()
	limits.text = "%d–%d jugadores" % [mode.min_players, mode.max_players]
	limits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	limits.add_theme_font_size_override("font_size", ThemeRef.SIZE_HELPER)
	limits.add_theme_color_override("font_color", ThemeRef.MUTED)
	limits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(limits)

	var badge = BadgeScript.new()
	badge.setup(mode.status_label(), mode.availability == "playable")
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(badge)


func _set_hot(on: bool) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.03, 1.03) if on else Vector2.ONE, 0.1)
