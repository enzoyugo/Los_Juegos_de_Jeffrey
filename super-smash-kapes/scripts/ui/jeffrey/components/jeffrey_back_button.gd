class_name JeffreyBackButton
extends Control

signal pressed

const Assets := preload("res://scripts/ui/jeffrey/global_ui_assets.gd")
const Layout := preload("res://scripts/ui/jeffrey/global_ui_layout.gd")
const ImageButton := preload("res://scripts/ui/jeffrey/global_image_button.gd")
const AudioHooks := preload("res://scripts/ui/jeffrey/global_ui_audio.gd")

var _button: Button


func _ready() -> void:
	_button = ImageButton.new()
	add_child(_button)
	Layout.bind_full(_button)
	_button.setup(Assets.BACK_BUTTON, "VOLVER", Vector2(180, 64))
	_button.pressed.connect(func():
		AudioHooks.play_back(self)
		pressed.emit()
	)
	call_deferred("_focus")


func _focus() -> void:
	if _button != null:
		_button.grab_focus()


func request_focus_back() -> void:
	_focus()
