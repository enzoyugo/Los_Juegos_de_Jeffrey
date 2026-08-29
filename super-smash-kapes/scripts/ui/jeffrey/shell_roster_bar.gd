class_name ShellRosterBar
extends HBoxContainer

const ThemeRef := preload("res://scripts/ui/jeffrey/global_shell_theme.gd")
const ButtonScript := preload("res://scripts/ui/jeffrey/shell_button.gd")

signal edit_pressed

var _summary: Label
var _edit: Button


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 4)
	add_child(block)
	var heading := Label.new()
	heading.text = "HOY"
	heading.add_theme_font_size_override("font_size", ThemeRef.SIZE_SECTION)
	heading.add_theme_color_override("font_color", ThemeRef.MUTED)
	block.add_child(heading)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD
	_summary.add_theme_font_size_override("font_size", ThemeRef.SIZE_BODY)
	_summary.add_theme_color_override("font_color", ThemeRef.TEXT)
	block.add_child(_summary)
	_edit = ButtonScript.new()
	_edit.configure("EDITAR", ButtonScript.Kind.SECONDARY, Vector2(140, 48))
	_edit.pressed.connect(func(): edit_pressed.emit())
	add_child(_edit)
	refresh()


func refresh() -> void:
	if _summary == null:
		return
	_summary.text = summarize(JeffreyCore.session.active_player_ids, JeffreyCore.profiles)


static func summarize(ids, store) -> String:
	var names: Array[String] = []
	for profile_id in ids:
		var profile = store.get_profile(profile_id)
		if profile != null:
			names.append(profile.display_name)
	if names.is_empty():
		return "Nadie seleccionado"
	if names.size() <= 4:
		return " · ".join(names)
	var shown: PackedStringArray = PackedStringArray()
	for i in 4:
		shown.append(names[i])
	return "%d jugadores\n%s · +%d" % [names.size(), " · ".join(shown), names.size() - 4]
