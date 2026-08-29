class_name JeffreyBootScreen
extends Control

signal start_pressed
signal quit_pressed

const Frame := preload("res://scripts/ui/jeffrey/global_screen_frame.gd")
const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ImageButton := preload("res://scripts/ui/jeffrey/global_image_button.gd")
const Motion := preload("res://scripts/ui/jeffrey/system/jeffrey_ui_motion.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")

var _logo: TextureRect
var _cta: Button
var _started: bool = false


func _ready() -> void:
	set_process_unhandled_input(true)
	Layout.bind_full(self)
	var frame = Frame.new()
	add_child(frame)
	frame.configure(Assets.BOOT_BACKGROUND, Assets.BOOT_AMBIENCE, 0.12, Assets.BOOT_CONTROLS)

	_logo = TextureRect.new()
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_logo.texture = Assets.texture(Assets.BOOT_LOGO)
	frame.content.add_child(_logo)
	Layout.apply_frac(_logo, 0.04, 0.05, 0.52, 0.46)
	if _logo.texture == null:
		var fallback := Layout.outlined_label("LOS JUEGOS DE JEFFREY", 42, Color("#e8eaef"), HORIZONTAL_ALIGNMENT_LEFT)
		frame.content.add_child(fallback)
		Layout.apply_frac(fallback, 0.05, 0.08, 0.5, 0.18)

	_cta = ImageButton.new()
	frame.content.add_child(_cta)
	_cta.setup(Assets.BOOT_PRESS_ENTER, "PRESIONÁ ENTER", Vector2(420, 110))
	Layout.apply_frac(_cta, 0.27, 0.68, 0.46, 0.16)
	_cta.pressed.connect(_start)
	_play_intro()
	call_deferred("_focus_cta")


func _focus_cta() -> void:
	if _cta != null:
		_cta.grab_focus()


func _play_intro() -> void:
	if _logo != null:
		_logo.modulate.a = 0.0
		_logo.pivot_offset = _logo.size * 0.5
		_logo.scale = Vector2(0.98, 0.98)
		var logo_tween := create_tween()
		logo_tween.tween_property(_logo, "modulate:a", 1.0, 0.4)
		logo_tween.parallel().tween_property(_logo, "scale", Vector2.ONE, 0.4)
	if _cta != null:
		_cta.modulate.a = 0.75
		Motion.fade_in(_cta, ThemeRef.DURATION_SCREEN, 0.35)
		var pulse := create_tween()
		pulse.set_loops()
		pulse.tween_property(_cta, "modulate:a", 1.0, 0.7)
		pulse.tween_property(_cta, "modulate:a", 0.78, 0.7)


func _unhandled_input(event: InputEvent) -> void:
	if _is_enter(event):
		_start()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause_match"):
		AudioHooks.play_back(self)
		quit_pressed.emit()
		get_viewport().set_input_as_handled()


func _is_enter(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER


func _start() -> void:
	if _started:
		return
	_started = true
	AudioHooks.play_confirm(self)
	start_pressed.emit()
