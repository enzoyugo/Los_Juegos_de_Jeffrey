class_name JeffreyTheme
extends RefCounted

## First-party design tokens for Los Juegos de Jeffrey UI System V1.
## Builds on GlobalShellTheme; do not scatter magic numbers in screens.

const Base := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")

const DESIGN := Vector2(1920.0, 1080.0)

const DURATION_FAST := 0.08
const DURATION_NORMAL := 0.14
const DURATION_SCREEN := 0.18

const RADIUS_SM := 6.0
const RADIUS_MD := 10.0
const RADIUS_LG := 14.0

const SPACE_XS := 6.0
const SPACE_SM := 10.0
const SPACE_MD := 16.0
const SPACE_LG := 24.0
const SPACE_XL := 32.0

## Shared type ladder — prefer these over per-screen magic sizes.
const TYPE_H1 := Base.SIZE_GAME_TITLE ## 56 — screen brand / hero
const TYPE_H2 := Base.SIZE_SCREEN_TITLE ## 42 — screen title
const TYPE_CARD := Base.SIZE_MODE_TITLE ## 28 — card / mode title
const TYPE_BODY := Base.SIZE_BODY ## 18
const TYPE_SECONDARY := Base.SIZE_HELPER ## 16
const TYPE_HUD_PRIMARY := 36
const TYPE_HUD_SECONDARY := 16

const BTN_MIN := Vector2(140, 44)
const BTN_PRIMARY := Vector2(180, 52)
const BTN_BACK := Vector2(180, 64)

const FOCUS_SCALE := 1.04
const HOVER_SCALE := 1.02
const PRESS_SCALE := 0.96

const MODE_SMASH := "smash"
const MODE_RACING := "racing"
const MODE_ZOMBIES := "zombies"


static func mode_accent(mode_id: String) -> Color:
	match mode_id:
		MODE_SMASH:
			return Color("#d94a4a")
		MODE_RACING:
			return Color("#3db8c9")
		MODE_ZOMBIES:
			return Color("#4caf63")
		_:
			return Base.GOLD


static func panel_style(accent: Color = Base.GOLD, alpha: float = 0.92) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Base.SURFACE.r, Base.SURFACE.g, Base.SURFACE.b, alpha)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.72)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.corner_radius_top_left = int(RADIUS_MD)
	box.corner_radius_top_right = int(RADIUS_MD)
	box.corner_radius_bottom_left = int(RADIUS_MD)
	box.corner_radius_bottom_right = int(RADIUS_MD)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 3)
	box.content_margin_left = SPACE_MD
	box.content_margin_right = SPACE_MD
	box.content_margin_top = SPACE_SM
	box.content_margin_bottom = SPACE_SM
	return box


static func button_style(kind: String, lit: bool, disabled: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var accent := Base.GOLD
	var hot := Base.GOLD_HOT
	match kind:
		"danger":
			accent = Base.DANGER
			hot = Color("#ff8080")
		"secondary":
			accent = Base.STROKE
			hot = Base.ACCENT
	box.bg_color = Color("#07080c") if not disabled else Color("#12141a")
	box.border_color = hot if lit and not disabled else Color(accent.r, accent.g, accent.b, 0.85 if not disabled else 0.35)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 3
	box.corner_radius_top_left = int(RADIUS_SM)
	box.corner_radius_top_right = int(RADIUS_SM)
	box.corner_radius_bottom_left = int(RADIUS_SM)
	box.corner_radius_bottom_right = int(RADIUS_SM)
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.shadow_size = 4 if lit else 2
	box.shadow_offset = Vector2(0, 2)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


static func apply_button_font(button: Button, lit: bool, disabled: bool = false) -> void:
	var color := Base.GOLD_HOT if lit and not disabled else Base.GOLD
	if disabled:
		color = Base.MUTED
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", Base.GOLD_HOT)
	button.add_theme_color_override("font_focus_color", Base.GOLD_HOT)
	button.add_theme_color_override("font_pressed_color", Base.GOLD)
	button.add_theme_color_override("font_disabled_color", Base.MUTED)
	button.add_theme_font_size_override("font_size", Base.SIZE_BODY)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	button.add_theme_constant_override("outline_size", 5)
