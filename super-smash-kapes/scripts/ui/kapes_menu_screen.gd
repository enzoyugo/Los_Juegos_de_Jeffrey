class_name KapesMenuScreen
extends Control

const UILayout := preload("res://scripts/ui/kapes_ui_layout.gd")

signal battle_pressed

const MENU_BACKGROUND_PATH := "res://assets/ui/menu/main_menu_bg.png"
const GAME_LOGO_PATH := "res://assets/ui/menu/smash_kapes_logo.png"
const LOCAL_BATTLE_PANEL_PATH := "res://assets/ui/menu/local_battle_panel.png"
const LOGO_SOURCE_SIZE := Vector2(1448.0, 1086.0)
const PANEL_SOURCE_SIZE := Vector2(1448.0, 1086.0)

var _background: TextureRect
var _logo: TextureRect
var _battle_panel: TextureRect
var _play_button: Button
var _hint: Label
var _accent: ColorRect
var _focus_tween: Tween

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UILayout.bind_full_rect(self)
	_build_nodes()
	resized.connect(_apply_layout)
	_apply_layout()
	_play_entrance()

func _build_nodes() -> void:
	_background = TextureRect.new()
	_background.name = "MenuBackground"
	_background.texture = load(MENU_BACKGROUND_PATH) as Texture2D
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.focus_mode = Control.FOCUS_NONE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_accent = ColorRect.new()
	_accent.name = "TricolorAccent"
	_accent.color = Color(KapesVisual.RED.r, KapesVisual.RED.g, KapesVisual.RED.b, 0.0)
	_accent.focus_mode = Control.FOCUS_NONE
	_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_accent)

	_logo = _make_art_rect(load(GAME_LOGO_PATH) as Texture2D)
	_logo.name = "GameLogo"
	add_child(_logo)

	_battle_panel = _make_art_rect(load(LOCAL_BATTLE_PANEL_PATH) as Texture2D)
	_battle_panel.name = "LocalBattlePanel"
	add_child(_battle_panel)

	_play_button = Button.new()
	_play_button.name = "LocalBattleArtworkButton"
	_play_button.flat = true
	_play_button.focus_mode = Control.FOCUS_ALL
	_play_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_play_button.modulate = Color(1, 1, 1, 0.01)
	_play_button.pressed.connect(func(): battle_pressed.emit())
	_play_button.focus_entered.connect(_on_play_focus_entered)
	_play_button.focus_exited.connect(_on_play_focus_exited)
	add_child(_play_button)

	_hint = Label.new()
	_hint.name = "PlayHint"
	_hint.text = "F / SPACE — JUGAR"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.focus_mode = Control.FOCUS_NONE
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override("font_color", KapesVisual.GOLD)
	add_child(_hint)

func _make_art_rect(texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.focus_mode = Control.FOCUS_NONE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func _apply_layout() -> void:
	UILayout.bind_full_rect(_background)
	var safe := UILayout.safe_rect(get_viewport())
	var safe_w := safe.size.x
	var safe_h := safe.size.y

	var logo_max := Vector2(safe_w * 0.42, safe_h * 0.58)
	var logo_size := UILayout.contain_size(LOGO_SOURCE_SIZE, logo_max)
	_logo.size = logo_size
	_logo.pivot_offset = logo_size * 0.5
	_logo.position = Vector2(
		safe.position.x + safe_w * 0.04,
		safe.position.y + safe_h * 0.5 - logo_size.y * 0.52
	)

	var panel_max := Vector2(safe_w * 0.36, safe_h * 0.64)
	var panel_size := UILayout.contain_size(PANEL_SOURCE_SIZE, panel_max)
	_battle_panel.size = panel_size
	_battle_panel.pivot_offset = panel_size * 0.5
	_battle_panel.position = Vector2(
		safe.position.x + safe_w - panel_size.x - safe_w * 0.04,
		safe.position.y + safe_h * 0.5 - panel_size.y * 0.5
	)

	_play_button.position = _battle_panel.position
	_play_button.size = _battle_panel.size

	var hint_font := UILayout.font_size(get_viewport(), 18)
	_hint.add_theme_font_size_override("font_size", hint_font)
	_hint.size = Vector2(safe_w * 0.5, hint_font * 1.8)
	_hint.position = Vector2(
		safe.position.x + safe_w * 0.5 - _hint.size.x * 0.5,
		safe.position.y + safe_h - _hint.size.y - safe_h * 0.02
	)

	_accent.position = Vector2(safe.position.x, safe.position.y + safe_h * 0.08)
	_accent.size = Vector2(safe_w, 6.0)

func _play_entrance() -> void:
	_logo.modulate.a = 0.0
	_logo.scale = Vector2(0.94, 0.94)
	_battle_panel.modulate.a = 0.0
	_battle_panel.scale = Vector2(0.96, 0.96)
	_hint.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_accent, "color:a", 0.55, 0.10)
	tween.parallel().tween_property(_logo, "modulate:a", 1.0, KapesVisual.NORMAL_MOTION).set_delay(0.08)
	tween.parallel().tween_property(_logo, "scale", Vector2.ONE, 0.28).from(Vector2(0.94, 0.94)).set_delay(0.08).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_battle_panel, "modulate:a", 1.0, KapesVisual.NORMAL_MOTION)
	tween.parallel().tween_property(_battle_panel, "scale", Vector2.ONE, 0.24).from(Vector2(0.96, 0.96)).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_hint, "modulate:a", 0.82, 0.16)
	tween.parallel().tween_property(_accent, "color:a", 0.0, 0.20)
	tween.tween_callback(func(): _play_button.grab_focus())

func _on_play_focus_entered() -> void:
	if _focus_tween != null:
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.tween_property(_battle_panel, "scale", Vector2(1.025, 1.025), KapesVisual.FAST_MOTION).set_trans(Tween.TRANS_BACK)
	_focus_tween.parallel().tween_property(_battle_panel, "modulate", Color(1.08, 1.05, 0.96, 1.0), KapesVisual.FAST_MOTION)

func _on_play_focus_exited() -> void:
	if _focus_tween != null:
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.tween_property(_battle_panel, "scale", Vector2.ONE, KapesVisual.FAST_MOTION)
	_focus_tween.parallel().tween_property(_battle_panel, "modulate", Color.WHITE, KapesVisual.FAST_MOTION)
