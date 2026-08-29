extends Node3D

## Isolated Track roadside candidate. Does not alter the procedural generator.
## Loads only Godot-isolated-probe PASS assets. Not canonical Track scenery.

const SIGNS := [
	{"path": "res://assets/debug/toolchain_candidates/Sign_ReduceSpeed_34.glb", "pos": Vector3(-3.2, 0.0, -1.6)},
	{"path": "res://assets/debug/toolchain_candidates/Light.glb", "pos": Vector3(3.4, 0.0, -2.0)},
	{"path": "res://assets/debug/toolchain_candidates/FireHydrant.glb", "pos": Vector3(4.6, 0.0, 0.8)},
	{"path": "res://assets/debug/toolchain_candidates/ParkingMeter.glb", "pos": Vector3(-4.4, 0.0, 1.2)},
]


func _ready() -> void:
	_stage()
	for item in SIGNS:
		await _load_candidate(str(item["path"]), item["pos"])
	var cam := Camera3D.new()
	cam.name = "RoadsideCamera"
	cam.fov = 50.0
	cam.current = true
	add_child(cam)
	cam.global_position = Vector3(0.0, 1.8, 8.5)
	cam.look_at(Vector3(0.0, 0.9, -1.5), Vector3.UP)
	print("[TRACK_ROADSIDE_CANDIDATE_V1] ready d3d12_isolated_pass_props=true HUMAN_REVIEW_REQUIRED")


func _load_candidate(path: String, pos: Vector3) -> void:
	var tries := 0
	while tries < 40:
		if ResourceLoader.exists(path):
			break
		await get_tree().create_timer(0.25).timeout
		tries += 1
	if not ResourceLoader.exists(path):
		print("[TRACK_ROADSIDE_CANDIDATE_V1] MISSING %s" % path)
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("[TRACK_ROADSIDE_CANDIDATE_V1] FAIL load %s" % path)
		return
	var inst := packed.instantiate()
	inst.position = pos
	add_child(inst)
	print("[TRACK_ROADSIDE_CANDIDATE_V1] loaded %s" % path)


func _stage() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "RoadsideLight"
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.light_energy = 1.15
	add_child(sun)
	var world := WorldEnvironment.new()
	world.name = "RoadsideWorld"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.37, 0.48, 0.56)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.82, 0.86)
	env.ambient_light_energy = 0.7
	world.environment = env
	add_child(world)
	var road := MeshInstance3D.new()
	road.name = "RoadStrip"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(18.0, 0.08, 6.0)
	road.mesh = mesh
	road.position = Vector3(0.0, -0.04, 1.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.23, 0.24)
	road.set_surface_override_material(0, mat)
	add_child(road)
	var post := MeshInstance3D.new()
	post.name = "PlaceholderPost"
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 2.2, 0.12)
	post.mesh = box
	post.position = Vector3(-3.2, 1.1, -1.8)
	add_child(post)
