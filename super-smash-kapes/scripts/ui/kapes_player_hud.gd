class_name KapesPlayerHUD
extends Control

const P1_PLATE_PATH := "res://assets/ui/hud/hud_p1.png"
const P2_PLATE_PATH := "res://assets/ui/hud/hud_p2.png"
const UILayout := preload("res://scripts/ui/kapes_ui_layout.gd")
const HUD_LAYOUT := preload("res://scripts/ui/kapes_hud_layout.gd")
const PORTRAIT_UTIL := preload("res://scripts/ui/kapes_portrait.gd")

@export var player_id: int = 1
@export var accent_color: Color = KapesVisual.P1_COLOR

var plate: TextureRect
var portrait_mask: Control
var portrait: TextureRect
var name_label: Label
var damage_label: Label
var last_damage: float = -1.0
var stocks: int = 3
var displayed_stocks: int = 3
var _damage_tween: Tween
var _stock_tween: Tween

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate = TextureRect.new()
	plate.texture = _load_plate()
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	plate.focus_mode = Control.FOCUS_NONE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.z_index = -1
	add_child(plate)

	portrait_mask = Control.new()
	portrait_mask.name = "PortraitMask"
	portrait_mask.clip_contents = true
	portrait_mask.focus_mode = Control.FOCUS_NONE
	portrait_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait_mask)

	portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.focus_mode = Control.FOCUS_NONE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_mask.add_child(portrait)

	name_label = _make_label(Vector2.ZERO, 22, accent_color)
	name_label.name = "FighterName"
	name_label.text = "P%d" % player_id
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if player_id == 1 else HORIZONTAL_ALIGNMENT_RIGHT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	damage_label = _make_label(Vector2.ZERO, 76, KapesVisual.WHITE)
	damage_label.text = "0%"
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if player_id == 1 else HORIZONTAL_ALIGNMENT_LEFT
	damage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	resized.connect(_apply_layout)
	call_deferred("_apply_layout")

func _load_plate() -> Texture2D:
	var path := P1_PLATE_PATH if player_id == 1 else P2_PLATE_PATH
	if not ResourceLoader.exists(path):
		push_warning("[HUD] missing plate %s — battle HUD art skipped; scripts still compile" % path)
		return null
	var loaded: Resource = load(path)
	if loaded is Texture2D:
		return loaded as Texture2D
	push_warning("[HUD] failed to load plate %s — battle HUD art skipped; scripts still compile" % path)
	return null


func _apply_layout() -> void:
	var portrait_region := HUD_LAYOUT.p1_portrait_region() if player_id == 1 else HUD_LAYOUT.p2_portrait_region()
	var name_region := HUD_LAYOUT.p1_name_region() if player_id == 1 else HUD_LAYOUT.p2_name_region()
	var damage_region := HUD_LAYOUT.p1_damage_region() if player_id == 1 else HUD_LAYOUT.p2_damage_region()
	var portrait_rect := HUD_LAYOUT.region(size, portrait_region)
	var name_rect := HUD_LAYOUT.region(size, name_region)
	var damage_rect := HUD_LAYOUT.region(size, damage_region)
	portrait_mask.position = portrait_rect.position
	portrait_mask.size = portrait_rect.size
	if name_label != null:
		name_label.position = name_rect.position
		name_label.size = name_rect.size
		name_label.add_theme_font_size_override("font_size", UILayout.font_size(get_viewport(), int(size.y * 0.16)))
	damage_label.position = damage_rect.position
	damage_label.size = damage_rect.size
	damage_label.pivot_offset = damage_rect.size * 0.5
	var font_size: int = UILayout.font_size(get_viewport(), int(size.y * 0.36))
	damage_label.add_theme_font_size_override("font_size", font_size)

func _make_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.9))
	label.add_theme_constant_override("outline_size", KapesVisual.OUTLINE_WIDTH)
	label.focus_mode = Control.FOCUS_NONE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func update_fighter(fighter: Fighter) -> void:
	if name_label != null and fighter.has_method("get_display_name"):
		name_label.text = fighter.get_display_name()
	if fighter.definition != null and fighter.definition.portrait_texture != null:
		portrait.texture = PORTRAIT_UTIL.get_hud_portrait(fighter.definition.portrait_texture)
	var changed := last_damage >= 0.0 and not is_equal_approx(last_damage, fighter.damage_percent)
	var stock_changed := stocks != fighter.stocks
	last_damage = fighter.damage_percent
	stocks = fighter.stocks
	damage_label.text = "%d%%" % roundi(fighter.damage_percent)
	damage_label.add_theme_color_override("font_color", KapesVisual.damage_color(fighter.damage_percent))
	_apply_layout()
	if changed:
		if _damage_tween != null:
			_damage_tween.kill()
		var punch := 1.14 if fighter.damage_percent < 100.0 else 1.20
		damage_label.scale = Vector2(punch, punch)
		_damage_tween = create_tween()
		_damage_tween.tween_property(damage_label, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if stock_changed:
		displayed_stocks = fighter.stocks
		if _stock_tween != null:
			_stock_tween.kill()
		_stock_tween = create_tween()
		_stock_tween.tween_property(self, "modulate", Color(1.2, 0.92, 0.92, 1.0) if player_id == 1 else Color(0.92, 1.05, 1.2, 1.0), 0.06)
		_stock_tween.tween_property(self, "modulate", Color.WHITE, 0.10)
		queue_redraw()

func _draw() -> void:
	_draw_stock_sockets()

func _draw_stock_sockets() -> void:
	var stock_region := HUD_LAYOUT.p1_stock_region() if player_id == 1 else HUD_LAYOUT.p2_stock_region()
	var stock_rect := HUD_LAYOUT.region(size, stock_region)
	var offsets := HUD_LAYOUT.stock_socket_offsets(player_id)
	var pip_r := size.y * 0.028
	var center_y := stock_rect.position.y + stock_rect.size.y * 0.42
	for index in range(3):
		var center_x := stock_rect.position.x + stock_rect.size.x * offsets[index]
		var filled := index < displayed_stocks
		var fill_color := accent_color if filled else Color(accent_color.r, accent_color.g, accent_color.b, 0.16)
		draw_circle(Vector2(center_x, center_y), pip_r, fill_color)
		draw_arc(Vector2(center_x, center_y), pip_r, 0.0, TAU, 24, Color(1, 1, 1, 0.55 if filled else 0.25), 2.0, true)
