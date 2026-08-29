class_name JeffreyComingSoonScreen
extends Control

signal back_pressed

const Frame := preload("res://scripts/ui/jeffrey/shell_frame.gd")
const Labels := preload("res://scripts/ui/jeffrey/shell_labels.gd")
const ButtonScript := preload("res://scripts/ui/jeffrey/shell_button.gd")
const ModeCard := preload("res://scripts/ui/jeffrey/shell_mode_card.gd")

var mode_id: String = ""
var participant_names: PackedStringArray = PackedStringArray()


func request_back() -> void:
	back_pressed.emit()


func _ready() -> void:
	set_process_unhandled_input(true)
	var mode = JeffreyCore.modes.get_mode(mode_id)
	var margin = Frame.decorate(self)
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)
	if mode != null:
		var card = ModeCard.new()
		card.custom_minimum_size = Vector2(360, 380)
		card.disabled = true
		layout.add_child(card)
		card.setup(mode)
	else:
		layout.add_child(Labels.screen_title("MODO"))
	if not participant_names.is_empty():
		layout.add_child(Labels.helper(" · ".join(participant_names)))
	var back = ButtonScript.new()
	back.configure("VOLVER", ButtonScript.Kind.PRIMARY, Vector2(220, 52))
	back.pressed.connect(func(): back_pressed.emit())
	layout.add_child(back)
	call_deferred("_focus_back", back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_match"):
		request_back()
		get_viewport().set_input_as_handled()


func _focus_back(back: Button) -> void:
	back.grab_focus()
