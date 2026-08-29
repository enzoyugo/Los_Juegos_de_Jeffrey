class_name JeffreyInputHint
extends HBoxContainer

## Reusable action hint: [GLYPH] LABEL — keyboard / generic gamepad.

const ThemeRef := preload("res://scripts/ui/jeffrey/system/jeffrey_theme.gd")

const KEYBOARD := {
	"confirm": "ENTER",
	"back": "ESC",
	"pause": "ESC",
	"accelerate": "W",
	"brake": "S",
	"steer": "A/D",
	"drift": "SHIFT",
	"checkpoint": "C",
	"restart": "BKSP",
	"jump": "SPACE",
	"attack": "J",
	"special": "K",
	"move": "WASD",
}

const GAMEPAD := {
	"confirm": "A",
	"back": "B",
	"pause": "START",
	"accelerate": "RT",
	"brake": "LT",
	"steer": "LS",
	"drift": "X",
	"checkpoint": "Y",
	"restart": "SELECT",
	"jump": "A",
	"attack": "X",
	"special": "Y",
	"move": "LS",
}


static func make(action: String, label: String, accent: Color = Color("#3db8c9")) -> HBoxContainer:
	var hint = new()
	hint.configure(action, label, accent)
	return hint


static func device_prefers_gamepad() -> bool:
	for i in Input.get_connected_joypads():
		return true
	return false


func configure(action: String, label: String, accent: Color = Color("#3db8c9")) -> void:
	for child in get_children():
		child.queue_free()
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_CENTER
	var glyph_text := _glyph_for(action)
	var plate := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.07, 0.09, 0.85)
	box.border_color = accent
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	plate.add_theme_stylebox_override("panel", box)
	add_child(plate)
	var glyph := Label.new()
	glyph.text = glyph_text
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 12)
	glyph.add_theme_color_override("font_color", accent)
	plate.add_child(glyph)
	var lab := Label.new()
	lab.text = label.to_upper()
	lab.add_theme_font_size_override("font_size", 12)
	lab.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	add_child(lab)


func _glyph_for(action: String) -> String:
	var key := action.strip_edges().to_lower()
	if device_prefers_gamepad() and GAMEPAD.has(key):
		return str(GAMEPAD[key])
	if KEYBOARD.has(key):
		return str(KEYBOARD[key])
	return key.to_upper()
