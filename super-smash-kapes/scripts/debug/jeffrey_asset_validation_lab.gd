extends Node3D

## Debug-only processed-asset validation lab. Not gameplay. Not SDS art.

const AMAROK := "res://assets/debug/toolchain_candidates/2009_volkswagen_amarok_low_poly.glb"
const HYDRANT := "res://assets/debug/toolchain_candidates/FireHydrant.glb"


func _ready() -> void:
	_stage()
	await _load_candidate(AMAROK, "ProcessedAssetAmarok", Vector3(-2.2, 0.0, 0.0))
	await _load_candidate(HYDRANT, "ProcessedAssetHydrant", Vector3(2.2, 0.0, 0.0))
	var cam := Camera3D.new()
	cam.name = "ValidationCamera"
	cam.fov = 50.0
	cam.current = true
	add_child(cam)
	cam.global_position = Vector3(0.0, 1.6, 6.5)
	cam.look_at(Vector3(0.0, 0.6, 0.0), Vector3.UP)
	print("[JEFFREY_ASSET_LAB] ready amarok=%s hydrant=%s" % [has_node("ProcessedAssetAmarok"), has_node("ProcessedAssetHydrant")])


func _stage() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "ValidationLight"
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var world := WorldEnvironment.new()
	world.name = "ValidationWorld"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.6)
	env.ambient_light_energy = 0.85
	world.environment = env
	add_child(world)
	var floor := MeshInstance3D.new()
	floor.name = "ValidationFloor"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(14, 14)
	floor.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.29, 0.31)
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
		print("[JEFFREY_ASSET_LAB] MISSING %s exists_on_disk=%s" % [path, FileAccess.file_exists(path)])
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("[JEFFREY_ASSET_LAB] FAIL load %s" % path)
		return
	var inst := packed.instantiate()
	inst.name = node_name
	inst.position = pos
	add_child(inst)
	print("[JEFFREY_ASSET_LAB] loaded %s as %s" % [path, node_name])
