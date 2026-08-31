extends Node3D

## H02: production M0 stage landing probe. The stage scene and Fighter scene are authoritative.
const STAGE := preload("res://scenes/stages/M0Stage.tscn")
const FIGHTER := preload("res://scenes/fighters/Fighter.tscn")
const OUT := "E:/JeffreyAIResearch/outputs/runtime-review/jeffrey_p0_closure_v1/smash"
var _fighter: CharacterBody3D
var _stage: Node3D
var _samples: Array = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_stage = STAGE.instantiate()
	add_child(_stage)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 6.5, 16.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 0.0, 0.0)
	light.light_energy = 1.2
	add_child(light)
	_fighter = FIGHTER.instantiate()
	_fighter.fighter_id = "jaguarete"
	_fighter.player_id = 1
	_fighter.position = Vector3(-7.0, 8.0, 0.0)
	add_child(_fighter)
	await _wait_landing(2.5)
	_sample("platform_A")
	_capture("01_platform_A_landing.png")
	_fighter.global_position = Vector3(7.0, 8.0, 0.0)
	_fighter.velocity = Vector3.ZERO
	await _wait_landing(2.5)
	_sample("platform_B")
	_capture("02_platform_B_landing.png")
	_capture("03_stage_platform_layout.png")
	var pass_all := true
	for item in _samples:
		pass_all = pass_all and bool(item.get("grounded", false)) and absf(float(item.get("delta_y", 999.0))) < 0.15
	var payload := {"samples": _samples, "pass": pass_all}
	print("[P0_SMASH_PLATFORM] %s" % JSON.stringify(payload))
	var f := FileAccess.open("E:/JeffreyAIResearch/outputs/runtime-review/jeffrey_p0_closure_v1/logs/smash_platform_harness.log", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "\t")); f.close()
	get_tree().quit(0 if pass_all else 1)

func _wait_landing(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _sample(label: String) -> void:
	var platform_y: float = 3.025 if label == "platform_A" or label == "platform_B" else 0.5
	_samples.append({"platform": label, "fighter_y": _fighter.global_position.y, "platform_top_y": platform_y, "delta_y": _fighter.global_position.y - platform_y, "grounded": _fighter.is_on_floor(), "position": str(_fighter.global_position)})

func _capture(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("%s/%s" % [OUT, name])
