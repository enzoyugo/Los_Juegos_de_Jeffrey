class_name CopaJeffreyConfirmDialog
extends "res://scripts/ui/jeffrey/components/jeffrey_modal.gd"

signal confirmed
signal cancelled


func _ready() -> void:
	super._ready()
	configure_dialog(
		"NUEVA COPA",
		"¿Empezar una nueva Copa Jeffrey?\nSe borrarán los puntos de esta sesión.",
		"NUEVA COPA",
		"CANCELAR",
		func(): confirmed.emit(),
		func(): cancelled.emit(),
		true,
		true,
		Vector2(580, 280)
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		AudioHooks.play_back(self)
		cancelled.emit()
		queue_free()
		get_viewport().set_input_as_handled()
