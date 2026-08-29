extends Node3D

## Blender SDS exterior only. No zombies. HUMAN_REVIEW_PENDING.

const ENV_A := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v1.glb"
const ENV_B := "res://assets/environments/shopping_del_sol/blender/exports/shopping_del_sol_zombies_environment_v1.glb"
const Probe := preload("res://scripts/debug/jeffrey_resource_probe.gd")

var _cam: Camera3D
var _env_path: String = ""


func _ready() -> void:
	_world()
	_proxies()
	_env_path = ENV_A if ResourceLoader.exists(ENV_A) or FileAccess.file_exists(ENV_A) else ENV_B
	if ResourceLoader.exists(_env_path):
		var packed: PackedScene = load(_env_path) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			inst.name = "BlenderEnv"
			add_child(inst)
			_strip(inst)
			print("[SDS_LAB] loaded=%s HUMAN_REVIEW_PENDING" % _env_path)
		else:
			print("[SDS_LAB] FAIL instantiate %s" % _env_path)
	else:
		print("[SDS_LAB] MISSING glb (run tools/blender/run_v8_content.py sds)")
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.current = true
	add_child(_cam)
	## Spawn view: parking, cars, palms, lamps, facade, entrance.
	_cam.global_position = Vector3(0.0, 1.65, 28.5)
	_cam.look_at(Vector3(0.0, 2.4, 8.2), Vector3.UP)
	Probe.dump("sds_lab", self)
	print("[SDS_LAB] camera pos=%s looking entrance z=8.2" % str(_cam.global_position))


func _world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, 130, 0)
	sun.light_energy = 0.55
	sun.light_color = Color("#9ab0d0")
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1c2438")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7a8498")
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_density = 0.003
	world.environment = env
	add_child(world)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 6.0, 18.0)
	fill.light_energy = 1.6
	fill.omni_range = 28.0
	fill.light_color = Color("#ffd8a8")
	add_child(fill)


func _proxies() -> void:
	## Simple gameplay-aligned floor proxies. Visual mesh is not collision.
	_box(Vector3(0, -0.5, 26.0), Vector3(48, 1, 34))
	_box(Vector3(0, -0.5, 8.9), Vector3(6.2, 1, 2.4))


func _box(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _strip(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	for child in node.get_children():
		_strip(child)
