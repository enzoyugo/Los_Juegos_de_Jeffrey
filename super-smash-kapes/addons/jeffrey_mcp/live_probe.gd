extends Node3D
## Minimal live-MCP probe scene. No gameplay. No Shopping del Sol art.

var last_key := ""


func _ready() -> void:
	print("JEFFREY_LIVE_PROBE_READY")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		last_key = OS.get_keycode_string(event.keycode)
