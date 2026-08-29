class_name ModeTransitionController
extends Control

## Game-entry transition with explicit state (not a coarse shell-wide lock).
## States: IDLE → ACCEPTED → ENTERING → READY
## Action acceptance is immediate; animation completion is separate.

signal finished(mode_id: String, context: Dictionary)
signal generation_started
signal generation_piece_added
signal generation_validation_started
signal generation_validated
signal generation_finished
signal feedback_started(mode_id: String)

const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")
const DefinitionScript := preload("res://scripts/ui/jeffrey/mode_transition_definition.gd")
const ModeRegistry := preload("res://scripts/core/jeffrey/game_mode_registry.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")
const ZombiesLoadingScript := preload("res://scripts/ui/jeffrey/zombies_loading_screen.gd")

enum State { IDLE, ACCEPTED, ENTERING, READY }

var _state: int = State.IDLE
var _mode_id: String = ""
var _context: Dictionary = {}
var _definition
var _elapsed: float = 0.0
var _status: Label
var _tip: Label
var _fill: ColorRect
var _flash: ColorRect
var _player_list: VBoxContainer
var _stage: Label
var _zombies_loading
var _t_input_usec: int = 0
var _completed: bool = false


func _ready() -> void:
	Layout.bind_full(self)
	set_process(false)
	set_process_unhandled_input(true)
	mouse_filter = Control.MOUSE_FILTER_STOP


func is_busy() -> bool:
	return _state == State.ACCEPTED or _state == State.ENTERING


func get_transition_state() -> int:
	return _state


func show_mode_transition(mode_id: String, context: Dictionary = {}) -> void:
	if _state != State.IDLE:
		return
	_t_input_usec = Time.get_ticks_usec()
	_state = State.ACCEPTED
	_completed = false
	_mode_id = mode_id
	_context = context.duplicate(true)
	_definition = DefinitionScript.new()
	_definition.configure(mode_id)
	_elapsed = 0.0
	print("[INPUT_RECEIVED] mode=%s t_us=%d" % [mode_id, _t_input_usec])
	_build_visual()
	_play_intro()
	feedback_started.emit(mode_id)
	print("[FEEDBACK_STARTED] mode=%s dt_ms=%.2f" % [mode_id, float(Time.get_ticks_usec() - _t_input_usec) / 1000.0])
	_state = State.ENTERING
	print("[TRANSITION_STARTED] mode=%s" % mode_id)
	set_process(true)
	_play_mode_hook()


func set_generation_stage(text: String) -> void:
	if _stage != null:
		_stage.text = text


func set_generation_progress(amount: float) -> void:
	_set_fill(amount)


func set_track_preview(_texture: Texture2D) -> void:
	pass


func set_tip(text: String) -> void:
	if _tip != null:
		_tip.text = text


func _unhandled_input(event: InputEvent) -> void:
	## Debounce only: swallow presses while entering so confirm cannot double-fire.
	## Does not permanently lock the application — state returns to READY/IDLE on complete.
	if _state != State.ACCEPTED and _state != State.ENTERING:
		return
	if event.is_pressed():
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _state != State.ENTERING:
		return
	_elapsed += delta
	var duration: float = 0.48
	if _definition != null:
		duration = maxf(_definition.duration_min, 0.40)
	_set_fill(clampf(_elapsed / duration, 0.0, 1.0))
	if _elapsed >= duration:
		_complete()


func _complete() -> void:
	if _completed or _state != State.ENTERING:
		return
	_completed = true
	set_process(false)
	_flash_exit()
	_state = State.READY
	print(
		"[TRANSITION_COMPLETE] mode=%s total_ms=%.2f"
		% [_mode_id, float(Time.get_ticks_usec() - _t_input_usec) / 1000.0]
	)
	finished.emit(_mode_id, _context)
	_state = State.IDLE


func _play_mode_hook() -> void:
	match _mode_id:
		ModeRegistry.MODE_SMASH:
			AudioHooks.play_soco_impact(self)
		ModeRegistry.MODE_RACING:
			AudioHooks.play_track_whoosh(self)
		ModeRegistry.MODE_ZOMBIES:
			AudioHooks.play_zombies_hit(self)


func _tex(path: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture = Assets.texture(path)
	return rect


func _build_visual() -> void:
	_zombies_loading = null
	_fill = null
	for child in get_children():
		child.queue_free()
	if _definition == null:
		return
	if _mode_id != ModeRegistry.MODE_ZOMBIES:
		var bg := _tex(_definition.background_texture)
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		Layout.bind_full(bg)
		add_child(bg)
		if not _definition.fx_overlay_texture.is_empty():
			var fx := _tex(_definition.fx_overlay_texture)
			fx.modulate.a = 0.0
			Layout.bind_full(fx)
			add_child(fx)
			var fx_tween := create_tween()
			fx_tween.tween_interval(0.06)
			fx_tween.tween_property(fx, "modulate:a", 1.0, 0.12)
	match _mode_id:
		ModeRegistry.MODE_SMASH:
			_build_soco()
		ModeRegistry.MODE_RACING:
			_build_track()
		ModeRegistry.MODE_ZOMBIES:
			_build_zombies()
		_:
			_status = Layout.outlined_label(_definition.status_copy, Styles.SIZE_TRANSITION, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
			Styles.apply(_status, "transition_status")
			add_child(_status)
			Layout.apply_frac(_status, 0.2, 0.7, 0.6, 0.08)
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 0.95, 0.82, 0)
	Layout.bind_full(_flash)
	add_child(_flash)


func _build_soco() -> void:
	var header := _tex(_definition.global_header_texture)
	add_child(header)
	Layout.apply_frac(header, 0.22, 0.04, 0.56, 0.12)
	var title := _tex(_definition.title_texture)
	title.pivot_offset = Vector2(960, 120)
	title.scale = Vector2(0.55, 0.55)
	title.modulate.a = 0.0
	add_child(title)
	Layout.apply_frac(title, 0.18, 0.18, 0.64, 0.22)
	var banner := _tex(_definition.mode_banner_texture)
	banner.modulate.a = 0.0
	add_child(banner)
	Layout.apply_frac(banner, 0.28, 0.40, 0.44, 0.10)
	var fist := _tex(_definition.emblem_texture)
	fist.modulate.a = 0.0
	add_child(fist)
	Layout.apply_frac(fist, 0.38, 0.48, 0.24, 0.22)
	_status = Layout.outlined_label(_definition.status_copy, Styles.SIZE_TRANSITION, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Styles.apply(_status, "transition_status")
	add_child(_status)
	Layout.apply_frac(_status, 0.2, 0.70, 0.6, 0.06)
	_add_progress(0.25, 0.76, 0.50, 0.06)
	var controls := _tex(_definition.controls_texture)
	add_child(controls)
	Layout.apply_frac(controls, 0.18, 0.88, 0.64, 0.09)
	var intro := create_tween()
	intro.tween_interval(0.08)
	intro.tween_property(title, "modulate:a", 1.0, 0.10)
	intro.parallel().tween_property(title, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_interval(0.04)
	intro.tween_property(banner, "modulate:a", 1.0, 0.10)
	intro.parallel().tween_property(fist, "modulate:a", 1.0, 0.12)


func _build_track() -> void:
	var header := _tex(_definition.global_header_texture)
	add_child(header)
	Layout.apply_frac(header, 0.04, 0.03, 0.40, 0.10)
	var title := _tex(_definition.title_texture)
	add_child(title)
	Layout.apply_frac(title, 0.04, 0.14, 0.42, 0.18)
	var banner := _tex(_definition.mode_banner_texture)
	add_child(banner)
	Layout.apply_frac(banner, 0.05, 0.32, 0.32, 0.08)
	var gen := _tex(_definition.main_panel_texture)
	add_child(gen)
	Layout.apply_frac(gen, 0.04, 0.52, 0.34, 0.28)
	_stage = Layout.outlined_label(_definition.status_copy, Styles.SIZE_STATUS, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	Styles.apply(_stage, "status")
	add_child(_stage)
	Layout.apply_frac(_stage, 0.07, 0.58, 0.28, 0.08)
	_status = _stage
	_add_progress(0.07, 0.70, 0.28, 0.05)
	var tip_art := _tex(_definition.secondary_panel_texture)
	add_child(tip_art)
	Layout.apply_frac(tip_art, 0.66, 0.70, 0.30, 0.16)
	_tip = Layout.outlined_label("Hotseat se arma en una próxima versión.", Styles.SIZE_HELPER, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	Styles.apply(_tip, "small_helper")
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_tip)
	Layout.apply_frac(_tip, 0.68, 0.74, 0.26, 0.10)
	var controls := _tex(_definition.controls_texture)
	add_child(controls)
	Layout.apply_frac(controls, 0.18, 0.88, 0.64, 0.09)


func _build_zombies() -> void:
	var loading := ZombiesLoadingScript.new()
	loading.embedded = true
	loading.auto_complete = false
	Layout.bind_full(loading)
	add_child(loading)
	_status = loading.loading_text
	_tip = loading.flavor_text
	_zombies_loading = loading


func _add_progress(left: float, top: float, width: float, height: float) -> void:
	var host := Control.new()
	add_child(host)
	Layout.apply_frac(host, left, top, width, height)
	var bar := TextureRect.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if _definition != null:
		bar.texture = Assets.texture(_definition.progress_texture)
	Layout.bind_full(bar)
	host.add_child(bar)
	var clip := Control.new()
	clip.clip_contents = true
	Layout.bind_full(clip)
	host.add_child(clip)
	_fill = ColorRect.new()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.color = Color(ThemeRef.GOLD.r, ThemeRef.GOLD.g, ThemeRef.GOLD.b, 0.55)
	clip.add_child(_fill)
	_fill.anchor_left = 0.06
	_fill.anchor_top = 0.32
	_fill.anchor_bottom = 0.68
	_fill.anchor_right = 0.06
	_fill.offset_left = 0
	_fill.offset_right = 0
	_fill.offset_top = 0
	_fill.offset_bottom = 0


func _set_fill(amount: float) -> void:
	if _zombies_loading != null:
		_zombies_loading.set_progress(amount)
		return
	if _fill == null:
		return
	## Width via size — avoids per-frame full layout invalidate from anchor churn.
	var parent := _fill.get_parent() as Control
	if parent != null:
		var w := parent.size.x * lerpf(0.0, 0.88, clampf(amount, 0.0, 1.0))
		_fill.position = Vector2(parent.size.x * 0.06, parent.size.y * 0.32)
		_fill.size = Vector2(maxf(w, 1.0), parent.size.y * 0.36)
	else:
		_fill.anchor_right = lerpf(0.06, 0.94, clampf(amount, 0.0, 1.0))


func _play_intro() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.08)


func _flash_exit() -> void:
	if _flash == null:
		return
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.45, 0.05)
	tween.tween_property(_flash, "color:a", 0.0, 0.08)
