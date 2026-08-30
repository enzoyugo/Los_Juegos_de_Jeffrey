class_name GlobalUiStyles
extends RefCounted

## Shared type styles and card/panel safe-zone fractions.
## Fractions are relative to the *visible* card/panel texture, not letterbox.
## Repeated lists must use these with Containers, not per-item coordinates.

const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")

## Portrait profile cards (1122×1402): painted nameplate sits near the bottom edge.
const NAMEPLATE_LEFT := 0.16
const NAMEPLATE_RIGHT := 0.84
const NAMEPLATE_TOP := 0.888
const NAMEPLATE_BOTTOM := 0.955
const PORTRAIT_LEFT := 0.26
const PORTRAIT_RIGHT := 0.74
const PORTRAIT_TOP := 0.16
const PORTRAIT_BOTTOM := 0.68

## Horizontal banner cards (1983×793) used by Edit Players / Mode Players.
const BANNER_PORTRAIT_LEFT := 0.05
const BANNER_PORTRAIT_RIGHT := 0.24
const BANNER_PORTRAIT_TOP := 0.20
const BANNER_PORTRAIT_BOTTOM := 0.72
const BANNER_NAME_LEFT := 0.30
const BANNER_NAME_RIGHT := 0.80
const BANNER_NAME_TOP := 0.30
const BANNER_NAME_BOTTOM := 0.58
const BANNER_STATUS_LEFT := 0.30
const BANNER_STATUS_RIGHT := 0.72
const BANNER_STATUS_TOP := 0.60
const BANNER_STATUS_BOTTOM := 0.74
const BANNER_CHECK_LEFT := 0.84
const BANNER_CHECK_RIGHT := 0.95
const BANNER_CHECK_TOP := 0.36
const BANNER_CHECK_BOTTOM := 0.64

## Character cards (1122×1402): portrait dominates; hex nameplate above stats.
const CHAR_PORTRAIT_LEFT := 0.14
const CHAR_PORTRAIT_RIGHT := 0.86
const CHAR_PORTRAIT_TOP := 0.10
const CHAR_PORTRAIT_BOTTOM := 0.66
const CHAR_NAMEPLATE_LEFT := 0.16
const CHAR_NAMEPLATE_RIGHT := 0.84
const CHAR_NAMEPLATE_TOP := 0.675
const CHAR_NAMEPLATE_BOTTOM := 0.775
const CHAR_CARD_MIN := Vector2(430, 538)

## Hub active-player painted rows (6 slots). Names only — P#/circles are in the art.
const HUB_ROW_AREA_TOP := 0.255
const HUB_ROW_AREA_BOTTOM := 0.930
const HUB_ROW_COUNT := 6
const HUB_NAME_LEFT := 0.24
const HUB_NAME_RIGHT := 0.70
const HUB_AVATAR_LEFT := 0.07
const HUB_AVATAR_RIGHT := 0.21

const ACTIVE_ROW_HEIGHT := 64.0
const AVATAR_WIDTH := 36.0
const NAME_LEFT_PAD := 14.0
const SLOT_BADGE_WIDTH := 48.0
const SLOT_RIGHT_PAD := 8.0

const SIZE_PROFILE := 15
const SIZE_CHARACTER := 26
const SIZE_PANEL_TITLE := 16
const SIZE_COUNTER := 22
const SIZE_STATUS := 15
const SIZE_BADGE := 13
const SIZE_HELPER := 14
const SIZE_TRANSITION := 22

const PORTRAIT_RATIO := 1122.0 / 1402.0
const BANNER_RATIO := 1983.0 / 793.0


static func apply(label: Label, kind: String) -> void:
	var size := SIZE_PROFILE
	var color: Color = ThemeRef.TEXT
	match kind:
		"panel_title":
			size = SIZE_PANEL_TITLE
			color = ThemeRef.GOLD
		"counter":
			size = SIZE_COUNTER
			color = ThemeRef.GOLD_HOT
		"status":
			size = SIZE_STATUS
			color = ThemeRef.TEXT
		"mode_badge":
			size = SIZE_BADGE
			color = ThemeRef.GOLD
		"small_helper":
			size = SIZE_HELPER
			color = ThemeRef.MUTED
		"transition_status":
			size = SIZE_TRANSITION
			color = ThemeRef.TEXT
		"character":
			size = SIZE_CHARACTER
			color = ThemeRef.TEXT
		_:
			size = SIZE_PROFILE
			color = ThemeRef.TEXT
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func name_label(text: String) -> Label:
	var label := Layout.outlined_label(text.to_upper(), SIZE_PROFILE, ThemeRef.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	apply(label, "profile")
	return label


static func bind_nameplate(plate: Control) -> void:
	Layout.bind_frac_rect(plate, NAMEPLATE_LEFT, NAMEPLATE_TOP, NAMEPLATE_RIGHT, NAMEPLATE_BOTTOM)


static func bind_portrait(rect: Control) -> void:
	Layout.bind_frac_rect(rect, PORTRAIT_LEFT, PORTRAIT_TOP, PORTRAIT_RIGHT, PORTRAIT_BOTTOM)


static func bind_banner_portrait(rect: Control) -> void:
	Layout.bind_frac_rect(rect, BANNER_PORTRAIT_LEFT, BANNER_PORTRAIT_TOP, BANNER_PORTRAIT_RIGHT, BANNER_PORTRAIT_BOTTOM)


static func bind_banner_nameplate(plate: Control) -> void:
	Layout.bind_frac_rect(plate, BANNER_NAME_LEFT, BANNER_NAME_TOP, BANNER_NAME_RIGHT, BANNER_NAME_BOTTOM)


static func bind_banner_status(plate: Control) -> void:
	Layout.bind_frac_rect(plate, BANNER_STATUS_LEFT, BANNER_STATUS_TOP, BANNER_STATUS_RIGHT, BANNER_STATUS_BOTTOM)


static func bind_banner_check(control: Control) -> void:
	Layout.bind_frac_rect(control, BANNER_CHECK_LEFT, BANNER_CHECK_TOP, BANNER_CHECK_RIGHT, BANNER_CHECK_BOTTOM)


static func bind_character_portrait(rect: Control) -> void:
	Layout.bind_frac_rect(rect, CHAR_PORTRAIT_LEFT, CHAR_PORTRAIT_TOP, CHAR_PORTRAIT_RIGHT, CHAR_PORTRAIT_BOTTOM)


static func bind_character_nameplate(plate: Control) -> void:
	Layout.bind_frac_rect(plate, CHAR_NAMEPLATE_LEFT, CHAR_NAMEPLATE_TOP, CHAR_NAMEPLATE_RIGHT, CHAR_NAMEPLATE_BOTTOM)


static func hub_row_top(index: int) -> float:
	var span := HUB_ROW_AREA_BOTTOM - HUB_ROW_AREA_TOP
	return HUB_ROW_AREA_TOP + span * (float(index) / float(HUB_ROW_COUNT))


static func hub_row_bottom(index: int) -> float:
	var span := HUB_ROW_AREA_BOTTOM - HUB_ROW_AREA_TOP
	return HUB_ROW_AREA_TOP + span * (float(index + 1) / float(HUB_ROW_COUNT))
