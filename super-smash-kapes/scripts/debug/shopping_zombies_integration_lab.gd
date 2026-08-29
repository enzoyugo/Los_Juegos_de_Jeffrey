extends Node3D

## Debug composition: Shopping shell + parking + interior. F3 HUD, F4 hide shell.

const MapScript := preload("res://scripts/zombies/zombies_map.gd")

var _map
var _label: Label
var _hide_shell: bool = false


func _ready() -> void:
	_map = MapScript.new()
	add_child(_map)
	_map.build()
	var cam := Camera3D.new()
	cam.current = true
	add_child(cam)
	cam.position = Vector3(0, 8.5, 38)
	cam.look_at(Vector3(0, 2.0, 8.2))
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(_label)
	print("[ZOMBIES_INTEGRATION] shell=%s spawn=%s parking=%d plaza=%d" % [
		str(_map.shell_loaded), str(_map.player_spawn), _map.parking_spawns.size(), _map.plaza_spawns.size()
	])
	if _map.shell_node != null:
		print("[ZOMBIES_INTEGRATION] SHELL_AABB %s size=%s" % [str(_map.shell_node.aabb.position), str(_map.shell_node.aabb.size)])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F4:
		_hide_shell = not _hide_shell
		if _map.shell_node != null:
			_map.shell_node.visible = not _hide_shell
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _label == null or _map == null:
		return
	_label.text = "SHOPPING INTEGRATION LAB\nshell %s  shopping_open %s  gallery_open %s\nnav %s\nF4 toggle shell" % [
		"YES" if _map.shell_loaded else "NO",
		str(_map.shopping_open),
		str(_map.gallery_open),
		_map.nav_mode,
	]
