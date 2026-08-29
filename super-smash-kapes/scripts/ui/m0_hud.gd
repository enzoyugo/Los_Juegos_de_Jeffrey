extends CanvasLayer

const PLAYER_CARD := preload("res://scripts/ui/kapes_player_hud.gd")
const UI_LAYERS := preload("res://scripts/ui/kapes_layers.gd")
const UILayout := preload("res://scripts/ui/kapes_ui_layout.gd")

var p1_card: KapesPlayerHUD
var p2_card: KapesPlayerHUD
var intro_layer: CanvasLayer
var message_label: Label
var intro_accent: ColorRect
var message_tween: Tween
var performance_label: Label
var performance_debug_enabled: bool = false

func _ready() -> void:
	if OS.get_environment("SSK_FREEZE_AUDIT") == "1":
		print("[FREEZE_AUDIT] HUD ready")
	layer = UI_LAYERS.HUD
	intro_layer = CanvasLayer.new()
	intro_layer.layer = UI_LAYERS.MATCH_INTRO
	add_child(intro_layer)
	p1_card = PLAYER_CARD.new()
	p1_card.player_id = 1
	p1_card.accent_color = KapesVisual.P1_COLOR
	add_child(p1_card)
	p2_card = PLAYER_CARD.new()
	p2_card.player_id = 2
	p2_card.accent_color = KapesVisual.P2_COLOR
	add_child(p2_card)
	intro_accent = ColorRect.new()
	intro_accent.color = Color(KapesVisual.KAPES_RED.r, KapesVisual.KAPES_RED.g, KapesVisual.KAPES_RED.b, 0.0)
	intro_accent.focus_mode = Control.FOCUS_NONE
	intro_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_layer.add_child(intro_accent)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", KapesVisual.WHITE)
	message_label.add_theme_color_override("font_outline_color", KapesVisual.NIGHT)
	message_label.add_theme_constant_override("outline_size", 8)
	message_label.focus_mode = Control.FOCUS_NONE
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.modulate.a = 0.0
	intro_layer.add_child(message_label)
	performance_label = _make_label(Vector2(24, 24), 15, Color("#b8c7dc"))
	performance_label.visible = false
	get_viewport().size_changed.connect(_apply_layout)
	call_deferred("_apply_layout")

func _process(_delta: float) -> void:
	if not performance_debug_enabled:
		return
	performance_label.text = "F3 PERF  FPS %.1f  FRAME %.2fms  NODES %d  OBJECTS %d  RES %d  VRAM %.1fMB  TEX %.1fMB" % [
		Engine.get_frames_per_second(),
		get_process_delta_time() * 1000.0,
		get_tree().get_node_count(),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0),
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / (1024.0 * 1024.0),
	]

func set_performance_debug(enabled: bool) -> void:
	performance_debug_enabled = enabled
	performance_label.visible = enabled

func _apply_layout() -> void:
	var safe: Rect2 = UILayout.safe_rect(get_viewport())
	var card_w := safe.size.x * KapesVisual.HUD_WIDTH_RATIO
	var card_h := safe.size.y * KapesVisual.HUD_HEIGHT_RATIO
	var bottom_pad := safe.size.y * 0.02
	var side_pad := safe.size.x * 0.012
	p1_card.size = Vector2(card_w, card_h)
	p2_card.size = Vector2(card_w, card_h)
	p1_card.position = Vector2(safe.position.x + side_pad, safe.position.y + safe.size.y - card_h - bottom_pad)
	p2_card.position = Vector2(safe.position.x + safe.size.x - card_w - side_pad, safe.position.y + safe.size.y - card_h - bottom_pad)
	p1_card.queue_redraw()
	p2_card.queue_redraw()
	var intro_font: int = UILayout.font_size(get_viewport(), 118)
	message_label.add_theme_font_size_override("font_size", intro_font)
	message_label.size = Vector2(safe.size.x * 0.72, intro_font * 1.35)
	message_label.position = Vector2(
		safe.position.x + safe.size.x * 0.5 - message_label.size.x * 0.5,
		safe.position.y + safe.size.y * 0.36 - message_label.size.y * 0.5
	)
	intro_accent.size = Vector2(safe.size.x * 0.34, 8.0)
	intro_accent.position = Vector2(
		safe.position.x + safe.size.x * 0.5 - intro_accent.size.x * 0.5,
		message_label.position.y + message_label.size.y * 0.72
	)

func _make_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.focus_mode = Control.FOCUS_NONE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func update_fighter(fighter: Fighter) -> void:
	if fighter.player_id == 1:
		p1_card.update_fighter(fighter)
	else:
		p2_card.update_fighter(fighter)

func set_message(text: String) -> void:
	if message_tween != null:
		message_tween.kill()
	message_label.text = text
	var is_intro := text.contains("DALE")
	var is_ko := text == "KO" or text.begins_with("KO")
	var is_win := text.contains("GANA") or text.contains("VICTORIA")
	_apply_layout()
	message_label.modulate.a = 1.0
	message_label.scale = Vector2(1.22, 1.22) if (is_intro or is_ko or is_win) else Vector2.ONE
	if is_ko:
		message_label.add_theme_color_override("font_color", KapesVisual.RED_BRIGHT)
		intro_accent.color = Color(KapesVisual.KAPES_RED.r, KapesVisual.KAPES_RED.g, KapesVisual.KAPES_RED.b, 0.0)
	elif is_win:
		message_label.add_theme_color_override("font_color", KapesVisual.GOLD)
		intro_accent.color = Color(KapesVisual.GOLD.r, KapesVisual.GOLD.g, KapesVisual.GOLD.b, 0.0)
	else:
		message_label.add_theme_color_override("font_color", KapesVisual.WHITE)
		intro_accent.color = Color(KapesVisual.KAPES_RED.r, KapesVisual.KAPES_RED.g, KapesVisual.KAPES_RED.b, 0.0)
	if not (is_intro or is_ko or is_win):
		return
	intro_accent.color.a = 0.0
	message_tween = create_tween()
	if OS.get_environment("SSK_FREEZE_AUDIT") == "1":
		print("[FREEZE_AUDIT] intro tween started")
	message_tween.tween_property(intro_accent, "color:a", 0.75, 0.08)
	message_tween.parallel().tween_property(message_label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var hold := 0.28 if is_ko else (0.55 if is_win else 0.36)
	message_tween.tween_interval(hold)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.18)
	message_tween.parallel().tween_property(intro_accent, "color:a", 0.0, 0.18)
	message_tween.tween_callback(func():
		if OS.get_environment("SSK_FREEZE_AUDIT") == "1":
			print("[FREEZE_AUDIT] intro tween finished")
	)


func show_ko_flash(_player_id: int, accent: Color) -> void:
	message_label.add_theme_color_override("font_color", accent)
	message_label.add_theme_constant_override("outline_size", 14)
	intro_accent.color = Color(accent.r, accent.g, accent.b, 0.0)
	set_message("KO")
