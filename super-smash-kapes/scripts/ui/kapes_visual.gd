class_name KapesVisual
extends RefCounted

const NIGHT := Color("#070a13")
const MIDNIGHT := Color("#10182a")
const INK := Color("#151d31")
const RED := Color("#d93b35")
const RED_BRIGHT := Color("#f05a3c")
const BLUE := Color("#2875b9")
const BLUE_BRIGHT := Color("#55a8ff")
const WHITE := Color("#f5f0df")
const GOLD := Color("#f5c66b")
const AMBER := Color("#e0a84b")
const MUTED := Color("#9daac4")

const KAPES_RED := RED
const KAPES_BLUE := BLUE
const KAPES_WHITE := WHITE
const KAPES_GOLD := GOLD
const KAPES_NAVY := NIGHT
const KAPES_BLACK := Color("#02040a")
const KAPES_MUTED := MUTED

const P1_COLOR := RED_BRIGHT
const P2_COLOR := BLUE_BRIGHT
const P3_COLOR := GOLD
const P4_COLOR := Color("#7fd46a")

const SAFE_MARGIN_X := 0.055
const SAFE_MARGIN_Y := 0.05
const TITLE_SCALE := 0.40
const BUTTON_SCALE := 0.38
const HUD_WIDTH_RATIO := 0.29
const HUD_HEIGHT_RATIO := 0.162
const RESULTS_HERO_RATIO := 0.46
const RESULTS_STATS_RATIO := 0.24
const RESULTS_WINNER_HEIGHT_RATIO := 0.63

const FAST_MOTION := 0.12
const NORMAL_MOTION := 0.22
const SCREEN_TRANSITION := 0.34
const OUTLINE_WIDTH := 5
const GOLD_EDGE_WIDTH := 3

static func player_color(player_id: int) -> Color:
	match player_id:
		1:
			return P1_COLOR
		2:
			return P2_COLOR
		3:
			return P3_COLOR
		4:
			return P4_COLOR
	return WHITE

static func damage_color(damage_percent: float) -> Color:
	## Visual emphasis only — does not change damage numbers.
	if damage_percent >= 150.0:
		return RED_BRIGHT  # DANGER
	if damage_percent >= 100.0:
		return Color("#ff7a3c")  # HIGH
	if damage_percent >= 50.0:
		return GOLD  # MEDIUM
	if damage_percent >= 20.0:
		return Color("#fff2d8")  # LOW-MID
	return WHITE  # LOW

static func panel_style(fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style

static func button_styles() -> Dictionary:
	return {
		"normal": panel_style(Color(0.03, 0.05, 0.10, 0.82), MUTED, 2),
		"hover": panel_style(Color(0.72, 0.16, 0.13, 0.94), GOLD, 3),
		"focus": panel_style(Color(0.72, 0.16, 0.13, 0.94), GOLD, 4),
		"pressed": panel_style(Color(0.32, 0.08, 0.08, 0.98), WHITE, 3),
	}

static func apply_button_theme(button: Button, font_size: int) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", GOLD)
	var styles := button_styles()
	button.add_theme_stylebox_override("normal", styles["normal"])
	button.add_theme_stylebox_override("hover", styles["hover"])
	button.add_theme_stylebox_override("focus", styles["focus"])
	button.add_theme_stylebox_override("pressed", styles["pressed"])
