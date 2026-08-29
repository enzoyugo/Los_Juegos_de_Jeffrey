class_name JeffreyShellChrome
extends RefCounted

## Compatibility wrapper. New screens should use ShellFrame / GlobalShellTheme.
const Frame := preload("res://scripts/ui/jeffrey/shell_frame.gd")
const Labels := preload("res://scripts/ui/jeffrey/shell_labels.gd")
const ButtonScript := preload("res://scripts/ui/jeffrey/shell_button.gd")


static func decorate(root: Control) -> void:
	Frame.decorate(root)


static func title(text: String, _size: int = 48) -> Label:
	return Labels.screen_title(text)


static func subtitle(text: String) -> Label:
	return Labels.helper(text)


static func button(text: String, min_size: Vector2 = Vector2(280, 56)) -> Button:
	var btn = ButtonScript.new()
	btn.configure(text, ButtonScript.Kind.PRIMARY, min_size)
	return btn


static func error_label() -> Label:
	return Labels.error()
