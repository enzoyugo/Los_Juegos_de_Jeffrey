class_name ZombiesHUD
extends CanvasLayer

const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const Typography := preload("res://scripts/ui/jeffrey/system/jeffrey_typography.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const GoldButton := preload("res://scripts/ui/jeffrey/gold_action_button.gd")
const Config := preload("res://scripts/zombies/zombies_config.gd")
const HUD_HEALTH := "res://assets/ui/zombies/hud_v2/health_block.png"
const HUD_POINTS := "res://assets/ui/zombies/hud_v2/points_block.png"
const HUD_ROUND := "res://assets/ui/zombies/hud_v2/round_block.png"
const HUD_WEAPON := "res://assets/ui/zombies/hud_v2/weapon_ammo_block.png"

signal hub_pressed
signal resume_pressed
signal restart_pressed

var _hp: Label
var _hp_caption: Label
var _hp_fill: ColorRect
var _hp_wrap: Control
var _hp_flash: float = 0.0
var _hp_last: float = 100.0
var _points: Label
var _points_toast: Label
var _points_toast_left: float = 0.0
var _wave: Label
var _wave_caption: Label
var _left: Label
var _gun: Label
var _ammo: Label
var _prompt: Label
var _banner: Label
var _toast: Label
var _debug: Label
var _over: Control
var _over_body: Label
var _pause: Control
var _toast_left: float = 0.0
var _banner_left: float = 0.0
var _debug_on: bool = false
var _hit_marker: Label
var _hit_left: float = 0.0
var _crosshair: Label
var _vignette: ColorRect
var _vignette_pulse: float = 0.0
var _low_hp: bool = false
var _dying: bool = false
var _ammo_flash: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	layer = 20
	var root := Control.new()
	Layout.bind_full(root)
	root.theme = Typography.theme_for(Typography.ZOMBIES)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_vignette = ColorRect.new()
	_vignette.color = Color(0.55, 0.02, 0.04, 1.0)
	_vignette.modulate.a = 0.0
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Layout.bind_full(_vignette)
	root.add_child(_vignette)
	var round_panel := _asset(root, HUD_ROUND, Vector2(720, 8), Vector2(480, 160))
	_wave = Layout.outlined_label("1", 52, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_wave.position = Vector2(174, 69)
	_wave.size = Vector2(132, 70)
	round_panel.add_child(_wave)
	_left = Layout.outlined_label("ZOMBIES  0", 18, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_left.visible = false
	root.add_child(_left)
	Layout.apply_frac(_left, 0.70, 0.03, 0.26, 0.05)
	var points_panel := _asset(root, HUD_POINTS, Vector2(18, 12), Vector2(330, 110))
	_points = Layout.outlined_label("0", 30, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_points.position = Vector2(150, 39)
	_points.size = Vector2(150, 42)
	points_panel.add_child(_points)
	_points_toast = Layout.outlined_label("", 26, ThemeRef.GOLD_HOT, HORIZONTAL_ALIGNMENT_LEFT)
	root.add_child(_points_toast)
	Layout.apply_frac(_points_toast, 0.04, 0.105, 0.18, 0.05)
	var health_panel := _asset(root, HUD_HEALTH, Vector2(18, 890), Vector2(380, 126))
	var hp_wrap := Control.new()
	_hp_wrap = hp_wrap
	root.add_child(hp_wrap)
	hp_wrap.position = Vector2(120, 76)
	hp_wrap.size = Vector2(225, 16)
	var hp_track := ColorRect.new()
	hp_track.color = Color(0.08, 0.09, 0.12, 0.85)
	hp_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Layout.bind_full(hp_track)
	hp_wrap.add_child(hp_track)
	_hp_fill = ColorRect.new()
	_hp_fill.color = ThemeRef.OK
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill.anchor_left = 0.0
	_hp_fill.anchor_top = 0.0
	_hp_fill.anchor_right = 1.0
	_hp_fill.anchor_bottom = 1.0
	hp_wrap.add_child(_hp_fill)
	_hp_caption = null
	_hp = Layout.outlined_label("100", 22, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_hp.position = Vector2(292, 38)
	_hp.size = Vector2(65, 40)
	health_panel.add_child(_hp)
	var weapon_panel := _asset(root, HUD_WEAPON, Vector2(1510, 872), Vector2(390, 130))
	_gun = Layout.outlined_label("PISTOLA", 21, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	_gun.position = Vector2(78, 42)
	_gun.size = Vector2(170, 38)
	weapon_panel.add_child(_gun)
	_ammo = Layout.outlined_label("10 / 80", 28, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_ammo.position = Vector2(210, 42)
	_ammo.size = Vector2(150, 42)
	weapon_panel.add_child(_ammo)
	_prompt = Layout.outlined_label("", 28, ThemeRef.GOLD_HOT, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_prompt)
	Layout.apply_frac(_prompt, 0.18, 0.62, 0.64, 0.10)
	_crosshair = Layout.outlined_label("+", 28, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_crosshair)
	Layout.apply_frac(_crosshair, 0.46, 0.46, 0.08, 0.08)
	_hit_marker = Layout.outlined_label("+", 34, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_hit_marker.visible = false
	root.add_child(_hit_marker)
	Layout.apply_frac(_hit_marker, 0.45, 0.45, 0.10, 0.10)
	_banner = Layout.outlined_label("", 48, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_banner)
	Layout.apply_frac(_banner, 0.22, 0.28, 0.56, 0.10)
	_toast = Layout.outlined_label("", 52, ThemeRef.GOLD_HOT, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_toast)
	Layout.apply_frac(_toast, 0.22, 0.16, 0.56, 0.10)
	_debug = Layout.outlined_label("", 14, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	_debug.visible = false
	root.add_child(_debug)
	Layout.apply_frac(_debug, 0.04, 0.16, 0.42, 0.22)
	_build_pause()
	_build_over()


func _process(delta: float) -> void:
	_t += delta
	_toast_left = maxf(_toast_left - delta, 0.0)
	_banner_left = maxf(_banner_left - delta, 0.0)
	_hit_left = maxf(_hit_left - delta, 0.0)
	_points_toast_left = maxf(_points_toast_left - delta, 0.0)
	_hp_flash = maxf(_hp_flash - delta, 0.0)
	_ammo_flash = maxf(_ammo_flash - delta, 0.0)
	_vignette_pulse = maxf(_vignette_pulse - delta, 0.0)
	if _toast != null and _toast_left <= 0.0:
		_toast.text = ""
	if _banner != null and _banner_left <= 0.0:
		_banner.text = ""
	if _points_toast != null and _points_toast_left <= 0.0:
		_points_toast.text = ""
	if _hit_marker != null:
		_hit_marker.visible = _hit_left > 0.0
	if _ammo != null:
		_ammo.modulate = ThemeRef.GOLD_HOT if _ammo_flash > 0.0 else Color.WHITE
	if _hp_fill != null:
		_hp_fill.modulate = Color(1.4, 1.2, 1.2) if _hp_flash > 0.0 else Color.WHITE
	_tick_vignette()


func _asset(parent: Control, path: String, pos: Vector2, size: Vector2) -> Control:
	var host := Control.new()
	host.position = pos
	host.size = size
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(host)
	var image := TextureRect.new()
	image.texture = load(path)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(image)
	return host


func set_hp(value: float) -> void:
	if value < _hp_last - 0.1:
		_hp_flash = 0.18
	_hp_last = value
	_low_hp = value < 30.0 and value > 0.0
	if _hp != null:
		_hp.text = "%d" % int(value)
	if _hp_fill != null:
		_hp_fill.anchor_right = clampf(value / 100.0, 0.0, 1.0)
		_hp_fill.color = ThemeRef.DANGER if value < 30.0 else ThemeRef.OK


func set_points(value: int) -> void:
	if _points != null:
		_points.text = "%d" % value


func show_points_toast(amount: int) -> void:
	if amount <= 0 or _points_toast == null:
		return
	_points_toast.text = "+%d" % amount
	_points_toast_left = 0.6


func set_wave(value: int, remaining: int) -> void:
	if _wave != null:
		_wave.text = "%d" % value
	if _left != null:
		_left.text = "ZOMBIES  %d" % remaining


func set_weapon(name_text: String, mag: int, reserve: int, reloading: bool = false) -> void:
	if _gun != null:
		_gun.text = "RECARGANDO" if reloading else name_text
	if _ammo != null:
		_ammo.text = "%d / %d" % [mag, reserve]


func set_prompt(text: String) -> void:
	if _prompt != null:
		_prompt.text = text


func set_status(text: String) -> void:
	announce(text, 1.6)


func announce_round(wave: int) -> void:
	if _wave != null:
		_wave.text = "%d" % wave


func announce(text: String, seconds: float = 2.0) -> void:
	if _banner == null:
		return
	if text == "+" or text.strip_edges().is_empty():
		_banner.text = ""
		_banner_left = 0.0
		return
	_banner.text = text
	_banner_left = seconds


func show_max_ammo() -> void:
	if _toast != null:
		_toast.text = "MAX AMMO"
		_toast_left = 2.8


func show_hit_marker(killed: bool = false) -> void:
	if _hit_marker == null:
		return
	_hit_marker.text = "+"
	_hit_marker.add_theme_font_size_override("font_size", 48 if killed else 34)
	_hit_left = 0.12
	_hit_marker.visible = true


func pulse_damage() -> void:
	_vignette_pulse = 0.16
	_hp_flash = 0.18


func flash_ammo() -> void:
	_ammo_flash = 0.16


func play_death_vignette() -> void:
	_dying = true
	_vignette_pulse = 0.4


func is_debug() -> bool:
	return _debug_on


func toggle_debug() -> void:
	_debug_on = not _debug_on
	if _debug != null:
		_debug.visible = _debug_on


func set_debug(text: String) -> void:
	if _debug != null:
		_debug.text = text


func show_pause(on: bool) -> void:
	if _pause != null:
		_pause.visible = on


func _build_over() -> void:
	_over = Control.new()
	_over.visible = false
	Layout.bind_full(_over)
	add_child(_over)
	var wash := ColorRect.new()
	wash.color = Color(0.02, 0.06, 0.03, 0.84)
	Layout.bind_full(wash)
	_over.add_child(wash)
	var Banner := preload("res://scripts/ui/jeffrey/zombies_result_banner_v1.gd")
	var card = Banner.make()
	_over.add_child(card)
	Layout.apply_frac(card, 0.30, 0.20, 0.40, 0.28)
	_over_body = null
	## Banner filled on show_game_over; keep action buttons below.
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	_over.add_child(box)
	Layout.apply_frac(box, 0.32, 0.52, 0.36, 0.28)
	var again = GoldButton.new()
	again.configure("REINICIAR", Vector2(220, 44))
	again.pressed.connect(func(): restart_pressed.emit())
	box.add_child(again)
	var hub = GoldButton.new()
	hub.configure("VOLVER AL HUB", Vector2(220, 44))
	hub.pressed.connect(func(): hub_pressed.emit())
	box.add_child(hub)
	_over.set_meta("zombies_banner", card)


func show_game_over(wave: int, kills: int) -> void:
	if _over == null:
		return
	_over.visible = true
	_set_play_hud_visible(false)
	var Banner := preload("res://scripts/ui/jeffrey/zombies_result_banner_v1.gd")
	var card = _over.get_meta("zombies_banner", null)
	if card != null:
		Banner.fill(card, wave, kills)
	elif _over_body != null:
		_over_body.text = "RONDA  %d\nBAJAS  %d\nCOPA  ·  0 PTS" % [wave, kills]


func hide_game_over() -> void:
	if _over != null:
		_over.visible = false
	_set_play_hud_visible(true)


func _set_play_hud_visible(on: bool) -> void:
	for node in [_wave, _wave_caption, _left, _points, _points_toast, _hp_caption, _hp, _hp_wrap, _gun, _ammo, _prompt, _crosshair, _banner, _toast, _hit_marker]:
		if node != null:
			node.visible = on
	if _vignette != null and not on:
		_vignette.modulate.a = 0.0


func _tick_vignette() -> void:
	if _vignette == null:
		return
	if _over != null and _over.visible:
		_vignette.modulate.a = 0.0
		return
	var a: float = 0.0
	if _dying:
		a = 0.7
	elif _vignette_pulse > 0.0:
		a = 0.34 * (_vignette_pulse / 0.16)
	elif _low_hp:
		a = 0.10 + 0.05 * (0.5 + 0.5 * sin(_t * 5.5))
	_vignette.modulate.a = a


func _build_pause() -> void:
	_pause = Control.new()
	_pause.visible = false
	Layout.bind_full(_pause)
	add_child(_pause)
	var wash := ColorRect.new()
	wash.color = Color(0, 0, 0, 0.7)
	Layout.bind_full(wash)
	_pause.add_child(wash)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	_pause.add_child(box)
	Layout.apply_frac(box, 0.35, 0.32, 0.3, 0.32)
	box.add_child(Layout.outlined_label("PAUSA", 28, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var resume = GoldButton.new()
	resume.configure("SEGUIR", Vector2(200, 44))
	resume.pressed.connect(func():
		show_pause(false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		resume_pressed.emit()
	)
	box.add_child(resume)
	var hub = GoldButton.new()
	hub.configure("HUB", Vector2(200, 44))
	hub.pressed.connect(func(): hub_pressed.emit())
	box.add_child(hub)
