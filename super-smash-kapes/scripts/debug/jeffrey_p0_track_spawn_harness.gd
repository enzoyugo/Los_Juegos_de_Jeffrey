extends Node3D

## H01: production Track spawn/reset proof. Uses TrackMain's car scene and a real start piece.
const PIECE := preload("res://scenes/track/modules/TrackPiece.tscn")
const CAR := preload("res://scenes/track/TrackCarWheelPhysics.tscn")
const OUT := "E:/JeffreyAIResearch/outputs/runtime-review/jeffrey_p0_closure_v1/track"
var _car: Node
var _t := 0.0
var _phase := 0
var result: Dictionary = {}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var piece = PIECE.instantiate()
	piece.piece_id = "start"
	add_child(piece)
	var camera := Camera3D.new()
	camera.position = Vector3(8.0, 5.5, 8.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.5, -8.0), Vector3.UP)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -25.0, 0.0)
	light.light_energy = 1.2
	add_child(light)
	var start: Transform3D = piece.player_spawn.global_transform
	_car = CAR.instantiate()
	add_child(_car)
	_car.reset_to(start)
	await _settle()
	_capture("01_spawn.png")
	var before: Vector3 = _car.global_position
	_car.use_scripted_input = true
	_car.scripted_throttle = 1.0
	await get_tree().create_timer(0.35).timeout
	_car.use_scripted_input = false
	_car.reset_to(start)
	await _settle()
	_capture("02_respawn.png")
	var wheels: Array = _car.wheels()
	var grounded := 0
	for wheel in wheels:
		if wheel != null and wheel.is_grounded:
			grounded += 1
	result = {"spawn_position": str(start.origin), "motion_position": str(before), "grounded_wheels": grounded, "wheel_count": wheels.size(), "reset_speed": _car.linear_velocity.length(), "reset_angular_speed": _car.angular_velocity.length(), "pass": grounded == 4 and _car.linear_velocity.length() < 0.01 and _car.angular_velocity.length() < 0.01}
	print("[P0_TRACK_SPAWN] %s" % JSON.stringify(result))
	var f := FileAccess.open("E:/JeffreyAIResearch/outputs/runtime-review/jeffrey_p0_closure_v1/logs/track_respawn_harness.log", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(result, "\t")); f.close()
	get_tree().quit(0 if result.pass else 1)

func _settle() -> void:
	await get_tree().create_timer(1.4).timeout

func _capture(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("%s/%s" % [OUT, name])
