class_name TrackTurboHud
extends CanvasLayer

## Production Hotseat HUD. Debug telemetry is a separate overlay.

const Hotseat := preload("res://scripts/track/track_hotseat_v2.gd")

var ranking_label: Label
var target_label: Label
var delta_label: Label
var fuel_label: Label
var fuel_bar: ColorRect
var player_label: Label
var banner: Label
var debug_label: Label
var debug_on: bool = false
var _fuel_pulse: float = 0.0
var _dimmer: ColorRect
var _summary: ColorRect
var _summary_label: Label
var _hint_label: Label
var _handoff: ColorRect
var _handoff_label: Label
var _phase_chip: Label
var _ultima_banner: Label
var _ultima_hold: float = 0.0


func _ready() -> void:
	layer = 30
	_build()


func _process(delta: float) -> void:
	if _ultima_hold > 0.0:
		_ultima_hold -= delta
		if _ultima_hold <= 0.0 and _ultima_banner != null:
			_ultima_banner.add_theme_font_size_override("font_size", 18)
			_ultima_banner.position = Vector2(16, 172)
			_ultima_banner.size = Vector2(360, 40)


func _build() -> void:
	_dimmer = ColorRect.new()
	_dimmer.color = Color(0.04, 0.05, 0.07, 0.0)
	_dimmer.position = Vector2.ZERO
	_dimmer.size = Vector2(1920, 1080)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dimmer)
	ranking_label = _lab(Vector2(1280, 18), 20, Color(1, 0.95, 0.82), 600)
	ranking_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_label = _lab(Vector2(24, 20), 26, Color("#f0d48a"), 480)
	target_label = _lab(Vector2(24, 58), 20, Color("#d8d0c0"), 420)
	delta_label = _lab(Vector2(24, 92), 20, Color("#e8e8e8"), 220)
	fuel_label = _lab(Vector2(24, 136), 20, Color("#c8e0a8"), 360)
	fuel_bar = ColorRect.new()
	fuel_bar.position = Vector2(24, 168)
	fuel_bar.size = Vector2(260, 12)
	fuel_bar.color = Color("#7aa85a")
	add_child(fuel_bar)
	_phase_chip = _lab(Vector2(24, 188), 18, Color("#f0d48a"), 420)
	_ultima_banner = _lab(Vector2(560, 80), 42, Color("#f0c040"), 800)
	_ultima_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ultima_banner.visible = false
	banner = _lab(Vector2(560, 40), 28, Color("#fff4c8"), 800)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary = ColorRect.new()
	_summary.color = Color(0.06, 0.05, 0.04, 0.92)
	_summary.position = Vector2(580, 200)
	_summary.size = Vector2(760, 560)
	_summary.visible = false
	add_child(_summary)
	_summary_label = _lab(Vector2(600, 250), 28, Color("#f4ead0"), 720)
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.size = Vector2(720, 360)
	_hint_label = _lab(Vector2(600, 640), 22, Color("#c8e0a8"), 720)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_handoff = ColorRect.new()
	_handoff.color = Color(0.05, 0.05, 0.07, 0.92)
	_handoff.position = Vector2(0, 0)
	_handoff.size = Vector2(1920, 1080)
	_handoff.visible = false
	add_child(_handoff)
	_handoff_label = _lab(Vector2(360, 280), 36, Color("#fff4c8"), 1200)
	_handoff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_handoff_label.size = Vector2(1200, 420)
	debug_label = _lab(Vector2(24, 220), 14, Color("#a8d8ff"), 700)
	debug_label.visible = false


func _lab(pos: Vector2, size: int, color: Color, width: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(width, 80)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func set_ranking(rows: Array, current_id: String) -> void:
	if ranking_label == null:
		return
	var lines := PackedStringArray()
	var n := 1
	for row in rows:
		var mark := "  ◀" if str(row.get("id", "")) == current_id else ""
		var ms: int = int(row.get("best_ms", -1))
		var time_s := Hotseat.format_ms(ms)
		lines.append("%d   %-8s   %s%s" % [n, str(row.get("name", "")), time_s, mark])
		n += 1
	ranking_label.text = "\n".join(lines)


func set_player(name_text: String, color: Color) -> void:
	if player_label == null:
		return
	player_label.text = name_text
	player_label.add_theme_color_override("font_color", color)


func set_target(ms: int) -> void:
	if target_label == null:
		return
	if ms < 0:
		target_label.text = "TARGET  --:--.---"
		return
	target_label.text = "TARGET  %s" % Hotseat.format_ms(ms)


func clear_delta() -> void:
	if delta_label == null:
		return
	delta_label.text = ""


func set_delta(delta_sec: float) -> void:
	if delta_label == null:
		return
	if is_nan(delta_sec):
		delta_label.text = ""
		return
	var sign := "+" if delta_sec >= 0.0 else "-"
	delta_label.text = "%s%.3f" % [sign, absf(delta_sec)]
	delta_label.add_theme_color_override("font_color", Color("#e07070") if delta_sec >= 0.0 else Color("#70d090"))


func set_fuel(seconds: float, max_s: float, ultima: bool, pulse: bool) -> void:
	if fuel_label == null or fuel_bar == null:
		return
	var m := int(seconds / 60.0)
	var s := seconds - float(m * 60)
	if ultima:
		fuel_label.text = "FUEL  --  ÚLTIMA"
		fuel_label.add_theme_color_override("font_color", Color("#f0c040"))
	else:
		fuel_label.text = "FUEL  %02d:%05.2f" % [m, s]
		fuel_label.add_theme_color_override("font_color", Color("#f0a040") if pulse else Color("#c8e0a8"))
	var t := clampf(seconds / maxf(max_s, 0.001), 0.0, 1.0)
	fuel_bar.size.x = 260.0 * t
	fuel_bar.color = Color("#d09040") if pulse else Color("#7aa85a")


func set_banner(text: String, on: bool) -> void:
	if banner == null:
		return
	banner.visible = on and not text.is_empty()
	banner.text = text


func set_phase_chip(text: String) -> void:
	if _phase_chip == null:
		return
	_phase_chip.visible = not text.is_empty()
	_phase_chip.text = text


func flash_ultima() -> void:
	if _ultima_banner == null:
		return
	_ultima_banner.visible = true
	_ultima_banner.text = "ÚLTIMA OPORTUNIDAD"
	_ultima_banner.position = Vector2(560, 80)
	_ultima_banner.add_theme_font_size_override("font_size", 42)
	_ultima_hold = 1.6


func set_generating(on: bool) -> void:
	if _dimmer != null:
		_dimmer.color.a = 0.18 if on else 0.0
	set_banner("GENERANDO PISTA...", on)
	hide_summary()
	hide_handoff()


func show_summary(body: String, hint: String = "[  DALE  ]        [  OTRA  ]") -> void:
	if _summary != null:
		_summary.visible = true
	if _summary_label != null:
		_summary_label.visible = true
		_summary_label.text = body
	if _hint_label != null:
		_hint_label.visible = true
		_hint_label.text = hint
	set_banner("", false)
	if _dimmer != null:
		_dimmer.color.a = 0.35


func hide_summary() -> void:
	if _summary != null:
		_summary.visible = false
	if _summary_label != null:
		_summary_label.visible = false
	if _hint_label != null:
		_hint_label.visible = false
	if _dimmer != null and (_handoff == null or not _handoff.visible):
		_dimmer.color.a = 0.0


func show_handoff(body: String, accent: Color) -> void:
	if _handoff != null:
		_handoff.visible = true
		_handoff.color = Color(accent.r * 0.12, accent.g * 0.1, accent.b * 0.08, 0.92)
	if _handoff_label != null:
		_handoff_label.visible = true
		_handoff_label.text = body
		_handoff_label.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.35))
	hide_summary()
	if _dimmer != null:
		_dimmer.color.a = 0.55
	set_banner("", false)


func hide_handoff() -> void:
	if _handoff != null:
		_handoff.visible = false
	if _handoff_label != null:
		_handoff_label.visible = false
	if _dimmer != null:
		_dimmer.color.a = 0.0


func set_debug(text: String) -> void:
	if debug_label == null:
		return
	debug_label.visible = debug_on
	debug_label.text = text
