class_name JeffreyOptionsScreen
extends Control

signal back_pressed

const Frame := preload("res://scripts/ui/jeffrey/global_screen_frame.gd")
const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")
const BackBtn := preload("res://scripts/ui/jeffrey/components/jeffrey_back_button.gd")
const TitleScript := preload("res://scripts/ui/jeffrey/components/jeffrey_title.gd")
const PanelScript := preload("res://scripts/ui/jeffrey/components/jeffrey_panel.gd")
const JeffreyBtn := preload("res://scripts/ui/jeffrey/components/jeffrey_button.gd")
const Motion := preload("res://scripts/ui/jeffrey/system/jeffrey_ui_motion.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")

var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider


func request_back() -> void:
	back_pressed.emit()


func _ready() -> void:
	set_process_unhandled_input(true)
	Layout.bind_full(self)
	var frame = Frame.new()
	add_child(frame)
	frame.configure(Assets.HUB_BACKGROUND, "", 0.38, Assets.HUB_CONTROLS)

	var title = TitleScript.new()
	frame.content.add_child(title)
	Layout.apply_frac(title, 0.20, 0.06, 0.60, 0.10)
	title.configure("OPCIONES", 1, HORIZONTAL_ALIGNMENT_CENTER)

	var panel = PanelScript.new()
	panel.configure(ThemeRef.Base.ACCENT, 0.9)
	frame.content.add_child(panel)
	Layout.apply_frac(panel, 0.26, 0.22, 0.48, 0.42)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", ThemeRef.SPACE_MD)
	Layout.bind_full(body)
	body.offset_left = ThemeRef.SPACE_XL
	body.offset_top = ThemeRef.SPACE_LG
	body.offset_right = -ThemeRef.SPACE_XL
	body.offset_bottom = -ThemeRef.SPACE_LG
	panel.add_child(body)

	_master_slider = _add_slider(body, "VOLUMEN GENERAL", "master_volume", 1.0)
	_music_slider = _add_slider(body, "MÚSICA", "music_volume", 1.0)
	_sfx_slider = _add_slider(body, "EFECTOS", "sfx_volume", 1.0)

	var apply = JeffreyBtn.new()
	apply.configure("GUARDAR", JeffreyBtn.Kind.PRIMARY, ThemeRef.BTN_PRIMARY)
	apply.pressed.connect(_save)
	body.add_child(apply)

	var back = BackBtn.new()
	frame.content.add_child(back)
	Layout.apply_frac(back, 0.06, 0.84, 0.18, 0.09)
	back.pressed.connect(func():
		AudioHooks.play_back(self)
		back_pressed.emit()
	)

	Motion.fade_in(frame, ThemeRef.DURATION_SCREEN)
	call_deferred("_focus_back", back)


func _add_slider(parent: VBoxContainer, label_text: String, key: String, default_value: float) -> HSlider:
	parent.add_child(Layout.outlined_label(label_text, ThemeRef.TYPE_SECONDARY, ThemeRef.Base.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(0, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = float(JeffreyCore.settings.get(key, default_value))
	slider.value_changed.connect(func(v): JeffreyCore.settings[key] = v)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	track.set_corner_radius_all(4)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(ThemeRef.Base.GOLD.r, ThemeRef.Base.GOLD.g, ThemeRef.Base.GOLD.b, 0.55)
	fill.set_corner_radius_all(4)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var grab_img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	grab_img.fill(Color(0, 0, 0, 0))
	for y in 18:
		for x in 18:
			var dx := float(x) - 8.5
			var dy := float(y) - 8.5
			if dx * dx + dy * dy <= 64.0:
				grab_img.set_pixel(x, y, ThemeRef.Base.GOLD_HOT)
	var grab_tex := ImageTexture.create_from_image(grab_img)
	slider.add_theme_icon_override("grabber", grab_tex)
	slider.add_theme_icon_override("grabber_highlight", grab_tex)
	parent.add_child(slider)
	return slider


func _save() -> void:
	JeffreyCore.settings["master_volume"] = _master_slider.value
	JeffreyCore.settings["music_volume"] = _music_slider.value
	JeffreyCore.settings["sfx_volume"] = _sfx_slider.value
	JeffreyCore.save()
	AudioHooks.play_confirm(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_match"):
		request_back()
		get_viewport().set_input_as_handled()


func _focus_back(back: Control) -> void:
	if back != null and back.has_method("request_focus_back"):
		back.call("request_focus_back")
