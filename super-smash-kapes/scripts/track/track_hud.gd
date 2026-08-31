class_name TrackHUD
extends CanvasLayer

const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const Typography := preload("res://scripts/ui/jeffrey/system/jeffrey_typography.gd")
const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const Styles := preload("res://scripts/ui/jeffrey/global_ui_styles.gd")
const GoldButton := preload("res://scripts/ui/jeffrey/gold_action_button.gd")
const Chrome := preload("res://scripts/track/track_hud_chrome_v1.gd")
const InputHint := preload("res://scripts/ui/jeffrey/components/jeffrey_input_hint.gd")

const HUD_POSITION := "res://assets/ui/track/hud_v2/position_block.png"
const HUD_TIMER := "res://assets/ui/track/hud_v2/timer_block.png"
const HUD_FUEL := "res://assets/ui/track/hud_v2/fuel_player_block.png"
const HUD_SPEED := "res://assets/ui/track/hud_v2/speedometer_block.png"
const PAUSE_PANEL := "res://assets/ui/track/pause_v2/pause_panel.png"
const PAUSE_TITLE := "res://assets/ui/track/pause_v2/pause_title.png"
const PAUSE_BUTTON := "res://assets/ui/track/pause_v2/pause_button.png"
const PAUSE_BUTTON_REGIONS := [
	Rect2(48, 393, 929, 169),
	Rect2(49, 577, 927, 166),
	Rect2(49, 757, 928, 169),
	Rect2(49, 943, 927, 167),
]
const FUEL_LABEL := "COMBUSTIBLE"

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
var _speed: Label
var _seed: Label
var _setup: Control
var _pause: Control
var _board_panel: PanelContainer
var _length: String = "media"
var _diff: String = "picante"
var _seed_label: Label
var _status_pulse: float = 0.0
var _check_flash: float = 0.0
var _position_value: Label
var _speed_value: Label
var _fuel_stack: VBoxContainer
var _fuel_rows: Dictionary = {}
var _active_fuel_key: String = ""


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
	## PUESTO owns the identity area; the fuel cards are the single racer roster.
	_driver.visible = false
	_active_fuel_key = person if not person.is_empty() else slot_tag
	if not _fuel_rows.has(_active_fuel_key) and not _fuel_rows.is_empty():
		var keys: Array = _fuel_rows.keys()
		_active_fuel_key = str(keys[mini(maxi(slot - 1, 0), keys.size() - 1)])
	if _fuel_rows.is_empty():
		_ensure_fuel_row(_active_fuel_key, _fuel_color(maxi(slot - 1, 0)))


func set_racer_roster(rows: Array) -> void:
	for i in rows.size():
		var row = rows[i]
		if not (row is Dictionary):
			continue
		var name_text := str(row.get("display_name", row.get("name", row.get("profile_id", "P%d" % (i + 1))))).strip_edges().to_upper()
		if name_text.is_empty():
			name_text = "P%d" % (i + 1)
		var slot := int(row.get("player_slot", i + 1))
		_ensure_fuel_row(name_text, _fuel_color(maxi(slot - 1, 0)))


func set_timer(seconds: float) -> void:
	if _timer != null:
		_timer.text = _fmt(seconds)


func set_best(seconds: float) -> void:
	if _best == null:
		return
	if seconds < 0.0:
		_best.text = "—"
	else:
		_best.text = _fmt(seconds)


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
	if _fuel == null and _fuel_stack == null:
		return
	var key := _active_fuel_key
	if key.is_empty():
		key = player_name.strip_edges().to_upper()
	if key.is_empty():
		key = "PLAYER"
	if not _fuel_rows.has(key) and _fuel_rows.is_empty():
		_ensure_fuel_row(key, _fuel_color(_fuel_rows.size()))
	var row: Dictionary = _fuel_rows.get(key, {})
	var label: Label = row.get("label")
	var fill: ColorRect = row.get("fill")
	if label != null:
		label.text = key if not last_dance else "%s  ·  RENDICIÓN" % key
	if fill != null:
		fill.size.x = 117.0 * clampf(seconds / 30.0, 0.0, 1.0)


func set_rank(rank: int, total: int) -> void:
	if _rank != null:
		_rank.text = "PUESTO  %d / %d" % [rank, total] if rank > 0 else ""
	if _position_value != null:
		_position_value.text = "%d / %d" % [rank, total] if rank > 0 else "— / %d" % total


func set_speed(meters_per_second: float) -> void:
	if _speed != null:
		_speed.text = "%03d" % maxi(int(round(maxf(meters_per_second, 0.0) * 3.6)), 0)
	if _speed_value != null:
		_speed_value.text = "%03d" % maxi(int(round(maxf(meters_per_second, 0.0) * 3.6)), 0)


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
	root.theme = Typography.theme_for(Typography.TRACK)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var timer_panel := _asset(root, HUD_TIMER, Vector2(720, 0), Vector2(480, 360))
	var brand := Layout.outlined_label("TRACK", 15, TRACK_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	brand.position = Vector2(150, 34)
	brand.size = Vector2(180, 24)
	timer_panel.add_child(brand)
	var accent_bar := Chrome.make_accent_bar()
	accent_bar.position = Vector2(110, 68)
	accent_bar.size = Vector2(260, 6)
	timer_panel.add_child(accent_bar)
	_timer = Layout.outlined_label("0:00.00", 38, TRACK_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_timer.add_theme_font_size_override("font_size", 48)
	_timer.position = Vector2(50, 112)
	_timer.size = Vector2(380, 76)
	timer_panel.add_child(_timer)
	_best = Layout.outlined_label("—", 13, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_best.add_theme_font_size_override("font_size", 16)
	_best.position = Vector2(50, 220)
	_best.size = Vector2(380, 34)
	timer_panel.add_child(_best)

	var position_panel := _asset(root, HUD_POSITION, Vector2(40, 24), Vector2(260, 195))
	_position_value = Layout.outlined_label("— / —", 26, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_position_value.position = Vector2(112, 73)
	_position_value.size = Vector2(123, 30)
	position_panel.add_child(_position_value)
	_driver = Layout.outlined_label("", 12, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	_driver.position = Vector2(17, 133)
	_driver.size = Vector2(217, 22)
	position_panel.add_child(_driver)
	_fuel_stack = VBoxContainer.new()
	_fuel_stack.position = Vector2(1630, 24)
	_fuel_stack.size = Vector2(280, 600)
	_fuel_stack.add_theme_constant_override("separation", -130)
	root.add_child(_fuel_stack)

	_check = Layout.outlined_label("", 13, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	_check.visible = false
	_check.position = Vector2(57, 97)
	_check.size = Vector2(188, 22)
	root.add_child(_check)
	_rank = Layout.outlined_label("", 13, TRACK_ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	_rank.visible = false
	_rank.position = Vector2(148, 97)
	_rank.size = Vector2(188, 22)
	root.add_child(_rank)
	var speed_panel := _asset(root, HUD_SPEED, Vector2(1670, 885), Vector2(200, 150))
	_speed_value = Layout.outlined_label("000", 28, ThemeRef.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_speed_value.position = Vector2(71, 69)
	_speed_value.size = Vector2(83, 30)
	speed_panel.add_child(_speed_value)
	_speed = _speed_value

	_seed = Layout.outlined_label("", 13, ThemeRef.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	root.add_child(_seed)
	Layout.apply_frac(_seed, 0.03, 0.155, 0.20, 0.035)
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
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(image)
	return host


func _fuel_color(index: int) -> Color:
	return [Color("#e34845"), Color("#73c86b"), Color("#e8c34c"), Color("#58bfe0")][mini(index, 3)]


func _ensure_fuel_row(player_name: String, color: Color) -> void:
	if _fuel_rows.has(player_name) or _fuel_stack == null:
		return
	var card := Control.new()
	card.custom_minimum_size = Vector2(280, 210)
	var image := TextureRect.new()
	image.texture = load(HUD_FUEL)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(image)
	var label := Layout.outlined_label(player_name, 15, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	label.position = Vector2(67, 71)
	label.size = Vector2(195, 24)
	card.add_child(label)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2(73, 119)
	fill.size = Vector2(117, 8)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(fill)
	_fuel_stack.add_child(card)
	_fuel_rows[player_name] = {"label": label, "fill": fill}


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
	var card := Control.new()
	_pause.add_child(card)
	Layout.apply_frac(card, 0.32, 0.22, 0.36, 0.56)
	var panel_art := _asset(card, PAUSE_PANEL, Vector2.ZERO, Vector2(680, 510))
	var title_art := _asset(card, PAUSE_TITLE, Vector2(90, 18), Vector2(500, 145))
	var box := VBoxContainer.new()
	box.position = Vector2(100, 154)
	box.size = Vector2(480, 292)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	box.add_child(Layout.outlined_label("TRACK", 16, Color("#c084fc"), HORIZONTAL_ALIGNMENT_CENTER))
	var resume := _pause_button("CONTINUAR", 0)
	resume.pressed.connect(func():
		show_pause(false)
		resume_pressed.emit()
	)
	box.add_child(resume)
	var otra := _pause_button("REINTENTAR", 1)
	otra.pressed.connect(func():
		show_pause(false)
		otra_pressed.emit()
	)
	box.add_child(otra)
	var nxt := _pause_button("SIGUIENTE TURNO", 2)
	nxt.pressed.connect(func():
		show_pause(false)
		next_pressed.emit()
	)
	box.add_child(nxt)
	var hub := _pause_button("VOLVER AL HUB", 3)
	hub.pressed.connect(func(): hub_pressed.emit())
	box.add_child(hub)
	panel_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_art.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _pause_button(text_value: String, region_index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(480, 50)
	button.clip_contents = true
	button.focus_mode = Control.FOCUS_ALL
	var atlas := load(PAUSE_BUTTON)
	var frame := AtlasTexture.new()
	frame.atlas = atlas
	frame.region = PAUSE_BUTTON_REGIONS[region_index]
	var background := TextureRect.new()
	background.texture = frame
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = 0
	button.add_child(background)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	var label := Layout.outlined_label(text_value, 16, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 1
	button.add_child(label)
	return button
