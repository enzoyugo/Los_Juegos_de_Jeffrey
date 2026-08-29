extends Node3D

## Rendered 4WHEEL lab captures. Does not promote TrackMain.

const PIECE_SCENE := "res://scenes/track/modules/TrackPiece.tscn"
const CAR_PATH := "res://scenes/track/TrackCarWheelPhysics.tscn"
const OUT := "res://docs/generated/track_visual_v5"

var _root: Node3D
var _cam: Camera3D
var _i: int = -1
var _shots: Array = []


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.light_energy = 1.15
	add_child(sun)
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 68.0
	add_child(_cam)
	_shots = [
		{"name": "4wheel_short.png", "seq": ["start", "straight_short", "straight_medium", "finish"]},
		{"name": "4wheel_medium.png", "seq": ["start", "straight_medium", "curve_r_90", "straight_short", "finish"]},
		{"name": "4wheel_elevation.png", "seq": ["start", "slope_up_gentle", "crest_gentle", "slope_down_gentle", "finish"]},
		{"name": "boost_normal.png", "seq": ["start", "straight_medium", "boost_straight", "straight_medium", "finish"]},
		{"name": "boost_wrong_way_skip.png", "seq": ["start", "boost_straight", "finish"]},
	]
	print("[TRACK_CAPTURE] START")
	call_deferred("_kick")


func _kick() -> void:
	await get_tree().process_frame
	_next()


func _next() -> void:
	_i += 1
	if _i >= _shots.size():
		print("[TRACK_CAPTURE] DONE")
		get_tree().quit(0)
		return
	if _root != null:
		_root.queue_free()
		_root = null
		await get_tree().process_frame
	_root = Node3D.new()
	add_child(_root)
	var shot: Dictionary = _shots[_i]
	var target := Transform3D.IDENTITY
	var packed: PackedScene = load(PIECE_SCENE) as PackedScene
	var last: Node3D
	for id in shot["seq"]:
		var piece = packed.instantiate()
		piece.piece_id = str(id)
		_root.add_child(piece)
		piece.align_entry_to(target)
		target = piece.exit_global()
		last = piece
	var car_ps: PackedScene = load(CAR_PATH) as PackedScene
	var car = car_ps.instantiate()
	_root.add_child(car)
	var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 1.15, -2.2))
	if _root.get_child_count() > 0:
		var first = _root.get_child(0)
		if first.get("player_spawn") != null:
			spawn = first.player_spawn.global_transform
	car.reset_to(spawn)
	if str(shot["name"]).contains("wrong_way"):
		car.rotate_y(PI)
	_cam.global_position = spawn.origin + Vector3(7.5, 4.2, 8.0)
	_cam.look_at(spawn.origin + Vector3(0, 0.6, -10.0), Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUT, str(shot["name"])]
	img.save_png(path)
	print("[TRACK_CAPTURE] wrote %s last=%s" % [path, str(last.piece_id) if last != null else ""])
	_next()
