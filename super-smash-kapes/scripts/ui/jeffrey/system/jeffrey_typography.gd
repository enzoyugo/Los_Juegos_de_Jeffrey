class_name JeffreyTypography
extends RefCounted

## Single typography authority for all Godot-rendered Jeffrey UI.
## Mode screens apply a Theme at their root; dynamically-created controls
## inherit it automatically. Borsok is the deterministic shared fallback.

const GLOBAL := "global"
const TRACK := "track"
const ZOMBIES := "zombies"
const SOCO := "soco"

const BORSOK: Font = preload("res://assets/fonts/global/boorsok.ttf")
const VETER: Font = preload("res://assets/fonts/track/Veter.ttf")
const SUPER_MIDNIGHT: Font = preload("res://assets/fonts/zombies/Super Midnight.ttf")
const JUMBOTRON: Font = preload("res://assets/fonts/soco/JUMBOTRON.otf")
const SUPER_CRAWLER: Font = preload("res://assets/fonts/soco/Super Crawler.ttf")

## Change this one reference to switch the active Soco/Smash face globally.
const SOCO_PRIMARY: Font = JUMBOTRON


static func font_for(mode: String, soco_alternate: bool = false) -> Font:
	_ensure_fallbacks()
	match mode.to_lower():
		TRACK:
			return VETER
		ZOMBIES:
			return SUPER_MIDNIGHT
		SOCO:
			return SUPER_CRAWLER if soco_alternate else SOCO_PRIMARY
		_:
			return BORSOK


static func theme_for(mode: String, soco_alternate: bool = false) -> Theme:
	_ensure_fallbacks()
	var theme := Theme.new()
	theme.default_font = font_for(mode, soco_alternate)
	theme.default_font_size = 18
	return theme

static func supports_glyph(font: Font, codepoint: int) -> bool:
	if font == null:
		return false
	if font.has_char(codepoint):
		return true
	for fallback in font.fallbacks:
		if fallback != null and fallback.has_char(codepoint):
			return true
	return false

static func _ensure_fallbacks() -> void:
	for font in [VETER, JUMBOTRON, SUPER_CRAWLER]:
		if font is FontFile:
			var file_font := font as FontFile
			if not file_font.fallbacks.has(BORSOK):
				file_font.fallbacks = [BORSOK]


static func apply_label(label: Label, mode: String = GLOBAL) -> void:
	if label != null:
		label.add_theme_font_override("font", font_for(mode))

static func apply_label3d(label: Label3D, mode: String = GLOBAL) -> void:
	if label != null:
		label.font = font_for(mode)


static func apply_button(button: Button, mode: String = GLOBAL) -> void:
	if button != null:
		button.add_theme_font_override("font", font_for(mode))


static func apply_line_edit(edit: LineEdit, mode: String = GLOBAL) -> void:
	if edit != null:
		edit.add_theme_font_override("font", font_for(mode))
