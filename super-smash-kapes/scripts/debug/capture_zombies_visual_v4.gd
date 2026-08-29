extends Node3D

## Rendered visual capture for Shopping del Sol V4. Windowed D3D12.

const MapScript := preload("res://scripts/zombies/zombies_map.gd")
const EnemyScript := preload("res://scripts/zombies/zombies_enemy.gd")

const OUT := "res://docs/generated/zombies_visual_v4"

var _map
var _cam: Camera3D
var _shots: Array = []
var _i: int = -1


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_map = MapScript.new()
	add_child(_map)
	_map.build()
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 70.0
	add_child(_cam)
	_spawn_zombies()
	_shots = [
		{"name": "01_spawn.png", "pos": Vector3(0, 1.7, 32.5), "look": Vector3(0, 2.2, 11.0)},
		{"name": "02_parking_wide.png", "pos": Vector3(0, 16.0, 46.0), "look": Vector3(0, 0.4, 20.0)},
		{"name": "03_facade.png", "pos": Vector3(0, 2.4, 26.0), "look": Vector3(0, 3.6, 8.5)},
		{"name": "04_main_entrance_locked.png", "pos": Vector3(0, 1.8, 19.0), "look": Vector3(0, 2.6, 8.2)},
		{"name": "05_combat_parking.png", "pos": Vector3(0.0, 3.2, 38.0), "look": Vector3(0.0, 1.0, 20.0)},
		{"name": "06_main_entrance_open.png", "pos": Vector3(0, 1.8, 15.0), "look": Vector3(0, 3.0, 6.0)},
		{"name": "07_transition_inside.png", "pos": Vector3(0, 1.7, 9.5), "look": Vector3(0, 2.0, 0.0)},
		{"name": "08_interior.png", "pos": Vector3(0, 1.7, 2.0), "look": Vector3(0, 2.2, -8.0)},
		{"name": "09_night_lighting.png", "pos": Vector3(14.0, 3.5, 34.0), "look": Vector3(0, 5.0, 12.0)},
		{"name": "10_reference_match.png", "pos": Vector3(0, 1.8, 32.0), "look": Vector3(0, 2.4, 11.0)},
		{"name": "spawn_reference_match.png", "pos": Vector3(0, 1.7, 32.5), "look": Vector3(0, 2.2, 11.0)},
	]
	print("[ZOMBIES_CAPTURE] START n=%d shell=%s" % [_shots.size(), str(_map.shell_loaded)])
	call_deferred("_kick")


func _spawn_zombies() -> void:
	for i in 5:
		var z = EnemyScript.new()
		z.position = Vector3(-8.0 + float(i) * 3.5, 0.05, 20.0 + float(i % 2) * 2.0)
		z.ai_enabled = false
		add_child(z)


func _kick() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_next()


func _next() -> void:
	_i += 1
	if _i >= _shots.size():
		print("[ZOMBIES_CAPTURE] DONE")
		get_tree().quit(0)
		return
	if _i == 5 and _map != null and _map.main_entrance != null:
		_map.main_entrance.unlock()
	var shot: Dictionary = _shots[_i]
	_cam.global_position = shot["pos"]
	_cam.look_at(shot["look"], Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUT, str(shot["name"])]
	img.save_png(path)
	print("[ZOMBIES_CAPTURE] wrote %s" % path)
	_next()
