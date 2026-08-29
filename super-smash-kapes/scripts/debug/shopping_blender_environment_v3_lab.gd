extends Node3D

## SDS V3 art lab. No zombies. Prefers V3 GLB.

const ENV_V3 := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v3.glb"
const ENV_V2 := "res://assets/environments/shopping_del_sol/processed/shopping_del_sol_zombies_environment_v2.glb"
const Probe := preload("res://scripts/debug/jeffrey_resource_probe.gd")


func _ready() -> void:
	_world()
	_proxies()
	var path := ENV_V3 if ResourceLoader.exists(ENV_V3) else ENV_V2
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			inst.name = "BlenderEnv"
			add_child(inst)
			_strip(inst)
			print("[SDS_V3_LAB] loaded=%s HUMAN_REVIEW_PENDING" % path)
		else:
			print("[SDS_V3_LAB] FAIL instantiate %s" % path)
	else:
		print("[SDS_V3_LAB] MISSING glb")
	var cam := Camera3D.new()
	cam.fov = 68.0
	cam.current = true
	add_child(cam)
	cam.global_position = Vector3(0.0, 1.65, 28.5)
	cam.look_at(Vector3(0.0, 3.4, 8.2), Vector3.UP)
	Probe.dump("sds_v3_lab", self)


func _world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, 128, 0)
	sun.light_energy = 0.38
	sun.light_color = Color("#8aa0c8")
	add_child(sun)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1a2232")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6a7488")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 5.5, 16.0)
	fill.light_energy = 2.4
	fill.omni_range = 28.0
	fill.light_color = Color("#ffc070")
	add_child(fill)
	var arch := OmniLight3D.new()
	arch.position = Vector3(0, 6.5, 10.0)
	arch.light_energy = 2.8
	arch.omni_range = 16.0
	arch.light_color = Color("#ffe0a0")
	add_child(arch)


func _proxies() -> void:
	_box(Vector3(0, -0.5, 26.0), Vector3(48, 1, 34))
	_box(Vector3(0, -0.5, 8.9), Vector3(6.2, 1, 2.4))
	_box(Vector3(0, -0.5, -8.0), Vector3(16, 1, 28))


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
