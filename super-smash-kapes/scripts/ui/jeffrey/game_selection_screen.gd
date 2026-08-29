class_name JeffreyGameSelectionScreen
extends Control

signal mode_chosen(mode_id: String)
signal edit_players_pressed
signal options_pressed

const Frame := preload("res://scripts/ui/jeffrey/shell_frame.gd")
const Labels := preload("res://scripts/ui/jeffrey/shell_labels.gd")
const ModeCard := preload("res://scripts/ui/jeffrey/shell_mode_card.gd")
const RosterBar := preload("res://scripts/ui/jeffrey/shell_roster_bar.gd")
const ButtonScript := preload("res://scripts/ui/jeffrey/shell_button.gd")
const Assets := preload("res://scripts/ui/jeffrey/shell_assets.gd")

var _error: Label
var _first_card: Button


func _ready() -> void:
	var margin = Frame.decorate(self)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	margin.add_child(layout)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	layout.add_child(header)
	var logo := TextureRect.new()
	logo.texture = Assets.logo()
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 64)
	logo.visible = logo.texture != null
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(logo)
	header.add_child(Labels.game_title("LOS JUEGOS DE JEFFREY"))

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 20)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(cards)
	for mode in JeffreyCore.modes.get_all_modes():
		var card = ModeCard.new()
		cards.add_child(card)
		card.setup(mode)
		var chosen_id: String = str(mode.id)
		card.pressed.connect(func(): _choose(chosen_id))
		if _first_card == null:
			_first_card = card

	_error = Labels.error()
	layout.add_child(_error)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	layout.add_child(footer)
	var roster = RosterBar.new()
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster.edit_pressed.connect(func(): edit_players_pressed.emit())
	footer.add_child(roster)
	var options = ButtonScript.new()
	options.configure("OPCIONES", ButtonScript.Kind.SECONDARY, Vector2(160, 48))
	options.pressed.connect(func(): options_pressed.emit())
	footer.add_child(options)

	call_deferred("_focus_first")


func _focus_first() -> void:
	if _first_card != null:
		_first_card.grab_focus()


func _choose(mode_id: String) -> void:
	var mode = JeffreyCore.modes.get_mode(mode_id)
	if mode == null:
		_error.text = "Ese modo no está registrado."
		return
	if mode.availability == "playable" and not ResourceLoader.exists(mode.scene_path):
		_error.text = "No se encontró la escena de %s." % mode.display_name
		push_error("[Jeffrey] missing mode scene: %s" % mode.scene_path)
		return
	_error.text = ""
	print("[MODE] Selected: %s" % str(mode.display_name).to_upper())
	mode_chosen.emit(mode_id)
