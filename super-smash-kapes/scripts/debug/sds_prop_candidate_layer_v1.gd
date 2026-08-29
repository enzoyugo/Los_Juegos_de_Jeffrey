extends Node3D

## Isolated SDS prop candidate layer. Not ZombiesMain. Not SDS V4 architecture.
## Only previously runtime-safe processed copies are instanced here.
## Additional processed city props remain in the research library after D3D12 import crashes.

const CANDIDATES := [
	{"path": "res://assets/debug/toolchain_candidates/2009_volkswagen_amarok_low_poly.glb", "name": "PropAmarok", "pos": Vector3(-4.2, 0.0, 0.0)},
	{"path": "res://assets/debug/toolchain_candidates/FireHydrant.glb", "name": "PropHydrant", "pos": Vector3(0.0, 0.0, 0.0)},
	{"path": "res://assets/debug/toolchain_candidates/ParkingMeter.glb", "name": "PropMeter", "pos": Vector3(2.6, 0.0, 0.8)},
	{"path": "res://assets/debug/toolchain_candidates/Light.glb", "name": "PropLight", "pos": Vector3(4.8, 0.0, -0.4)},
]


func _ready() -> void:
	_stage()
	for item in CANDIDATES:
		await _load_candidate(str(item["path"]), str(item["name"]), item["pos"])
	var cam := Camera3D.new()
	cam.name = "CandidateCamera"
	cam.fov = 55.0
	cam.current = true
	add_child(cam)
	cam.global_position = Vector3(0.0, 2.2, 9.0)
	cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
	print("[SDS_PROP_CANDIDATE_LAYER_V1] ready")


func _stage() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "CandidateLight"
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var world := WorldEnvironment.new()
	world.name = "CandidateWorld"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.19, 0.21)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.6)
	env.ambient_light_energy = 0.85
	world.environment = env
	add_child(world)
	var floor := MeshInstance3D.new()
	floor.name = "CandidateFloor"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(28, 28)
	floor.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.31, 0.33)
	floor.set_surface_override_material(0, mat)
	add_child(floor)


func _load_candidate(path: String, node_name: String, pos: Vector3) -> void:
	var tries := 0
	while tries < 40:
		if ResourceLoader.exists(path):
			break
		await get_tree().create_timer(0.25).timeout
		tries += 1
	if not ResourceLoader.exists(path):
		print("[SDS_PROP_CANDIDATE_LAYER_V1] MISSING %s" % path)
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("[SDS_PROP_CANDIDATE_LAYER_V1] FAIL load %s" % path)
		return
	var inst := packed.instantiate()
	inst.name = node_name
	inst.position = pos
	add_child(inst)
	print("[SDS_PROP_CANDIDATE_LAYER_V1] loaded %s" % node_name)
