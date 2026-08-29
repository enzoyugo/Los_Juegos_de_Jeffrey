class_name TrackHUD
extends CanvasLayer

const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")
const GoldButton := preload("res://scripts/ui/jeffrey/gold_action_button.gd")
const Chrome := preload("res://scripts/track/track_hud_chrome_v1.gd")
const InputHint := preload("res://scripts/ui/jeffrey/components/jeffrey_input_hint.gd")

const TRACK_ACCENT := Color("#3db8c9")

signal play_pressed(length_id: String, difficulty_id: String)
signal next_pressed
signal hub_pressed
signal resume_pressed
signal otra_pressed

var _driver: Label
var _timer: Label
var _best: Label
var _fuel: Label
var _check: Label
var _status: Label
var _board: Label
var _prompt: Control
var _rank: Label
var _seed: Label
var _setup: Control
var _pause: Control
var _board_panel: PanelContainer
var _length: String = "media"
var _diff: String = "picante"
var _seed_label: Label
var _status_pulse: float = 0.0
var _check_flash: float = 0.0


func _ready() -> void:
	layer = 20
	_build_hud()
	_build_setup()
	_build_pause()
	if _seed != null:
		_seed.visible = false
	if _board_panel != null:
		_board_panel.visible = false


func show_setup() -> void:
	if _setup != null:
		_setup.visible = true
	if _pause != null:
		_pause.visible = false
	if _seed != null:
		_seed.visible = false
	if _board_panel != null:
		_board_panel.visible = false


func hide_setup() -> void:
	if _setup != null:
		_setup.visible = false
	if _seed != null:
		_seed.visible = false


func is_setup_visible() -> bool:
	return _setup != null and _setup.visible


func show_pause(on: bool) -> void:
	if _pause != null:
		_pause.visible = on


func set_driver(name_text: String, character_name: String, slot: int) -> void:
	if _driver == null:
		return
	var person := name_text.strip_edges().to_upper()
	var kape := character_name.strip_edges().to_upper()
	var slot_tag := "P%d" % slot
	## Avoid "P1 P1 · TERERÉ" when display_name already mirrors the slot.
	if person.is_empty() or person == slot_tag or person == ("PLAYER %d" % slot):
		_driver.text = "%s  ·  %s" % [slot_tag, kape]
	else:
		_driver.text = "%s  %s  ·  %s" % [slot_tag, person, kape]


func set_timer(seconds: float) -> void:
	if _timer != null:
		_timer.text = _fmt(seconds)


func set_best(seconds: float) -> void:
	if _best == null:
		return
	if seconds < 0.0:
		_best.text = "MEJOR  —"
	else:
		_best.text = "MEJOR  %s" % _fmt(seconds)


func flash_checkpoint(current: int, total: int) -> void:
	set_progress(current, total)
	_check_flash = 0.55
	if _status != null:
		_status.text = "PUNTO  %d / %d" % [current, total]
		_status.add_theme_font_size_override("font_size", 34)
		_status.add_theme_color_override("font_color", TRACK_ACCENT)
	_status_pulse = 0.55


func flash_finish(seconds: float) -> void:
	if _status != null:
		_status.text = "META  ·  %s" % _fmt(seconds)
		_status.add_theme_font_size_override("font_size", 40)
		_status.add_theme_color_override("font_color", ThemeRef.GOLD_HOT)
	_status_pulse = 1.4


func set_fuel(seconds: float, last_dance: bool, player_name: String = "") -> void:
	if _fuel == null:
		return
	if last_dance:
		_fuel.text = "RENDICIÓN"
		_fuel.add_theme_color_override("font_color", ThemeRef.GOLD_HOT)
	else:
		_fuel.text = "COMBUSTIBLE  %s" % _fmt(seconds)
		_fuel.add_theme_color_override("font_color", ThemeRef.TEXT)


func set_rank(rank: int, total: int) -> void:
	if _rank != null:
		_rank.text = "PUESTO  %d / %d" % [rank, total] if rank > 0 else ""


func set_seed(seed_value: int) -> void:
	## Race HUD seed looks like debug — keep seed on setup card only.
	if _seed != null:
		_seed.text = ""
		_seed.visible = false
	if _seed_label != null:
		_seed_label.text = "Pista #%d" % seed_value


func set_progress(current: int, total: int) -> void:
	if _check != null:
		_check.text = "CONTROL  %d / %d" % [current, total]


func set_status(text: String) -> void:
	if _status == null:
		return
	_status.text = text
	## Countdown / DALE get larger Track identity type.
	var upper := text.strip_edges().to_upper()
	if upper.is_valid_int() or upper == "DALE" or upper == "PREPARADOS":
		_status.add_theme_font_size_override("font_size", 64 if upper == "DALE" else 72)
		_status.add_theme_color_override("font_color", TRACK_ACCENT if upper.is_valid_int() else ThemeRef.GOLD_HOT)
		_status_pulse = 0.35
	elif upper.begins_with("META") or upper.begins_with("FINISH") or upper.begins_with("TIEMPO"):
		_status.add_theme_font_size_override("font_size", 40)
		_status.add_theme_color_override("font_color", ThemeRef.GOLD_HOT)
	elif upper.begins_with("PUNTO") or upper.begins_with("CHECK"):
		_status.add_theme_font_size_override("font_size", 34)
		_status.add_theme_color_override("font_color", TRACK_ACCENT)
	else:
		_status.add_theme_font_size_override("font_size", 30)
		_status.add_theme_color_override("font_color", ThemeRef.GOLD_HOT)


func _process(delta: float) -> void:
	_status_pulse = maxf(_status_pulse - delta, 0.0)
	_check_flash = maxf(_check_flash - delta, 0.0)
	if _status != null and _status_pulse > 0.0:
		var t := _status_pulse
		_status.modulate = Color(1.0, 1.0, 1.0, clampf(0.55 + t, 0.55, 1.0))
		_status.scale = Vector2.ONE * (1.0 + 0.06 * t)
	elif _status != null:
		_status.modulate = Color.WHITE
		_status.scale = Vector2.ONE
	if _check != null:
		_check.modulate = TRACK_ACCENT if _check_flash > 0.0 else Color.WHITE


func set_board(lines: PackedStringArray) -> void:
	if _board != null:
		_board.text = "\n".join(lines)
	if _board_panel != null:
		_board_panel.visible = not lines.is_empty()


func set_prompt(text: String) -> void:
	## Legacy string API kept for callers; glyph strip is preferred.
	if _prompt is Label:
		(_prompt as Label).text = text


func _fmt(seconds: float) -> String:
	var m := int(seconds) / 60
	var s := fmod(seconds, 60.0)
	return "%d:%05.2f" % [m, s]


func _build_hud() -> void:
	set_process(true)
	var root := Control.new()
	Layout.bind_full(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var timer_panel = Chrome.make_timer_frame()
	root.add_child(timer_panel)
	Layout.apply_frac(timer_panel, 0.36, 0.018, 0.28, 0.12)
	var timer_col := VBoxContainer.new()
	timer_col.add_theme_constant_override("separation", 2)
	timer_panel.add_child(timer_col)
	var brand_row := HBoxContainer.new()
	brand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	brand_row.add_theme_constant_override("separation", 8)
	timer_col.add_child(brand_row)
	brand_row.add_child(Layout.outlined_label("▸", 14, TRACK_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	brand_row.add_child(Layout.outlined_label("TRACK", 15, TRACK_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	brand_row.add_child(Layout.outlined_label("◂", 14, TRACK_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	timer_col.add_child(Chrome.make_accent_bar())
	_timer = Layout.outlined_label("0:00.00", 38, TRACK_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	timer_col.add_child(_timer)
	_best = Layout.outlined_label("MEJOR  —", 13, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	timer_col.add_child(_best)

	var driver_chip = Chrome.make_side_chip()
	root.add_child(driver_chip)
	Layout.apply_frac(driver_chip, 0.02, 0.022, 0.26, 0.042)
	_driver = Layout.outlined_label("", 15, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	driver_chip.add_child(_driver)

	var fuel_chip = Chrome.make_side_chip(ThemeRef.GOLD)
	root.add_child(fuel_chip)
	Layout.apply_frac(fuel_chip, 0.72, 0.022, 0.26, 0.042)
	_fuel = Layout.outlined_label("", 14, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	fuel_chip.add_child(_fuel)

	var check_chip = Chrome.make_side_chip()
	root.add_child(check_chip)
	Layout.apply_frac(check_chip, 0.02, 0.072, 0.18, 0.036)
	_check = Layout.outlined_label("", 13, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	check_chip.add_child(_check)

	var rank_chip = Chrome.make_side_chip(TRACK_ACCENT)
	root.add_child(rank_chip)
	Layout.apply_frac(rank_chip, 0.02, 0.115, 0.18, 0.036)
	_rank = Layout.outlined_label("", 13, TRACK_ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	rank_chip.add_child(_rank)

	_seed = Layout.outlined_label("", 13, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	root.add_child(_seed)
	Layout.apply_frac(_seed, 0.03, 0.19, 0.28, 0.04)
	_status = Layout.outlined_label("", 30, ThemeRef.GOLD_HOT, HORIZONTAL_ALIGNMENT_CENTER)
	_status.pivot_offset = Vector2(480, 40)
	root.add_child(_status)
	Layout.apply_frac(_status, 0.25, 0.38, 0.5, 0.14)
	_board = Layout.outlined_label("", 16, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_board.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_board_panel = PanelContainer.new()
	var board_box := StyleBoxFlat.new()
	board_box.bg_color = Color(0.04, 0.08, 0.1, 0.55)
	board_box.border_color = TRACK_ACCENT
	board_box.set_border_width_all(1)
	board_box.set_corner_radius_all(8)
	board_box.content_margin_left = 10
	board_box.content_margin_right = 10
	board_box.content_margin_top = 8
	board_box.content_margin_bottom = 8
	_board_panel.add_theme_stylebox_override("panel", board_box)
	root.add_child(_board_panel)
	Layout.apply_frac(_board_panel, 0.72, 0.12, 0.25, 0.4)
	_board_panel.add_child(_board)
	_board_panel.visible = false
	var hint = Chrome.make_hint_strip()
	root.add_child(hint)
	Layout.apply_frac(hint, 0.18, 0.935, 0.64, 0.045)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	hint.add_child(row)
	row.add_child(InputHint.make("accelerate", "ACELERAR", TRACK_ACCENT))
	row.add_child(InputHint.make("steer", "GIRO", TRACK_ACCENT))
	row.add_child(InputHint.make("drift", "DRIFT", TRACK_ACCENT))
	row.add_child(InputHint.make("pause", "PAUSA", TRACK_ACCENT))
	_prompt = row


func _build_setup() -> void:
	_setup = Control.new()
	Layout.bind_full(_setup)
	add_child(_setup)
	var wash := ColorRect.new()
	wash.color = Color(0.02, 0.04, 0.06, 0.72)
	Layout.bind_full(wash)
	_setup.add_child(wash)
	var card = Chrome.make_setup_card()
	_setup.add_child(card)
	Layout.apply_frac(card, 0.32, 0.16, 0.36, 0.68)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)
	box.add_child(Layout.outlined_label("TRACK", 30, TRACK_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(Chrome.make_accent_bar())
	box.add_child(Layout.outlined_label("Elegí largo y dificultad", 15, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_seed_label = Layout.outlined_label("Pista #—", 12, Color(ThemeRef.MUTED.r, ThemeRef.MUTED.g, ThemeRef.MUTED.b, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_seed_label)
	box.add_child(Layout.outlined_label("LARGO", 11, TRACK_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_choice_row(["corta", "media", "larga"], true))
	box.add_child(Layout.outlined_label("DIFICULTAD", 11, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_choice_row(["tranqui", "picante", "demente"], false))
	var play = GoldButton.new()
	play.configure("GENERAR Y CORRER", Vector2(280, 52))
	play.pressed.connect(func():
		hide_setup()
		play_pressed.emit(_length, _diff)
	)
	box.add_child(play)
	var secondary := HBoxContainer.new()
	secondary.alignment = BoxContainer.ALIGNMENT_CENTER
	secondary.add_theme_constant_override("separation", 10)
	box.add_child(secondary)
	var otra = GoldButton.new()
	otra.configure("OTRA", Vector2(140, 42))
	otra.pressed.connect(func(): otra_pressed.emit())
	secondary.add_child(otra)
	var back = GoldButton.new()
	back.configure("VOLVER AL HUB", Vector2(200, 42))
	back.pressed.connect(func(): hub_pressed.emit())
	secondary.add_child(back)


func _choice_row(ids: Array, is_length: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for id in ids:
		var btn = GoldButton.new()
		btn.configure(str(id).to_upper(), Vector2(110, 40))
		var captured := str(id)
		btn.pressed.connect(func():
			if is_length:
				_length = captured
			else:
				_diff = captured
		)
		row.add_child(btn)
	return row


func _build_pause() -> void:
	_pause = Control.new()
	_pause.visible = false
	Layout.bind_full(_pause)
	add_child(_pause)
	var wash := ColorRect.new()
	wash.color = Color(0.02, 0.01, 0.05, 0.82)
	Layout.bind_full(wash)
	_pause.add_child(wash)
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.04, 0.09, 0.96)
	card_style.border_color = Color("#c084fc")
	card_style.set_border_width_all(2)
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 18
	card_style.corner_radius_bottom_right = 8
	card_style.corner_radius_bottom_left = 18
	card_style.content_margin_left = 28
	card_style.content_margin_right = 28
	card_style.content_margin_top = 22
	card_style.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", card_style)
	_pause.add_child(card)
	Layout.apply_frac(card, 0.34, 0.28, 0.32, 0.44)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	box.add_child(Layout.outlined_label("PAUSA", 34, Color("#f5c542"), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(Layout.outlined_label("TRACK", 14, Color("#c084fc"), HORIZONTAL_ALIGNMENT_CENTER))
	var resume = GoldButton.new()
	resume.configure("SEGUIR", Vector2(220, 48))
	resume.pressed.connect(func():
		show_pause(false)
		resume_pressed.emit()
	)
	box.add_child(resume)
	var hub = GoldButton.new()
	hub.configure("VOLVER AL HUB", Vector2(220, 44))
	hub.pressed.connect(func(): hub_pressed.emit())
	box.add_child(hub)
	var nxt = GoldButton.new()
	nxt.configure("SIGUIENTE TURNO", Vector2(220, 44))
	nxt.pressed.connect(func():
		show_pause(false)
		next_pressed.emit()
	)
	box.add_child(nxt)
	var otra = GoldButton.new()
	otra.configure("OTRA PISTA", Vector2(220, 44))
	otra.pressed.connect(func():
		show_pause(false)
		otra_pressed.emit()
	)
	box.add_child(otra)
